-- ===========================================================================
-- Trade Route Popup
-- ===========================================================================

include( "IconSupport" );
include( "InstanceManager" );
include( "CommonBehaviors" );
include( "TradeRouteHelpers" );


-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local g_ItemManagers = {
	InstanceManager:new( "ItemInstance", "Button", Controls.PreviousRouteStack ),
	InstanceManager:new( "ItemInstance", "Button", Controls.YourCitiesStack ),
	InstanceManager:new( "ItemInstance", "Button", Controls.YourOutpostsStack ),
	InstanceManager:new( "ItemInstance", "Button", Controls.OtherCivsStack ),
	InstanceManager:new( "ItemInstance", "Button", Controls.StationsStack ),
}

local g_iUnitIndex					= -1;
local g_iPlayer						= -1;
local g_invalidPlotMiasmaStyle		= "InvalidPlotMiasma";
local g_invalidPlotMiasmaColor		= Vector4(1, 0, 0, 0.5);
local m_bHidden						= true;
local g_PopupInfo					= nil;

local g_bAutoRenewFlag				= 1;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function Initialize()

	local m_screenSizeX, m_screenSizeY	= UIManager:GetScreenSizeVal()
	local spHeight						= Controls.ItemScrollPanel:GetSizeY();
	local bpHeight						= Controls.BottomPanel:GetSizeY();

	local ART_BUFFER					= 5;
	Controls.BottomPanel:SetSizeY( m_screenSizeY - ART_BUFFER );
	Controls.BottomPanel:ReprocessAnchoring();

	local ART_BUFFER_SCROLLAREA			= 211;
	Controls.ItemScrollPanel:SetSizeY( Controls.BottomPanel:GetSizeY() - ART_BUFFER_SCROLLAREA );
	Controls.ItemScrollPanel:CalculateInternalSize();
	Controls.ItemScrollPanel:ReprocessAnchoring();

	Controls.AutoRenewCheckBox:SetCheck(g_bAutoRenewFlag);
end

-------------------------------------------------
-------------------------------------------------
function OnPopupMessage(popupInfo)
	local popupType = popupInfo.Type;
	if popupType ~= ButtonPopupTypes.BUTTONPOPUP_CHOOSE_INTERNATIONAL_TRADE_ROUTE then
		return;
	end	
	
	g_PopupInfo = popupInfo;
	
	g_iUnitIndex = popupInfo.Data2;
   	UIManager:QueuePopup( ContextPtr, PopupPriority.SocialPolicy );
	UI.SetTradeRouteVisibleMode(true );

end
Events.SerialEventGameMessagePopup.Add( OnPopupMessage );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    ----------------------------------------------------------------        
    -- Key Down Processing
    ----------------------------------------------------------------        
    if uiMsg == KeyEvents.KeyDown then
        if (wParam == Keys.VK_ESCAPE) then
			if(not Controls.ChooseConfirm:IsHidden()) then
				Controls.ChooseConfirm:SetHide(true);
			else
				OnClose();
			end
        	return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function TradeOverview()
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_TRADE_ROUTE_OVERVIEW,
	}
	Events.SerialEventGameMessagePopup(popupInfo);
end
Controls.TradeOverviewButton:RegisterCallback( Mouse.eLClick, TradeOverview );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
	Events.ClearHexHighlightStyle(g_invalidPlotMiasmaStyle);
    UIManager:DequeuePopup(ContextPtr);
	UI.SetTradeRouteVisibleMode(OptionsManager.GetShowTradeOn());

