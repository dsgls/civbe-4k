-------------------------------------------------
-- Declare War Popup
-------------------------------------------------
include( "IconSupport" );
include( "InstanceManager" );
include( "CommonBehaviors" );

local g_AlliedCityStatesInstanceManager		= GenerationalInstanceManager:new( "CityStateInstance", "Base", Controls.AlliedCityStatesStack);
local g_UnderProtectionOfInstanceManager	= GenerationalInstanceManager:new( "UnderProtectionCivInstance", "Base", Controls.UnderProtectionOfStack);
local g_ActiveTradesInstanceManager			= GenerationalInstanceManager:new("TradeRouteInstance", "Base", Controls.TradeRoutesStack);

PopupLayouts = {};
PopupInputHandlers = {};
g_PopupInfo = nil;		-- The current popupinfo.


------------------------------------------------
-- Misc Utility Methods
------------------------------------------------
-- Hides popup window.
function HideWindow()
    UIManager:DequeuePopup( ContextPtr );
    ClearButtons();
end

-- Sets popup text.
function SetPopupText(popupText)
	Controls.PopupText:SetText(popupText);
end

-- Remove all buttons from popup.
function ClearButtons()
	local i = 1;
	repeat
		local button = Controls["Button"..i];
		if button then
			button:SetHide(true);
		end
		i = i + 1;
	until button == nil;
end

function HideAllInfoControls(bHide)
	
	Controls.UnderProtectionOfHeader:SetHide(bHide);
	Controls.UnderProtectionOfStack:SetHide(bHide);
	
	Controls.AlliedCityStatesHeader:SetHide(bHide);
	Controls.AlliedCityStatesStack:SetHide(bHide);
		
	Controls.ActiveDealsHeader:SetHide(bHide);
    Controls.ActiveDealsStack:SetHide(bHide);

	Controls.TradeRoutesHeader:SetHide(bHide);
	Controls.TradeRoutesStack:SetHide(bHide);

	Controls.DeclareWarDetailsScrollPanel:SetHide(bHide);
	Controls.DeclareWarDetailsStack:SetHide(bHide);

--	Controls.LeaderFrame:SetHide(bHide);
--	Controls.RivalFrame:SetHide(bHide);
	--Controls.WarAnim:SetHide(bHide);
			
	Controls.ButtonStack:ReprocessAnchoring();
	Controls.ButtonStack:CalculateSize();	
	
	local frameWidth, frameHeight = Controls.ButtonStackFrame:GetSizeVal();
	local stackWidth, stackHeight = Controls.ButtonStack:GetSizeVal();
	
	Controls.ButtonStackFrame:SetSizeVal(frameWidth, stackHeight + 160);	
	Controls.ButtonStackFrame:ReprocessAnchoring();
end

-- Add a button to popup.
-- NOTE: Current Limitation is 4 buttons
function AddButton(buttonText, buttonClickFunc, strToolTip, bPreventClose)
	local i = 1;
	repeat
		local button = Controls["Button"..i];
		if button and button:IsHidden() then
			local buttonLabel = Controls["Button"..i.."Text"];
			buttonLabel:SetText( buttonText );
			
			button:SetToolTipString(strToolTip);

			--By default, button clicks will hide the popup window after
			--executing the click function
			local clickHandler = function()
				if buttonClickFunc ~= nil then
					buttonClickFunc();
				end
				
				HideWindow();
			end
			local clickHandlerPreventClose = function()
				if buttonClickFunc ~= nil then
					buttonClickFunc();
				end
			end
			
			-- This is only used in one case, when viewing a captured city (PuppetCityPopup)
			if (bPreventClose) then
				button:RegisterCallback(Mouse.eLClick, clickHandlerPreventClose);
			else
				button:RegisterCallback(Mouse.eLClick, clickHandler);
			end
			
			button:SetHide(false);
			
			return;
		end
		i = i + 1;
	until button == nil;
end

-------------------------------------------------
-- On Display
-------------------------------------------------
function OnDisplay(popupInfo)
	
	g_PopupInfo = popupInfo;
	-- Initialize popups
	local initialize = PopupLayouts[popupInfo.Type];
	if initialize then
		ClearButtons();
		if(initialize(popupInfo)) then
			if(popupInfo.Option1) then
				UIManager:QueuePopup( ContextPtr, PopupPriority.LeaderHeadPopup);
			else
				UIManager:QueuePopup( ContextPtr, PopupPriority.GenericPopup );		
			end
		end
		
	end
