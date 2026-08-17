-------------------------------------------------
-- Production Chooser Popup
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("InfoTooltipInclude");

local g_UnitInstanceManager		= InstanceManager:new( "ProdButton", "Top", Controls.UnitButtonStack );
local g_BuildingInstanceManager = InstanceManager:new( "ProdButton", "Top", Controls.BuildingButtonStack );
local g_WonderInstanceManager	= InstanceManager:new( "ProdButton", "Top", Controls.WonderButtonStack );
local g_ProcessInstanceManager	= InstanceManager:new( "ProdButton", "Top", Controls.OtherButtonStack );
local g_PlotSelectButtonIM		= nil;

local m_PopupInfo = nil;

local bHidden = true;
local m_cachedCompletedEntries = {};

------------------------------------------------
-- global constants
------------------------------------------------
g_strInfiniteTurns = Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_INFINITE_TURNS");

-- Storing current city in a global because the button cannot have more than 2 extra args.
-- NOTE: Storing the PlayerID/CityID for the city, it is not safe to store the pointer to a city
--       over multiple frames, the city could get removed by the game core thread
local g_currentCityOwnerID = -1;
local g_currentCityID = -1;

local g_append = false;
local g_IsProductionMode = true;
local g_PlotProjectData = {};	--	necessary to carry project data between selection and plot button callbacks

-- Defines used to track building/unit and energy/faith information on city purchase menu with a single int
local g_PURCHASE_UNIT_ENERGY = 0;
local g_PURCHASE_BUILDING_ENERGY = 1;
local g_PURCHASE_PROJECT_ENERGY = 2;
local g_CONSTRUCT_UNIT = 6;
local g_CONSTRUCT_BUILDING = 7;
local g_CONSTRUCT_PROJECT = 8;
local g_MAINTAIN_PROCESS = 9;

local g_TheVeniceException = false;

local m_gOrderType = -1;
local m_gFinishedItemType = -1;

local m_screenSizeX, m_screenSizeY = UIManager:GetScreenSizeVal()

local listOfStrings = {};

-- Base width to truncate to before advisor icons are taken into account.
local g_UnitNameBaseTruncateWidth = 410;


-------------------------------------------------
-- Get the current city the popup is working with
-- Can return nil
-------------------------------------------------
function GetCurrentCity()
	if (g_currentCityOwnerID ~= -1 and g_currentCityID ~= -1) then
		local pPlayer = Players[g_currentCityOwnerID];
		if (pPlayer ~= nil) then
			local pCity = pPlayer:GetCityByID(g_currentCityID);
			return pCity;
		end
	end
	
	return nil;
end
-------------------------------------------------
-- On Production Selected
-------------------------------------------------
function ProductionSelected( ePurchaseEnum, iData)
	
	local eOrder;
	local eYield;
		
	-- Viewing mode only!
	local player = Players[Game.GetActivePlayer()];	
    local city = GetCurrentCity();

	-- Unpack the enum
	if (ePurchaseEnum == g_PURCHASE_UNIT_ENERGY) then
	   eOrder = OrderTypes.ORDER_TRAIN;
	   eYield = YieldTypes.YIELD_ENERGY;
	elseif (ePurchaseEnum == g_PURCHASE_BUILDING_ENERGY) then
	   eOrder = OrderTypes.ORDER_CONSTRUCT;
	   eYield = YieldTypes.YIELD_ENERGY;
	elseif (ePurchaseEnum == g_PURCHASE_PROJECT_ENERGY) then
	   eOrder = OrderTypes.ORDER_CREATE;
	   eYield = YieldTypes.YIELD_ENERGY;
	elseif (ePurchaseEnum == g_CONSTRUCT_UNIT) then
	   eOrder = OrderTypes.ORDER_TRAIN;
	elseif (ePurchaseEnum == g_CONSTRUCT_BUILDING) then
	   eOrder = OrderTypes.ORDER_CONSTRUCT;
	elseif (ePurchaseEnum == g_CONSTRUCT_PROJECT) then
	   eOrder = OrderTypes.ORDER_CREATE;
	elseif (ePurchaseEnum == g_MAINTAIN_PROCESS) then
	   eOrder = OrderTypes.ORDER_MAINTAIN;
	else
		error("ProductionSelected: Unrecognized order or yield info");
	end
    
    if (city == nil) then
		OnClose();
		return;
	end

	-- Early out here if this is a plot choice project (handled elsewhere)
	if eOrder == OrderTypes.ORDER_CREATE then
		local projectInfo = GameInfo.Projects[iData];
		if projectInfo ~= nil then
			if projectInfo.PlotProject then
				DoProjectPlotSelection (eOrder, iData, projectInfo);
			return;
			end
		end
	else
		-- Restore interface mode if we were presently in wonder plot mode and are clicking on a different production button
		if UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION then
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		end	
	end

    if g_IsProductionMode then
		
		Game.CityPushOrder(city, eOrder, iData, false, not g_append, true);

		-- Remove from "just finished" cache, now that something else is selected.
		local x = city:GetX();
		local y = city:GetY();
		for i,completedEntry in ipairs(m_cachedCompletedEntries) do
			if completedEntry.x == x and completedEntry.y == y then
				table.remove( m_cachedCompletedEntries, i );
				break;
			end
		end		

    else
		if (eOrder == OrderTypes.ORDER_TRAIN) then
			if (city:IsCanPurchase(true, true, iData, -1, -1, eYield)) then
				Game.CityPurchaseUnit(city, iData, eYield);
			end
		elseif (eOrder == OrderTypes.ORDER_CONSTRUCT) then
			if (city:IsCanPurchase(true, true, -1, iData, -1, eYield)) then
				Game.CityPurchaseBuilding(city, iData, eYield);
			end
		elseif (eOrder == OrderTypes.ORDER_CREATE) then
			if (city:IsCanPurchase(true, true, -1, -1, iData, eYield)) then
				Game.CityPurchaseProject(city, iData, eYield);
			end
		end
		
		if (eOrder == OrderTypes.ORDER_TRAIN or eOrder == OrderTypes.ORDER_CONSTRUCT or eOrder == OrderTypes.ORDER_CREATE) then
			if (eYield == YieldTypes.YIELD_ENERGY) then
				Events.AudioPlay2DSound("AS2D_INTERFACE_CITY_SCREEN_PURCHASE");
			elseif (eYield == YieldTypes.YIELD_FAITH) then
				Events.AudioPlay2DSound("AS2D_INTERFACE_CITY_SCREEN_PURCHASE");
			end
		end
    end
     
	local cityID = city:GetID();
	local player = city:GetOwner();
    Events.SpecificCityInfoDirty( player, cityID, CityUpdateTypes.CITY_UPDATE_TYPE_BANNER);
    Events.SpecificCityInfoDirty( player, cityID, CityUpdateTypes.CITY_UPDATE_TYPE_PRODUCTION);
--	LuaEvents.CityQueueDirty();

	if not g_append or not g_IsProductionMode then 
		OnClose();
	end
end

-------------------------------------------------
-------------------------------------------------
local buildingHeadingOpen = true;
local unitHeadingOpen = true;
local wonderHeadingOpen = true;
local otherHeadingOpen = true;

