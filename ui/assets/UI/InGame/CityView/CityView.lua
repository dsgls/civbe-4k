-- ===========================================================================
--
--	City View
--
-- ===========================================================================

-- ===========================================================================
--	Includes
-- ===========================================================================

include( "IconSupport" );
include( "InstanceManager" );
include( "SupportFunctions"  );
include( "TutorialPopupScreen" );
include( "InfoTooltipInclude" );
include( "IntrigueHelper" );


-- ===========================================================================
--	Constants
-- ===========================================================================

local ART_INTRIGUE_WIDTH					= 102;
local ART_INTRIGUE_HEIGHT					= 24;
local ART_HEIGHT_PRODUCTION_PANEL_CLOSED	= 66;
local ART_HEIGHT_PRODUCTION_PANEL_OPEN		= 600;
local ART_HEIGHT_AROUND_BUILDINGS_PANEL		= 270;	
local MAX_QUEUE_ITEMS						= 6;
local COLOR_FOCUS_GLOW_NONE					= 0x00000000;
local COLOR_FOCUS_GLOW_CULTURE				= 0xee9B3D81;
local COLOR_FOCUS_GLOW_PRODUCTION			= 0xee205CC3;
local COLOR_FOCUS_GLOW_FOOD					= 0xee179C6B;
local COLOR_FOCUS_GLOW_ENERGY				= 0xee2be7e9;
local COLOR_FOCUS_GLOW_SCIENCE				= 0xeeCA9943;
local COLOR_FOCUS_GLOW_UNKNOWN				= 0xcc0000ff;
local COLOR_HEALTH_GOOD						= 0xff00ff00;
local COLOR_HEALTH_BAD						= 0xff0000ff;
local COLOR_HEALTH_NEUTRAL					= 0xff707070;

local WorldPositionOffset					= { x = 0, y = 0, z = 30 };
local WorldPositionOffset2					= { x = 0, y = -22, z = 0 };


-- ===========================================================================
--	Members
-- ===========================================================================

local g_BuildingIM		= InstanceManager:new( "BuildingInstance",				"BuildingButton",		Controls.BuildingStack );
local g_NoBuildingIM	= InstanceManager:new( "NoBuildingInstance",			"NothingBox",		Controls.BuildingStack );
local g_PlotButtonIM	= InstanceManager:new( "PlotButtonInstance",			"PlotButtonAnchor",		Controls.PlotButtonContainer );
local g_BuyPlotButtonIM = InstanceManager:new( "BuyPlotButtonInstance",			"BuyPlotButtonAnchor",	Controls.PlotButtonContainer );

local workerHeadingOpen					= OptionsManager.IsNoCitizenWarning();
local m_isImprovementProjectsHeadingOpen= true;
local m_isWonderHeadingOpen				= true;
local m_isBuildingHeadingOpen			= true;
local m_isSpecialistsHeadingOpen		= true;
local g_isCityContentsListOpen			= false;
local g_isProductionQueueOpen			= false;
local screenSizeX, screenSizeY			= UIManager:GetScreenSizeVal();
local pediaSearchStrings				= {};
local m_uiSpecialistStackCache			= {};

local g_iBuildingToSell = -1;

local g_bRazeButtonDisabled = false;

-- Add any interface modes that need special processing to this table
local InterfaceModeMessageHandler = 
{
	[InterfaceModeTypes.INTERFACEMODE_SELECTION] = {},
	[InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT] = {},
	[InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION] = {}
}
-------------------------------------------------
-- Clear out the UI so that when a player changes
-- the next update doesn't show the previous player's
-- values for a frame
-------------------------------------------------
function ClearCityUIInfo()

	Controls.b1box:SetHide( true );
	Controls.b2box:SetHide( true );
	Controls.b3box:SetHide( true );
	Controls.b4box:SetHide( true );
	Controls.b5box:SetHide( true );
	Controls.b6box:SetHide( true );

end

-- Apply a color to a control
function RefreshColoredItem(item : table, color : number)
	if (item ~= nil) then
		item:SetColor(color);
	end
end

-- Refresh all the items that are using PlayerColor1.  That color is volatile in a Hotseat game.
function RefreshPlayerColoredItems()

	local playerColorIndex = PreGame.GetCivilizationColor( Game.GetActivePlayer() );
	local playerColorSet = GameInfo.PlayerColors[playerColorIndex];
	if (playerColorSet ~= nil) then
		local primaryColor = GameInfo.Colors[playerColorSet.PrimaryColor];
		local secondaryColor = GameInfo.Colors[playerColorSet.SecondaryColor];
		if (primaryColor ~= nil and secondaryColor ~= nil) then

			local primaryColorVector		= Vector4( primaryColor.Red, primaryColor.Green, primaryColor.Blue, 1.0 );
			local colorValue = RGBAObjectToABGRHex( primaryColorVector );

			RefreshColoredItem(Controls.CityCapitalIcon, colorValue);
			RefreshColoredItem(Controls.CityPopulation, colorValue);
			RefreshColoredItem(Controls.GrowthBar, colorValue);
			RefreshColoredItem(Controls.GrowthBarShadow, colorValue);
			RefreshColoredItem(Controls.CityNameTitleBarLabel, colorValue);
			RefreshColoredItem(Controls.ProductionBar, colorValue);
			RefreshColoredItem(Controls.ProductionBarShadow, colorValue);

			RefreshColoredItem(Controls.CityBannerLeftBackground, colorValue);
			RefreshColoredItem(Controls.CityBannerBackgroundLeftIn, colorValue);
			RefreshColoredItem(Controls.TurnsUntilNewCitizen, colorValue);
			RefreshColoredItem(Controls.CitizensLabel, colorValue);
			RefreshColoredItem(Controls.CityBannerBackground, colorValue);
			RefreshColoredItem(Controls.PrevCityButton, colorValue);
			RefreshColoredItem(Controls.NextCityButton, colorValue);
			RefreshColoredItem(Controls.CityBannerBackgroundRightIn, colorValue);
			RefreshColoredItem(Controls.ProductionTurnsLabel, colorValue);
			RefreshColoredItem(Controls.ProductionItemName, colorValue);
			RefreshColoredItem(Controls.CityBannerRightBackground, colorValue);
			RefreshColoredItem(Controls.CityBannerProductionImage, colorValue);
			RefreshColoredItem(Controls.TradeRoutesIcon, colorValue);
			RefreshColoredItem(Controls.TradeRoutes, colorValue);
			RefreshColoredItem(Controls.ShieldIcon, colorValue);
			RefreshColoredItem(Controls.Defense, colorValue);

			local secondaryColorVector		= Vector4( secondaryColor.Red, secondaryColor.Green, secondaryColor.Blue, 1.0 );
			local colorValue = RGBAObjectToABGRHex( secondaryColorVector );

			RefreshColoredItem(Controls.PrevCityBackground, colorValue);
			RefreshColoredItem(Controls.NextCityBackground, colorValue);
			RefreshColoredItem(Controls.CityBannerStrengthFrame, colorValue);	
			
			RefreshColoredItem(Controls.CityBannerButtonBaseLeft, colorValue);	
			RefreshColoredItem(Controls.CityBannerButtonBaseLeftIn, colorValue);	
			RefreshColoredItem(Controls.CityBannerButtonBase, colorValue);	
			RefreshColoredItem(Controls.CityBannerButtonBaseRightIn, colorValue);	
			RefreshColoredItem(Controls.CityBannerButtonBaseRight, colorValue);		
		end
	end

	-- Potential exceptions

	local city = UI.GetHeadSelectedCity();
	if city ~= nil then
		if ( city:GetProductionProcess() ~= -1 ) then
			CityBannerProductionImage:SetColor( 0xffffffff );
		end
	end

end
-----------------------------------------------------------------
-- CITY SCREEN CLOSED
-----------------------------------------------------------------
function CityScreenClosed()
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	OnCityViewUpdate();

	-- We may get here after a player change, clear the UI if this is not the active player's city
	local city = UI.GetHeadSelectedCity();
	if city ~= nil then
		if city:GetOwner() ~= Game.GetActivePlayer() then
			ClearCityUIInfo();
		end
	end
	UI.ClearSelectedCities();
	
	LuaEvents.TryDismissTutorial("CITY_SCREEN");
	
	g_iCurrentSpecialist = -1;
	if (not Controls.SellBuildingConfirm:IsHidden()) then 
		Controls.SellBuildingConfirm:SetHide(true);
	end
	g_iBuildingToSell = -1;
		
	Controls.RazeCityButton:SetHide(true);

	-- Try and re-select the last unit selected		
	if (UI.GetHeadSelectedUnit() == nil and UI.GetLastSelectedUnit() ~= nil) then
		UI.SelectUnit(UI.GetLastSelectedUnit());
		UI.LookAtSelectionPlot();		
	end
	
	UI.SetCityScreenViewingMode(false);
end
Events.SerialEventExitCityScreen.Add(CityScreenClosed);

local DefaultMessageHandler = {};

DefaultMessageHandler[KeyEvents.KeyDown] =
function( wParam, lParam )
	
	local interfaceMode = UI.GetInterfaceMode();
	if (interfaceMode == InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION ) then
		if ( wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN ) then
			--UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			return true;
		end	
	else
		if ( wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN ) then

			if(not Controls.CityConfirmPlotPurchase:IsHidden())then
				Controls.CityConfirmPlotPurchase:SetHide(true);
				return true;
			elseif(Controls.SellBuildingConfirm:IsHidden())then
				--CloseScreen();
				Events.SerialEventExitCityScreen();
				return true;
			else
				Controls.SellBuildingConfirm:SetHide(true);
				g_iBuildingToSell = -1;
				return true;
			end
		elseif wParam == Keys.VK_LEFT then
			Game.DoControl(GameInfoTypes.CONTROL_PREVCITY);
			return true;
		elseif wParam == Keys.VK_RIGHT then
			Game.DoControl(GameInfoTypes.CONTROL_NEXTCITY);
			return true;
		end
	end
	
    return false;
end


InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.LButtonDown] = 
function( wParam, lParam )	
	if GameDefines.CITY_SCREEN_CLICK_WILL_EXIT == 1 then
		UI.ClearSelectedCities();
		return true;
	end

	return false;
end


----------------------------------------------------------------        
----------------------------------------------------------------        
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT][MouseEvents.RButtonUp] = 
function( wParam, lParam )
	--UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION][MouseEvents.RButtonUp] = 
function( wParam, lParam )
	--UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end


----------------------------------------------------------------        
-- Input handling 
-- (this may be overkill for now because there is currently only 
-- one InterfaceMode on this display, but if we add some, which we did...)
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )

	--[[ ??TRON: Use R to fast reload		
	if ( uiMsg == 2 and wParam == 114 ) then
		OnCityViewUpdate();
		return true;
	end
	--]]

	local interfaceMode = UI.GetInterfaceMode();
	local currentInterfaceModeHandler = InterfaceModeMessageHandler[interfaceMode];
	if currentInterfaceModeHandler and currentInterfaceModeHandler[uiMsg] then
		return currentInterfaceModeHandler[uiMsg]( wParam, lParam );
	elseif DefaultMessageHandler[uiMsg] then
		return DefaultMessageHandler[uiMsg]( wParam, lParam );
	end
	return false;
end
ContextPtr:SetInputHandler( InputHandler );


---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

local otherSortedList = {};
local sortOrder = 0;

function CVSortFunction( a, b )

    local aVal = otherSortedList[ tostring( a ) ];
    local bVal = otherSortedList[ tostring( b ) ];
    
    if (aVal == nil) or (bVal == nil) then 
		if aVal and (bVal == nil) then
			return false;
		elseif (aVal == nil) and bVal then
			return true;
		else
			return tostring(a) < tostring(b); -- gotta do something deterministic
        end;
    else
        return aVal < bVal;
    end
end

function OnSlackersSelected()
	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		local city = UI.GetHeadSelectedCity();
		if city ~= nil then
			Network.SendDoTask(city:GetID(), TaskTypes.TASK_REMOVE_SLACKER, 0, -1, false, bAlt, bShift, bCtrl);
		end
	end
end

function OnImprovementProjectsHeaderSelected()
	m_isImprovementProjectsHeadingOpen = not m_isImprovementProjectsHeadingOpen;
	OnCityViewUpdate();
end

function OnWondersHeaderSelected()
	m_isWonderHeadingOpen = not m_isWonderHeadingOpen;
	OnCityViewUpdate();
end

function OnBuildingsHeaderSelected()
	m_isBuildingHeadingOpen = not m_isBuildingHeadingOpen;
	OnCityViewUpdate();
end

function OnSpecialistsHeaderSelected()
	m_isSpecialistsHeadingOpen = not m_isSpecialistsHeadingOpen;
	OnCityViewUpdate();
end

function GetPedia( void1, void2, button )
	local searchString = pediaSearchStrings[tostring(button)];
	if (searchString ~= nil) then
		Events.SearchForPediaEntry( searchString );
	end
end

-------------------------------------------------
-------------------------------------------------
function OnEditNameClick()
	if UI.GetHeadSelectedCity() then
		local popupInfo = {
				Type = ButtonPopupTypes.BUTTONPOPUP_RENAME_CITY,
				Data1 = UI.GetHeadSelectedCity():GetID(),
				Data2 = -1,
				Data3 = -1,
				Option1 = false,
				Option2 = false;
			}
		Events.SerialEventGameMessagePopup(popupInfo);
	end
end
Controls.EditButton:RegisterCallback( Mouse.eLClick, OnEditNameClick );