end
Events.SerialEventGameMessagePopup.Add( OnDisplay );


-------------------------------------------------
-- Keyboard Handler
-------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )

	----------------------------------------------------------------        
    -- Key Down Processing
    ----------------------------------------------------------------        
    if(uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE) then
        HideWindow();
	    return true;
    end
end
ContextPtr:SetInputHandler( InputHandler );


function GatherData(RivalId, Text)
	local data = {};
	
	data.Text = Text;
	
	data.LeaderId = Game.GetActivePlayer();

	local activePlayer = Players[data.LeaderId];	
	local leader = GameInfo.Leaders[activePlayer:GetLeaderType()];
	
	data.LeaderIcon = {
		PortraitIndex = leader.PortraitIndex,
		IconAtlas = leader.IconAtlas
	};
	
	data.RivalId = RivalId;
	local rivalPlayer = Players[data.RivalId];
	
	local rivalCiv = GameInfo.Civilizations[rivalPlayer:GetCivilizationType()];
	if(rivalCiv.Type == "CIVILIZATION_MINOR") then
		data.RivalIsMinor = true;	
	else
		data.RivalIsMinor = false;
		local rivalLeader = GameInfo.Leaders[rivalPlayer:GetLeaderType()];
	
		data.RivalIcon = {
			PortraitIndex = rivalLeader.PortraitIndex,
			IconAtlas = rivalLeader.IconAtlas
		};
	end
		
	-- Rival Civ + his Allies
	local rivalIDs = {
		[RivalId] = true,
	};
	
	data.AlliedCityStates = {};
	
	for iPlayerLoop = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS - 1, 1 do	
		local cityState = Players[iPlayerLoop];
		if(cityState and cityState:GetAlly() == RivalId) then
			rivalIDs[iPlayerLoop] = true;
			local playerColor = GameInfo.PlayerColors[cityState:GetPlayerColor()];
			local primaryColor = GameInfo.Colors[playerColor.PrimaryColor];
			local secondaryColor = GameInfo.Colors[playerColor.SecondaryColor];
			table.insert(data.AlliedCityStates, {
				PlayerID = iPlayerLoop,
				Name = cityState:GetCivilizationDescriptionKey(),
				PrimaryColor = primaryColor,
				SecondaryColor = secondaryColor,
			});
		end
	end
	
	data.UnderProtectionOf = {};
	if(data.RivalIsMinor) then
		for iPlayerLoop = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do	
			local player = Players[iPlayerLoop];
			if(player and player:IsAlive() and player:IsProtectingMinor(RivalId)) then
				table.insert(data.UnderProtectionOf, {
					PlayerID = iPlayerLoop,
					Name = player:GetCivilizationShortDescriptionKey(),
				});
			end
		end	
	end
	
	local dealsFromThem = {};
	local dealsFromUs = {};
	
	local ourResources = {};
	local theirResources = {};
	
	
	local iNumCurrentDeals = UI.GetNumCurrentDeals( data.LeaderId );    
    if( iNumCurrentDeals > 0 ) then
        for i = 0, iNumCurrentDeals - 1 do
			UI.LoadCurrentDeal( data.LeaderId, i );
			local deal = UI.GetScratchDeal();
			if(deal:GetOtherPlayer(data.LeaderId) == RivalId) then
				print("We have an active deal!");
				
				
				deal:ResetIterator();
				local itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayer = deal:GetNextItem();
    
				while(itemType ~= nil) do
					local bFromUs = (fromPlayer == data.LeaderId);
			        			        
					if( TradeableItems.TRADE_ITEM_GOLD_PER_TURN == itemType ) then
						if( bFromUs ) then
							local gpt = data1;
							local str = tostring(gpt) .. " " .. Locale.Lookup("TXT_KEY_DIPLO_GOLD_PER_TURN");
							table.insert(dealsFromUs, str);
						else
							local gpt = data1;
							local str = tostring(gpt) .. " " .. Locale.Lookup("TXT_KEY_DIPLO_GOLD_PER_TURN");
							table.insert(dealsFromThem, str);
						end	        			        
					elseif( TradeableItems.TRADE_ITEM_RESOURCES == itemType ) then
			        	local resource = GameInfo.Resources[data1];
						
						local str = Locale.Lookup("TXT_KEY_ACTIVE_DEAL_RESOURCE", data2, resource.IconString, resource.Description);
						if( bFromUs ) then
							table.insert(ourResources, str);
						else
							table.insert(theirResources, str);
						end
					end
					
					itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayer = deal:GetNextItem();
				end
			end
        end
    end
    
    if(#ourResources > 0) then
		table.insert(dealsFromUs, table.concat(ourResources, ", "));
    end
    
    if(#theirResources > 0) then
		table.insert(dealsFromThem, table.concat(theirResources, ", "));
    end
	
	data.DealsFromUs = table.concat(dealsFromUs, "[NEWLINE]");
	data.DealsFromThem = table.concat(dealsFromThem, "[NEWLINE]");	
	
	-- TODO Fix up

	--local tradeRoutes = {};
	--local myTrades = activePlayer:GetTradeRoutes();
	--local theirTrades = activePlayer:GetTradeRoutesToYou();
--
	--local bonusTips = {};
	--
	--local tips = {
		--{
			--Field = "GPT",
			--Description = "TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_GOLD",
		--},
		--{
			--Field = "Food",
			--Description = "TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_FOOD",
		--},
		--{
			--Field = "Production",
			--Description = "TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_PRODUCTION",
		--},
		--{
			--Field = "Science",
			--Description = "TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_SCIENCE",
		--},
	--}
	--
	--function GetBonusTips(tradeRoute, bonuses, arrowIcon, direction)
		--for i,v in ipairs(tips) do
			--local value = tradeRoute[direction .. v.Field];
			--if(value and value > 0) then
				--table.insert(bonuses, arrowIcon .. " " .. Locale.Lookup(v.Description, value/100));
			--end
		--end
	--end
--
	--for i,v in ipairs(myTrades) do
		--if(rivalIDs[v.ToID] == true) then
			--v.TargetPlayerId = v.ToID;
			--
			--local bonuses = {};
			--GetBonusTips(v, bonuses, "[ICON_ARROW_LEFT]", "From");
			--GetBonusTips(v, bonuses, "[ICON_ARROW_RIGHT]", "To"); 
			--
			--v.Bonuses = table.concat(bonuses, "[NEWLINE]");
			--
			--table.insert(tradeRoutes, v);
		--end
	--end	
	--
	--for i,v in ipairs(theirTrades) do
		--if(rivalIDs[v.FromID] == true) then
			--v.TargetPlayerId = v.FromID;
			--
			--local bonuses = {};
			--GetBonusTips(v, bonuses, "[ICON_ARROW_LEFT]", "To");
			--GetBonusTips(v, bonuses, "[ICON_ARROW_RIGHT]", "From"); 
			--
			--v.Bonuses = table.concat(bonuses, "[NEWLINE]");
			--
			--table.insert(tradeRoutes, v);
		--end
	--end
	--
	--data.TradeRoutes = tradeRoutes;

	return data;
end

function View(data)
	Controls.PopupText:SetText(data.Text);
		
	--IconHookup(data.LeaderIcon.PortraitIndex, 128, data.LeaderIcon.IconAtlas, Controls.LeaderIcon);           
	--CivIconHookup(Game.GetActivePlayer(), 64, Controls.LeaderSubIcon, Controls.LeaderSubIconBG, Controls.LeaderSubIconShadow, true, true, Controls.LeaderSubIconHighlight);
	--SimpleCivIconHookup( Game.GetActivePlayer(), 64, Controls.CivIcon );
	CivIconHookup(Game.GetActivePlayer(), 64, Controls.CivIcon, Controls.CivIconBG, nil, false, false, Controls.CivIconHighlight);
	
	if(data.RivalIsMinor) then
	
	    CivIconHookup(26, 64, Controls.CivRivalIcon, Controls.CivRivalIconBG, nil, false, false, Controls.CivRivalIconHighlight);
		--IconHookup( 26, 64, "CIV_COLOR_ATLAS", Controls.CivRivalIcon );
		
		
		Controls.AlliedCityStatesHeader:SetHide(true);
		Controls.AlliedCityStatesStack:SetHide(true);
		
		Controls.ActiveDealsHeader:SetHide(true);
        Controls.ActiveDealsStack:SetHide(true);
		
		Controls.UnderProtectionOfHeader:SetHide(false);
		Controls.UnderProtectionOfStack:SetHide(false);
	else
	    
	    local white = Vector4(1.0, 1.0, 1.0, 1.0);
	    --Controls.RivalIcon:SetColor(white);
		CivIconHookup(data.RivalId, 64, Controls.CivRivalIcon, Controls.CivRivalIconBG, nil, false, false, Controls.CivRivalIconHighlight);
		
		--Controls.RivalIconBG:SetHide(true);
		--Controls.RivalIconShadow:SetHide(true);
		--Controls.RivalSubIconFrame:SetHide(false);
		
		Controls.UnderProtectionOfHeader:SetHide(true);
		Controls.UnderProtectionOfStack:SetHide(true);
	
        Controls.ActiveDealsHeader:SetHide(false);
        Controls.ActiveDealsStack:SetHide(false);
		
		Controls.AlliedCityStatesHeader:SetHide(false);
		Controls.AlliedCityStatesStack:SetHide(false);
	end
	
	g_AlliedCityStatesInstanceManager:ResetInstances();
	local alliedCityStates = data.AlliedCityStates or {};
	Controls.AlliedCityStatesNone:SetHide(#alliedCityStates > 0);
	
	for i,v in ipairs(alliedCityStates) do
	
		local instance = g_AlliedCityStatesInstanceManager:GetInstance();	
		CivIconHookup(v.PlayerID, 45, instance.Icon, instance.IconBG, instance.IconShadow, true, true, instance.IconHighlight);
		
		instance.Label:SetColor({x = v.SecondaryColor.Red, y = v.SecondaryColor.Green, z = v.SecondaryColor.Blue, w = 1.0}, 0);
		
		local name = Locale.Lookup(v.Name);
		instance.Label:SetText(name);
		instance.IconFrame:SetToolTipString(name);
	end	
	
	g_UnderProtectionOfInstanceManager:ResetInstances();
	local underProtectionOf = data.UnderProtectionOf or {};
	Controls.UnderProtectionOfNone:SetHide(#underProtectionOf > 0);
	
	for i,v in ipairs(underProtectionOf) do
	
		local instance = g_UnderProtectionOfInstanceManager:GetInstance();	
		CivIconHookup(v.PlayerID, 45, instance.Icon, instance.IconBG, instance.IconShadow, true, true, instance.IconHighlight);
		
		local name = Locale.Lookup(v.Name);
		instance.Label:SetText(name);
		instance.IconFrame:SetToolTipString(name);
	end	
     
	local hasDeals = false;
	local hasDealsFromThem = false;
	local hasDealsFromUs = false;
	if(data.DealsFromThem and #data.DealsFromThem > 0) then
		Controls.DealsFromThemHeader:SetHide(false);
		Controls.DealsFromThem:SetHide(false);
		Controls.DealsFromThem:SetText(data.DealsFromThem);
		hasDeals = true;
		hasDealsFromThem = true;
	else
		Controls.DealsFromThemHeader:SetHide(true);
		Controls.DealsFromThem:SetHide(true);
	end
	
	if(data.DealsFromUs and #data.DealsFromUs > 0) then
		Controls.DealsFromYouHeader:SetHide(false);
		Controls.DealsFromYou:SetHide(false);
		Controls.DealsFromYou:SetText(data.DealsFromUs);
		hasDeals = true;
		hasDealsFromUs = true;
	else
		Controls.DealsFromYouHeader:SetHide(true);
		Controls.DealsFromYou:SetHide(true);
	end
	
	Controls.ActiveDealsNone:SetHide(hasDeals);
	Controls.DealsSeparator:SetHide(hasDealsFromThem == false or hasDealsFromUs == false);
			
	g_ActiveTradesInstanceManager:ResetInstances();
	local tradeRoutes = data.TradeRoutes or {};
	Controls.TradeRoutesNone:SetHide(#tradeRoutes > 0);
	for _, tradeRoute in ipairs(tradeRoutes) do
		
		local itemInstance = g_ActiveTradesInstanceManager:GetInstance();
		
		itemInstance.CityName:SetText(tradeRoute.FromCityName .. " [ICON_ARROW_RIGHT] " .. tradeRoute.ToCityName);		
		itemInstance.Bonuses:SetText(tradeRoute.Bonuses);
	
		CivIconHookup(tradeRoute.TargetPlayerId, 64, itemInstance.CivIcon, itemInstance.CivIconBG, itemInstance.CivIconShadow, true, true );
		itemInstance.Base:SetToolTipString(tradeRoute.ToolTip);
	
		local buttonWidth, buttonHeight = itemInstance.Base:GetSizeVal();
		local descWidth, descHeight = itemInstance.Bonuses:GetSizeVal();		
		local newHeight = math.max(80, descHeight + 40);	
		
		itemInstance.Base:SetSizeVal(buttonWidth, newHeight);
	end
		
	Controls.UnderProtectionOfStack:ReprocessAnchoring();
	Controls.UnderProtectionOfStack:CalculateSize();	
	Controls.AlliedCityStatesStack:ReprocessAnchoring();
	Controls.AlliedCityStatesStack:CalculateSize();
	Controls.ActiveDealsStack:ReprocessAnchoring();
	Controls.ActiveDealsStack:CalculateSize();
	Controls.TradeRoutesStack:ReprocessAnchoring();
	Controls.TradeRoutesStack:CalculateSize();
	
	Controls.DeclareWarDetailsStack:ReprocessAnchoring();
	Controls.DeclareWarDetailsStack:CalculateSize();
	
	Controls.DeclareWarDetailsScrollPanel:CalculateInternalSize();
	
	Controls.ButtonStack:ReprocessAnchoring();
	Controls.ButtonStack:CalculateSize();
	
	
	local frameWidth, frameHeight = Controls.ButtonStackFrame:GetSizeVal();
	local stackWidth, stackHeight = Controls.ButtonStack:GetSizeVal();
	
	Controls.ButtonStackFrame:SetSizeVal(frameWidth, stackHeight + 160);
	
	Controls.ButtonStackFrame:ReprocessAnchoring();
end

-- DECLARE WAR MOVE POPUP
-- This popup occurs when a team unit moves onto rival territory
-- or attacks an rival unit
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_DECLAREWAR_PLUNDER_TRADE_ROUTE] = function(popupInfo)
	local eRivalTeam = popupInfo.Data1;
	local eOtherTeam = popupInfo.Data2;
	local popupText;
	
	-- If there's no rival team, let the other popup handle the warning.
	if(eRivalTeam == nil or eRivalTeam == -1) then
		return false;
	end		
	
	--if (eOtherTeam ~= -1) then
	--	popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_DOES_THIS_MEAN_WAR_PLUS_PILLAGE_UPSET", Teams[eRivalTeam]:GetNameKey(), Teams[eOtherTeam]:GetNameKey());
	--else
		popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_DOES_THIS_MEAN_WAR", Teams[eRivalTeam]:GetNameKey());
	--end
	
	local data = GatherData(Teams[eRivalTeam]:GetLeaderID(), popupText);
	View(data);
	
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		-- Send War netmessage.
		Network.SendChangeWar(eRivalTeam, true);	
		
		-- Diplomatic response from AI
		if (not Teams[eRivalTeam]:IsMinorCiv() and not Teams[eRivalTeam]:IsHuman()) then
			if (not Game.IsNetworkMultiPlayer()) then
				Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_HUMAN_DECLARES_WAR, Teams[eRivalTeam]:GetLeaderID(), 0, 0 );
			end
		end
		
		if (eOtherTeam ~= -1) then
			Network.SendIgnoreWarning(eOtherTeam);
		end
		
		Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_PLUNDER_TRADE_ROUTE, -1, -1, 0, false, false);
	end
	
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_YES");
	AddButton(buttonText, OnYesClicked);
	
	-- Initialize 'no' button.
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_NO");
	AddButton(buttonText, nil);	
	
	return true;
end

-- ATTACK SITE POPUP
-- This popup occurs when a unit moves to attack an unaffiliated site (such as a station)
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_ATTACK_SITE] = function(popupInfo)
	local eAttackingTeam = popupInfo.Data1;
	local iX = popupInfo.Data2;
	local iY = popupInfo.Data3;
	local popupText;
	local eSiteType = -1;

	local plot = Map.GetPlot(iX, iY);
	if (plot) then
		-- Attacking a station?
		local station = plot:GetPlotStation();
		if (station ~= nil) then

			eSiteType = station:GetType();

			if (station:IsHostile(eAttackingTeam) ~= true) then
			
				popupText = Locale.ConvertTextKey("TXT_KEY_CONFIRM_ATTACK_STATION", station:GetNameKey());

				-- Initialize 'yes' button.
				local OnYesClicked = function()

					-- Send hostile netmessage.
					Network.SendChangeStationHostile(eSiteType, eAttackingTeam, true);
		
					-- Tell unit to move to position.
					if(plot ~= nil) then
						Game.SelectionListMove(plot, false, false, false);
					end
				end

				local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_YES");
				AddButton(buttonText, OnYesClicked);
	
				-- Initialize 'no' button.
				local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_NO");
				AddButton(buttonText, nil);

			end
		end
	end

	HideAllInfoControls(true);

	Controls.PopupText:SetText(popupText);
	CivIconHookup(Game.GetActivePlayer(), 64, Controls.CivIcon, Controls.CivIconBG, nil, false, false, Controls.CivIconHighlight);
	IconHookup(26, 64, "CIV_COLOR_ATLAS", Controls.CivRivalIconBG);    
	Controls.CivRivalIcon:SetHide( true );
	Controls.CivRivalIconHighlight:SetHide( true );

	-- The text can cause us to need to resize the popup.
	Controls.ButtonStack:ReprocessAnchoring();
	Controls.ButtonStack:CalculateSize();
		
	local frameWidth, frameHeight = Controls.ButtonStackFrame:GetSizeVal();
	local stackWidth, stackHeight = Controls.ButtonStack:GetSizeVal();
	
	Controls.ButtonStackFrame:SetSizeVal(frameWidth, stackHeight + 160);	
	Controls.ButtonStackFrame:ReprocessAnchoring();

	return true;
end

-- DECLARE WAR MOVE POPUP
-- This popup occurs when a team unit moves onto rival territory
-- or attacks an rival unit
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_DECLAREWARMOVE] = function(popupInfo)
	local eRivalTeam = popupInfo.Data1;
	local iX = popupInfo.Data2;
	local iY = popupInfo.Data3;
	
	local popupText;
	local plot;
	if(popupInfo.Option1 ~= true and iX ~= nil and iY ~= nil and iX > -1 and iY > -1) then
		plot = Map.GetPlot(iX, iY);
	end
	-- Declaring war by entering player's lands
	if (plot and plot:GetTeam() == eRivalTeam and not plot:IsStrategicSite()) then		
		local pRivalTeam = Teams[eRivalTeam];
		if (pRivalTeam:IsAllowsOpenBordersToTeam(Game.GetActiveTeam())) then
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_DOES_THIS_MEAN_WAR", Teams[eRivalTeam]:GetNameKey());
		else
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ENTER_LANDS_WAR", Teams[eRivalTeam]:GetNameKey());
		end		
		
	-- Declaring war by attacking Unit
	else
	    popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_DOES_THIS_MEAN_WAR", Teams[eRivalTeam]:GetNameKey());
	end
	
	local data = GatherData(Teams[eRivalTeam]:GetLeaderID(), popupText);
	View(data);
	
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		-- Send War netmessage.
		Network.SendChangeWar(eRivalTeam, true);
		
		-- Diplomatic response from AI
		if (not Teams[eRivalTeam]:IsMinorCiv() and not Teams[eRivalTeam]:IsHuman()) then
			if (not Game.IsNetworkMultiPlayer() or plot == nil) then
				Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_HUMAN_DECLARES_WAR, Teams[eRivalTeam]:GetLeaderID(), 0, 0 );
			end
		end
		
		-- Tell unit to move to position.
		if(plot ~= nil) then
			Game.SelectionListMove(plot, false, false, false);
		end
	end
	
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_YES");
	AddButton(buttonText, OnYesClicked);
	
	-- Initialize 'no' button.
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_NO");
	AddButton(buttonText, nil);
	
	return true;
end

-- DECLARE WAR RANGE STRIKE POPUP
-- This popup occurs when a team unit attempts a range strike
-- attack on a rival unit or city.
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_DECLAREWARRANGESTRIKE] = function(popupInfo)
	local eRivalTeam	= popupInfo.Data1;
	local iX			= popupInfo.Data2;
	local iY			= popupInfo.Data3;
	local eAttackingPlayer = popupInfo.Data4;

	-- Attacking a station?
	local plot = Map.GetPlot(iX, iY);
	if (plot) then		
		local station = plot:GetPlotStation();
		if (station ~= nil) then

			eSiteType = station:GetType();

			if (station:IsHostile(eAttackingPlayer) ~= true) then
			
				popupText = Locale.ConvertTextKey("TXT_KEY_CONFIRM_ATTACK_STATION", station:GetNameKey());

				-- Initialize 'yes' button.
				local OnYesClicked = function()

					-- Send hostile netmessage.
					Network.SendChangeStationHostile(eSiteType, eAttackingPlayer, true);
		
					-- Attack!
					local messagePushMission = GameMessageTypes.GAMEMESSAGE_PUSH_MISSION
					local missionRangeAttack = MissionTypes.MISSION_RANGE_ATTACK
					Game.SelectionListGameNetMessage(messagePushMission, missionRangeAttack, iX, iY);
		
					local interfaceModeSelection = InterfaceModeTypes.INTERFACEMODE_SELECTION
					UI.SetInterfaceMode(interfaceModeSelection);
				end

				local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_YES");
				AddButton(buttonText, OnYesClicked);
	
				-- Initialize 'no' button.
				local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_NO");
				AddButton(buttonText, nil);

				HideAllInfoControls(true);

				Controls.PopupText:SetText(popupText);
				CivIconHookup(Game.GetActivePlayer(), 64, Controls.CivIcon, Controls.CivIconBG, nil, false, false, Controls.CivIconHighlight);
				IconHookup(26, 64, "CIV_COLOR_ATLAS", Controls.CivRivalIconBG);    
				Controls.CivRivalIcon:SetHide( true );
				Controls.CivRivalIconHighlight:SetHide( true );

				-- The text can cause us to need to resize the popup.
				Controls.ButtonStack:ReprocessAnchoring();
				Controls.ButtonStack:CalculateSize();
		
				local frameWidth, frameHeight = Controls.ButtonStackFrame:GetSizeVal();
				local stackWidth, stackHeight = Controls.ButtonStack:GetSizeVal();
	
				Controls.ButtonStackFrame:SetSizeVal(frameWidth, stackHeight + 160);	
				Controls.ButtonStackFrame:ReprocessAnchoring();

				return true;
			else
				-- Attack!
				local messagePushMission = GameMessageTypes.GAMEMESSAGE_PUSH_MISSION
				local missionRangeAttack = MissionTypes.MISSION_RANGE_ATTACK
				Game.SelectionListGameNetMessage(messagePushMission, missionRangeAttack, iX, iY);

				return false;
			end
		end
	end

	-- Normal range strike attack
	local rivalTeam = Teams[eRivalTeam];
	popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_DOES_THIS_MEAN_WAR", rivalTeam:GetName());
		
	local data = GatherData(Teams[eRivalTeam]:GetLeaderID(), popupText);
	View(data);
	
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		-- Send War netmessage.
		Network.SendChangeWar(eRivalTeam, true);

		-- Diplomatic response from AI
		if (not rivalTeam:IsMinorCiv() and not rivalTeam:IsHuman()) then
			if (not Game.IsNetworkMultiPlayer()) then
				Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_HUMAN_DECLARES_WAR, rivalTeam:GetLeaderID(), 0, 0 );
			end
		end
		
		-- Attack!
		local messagePushMission = GameMessageTypes.GAMEMESSAGE_PUSH_MISSION
		local missionRangeAttack = MissionTypes.MISSION_RANGE_ATTACK
		Game.SelectionListGameNetMessage(messagePushMission, missionRangeAttack, iX, iY);
		
		local interfaceModeSelection = InterfaceModeTypes.INTERFACEMODE_SELECTION
		UI.SetInterfaceMode(interfaceModeSelection);
		
	end
	
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_YES");
	AddButton(buttonText, OnYesClicked);
		
	-- Initialize 'no' button.
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_NO");
	AddButton(buttonText, nil);
	
	return true;