function OnBuildingHeaderSelected()
	buildingHeadingOpen = not buildingHeadingOpen;
	UpdateWindow( GetCurrentCity(), true );
end

function OnUnitHeaderSelected()
	unitHeadingOpen = not unitHeadingOpen;
	UpdateWindow( GetCurrentCity(), true );
end

function OnWonderHeaderSelected()
	wonderHeadingOpen = not wonderHeadingOpen;
	UpdateWindow( GetCurrentCity(), true );
end

function OnOtherHeaderSelected()
	otherHeadingOpen = not otherHeadingOpen;
	UpdateWindow( GetCurrentCity(), true );
end


function UpdateWindow( city, focusOnCity )
    g_UnitInstanceManager:ResetInstances();
    g_BuildingInstanceManager:ResetInstances();
    g_WonderInstanceManager:ResetInstances();
    g_ProcessInstanceManager:ResetInstances();

	if ( g_PlotSelectButtonIM == nil ) then
		Initialize();
	end

	if UI.GetInterfaceMode() ~= InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION then
		g_PlotSelectButtonIM:ResetInstances();
		g_PlotProjectData = {};
	end
    
    if city == nil then
		city = UI.GetHeadSelectedCity();
    end

	if focusOnCity == nil then
		focusOnCity = false;
	end

    if city == nil then
		OnClose();
		return;
    end
   
	local qMode = g_append and g_IsProductionMode;
 
	if qMode then
		local qLength = city:GetOrderQueueLength();
		if qLength >= 6 then
			OnClose();
		end
		
		local queuedOrderType;
		local queuedData1;
		local queuedData2;
		local queuedSave;
		local queuedRush;

		local isMaint = false;
		for i = 1, qLength do
			queuedOrderType, queuedData1, queuedData2, queuedSave, queuedRush = city:GetOrderFromQueue( i-1 );
			if (queuedOrderType == OrderTypes.ORDER_MAINTAIN) then
				isMaint = true;
				break;
			end
		end
		
		if isMaint then
			OnClose();
		end
	end

    local player = Players[Game.GetActivePlayer()];
    local cityID = city:GetID();
    
    local selectedCity = UI.GetHeadSelectedCity();
    local selectedCityID = selectedCity and selectedCity:GetID() or -1;
	
	Game.SetAdvisorRecommenderCity(city);

	-- Should we pan to this city?
	if(cityID ~= selectedCityID and focusOnCity == true) then
		local plot = city:Plot();
		UI.LookAt(plot, 0);
	end
   
    g_currentCityID = city:GetID();
    g_currentCityOwnerID = city:GetOwner();

	-- Base Production per turn
	local iProductionPerTurn = city:GetCurrentProductionDifferenceTimes100(false, false) / 100;--pCity:GetYieldRate(YieldTypes.YIELD_PRODUCTION);
	local strTurnsLeft = g_strInfiniteTurns;

	local bGeneratingProduction = false;
	if (iProductionPerTurn > 0) then
		bGeneratingProduction = true;
	end

	listOfStrings = {};
	
	local listWonders = {};
	local listUnits = {};
	local listBuildings = {};
	
	
	function GetUnitSortPriority(unitInfo)
		if(unitInfo.CivilianAttackPriority ~= nil) then
			if(unitInfo.Domain == "DOMAIN_LAND") then
				return 0;
			else
				return 1;
			end
		else
			if(unitInfo.Domain == "DOMAIN_LAND") then
				return 2;
			else
				return 3;
			end
		end	
	end
	
	local eraIDs = {};
	local erasByTech = {};
	
	for row in GameInfo.Eras() do
		eraIDs[row.Type] = row.ID;
	end
	
	for row in GameInfo.Technologies() do
		erasByTech[row.Type] =  eraIDs[row.Era];
	end
	
	
	function GetBuildingSortPriority(buildingInfo)
		if(buildingInfo.PrereqTech ~= nil) then
			return erasByTech[buildingInfo.PrereqTech];
		else
			return 0;
		end
	end
	
    -- Units
 	for unit in GameInfo.Units() do
 		local unitID = unit.ID;
 		if g_IsProductionMode then
 			-- test w/ visible (ie COULD train if ... )
			if city:CanTrain( unitID, false, true ) then
				local isDisabled = false;
     			-- test w/o visible (ie can train right now)
     			local bIsCurrentlyBuilding = false;
     			if (city:GetProductionUnit() == eUnit) then
     				bIsCurrentlyBuilding = true;
     			end
     			
    			if not city:CanTrain(unitID, bIsCurrentlyBuilding) then
    				isDisabled = true;
				end
				
				if (bGeneratingProduction) then
					strTurnsLeft = Locale.ConvertTextKey( "TXT_KEY_STR_TURNS", city:GetUnitProductionTurnsLeft( unitID ));
				else
					strTurnsLeft = g_strInfiniteTurns;
				end

				local descriptionKey = GetUpgradedUnitDescriptionKey(player, unitID);
				
				table.insert(listUnits, {
					ID = unitID,
					Description = descriptionKey;
					DisplayDescription = Locale.Lookup(descriptionKey),
					OrderType = OrderTypes.ORDER_TRAIN,
					Cost = strTurnsLeft,
					Disabled = isDisabled,
					YieldType = YieldTypes.NO_YIELD,
					SortPriority = GetUnitSortPriority(unit)
				});
			end
 		else
			if city:IsCanPurchase(false, false, unitID, -1, -1, YieldTypes.YIELD_ENERGY) then
 				local isDisabled = false;
     			-- test w/o visible (ie can train right now)
	     	
    			if (not city:IsCanPurchase(true, true, unitID, -1, -1, YieldTypes.YIELD_ENERGY)) then
    				isDisabled = true;
				end
	 			
 				local cost = city:GetUnitPurchaseCost( unitID );

				local descriptionKey = GetUpgradedUnitDescriptionKey(player, unitID);
 				
 				table.insert(listUnits, {
 					ID = unitID,
 					Description = descriptionKey,
 					DisplayDescription = Locale.Lookup(descriptionKey),
 					OrderType = OrderTypes.ORDER_TRAIN,
 					Cost = cost,
 					Disabled = isDisabled,
 					YieldType = YieldTypes.YIELD_ENERGY,
 					SortPriority = GetUnitSortPriority(unit)
 				});
 			end
 		end
	end


    -- Projects	
 	for project in GameInfo.Projects() do
 		local projectID = project.ID;
 	 	if g_IsProductionMode then
 	 	 	-- test w/ visible (ie COULD train if ... )
			if city:CanCreate( projectID, 0, 1 ) then
				local isDisabled = false;
			    
     			-- test w/o visible (ie can train right now)
    			if( not city:CanCreate( projectID ) )
    			then
    				isDisabled = true;
				end
				
				if (bGeneratingProduction) then
					strTurnsLeft = Locale.ConvertTextKey( "TXT_KEY_STR_TURNS", city:GetProjectProductionTurnsLeft( projectID ));
				else
					strTurnsLeft = g_strInfiniteTurns;
				end
				
				table.insert(listWonders, {
					ID = projectID,
					Description = project.Description,
					DisplayDescription = Locale.Lookup(project.Description),
					OrderType = OrderTypes.ORDER_CREATE,
					Cost = strTurnsLeft,
					Disabled = isDisabled,
					YieldType = YieldTypes.NO_YIELD,
				});
			end
		else
			if city:IsCanPurchase(false, false, -1, -1, projectID, YieldTypes.YIELD_ENERGY) then
				local isDisabled = true;		    
 				local cost = city:GetProjectPurchaseCost( projectID );
 				
 				table.insert(listWonders, {
 					ID = projectID,
 					Description = project.Description,
 					DisplayDescription = Locale.Lookup(project.Description),
 					OrderType = OrderTypes.ORDER_CREATE,
 					Cost = cost,
 					Disabled = isDisabled,
 					YieldType = YieldTypes.YIELD_ENERGY,
 				});
			end
		end
	end

    -- Buildings	
 	for building in GameInfo.Buildings() do
 		local buildingID = building.ID;
 		if g_IsProductionMode then
 			-- test w/ visible (ie COULD train if ... )
			if city:CanConstruct( buildingID, 0, 1 ) then
				local isDisabled = false;
			    
     			-- test w/o visible (ie can train right now)
    			if not city:CanConstruct( buildingID ) then
    				isDisabled = true;
				end

				local col = 2;
				local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
				if thisBuildingClass.MaxGlobalInstances > 0 or thisBuildingClass.MaxPlayerInstances == 1 or thisBuildingClass.MaxTeamInstances > 0 then
					col = 3;
				end
				
				if (bGeneratingProduction) then
					strTurnsLeft = Locale.ConvertTextKey( "TXT_KEY_STR_TURNS", city:GetBuildingProductionTurnsLeft( buildingID ));
				else
					strTurnsLeft = g_strInfiniteTurns;
				end
				local building = {
					ID = buildingID,
					Description = building.Description,
					DisplayDescription = Locale.Lookup(building.Description),
					OrderType = OrderTypes.ORDER_CONSTRUCT,
					Cost = strTurnsLeft,
					Disabled = isDisabled,
					YieldType = YieldTypes.NO_YIELD,
					SortPriority = GetBuildingSortPriority(building)
				};
				
				if col == 2 then
					table.insert(listBuildings, building);
				else
					table.insert(listWonders, building);
				end
			end
		else
			if city:IsCanPurchase(false, false, -1, buildingID, -1, YieldTypes.YIELD_ENERGY) then
				local col = 2;
				local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
				if thisBuildingClass.MaxGlobalInstances > 0 or thisBuildingClass.MaxPlayerInstances == 1 or thisBuildingClass.MaxTeamInstances > 0 then
					col = 3;
				end

 				local isDisabled = false;
    			if (not city:IsCanPurchase(true, true, -1, buildingID, -1, YieldTypes.YIELD_ENERGY)) then
 					isDisabled = true;
 				end
	 			
 				local cost = city:GetBuildingPurchaseCost( buildingID );
				local building = {
					ID = buildingID,
					Description = building.Description,
					DisplayDescription = Locale.Lookup(building.Description),
					OrderType = OrderTypes.ORDER_CONSTRUCT,
					Cost = cost,
					Disabled = isDisabled,
					YieldType = YieldTypes.YIELD_ENERGY,
					SortPriority = GetBuildingSortPriority(building)
				};
				
				if col == 2 then
					table.insert(listBuildings, building);
				else
					table.insert(listWonders, building);
				end
			end
		end
	end
	
	local GenericSort = function(a,b)
		local aSort = a.SortPriority or 0;
		local bSort = b.SortPriority or 0;
	
		if(aSort == bSort) then
			local comp = Locale.Compare(a.DisplayDescription, b.DisplayDescription);
			if(comp == 0) then
				return a.YieldType ~= YieldTypes.YIELD_FAITH;
			else
				return comp == -1;
			end
		else
			return aSort < bSort;
		end	
	end
	
	numUnitButtons = #listUnits;
	numBuildingButtons = #listBuildings;
	numWonderButtons = #listWonders;
	
	table.sort(listUnits, GenericSort);
	table.sort(listBuildings, GenericSort);
	table.sort(listWonders, GenericSort);
	
	
	local isViewOnly = UI.IsCityScreenViewingMode();

	for _, unit in ipairs(listUnits) do
		AddProductionButton(unit.ID, unit.Description, unit.OrderType, unit.Cost, 1, unit.Disabled or isViewOnly, unit.YieldType);
	end
	for _, building in ipairs(listBuildings) do
		AddProductionButton(building.ID, building.Description, building.OrderType, building.Cost, 2, building.Disabled or isViewOnly, building.YieldType);
	end	
	for _ , wonder in ipairs(listWonders) do
		AddProductionButton(wonder.ID, wonder.Description, wonder.OrderType, wonder.Cost, 3, wonder.Disabled or isViewOnly, wonder.YieldType);
	end	
	
	
	if unitHeadingOpen then
		Controls.UnitButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_POP_UNITS" ));
		Controls.UnitButtonPlus:SetText( "[ICON_MINUS]" );
		Controls.UnitButtonStack:SetHide( false );
		
	else
		Controls.UnitButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_POP_UNITS" ));
		Controls.UnitButtonPlus:SetText( "[ICON_PLUS]" );
		Controls.UnitButtonStack:SetHide( true );
	end
	if numUnitButtons > 0 then
		Controls.UnitButton:SetHide( false );
	else
		Controls.UnitButton:SetHide( true );
		Controls.UnitButton:SetHide( true );
	end
	Controls.UnitButton:RegisterCallback( Mouse.eLClick, OnUnitHeaderSelected );

	
	if buildingHeadingOpen then
		Controls.BuildingsButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_POP_BUILDINGS" ));
		Controls.BuildingsButtonPlus:SetText( "[ICON_MINUS]" );
		Controls.BuildingButtonStack:SetHide( false );
	else
		Controls.BuildingsButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_POP_BUILDINGS" ));
		Controls.BuildingsButtonPlus:SetText( "[ICON_PLUS]" );
		Controls.BuildingButtonStack:SetHide( true );
	end
	if numBuildingButtons > 0 then
		Controls.BuildingsButton:SetHide( false );
	else
		Controls.BuildingsButton:SetHide( true );
		Controls.BuildingsButton:SetHide( true );
	end	
	Controls.BuildingsButton:RegisterCallback( Mouse.eLClick, OnBuildingHeaderSelected );

	
	if wonderHeadingOpen then
		Controls.WondersButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_POP_WONDERS" ));
		Controls.WondersButtonPlus:SetText( "[ICON_MINUS]" );
		Controls.WonderButtonStack:SetHide( false );
	else
		Controls.WondersButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_POP_WONDERS" ));
		Controls.WondersButtonPlus:SetText( "[ICON_PLUS]" );
		Controls.WonderButtonStack:SetHide( true );
	end
	if numWonderButtons > 0 then
		Controls.WondersButton:SetHide( false );
	else
		Controls.WondersButton:SetHide( true );
		Controls.WondersButton:SetHide( true );
	end	
	Controls.WondersButton:RegisterCallback( Mouse.eLClick, OnWonderHeaderSelected );
    	
	-- Processes
	local numOtherButtons = 0;
	for process in GameInfo.Processes() do
		local processID = process.ID;
		if g_IsProductionMode then
			if city:CanMaintain( processID ) then
				local isDisabled = false;
				local col = 4;
				strTurnsLeft = Locale.Lookup("TXT_KEY_PRODUCTION_HELP_ONGOING");
				AddProductionButton( processID, process.Description, OrderTypes.ORDER_MAINTAIN, strTurnsLeft, col, isDisabled or isViewOnly, YieldTypes.NO_YIELD );
				numOtherButtons = numOtherButtons + 1;
			end
		else
			-- Processes cannot be purchased
		end
	end
	if otherHeadingOpen then
		Controls.OtherButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_OTHER" ));
		Controls.OtherButtonPlus:SetText( "[ICON_MINUS]" );
		Controls.OtherButtonStack:SetHide( false );
	else
		Controls.OtherButtonLabel:SetText(Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_OTHER" ));
		Controls.OtherButtonPlus:SetText( "[ICON_PLUS]" );
		Controls.OtherButtonStack:SetHide( true );
	end
	if numOtherButtons > 0 then
		Controls.OtherButton:SetHide( false );
	else
		Controls.OtherButton:SetHide( true );
	end
	Controls.OtherButton:RegisterCallback( Mouse.eLClick, OnOtherHeaderSelected );

    	   	
	-- Header Text
	
	-------------------------------------------
	-- Item under Production
	-------------------------------------------
	
	local strItemName	= "";
	local strStats		= "";
	local strToolTip	= "";
	local unitProduction = -1;
	local buildingProduction = -1;
	local projectProduction = -1;
	local processProduction = -1;
	local noProduction = false;
	local thisInfo = nil;
	local textureOffset;
	local textureSheet;	

	local bIncludeRequirementsInfo  = false; -- always false here, use a good variable name though so we're not tracking down meaning
	
	-- Determine if a production item is finished (just completed) or still in progress
	local bJustFinishedSomething	= false;
	if (m_gOrderType > -1 and m_gOrderType < 5) then
		bJustFinishedSomething = true;
	end

	-- Wasn't raised via the notification (which sets the order type),
	-- check if raised via city or banner by checking what was
	-- eavesdropped via the notifications.	
	if ( not bJustFinishedSomething ) then
		local city = GetCurrentCity();
		local x = city:GetX();
		local y = city:GetY();

		for _,completedEntry in ipairs(m_cachedCompletedEntries) do
			if completedEntry.x == x and completedEntry.y == y then
				bJustFinishedSomething	= true;
				m_gOrderType			= completedEntry.orderType;
				m_gFinishedItemType		= completedEntry.productionId;
				break;
			end
		end		
	end
			
	-- Didn't just finish something
	if ( not bJustFinishedSomething ) then
			
		strItemName = Locale.ConvertTextKey(city:GetProductionNameKey());
		
		-- Description and picture of Item under Production
		unitProduction		= city:GetProductionUnit();
		buildingProduction	= city:GetProductionBuilding();
		projectProduction	= city:GetProductionProject();
		processProduction	= city:GetProductionProcess();
		
	else
		-- We just finished something, so show THAT 	

		strItemName = Locale.ConvertTextKey("TXT_KEY_RESEARCH_FINISHED") .. " ";

		-- Just finished a Unit
		if (m_gOrderType == OrderTypes.ORDER_TRAIN) then
			unitProduction		= m_gFinishedItemType;
			local descriptionKey= GetUpgradedUnitDescriptionKey(player, unitProduction);
			strItemName			= strItemName .. Locale.ConvertTextKey(descriptionKey);			
			
		-- Just finished a Building/Wonder
		elseif (m_gOrderType == OrderTypes.ORDER_CONSTRUCT) then
			buildingProduction	= m_gFinishedItemType;
			strItemName			= strItemName .. Locale.ConvertTextKey(GameInfo.Buildings[buildingProduction].Description);			
			
		-- Just finished a Project
		elseif (m_gOrderType == OrderTypes.ORDER_CREATE) then
			projectProduction	= m_gFinishedItemType;
			strItemName			= strItemName .. Locale.ConvertTextKey(GameInfo.Projects[projectProduction].Description);

		-- Ignore processes (continuous), and initial startup
		else
			strItemName			= "";		
		end
		
		
	end

	if ( unitProduction ~= -1 )	then
		strToolTip	= Locale.ConvertTextKey(GetHelpTextForUnit(unitProduction, bIncludeRequirementsInfo));
		thisInfo	= GameInfo.Units[unitProduction]; 
		local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(unitProduction, g_currentCityOwnerID);
		textureOffset, textureSheet = IconLookup( portraitOffset, 45, portraitAtlas );						
	end
	if ( buildingProduction ~= -1 ) then 
		strToolTip	= Locale.ConvertTextKey(GetHelpTextForBuilding(buildingProduction, bIncludeRequirementsInfo));
		thisInfo	= GameInfo.Buildings[buildingProduction]; 
		strStats	= GetUIIconsForBuilding( buildingProduction, city, false );
		textureOffset, textureSheet = IconLookup( thisInfo.PortraitIndex, 45, thisInfo.IconAtlas );				
	end
	if ( projectProduction ~= -1 )	then 
		strToolTip	= Locale.ConvertTextKey(GetHelpTextForProject(projectProduction, bIncludeRequirementsInfo));
		thisInfo	= GameInfo.Projects[projectProduction]; 
		textureOffset, textureSheet = IconLookup( thisInfo.PortraitIndex, 45, thisInfo.IconAtlas );				
	end
	if ( processProduction ~= -1 )	then 
		strToolTip	= Locale.ConvertTextKey(GetHelpTextForProcess(processProduction, bIncludeRequirementsInfo));
		thisInfo	= GameInfo.Processes[processProduction]; 
		textureOffset, textureSheet = IconLookup( thisInfo.PortraitIndex, 45, thisInfo.IconAtlas );
	end
	
	-- Current/Finished production icon
	if textureSheet ~= nil and textureOffset ~= nil then
		Controls.ProductionImage:SetHide( false );
		Controls.ProductionImage:SetTexture(textureSheet);
		Controls.ProductionImage:SetTextureOffset(textureOffset);
	else
		Controls.ProductionImage:SetHide( true );
	end	
	Controls.ProductionItemName:SetText( Locale.ToUpper(strItemName) );

	Controls.CurrentProductionPanel:SetToolTipString( strToolTip );	
	Controls.ProductionUnitStats:SetText(strStats);

	-- Turns left
	local strNumTurns;
	if ( bJustFinishedSomething ) then
		strNumTurns = "";
	else
		
		if (processProduction ~= -1 ) then
			strNumTurns = Locale.ConvertTextKey("TXT_KEY_PRODUCING_ONGOING") .. "[NEWLINE]" ..  Locale.Lookup("TXT_KEY_PRODUCTION_HELP_ONGOING");
		else
			local productionTurnsLeft = city:GetProductionTurnsLeft();
			if productionTurnsLeft > 99 then
				strNumTurns = Locale.ConvertTextKey("TXT_KEY_PRODUCING_ONGOING") .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_99PLUS_TURNS");
			else
				strNumTurns = Locale.ConvertTextKey("TXT_KEY_PRODUCING_ONGOING") .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_NUM_TURNS", productionTurnsLeft);
			end
		end
	end
	Controls.ProductionNumTurns:SetText( Locale.ToUpper( strNumTurns ));

	
	Controls.UnitButtonStack:CalculateSize();
	Controls.UnitButtonStack:ReprocessAnchoring();
	
	Controls.BuildingButtonStack:CalculateSize();
	Controls.BuildingButtonStack:ReprocessAnchoring();
	
	Controls.WonderButtonStack:CalculateSize();
	Controls.WonderButtonStack:ReprocessAnchoring();
	
	Controls.OtherButtonStack:CalculateSize();
	Controls.OtherButtonStack:ReprocessAnchoring();
	
	Controls.StackOStacks:CalculateSize();
	Controls.StackOStacks:ReprocessAnchoring();

	-- ??TRON: Dynamic resizing not working due to BaseButton style has animation highlights that stay the same size due to VisibilityBox not being updated/calculated
	--local CANCEL_BUTTON_BASE_WIDTH = 20;
	--Controls.CancelButton:SetSizeX( Controls.CancelLabel:GetSizeX() + Controls.CancelIcon:GetSizeX() + CANCEL_BUTTON_BASE_WIDTH );


	-- Adjust height of list based on if a production queue is showing.
	local productionQueueHeight = 0;
	local productionQueueOffsetY = 0;
	local cityView		= ContextPtr:LookUpControl("/InGame/CityView");

	if ( cityView ~= nil and not cityView:IsHidden() ) then
		local queueControl	= ContextPtr:LookUpControl("/InGame/CityView/ProductionQueue");
		if ( queueControl ~= nil and not queueControl:IsHidden() ) then
			queueControl:CalculateSize();		-- Not quite overkill, as adding/removing items adjusts queue size while this is up.
			queueControl:ReprocessAnchoring();
			productionQueueHeight	= queueControl:GetSizeY();
			productionQueueOffsetY	= queueControl:GetOffsetY();
		else
			print("ERROR: Cannot determine height, as production queue control isn't found in lookup path.");
		end
	end

	local ADDITION_HEIGHT_PADDING = 360;
	local subAmount		= Controls.ScrollPanel:GetOffsetY() + productionQueueHeight + productionQueueOffsetY + ADDITION_HEIGHT_PADDING;
	local newHeight		= m_screenSizeY - subAmount;
	Controls.ScrollPanel:SetSizeY( newHeight - 190);
	Controls.ScrollBar:SetSizeY( newHeight - 178);
	Controls.FixScrollArea:SetEndVal( -32, newHeight - 8);
	Controls.ScrollPanel:CalculateInternalSize();
	Controls.ScrollPanel:ReprocessAnchoring();

	Controls.Backdrop:SetSizeY( newHeight );
	Controls.Backdrop:ReprocessAnchoring();
end


-------------------------------------------------
-- On Popup
-------------------------------------------------
function OnPopup( popupInfo )

	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_CHOOSEPRODUCTION ) then
		return;
	end

	-- Hide all the diplo panels that might be open
	LuaEvents.SubDiploPanelClosed();

	CivIconHookup( Game.GetActivePlayer(), 32, Controls.CivIcon, Controls.CivIconBG, Controls.CivIconShadow, false, true );
	
	m_PopupInfo = popupInfo;

	local player = Players[Game.GetActivePlayer()];

	-- Can't open this popup when you're not turn active.
	if(not player:IsTurnActive()) then
		return;
	end

    -- Purchase mode?
    if (popupInfo.Option2 == true) then
		g_IsProductionMode = false;
	else
		g_IsProductionMode = true;
	end

    local city = player:GetCityByID( popupInfo.Data1 );
    
    if (city == nil) then
		return;
	end
    if city and city:IsPuppet() then
		if (player:MayNotAnnex() and not g_IsProductionMode) then
			-- You're super-special Venice and are able to update the window. Congrats.
		else
			return;
		end
    end
	
	m_gOrderType = popupInfo.Data2;
	m_gFinishedItemType = popupInfo.Data3;
	
    g_append = popupInfo.Option1;
	print("popupInfo.Option1 (append): " .. tostring(g_append) );
	print("popupInfo.Option2: (productionMode): " .. tostring(g_IsProductionMode) );
 
	UpdateWindow( city, true );
 			
    --UIManager:QueuePopup( ContextPtr, PopupPriority.ProductionPopup );
    ContextPtr:SetHide( false );
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

