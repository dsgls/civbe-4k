-------------------------------------------------
-- Trade Overview Popup
-------------------------------------------------
include( "IconSupport" );
include("TabSupport");
include( "InstanceManager" );
include( "TradeRouteHelpers" );

local g_PopupInfo = nil;

-------------------------------------------------
-- Global Variables
-------------------------------------------------
local g_CurrentTab = "YourTR";		-- The currently selected Tab.
local g_iSelectedPlayerID = Game.GetActivePlayer();
local m_tabs;
local g_Data = nil;

-------------------------------------------------
-- Global Constants
-------------------------------------------------

local g_SortOptions = {
	{
		Button = Controls.FromOwnerHeader,
		Column = "FromCiv",
		SecondaryColumn = "OriginSiteName",
		SecondaryDirection = "asc",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.FromCityHeader,
		Column = "OriginSiteName",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.ToOwnerHeader,
		Column = "ToCiv",
		SecondaryColumn = "DestSiteName",
		SecondaryDirection = "asc",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.ToCityHeader,
		Column = "DestSiteName",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.AutoRenew,
		Column = "AutoRenew",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.TurnsLeft,
		Column = "TurnsLeft",
		DefaultDirection = "asc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
};
g_SortFunction = nil;

g_RouteSortOptions = {
	{"TXT_KEY_ROUTE_DESCRIPTION", SortBySiteName},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_ENERGY", SortByMaxEnergy},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_ENERGY_DELTA", SortByEnergyDelta}, 
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_SCIENCE", SortByMaxScience},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_SCIENCE_DELTA", SortByScienceDelta},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_FOOD", SortByMaxFood},
	{"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_SORT_MAX_PRODUCTION", SortByMaxProduction},
	{"TXT_KEY_TRADE_ROUTE_SORT_MAX_RESOURCES", SortByMaxResources},
	{"TXT_KEY_TRADE_ROUTE_SORT_MAX_RESOURCES_DELTA", SortByResourceDelta},
}
g_CurrentRouteSortOption = 1;

-------------------------------------------------------------------------------
-- Sorting Support
-------------------------------------------------------------------------------
function AlphabeticalSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == -1;
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == 1;
			end
		end
	end
end

function NumericSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;
			
			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(va) < tonumber(vb);
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;

			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(vb) < tonumber(va);
			end
		end
	end
end

-- Registers the sort option controls click events
function RegisterSortOptions()
	
	for i,v in ipairs(g_SortOptions) do
		if(v.Button ~= nil) then
			v.Button:RegisterCallback(Mouse.eLClick, function() SortOptionSelected(v); end);
		end
	end
	
	g_SortFunction = GetSortFunction(g_SortOptions);
end

function GetSortFunction(sortOptions)
	local orderBy = nil;
	for i,v in ipairs(sortOptions) do
		if(v.CurrentDirection ~= nil) then
			local secondarySort = nil;
			if(v.SecondaryColumn ~= nil) then
				if(v.SecondarySortType == "numeric") then
					secondarySort = NumericSortFunction(v.SecondaryColumn, v.SecondaryDirection)
				else
					secondarySort = AlphabeticalSortFunction(v.SecondaryColumn, v.SecondaryDirection);
				end
			end
		
			if(v.SortType == "numeric") then
				return NumericSortFunction(v.Column, v.CurrentDirection, secondarySort);
			else
				return AlphabeticalSortFunction(v.Column, v.CurrentDirection, secondarySort);
			end
		end
	end
	
	return nil;
end

-- Updates the sort option structure
function UpdateSortOptionState(sortOptions, selectedOption)
	-- Current behavior is to only have 1 sort option enabled at a time 
	-- though the rest of the structure is built to support multiple in the future.
	-- If a sort option was selected that wasn't already selected, use the default 
	-- direction.  Otherwise, toggle to the other direction.
	for i,v in ipairs(sortOptions) do
		if(v == selectedOption) then
			if(v.CurrentDirection == nil) then			
				v.CurrentDirection = v.DefaultDirection;
			else
				if(v.CurrentDirection == "asc") then
					v.CurrentDirection = "desc";
				else
					v.CurrentDirection = "asc";
				end
			end
		else
			v.CurrentDirection = nil;
		end
	end