end


local oldCursor; -- The previous cursor being used.
function ShowHideHandler( bIsHide, bInitState )
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore(); 

        	Events.BlurStateChange(0);
			print("DeclareWarPopup, Blur On");

        	oldCursor = UIManager:SetUICursor(0); -- make sure we start with the default cursor
        	
			Controls.AlphaAnim:SetToBeginning();
			Controls.AlphaAnim:Play();
			Controls.TopBarSlideAnim:SetToBeginning();
			Controls.TopBarSlideAnim:Play();
			Controls.BottomBarSlideAnim:SetToBeginning();
			Controls.BottomBarSlideAnim:Play();

        	if(g_PopupInfo ~= nil) then        	
        		Events.SerialEventGameMessagePopupShown(g_PopupInfo);
        		Events.SerialEventGameMessagePopupProcessed.CallImmediate(g_PopupInfo.Type, 0);
        	end
        else
			UIManager:SetUICursor(oldCursor);
			Events.BlurStateChange(1);
			print("DeclareWarPopup, Blur Off");
			if(g_PopupInfo ~= nil) then
		--		Events.SerialEventGameMessagePopupProcessed.CallImmediate(g_PopupInfo.Type, 0);
			end
            UI.decTurnTimerSemaphore();
            
            
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------
-- Collapse/Expand Behaviors --
-------------------------------
function OnCollapseExpand()
	Controls.UnderProtectionOfStack:CalculateSize();
	Controls.UnderProtectionOfStack:ReprocessAnchoring();
	Controls.AlliedCityStatesStack:CalculateSize();
	Controls.AlliedCityStatesStack:ReprocessAnchoring();
	Controls.ActiveDealsStack:CalculateSize();
	Controls.ActiveDealsStack:ReprocessAnchoring();
	Controls.TradeRoutesStack:CalculateSize();
	Controls.TradeRoutesStack:ReprocessAnchoring();
	Controls.DeclareWarDetailsStack:CalculateSize();
	Controls.DeclareWarDetailsStack:ReprocessAnchoring();
	Controls.DeclareWarDetailsScrollPanel:CalculateInternalSize();