end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function RefreshData()
	
	local iActivePlayer = Game.GetActivePlayer();
	local pPlayer = Players[iActivePlayer];
	local pUnit = pPlayer:GetUnitByID(g_iUnitIndex);
	if (pUnit == nil) then
		return;
	end
	
	local pOriginPlot	= pUnit:GetPlot();
	local pOriginCity	= pOriginPlot:GetPlotCity();	
	local eDomain		= pUnit:GetDomainType();		
	local unitType		= pUnit:GetUnitType();
	local unitInfo		= GameInfo.Units[unitType];
	
	local originCityName : string = pOriginCity:GetName();

	local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(unitType, pPlayer:GetID());
	IconHookup(portraitOffset, 64, portraitAtlas, Controls.TradeUnitIcon);
	
	Controls.StartingCity:LocalizeAndSetText("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_STARTING_CITY", originCityName);
	Controls.UnitInfo:LocalizeAndSetText("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_TRADE_UNIT", pUnit:GetName());

	local sortByPulldown = Controls.SortByPullDown;
	sortByPulldown:ClearEntries();
	for i, v in ipairs(g_SortOptions) do
		local controlTable = {};
		sortByPulldown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText(v[1]);
		
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			sortByPulldown:GetButton():LocalizeAndSetText(v[1]);
			g_CurrentSortOption = i;
			
			SortData();
			DisplayData();
		end);
	end
	sortByPulldown:CalculateInternals();
	sortByPulldown:GetButton():LocalizeAndSetText(g_SortOptions[g_CurrentSortOption][1]);

	
	local map = Map;

	g_Model = {};
	g_Unit = pUnit;
	
	local potentialTradeSpots = pPlayer:GetUnitAvailableTradeRoutes(pUnit);
	for i,v in ipairs(potentialTradeSpots) do
		
		local tradeRoute = {
			PlotX = v.DestX,
			PlotY = v.DestY,
			TradeConnectionType = v.TradeConnectionType
		};
		
		-- Site Plot
		local pTargetPlot = map.GetPlot(v.DestX, v.DestY);
		-- Site Owner ID
		local iTargetOwner = v.DestPlayerID;
		-- Site Name
		tradeRoute.RouteName = v.DestSiteName;
		-- Site Player
		local pTargetPlayer = Players[iTargetOwner];
		-- Site Civ Name
		if (v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_STATION) then
			tradeRoute.CivName = Locale.Lookup("TXT_KEY_TRADE_ROUTE_DEFAULT_STATION_CIV_NAME");
		else
			tradeRoute.CivName = pTargetPlayer:GetCivilizationDescription();
		end
		
		if (v.OldTradeRoute) then
			tradeRoute.Category = 1;	-- Previous Route
		elseif(iTargetOwner == iActivePlayer) then
			if (pTargetPlot:IsCity()) then
				tradeRoute.Category = 2;	-- Your Cities
			elseif (pTargetPlot:IsOutpost()) then
				tradeRoute.Category = 3;	-- Your Outposts
			end
		elseif (iTargetOwner < GameDefines.MAX_MAJOR_CIVS) then
			tradeRoute.Category = 4;	-- Other Civ Cities
		elseif (pTargetPlot:IsStation()) then
			tradeRoute.Category = 5;	-- Station
		end
		
		local myBonuses = {};
		local theirBonuses = {};
		if (v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_INTERNATIONAL or 
			v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_INTERNAL_CITY or
			v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_STATION) then

			if (v.Yields ~= nil) then
				print("Trade Effect: Yield");
				for j,u in ipairs(v.Yields) do
					local iYield = j - 1;
					local entry = GetYieldTradeRouteTip(iYield);

					local iMyYield = math.floor(u.Mine / 100);
					local iTheirYield = math.floor(u.Theirs / 100);

					if(iMyYield ~= 0) then
						table.insert(myBonuses, "[ICON_ARROW_LEFT] " .. Locale.Lookup(entry, iMyYield));
					end
				
					if(iTheirYield ~= 0) then
						table.insert(theirBonuses, "[ICON_ARROW_RIGHT] " .. Locale.Lookup(entry, iTheirYield));
					end
				end
			end

			-- Stations may have other effects to display
			local station = pTargetPlot:GetPlotStation();
			if (station ~= nil) then
				local extraEffectSummary = station:GetTradePopupSummary();
				if (extraEffectSummary ~= "") then
					table.insert(myBonuses, extraEffectSummary);
				end
			end

		elseif (v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_OUTPOST) then

			print("Trade Effect: Outpost Growth");
			table.insert(theirBonuses, Locale.Lookup("TXT_KEY_OUTPOST_TRADE_ROUTE_PERCENT_GROWTH", v.OutpostGrowthMod));

		end	
		
		local strOutput = "";
		if(#myBonuses > 0) then
			local strCityGain = Locale.Lookup("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_CITY_WILL_GAIN", originCityName);
			strOutput = strCityGain .. "[NEWLINE]" .. table.concat(myBonuses, "[NEWLINE]") .. "[NEWLINE]"
		end

		if (#theirBonuses > 0) then
			local strCityGain = Locale.Lookup("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_CITY_WILL_GAIN", v.DestSiteName);
			strOutput = strOutput .. strCityGain .. "[NEWLINE]" .. table.concat(theirBonuses, "[NEWLINE]");
		end
		
		tradeRoute.Bonuses = strOutput;
		tradeRoute.TargetPlayerId = pTargetPlayer:GetID();
		tradeRoute.eDomain = eDomain;
		tradeRoute.Yields = v.Yields;
		
		table.insert(g_Model, tradeRoute);
	end

	-- Highlight invalid trade plots
	local bHighlightMiasma : boolean = pPlayer:GetGeneralUnitMiasmaHealthDelta() < 0;

	for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do

		local pPlot = Map.GetPlotByIndex(iPlotLoop);
		local hexID = ToHexFromGrid(Vector2(pPlot:GetX(), pPlot:GetY()));

		if pPlot:IsVisible(pPlayer:GetTeam(), false) then

			if (bHighlightMiasma and pPlot:HasMiasma()) then
				Events.SerialEventHexHighlight(hexID, true, g_invalidPlotMiasmaColor, g_invalidPlotMiasmaStyle);
			end
		end
	end 	
end



function SortBySiteName(a, b)
	return Locale.Compare(a.RouteName, b.RouteName) == -1;
end

function SortByCivName(a, b)
	local result = Locale.Compare(a.CivName, b.CivName);
	if(result == 0) then
		return SortBySiteName(a,b);
	else
		return result == -1;
	end
end

function SortByNearest(a, b)
	if g_Unit == nil then
		return;
	end

	local pPlot = g_Unit:GetPlot();
	local distA = Map.PlotDistance(pPlot:GetX(), pPlot:GetY(), a.PlotX, a.PlotY);
	local distB = Map.PlotDistance(pPlot:GetX(), pPlot:GetY(), b.PlotX, b.PlotY);
	return distA < distB;
end

function SortByMaxYield(a, b, yieldType)
	if(a.Yields ~= nil and b.Yields~= nil) then
		local yieldTableIndex = yieldType+1;
		local yieldDataA = a.Yields[yieldTableIndex];
		local yieldDataB = b.Yields[yieldTableIndex];
		return yieldDataA.Mine > yieldDataB.Mine;
	end

	return false;
end

function SortByYieldDelta(a, b, yieldType)
	if(a.Yields ~= nil and b.Yields~= nil) then
		local yieldTableIndex = yieldType+1;
		local yieldDataA = a.Yields[yieldTableIndex];
		local yieldDataB = b.Yields[yieldTableIndex];
		local yieldDeltaA = yieldDataA.Mine - yieldDataA.Theirs;
		local yieldDeltaB = yieldDataB.Mine - yieldDataB.Theirs;
		return yieldDeltaA > yieldDeltaB;
	end

	return false;
end

function SortByMaxEnergy(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_ENERGY);
end

function SortByEnergyDelta(a, b)
	return SortByYieldDelta(a, b, YieldTypes.YIELD_ENERGY);
end

function SortByMaxScience(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_SCIENCE);
end

function SortByScienceDelta(a, b)
	return SortByYieldDelta(a, b, YieldTypes.YIELD_SCIENCE);
end

function SortByMaxFood(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_FOOD);
end

function SortByMaxProduction(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_PRODUCTION);
end

g_SortOptions = {
	{"TXT_KEY_PEDIA_CIVILIZATION_NAME", SortByCivName},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_CITYNAME", SortBySiteName},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_NEAREST", SortByNearest},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_ENERGY", SortByMaxEnergy},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_ENERGY_DELTA", SortByEnergyDelta}, 
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_SCIENCE", SortByMaxScience},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_SCIENCE_DELTA", SortByScienceDelta},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_FOOD", SortByMaxFood},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_PRODUCTION", SortByMaxProduction},
}
g_CurrentSortOption = 1;