end

-- Callback for when sort options are selected.
function SortOptionSelected(option)
	local sortOptions = g_SortOptions;
	UpdateSortOptionState(sortOptions, option);
	g_SortFunction = GetSortFunction(sortOptions);
	
	SortData();
	DisplayData();
end

-------------------------------------------------
--Initialize the window
-------------------------------------------------
function OnPopupMessage(popupInfo)

	local popupType = popupInfo.Type;
	if popupType ~= ButtonPopupTypes.BUTTONPOPUP_TRADE_ROUTE_OVERVIEW then
		return;
	end
	
	g_PopupInfo = popupInfo;

	-- Data 2 parameter holds desired tab to open on
	if (g_PopupInfo.Data2 == 1) then
		m_tabs.SelectTab(Controls.TabButtonYourTR);
	elseif (g_PopupInfo.Data2 == 2) then
		m_tabs.SelectTab( Controls.TabButtonAvailableTR);
	elseif (g_PopupInfo.Data2 == 3) then
		m_tabs.SelectTab( Controls.TabButtonTRWithYou);
	else
		m_tabs.SelectTab(Controls.TabButtonYourTR);
	end

	
	if( g_PopupInfo.Data1 == 1 ) then
    	if( ContextPtr:IsHidden() == false ) then
    		OnClose();
		else
        	UIManager:QueuePopup( ContextPtr, PopupPriority.InGameUtmost );
    	end
	else
		UIManager:QueuePopup( ContextPtr, PopupPriority.SocialPolicy );
	end
end
Events.SerialEventGameMessagePopup.Add( OnPopupMessage );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function IgnoreLeftClick( Id )
	-- just swallow it
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    ----------------------------------------------------------------        
    -- Key Down Processing
    ----------------------------------------------------------------        
    if(uiMsg == KeyEvents.KeyDown) then
        if (wParam == Keys.VK_ESCAPE) then
			OnClose();
			return true;
        end
        
        -- Do Nothing.
        if(wParam == Keys.VK_RETURN) then
			return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function RefreshYourTR()
	local pPlayer = Players[ Game.GetActivePlayer() ];
	g_CurrentTab = "YourTR";
	SetData(pPlayer:GetAllActiveTradeRoutes());
	SortData();
	DisplayData();
	
end
--g_Tabs["YourTR"].RefreshContent = RefreshYourTR;

-- Shows all routes currently available to be established
function RefreshAvailableTR()
	local pPlayer = Players[ Game.GetActivePlayer() ];
	g_CurrentTab = "AvailableTR"; 
    SetData(pPlayer:GetAllPotentialTradeRoutes(false));
	SortData();
	DisplayData();
end
--g_Tabs["AvailableTR"].RefreshContent = RefreshAvailableTR;

-- Shows all trade routes established with the active player by another player
function RefreshTRWithYou()
	local pPlayer = Players[ Game.GetActivePlayer() ];
    g_CurrentTab = "TRWithYou";
    SetData(pPlayer:GetTradeRoutesToYou());
    SortData();
    DisplayData();
    
end
--g_Tabs["TRWithYou"].RefreshContent = RefreshTRWithYou;


function SetData(data)

	function GetCivName(civID )
		local civ = GameInfo.Civilizations[civID];
		return Locale.Lookup(civ.Description);
	end
	
	for i,v in ipairs(data) do
		v.FromCiv = GetCivName(v.OriginCivilizationType);
		v.ToCiv = GetCivName(v.DestCivilizationType);
	end
	g_Data = data;
end

function SortData()
	if (g_Data ~= nil) then
		table.sort(g_Data, g_SortFunction);
	end
end