function OnSubDiploPanelOpen()
	OnClose();
end
LuaEvents.SubDiploPanelOpen.Add(OnSubDiploPanelOpen);

-- ===========================================================================
function OnDirty( isQueueOpen )
	if (isQueueOpen ~= nil) then		
		g_append = (isQueueOpen ~= 0);		-- Sometimes this is setting g_append to zero which is not registering as false!
	end

	if not bHidden then
		local pCity = UI.GetHeadSelectedCity();
		if pCity ~= nil then
			UpdateWindow( pCity );
		else
			UpdateWindow( GetCurrentCity() );
		end
	end
end
Events.SerialEventCityScreenDirty.Add( OnDirty );
Events.SerialEventCityInfoDirty.Add( OnDirty );
Events.SerialEventGameDataDirty.Add( OnDirty );
Events.SerialEventUnitInfoDirty.Add( OnDirty );
Events.UnitSelectionChanged.Add( OnDirty );
Events.UnitGarrison.Add( OnDirty );
Events.UnitEmbark.Add( OnDirty );
LuaEvents.CityQueueDirty.Add( OnDirty );	-- ??TRON attempt to fix queue size issue


function OnCityDestroyed(hexPos, playerID, cityID, newPlayerID)
	if not bHidden then
		if playerID == g_currentOwnerID and cityID == g_currentCityID then
			OnClose();
		end
	end	