-- ===========================================================================
--	Building / Wonder
-- ===========================================================================
function AddBuildingButton( city, building )
	local buildingID= building.ID;
	if (city:IsHasBuilding(buildingID)) then
		
		local controlTable = g_BuildingIM:GetInstance();

		sortOrder = sortOrder + 1;
		otherSortedList[tostring( controlTable.BuildingButton )] = sortOrder;
		
		if (city:GetNumFreeBuilding(buildingID) > 0) then
			bIsBuildingFree = true;
		else
			bIsBuildingFree = false;
		end
		
		-- Name
		local strBuildingName;
		
		-- Religious Buildings have special names
		--if (building.IsReligious) then
		--	strBuildingName = Locale.ConvertTextKey("TXT_KEY_RELIGIOUS_BUILDING", building.Description, pPlayer:GetStateReligionKey());
		--else
			strBuildingName = Locale.ConvertTextKey(building.Description);
		--end
		

		-- Building is free, add an asterisk to the name
		if (bIsBuildingFree) then
			strBuildingName = strBuildingName .. " (" .. Locale.ConvertTextKey("TXT_KEY_FREE") .. ")";
		end
				
		controlTable.BuildingName:SetText( Locale.ToUpper(strBuildingName));

		pediaSearchStrings[tostring(controlTable.BuildingButton)] = Locale.ConvertTextKey(building.Description);
		controlTable.BuildingButton:RegisterCallback( Mouse.eRClick, GetPedia );
				
		-- Portrait
		if IconHookup( building.PortraitIndex, 128, building.IconAtlas, controlTable.BuildingImage ) then
			controlTable.BuildingImage:SetHide( false );
		else
			controlTable.BuildingImage:SetHide( true );
		end

		-- Build stats/bonuses (most logic pulled from InfoToolTipInclude.lua)			
		local pCity				= city;
		local iActivePlayer		= Game.GetActivePlayer();
		local pActivePlayer		= Players[iActivePlayer];
		local pActiveTeam		= Teams[iActivePlayer];
		local pBuildingInfo		= GameInfo.Buildings[buildingID];
		local buildingClass		= GameInfo.Buildings[buildingID].BuildingClass;
		local buildingClassID	= GameInfo.BuildingClasses[buildingClass].ID;
		local lines				= {};
		local strBuildingStats	= "";

		-- Get the active perk types.  It is better to get this once and pass it around, rather than having each function re-get it every time.
		local activePerkTypes = pActivePlayer:GetAllActivePlayerPerkTypes();

		for yieldIndex, yieldInfo in ipairs(CachedYieldInfoArray) do
			local eYield = yieldInfo.ID;

			-- FLAT Yield from the building
			local iFlatYield = Game.GetBuildingYieldChange(buildingID, eYield);
			if (pCity ~= nil) then
				iFlatYield = iFlatYield + pCity:GetReligionBuildingClassYieldChange(buildingClassID, eYield) + pActivePlayer:GetPlayerBuildingClassYieldChange(buildingClassID, eYield);
				iFlatYield = iFlatYield + pCity:GetLeagueBuildingClassYieldChange(buildingClassID, eYield);
			end
			-- FLAT Yield changes from PLAYER PERKS
			local iFlatYieldFromPerks = GetPlayerPerkBuildingFlatYieldChanges(activePerkTypes, iActivePlayer, buildingID, eYield);
			iFlatYield = iFlatYield + iFlatYieldFromPerks;

			if (iFlatYield ~= nil and iFlatYield ~= 0) then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD", yieldInfo.IconString, iFlatYield));
			end

			-- MOD Yield from the building
			local iModYield = Game.GetBuildingYieldModifier(buildingID, eYield);
			-- MOD from Virtues
			iModYield = iModYield + pActivePlayer:GetPolicyBuildingClassYieldModifier(buildingClassID, eYield);
			-- MOD from Player Perks
			local iModYieldFromPerks = GetPlayerPerkBuildingPercentYieldChanges(activePerkTypes, iActivePlayer, buildingID, eYield);
			iModYield = iModYield + iModYieldFromPerks;

			if (iModYield ~= nil and iModYield ~= 0) then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD_MOD", yieldInfo.IconString, iModYield));
			end
		end
		
		-- FLAT Health
		local iHealthTotal = 0;
		local iHealth = pBuildingInfo.Health;
		if (iHealth ~= nil) then
			iHealthTotal = iHealthTotal + iHealth;
		end
		if(pBuildingInfo.UnmoddedHealth ~= nil) then
			local iHealth = pBuildingInfo.UnmoddedHealth;
			if (iHealth ~= nil) then
				iHealthTotal = iHealthTotal + iHealth;
			end
		end
		-- Health from Virtues
		iHealthTotal = iHealthTotal + pActivePlayer:GetExtraBuildingHealthFromPolicies(buildingID);
		-- Health from Player Perks
		local iHealthFromPerks = GetPlayerPerkBuildingFlatHealthChanges(activePerkTypes, iActivePlayer, buildingID);
		iHealthTotal = iHealthTotal + iHealthFromPerks;

		if (iHealthTotal ~= 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_HEALTH", iHealthTotal));
		end

		-- MOD Health
		local iHealthMod = pBuildingInfo.HealthModifier;
		-- MOD from Player Perks
		local iHealthModFromPerks = GetPlayerPerkBuildingPercentHealthChanges(activePerkTypes, iActivePlayer, buildingID);
		iHealthMod = iHealthMod + iHealthModFromPerks;

		if (iHealthMod ~= nil and iHealthMod ~= 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD_MOD", HEALTH_ICON, iHealthMod));
		end
	
		-- City Strength
		local iCityStrength = pBuildingInfo.Defense;
		-- City Strength from PLAYER PERKS
		local iCityStrengthFromPerks = GetPlayerPerkBuildingCityStrengthChanges(activePerkTypes, iActivePlayer, buildingID);
		if (iCityStrengthFromPerks ~= nil and iCityStrengthFromPerks ~= 0) then
			iCityStrength = iCityStrength + iCityStrengthFromPerks;
		end
		if (iCityStrength ~= nil and iCityStrength ~= 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_DEFENSE", iCityStrength / 100));
		end
	
		-- City Hit Points
		local iHitPoints = pBuildingInfo.ExtraCityHitPoints;
		-- City Hit Points from PLAYER PERKS
		local iCityHPFromPerks = GetPlayerPerkBuildingCityHPChanges(activePerkTypes, iActivePlayer, buildingID);
		if (iCityHPFromPerks ~= nil and iCityHPFromPerks ~= 0) then
			iHitPoints = iHitPoints + iCityHPFromPerks;
		end
		if (iHitPoints ~= nil and iHitPoints ~= 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_HITPOINTS", iHitPoints));
		end

		-- If there are standard yields to add
		if #lines > 0 then
			strBuildingStats = strBuildingStats .. table.concat(lines, "  ");
			lines = {};
		end

		controlTable.BuildingStats:SetString( strBuildingStats );


		-- Specialists

		if building.SpecialistType then

			local numAvailableSpecialists	= city:GetNumSpecialistsAllowedByBuilding(buildingID);
			local numAssignedSpecialists	= city:GetNumSpecialistsInBuilding(buildingID);
	
			if ( numAvailableSpecialists < 1 ) then
				print("ERROR: Building has a SpecialistType set but no room to set specialists! id: ", buildingID );
			end

			-- Add specialist slots, re-create even if they exist as this is a new controlTable instance.
			m_uiSpecialistStackCache[buildingID] = 
			{
				specialistsIM	= InstanceManager:new( "BuildingSpecialistsInstance", "Top", controlTable.SlotsStack ),
				slotsUsed		= {}
			};
			m_uiSpecialistStackCache[buildingID].specialistsIM:DestroyInstances();
			
						
			local TEXOFFSET_BACKING_NOSHADOW_EMPTY	= 128;
			local TEXOFFSET_BACKING_NOSHADOW_FILLED = 192;
			local TEXTURE_ICON_SIZE					= 45;
			local isViewCityOnly	= UI.IsCityScreenViewingMode();
			local iSpecialistID		= GameInfoTypes[building.SpecialistType];
			local pSpecialistInfo	= GameInfo.Specialists[iSpecialistID];
			local specialistName	= Locale.ConvertTextKey(pSpecialistInfo.Description);
			local toolTipString		= specialistName .. " ";			

			-- Culture add to ToolTip
			--local iCultureFromSpecialist = city:GetCultureFromSpecialist(iSpecialistID);
			--if (iCultureFromSpecialist > 0) then
			--	toolTipString = toolTipString .. " +" .. iCultureFromSpecialist .. " [ICON_CULTURE]";
			--end

			-- Yield add to ToolTip
			for yieldIndex, pYieldInfo in ipairs(CachedYieldInfoArray) do
				local iYieldID		= pYieldInfo.ID;
				local iYieldAmount	= city:GetSpecialistYield(iSpecialistID, iYieldID);				
				if (iYieldAmount > 0) then
					toolTipString = toolTipString .. " +" .. iYieldAmount .. " " .. pYieldInfo.IconString;
				end
			end

			-- Build slots based on # of specialists...

			-- Make sure nothing re-assigned a specialist out from under us.
			-- While the user is playing around, we are allowing them to use any slot, meaning
			-- if they have just one slot assigned in a building with two slots, we let then click in
			-- any slot.
			local iSeenActiveSlots = 0;
			for i, value in ipairs(m_uiSpecialistStackCache[buildingID].slotsUsed) do
				if (value ~= false) then
					iSeenActiveSlots = iSeenActiveSlots + 1;
					if (iSeenActiveSlots > numAssignedSpecialists) then
						m_uiSpecialistStackCache[buildingID].slotsUsed[i] = false;
					end
				end
			end

			for iSlot = 1, numAvailableSpecialists, 1 do
				local specialist = m_uiSpecialistStackCache[buildingID].specialistsIM:GetInstance();

				specialist.Backing:SetTextureOffsetVal( 0, TEXOFFSET_BACKING_NOSHADOW_EMPTY );
				specialist.Backing:SetToolTipString( toolTipString );

				-- Dynamically allocate
				if m_uiSpecialistStackCache[buildingID].slotsUsed[iSlot] == nil then					
					m_uiSpecialistStackCache[buildingID].slotsUsed[iSlot] = (iSlot <= numAssignedSpecialists);
				end

				-- Fill with citizen icon or empty?				
				if m_uiSpecialistStackCache[buildingID].slotsUsed[iSlot] then
					-- Filled slot
					IconHookup(	pSpecialistInfo.PortraitIndex, TEXTURE_ICON_SIZE, pSpecialistInfo.IconAtlas, specialist.Icon);
					specialist.Icon:SetHide( false );
					if ( not isViewCityOnly ) then
						specialist.Backing:SetVoid1( buildingID );
						specialist.Backing:SetVoid2( iSlot );
						specialist.Backing:RegisterCallback( Mouse.eLClick, OnRemoveSpecialist );
					end
				else 
					-- Empty slot
					specialist.Icon:SetHide( true );
					if ( not isViewCityOnly ) then
						specialist.Backing:SetVoid1( buildingID );
						specialist.Backing:SetVoid2( iSlot );
						specialist.Backing:RegisterCallback( Mouse.eLClick, OnAddSpecialist );
					end
				end

				pediaSearchStrings[tostring(specialist.Backing)] = specialistName;
				specialist.Backing:RegisterCallback( Mouse.eRClick, GetPedia );
			end
			controlTable.SlotsStack:CalculateSize();
		end


		-- If all the contents are taller than the icon, grow the box.
		local EXTRA_HEIGHT_PADDING	= 8;
		local totalHeight			= EXTRA_HEIGHT_PADDING;
		totalHeight					= totalHeight + controlTable.ContentStack:GetSizeY();

		if (totalHeight > controlTable.BuildingImage:GetSizeY() ) then
			controlTable.BuildingButton:SetSizeY( totalHeight );
		end

		-- Tool Tip
		local bExcludeHeader	= false;
		local bExcludeName		= false;
		local bNoMaintenance	= bIsBuildingFree;
		local strToolTip		= GetHelpTextForBuilding(buildingID, bExcludeName, bExcludeHeader, bNoMaintenance, city);

		-- Can we sell this thing?
		if (city:IsBuildingSellable(buildingID) and not city:IsPuppet()) then
			local sellValue = city:GetSellBuildingRefund(buildingID);
			local valueStr = " ([ICON_ENERGY] " .. tostring(sellValue) .. ")";
			
			strToolTip = strToolTip .. "[NEWLINE][NEWLINE][COLOR_YELLOW]" .. Locale.ConvertTextKey( "TXT_KEY_CLICK_TO_SELL" ) .. valueStr .. "[ENDCOLOR]";
			
			controlTable.BuildingButton:RegisterCallback( Mouse.eLClick, OnBuildingClicked );
			controlTable.BuildingButton:SetVoid1( buildingID );
		-- We have to clear the data out here or else the instance manager will recycle it in other cities!
		else
			controlTable.BuildingButton:ClearCallback(Mouse.eLClick);
			controlTable.BuildingButton:SetVoid1( -1 );
		end
		
		controlTable.BuildingButton:SetToolTipString(strToolTip);

		-- Viewing Mode only
		if (UI.IsCityScreenViewingMode()) then
			controlTable.BuildingButton:SetDisabled( true );
		else
			controlTable.BuildingButton:SetDisabled( false );
		end

	end		-- Does city have this building?
end


-- ===========================================================================
--	Adds an end-game, plot-based improvement project (as a Wonder)
-- ===========================================================================
function AddPlotProjectButton( city, project )
	
	local projectID		= project.ID;		
	local controlTable	= g_BuildingIM:GetInstance();
		
	sortOrder = sortOrder + 1;
	otherSortedList[tostring( controlTable.BuildingButton )] = sortOrder;
		
	-- Name
	local strBuildingName = Locale.ConvertTextKey(project.Description);	
	controlTable.BuildingName:SetText( Locale.ToUpper(strBuildingName) );

	-- Civilopedia callback
	pediaSearchStrings[tostring(controlTable.BuildingButton)] = Locale.ConvertTextKey(project.Description);
	controlTable.BuildingButton:RegisterCallback( Mouse.eRClick, GetPedia );
				
	-- Portrait
	if IconHookup( project.PortraitIndex, 128, project.IconAtlas, controlTable.BuildingImage ) then
		controlTable.BuildingImage:SetHide( false );
	else
		controlTable.BuildingImage:SetHide( true );
	end
		
	local strInfo = Locale.Lookup( project.Help);
	controlTable.BuildingStats:SetString( "" );

	-- If all the contents are taller than the icon, grow the box.
	local EXTRA_HEIGHT_PADDING	= 28;
	local totalHeight			= EXTRA_HEIGHT_PADDING;
	totalHeight					= totalHeight + controlTable.BuildingName:GetSizeY();
	totalHeight					= totalHeight + controlTable.BuildingStats:GetSizeY();
	totalHeight					= totalHeight + controlTable.SlotsStack:GetSizeY();
	if (totalHeight > controlTable.BuildingImage:GetSizeY() ) then
		controlTable.BuildingButton:SetSizeY( totalHeight );
	end		
	controlTable.SlotsStack:ReprocessAnchoring();
	controlTable.ContentStack:ReprocessAnchoring();

	local strToolTip = Locale.Lookup( project.Help);
	controlTable.BuildingButton:SetToolTipString(strToolTip);

	-- Viewing Mode only
	if (UI.IsCityScreenViewingMode()) then
		controlTable.BuildingButton:SetDisabled( true );
	else
		controlTable.BuildingButton:SetDisabled( false );
	end
end


-- ===========================================================================
--	Update production queue item
--	RETURNS: is maintained?
-- ===========================================================================
function UpdateThisQueuedItem(city, queuedItemNumber, queueLength)
	local buttonPrefix = "b"..tostring(queuedItemNumber);
	local queuedOrderType;
	local queuedData1;
	local queuedData2;
	local queuedSave;
	local queuedRush;
	local controlBox	= buttonPrefix.."box";
	local controlImage	= buttonPrefix.."image";
	local controlName	= buttonPrefix.."name";
	local controlTurns	= buttonPrefix.."turns";
	local isMaint = false;
	
	local strToolTip = "";
	
	local bGeneratingProduction = false;
	if (city:GetCurrentProductionDifferenceTimes100(false, false) > 0) then
		bGeneratingProduction = true;
	end
	
	Controls[controlTurns]:SetHide( false );
	queuedOrderType, queuedData1, queuedData2, queuedSave, queuedRush = city:GetOrderFromQueue( queuedItemNumber-1 );
    if (queuedOrderType == OrderTypes.ORDER_TRAIN) then
		local thisUnitInfo = GameInfo.Units[queuedData1];
		local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(queuedData1, city:GetOwner());
		IconHookup( portraitOffset, 45, portraitAtlas, Controls[controlImage] );
		local descriptionKey = GetUpgradedUnitDescriptionKey(Players[city:GetOwner()], thisUnitInfo.ID);
		Controls[controlName]:SetText( Locale.ToUpper( Locale.ConvertTextKey( descriptionKey )));
		if (bGeneratingProduction) then
			Controls[controlTurns]:SetText(Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_NUM_TURNS", city:GetUnitProductionTurnsLeft(queuedData1, queuedItemNumber-1) ) );
		else
			Controls[controlTurns]:SetText(Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_INFINITE_TURNS"));
		end
		
		strToolTip = Locale.ConvertTextKey(GetHelpTextForUnit(queuedData1, true));

    elseif (queuedOrderType == OrderTypes.ORDER_CONSTRUCT) then
		local thisBuildingInfo = GameInfo.Buildings[queuedData1];
		IconHookup( thisBuildingInfo.PortraitIndex, 45, thisBuildingInfo.IconAtlas, Controls[controlImage] );
		Controls[controlName]:SetText( Locale.ToUpper( Locale.ConvertTextKey( thisBuildingInfo.Description )));
		if (bGeneratingProduction) then
			Controls[controlTurns]:SetText(  Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_NUM_TURNS", city:GetBuildingProductionTurnsLeft(queuedData1, queuedItemNumber-1)) );
		else
			Controls[controlTurns]:SetText(Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_INFINITE_TURNS"));
		end
		
		strToolTip = Locale.ConvertTextKey(GetHelpTextForBuilding(queuedData1, false, false, false, nil));
	
    elseif (queuedOrderType == OrderTypes.ORDER_CREATE) then
		local thisProjectInfo = GameInfo.Projects[queuedData1];
		IconHookup( thisProjectInfo.PortraitIndex, 45, thisProjectInfo.IconAtlas, Controls[controlImage] );
		Controls[controlName]:SetText( Locale.ToUpper( Locale.ConvertTextKey( thisProjectInfo.Description )));
		if (bGeneratingProduction) then
			Controls[controlTurns]:SetText( Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_NUM_TURNS",city:GetProjectProductionTurnsLeft(queuedData1, queuedItemNumber-1)) );
		else
			Controls[controlTurns]:SetText(Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_INFINITE_TURNS"));
		end
		
		strToolTip = Locale.ConvertTextKey(GetHelpTextForProject(queuedData1, true));
	
    elseif (queuedOrderType == OrderTypes.ORDER_MAINTAIN) then
		isMaint = true;
 		local thisProcessInfo = GameInfo.Processes[queuedData1];
		IconHookup( thisProcessInfo.PortraitIndex, 45, thisProcessInfo.IconAtlas, Controls[controlImage] );
		Controls[controlName]:SetText( Locale.ToUpper( Locale.ConvertTextKey( thisProcessInfo.Description )));
		Controls[controlTurns]:SetHide( true );
		
		strToolTip = Locale.ConvertTextKey(GetHelpTextForProcess(queuedData1, true));

	else
		print("ERROR! Unknown queuedOrderType: ", queuedOrderType);
	end
   
	Controls[controlBox]:SetToolTipString(Locale.ConvertTextKey(strToolTip));
	return isMaint;
end



-- ===========================================================================
--	Triggered when the production queue changes and the stacks of the
--	queue itself and production list need to be resized.
-- ===========================================================================
function OnSpecificCityInfoDirty(iPlayerID, iCityID, eUpdateType)
	if (eUpdateType == CityUpdateTypes.CITY_UPDATE_TYPE_PRODUCTION) then
		OnCityViewUpdate();
	end
end


-- ===========================================================================
-- City View Update
-- ===========================================================================
function OnCityViewUpdate()

    if( ContextPtr:IsHidden() ) then
        return;
    end
        
	local city = UI.GetHeadSelectedCity();
	
	if (city == nil) then
		print("ERROR: No head selected city!");
		return;
	end

	CacheDatabaseQueries();

	pediaSearchStrings = {};

	Controls.EditButton:SetHide(false);
	Controls.PurchaseButton:SetDisabled(false);
--	Controls.EndTurnText:SetText(Locale.ConvertTextKey("TXT_KEY_CITYVIEW_RETURN_TO_MAP"));
		
	-------------------------------------------
	-- City Banner
	-------------------------------------------
	local pPlayer								= Players[city:GetOwner()];
	local isActiveTeamCity						= true;
	local iTurnsToNextGrowth					= city:GetFoodTurnsLeft();
	local primaryColorRaw, secondaryColorRaw	= pPlayer:GetPlayerColors();
	local primaryColorAlphaedRaw				= { x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 0.5 };
	local primaryColor 	 						= RGBAObjectToABGRHex( primaryColorRaw );
	local secondaryColor 						= RGBAObjectToABGRHex( secondaryColorRaw );	
	local primaryColorAlphaed 	 				= RGBAObjectToABGRHex( primaryColorAlphaedRaw );	

	-- Buttonify top
	Controls.ReturnToGameHugeBarButton	:RegisterCallback( Mouse.eLClick, function() Events.SerialEventExitCityScreen(); end );
		
	-- Update capital icon
	local isCapital = city:IsCapital();
	Controls.CityCapitalIcon:SetHide(not isCapital);
		
	-- Connected to capital?
	if (isActiveTeamCity) then
		if (not isCapital and pPlayer:IsCapitalConnectedToCity(city) and not city:IsBlockaded()) then
			Controls.ConnectedIcon:SetHide(false);
			Controls.ConnectedIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_CONNECTED");
		else
			Controls.ConnectedIcon:SetHide(true);
		end
	end
	
	-- Update population
	local cityPopulation = math.floor(city:GetPopulation());
	Controls.CityPopulation:SetText(cityPopulation);
	

	-------------------------------------------
	-- Growth Meter
	-------------------------------------------
	local iCurrentFood = city:GetFood();
	local iFoodNeeded = city:GrowthThreshold();
	local iFoodPerTurn = city:FoodDifference();
	local iCurrentFoodPlusThisTurn = iCurrentFood + iFoodPerTurn;
		
	local fGrowthProgressPercent = iCurrentFood / iFoodNeeded;
	local fGrowthProgressPlusThisTurnPercent = iCurrentFoodPlusThisTurn / iFoodNeeded;
	if (fGrowthProgressPlusThisTurnPercent > 1) then
		fGrowthProgressPlusThisTurnPercent = 1
	end
		
	SetCitizenGrowthBar( Controls.GrowthBar, Controls.GrowthBarShadow )	
	
	-- Stagnation/Starvation/New Citizen	
	if (city:IsFoodProduction() or city:FoodDifferenceTimes100() == 0) then
		Controls.TurnsUntilNewCitizen:SetText(Locale.ConvertTextKey("TXT_KEY_CITYVIEW_STAGNATION_TEXT"));
	elseif city:FoodDifference() < 0 then
		Controls.TurnsUntilNewCitizen:SetText(Locale.ConvertTextKey("TXT_KEY_CITYVIEW_STARVATION_TEXT"));
	else
		Controls.TurnsUntilNewCitizen:SetText(Locale.ConvertTextKey("TXT_KEY_CITYVIEW_TURNS_TILL_CITIZEN_TEXT", iTurnsToNextGrowth));
	end

	local citizensLabel = Locale.ToUpper( Locale.ConvertTextKey( "TXT_KEY_CITIZENS", cityPopulation ));

	Controls.CitizensLabel:SetText( citizensLabel );
	local growthTooltipStr = "[ICON_FOOD] " .. tostring(iCurrentFood) .. "/" .. tostring(iFoodNeeded) .. " (+" .. tostring(iFoodPerTurn) .. ")";
	Controls.CitizensLabel:SetToolTipString(Locale.ConvertTextKey(growthTooltipStr));
	

	-- Blockaded
	if (city:IsBlockaded()) then
		Controls.BlockadedIcon:SetHide(false);
		Controls.BlockadedIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_BLOCKADED");
	else
		Controls.BlockadedIcon:SetHide(true);
	end
		
	-- Being Razed
	if (city:IsRazing()) then
		Controls.RazingIcon:SetHide(false);
		Controls.RazingIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_BURNING", city:GetRazingTurns());
	else
		Controls.RazingIcon:SetHide(true);
	end

	-- Puppet Status
	if (city:IsPuppet()) then
		Controls.PuppetIcon:SetHide(false);
		Controls.PuppetIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_PUPPET");
	else
		Controls.PuppetIcon:SetHide(true);
	end

	-- Resistance Status
	if (city:IsResistance()) then
		Controls.ResistanceIcon:SetHide(false);
		Controls.ResistanceIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_RESISTANCE", city:GetResistanceTurns());
	else
		Controls.ResistanceIcon:SetHide(true);
	end

	-- In Martial Law
	if (city:IsMartialLaw()) then
		Controls.OccupiedIcon:SetHide(false);
		Controls.OccupiedIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_MARTIAL_LAW", city:GetMartialLawTurns());
	else
		Controls.OccupiedIcon:SetHide(true);
	end
		
	-- City Name (must be computed after top is resized)
	local cityName = city:GetNameKey();
	local convertedKey = Locale.ConvertTextKey(cityName);
		
	if (city:IsRazing()) then
		convertedKey = convertedKey .. " (" .. Locale.ConvertTextKey("TXT_KEY_BURNING") .. ")";
	end
		
	if (pPlayer:GetNumCities() <= 1) then
		Controls.PrevCityButton:SetDisabled( true );
		Controls.NextCityButton:SetDisabled( true );
	else
		Controls.PrevCityButton:SetDisabled( false );
		Controls.NextCityButton:SetDisabled( false );
	end
		
	OnCitySetDamage(city:GetDamage(), city:GetMaxHitPoints());
		
	convertedKey = Locale.ToUpper(convertedKey);

	local cityNameSize	= Controls.CityBannerButtonBase:GetSizeX();
	if(isCapital)then
		cityNameSize	= cityNameSize - Controls.CityCapitalIcon:GetSizeX();
	end
	TruncateString(Controls.CityNameTitleBarLabel, cityNameSize, convertedKey); 
	--Controls.CityNameTitleBarLabel:SetText( convertedKey );

	Controls.TitleStack:CalculateSize();
	Controls.TitleStack:ReprocessAnchoring();

	-- City Combat stats
	local cityStrength = math.floor(city:GetStrengthValue() / 100);

	Controls.Defense:SetText(cityStrength);

	local cityMaxHP = city:GetMaxHitPoints();
	local cityCurHP = cityMaxHP - city:GetDamage();

	local defenseStr = Locale.ConvertTextKey("TXT_KEY_NUM_COMBAT_STRENGTH", cityStrength);
	defenseStr = defenseStr .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUM_CUR_HIT_POINTS", cityCurHP, cityMaxHP);
	Controls.Defense:SetToolTipString(defenseStr);

	-- Trade Routes
	local tradeRoutesAllowed	= city:GetNumTradeRoutesAllowed();
	local tradeRoutesAvailable	= city:GetNumTradeRoutesAvailable();
	local tradeRoutesOccupied	= tradeRoutesAllowed - tradeRoutesAvailable;
	Controls.TradeRoutes:SetText(tradeRoutesOccupied .. "/" .. tradeRoutesAllowed);

	local tradeRouteTooltip = "";
	if tradeRoutesAllowed == 0 then
		tradeRouteTooltip = Locale.Lookup("TXT_KEY_CITYVIEW_TRADE_ROUTES_NO_SLOTS_TT");
	else
		tradeRouteTooltip = Locale.ConvertTextKey("TXT_KEY_CITYVIEW_TRADE_ROUTES_NUM_SLOTS_TT", tradeRoutesAllowed, tradeRoutesOccupied);

		local playerTradeRoutes = pPlayer:GetAllActiveTradeRoutes();
		if #playerTradeRoutes > 0 then

			tradeRouteTooltip = tradeRouteTooltip .. "[NEWLINE]";

			local cityX = city:GetX();
			local cityY = city:GetY();

			for i,route in ipairs(playerTradeRoutes) do

				if route.OriginX == cityX and route.OriginY == cityY then

					local domainInfo= GameInfo.Domains[route.Domain];
					local routeStr	= Locale.ConvertTextKey("TXT_KEY_CITYVIEW_TRADE_ROUTES_ENTRY_TT", route.DestSiteName, domainInfo.Adjective, route.TurnsLeft);

					tradeRouteTooltip = tradeRouteTooltip .. "[NEWLINE]" .. routeStr;
				end
			end
		end

		local tradeRouteSlotThreshold : number = city:GetTradeRouteSlotThreshold();
		if tradeRouteSlotThreshold ~= nil and tradeRouteSlotThreshold > 0 then
			local routeUnlockStr : string = Locale.ConvertTextKey("TXT_KEY_CITYVIEW_TRADE_ROUTES_SLOTS_UNLOCK_TT", tradeRouteSlotThreshold);
			tradeRouteTooltip = tradeRouteTooltip .. "[NEWLINE][NEWLINE]" .. routeUnlockStr;
		end
	end
	Controls.TradeRoutes:SetToolTipString(tradeRouteTooltip);


	-- City Health (not HP)

	local healthString		= "[ICON_HEALTH]";
	local healthColor		= COLOR_HEALTH_NEUTRAL;
	local iActivePlayer		= Game.GetActivePlayer();
	local pActivePlayer		= Players[iActivePlayer];
	local activePerkTypes	= pActivePlayer:GetAllActivePlayerPerkTypes();
	local healthAmt			= city:GetLocalHealth();
	if ( healthAmt > 0 ) then
		healthColor	= COLOR_HEALTH_GOOD;
	elseif (healthAmt < 0 ) then 
		healthColor	= COLOR_HEALTH_BAD;
		healthString= "[ICON_UNHEALTH]";
	end
	Controls.HealthLabel:SetColor( healthColor, 0 );
	Controls.HealthLabel:SetText( Locale.ConvertTextKey( healthString .. tostring(healthAmt) ));


 	CivIconHookup( pPlayer:GetID(), 64, Controls.CivIcon, Controls.CivIconBG, nil, false, false, Controls.CivIconHighlight );

	-------------------------------------------
	-- Deal with the production queue buttons
	-------------------------------------------
	local qLength = city:GetOrderQueueLength();
	if qLength > MAX_QUEUE_ITEMS then
		print("ERROR: Attempt to add queue item past length " .. tostring(qLength) );
		qLength = MAX_QUEUE_ITEMS;
	end

	-- hide the queue buttons
	Controls.b1box:SetHide( true );
	Controls.b2box:SetHide( true );
	Controls.b3box:SetHide( true );
	Controls.b4box:SetHide( true );
	Controls.b5box:SetHide( true );
	Controls.b6box:SetHide( true );

	local anyMaintained = false;
		
	-- If the production queue is open, and more than one item in the queue...
	local panelSizeY;
	if g_isProductionQueueOpen and qLength > 0 then

		Controls.ProductionButtonLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_QUEUE_PROD") );
		Controls.ProductionButton:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_QUEUE_PROD_TT") );

		-- Set the up and down arrows to move items in the queue.
		for i = 1, qLength, 1 do
			
			local buttonName= "b"..tostring(i).."box";
			local buttonDown= "b"..tostring(i).."down";
			local buttonUp	= "b"..tostring(i).."up";

			--  Show current button
			Controls[buttonName]:SetHide( false );			
						
			-- Show move down in queue button (if not at bottom)
			if qLength == i then
				Controls[buttonDown]:SetHide( true );
			else
				Controls[buttonDown]:SetHide( false );
			end

			-- Show move up in queue button (if not at top)
			local isMaintained = UpdateThisQueuedItem(city, i, qLength);
			if isMaintained then
				anyMaintained = true;
				Controls[buttonUp]:SetHide( true );
				if ( i > 1 ) then
					buttonDown = "b"..tostring( i-1 ).."down";
					Controls[buttonDown]:SetHide( true );
				end
			else				
				Controls[buttonUp]:SetHide( i == 1 );
			end				
		end

		Controls.ProductionQueue:CalculateSize();
		Controls.ProductionQueue:ReprocessAnchoring();

	else
		if qLength == 0 then
			Controls.ProductionButtonLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_CHOOSE_PROD") );
			Controls.ProductionButton:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_CHOOSE_PROD_TT") );
		else
			Controls.ProductionButtonLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_CHANGE_PROD") );
			Controls.ProductionButton:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_CHANGE_PROD_TT") );
		end	
	end

	if g_isProductionQueueOpen and (qLength >= MAX_QUEUE_ITEMS or anyMaintained == true) then
		Controls.ProductionButton:SetDisabled( true );
	else
		Controls.ProductionButton:SetDisabled( false );
	end
	if qLength == 1 then
		Controls.b1remove:SetHide( true );		
	end


	Controls.BuildingListBackground:SetHide( not g_isCityContentsListOpen );


	-------------------------------------------
	-- Item under Production
	-------------------------------------------
	DoUpdateProductionInfo( primaryColor, primaryColorAlphaed );


	-------------------------------------------
	-- Buildings (etc.) List
	-------------------------------------------			
	-- Reset...
	g_NoBuildingIM:ResetInstances();
	g_BuildingIM:ResetInstances();
	g_PlotButtonIM:ResetInstances();
	g_BuyPlotButtonIM:ResetInstances();
	ClearCachedDynamicUI();
	
	local controlTable;

	local slackerType = GameDefines.DEFAULT_SPECIALIST;
	local numSlackersInThisCity = city:GetSpecialistCount( slackerType );
		
	local isForcingPlotsToBeWorked = (city:GetNumForcedWorkingPlots() > 0);
	local focusType = city:GetFocusType();
	if ( isForcingPlotsToBeWorked ) then
		focusType = CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE;
	end

	Controls.CultureFocusSelected	:SetHide( not (focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE) );
	Controls.ProductionFocusSelected:SetHide( not (focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION) );
	Controls.FoodFocusSelected		:SetHide( not (focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD) );
	Controls.EnergyFocusSelected	:SetHide( not (focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_ENERGY) );
	Controls.ResearchFocusSelected	:SetHide( not (focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE) );

	local focusString	= "";
	local focusColor	= "[COLOR_YIELD_NONE]";
	local glowColor		= COLOR_FOCUS_GLOW_NONE;  
	local isHidingReset	= false;
		
	if city:GetNumForcedWorkingPlots() > 0 then			-- Set in updating hexes
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_CUSTOM_TEXT" );
		focusColor	= "[COLOR_WHITE]";
		glowColor	= COLOR_FOCUS_GLOW_NONE;
	elseif focusType == CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE then
		focusString		= Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_NONE_TEXT" );
		focusColor		= "[COLOR_YIELD_NONE]";
		glowColor		= COLOR_FOCUS_GLOW_NONE;
		isHidingReset	= (numSlackersInThisCity < 1);
	elseif focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE then
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_CULTURE_TEXT" );
		focusColor	= "[COLOR_YIELD_CULTURE]";
		glowColor	= COLOR_FOCUS_GLOW_CULTURE;			
	elseif focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION then
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_PROD_TEXT" );
		focusColor	= "[COLOR_YIELD_PRODUCTION]";
		glowColor	= COLOR_FOCUS_GLOW_PRODUCTION;
	elseif focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD then
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_FOOD_TEXT" );
		focusColor	= "[COLOR_YIELD_FOOD]";
		glowColor	= COLOR_FOCUS_GLOW_FOOD;
	elseif focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_ENERGY then
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_ENERGY_TEXT" );
		focusColor	= "[COLOR_YIELD_ENERGY]";			
		glowColor	= COLOR_FOCUS_GLOW_ENERGY;
	elseif focusType == CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE then
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_RESEARCH_TEXT" );
		focusColor	= "[COLOR_YIELD_SCIENCE]";
		glowColor	= COLOR_FOCUS_GLOW_SCIENCE;			
	else
		print("ERROR: Unknown focus type: " .. tostring( focusType ) );
		focusString = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_FOCUS_NONE_TEXT" );
		focusColor	= "[COLOR_RED]";
		glowColor	= COLOR_FOCUS_GLOW_UNKNOWN;
	end

	Controls.FocusLabel:SetColor( glowColor, 1);								-- Glow Layer
	Controls.FocusLabel:SetText( focusColor .. focusString .. "[ENDCOLOR]");	-- Main text

	local tw = Controls.FocusLabel:GetSizeX() + Controls.FocusWord:GetSizeX();
	if (tw > 230) then
		TruncateStringWithTooltip(Controls.FocusLabel, 76, focusString);
	else
		Controls.FocusLabel:SetText( focusColor .. focusString .. "[ENDCOLOR]");	-- Main text
	end
	
	Controls.ResetButton:SetHide( isHidingReset );
	
	Controls.UnemployedCitizens:SetHide( numSlackersInThisCity == 0 );
	Controls.NumUnemployedCitizens:SetText( tostring(numSlackersInThisCity) );
	Controls.UnemployedCitizensLabel:SetText(Locale.Lookup("TXT_KEY_UNEMPLOYED_CITIZENS", numSlackersInThisCity));
		

	Events.RequestYieldDisplay( YieldDisplayTypes.CITY_OWNED, city:GetX(), city:GetY() );
	-- no yields: Events.RequestYieldDisplay( YieldDisplayTypes.CITY_WORKED, city:GetX(), city:GetY() );
	
	sortOrder = 0;
	otherSortedList = {};
		
	local iBuildingMaintenance = city:GetTotalBaseBuildingMaintenance();
	local strMaintenanceTT = Locale.ConvertTextKey("TXT_KEY_BUILDING_MAINTENANCE_TT", iBuildingMaintenance);
	Controls.BuildingsHeader:SetToolTipString(strMaintenanceTT);


	local sortedList = {};
	

	-- ====== SPECIALISTS BUILDINGS ======

	local numSpecialBuildingsInThisCity = 0;
	if m_isSpecialistsHeadingOpen then
		Controls.SpecialBuildingsHeaderCollapse:SetText("[ICON_MINUS]");
	else
		Controls.SpecialBuildingsHeaderCollapse:SetText("[ICON_PLUS]");
	end
	sortedList = {};
	thisId = 1;
	for buildingIndex, building in ipairs(CachedBuildingInfoArray) do
		local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
		if thisBuildingClass.MaxGlobalInstances <= 0 and thisBuildingClass.MaxTeamInstances <= 0 then
			local buildingID= building.ID;
			if city:GetNumSpecialistsAllowedByBuilding(buildingID) > 0 then
				if (city:IsHasBuilding(buildingID)) then
					numSpecialBuildingsInThisCity	= numSpecialBuildingsInThisCity + 1;
					local element					= {};
					element.name					= Locale.ConvertTextKey( building.Description );
					element.ID						= building.ID;
					sortedList[thisId]				= element;
					thisId = thisId + 1;
				end
			end
		end
	end
	table.sort(sortedList, function(a, b) return a.name < b.name end);

	if numSpecialBuildingsInThisCity > 0 then
		Controls.SpecialBuildingsHeader:SetHide( false );
		sortOrder = sortOrder + 1;
		otherSortedList[tostring( Controls.SpecialBuildingsHeader )] = sortOrder;
		sortOrder = sortOrder + 1;
		otherSortedList[tostring( Controls.SpecialistControlBox )] = sortOrder;
		if m_isSpecialistsHeadingOpen then
			Controls.SpecialBuildingsHeader:RegisterCallback( Mouse.eLClick, OnSpecialistsHeaderSelected );
			for i, v in ipairs(sortedList) do
				local building = GameInfo.Buildings[v.ID];
				AddBuildingButton( city, building );
			end
		end			
	else
		Controls.SpecialBuildingsHeader:SetHide( true );
	end



	-- ====== WONDERS ======

	local numWondersInThisCity = 0;
	local numWondersWithSpecialistInThisCity = 0;
	if m_isWonderHeadingOpen then
		Controls.WondersHeaderCollapse:SetText("[ICON_MINUS]");
	else
		Controls.WondersHeaderCollapse:SetText("[ICON_PLUS]");
	end
	sortedList = {};
	local thisId = 1;
	for buildingIndex, building in ipairs(CachedBuildingInfoArray) do
		local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
		if thisBuildingClass.MaxGlobalInstances > 0 or (thisBuildingClass.MaxPlayerInstances == 1 and building.SpecialistCount == 0) or thisBuildingClass.MaxTeamInstances > 0 then
			local buildingID= building.ID;
			if (city:IsHasBuilding(buildingID)) then
				numWondersInThisCity = numWondersInThisCity + 1;
				if(city:GetNumSpecialistsAllowedByBuilding(buildingID) > 0) then
					numWondersWithSpecialistInThisCity = numWondersWithSpecialistInThisCity + 1;
				end
					
				local element = {};
				local name = Locale.ConvertTextKey( building.Description )
				element.name = name;
				element.ID = building.ID;
				sortedList[thisId] = element;
				thisId = thisId + 1;
			end
		end
	end
	table.sort(sortedList, function(a, b) return a.name < b.name end);
		
	if numWondersInThisCity > 0 then
		--if header is not hidden and is open
		Controls.WondersHeader:SetHide( false );
		sortOrder = sortOrder + 1;
		otherSortedList[tostring( Controls.WondersHeader )] = sortOrder;
			
		if m_isWonderHeadingOpen then
			Controls.WondersHeader:RegisterCallback( Mouse.eLClick, OnWondersHeaderSelected );
			for i, v in ipairs(sortedList) do				
				local building = GameInfo.Buildings[v.ID];
				AddBuildingButton( city, building );
			end
		end
	else
		Controls.WondersHeader:SetHide( true );
	end
		

	-- ====== (PLOT) IMPROVEMENT PROJECTS ======	

	local numPlotImprovementProjectsInThisCity = 0;
	if m_isImprovementProjectsHeadingOpen then
		Controls.ImprovementProjectsHeaderCollapse:SetText("[ICON_MINUS]");
	else
		Controls.ImprovementProjectsHeaderCollapse:SetText("[ICON_PLUS]");
	end
	sortedList = {};
	local cityPlotsMax = city:GetNumCityPlots() - 1;
 	for project in GameInfo.Projects() do

		-- Add (end-game) "projects" which are implemented on tiles as improvements.
		if (  project.PlotProject ) then

			for i = 0, cityPlotsMax, 1 do
				local plot = city:GetCityIndexPlot( i );
				if plot ~= nil and plot:HasImprovement() then
					local improvementKey = plot:GetImprovementType();	-- comes back as ID
					local improvementType = GameInfo.Improvements[improvementKey].Type;
					
					if ( improvementType == project.PartialImprovement or improvementType == project.CompleteImprovement ) then
						numPlotImprovementProjectsInThisCity = numPlotImprovementProjectsInThisCity + 1;
						table.insert(sortedList, {
							ID = project.ID,
							name = Locale.ConvertTextKey( project.Description ),
						});
					end
				end
			end		
		end
	end

	if numPlotImprovementProjectsInThisCity > 0 then
		--if header is not hidden and is open
		Controls.ImprovementProjectsHeader:SetHide( false );
		sortOrder = sortOrder + 1;
		otherSortedList[tostring( Controls.ImprovementProjectsHeader )] = sortOrder;
			
		if m_isImprovementProjectsHeadingOpen then
			Controls.ImprovementProjectsHeader:RegisterCallback( Mouse.eLClick, OnBuildingsHeaderSelected );
			for i, v in ipairs(sortedList) do
				local project = GameInfo.Projects[v.ID];
				AddPlotProjectButton( city, project );
			end
		end
	else
		Controls.ImprovementProjectsHeader:SetHide( true );
	end
	

	-- ===== BUILDINGS =====
	local numBuildingsInThisCity = 0;
	if m_isBuildingHeadingOpen then
		Controls.BuildingHeaderCollapse:SetText("[ICON_MINUS]");
	else
		Controls.BuildingHeaderCollapse:SetText("[ICON_PLUS]");
	end
	sortedList = {};
	thisId = 1;
	for buildingIndex, building in ipairs(CachedBuildingInfoArray) do
		local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
		if thisBuildingClass.MaxGlobalInstances <= 0 and thisBuildingClass.MaxPlayerInstances ~= 1 and thisBuildingClass.MaxTeamInstances <= 0 then
			local buildingID= building.ID;
			if city:GetNumSpecialistsAllowedByBuilding(buildingID) <= 0 then
				if city:IsHasBuilding(buildingID) then
					numBuildingsInThisCity = numBuildingsInThisCity + 1;
					local element = {};
					local name = Locale.ConvertTextKey( building.Description )
					element.name = name;
					element.ID = building.ID;
					sortedList[thisId] = element;
					thisId = thisId + 1;
				end
			end
		end
	end
	table.sort(sortedList, function(a, b) return a.name < b.name end);
	if numBuildingsInThisCity > 0 then
		--if header is not hidden and is open
		Controls.BuildingsHeader:SetHide( false );
		sortOrder = sortOrder + 1;
		otherSortedList[tostring( Controls.BuildingsHeader )] = sortOrder;
		if m_isBuildingHeadingOpen then
			Controls.BuildingsHeader:RegisterCallback( Mouse.eLClick, OnBuildingsHeaderSelected );
			for i, v in ipairs(sortedList) do
				local building = GameInfo.Buildings[v.ID];
				AddBuildingButton( city, building );
			end
		end
	else
		Controls.BuildingsHeader:SetHide( true );
	end

	-- No buildings or wonders in the city?
	if (	numBuildingsInThisCity < 1					and 
			numPlotImprovementProjectsInThisCity < 1	and
			numWondersInThisCity < 1					and
			numSpecialBuildingsInThisCity < 1 )			then
		local controlTable = g_NoBuildingIM:GetInstance();
	end

	RecalcPanelSize();
		
		
	-------------------------------------------
	-- Resource Demanded
	-------------------------------------------
		
	local szResourceDemanded = "??? (Research Required)";
		
	if (city:GetResourceDemanded(true) ~= -1) then
		local pResourceInfo = GameInfo.Resources[city:GetResourceDemanded()];
		szResourceDemanded = Locale.ConvertTextKey(pResourceInfo.IconString) .. " " .. Locale.ConvertTextKey(pResourceInfo.Description);
		Controls.ResourceDemandedBox:SetHide(false);
			
	else
		Controls.ResourceDemandedBox:SetHide(true);
	end
				
	local iNumTurns = city:GetWeLoveTheKingDayCounter();
	if (iNumTurns > 0) then
		szText = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_WLTKD_COUNTER", tostring(iNumTurns) );
		Controls.ResourceDemandedBox:SetToolTipString(Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_RESOURCE_FULFILLED_TT" ) );
	else
		szText = Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_RESOURCE_DEMANDED", szResourceDemanded );
		Controls.ResourceDemandedBox:SetToolTipString(Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_RESOURCE_DEMANDED_TT" ) );
	end
		
	Controls.ResourceDemandedString:SetText(szText);
	Controls.ResourceDemandedBox:SetSizeX(Controls.ResourceDemandedString:GetSizeX() + 10);
		
	Controls.IconsStack:CalculateSize();
	Controls.IconsStack:ReprocessAnchoring();
		
	Controls.NotificationStack:CalculateSize();
	Controls.NotificationStack:ReprocessAnchoring();
		
	-------------------------------------------
	-- Raze City Button (Resistance Cities only)
	-------------------------------------------
		
	if ( (not city:IsResistance() and not city:IsMartialLaw())  or city:IsRazing() ) then		
		g_bRazeButtonDisabled = true;
		Controls.RazeCityButton:SetHide(true);
	else
		-- Can we not actually raze this city?
		if (not pPlayer:CanRaze(city, false)) then
			-- We COULD raze this city if it weren't a capital
			if (pPlayer:CanRaze(city, true)) then
				g_bRazeButtonDisabled = true;
				Controls.RazeCityButton:SetHide(false);
				Controls.RazeCityButton:SetDisabled(true);
				Controls.RazeCityButton:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_RAZE_BUTTON_DISABLED_BECAUSE_CAPITAL_TT" ) );
			-- Can't raze this city period
			else
				g_bRazeButtonDisabled = true;
				Controls.RazeCityButton:SetHide(true);
			end
		else
			g_bRazeButtonDisabled = false;
			Controls.RazeCityButton:SetHide(false);
			Controls.RazeCityButton:SetDisabled(false);		
			Controls.RazeCityButton:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_CITYVIEW_RAZE_BUTTON_TT" ) );
		end
	end

	-- Stop city razing
	if (city:IsRazing()) then
		g_bRazeButtonDisabled = false;
		Controls.UnrazeCityButton:SetHide(false);
	else
		g_bRazeButtonDisabled = true;
		Controls.UnrazeCityButton:SetHide(true);
	end

	-- display energy income
	local iEnergyPerTurn = city:GetYieldRateTimes100(YieldTypes.YIELD_ENERGY) / 100;
	Controls.EnergyPerTurnLabel:SetText( "[ICON_ENERGY]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iEnergyPerTurn) );
			
	-- display science income
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
		Controls.ResearchPerTurnLabel:SetText( "[ICON_RESEARCH]" .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_OFF") );
	else
		local iSciencePerTurn = city:GetYieldRateTimes100(YieldTypes.YIELD_SCIENCE) / 100;
		Controls.ResearchPerTurnLabel:SetText( "[ICON_RESEARCH]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iSciencePerTurn) );
	end

	-- display culture rate
	local iCulturePerTurn = city:GetCulturePerTurn();
	Controls.CulturePerTurnLabel:SetText( "[ICON_CULTURE]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iCulturePerTurn) );

	-- display health rate
	local iLocalCityHealth = city:GetLocalHealth();
	Controls.HealthPerTurnLabel:SetText( "[ICON_HEALTH_1]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iLocalCityHealth) );

	-- ===== Culture Meter ======

	local cultureStored = city:GetCultureStored();
	local cultureNext	= city:GetCultureThreshold();
	local cultureDiff	= cultureNext - cultureStored;
	if iCulturePerTurn > 0 then
		local cultureTurns = math.ceil(cultureDiff / iCulturePerTurn);
		if (cultureTurns < 1) then
			cultureTurns = 1
		end
		Controls.CultureTimeTillGrowthLabel:SetText( Locale.ToUpper( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_TURNS_TILL_TILE_TEXT", cultureTurns)) );
		Controls.CultureTimeTillGrowthLabel:SetHide( false );
	else
		Controls.CultureTimeTillGrowthLabel:SetHide( true );
	end
	local percentComplete = cultureStored / cultureNext;

	Controls.CultureMeter:SetPercent( percentComplete );
	Controls.CultureMeterLineTop:SetTextureOffsetVal( 0, 96+(48-(48 * percentComplete)));
	Controls.CultureMeterLineTop:SetTextureSizeVal(48,1);
	Controls.CultureMeterLineTop:SetSizeY( 1 );
	Controls.CultureMeterLineTop:SetOffsetY( -(48 * percentComplete)+24 );


	-- ===== Covert Ops =====

	local intrigueLevel = city:GetIntrigueLevel();		-- 1 to 5
	local intrigue		= city:GetIntrigue();			-- 0 to 100	
	local percent		= intrigue / 100 ;

	Controls.Intrigue			:SetSizeVal( ART_INTRIGUE_WIDTH * percent , ART_INTRIGUE_HEIGHT);
	Controls.IntrigueHighlight	:SetColor( IntrigueToABGRColor( intrigue ) );



--[[ Alas, no space religion - for now
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
		Controls.FaithPerTurnLabel:SetText( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_OFF") );
	else
		local iFaithPerTurn = city:GetFaithPerTurn();
		Controls.FaithPerTurnLabel:SetText( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iFaithPerTurn) );
	end
]]
		
	local iFoodPerTurn = city:FoodDifferenceTimes100() / 100;		
	if (iFoodPerTurn >= 0) then
		Controls.FoodPerTurnLabel:SetText( "[ICON_FOOD]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iFoodPerTurn) );
	else
		Controls.FoodPerTurnLabel:SetText( "[ICON_FOOD]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT_NEGATIVE", iFoodPerTurn) );
	end	

	local iCurrentFood = city:GetFood();
	local iFoodNeeded = city:GrowthThreshold();
	local iFoodDiff = city:FoodDifference();
	local iCurrentFoodPlusThisTurn = iCurrentFood + iFoodDiff;
			
	local fGrowthProgressPercent = iCurrentFood / iFoodNeeded;			
		
	-- Viewing mode only
	if (UI.IsCityScreenViewingMode()) then
			
		-- City Cycling
		Controls.PrevCityButton:SetDisabled( true );
		Controls.NextCityButton:SetDisabled( true );
			
		-- Governor
		Controls.FoodFocusButton:SetDisabled( true );
		Controls.ProductionFocusButton:SetDisabled( true );
		Controls.EnergyFocusButton:SetDisabled( true );
		Controls.ResearchFocusButton:SetDisabled( true );
		Controls.CultureFocusButton:SetDisabled( true );
		Controls.HealthFocusButton:SetDisabled( true );

		Controls.ResetButton:SetDisabled( true );

		-- Other
		Controls.RazeCityButton:SetDisabled( true );
		Controls.UnrazeCityButton:SetDisabled( true );			
			
	else
			
		-- City Cycling
		Controls.PrevCityButton:SetDisabled( false );
		Controls.NextCityButton:SetDisabled( false );
			
		-- Governor
		
		Controls.FoodFocusButton:SetDisabled( false );
		Controls.ProductionFocusButton:SetDisabled( false );
		Controls.EnergyFocusButton:SetDisabled( false );
		Controls.ResearchFocusButton:SetDisabled( false );
		Controls.CultureFocusButton:SetDisabled( false );
		Controls.HealthFocusButton:SetDisabled( false );
		Controls.ResetButton:SetDisabled( false );
						
		-- Other
		if (not g_bRazeButtonDisabled) then
			Controls.RazeCityButton:SetDisabled( false );
			Controls.UnrazeCityButton:SetDisabled( false );
		end
	end

	UpdateWorkingHexes();
	UpdateCitizensFocusTooltips();

		
	if (city:GetOwner() ~= Game.GetActivePlayer()) then
		Controls.ProductionButton:SetDisabled(true);
		Controls.PurchaseButton:SetDisabled(true);
		Controls.EditButton:SetHide(true);
		Controls.EndTurnText:SetText(Locale.ConvertTextKey("TXT_KEY_CITYVIEW_RETURN_TO_ESPIONAGE"));
	end
		
	if( UI.IsCityScreenViewingMode() ) then
		Controls.EditButton:SetHide(true);
	end
	
	-- If this is the first show, all top elements are hidden by default
	-- So they don't look wacky until the resize occurs.
	Controls.AllCityInfoHiddenForInit:SetHide( false );

end
Events.SpecificCityInfoDirty.Add(OnSpecificCityInfoDirty);   -- ??TRON queue-resizing - trying to get callback after production list is updated do queue resizes properly
Events.SerialEventCityScreenDirty.Add(OnCityViewUpdate);
Events.SerialEventCityInfoDirty.Add(OnCityViewUpdate);



-- ===========================================================================
--	Recalculate dynamic panel sizes
-- ===========================================================================
function RecalcPanelSize()

	-- Header (very top)
	local size = (screenSizeX / 2 ) - (Controls.HeaderCenter:GetSizeX() / 2);
	Controls.HeaderLeft:SetSizeX( size );
	Controls.HeaderRight:SetSizeX( size );
	
	-- Header (2nd row)
	size =	(screenSizeX / 2) - 
				(Controls.CityBannerButtonBaseLeft:GetSizeX() + (Controls.CityBannerButtonBase:GetSizeX() / 2) + Controls.PrevCityButton:GetSizeX() );
	Controls.CityBannerButtonBaseLeftIn:SetSizeX( size );
	Controls.CityBannerBackgroundLeftIn:SetSizeX( size );
	Controls.CityBannerButtonBaseRightIn:SetSizeX( size );
	Controls.CityBannerBackgroundRightIn:SetSizeX( size );	
	
	-- Culture Header (3rd Row)
	size =	screenSizeX - 
		( Controls.CitizenManagementArea:GetSizeX() + Controls.ProductionArea:GetSizeX() );
	Controls.CityCultureArea:SetSizeX( size + 6 );

	-- Buildings and Wonders
	Controls.BuildingStack:SortChildren( CVSortFunction );		
	Controls.BuildingStack:CalculateSize();
	Controls.BuildingStack:ReprocessAnchoring();
		
	local maxHeight		= screenSizeY - ART_HEIGHT_AROUND_BUILDINGS_PANEL;
	local currentHeight = Controls.BuildingStack:GetSizeY() + 10;
	currentHeight		= math.min( currentHeight, maxHeight);
		
	Controls.BuildingListBackground:SetSizeY( currentHeight );
	Controls.ScrollPanel:SetSizeY( currentHeight - 10 );

	Controls.ScrollPanel:CalculateInternalSize();
	Controls.ScrollPanel:ReprocessAnchoring();
	Controls.BuildingStack:SortChildren( CVSortFunction );		
	Controls.BuildingStack:CalculateSize();
	Controls.BuildingStack:ReprocessAnchoring();
end


-------------------------------------------------
-- On City Set Damage
-------------------------------------------------
function OnCitySetDamage(iDamage, iMaxDamage)
	
	local iHealthPercent = 1 - (iDamage / iMaxDamage);

    Controls.HPMeter:SetPercent(iHealthPercent);
    
    if iHealthPercent > 0.66 then
        Controls.HPMeter:SetTexture("CityNamePanelHealthBarGreen.dds");
    elseif iHealthPercent > 0.33 then
        Controls.HPMeter:SetTexture("CityNamePanelHealthBarYellow.dds");
    else
        Controls.HPMeter:SetTexture("CityNamePanelHealthBarRed.dds");
    end
    
    -- Show or hide the Health Bar as necessary
    if (iDamage == 0) then
		Controls.HPFrame:SetHide(false);
	else
		Controls.HPFrame:SetHide(false);
    end
end


-- ===========================================================================
--	Update citizen growth meter; how long until next citizen is born
--	control,		The control that shows the current citizen's growth
--	controlShadow,	Companion control to show the position after one turn
-- ===========================================================================
function SetCitizenGrowthBar( control, controlShadow )	
	local city						= UI.GetHeadSelectedCity();		
	local iCurrentFood				= city:GetFood();
	local iFoodNeeded				= city:GrowthThreshold();
	local iFoodPerTurn				= city:FoodDifference();
	local iCurrentFoodPlusThisTurn	= iCurrentFood + iFoodPerTurn;			
	local fGrowthProgressPercent				= iCurrentFood / iFoodNeeded;
	local fGrowthProgressPlusThisTurnPercent	= iCurrentFoodPlusThisTurn / iFoodNeeded;
	if (fGrowthProgressPlusThisTurnPercent > 1) then
		fGrowthProgressPlusThisTurnPercent = 1;
	end			
	control:SetPercent( fGrowthProgressPercent );
	controlShadow:SetPercent( fGrowthProgressPlusThisTurnPercent );			
end


-- ===========================================================================
--	Update Production growth meter; how long until next item is completed.
--	control,		The control that shows the current production's growth
--	controlShadow,	Companion control to show the position after one turn
-- ===========================================================================
function SetProductionQueueGrowthBar( control, controlShadow )
	local city						= UI.GetHeadSelectedCity();		
	local iCurrentProduction		= city:GetProduction();
	local iProductionNeeded			= city:GetProductionNeeded();
	local iProductionPerTurn		= city:GetYieldRate(YieldTypes.YIELD_PRODUCTION);
	if (city:IsFoodProduction()) then
		iProductionPerTurn = iProductionPerTurn + city:GetFoodProduction();
	end
	local iCurrentProductionPlusThisTurn = iCurrentProduction + iProductionPerTurn;
			
	local fProductionProgressPercent = iCurrentProduction / iProductionNeeded;
	local fProductionProgressPlusThisTurnPercent = iCurrentProductionPlusThisTurn / iProductionNeeded;
	if (fProductionProgressPlusThisTurnPercent > 1) then
		fProductionProgressPlusThisTurnPercent = 1
	end
			
	control:SetPercent( fProductionProgressPercent );
	controlShadow:SetPercent( fProductionProgressPlusThisTurnPercent );
end


-- ===========================================================================
--	Set Production Icon
--	control,	The image control which will host the icon.
--	RETURN:	true if icon was found and set
-- ===========================================================================
function SetCurrentProductionIcon( control )

	local city					= UI.GetHeadSelectedCity();
	local unitProduction		= city:GetProductionUnit();
	local buildingProduction	= city:GetProductionBuilding();
	local projectProduction		= city:GetProductionProject();
	local processProduction		= city:GetProductionProcess();
	local isSet					= true;

	if unitProduction ~= -1 then
		local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(unitProduction, city:GetOwner());			
		if IconHookup( portraitOffset, 45, portraitAtlas, control ) then
			control:SetHide( false );					
		else
			control:SetHide( true );
		end
	elseif buildingProduction ~= -1 then
		local thisBuildingInfo = GameInfo.Buildings[buildingProduction];
		if IconHookup( thisBuildingInfo.PortraitIndex, 45, thisBuildingInfo.IconAtlas, control ) then
			control:SetHide( false );
		else
			control:SetHide( true );
		end
	elseif projectProduction ~= -1 then
		local thisProjectInfo = GameInfo.Projects[projectProduction];
		if IconHookup( thisProjectInfo.PortraitIndex, 45, thisProjectInfo.IconAtlas, control ) then
			control:SetHide( false );
		else
			control:SetHide( true );
		end
	elseif processProduction ~= -1 then
		control:SetColor( 0xffffffff );		-- These have coloured icons, don't tint!
		local thisProcessInfo = GameInfo.Processes[processProduction];
		if IconHookup( thisProcessInfo.PortraitIndex, 45, thisProcessInfo.IconAtlas, control ) then
			control:SetHide( false );
		else
			control:SetHide( true );
		end
	else 
		-- nothing is set.
		control:SetHide(true);
		isSet = false;
	end		

	return isSet;
end


-------------------------------------------------
-- Update Production Info
-------------------------------------------------
function DoUpdateProductionInfo( primaryColor, primaryColorAlphaed )
	
	local city				= UI.GetHeadSelectedCity();
	local pPlayer			= Players[city:GetOwner()];
	local iProductionPerTurn= city:GetCurrentProductionDifference(false, false);
	local szItemName		= Locale.ToUpper( Locale.ConvertTextKey(city:GetProductionNameKey()) );
	local iActivePlayer		= Game.GetActivePlayer();
	local isActivePlayerCity= (city:GetOwner() == iActivePlayer);
	

	Controls.CityBannerProductionButton:ClearCallback(Mouse.eLClick);

	-- Set icon
	Controls.CityBannerProductionImage:SetColor( primaryColor );	-- May be reset later...
	local hasProduction		=	SetCurrentProductionIcon( Controls.CityBannerProductionImage );
	Controls.ProductionBar:SetHide( not hasProduction );
	Controls.ProductionBarShadow:SetHide( not hasProduction );

	-- If no icon was found, assume production isn't set and early exit...
	if not hasProduction then
		Controls.ProductionTurnsLabel:SetText( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_NOTHING_IN_PRODUCTION"));
		Controls.ProductionItemName:SetText("");
		Controls.ProductionItemName:SetToolTipString( Locale.ConvertTextKey("") );
		Controls.ProdPerTurnLabel:SetToolTipString( Locale.ConvertTextKey("") );
		local iProductionToDisplay = city:GetRawProductionDifferenceTimes100(false, false) / 100;
		Controls.ProdPerTurnLabel:SetText( "[ICON_PRODUCTION]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iProductionToDisplay) );
		return;
	end

	TruncateStringWithTooltip(Controls.ProductionItemName, 300, szItemName);

	SetProductionQueueGrowthBar( Controls.ProductionBar, Controls.ProductionBarShadow);	
		
	if isActivePlayerCity then
    	Controls.CityBannerProductionButton:RegisterCallback( Mouse.eLClick, OnProductionClick );
    	Controls.CityBannerProductionButton:SetVoids( city:GetID(), nil );    	
	end		

	-- Production stored and needed
	local iStoredProduction = city:GetProductionTimes100() / 100;
	local iProductionNeeded = city:GetProductionNeeded();
	if (city:IsProductionProcess()) then
		iProductionNeeded = 0;
	end
	
	-- Progress info for meter	
	local iStoredProductionPlusThisTurn = iStoredProduction + iProductionPerTurn;
	
	local fProductionProgressPercent = iStoredProduction / iProductionNeeded;
	local fProductionProgressPlusThisTurnPercent = iStoredProductionPlusThisTurn / iProductionNeeded;
	if (fProductionProgressPlusThisTurnPercent > 1) then
		fProductionProgressPlusThisTurnPercent = 1
	end
	
	-- Turns left
	local productionTurnsLeft = city:GetProductionTurnsLeft();
	
	local strNumTurns;
	if(productionTurnsLeft > 99) then
		strNumTurns = Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_99PLUS_TURNS");
	else
		strNumTurns = Locale.ConvertTextKey("TXT_KEY_PRODUCTION_TURNS_UNTIL", productionTurnsLeft);
	end
			
	local bGeneratingProduction = city:IsProductionProcess() or city:GetCurrentProductionDifferenceTimes100(false, false) == 0;	
	if (bGeneratingProduction) then
		strNumTurns = "";
	end		
	
	Controls.ProductionTurnsLabel:SetText(strNumTurns);
	local productionTooltipStr = "[ICON_PRODUCTION] " .. tostring(iStoredProduction) .. "/" .. tostring(iProductionNeeded) .. " (+" .. tostring(iProductionPerTurn) .. ")";
	Controls.ProductionTurnsLabel:SetToolTipString(Locale.ConvertTextKey(productionTooltipStr));
	
	-- Info for the upper-left display
	local iProductionToDisplay = city:GetCurrentProductionDifferenceTimes100(false, false) / 100;
	Controls.ProdPerTurnLabel:SetText( "[ICON_PRODUCTION]" .. " " .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_PERTURN_TEXT", iProductionToDisplay) );
end


-- ===========================================================================
--	Update Tooltips for what citizens should be focusing on.
-- ===========================================================================
function UpdateCitizensFocusTooltips()
	local city				= UI.GetHeadSelectedCity();	
	local strFoodToolTip	= GetFoodTooltip( city );
	local strEnergyToolTip	= GetEnergyTooltip( city );
	local strScienceToolTip = GetScienceTooltip( city );
	local strCultureToolTip = GetCultureTooltip( city );
	local strProductionHelp = GetProductionTooltip(city);
	local strHealthHelp		= GetHealthTooltip(city);

	Controls.FoodFocusButton:SetToolTipString( strFoodToolTip );	
	Controls.EnergyFocusButton:SetToolTipString( strEnergyToolTip );	
	Controls.ResearchFocusButton:SetToolTipString( strScienceToolTip );	
	Controls.CultureFocusButton:SetToolTipString( strCultureToolTip );	
	Controls.ProductionFocusButton:SetToolTipString( strProductionHelp );
	Controls.HealthFocusButton:SetToolTipString( strHealthHelp );
end

-------------------------------------------------
--	Enter City Screen
--	ShowScreen
-------------------------------------------------
function OnEnterCityScreen()
	
	local city = UI.GetHeadSelectedCity();
	
	ClearCachedDynamicUI();
	-- m_uiSpecialistStackCache = {};	

	if (city ~= nil) then
		Network.SendUpdateCityCitizens(city:GetID());
	end

	LuaEvents.TryQueueTutorial("CITY_SCREEN", true);

	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT);	

	ContextPtr:SetHide(false);
	
	OnCityViewUpdate();	
end
Events.SerialEventEnterCityScreen.Add(OnEnterCityScreen);


-------------------------------------------------
-------------------------------------------------
function PlotButtonClicked( iPlotIndex )
	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		if iPlotIndex > 0 then
			local city = UI.GetHeadSelectedCity();
			Network.SendDoTask(city:GetID(), TaskTypes.TASK_CHANGE_WORKING_PLOT, iPlotIndex, -1, false, bAlt, bShift, bCtrl);
		end
	end	
end

-- ===========================================================================
--	Actually buy a plot
-- ===========================================================================
function BuyPlotAnchorButtonClicked( iPlotIndex )

	if not Players[Game.GetActivePlayer()]:IsTurnActive() then
		return;
	end
	
	local activePlayerID = Game.GetActivePlayer();
	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	if pHeadSelectedCity then
		local plot	= pHeadSelectedCity:GetCityIndexPlot( iPlotIndex );
		local plotX = plot:GetX();
		local plotY = plot:GetY();
		Network.SendCityBuyPlot(pHeadSelectedCity:GetID(), plotX, plotY);
		UI.UpdateCityScreen();
		Events.AudioPlay2DSound("AS2D_INTERFACE_BORDERS_EXPAND");		
	end
	return true;
end
LuaEvents.DoPlotPurchase.Add( BuyPlotAnchorButtonClicked );

-- ===========================================================================
--	Confirmation dialog to raise a plot
-- ===========================================================================
function OnConfirmBuyPlotButtonClicked( iPlotIndex, iPlotCost )
	-- Raise dialog to make absolutely sure the player really wants to buy the plot.
	LuaEvents.RaiseConfirmPlotPurchase( iPlotIndex, iPlotCost );
end


-- ===========================================================================
-- Highlight hexes for the city mode.  This is separate from UpdateWorkingHexes
-- because it is also called as the user moves their cursor around.
function UpdateHexHighlights()
		
	local city = UI.GetHeadSelectedCity();
	
    if( city == nil or (UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION )) then
        return;
    end	

	if (UI.IsCityScreenUp()) then   

		for i = 0, city:GetNumCityPlots() - 1, 1 do
			local plot = city:GetCityIndexPlot( i );
			if (plot ~= nil) then				
				local hexPos = ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) );				
				Events.SerialEventHexHighlight( hexPos, false, Vector4( 0.0, 0.0, 0.0, 1 ) );
			end
		end
		
		-- Buy plot highlights		
		local uiMode = UI.GetInterfaceMode();
		if  uiMode == InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT then
			local aPurchasablePlots = {city:GetBuyablePlotList()};
			for i = 1, #aPurchasablePlots, 1 do
				Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( aPurchasablePlots[i]:GetX(), aPurchasablePlots[i]:GetY() ) ), true, Vector4( 1.0, 0.0, 1.0, 1 ) );
			end

		-- Wonder Plot highlights
		elseif uiMode == InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION then
			local aWonderPlots = {city:GetWonderPlotsList()};
			for i = 1, #aWonderPlots, 1 do
				Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( aWonderPlots[i]:GetX(), aWonderPlots[i]:GetY() ) ), true, Vector4( 1.0, 1.0, 0.0, 1 ) );
			end

		-- Standard mode - show plots that will be acquired by culture
		else
			local aPurchasablePlots = {city:GetBuyablePlotList()};
			for i = 1, #aPurchasablePlots, 1 do
				Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( aPurchasablePlots[i]:GetX(), aPurchasablePlots[i]:GetY() ) ), true, Vector4( 1.0, 0.0, 1.0, 1 ) );
			end
		end
    end	
end

-- ===========================================================================
function UpdateWorkingHexes()
		
	local city = UI.GetHeadSelectedCity();
	
    if( city == nil or (UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_WONDER_PLOT_SELECTION )) then
        return;
    end	

	if (UI.IsCityScreenUp()) then   

		-- CivBE: Force Plot selection mode
		if ( UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_SELECTION ) then
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT);
		end

		-- display worked plots
		g_PlotButtonIM:ResetInstances();		

		local CITIZEN_ICON_SIZE = 64;

		for i = 0, city:GetNumCityPlots() - 1, 1 do
			local plot = city:GetCityIndexPlot( i );
			if (plot ~= nil) then
				
				local hexPos = ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) );
				if ( plot:GetOwner() == city:GetOwner() ) then
				
					local worldPos = HexToWorld( hexPos );
					
					-- the city itself
					if ( i == 0 ) then
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, CITIZEN_ICON_SIZE );
						controlTable.PlotBacking:ReprocessAnchoring();
						IconHookup(	11, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_CITY_CENTER") );
						controlTable.PlotButtonImage:SetVoid1( -1 );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, OnResetForcedTiles);
							
						DoTestViewingModeOnly(controlTable);
							
						--Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) ), true, Vector4( 1.0, 1.0, 1.0, 1 ) );
					-- FORCED worked plot
					elseif ( city:IsWorkingPlot( plot ) and city:IsForcedWorkingPlot( plot ) ) then
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, CITIZEN_ICON_SIZE );
						IconHookup(	10, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_FORCED_WORK_TILE") );
						controlTable.PlotButtonImage:SetVoid1( i );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, PlotButtonClicked);
							
						DoTestViewingModeOnly(controlTable);							

						--Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) ), true, Vector4( 1.0, 1.0, 1.0, 1 ) );
					-- AI-picked worked plot
					elseif ( city:IsWorkingPlot( plot ) ) then						
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, CITIZEN_ICON_SIZE );
						IconHookup(	0, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_GUVNA_WORK_TILE") );
						controlTable.PlotButtonImage:SetVoid1( i );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, PlotButtonClicked);
							
						DoTestViewingModeOnly(controlTable);
							
						--Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) ), true, Vector4( 0.0, 1.0, 0.0, 1 ) );
					-- Owned by another one of our Cities
					elseif ( plot:GetWorkingCity():GetID() ~= city:GetID() and  plot:GetWorkingCity():IsWorkingPlot( plot ) ) then
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, CITIZEN_ICON_SIZE );
						IconHookup(	12, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_NUTHA_CITY_TILE") );
						controlTable.PlotButtonImage:SetVoid1( i );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, PlotButtonClicked);
							
						DoTestViewingModeOnly(controlTable);
							
						--Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) ), true, Vector4( 0.0, 0.0, 1.0, 1 ) );
					-- Blockaded water plot
					elseif ( plot:IsWater() and city:IsPlotBlockaded( plot ) ) then
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, CITIZEN_ICON_SIZE );
						IconHookup(	13, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_BLOCKADED_CITY_TILE") );
						controlTable.PlotButtonImage:SetVoid1( -1 );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, PlotButtonClicked);
							
						DoTestViewingModeOnly(controlTable);
							
						--Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) ), true, Vector4( 1.0, 0.0, 0.0, 1 ) );
					-- Enemy Unit standing here
					elseif ( plot:IsUnitBlockingCityWork(city:GetOwner()) ) then
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, CITIZEN_ICON_SIZE );
						IconHookup(	13, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_ENEMY_UNIT_CITY_TILE") );
						controlTable.PlotButtonImage:SetVoid1( -1 );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, PlotButtonClicked);
							
						DoTestViewingModeOnly(controlTable);
							
						--Events.SerialEventHexHighlight( ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) ), true, Vector4( 1.0, 0.0, 0.0, 1 ) );
					-- Other: turn off highlight
					elseif ( city:CanWork( plot ) or plot:GetWorkingCity():GetID() ~= city:GetID() ) then
						local controlTable = g_PlotButtonIM:GetInstance();						
						controlTable.PlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
						controlTable.PlotButtonImage:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_CITYVIEW_UNWORKED_CITY_TILE") );
						controlTable.PlotBacking:SetTextureOffsetVal( 0, 0 );
						IconHookup(	9, 45, "CITIZEN_ATLAS", controlTable.PlotButtonImage);
						controlTable.PlotButtonImage:SetVoid1( i );
						controlTable.PlotButtonImage:RegisterCallback( Mouse.eLCLick, PlotButtonClicked);
							
						DoTestViewingModeOnly(controlTable);
							
					end
												
				end			
			end
		end
		
		-- Plot Choosers
		g_BuyPlotButtonIM:ResetInstances();
		
		local bDiablePurchasePlots : boolean = UI.IsCityScreenViewingMode();
		-- Buy plot buttons		
		local uiMode = UI.GetInterfaceMode();
		if  uiMode == InterfaceModeTypes.INTERFACEMODE_PURCHASE_PLOT then
			Events.RequestYieldDisplay( YieldDisplayTypes.CITY_PURCHASABLE, city:GetX(), city:GetY() );
			for i = 0, city:GetNumCityPlots() - 1, 1 do
				local plot = city:GetCityIndexPlot( i );
				if (plot ~= nil) then

					local hexPos		= ToHexFromGrid( Vector2( plot:GetX(), plot:GetY() ) );
					local worldPos		= HexToWorld( hexPos );
					local controlTable	= g_BuyPlotButtonIM:GetInstance();

					if (city:CanBuyPlotAt(plot:GetX(), plot:GetY(), false)) then						
						local iPlotCost		= city:GetBuyPlotCost( plot:GetX(), plot:GetY() );
						local strText		= Locale.ConvertTextKey("TXT_KEY_CITYVIEW_CLAIM_NEW_LAND");
						controlTable.BuyPlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset2 ) );						
						controlTable.BuyPlotAnchoredButton:SetToolTipString( strText );
						controlTable.BuyPlotAnchoredButtonLabel:SetText( tostring(iPlotCost) );
						controlTable.BuyPlotAnchoredButton:SetDisabled( bDiablePurchasePlots );
						controlTable.BuyPlotAnchoredButton:SetVoid1( i );
						controlTable.BuyPlotAnchoredButton:SetVoid2( iPlotCost );
						controlTable.BuyPlotAnchoredButton:RegisterCallback( Mouse.eLCLick, OnConfirmBuyPlotButtonClicked);
						controlTable.BuyPlotAnchoredButton:SetHide( false );
					elseif (city:CanBuyPlotAt(plot:GetX(), plot:GetY(), true)) then
						local iPlotCost		= city:GetBuyPlotCost( plot:GetX(), plot:GetY() );						
						local strText		= Locale.ConvertTextKey("TXT_KEY_CITYVIEW_NEED_MONEY_BUY_TILE",iPlotCost);
						controlTable.BuyPlotButtonAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset2 ) );
						controlTable.BuyPlotAnchoredButton:SetToolTipString( strText );
						controlTable.BuyPlotAnchoredButton:SetDisabled( bDiablePurchasePlots );
						controlTable.BuyPlotAnchoredButtonLabel:SetText( "[COLOR_GREY]"..tostring(iPlotCost).."[ENDCOLOR]" );
						controlTable.BuyPlotAnchoredButton:SetHide( false );
					else
						controlTable.BuyPlotAnchoredButton:SetHide( true );
					end

					-- Resize width of background elements based on text contents.
					local purchaseWidth = 50 + controlTable.BuyPlotAnchoredButtonLabel:GetSizeX();
					controlTable.BuyPlotAnchoredButton:SetSizeX( purchaseWidth );
					controlTable.GridOver:SetSizeX( purchaseWidth );					
					controlTable.GridOut:SetSizeX( purchaseWidth );				
				end
			end
		end

		UpdateHexHighlights();
    end	
