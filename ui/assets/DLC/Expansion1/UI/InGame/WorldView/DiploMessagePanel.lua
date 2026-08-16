include("ConversationSystem");
include("SupportFunctions");
include("IconSupport");

-- ===========================================================================
--	Diplo Message Panel
-- ===========================================================================
hstructure MessageData
	PlayerType : number
	Header : string
	Subject : string
	Message : string
	RespectChange : number
	AdvisorType : number
	OnClick : ifunction
	X : number
	Y : number
end

local g_queuedCommuniques = {};
local g_activeCommunique : MessageData = nil;

-- Constants
local MAX_COMMUNIQUE_CHARS : number = 160;

local m_lastMessageData : MessageData = nil;

-- ===========================================================================
--	CALLBACKS
-- ===========================================================================

-- Remove the top of the queue and continue to display the next
function StepQueue()
	if (#g_queuedCommuniques >= 1) then		
		table.remove(g_queuedCommuniques, 1);
		DisplayNextQueuedCommunique();
	end
end
Controls.MessageSlide:RegisterEndCallback(StepQueue);

function OnMouseEnter()
	Controls.MessageSlide:Stop();
	Controls.MessageFade:Stop();
end
Controls.MouseAreaButton:RegisterMouseEnterCallback(OnMouseEnter);

function OnMouseExit()
	Controls.MessageSlide:Play();
	Controls.MessageFade:Play();
end
Controls.MouseAreaButton:RegisterMouseExitCallback(OnMouseExit);

-- ===========================================================================
-- Pause fade-out animations if another popup is showing that blocks view
function OnShowingOtherPopup( popupInfo )
	if ( popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_TEXT or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_TUTORIAL or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_COUNSEL or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_AFFINITY_OVERVIEW or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_TECH_AWARD) 
	then
		if (not Controls.MessageContainer:IsHidden()) then
			Controls.MessageSlide:Stop();
			Controls.MessageFade:Stop();
		end
	end	
end
Events.SerialEventGameMessagePopupShown.Add( OnShowingOtherPopup );

-- ===========================================================================
-- Resume fade-out animations if the blocking popup is dismissed
function OnHidingOtherPopup( popupID )
	if ( popupID == ButtonPopupTypes.BUTTONPOPUP_TEXT or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_TUTORIAL or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_COUNSEL or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_AFFINITY_OVERVIEW or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_TECH_AWARD)  
	then
		if (not Controls.MessageContainer:IsHidden()) then
			Controls.MessageSlide:Play();
			Controls.MessageFade:Play();
		end
	end	
end
Events.SerialEventGameMessagePopupProcessed.Add( OnHidingOtherPopup );

function OnClick()
	-- Zoom camera to location of the notification
	if (g_activeCommunique ~= nil) then
		if (g_activeCommunique.X ~= nil and g_activeCommunique.Y ~= nil) then
			local focusPlot : object = Map.GetPlot(g_activeCommunique.X, g_activeCommunique.Y);
			if (focusPlot ~= nil) then
				UI.LookAt(focusPlot, 0);
			end
		end

		if (g_activeCommunique.OnClick ~= nil) then
			g_activeCommunique.OnClick();
		end
	end
end
Controls.MouseAreaButton:RegisterCallback(Mouse.eLClick, OnClick);

function OnOptionClick()
	StepQueue();
end
Controls.MouseAreaButton:RegisterCallback(Mouse.eRClick, OnOptionClick);

-- ===========================================================================
--	COMMUNIQUE MANAGEMENT
-- ===========================================================================
-- Compose and enqueue a new communique message
-- Will activate the queue processing if the queue was previously idle (empty)
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

	local leaderInfo = GameInfo.Leaders[player:GetLeaderType()];
	local civInfo : table = GameInfo.Civilizations[player:GetCivilizationType()];

	local communiqueID : number = GenerateCommuniqueDeterministicID(playerType, reactionType, x, y);

	local header : string = leaderInfo.Description;
	local subject : string = Locale.ConvertTextKey("TXT_KEY_COMMUNIQUE_UI_SUBJECT", reactionInfo.CommuniqueSubject or "TXT_KEY_COMMUNIQUE_SUBJECT_GENERIC");
	local textKey : string = SelectMessageForCommunique(player, reactionType, communiqueID);
	if (textKey == nil) then
		return;
	end

	local message : string = Locale.ConvertTextKey(SelectMessageForCommunique(player, reactionType, communiqueID));

	local newMessageData = hmake MessageData
	{
		PlayerType = playerType,
		Header = header,
		Subject = subject,
		Message = message,
		RespectChange = reactionInfo.RespectChange or 0,
		AdvisorType = AdvisorTypes.NO_ADVISOR_TYPE,
		OnClick = nil,
		X = x,
		Y = y,
	};

	EnqueueCommuniqueMessage(newMessageData);
end
Events.AddCommuniqueMessage.Add(OnAddCommuniqueMessage);

function OnAddAdvisorCommunique(advisorType : number, otherPlayerType : number, foreignPolicyType : number)
	local advisorTitleKey : string = nil;
	local advisorMessageKey : string = nil;

	if (advisorType == AdvisorTypes.ADVISOR_ECONOMIC) then
		advisorTitleKey = "TXT_KEY_ADVISOR_ECON_TITLE";
		advisorMessageKey = "TXT_KEY_ADVISOR_AGREEMENT_COMMUNIQUE_ECONOMIC";
	elseif (advisorType == AdvisorTypes.ADVISOR_MILITARY) then
		advisorTitleKey = "TXT_KEY_ADVISOR_MILITARY_TITLE";
		advisorMessageKey = "TXT_KEY_ADVISOR_AGREEMENT_COMMUNIQUE_MILITARY";
	elseif (advisorType == AdvisorTypes.ADVISOR_FOREIGN) then
		advisorTitleKey = "TXT_KEY_ADVISOR_FOREIGN_TITLE";
		advisorMessageKey = "TXT_KEY_ADVISOR_AGREEMENT_COMMUNIQUE_FOREIGN";
	elseif (advisorType == AdvisorTypes.ADVISOR_SCIENCE) then
		advisorTitleKey = "TXT_KEY_ADVISOR_SCIENCE_TITLE";
		advisorMessageKey = "TXT_KEY_ADVISOR_AGREEMENT_COMMUNIQUE_SCIENCE";
	else
		print("Invalid advisor type!");
	end

	local header : string = Locale.ConvertTextKey("TXT_KEY_ADVISOR_COMMUNIQUE_HEADER", advisorTitleKey);
	local subject : string = Locale.Lookup("TXT_KEY_ADVISOR_COMMUNIQUE_SUBJECT");

	local otherPlayer : object = Players[otherPlayerType];
	local policyInfo : table = GameInfo.ForeignPolicies[foreignPolicyType];
	local message : string = Locale.ConvertTextKey(advisorMessageKey, otherPlayer:GetCivilizationShortDescriptionKey(), policyInfo.Description);

	local newMessageData = hmake MessageData
	{
		PlayerType = otherPlayerType,
		Header = header,
		Subject = subject,
		Message = message,
		AdvisorType = advisorType,
		OnClick = function()
			Events.SerialEventGameMessagePopup{Type = ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW, Data2 = g_activeCommunique.PlayerType};
		end
	};

	EnqueueCommuniqueMessage(newMessageData);
end
Events.AddAdvisorCommunique.Add(OnAddAdvisorCommunique);

-- Add a message object to the queue
function EnqueueCommuniqueMessage(messageData : MessageData)

	table.insert(g_queuedCommuniques, messageData);

	-- If this is the first/only message in the queue, fire it off right now
	if (#g_queuedCommuniques == 1) then
		DisplayNextQueuedCommunique();
	end
end

-- Execute the next communique message in the queue.
-- Relies on the EndCallback (above) to trigger the continuation of the queue
function DisplayNextQueuedCommunique()

	Reset();

	if (#g_queuedCommuniques > 0) then
		
		-- Set the top of the queue as the active message		
		g_activeCommunique = g_queuedCommuniques[1];
		if (g_activeCommunique ~= nil) then
			
			-- Advisor or Civ Communique?
			if (g_activeCommunique.AdvisorType ~= AdvisorTypes.NO_ADVISOR_TYPE) then
				Controls.AdvisorIconGrid:SetHide(false);
				Controls.EconomicAdvisorIcon:SetHide(true);
				Controls.ForeignAdvisorIcon:SetHide(true);
				Controls.MilitaryAdvisorIcon:SetHide(true);
				Controls.ScienceAdvisorIcon:SetHide(true);
				Controls.CivIcon:SetHide(true);
				Controls.RespectDeltaContainer:SetHide(true);

				if (g_activeCommunique.AdvisorType == AdvisorTypes.ADVISOR_ECONOMIC) then
					Controls.EconomicAdvisorIcon:SetHide(false);
				elseif (g_activeCommunique.AdvisorType == AdvisorTypes.ADVISOR_MILITARY) then
					Controls.MilitaryAdvisorIcon:SetHide(false);
				elseif (g_activeCommunique.AdvisorType == AdvisorTypes.ADVISOR_FOREIGN) then
					Controls.ForeignAdvisorIcon:SetHide(false);
				elseif (g_activeCommunique.AdvisorType == AdvisorTypes.ADVISOR_SCIENCE) then
					Controls.ScienceAdvisorIcon:SetHide(false);
				end
			elseif (g_activeCommunique.PlayerType >= 0) then
				Controls.AdvisorIconGrid:SetHide(true);
				Controls.CivIcon:SetHide(false);

				-- Portrait
				local player : object = Players[g_activeCommunique.PlayerType];
				local leaderInfo : table = GameInfo.Leaders[player:GetLeaderType()];
				local civInfo : table = GameInfo.Civilizations[player:GetCivilizationType()];
				IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, Controls.CivIcon);
				IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, Controls.BigCivIcon);

				-- Respect Change
				Controls.RespectDeltaContainer:SetHide(false);
				local tooltipString : string = "";
				local iconStr : string = "";
				if (g_activeCommunique.RespectChange >= 10) then
					iconStr = "[ICON_RESPECT_UP_ALOT]";
					tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTUP2_TT");
				elseif (g_activeCommunique.RespectChange > 0) then
					iconStr = "[ICON_RESPECT_UP]";
					tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTUP1_TT");
				elseif (g_activeCommunique.RespectChange <= -10) then
					iconStr = "[ICON_RESPECT_DOWN_ALOT]";
					tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTDOWN2_TT");
				elseif (g_activeCommunique.RespectChange < 0) then
					iconStr = "[ICON_RESPECT_DOWN]";
					tooltipString = tooltipString .." ".. Locale.Lookup("TXT_KEY_DIPLO_RESPECTDOWN1_TT");
				elseif (g_activeCommunique.RespectChange == 0) then
					Controls.RespectDeltaContainer:SetHide(true);
				end
				Controls.RespectDeltaContainer:SetToolTipString(tooltipString);
				Controls.RespectDelta:SetText(iconStr);
				Controls.DeltaAnim:Play();
			end

			-- Header
			Controls.HeaderLabel:SetText(Locale.ToUpper(g_activeCommunique.Header));
			-- Subject
			if (g_activeCommunique.Subject ~= nil and g_activeCommunique.Subject ~= "") then
				Controls.SubjectLabel:SetHide(false);
				Controls.SubjectLabel:SetText(Locale.ToUpper(g_activeCommunique.Subject));
			else
				Controls.SubjectLabel:SetHide(true);
			end
			-- Message
			local sizedMessage : string = TruncateStringByLength(g_activeCommunique.Message, MAX_COMMUNIQUE_CHARS);
			Controls.MessageLabel:SetText(sizedMessage);
			local entryPadding = 20;
			Controls.MessageLabel:SetWrapWidth(Controls.Content:GetSizeX()-75);
			local heightNeeded = Controls.CivIcon:GetSizeY();
			Controls.MessageStack:CalculateSize();
			Controls.MessageStack:ReprocessAnchoring();
			if (heightNeeded < Controls.MessageStack:GetSizeY()) then
				heightNeeded = Controls.MessageStack:GetSizeY();
			end
			Controls.Content:SetSizeY(Controls.HeaderLabel:GetSizeY() + heightNeeded + entryPadding);
			Controls.ContentStack:CalculateSize();
			Controls.ContentStack:ReprocessAnchoring();
			Controls.MessageContainer:SetHide(false);

			-- Play sound effect if this communique is different from the last one.
			if (m_lastMessageData == nil or m_lastMessageData.Subject ~= g_activeCommunique.Subject) then
				Events.AudioPlay2DSound("AS2D_IF_MP_CHAT_DING");
			end
			
			Controls.MessageSlide:Play();
			Controls.MessageFade:Play();

			m_lastMessageData = g_activeCommunique;
		end		
	end
end

function OnTurnStart()
	m_lastMessageData = nil;
end
Events.ActivePlayerTurnStart.Add(OnTurnStart);

-- Clear the active communique and reset the UI animation state
function Reset()
	g_activeCommunique = nil;
	Controls.MessageSlide:SetToBeginning();
	Controls.MessageFade:SetToBeginning();
	Controls.MessageContainer:SetHide(true);
end