end
Events.SerialEventCityDestroyed.Add(OnCityDestroyed);
Events.SerialEventCityCaptured.Add(OnCityDestroyed);


function GetProdHelp( void1, void2, button )
	local searchString = listOfStrings[tostring(button)];
	Events.SearchForPediaEntry( searchString );		
end


local defaultErrorTextureSheet = "TechAtlasSmall.dds";
local nullOffset = Vector2( 0, 0 );

----------------------------------------------------------------        
-- Add a button based on the item info
----------------------------------------------------------------        
function AddProductionButton( id, description, orderType, turnsLeft, column, isDisabled, ePurchaseYield )	
	local controlTable;
	
	local pCity = GetCurrentCity();
	if (pCity == nil) then
		return;
	end
	local abAdvisorRecommends = {false, false, false, false};
	local iUnit = -1;
	local iBuilding = -1;
	local iProject = -1;
	local iProcess = -1;
	
	if column == 1 then -- we are a unit
		iUnit = id;
		controlTable = g_UnitInstanceManager:GetInstance();
		local thisUnitInfo = GameInfo.Units[id];
		
		-- Portrait
		local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(id, pCity:GetOwner());
		local textureOffset, textureSheet = IconLookup( portraitOffset, 45, portraitAtlas );				
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end				
		controlTable.ProductionButtonImage:SetTexture(textureSheet);
		controlTable.ProductionButtonImage:SetTextureOffset(textureOffset);
		
		-- Tooltip
		local bIncludeRequirementsInfo = false;
		local strToolTip = Locale.ConvertTextKey(GetHelpTextForUnit(id, bIncludeRequirementsInfo));
		
		-- Disabled help text
		if (isDisabled) then
			if (g_IsProductionMode) then
				local strDisabledInfo = pCity:CanTrainTooltip(id);
				if (strDisabledInfo ~= nil and strDisabledInfo ~= "") then
					strToolTip = strToolTip .. "[NEWLINE][COLOR_WARNING_TEXT]" .. strDisabledInfo .. "[ENDCOLOR]";
				end
			else
				local strDisabledInfo;
				if (ePurchaseYield == YieldTypes.YIELD_ENERGY) then
					strDisabledInfo = pCity:GetPurchaseUnitTooltip(id);
				end
				if (strDisabledInfo ~= nil and strDisabledInfo ~= "") then
					strToolTip = strToolTip .. "[NEWLINE][COLOR_WARNING_TEXT]" .. strDisabledInfo .. "[ENDCOLOR]";
				end
			end
		end
		
		controlTable.Button:SetToolTipString(strToolTip);
		
	elseif column == 2 or column == 3 then -- we are a building, wonder, or project
		
		if column == 2 then
			controlTable = g_BuildingInstanceManager:GetInstance();
		elseif column == 3 then
			controlTable = g_WonderInstanceManager:GetInstance();
		end
		
		local thisInfo;
		
		local strToolTip = "";
		
		if orderType == OrderTypes.ORDER_MAINTAIN then
			print("SCRIPTING ERROR: Got a Process when a Building was expected");
		else
			local bBuilding : boolean;

			if orderType == OrderTypes.ORDER_CREATE then
				bBuilding = false;
				thisInfo = GameInfo.Projects[id];
				iProject = id;
				g_IsPlotChoiceProject = thisInfo.PlotProject;
			elseif orderType == OrderTypes.ORDER_CONSTRUCT then
				bBuilding = true;
				thisInfo = GameInfo.Buildings[id];
				iBuilding = id;
			end
			
			local textureOffset, textureSheet = IconLookup( thisInfo.PortraitIndex, 45, thisInfo.IconAtlas );				
			if textureOffset == nil then
				textureSheet = defaultErrorTextureSheet;
				textureOffset = nullOffset;
			end				
			controlTable.ProductionButtonImage:SetTexture(textureSheet);
			controlTable.ProductionButtonImage:SetTextureOffset(textureOffset);
			
			-- Tooltip
			local strStats = "";
			if (bBuilding) then
				local bExcludeName = false;
				local bExcludeHeader = false;
				strToolTip	= GetHelpTextForBuilding(id, bExcludeName, bExcludeHeader, false, pCity);
				strStats	= GetUIIconsForBuilding( id, pCity, false );
			else
				local bIncludeRequirementsInfo = false;
				strToolTip	= GetHelpTextForProject(id, bIncludeRequirementsInfo);
				strStats	= GetUIIconsForProject( id, pCity, false );
			end

			-- Stats			
			controlTable.UnitStats:SetText( strStats );

			
			-- Disabled help text
			if (isDisabled) then
				local strDisabledInfo;
				if (g_IsProductionMode) then
					if (bBuilding) then
						strDisabledInfo = pCity:CanConstructTooltip(id);
					else
						strDisabledInfo = pCity:CanCreateTooltip(id);					
					end
				else
					if (ePurchaseYield == YieldTypes.YIELD_ENERGY) then
						strDisabledInfo = pCity:GetPurchaseBuildingTooltip(id);
					end
				end

				if (strDisabledInfo ~= nil and strDisabledInfo ~= "") then
					strToolTip = strToolTip .. "[NEWLINE][COLOR_WARNING_TEXT]" .. strDisabledInfo .. "[ENDCOLOR]";
				end
			end
			
		end

		controlTable.Button:SetToolTipString(strToolTip);
		
	elseif column == 4 then -- processes
		
		iProcess = id;
		controlTable = g_ProcessInstanceManager:GetInstance();
		local thisProcessInfo = GameInfo.Processes[id];
		
		-- Portrait
		local textureOffset, textureSheet = IconLookup( thisProcessInfo.PortraitIndex, 45, thisProcessInfo.IconAtlas );
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end				
		controlTable.ProductionButtonImage:SetTexture(textureSheet);
		controlTable.ProductionButtonImage:SetTextureOffset(textureOffset);
		
		-- Tooltip
		local bIncludeRequirementsInfo = false;
		local strToolTip = Locale.ConvertTextKey(GetHelpTextForProcess(id, bIncludeRequirementsInfo));
		
		-- Disabled help text
		if (isDisabled) then
			
		end
		
		controlTable.Button:SetToolTipString(strToolTip);
		
	else
		return
	end
    
    local nameString = Locale.ConvertTextKey( description );
    
    listOfStrings[tostring(controlTable.InvisibleCivilopediaButton)] = nameString;
    
    controlTable.UnitName:SetText( Locale.ToUpper(nameString) );
	turnsLeft = Locale.ToUpper(turnsLeft);
    if g_IsProductionMode then
		controlTable.NumTurns:SetText(turnsLeft);
	else
		if (ePurchaseYield == YieldTypes.YIELD_ENERGY) then
			controlTable.NumTurns:SetText( turnsLeft.." [ICON_ENERGY]" );
		else
			controlTable.NumTurns:SetText( turnsLeft.." [ICON_PEACE]" );
		end
	end

	local hasCivilopediaArticle = true;
	local ePurchaseEnum;
	if g_IsProductionMode then
		if (orderType == OrderTypes.ORDER_TRAIN) then
			ePurchaseEnum = g_CONSTRUCT_UNIT;
		elseif (orderType == OrderTypes.ORDER_CONSTRUCT) then
			ePurchaseEnum = g_CONSTRUCT_BUILDING;
		elseif (orderType == OrderTypes.ORDER_CREATE) then
			ePurchaseEnum = g_CONSTRUCT_PROJECT;
		elseif (orderType == OrderTypes.ORDER_MAINTAIN) then
			ePurchaseEnum = g_MAINTAIN_PROCESS;		-- if this is removed, projects stop working! Use another bool to track if there is a civ article.
			hasCivilopediaArticle = false;
		end
	else
		if (orderType == OrderTypes.ORDER_TRAIN) then
			ePurchaseEnum = g_PURCHASE_UNIT_ENERGY;
		elseif (orderType == OrderTypes.ORDER_CONSTRUCT) then
			ePurchaseEnum = g_PURCHASE_BUILDING_ENERGY;
		elseif (orderType == OrderTypes.ORDER_CREATE) then
			ePurchaseEnum = g_PURCHASE_PROJECT_ENERGY;
		elseif (orderType == OrderTypes.ORDER_MAINTAIN) then
			print("SCRIPTING ERROR: Processes are not allowed to be purchased");
		end
	end
	
	-- Need a 2nd (invisible) Civilopedia button since setting disabled on the actual
	-- production button will stop right-clicks as well as left-clicks
	-- If no article is associated with it, clear the callbacks.
	if( hasCivilopediaArticle ) then
		controlTable.InvisibleCivilopediaButton:SetVoid1( ePurchaseEnum );
		controlTable.InvisibleCivilopediaButton:SetVoid2( id );
		controlTable.InvisibleCivilopediaButton:RegisterCallback( Mouse.eRClick, GetProdHelp );
	else
		controlTable.InvisibleCivilopediaButton:ClearCallback(Mouse.eRClick);
	end

    controlTable.Button:SetVoid1( ePurchaseEnum );
    controlTable.Button:SetVoid2( id );

	controlTable.Button:RegisterCallback( Mouse.eLClick, ProductionSelected );       
    controlTable.Button:SetDisabled( isDisabled );
    if( isDisabled )
    then
        controlTable.Button:SetAlpha( 0.4 );
    else
        controlTable.Button:SetAlpha( 1.0 );
    end
    
    if (iUnit >= 0) then
		for iAdvisorLoop = 0, AdvisorTypes.NUM_ADVISOR_TYPES - 1, 1 do
			abAdvisorRecommends[iAdvisorLoop] = Game.IsUnitRecommended(iUnit, iAdvisorLoop);
		end
    elseif (iBuilding >= 0) then
		for iAdvisorLoop = 0, AdvisorTypes.NUM_ADVISOR_TYPES - 1, 1 do
			abAdvisorRecommends[iAdvisorLoop] = Game.IsBuildingRecommended(iBuilding, iAdvisorLoop);
		end
    elseif (iProject >= 0) then
		for iAdvisorLoop = 0, AdvisorTypes.NUM_ADVISOR_TYPES - 1, 1 do
			abAdvisorRecommends[iAdvisorLoop] = Game.IsProjectRecommended(iProject, iAdvisorLoop);
		end    
    elseif (iProcess >= 0) then
		-- Advisors will not recommend Processes
    end

    for iAdvisorLoop = 0, AdvisorTypes.NUM_ADVISOR_TYPES - 1, 1 do
		local pControl = nil;
		if (iAdvisorLoop == AdvisorTypes.ADVISOR_ECONOMIC) then			
			pControl = controlTable.EconomicRecommendation;
		elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_MILITARY) then
			pControl = controlTable.MilitaryRecommendation;			
		elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_SCIENCE) then
			pControl = controlTable.ScienceRecommendation;
		elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_CULTURE) then
			pControl = controlTable.CultureRecommendation;
		elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_GROWTH) then
			pControl = controlTable.GrowthRecommendation;
		end

		if (pControl) then
			pControl:SetHide(not abAdvisorRecommends[iAdvisorLoop]);
		end
    end

	controlTable.RecommendationStack:ReprocessAnchoring();
	controlTable.RecommendationStack:CalculateSize();

	controlTable.UnitName:SetTruncateWidth(g_UnitNameBaseTruncateWidth - controlTable.RecommendationStack:GetSizeX());
