include("ConversationSystem");
include("SupportFunctions");
include("IconSupport");
include("InstanceManager");

-- ===========================================================================
--	Diplo Message Log
-- ===========================================================================
local g_MessagesIM = InstanceManager:new("NewMessageItem", "MouseAreaButton", Controls.MessageStack);
local g_OldMessagesIM = InstanceManager:new("OldMessageItem", "MouseAreaButton", Controls.MessageStack);

-- ===========================================================================
-- PANEL HIDE / SHOW
function Reveal()
	Controls.LogContainer:SetHide(false);
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	Controls.LogContainer:SetSizeY(screenSizeY-240);
	Controls.ContainerSlide:SetSizeY(screenSizeY-240);
	Controls.ContainerStack:SetSizeY(screenSizeY-240);
	Controls.MessageStackPanel:SetSizeY(screenSizeY-320);

	if (Controls.ContainerSlide:IsStopped()) then
		Controls.ContainerSlide:SetToBeginning();
		Controls.ContainerSlide:Play();
	end
end

function Hide()
	Controls.ContainerSlide:Stop();
	Controls.ContainerSlide:Reverse();
end

function Toggle()
	if (Controls.LogContainer:IsHidden()) then
		Reveal();
	else		
		Hide();
	end
end

-- ===========================================================================
-- MOUSE INPUT
function OnRevealButtonClick()
	Reveal();
end
Controls.RevealButton:RegisterCallback(Mouse.eLClick, OnRevealButtonClick);

function OnCloseButtonClick()
	Hide();
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnCloseButtonClick);