function SortData()
	table.sort(g_Model, g_SortOptions[g_CurrentSortOption][2]);
end


function DisplayData()
	
	for _, itemManager in ipairs(g_ItemManagers) do
		itemManager:ResetInstances();
	end
		
	local showPreviousRoute : boolean = false;

	for _, tradeRoute in ipairs(g_Model) do
		
		local itemInstance = g_ItemManagers[tradeRoute.Category]:GetInstance();
		if (tradeRoute.Category == 1) then
			showPreviousRoute = true;
		end
		
		itemInstance.RouteName:SetText(tradeRoute.RouteName);		
		itemInstance.Bonuses:SetText(tradeRoute.Bonuses);

		SimpleCivIconHookup(tradeRoute.TargetPlayerId, 64, itemInstance.CivIcon);
		itemInstance.Button:RegisterCallback(Mouse.eLClick, function() SelectTradeDestinationChoice(tradeRoute.PlotX, tradeRoute.PlotY, tradeRoute.TradeConnectionType); end);
		itemInstance.Button:SetToolTipString(tradeRoute.ToolTip);
		
		local buttonWidth, buttonHeight = itemInstance.Button:GetSizeVal();
		--local descWidth, descHeight = itemInstance.Bonuses:GetSizeVal();

		itemInstance.DetailsStack:ReprocessAnchoring();
		itemInstance.DetailsStack:CalculateSize();
		local descWidth, descHeight = itemInstance.DetailsStack:GetSizeVal();
		
		local newHeight = math.max(80, descHeight + 20);	
		
		itemInstance.Button:SetSizeVal(buttonWidth, newHeight);
		--itemInstance.Box:SetSizeVal(buttonWidth, newHeight);
				
		itemInstance.GoToCity:RegisterCallback(Mouse.eLClick, function() 
			local plot = Map.GetPlot(tradeRoute.PlotX, tradeRoute.PlotY);
			UI.LookAt(plot, 0);  
		end);
		
		itemInstance.Button:RegisterCallback(Mouse.eMouseEnter, function() Game.SelectedUnit_SpeculativePopupTradeRoute_Display(tradeRoute.PlotX, tradeRoute.PlotY, tradeRoute.TradeConnectionType, tradeRoute.eDomain); end);
		itemInstance.Button:RegisterCallback(Mouse.eMouseExit, function() Game.SelectedUnit_SpeculativePopupTradeRoute_Hide(tradeRoute.PlotX, tradeRoute.PlotY, tradeRoute.TradeConnectionType); end);
	end

	if (showPreviousRoute) then
		Controls.PreviousRouteLabel:SetHide(false);
	else
		Controls.PreviousRouteLabel:SetHide(true);
	end

	Controls.PreviousRouteStack:CalculateSize();
	Controls.PreviousRouteStack:ReprocessAnchoring();
	Controls.YourCitiesStack:CalculateSize();
	Controls.YourCitiesStack:ReprocessAnchoring();
	Controls.YourOutpostsStack:CalculateSize();
	Controls.YourOutpostsStack:ReprocessAnchoring();
	Controls.OtherCivsStack:CalculateSize();
	Controls.OtherCivsStack:ReprocessAnchoring();
	Controls.StationsStack:CalculateSize();
	Controls.StationsStack:ReprocessAnchoring();
	Controls.ItemStack:CalculateSize();
	Controls.ItemStack:ReprocessAnchoring();
	Controls.ItemScrollPanel:CalculateInternalSize();