end


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnClose()
    --UIManager:DequeuePopup( ContextPtr );

	if UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	end	

	if ( g_PlotSelectButtonIM ~= nil ) then
		g_PlotSelectButtonIM:DestroyInstances();
	end
	
	g_currentCityOwnerID = -1;
	g_currentCityID = -1;
    ContextPtr:SetHide( true );
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnClose );
Events.SerialEventExitCityScreen.Add( OnClose );



----------------------------------------------------------------        
-- Input processing
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose();
            return true;
 		--elseif wParam == Keys.VK_LEFT then
			--Game.DoControl(GameInfoTypes.CONTROL_PREVCITY);
			--return true;
		--elseif wParam == Keys.VK_RIGHT then
			--Game.DoControl(GameInfoTypes.CONTROL_NEXTCITY);
			--return true;
		end
    end
end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

    if( not bInitState ) then
        if( not bIsHide ) then
	       	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
        else
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_CHOOSEPRODUCTION, 0);
        end
        bHidden = bIsHide;
        LuaEvents.ProductionPopup( bIsHide );
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged()
	if (not ContextPtr:IsHidden()) then
		OnClose();
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);


-------------------------------------------------------------------------------
function DoProjectPlotSelection( eOrder, iData, projectInfo )	
	
	local textureOffset, textureSheet = IconLookup( projectInfo.PortraitIndex, 64, projectInfo.IconAtlas );				
	if textureOffset == nil then
		textureSheet = defaultErrorTextureSheet;
		textureOffset = nullOffset;
	end				

	local pCity = GetCurrentCity();
	local WorldPositionOffset = { x = 0, y = 35, z = 0 };
	g_PlotSelectButtonIM:ResetInstances();
	g_PlotProjectData = {
		Order = eOrder,
		Data = iData,
	};

	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION);

	-- Get the list of wonder plots
	local aWonderPlots = {pCity:GetWonderPlotsList()};

	-- Do selection buttons
	for i = 1, #aWonderPlots, 1 do
		local plot = aWonderPlots[i];
		if (plot ~= nil) then
			local hexPos = ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) );
			local worldPos = HexToWorld( hexPos );
			if (pCity:CanPlaceWonderAt(plot:GetX(), plot:GetY())) then

				local controlTable = g_PlotSelectButtonIM:GetInstance();						
				controlTable.PlotSelectButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
				controlTable.PlotSelectAnchoredButton:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_PLACE_WONDER_HERE") );
				--controlTable.PlotSelectAnchoredButton:SetText( "Select" );
				controlTable.PlotSelectAnchoredButton:SetVoid1( plot:GetPlotIndex() );
				controlTable.PlotSelectAnchoredButton:RegisterCallback( Mouse.eLCLick, OnPlotSelectedForProject);
				controlTable.WonderIcon:SetTexture(textureSheet);
				controlTable.WonderIcon:SetTextureOffset(textureOffset);	
			end
		end
	end
	