-- ===========================================================================
-- CONTENT
function Refresh()

	g_MessagesIM:ResetInstances();
	g_OldMessagesIM:ResetInstances();

	Controls.MessageStack:DestroyAllChildren();

	local player : object = Players[Game.GetActivePlayer()];
	if (player == nil) then
		error("Invalid player data");
		return nil;
	end

	-- Recover, sort, and display all logged communiques
	local allLoggedMessages : table = {};

	local records : table = {};
	for otherPlayerType = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		records = {};
		if (otherPlayerType ~= Game.GetActivePlayer()) then
			records = Players[otherPlayerType]:GetCommuniqueRecords(Game.GetActivePlayer());
			if (table.count(records) > 0 ) then
				for _, record : object in ipairs(records) do
					table.insert(allLoggedMessages, { PlayerType = otherPlayerType, Turn = record:GetTurnSent(), Record = record });
				end
			end
		end
	end

	if (#allLoggedMessages > 0) then
		table.sort(allLoggedMessages, function(a,b)
			return a.Turn < b.Turn;
		end);

		for i = 1, table.count(allLoggedMessages), 1 do
			local loggedMessage : object = allLoggedMessages[i];
			local reprocessControls : boolean = i == table.count(allLoggedMessages);
			AddMessage(
				loggedMessage.PlayerType, 
				loggedMessage.Record:GetReactionType(), 
				loggedMessage.Record:GetHeaderTextKey(), 
				loggedMessage.Record:GetMessageTextKey(), 
				loggedMessage.Turn, 
				reprocessControls );
		end
	end
end

-- Add a new communique message to the log
function OnAddCommuniqueMessage(playerType : number, reactionType : number, x : number, y : number)

	local player : object = Players[playerType];
	if (player == nil) then
		error("Invalid player data");
		return nil;
	end

	local reactionInfo : table = GameInfo.Reactions[reactionType];
	if (reactionInfo == nil) then
		error("Could not find reaction info");
		return;
	end

	local communiqueID : number = GenerateCommuniqueDeterministicID(playerType, reactionType, x, y);
	local textKey : string = SelectMessageForCommunique(player, reactionType, communiqueID);
	if (textKey == nil) then
		return;		
	end

	local message : string = Locale.ConvertTextKey(textKey);
	local subject : string = Locale.ConvertTextKey("TXT_KEY_COMMUNIQUE_UI_SUBJECT", reactionInfo.CommuniqueSubject or "TXT_KEY_COMMUNIQUE_SUBJECT_GENERIC");
	AddMessage(playerType, reactionType, subject, message, Game.GetGameTurn(), true);

	-- Log communique for representation in Diplomacy Overview
	if (subject ~= nil and message ~= nil) then		
		Players[playerType]:LogCommunique(Game.GetActivePlayer(), reactionType, subject, message);
	end
end
Events.AddCommuniqueMessage.Add(OnAddCommuniqueMessage);

-- When the player changes, refresh the whole UI
function OnPlayerChanged( iActivePlayer : number, iPrevActivePlayer : number )
	Controls.LogContainer:SetHide(true);  -- hide the panel
	Refresh();
end
Events.GameplaySetActivePlayer.Add(OnPlayerChanged);

function OnPlayerTurnStart()
	Refresh();	
end
Events.ActivePlayerTurnStart.Add(OnPlayerTurnStart);
Events.RemotePlayerTurnStart.Add(OnPlayerTurnStart);

-- Add a new message to the UI
function AddMessage(sendingPlayerType : number, reactionType : number, subject : string, message : string, turn : number, reprocessControls : boolean)

	local player : object = Players[sendingPlayerType];
	if (player == nil) then
		error("Invalid player data");
		return nil;
	end

	local reactionInfo : table = GameInfo.Reactions[reactionType];
	if (reactionInfo == nil) then
		error("Could not find reaction info");
		return;
	end

	local leaderInfo : table = GameInfo.Leaders[player:GetLeaderType()];
	local civInfo : table = GameInfo.Civilizations[player:GetCivilizationType()];
	local turnsAgo : number = Game.GetGameTurn() - turn;

	local instance = {};	
	ContextPtr:BuildInstanceForControlAtIndex("MessageItem", instance, Controls.MessageStack, 0);
	instance.NewIndicator:SetHide(true);

	local tooltipString : string = "";
	local iconStr : string = "";
	if (reactionInfo.RespectChange >= 10) then
		iconStr = "[ICON_RESPECT_UP_ALOT]";
		tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTUP2_TT");
	elseif (reactionInfo.RespectChange > 0) then
		iconStr = "[ICON_RESPECT_UP]";
		tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTUP1_TT");
	elseif (reactionInfo.RespectChange <= -10) then
		iconStr = "[ICON_RESPECT_DOWN_ALOT]";
		tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTDOWN2_TT");
	elseif (reactionInfo.RespectChange < 0) then
		iconStr = "[ICON_RESPECT_DOWN]";
		tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTDOWN1_TT");
	elseif (reactionInfo.RespectChange == 0) then
		instance.RespectDeltaContainer:SetHide(true);
	end
	instance.RespectDeltaContainer:SetToolTipString(tooltipString);
	instance.RespectDelta:SetText(iconStr);
	local entryPadding = 20;
	if(turnsAgo <= 0) then
		instance.NewIndicator:SetHide(false);
		instance.NewIndicator:SetSizeX(instance.NewLabel:GetSizeX()+30);
		instance.DeltaAnim:Play();
		header = Locale.ConvertTextKey("TXT_KEY_COMMUNIQUE_LOG_HEADER_THIS_TURN", leaderInfo.Description);
	else
		instance.DeltaAnim:SetToBeginning();
		instance.DeltaAnim:Stop();
		header = Locale.ConvertTextKey("TXT_KEY_COMMUNIQUE_LOG_HEADER_PAST_TURN", leaderInfo.Description, turnsAgo);
	end
	instance.HeaderLabel:SetText(header);
	instance.SubjectLabel:SetText(subject);
	instance.MessageLabel:SetWrapWidth(instance.Content:GetSizeX()-75);
	instance.MessageLabel:SetText(message);
	instance.MessageStack:CalculateSize();
	instance.MessageStack:ReprocessAnchoring();
	local heightNeeded = instance.CivIcon:GetSizeY();
	if (heightNeeded < instance.MessageStack:GetSizeY()) then
		heightNeeded = instance.MessageStack:GetSizeY();
		reprocessControls = true;
	end
	instance.Content:SetSizeY(instance.HeaderLabel:GetSizeY() + heightNeeded + entryPadding);
	instance.Root:SetSizeY(instance.HeaderLabel:GetSizeY() + heightNeeded + entryPadding);
	instance.ContentStack:CalculateSize();
	instance.ContentStack:ReprocessAnchoring();
	IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, instance.CivIcon);
	IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);

	if( reprocessControls == true ) then
		Controls.MessageStack:CalculateSize();
		Controls.MessageStack:ReprocessAnchoring();
		Controls.MessageStackPanel:CalculateInternalSize();
	end

	instance.MouseAreaButton:RegisterCallback(Mouse.eLClick, function()
		Events.SerialEventGameMessagePopup{Type = ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW, Data2 = sendingPlayerType};
	end);

	return header, subject, message;
end


-- ===========================================================================
-- ===========================================================================
-- DEBUG

function Bump()
	-- Make new instance
	local controlTable = g_MessagesIM:GetInstance();

	Controls.MessageStack:CalculateSize();
	Controls.MessageStack:ReprocessAnchoring();
	Controls.MessageStackPanel:CalculateInternalSize();
end

function Bump10()
	for i=0,10,1 do
		Bump();
	end
end