end

function SelectTradeDestinationChoice(iPlotX, iPlotY, iTradeConnectionType) 
	g_selectedPlotX = iPlotX;
	g_selectedPlotY = iPlotY;
	g_selectedTradeType = iTradeConnectionType;
	
	Controls.ChooseConfirm:SetHide(false);
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnConfirmYes( )
	Controls.ChooseConfirm:SetHide(true);
	
	local kPlot = Map.GetPlot( g_selectedPlotX, g_selectedPlotY );	
	Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_ESTABLISH_TRADE_ROUTE, kPlot:GetPlotIndex(), g_selectedTradeType, g_bAutoRenewFlag, false, nil);
		
	Events.AudioPlay2DSound("AS2D_INTERFACE_TRADE_ROUTE_CONFIRM");	
	
	OnClose();	
end
Controls.ConfirmYes:RegisterCallback( Mouse.eLClick, OnConfirmYes );

function OnConfirmNo( )
	Controls.ChooseConfirm:SetHide(true);
end
Controls.ConfirmNo:RegisterCallback( Mouse.eLClick, OnConfirmNo );


----------------------------------------------------------------
----------------------------------------------------------------
function OnAutoRenewCheck( bIsChecked )
	if (bIsChecked) then
		g_bAutoRenewFlag = 1;
	else
		g_bAutoRenewFlag = 0;
	end