end
Events.SerialEventCityHexHighlightDirty.Add(UpdateWorkingHexes);


-------------------------------------------------
function DoTestViewingModeOnly(controlTable)
	-- Viewing mode only?
	if (UI.IsCityScreenViewingMode()) then
		controlTable.PlotButtonImage:SetDisabled(true);
	else
		controlTable.PlotButtonImage:SetDisabled(false);
	end
end	


-------------------------------------------------
-------------------------------------------------
function OnProductionClick()
	
	local city = UI.GetHeadSelectedCity();
	local cityID = city:GetID();
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_CHOOSEPRODUCTION,
		Data1 = cityID,
		Data2 = -1,
		Data3 = -1,
		Option1 = (g_isProductionQueueOpen and city:GetOrderQueueLength() > 0),
		Option2 = false;
	}
	Events.SerialEventGameMessagePopup(popupInfo);
    -- send production popup message
end
Controls.ProductionButton:RegisterCallback( Mouse.eLClick, OnProductionClick );


-------------------------------------------------
-------------------------------------------------
function OnRemoveClick( num )	
	Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_POP_ORDER, num);
	LuaEvents.CityQueueDirty( g_isProductionQueueOpen );	-- ??TRON queue-resizing
end
Controls.b1remove:RegisterCallback( Mouse.eLClick, OnRemoveClick );
Controls.b1remove:SetVoid1( 0 );
Controls.b2remove:RegisterCallback( Mouse.eLClick, OnRemoveClick );
Controls.b2remove:SetVoid1( 1 );
Controls.b3remove:RegisterCallback( Mouse.eLClick, OnRemoveClick );
Controls.b3remove:SetVoid1( 2 );
Controls.b4remove:RegisterCallback( Mouse.eLClick, OnRemoveClick );
Controls.b4remove:SetVoid1( 3 );
Controls.b5remove:RegisterCallback( Mouse.eLClick, OnRemoveClick );
Controls.b5remove:SetVoid1( 4 );
Controls.b6remove:RegisterCallback( Mouse.eLClick, OnRemoveClick );
Controls.b6remove:SetVoid1( 5 );