end

-- ===========================================================================
function OnPlotSelectedForProject( plotIndex )

	if not Players[Game.GetActivePlayer()]:IsTurnActive() then
		return;
	end
	
	local activePlayerID = Game.GetActivePlayer();
	local pCity = GetCurrentCity();
	if pCity then
		local pPlot = Map.GetPlotByIndex(plotIndex);
		local eOrder = g_PlotProjectData.Order;
		local iData = g_PlotProjectData.Data;

		local popupInfo = {
			Type = ButtonPopupTypes.BUTTONPOPUP_CHOOSE_PLOT_PROJECT_SITE,
			Data1 = plotIndex,
			Data2 = eOrder,
			Data3 = iData,
			Data4 = pCity:GetPlotIndex(),
		}
		Events.SerialEventGameMessagePopup(popupInfo);

		-- Plot Projects must be at the front of the queue.  Since we don't know if there are any
		-- other placed wonders in the queue already, we have to assume there might be and clear the queue as well.
	end

	OnClose();
end


-- ===========================================================================
--	Obtain a string containing icon specifiers for what the building produces
--
--	iBuildingID,		ID of building
--	pCity,				City Object
--	isShowingAmount,	If true, a look up string that (should) accept a #
--						will be used in concating the string, otherwise just
--						an icon will be added per yield to the string.
-- ===========================================================================
function GetUIIconsForBuilding( iBuildingID, pCity, isShowingAmt )

	local strBuildingStats	= "";
	local pActivePlayer		= Players[Game.GetActivePlayer()];
	local pActiveTeam		= Teams[Game.GetActiveTeam()];
	local pBuildingInfo		= GameInfo.Buildings[iBuildingID];
	local buildingClass		= GameInfo.Buildings[iBuildingID].BuildingClass;
	local buildingClassID	= GameInfo.BuildingClasses[buildingClass].ID;
	local lines				= {};

	----------------------------------------
	-- STANDARD YIELDS
	for yieldInfo in GameInfo.Yields() do
		local eYield = yieldInfo.ID;

		-- FLAT Yield from the building
		local iFlatYield = Game.GetBuildingYieldChange(iBuildingID, eYield);
		if (pCity ~= nil) then
			iFlatYield = iFlatYield + pCity:GetReligionBuildingClassYieldChange(buildingClassID, eYield) + pActivePlayer:GetPlayerBuildingClassYieldChange(buildingClassID, eYield);
			iFlatYield = iFlatYield + pCity:GetLeagueBuildingClassYieldChange(buildingClassID, eYield);
		end
		if (iFlatYield ~= nil and iFlatYield ~= 0) then
			if isShowingAmt then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD", yieldInfo.IconString, iFlatYield));
			else
				table.insert(lines, yieldInfo.IconString );
			end
		end

		-- MOD Yield from the building
		local iModYield = Game.GetBuildingYieldModifier(iBuildingID, eYield);
		iModYield = iModYield + pActivePlayer:GetPolicyBuildingClassYieldModifier(buildingClassID, eYield);
		if (iModYield ~= nil and iModYield ~= 0) then
			if isShowingAmt then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD_MOD", yieldInfo.IconString, yieldInfo.Description, iModYield));
			else
				table.insert(lines, yieldInfo.IconString );
			end
		end
	end

	-- HEALTH
	local iHealthTotal = 0;
	local iHealth = pBuildingInfo.Health;
	if (iHealth ~= nil) then
		iHealthTotal = iHealthTotal + iHealth;
	end
	if(pBuildingInfo.Unmoddedhealth ~= nil) then
		local iHealth = pBuildingInfo.UnmoddedHealth;
		if (iHealth ~= nil) then
			iHealthTotal = iHealthTotal + iHealth;
		end
	end
	iHealthTotal = iHealthTotal + pActivePlayer:GetExtraBuildingHealthFromPolicies(iBuildingID);
	if (iHealthTotal ~= 0) then
		if isShowingAmt then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_HEALTH_TT", iHealthTotal));
		else
			table.insert(lines, "[ICON_HEALTH_1]");
		end
	end

	local iHealthMod = pBuildingInfo.HealthModifier;
	if (iHealthMod ~= nil and iHealthMod ~= 0) then
		if isShowingAmt then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_TOOLTIP_POSITIVE_YIELD_MOD", HEALTH_ICON, "TXT_KEY_HEALTH", iHealthMod));
		else
			table.insert(lines, Locale.ConvertTextKey("[ICON_HEALTH]"));
		end
	end
	
	-- City Defense
	local iDefense = pBuildingInfo.Defense;
	if (iDefense ~= nil and iDefense ~= 0) then
		if isShowingAmt then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_DEFENSE_TT", iDefense / 100));
		else
			table.insert(lines, "[ICON_STRENGTH]");
		end
	end
	
	-- City Hit Points
	local iHitPoints = pBuildingInfo.ExtraCityHitPoints;
	if (iHitPoints ~= nil and iHitPoints ~= 0) then
		if isShowingAmt then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_HITPOINTS_TT", iHitPoints));
		else
			table.insert(lines, "[ICON_STRENGTH]");
		end
	end

	-- If there are standard yields to add
	if #lines > 0 then
		strBuildingStats = strBuildingStats .. table.concat(lines, " ");
	end

	return strBuildingStats;