end
Controls.AutoRenewCheckBox:RegisterCheckHandler(OnAutoRenewCheck);

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

	m_bHidden = bIsHide;
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(g_PopupInfo);
        	
        	RefreshData();
        	SortData();
        	DisplayData();
        
			local unitPanel = ContextPtr:LookUpControl( "/InGame/WorldView/UnitPanel/Base" );
			if( unitPanel ~= nil ) then
				unitPanel:SetHide( true );
			end
			
			local infoCorner = ContextPtr:LookUpControl( "/InGame/WorldView/InfoCorner" );
			if( infoCorner ~= nil ) then
				infoCorner:SetHide( true );
			end
               	
        else
      
			local unitPanel = ContextPtr:LookUpControl( "/InGame/WorldView/UnitPanel/Base" );
			if( unitPanel ~= nil ) then
				unitPanel:SetHide(false);
			end
			
			local infoCorner = ContextPtr:LookUpControl( "/InGame/WorldView/InfoCorner" );
			if( infoCorner ~= nil ) then
				infoCorner:SetHide(false);
			end
			
			if(g_PopupInfo ~= nil) then
				Events.SerialEventGameMessagePopupProcessed.CallImmediate(g_PopupInfo.Type, 0);
			end
            UI.decTurnTimerSemaphore();
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

function OnDirty()
	-- If the user performed any action that changes selection states, just close this UI.
	if not m_bHidden then
		OnClose();
	end
end
Events.UnitSelectionChanged.Add( OnDirty );


function OnCollapseExpand()
	Controls.PreviousRouteStack:CalculateSize();
	Controls.PreviousRouteStack:ReprocessAnchoring();
	Controls.YourCitiesStack:CalculateSize();
	Controls.YourCitiesStack:ReprocessAnchoring();
	Controls.YourOutpostsStack:CalculateSize();
	Controls.YourOutpostsStack:ReprocessAnchoring();
	Controls.OtherCivsStack:CalculateSize();
	Controls.OtherCivsStack:ReprocessAnchoring();
	Controls.StationsStack:CalculateSize();
	Controls.StationsStack:ReprocessAnchoring();
	Controls.ItemStack:CalculateSize();
	Controls.ItemStack:ReprocessAnchoring();
	Controls.ItemScrollPanel:CalculateInternalSize();
end

RegisterCollapseBehavior{	
	Header = Controls.YourCitiesHeader, 
	HeaderLabel = Controls.YourCitiesHeaderLabel, 
	HeaderExpandedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_YOUR_CITIES"),
	HeaderCollapsedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_YOUR_CITIES_COLLAPSED"),
	Panel = Controls.YourCitiesStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};

RegisterCollapseBehavior{	
	Header = Controls.YourOutpostsHeader, 
	HeaderLabel = Controls.YourOutpostsHeaderLabel, 
	HeaderExpandedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_YOUR_OUTPOSTS"),
	HeaderCollapsedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_YOUR_OUTPOSTS_COLLAPSED"),
	Panel = Controls.YourOutpostsStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};
							
RegisterCollapseBehavior{
	Header = Controls.OtherCivsHeader,
	HeaderLabel = Controls.OtherCivsHeaderLabel,
	HeaderExpandedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_OTHER_CIVS"),
	HeaderCollapsedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_OTHER_CIVS_COLLAPSED"),
	Panel = Controls.OtherCivsStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};

RegisterCollapseBehavior{
	Header = Controls.StationsHeader,
	HeaderLabel = Controls.StationsHeaderLabel,
	HeaderExpandedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_STATIONS"),
	HeaderCollapsedLabel = Locale.Lookup("TXT_KEY_CHOOSE_TRADE_ROUTE_STATIONS_COLLAPSED"),
	Panel = Controls.StationsStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};


Initialize();