-------------------------------------------------
-------------------------------------------------
function OnSwapClick( num )
	Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_SWAP_ORDER, num);
end
Controls.b1down:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b1down:SetVoid1( 0 );

Controls.b2up:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b2up:SetVoid1( 0 );
Controls.b2down:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b2down:SetVoid1( 1 );

Controls.b3up:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b3up:SetVoid1( 1 );
Controls.b3down:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b3down:SetVoid1( 2 );

Controls.b4up:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b4up:SetVoid1( 2 );
Controls.b4down:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b4down:SetVoid1( 3 );

Controls.b5up:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b5up:SetVoid1( 3 );
Controls.b5down:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b5down:SetVoid1( 4 );

Controls.b6up:RegisterCallback( Mouse.eLClick, OnSwapClick );
Controls.b6up:SetVoid1( 4 );
--Controls.b6down:RegisterCallback( Mouse.eLClick, OnSwapClick );
--Controls.b6down:SetVoid1( 5 );


-------------------------------------------------
-------------------------------------------------

local g_iCurrentSpecialist = -1;
local g_bCurrentSpecialistGrowth = true;

-------------------------------------------------
function OnNextCityButton()
	Game.DoControl(GameInfoTypes.CONTROL_NEXTCITY)
end
Controls.NextCityButton:RegisterCallback( Mouse.eLClick, OnNextCityButton );