function round(num, idp)
  return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function DisplayData()
	Controls.MainStack:DestroyAllChildren(); 

	if (g_Data ~= nil) then
		for i,v in ipairs(g_Data) do

			local instance = {};
			ContextPtr:BuildInstanceForControl( "TRInstance", instance, Controls.MainStack );
	
			instance.Domain_Land:LocalizeAndSetToolTip("TXT_KEY_TRO_LAND_DOMAIN_TT"); 
			instance.Domain_Sea:LocalizeAndSetToolTip("TXT_KEY_TRO_SEA_DOMAIN_TT"); 	
	
			instance.Domain_Land:SetHide(false);
		
			--SimpleCivIconHookup(v.OriginPlayerID, 32, instance.FromCivIcon);
			CivIconHookup( v.OriginPlayerID, 32, instance.FromCivIcon, instance.FromCivIconBG, nil, false, false, instance.FromCivIconHighlight );
			
			instance.FromCivIcon:SetToolTipString(v.FromCiv);
			instance.FromCity:SetText(v.OriginSiteName);
			instance.FromCity:SetToolTipString(strTT);
		
			--SimpleCivIconHookup(v.DestPlayerID, 32, instance.ToCivIcon);
			CivIconHookup( v.DestPlayerID, 32, instance.ToCivIcon, instance.ToCivIconBG, nil, false, false, instance.ToCivIconHighlight );
			instance.ToCivIcon:SetToolTipString(v.ToCiv);
			instance.ToSite:SetText(v.DestSiteName);
			instance.ToSite:SetToolTipString(strTT);
		
			if (g_CurrentTab == "AvailableTR") then
				instance.TurnsLeft:SetHide(true);
				instance.AutoRenew:SetHide(true);
			else
				if (v.TurnsLeft ~= nil and v.TurnsLeft >= 0) then
					instance.TurnsLeft:SetHide(false);
					instance.TurnsLeft:SetText(v.TurnsLeft);
				end

				if (v.AutoRenew ~= nil) then
					instance.AutoRenew:SetHide(false);
					instance.AutoRenew:SetCheck(v.AutoRenew);

					local capturedValue : table = v;
					instance.AutoRenew:RegisterCheckHandler(function(bCheck)
						if (capturedValue.ID ~= nil) then
							Game.SetTradeRouteAutoRenew(capturedValue.ID, bCheck);
						end
					end);
				end
			end

			local bOutboundArrows : boolean = Game.GetActivePlayer() == v.OriginPlayerID;

			-- Trade Route Information String
			-- dependent on type of route (city/station/outpost)
			local tradeRouteInfoStr = "";

			local myBonuses = {};
			local theirBonuses = {};

			if (v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_INTERNATIONAL or 
				v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_INTERNAL_CITY or
				v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_STATION) then
			
				local pDestPlot = Map.GetPlot(v.DestX, v.DestY);

				if (v.Yields ~= nil) then

					for j,u in ipairs(v.Yields) do

						local iYield = j - 1;			
						local yieldInfo = GameInfo.Yields[iYield];

						if(u.Mine ~= 0) then
							table.insert(myBonuses, yieldInfo.IconString .. " " .. math.floor(u.Mine / 100));
						end
				
						if(u.Theirs ~= 0) then
							table.insert(theirBonuses, yieldInfo.IconString .. " " .. math.floor(u.Theirs / 100));
						end
					end
				end

				if (v.Resources ~= nil) then
					for j,u in ipairs(v.Resources) do
						local resourceType : number = u.Type;
						local myRate : number = u.Mine;
						local theirRate : number = u.Theirs;

						if (myRate > 0) then
							--local lineItem : string = GetResourceTradeRouteTip(resourceType, myRate);
							--table.insert(myBonuses, "[ICON_ARROW_LEFT] " .. lineItem);
							table.insert(myBonuses, GameInfo.Resources[resourceType].IconString .. " " .. myRate);
						end

						if (theirRate > 0) then
							--local lineItem : string = GetResourceTradeRouteTip(resourceType, theirRate);
							--table.insert(theirBonuses, "[ICON_ARROW_RIGHT] " .. lineItem);
							table.insert(theirBonuses, GameInfo.Resources[resourceType].IconString .. " " .. theirRate);
						end
					end
				end

				if (#myBonuses > 0) then
					if (bOutboundArrows) then
						tradeRouteInfoStr = "[ICON_ARROW_LEFT] ";
					else
						tradeRouteInfoStr = "[ICON_ARROW_RIGHT] ";
					end
					 tradeRouteInfoStr = tradeRouteInfoStr ..  table.concat(myBonuses, " ");
				end

				if (#theirBonuses > 0) then
				
					if (#myBonuses > 0) then
						tradeRouteInfoStr = tradeRouteInfoStr .. "[NEWLINE]";
					end
					
					if (bOutboundArrows) then
						tradeRouteInfoStr = tradeRouteInfoStr .. "[ICON_ARROW_RIGHT] ";
					else
						tradeRouteInfoStr = tradeRouteInfoStr .. "[ICON_ARROW_LEFT] ";
					end
					tradeRouteInfoStr = tradeRouteInfoStr .. table.concat(theirBonuses, " ");
				end

				-- Stations may have other effects to display
				local station = pDestPlot:GetPlotStation();
				if (station ~= nil) then
					local extraEffectSummary = station:GetTradePopupSummary();
					if (extraEffectSummary ~= "") then
						if (tradeRouteInfoStr ~= "") then
							tradeRouteInfoStr = tradeRouteInfoStr .. "[NEWLINE]";
						end
						tradeRouteInfoStr = tradeRouteInfoStr .. extraEffectSummary;
					end
				end

			elseif (v.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_OUTPOST) then

				tradeRouteInfoStr = Locale.Lookup("TXT_KEY_OUTPOST_TRADE_ROUTE_PERCENT_GROWTH", v.OutpostGrowthMod);
			end

			instance.TradeRouteInfo:SetText(tradeRouteInfoStr);
			local height : number = instance.TradeRouteInfo:GetSizeY();
			local PADDING : number = 12;
			instance.Root:SetSizeY(height + PADDING);

			local sortByPulldown = Controls.SortByPullDown;
			sortByPulldown:ClearEntries();
			for i, v in ipairs(g_RouteSortOptions) do
				local controlTable = {};
				sortByPulldown:BuildEntry( "InstanceOne", controlTable );
				controlTable.Button:LocalizeAndSetText(v[1]);
		
				controlTable.Button:RegisterCallback(Mouse.eLClick, function()
					sortByPulldown:GetButton():LocalizeAndSetText(v[1]);
					g_CurrentRouteSortOption = i;
					g_SortFunction = v[2];			
					SortData();
					DisplayData();
				end);
			end
			sortByPulldown:CalculateInternals();
			sortByPulldown:GetButton():LocalizeAndSetText(g_RouteSortOptions[g_CurrentRouteSortOption][1]);
		end
	end

    Controls.MainStack:CalculateSize();
    Controls.MainStack:ReprocessAnchoring();
    Controls.MainScroll:CalculateInternalSize();

end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )
	-- Set Civ Icon
	SimpleCivIconHookup( Game.GetActivePlayer(), 64, Controls.CivIcon);
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();  
        	Events.SerialEventGameMessagePopupShown(g_PopupInfo);
        else
			if(g_PopupInfo ~= nil) then
				Events.SerialEventGameMessagePopupProcessed.CallImmediate(g_PopupInfo.Type, 0);
            end
            UI.decTurnTimerSemaphore();
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

function Initialize()
	m_tabs = CreateTabs( Controls.TabContainer, 64, 32 );
	m_tabs.AddTab( Controls.TabButtonYourTR, RefreshYourTR );
	m_tabs.AddTab( Controls.TabButtonAvailableTR, RefreshAvailableTR);
	m_tabs.AddTab( Controls.TabButtonTRWithYou, RefreshTRWithYou );
	m_tabs.EvenlySpreadTabs();
end

RegisterSortOptions();
Initialize();