end

-- ===========================================================================
--
-- ===========================================================================
function GetUIIconsForWonder( iWonderID, pCity, isShowingAmt )
	return GetUIIconsForBuilding( iWonderID, pCity, isShowingAmt );
end

-- ===========================================================================
--	
-- ===========================================================================
function GetUIIconsForProject( iProjectID, pCity, isShowingAmt )
	-- Projects do not (presently) have the ability to offer yields. If that changes,
	--	ensure this method is updated to reflect their data.
	return "";
end


-- ===========================================================================
--	Is a building a wonder
--	RETURNS: true if so
-- ===========================================================================
function IsWonder( building )
	local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
	if thisBuildingClass.MaxGlobalInstances > 0 or (thisBuildingClass.MaxPlayerInstances == 1 and building.SpecialistCount == 0) or thisBuildingClass.MaxTeamInstances > 0 then
		return true;
	end
	return false;	
end


-- ===========================================================================
--	Listen in on notications about completed production and cache result
--
--	Details:
--	Civ5 didn't cache last object created and so the only way to get the
--	information was from the notificaiton on an object being completed.
--	So if the production popup was raised from the notification, the last
--	completed item was shown; otherwise it was blank.
-- ===========================================================================
function OnNotificationAdded( Id, type, toolTip, strSummary, iGameValue, iExtraGameData, ePlayer, x, y )
		
	if(type == NotificationTypes.NOTIFICATION_PRODUCTION) then	
		--print("Production Completed: ",Id,type,toolTip,strSummary,iGameValue,iExtraGameData,ePlayer,x,y);  --debug
		local cachedCompletedEntry			= {};
		cachedCompletedEntry.x				= x;
		cachedCompletedEntry.y				= y;
		cachedCompletedEntry.orderType		= iGameValue;
		cachedCompletedEntry.productionId	= iExtraGameData;

		table.insert( m_cachedCompletedEntries, cachedCompletedEntry);	  
	end
	
end
Events.NotificationAdded.Add( OnNotificationAdded );



-- ===========================================================================
function OnPlayerProcessingTurnEnd( )
	m_cachedCompletedEntries = {};
end
Events.PlayerProcessingTurnEnd.Add(OnPlayerProcessingTurnEnd);



-- ===========================================================================
--	May have to be lazy initialized as a child of another LUA context
--	and LookUp doesn't always succeed while initial loading.
-- ===========================================================================
function Initialize()
	local containerControl = ContextPtr:LookUpControl("/InGame/GenericWorldAnchor/PlotButtonContainer");
	if ( containerControl ~= nil ) then
		g_PlotSelectButtonIM = InstanceManager:new( "PlotSelectButtonInstance", "PlotSelectButtonAnchor", containerControl );
	end
	UI.RebroadcastNotifications();
end
Initialize();