-------------------------------------------------
function OnPrevCityButton()
	Game.DoControl(GameInfoTypes.CONTROL_PREVCITY)
end
Controls.PrevCityButton:RegisterCallback( Mouse.eLClick, OnPrevCityButton );


-------------------------------------------------
-- Plot moused over
-------------------------------------------------
function OnMouseOverHex( hexX, hexY )
	
	local city = UI:GetHeadSelectedCity();		
	if (city == nil) or (ContextPtr:IsHidden()) then
		return;
	end

	-- Only update the hexes if a confirm dialog isn't in the forground.
	if Controls.CityConfirmPlotPurchase:IsHidden() then

		Events.ClearHexHighlightStyle(genericUnitHexBorder);
		-- The cursor will destroy the highlights, and we are not keeping track of
		-- where the cursor has been so just do a full re-highlight of all the hexes.
		UpdateHexHighlights();

		-- Only highlight plot if it can be purcahsed.
		if (city:CanBuyPlotAt( hexX, hexY, true)) then
			local highlightColor = Vector4( 1, 1, 1, 1 );	
			Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(hexX, hexY)), true, highlightColor, genericUnitHexBorder );
		end
	end
	

end
Events.SerialEventMouseOverHex.Add( OnMouseOverHex );

-------------------------------------------------
-------------------------------------------------
function OnReturnToMapButton()
	Events.SerialEventExitCityScreen();