end


local underProtectionOfText = Locale.Lookup("TXT_KEY_DECLARE_WAR_UNDER_PROTECTION_OF");
RegisterCollapseBehavior{	
	Header = Controls.UnderProtectionOfHeader, 
	HeaderLabel = Controls.UnderProtectionOfHeader, 
	HeaderExpandedLabel = "[ICON_MINUS] " .. underProtectionOfText,
	HeaderCollapsedLabel = "[ICON_PLUS] " .. underProtectionOfText,
	Panel = Controls.UnderProtectionOfStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};

local alliedCityStatesText = Locale.Lookup("TXT_KEY_DECLARE_WAR_ALLIED_CITYSTATES");
RegisterCollapseBehavior{	
	Header = Controls.AlliedCityStatesHeader, 
	HeaderLabel = Controls.AlliedCityStatesHeader, 
	HeaderExpandedLabel = "[ICON_MINUS] " .. alliedCityStatesText,
	HeaderCollapsedLabel = "[ICON_PLUS] " .. alliedCityStatesText,
	Panel = Controls.AlliedCityStatesStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};
			
local activeDealsText = Locale.Lookup("TXT_KEY_DECLARE_WAR_ACTIVE_DEALS");
RegisterCollapseBehavior{
	Header = Controls.ActiveDealsHeader,
	HeaderLabel = Controls.ActiveDealsHeader,
	HeaderExpandedLabel = "[ICON_MINUS] " .. activeDealsText,
	HeaderCollapsedLabel = "[ICON_PLUS] " .. activeDealsText,
	Panel = Controls.ActiveDealsStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};

local tradeRoutesText = Locale.Lookup("TXT_KEY_DECLARE_WAR_TRADE_ROUTES");
RegisterCollapseBehavior{
	Header = Controls.TradeRoutesHeader,
	HeaderLabel = Controls.TradeRoutesHeader,
	HeaderExpandedLabel = "[ICON_MINUS] " .. tradeRoutesText,
	HeaderCollapsedLabel = "[ICON_PLUS] " .. tradeRoutesText,
	Panel = Controls.TradeRoutesStack,
	Collapsed = false,
	OnCollapse = OnCollapseExpand,
	OnExpand = OnCollapseExpand,
};