end
Controls.ReturnToMapButton:RegisterCallback( Mouse.eLClick, OnReturnToMapButton);

-------------------------------------------------
-------------------------------------------------
function OnRazeButton()

	local city = UI.GetHeadSelectedCity();
	
	if (city == nil) then
		return;
	end;
	
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_CONFIRM_CITY_TASK,
		Data1 = city:GetID(),
		Data2 = TaskTypes.TASK_RAZE,
		}
    
	Events.SerialEventGameMessagePopup( popupInfo );
end
Controls.RazeCityButton:RegisterCallback( Mouse.eLClick, OnRazeButton);

-------------------------------------------------
-------------------------------------------------
function OnUnrazeButton()

	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		local city = UI.GetHeadSelectedCity();
		
		if (city == nil) then
			return;
		end;
		
		Network.SendDoTask(city:GetID(), TaskTypes.TASK_UNRAZE, -1, -1, false, false, false, false);
	end
end
Controls.UnrazeCityButton:RegisterCallback( Mouse.eLClick, OnUnrazeButton);

-------------------------------------------------
-------------------------------------------------
function OnPurchaseButton()
	local city = UI.GetHeadSelectedCity();
	local cityID = city:GetID();
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_CHOOSEPRODUCTION,
		Data1 = cityID,
		Data2 = -1,
		Data3 = -1,
		Option1 = (g_isProductionQueueOpen and city:GetOrderQueueLength() > 0),
		Option2 = true;
	}
	Events.SerialEventGameMessagePopup(popupInfo);
    -- send production popup message

end
Controls.PurchaseButton:RegisterCallback( Mouse.eLClick, OnPurchaseButton);

function OnPortraitRClicked()
	local city = UI.GetHeadSelectedCity();
	local cityID = city:GetID();

	local searchString = "";
	local unitProduction = city:GetProductionUnit();
	local buildingProduction = city:GetProductionBuilding();
	local projectProduction = city:GetProductionProject();
	local processProduction = city:GetProductionProcess();
	local noProduction = false;

	if unitProduction ~= -1 then
		local thisUnitInfo = GameInfo.Units[unitProduction];
		searchString = Locale.ConvertTextKey( thisUnitInfo.Description );
	elseif buildingProduction ~= -1 then
		local thisBuildingInfo = GameInfo.Buildings[buildingProduction];
		searchString = Locale.ConvertTextKey( thisBuildingInfo.Description );
	elseif projectProduction ~= -1 then
		local thisProjectInfo = GameInfo.Projects[projectProduction];
		searchString = Locale.ConvertTextKey( thisProjectInfo.Description );
	elseif processProduction ~= -1 then
		local pProcessInfo = GameInfo.Processes[processProduction];
		searchString = Locale.ConvertTextKey( pProcessInfo.Description );
	else
		noProduction = true;
	end
		
	if noProduction == false then	
		--CloseScreen();
		-- search by name
		Events.SearchForPediaEntry( searchString );		
	end
		
end
Controls.CityBannerProductionButton:RegisterCallback( Mouse.eRClick, OnPortraitRClicked );


-- ===========================================================================
--	Show/Hide Production Queue
-- ===========================================================================
function OnToggleShowProductionQueue( bIsChecked )
	g_isProductionQueueOpen = bIsChecked;	
	OnCityViewUpdate();
	LuaEvents.CityQueueDirty( g_isProductionQueueOpen );
end
Controls.ShowQueueProductionButton:RegisterCheckHandler( OnToggleShowProductionQueue );


-- ===========================================================================
--	Show/Hide Contents of the city (Buildings, wonders, etc...)
-- ===========================================================================
function OnToggleShowCityContents( bIsChecked )
	g_isCityContentsListOpen = bIsChecked;	
	OnCityViewUpdate();
end
Controls.ShowQueueBuildWondersButton:RegisterCheckHandler( OnToggleShowCityContents );


-- ===========================================================================
--	Change which citizen focus should ben
-- ===========================================================================
function CitizenFocusChanged( focus )

	-- Reset all focus...
	if ( focus == CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE ) then
		OnResetForcedTiles();
	end

	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		local city = UI.GetHeadSelectedCity();
		Network.SendSetCityAIFocus( city:GetID(), focus );
		--Network.SendUpdateCityCitizens( city:GetID() );	-- Doesn't help to update
	end
end
Controls.FoodFocusButton:SetVoid1( CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD )
Controls.FoodFocusButton:RegisterCallback( Mouse.eLClick, CitizenFocusChanged );

Controls.ProductionFocusButton:SetVoid1( CityAIFocusTypes.CITY_AI_FOCUS_TYPE_PRODUCTION )
Controls.ProductionFocusButton:RegisterCallback( Mouse.eLClick, CitizenFocusChanged );

Controls.EnergyFocusButton:SetVoid1( CityAIFocusTypes.CITY_AI_FOCUS_TYPE_ENERGY )
Controls.EnergyFocusButton:RegisterCallback( Mouse.eLClick, CitizenFocusChanged );

Controls.ResearchFocusButton:SetVoid1( CityAIFocusTypes.CITY_AI_FOCUS_TYPE_SCIENCE )
Controls.ResearchFocusButton:RegisterCallback( Mouse.eLClick, CitizenFocusChanged );

Controls.CultureFocusButton:SetVoid1( CityAIFocusTypes.CITY_AI_FOCUS_TYPE_CULTURE )
Controls.CultureFocusButton:RegisterCallback( Mouse.eLClick, CitizenFocusChanged );

-- TODO
--Controls.HealthFocusButton:SetVoid1( CityAIFocusTypes.CITY_AI_FOCUS_TYPE_FOOD )
--Controls.HealthFocusButton:RegisterCallback( Mouse.eLClick, CitizenFocusChanged );

----------------------------------------------------------------
--[[ May bring back, undecided by design.  - TRON 4/22/14
function OnAvoidGrowth( )
	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		local city = UI.GetHeadSelectedCity();
		Network.SendSetCityAvoidGrowth( city:GetID(), not city:IsForcedAvoidGrowth() );
	end		
end
Controls.AvoidGrowthButton:RegisterCallback( Mouse.eLClick, OnAvoidGrowth );
]]

----------------------------------------------------------------
----------------------------------------------------------------

function OnResetForcedTiles( )
	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		local city = UI.GetHeadSelectedCity();
		if city ~= nil then
			-- calling this with the city center (0 in the third param) causes it to reset all forced tiles
			Network.SendDoTask(city:GetID(), TaskTypes.TASK_CHANGE_WORKING_PLOT, 0, -1, false, bAlt, bShift, bCtrl);
		end
	end	
end
Controls.ResetButton:RegisterCallback( Mouse.eLClick, function() CitizenFocusChanged( CityAIFocusTypes.NO_CITY_AI_FOCUS_TYPE ); end );

---------------------------------------------------------------------------------------
-- Support for Modded Add-in UI's
---------------------------------------------------------------------------------------
g_uiAddins = {};
for addin in Modding.GetActivatedModEntryPoints("CityViewUIAddin") do
	local addinFile = Modding.GetEvaluatedFilePath(addin.ModID, addin.Version, addin.File);
	local addinPath = addinFile.EvaluatedPath;
	
	-- Get the absolute path and filename without extension.
	local extension = Path.GetExtension(addinPath);
	local path = string.sub(addinPath, 1, #addinPath - #extension);
	
	table.insert(g_uiAddins, ContextPtr:LoadNewContext(path));
end


---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
function OnProductionPopup( isProductionPopupHiding )
end
LuaEvents.ProductionPopup.Add( OnProductionPopup );


------------------------------------------------------------
-- Selling Buildings
------------------------------------------------------------
function OnBuildingClicked(iBuildingID)

	if (not Players[Game.GetActivePlayer()]:IsTurnActive()) then
		return;
	end

	local city = UI.GetHeadSelectedCity();
	
	-- Can this building even be sold?
	if (not city:IsBuildingSellable(iBuildingID)) then
		return;
	end
	
	-- Build info string
	local pBuilding = GameInfo.Buildings[iBuildingID];
	
	local iRefund = city:GetSellBuildingRefund(iBuildingID);
	local iMaintenance = pBuilding.EnergyMaintenance;
	
	local localizedLabel = Locale.ConvertTextKey( "TXT_KEY_SELL_BUILDING_INFO", iRefund, iMaintenance );
	Controls.SellBuildingPopupText:SetText(localizedLabel);
	
	g_iBuildingToSell = iBuildingID;
	
	Controls.SellBuildingConfirm:SetHide(false);
end

-- ===========================================================================
function OnYes( )
	Controls.SellBuildingConfirm:SetHide(true);
	if Players[Game.GetActivePlayer()]:IsTurnActive() then
		local city = UI.GetHeadSelectedCity();
		Network.SendSellBuilding(city:GetID(), g_iBuildingToSell);
	end
	g_iBuildingToSell = -1;
end
Controls.YesButton:RegisterCallback( Mouse.eLClick, OnYes );

-- ===========================================================================
function OnNo( )
	Controls.SellBuildingConfirm:SetHide(true);
	g_iBuildingToSell = -1;
end
Controls.NoButton:RegisterCallback( Mouse.eLClick, OnNo );


-- ===========================================================================
function OnAddSpecialist( buildingID, iSlot )
	local pCity = UI.GetHeadSelectedCity();
				
	-- If Specialists are automated then you can't change things with them
	if (not pCity:IsNoAutoAssignSpecialists()) then
		Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_TASK, TaskTypes.TASK_NO_AUTO_ASSIGN_SPECIALISTS, -1, -1, true);
	end
	
	local iSpecialist = GameInfoTypes[GameInfo.Buildings[buildingID].SpecialistType];
	
	-- If we can add something, add it
	if (pCity:IsCanAddSpecialistToBuilding(buildingID)) then
		Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_TASK, TaskTypes.TASK_ADD_SPECIALIST, iSpecialist, buildingID);
		m_uiSpecialistStackCache[buildingID].slotsUsed[iSlot] = true;
	end
end

-- ===========================================================================
function OnRemoveSpecialist( buildingID, iSlot )
	local pCity = UI.GetHeadSelectedCity();
	
	local iNumSpecialistsAssigned = pCity:GetNumSpecialistsInBuilding(buildingID);
				
	-- If Specialists are automated then you can't change things with them
	if (not pCity:IsNoAutoAssignSpecialists()) then
		Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_TASK, TaskTypes.TASK_NO_AUTO_ASSIGN_SPECIALISTS, -1, -1, true);
	end
	
	local iSpecialist = GameInfoTypes[GameInfo.Buildings[buildingID].SpecialistType];
	
	-- If we can remove something, remove it
	if (iNumSpecialistsAssigned > 0) then
		Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_TASK, TaskTypes.TASK_REMOVE_SPECIALIST, iSpecialist, buildingID);
		m_uiSpecialistStackCache[buildingID].slotsUsed[iSlot] = false;
	end

end


----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnEventActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	ClearCityUIInfo();
	RefreshPlayerColoredItems();
    if( not ContextPtr:IsHidden() ) then
		Events.SerialEventExitCityScreen();	
	end
end
Events.GameplaySetActivePlayer.Add(OnEventActivePlayerChanged);

-- ===========================================================================
function ClearCachedDynamicUI()
	-- Cache of (sub) UI elements.
	for _,ui in pairs( m_uiSpecialistStackCache ) do
		ui.specialistsIM:ResetInstances();
	end
end
