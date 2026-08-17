-------------------------------------------------
-- Diplomacy Overview
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");
include("ConversationSystem");

------------------------------------------------
-- Members
------------------------------------------------
local HARMONY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID;
local PURITY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID;
local SUPREMACY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID;

local m_shown : boolean = false;
local m_smallInfoCards : boolean = false;
local m_player : object = nil;
local m_selectedPlayer : object = nil;
local m_popupInfo : table = nil;
local m_transmissionCloseOverride : boolean = false; --WRM: This is a hack to keep the diplo window from closing if the user clicks on another leader after handling a transmission

local m_breadcrumbEntryInstanceManager : table = InstanceManager:new("BreadcrumbEntry", "Content", Controls.BreadcrumbsStack);

local m_selectedPlayerInfoCardInstance : table = nil;
local m_activePlayerInfoCardInstance : table = nil;
local m_selectedPlayerActivityInstance : table = nil;
local m_playerRibbonEntryInstances : table = {};

local m_stateBreadcrumbNames : table =
{
	[g_diplomacyUIStates.ACTIONS]		= "{TXT_KEY_DIPLOMACYUI_MYINFO:upper}",
	[g_diplomacyUIStates.TRAITS]		= "{TXT_KEY_DIPLOMACYUI_TRAITS:upper}",
	[g_diplomacyUIStates.AGREEMENTS]	= "{TXT_KEY_DIPLOMACYUI_AGREEMENTS:upper}",
	[g_diplomacyUIStates.AGREEMENTS_FROM_ALL_SERVICES] = "{TXT_KEY_DIPLOMACYUI_AGREEMENTS:upper}",
	[g_diplomacyUIStates.RELATIONSHIP]	= "{TXT_KEY_DIPLOMACYUI_CHANGERELATIONSHIP:upper}",
	[g_diplomacyUIStates.CONFRONTATION]	= "{TXT_KEY_DIPLOMACYUI_CONFRONTATION:upper}",
	[g_diplomacyUIStates.AFFINITY]		= "{TXT_KEY_DIPLOMACYUI_AFFINITY:upper}",
	[g_diplomacyUIStates.WAR]			= "{TXT_KEY_DIPLOMACYUI_WAR:upper}",
	[g_diplomacyUIStates.ALL_SERVICES]	= "{TXT_KEY_DIPLOMACYUI_AGREEMENTS:upper}",
};

------------------------------------------------
-- Init
------------------------------------------------
function OnPopup(popupInfo : table)
	if (not (popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW or 
		popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS or
		popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_AFFINITY_OVERVIEW)) 
	then
		return;
	end

	local player = Players[Game.GetActivePlayer()];
	if (player ~= nil and player:IsObserver()) then
		return;
	end;

	if (popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS)
	then
		local numPendingTransactions : number = Game.GetNumPendingTransactionsWithReceivingPlayer(player:GetID())
		if (numPendingTransactions == 0) then
			return;
		end
	end

	local isShowRequest : boolean = true;

	if (m_popupInfo ~= nil) then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_popupInfo.Type, 0);
		m_popupInfo = nil;
	end

	m_popupInfo = popupInfo;

	-- Toggle?
	if (m_popupInfo.Data1 == 1 and ContextPtr:IsHidden() == false) then
		isShowRequest = false;
	end

	if (isShowRequest) then
		if (ContextPtr:IsHidden()) then
			UI.EnterDiplomacy();
		end
	else
		if (not ContextPtr:IsHidden()) then
			UI.ExitDiplomacy();
		end
	end
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

function Close()
	if (m_popupInfo ~= nil) then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_popupInfo.Type, 0);
		m_popupInfo = nil;
	end

	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, Close);
LuaEvents.Diplomacy_Close.Add(Close);


function Open()
	UIManager:QueuePopup(ContextPtr, PopupPriority.LeaderHeadPopup);
end
LuaEvents.Diplomacy_Open.Add(Open);

function ShowHideHandler(isHide : boolean)
	if (not isHide and m_popupInfo ~= nil) then
		Events.SerialEventGameMessagePopupShown(m_popupInfo);
		UI.EnterDiplomacy();
		Controls.WarSpoilsBuilder:SetHide(true);
		ShowWindow();
		m_shown = true;
	else
		m_shown = false;
		UI.ExitDiplomacy();
		if (m_popupInfo ~= nil) then
			Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_popupInfo.Type, 0);
			m_popupInfo = nil;
		end
		HideWindow();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function ShowWindow()

	m_transmissionCloseOverride = false;
	LuaEvents.DiplomacyUI_ResetAnimations();

	-- Clears out any in-progress UI state (like range attack/bombard)
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	UI.ClearSelectedCities();

	Controls.Advisor:SetHide(true);

	m_player = Players[Game.GetActivePlayer()];

	if (m_popupInfo ~= nil) then
		if (m_popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW) then
			local selectedPlayer : number = Game.GetActivePlayer();
			if (m_popupInfo.Data2 > -1) then
				selectedPlayer = m_popupInfo.Data2;
			end

			local isAtWar : boolean = Teams[m_player:GetTeam()]:IsAtWar(Players[selectedPlayer]:GetTeam()) and Players[selectedPlayer]:IsAlive();

			if (isAtWar) then
				SetDiplomacyUIState(g_diplomacyUIStates.WAR, selectedPlayer);
				Events.LeaderSetVisible();
			else
				if (Game.GetNumPendingTransactions(selectedPlayer, m_player:GetID()) > 0) then
					DoNextPendingTransactionForPlayer(selectedPlayer, -1);
				else	
					SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, selectedPlayer);
				end
				
				Events.LeaderSetVisible();
			end
		elseif (m_popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS) then
			if (m_popupInfo.Data3 ~= -1 and m_popupInfo.Data2 ~= -1) then
				local sendingPlayerType : number = m_popupInfo.Data2;
				local transactionID : number = m_popupInfo.Data3;
				DoNextPendingTransactionForPlayer(sendingPlayerType, transactionID);
			else
				DoNextPendingTransaction();
			end
			
		elseif (m_popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_AFFINITY_OVERVIEW) then
			SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, m_player:GetID());
			PushDiplomacyUIState(g_diplomacyUIStates.AFFINITY, m_player:GetID());
			Events.LeaderSetVisible();
		else
			error("Unhandled popup info type");
		end
	else
		print("DiplomacyOverview","Showing diplo window without popup info");
	end

	UpdatePlayerRibbon();

	-- Run a delayed animation of these cards filtering in
	local delay = .2;
	for playerType : number, instance : table in pairs(m_playerRibbonEntryInstances) do
		instance.InitialSlide:SetPauseTime(delay);
		instance.InitialSlide:SetToBeginning();
		instance.InitialSlide:Play();
		instance.InitialAlpha:SetPauseTime(delay);
		instance.InitialAlpha:SetToBeginning();
		instance.InitialAlpha:Play();
		delay = delay + .1;
	end
	if (Controls.PlayerRibbon_Stack:GetSizeY()==0) then
		Controls.RelationshipsBracket:SetHide(true);
		Controls.PlayerRibbonBacking:SetHide(true);
	end
	Controls.BracketAlpha:SetToBeginning();
	Controls.BracketSlide:SetToBeginning();
	Controls.BracketAlpha:Play();
	Controls.BracketSlide:Play();
	

	ShowDiploTutorial("DIPLOMACY_INTRO", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_INTRO"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_INTRO");
end

function HideWindow()
end

function SelectPlayer(playerType : number)
	m_previousPlayer = m_selectedPlayer;
	m_selectedPlayer = Players[playerType];
	if (m_previousPlayer == nil) then
		m_previousPlayer = m_selectedPlayer;
	end

	LuaEvents.DiplomacyUI_PlayerSelected(playerType);
end

function UpdateBreadcrumbs()
	if (m_popupInfo == nil) then
		return;
	end

	if (m_popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_CONFRONTATION) then
		Controls.BreadcrumbsStack:SetHide(true);
	else
		Controls.BreadcrumbsStack:SetHide(false);
	end 

	m_breadcrumbEntryInstanceManager:ResetInstances();

	local statesData : table = UI.GetDiplomacyUIStates();
	for i : number, stateData : table in ipairs(statesData) do
		local instance = m_breadcrumbEntryInstanceManager:GetInstance();

		local breadcrumbString : string = nil;
		if (stateData.State == g_diplomacyUIStates.ACTIONS) then
			local selectedPlayer : object = Players[stateData.SelectedPlayer];
			if (selectedPlayer:GetID() == Game.GetActivePlayer()) then
				breadcrumbString = Locale.Lookup("TXT_KEY_DIPLOMACYUI_ME", selectedPlayer:GetName());
			else
				breadcrumbString = selectedPlayer:GetName();
			end
		else
			breadcrumbString = Locale.Lookup(m_stateBreadcrumbNames[stateData.State]);
		end

		InitBreadcrumbEntryInstance(instance, stateData.State, breadcrumbString);

		if(i == #statesData and #statesData > 1) then										-- Only animate a breadcrumb if it is new 
			instance.BreadcrumbAlpha:SetToBeginning();
			instance.BreadcrumbSlide:SetToBeginning();
			instance.BreadcrumbAlpha:Play();
			instance.BreadcrumbSlide:Play();
		end
		m_activePlayerInfoCardInstance.CardAlphaAnim:SetToBeginning();
		m_activePlayerInfoCardInstance.CardAlphaAnim:Play();
		m_activePlayerInfoCardInstance.CardSlideAnim:SetToBeginning();
		m_activePlayerInfoCardInstance.CardSlideAnim:Play();
		
		local tempState : number = stateData.State;
		instance.Button:RegisterCallback(Mouse.eLClick, function() 
			local numToPop : number = #statesData - i;
			if (numToPop > 0) then
				PopDiplomacyUIStates(numToPop);
			end
		end);
	end

	Controls.BreadcrumbsStack:CalculateSize();
	Controls.BreadcrumbsStack:ReprocessAnchoring();

	Controls.BackButton:SetHide(#statesData <= 1);
	Controls.BackButton:RegisterCallback(Mouse.eLClick, function() 
		PopDiplomacyUIState();
		LuaEvents.DiplomacyUI_ResetAnimations();
	end);
end

function UpdatePlayerRibbon()
	-- Change highlight on the player's icon
	local isSelfSelected = m_selectedPlayer ~= nil and m_selectedPlayer:GetID() == m_player:GetID();
	local leaderInfo : table = GameInfo.Leaders[m_player:GetLeaderType()];
	local civInfo : table = GameInfo.Civilizations[m_player:GetCivilizationType()];
	IconHookup(leaderInfo.PortraitIndex, 80, leaderInfo.IconAtlas, Controls.PlayerRibbon_PlayerIcon);

	Controls.PlayerRibbon_PlayerButton:SetDisabled(isSelfSelected);
	
	if(isSelfSelected) then
		Controls.PlayerSlide:SetBeginVal(-40,0);
		Controls.PlayerSlide:SetEndVal(0,0);
		Controls.PlayerSlide:SetToBeginning();
		Controls.PlayerSlide:Play();
		Controls.PlayerRibbon_PlayerHighlight:SetToBeginning();
		Controls.PlayerRibbon_PlayerHighlight:Play();
	else
		Controls.PlayerRibbon_PlayerHighlight:SetToBeginning();
		if(Controls.PlayerSlide:GetBeginValX() ~= 0) then
			Controls.PlayerSlide:SetBeginVal(0,0);
			Controls.PlayerSlide:SetEndVal(-40,0);
			Controls.PlayerSlide:SetToBeginning();
			Controls.PlayerSlide:Play();
		end
	end

	local relationshipInfo : table;
	local needsTalk : number;
	-- Update highlights for all other leaders in the ribbon
	for playerType : number, instance : table in pairs(m_playerRibbonEntryInstances) do
		needsTalk = Game.GetNumPendingTransactions(playerType, m_player:GetID());
		if (needsTalk > 0) then
			instance.TalkIndicator:SetHide(false);
		else
			instance.TalkIndicator:SetHide(true);
		end
		InitPlayerRibbonEntryInstance(instance, playerType);
		relationshipInfo = GameInfo.RelationshipLevels[Game.GetRelationship(playerType, m_player:GetID())];
		local relationshipOffset : number = (75*relationshipInfo.ID) * 2;
		instance.RelationshipIndicator:SetTextureOffsetVal(0,relationshipOffset);
		local isSelected : boolean = m_selectedPlayer:GetID() == playerType;
		instance.Button:SetDisabled(isSelected);
		if (isSelected) then
			instance.OtherSlide:SetBeginVal(-40,0);
			instance.OtherSlide:SetEndVal(30,0);
			instance.OtherSlide:SetToBeginning();
			instance.OtherSlide:Play();
		else
			if(instance.OtherSlide:GetBeginValX() ~= 15) then
				instance.OtherSlide:SetBeginVal(30,0);
				instance.OtherSlide:SetEndVal(-40,0);
				instance.OtherSlide:SetToBeginning();
				instance.OtherSlide:Play();
			end
		end
	end

	Controls.PlayerRibbon_Stack:CalculateSize();
	Controls.PlayerRibbon_Stack:ReprocessAnchoring();
	Controls.PlayerRibbonBacking:SetSizeY(Controls.PlayerRibbon_Stack:GetSizeY()+79);
	if(Controls.PlayerRibbon_Stack:GetSizeY() ~= 0) then
		Controls.PlayerRibbonBacking:SetHide(false);
		Controls.RelationshipsBracket:SetHide(false);
		Controls.RelationshipsBracket:SetSizeY(Controls.PlayerRibbon_Stack:GetSizeY()+10);
	else
		Controls.PlayerRibbonBacking:SetHide(true);
		Controls.RelationshipsBracket:SetHide(true);
	end
	
end

function UpdateLeaderCards()	
	if (m_selectedPlayer ~= nil) then
		InitInfoCard(m_selectedPlayerInfoCardInstance, m_selectedPlayer:GetID());
	end

	if (m_player ~= nil) then
		InitInfoCard(m_activePlayerInfoCardInstance, m_player:GetID());
	end
end

function UpdateRecentActivity()
	if (m_selectedPlayer ~= nil) then
		InitPlayerActivityInstance(m_selectedPlayerActivityInstance, m_selectedPlayer);
	end
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function OnInitialize(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];

	-- Init static controls
	InitControls();

	-- Register events
	LuaEvents.DiplomacyUI_ResetAnimations.Add(RefreshData);
	LuaEvents.DiplomacyUI_PlayerSelected.Add(OnPlayerSelected);
	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	LuaEvents.DiplomacyUI_StatePushed.Add(OnStatePushed);
	LuaEvents.DiplomacyUI_StatePopped.Add(OnStatePopped);
	LuaEvents.DiplomacyUI_ShowTutorialIntro.Add(OnShowTutorialIntro);
	Events.DiplomacyAgreementCreated.Add(OnAgreementCreated);
	Events.DiplomacyRelationshipChanged.Add(OnDiplomacyRelationshipChanged);
	Events.PersonalityTraitLeveledUp.Add(OnTraitLeveledUp);
	Events.PersonalityTraitAdded.Add(OnTraitAdded);
	Events.TransactionCreated.Add(OnTransactionCreated);
	Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

	-- Select active player
	SelectPlayer(m_player:GetID());
end
ContextPtr:SetInitHandler(OnInitialize);

-- ===========================================================================
function OnShutdown()

	-- Clean up dynamic controls in order (or face potential crash)
	if m_selectedPlayerInfoCardInstance.TraitsInstanceManager ~= nil then
		m_selectedPlayerInfoCardInstance.TraitsInstanceManager:DestroyInstances();
	end
	if m_selectedPlayerInfoCardInstance.CommuniqueEntriesInstanceManager ~= nil then
		m_selectedPlayerInfoCardInstance.CommuniqueEntriesInstanceManager:DestroyInstances();
	end
	if m_selectedPlayerInfoCardInstance.AgreementsInstanceManager ~= nil then
		m_selectedPlayerInfoCardInstance.AgreementsInstanceManager:DestroyInstances();
	end
	if m_activePlayerInfoCardInstance.TraitsInstanceManager ~= nil then
		m_activePlayerInfoCardInstance.TraitsInstanceManager:DestroyInstances();
	end
	if m_activePlayerInfoCardInstance.CommuniqueEntriesInstanceManager ~= nil then
		m_activePlayerInfoCardInstance.CommuniqueEntriesInstanceManager:DestroyInstances();
	end
	if m_activePlayerInfoCardInstance.AgreementsInstanceManager ~= nil then
		m_activePlayerInfoCardInstance.AgreementsInstanceManager:DestroyInstances();
	end
	Controls.PlayerRibbon_Stack:DestroyAllChildren();

	-- Unregister events
	LuaEvents.DiplomacyUI_ResetAnimations.Remove(RefreshData);
	LuaEvents.DiplomacyUI_PlayerSelected.Remove(OnPlayerSelected);
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
	LuaEvents.DiplomacyUI_StatePushed.Remove(OnStatePushed);
	LuaEvents.DiplomacyUI_StatePopped.Remove(OnStatePopped);
	LuaEvents.DiplomacyUI_ShowTutorialIntro.Remove(OnShowTutorialIntro);
	Events.DiplomacyAgreementCreated.Remove(OnAgreementCreated);
	Events.DiplomacyRelationshipChanged.Remove(OnDiplomacyRelationshipChanged);
	Events.PersonalityTraitLeveledUp.Remove(OnTraitLeveledUp);
	Events.PersonalityTraitAdded.Remove(OnTraitAdded);
	Events.TransactionCreated.Remove(OnTransactionCreated);
end
ContextPtr:SetShutdown(OnShutdown)

function InputHandler(msg : number, wParam : number, lParam : number)
	if (msg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE) then
			if (UI.GetNumDiplomacyUIStates() > 1) then
				PopDiplomacyUIState();
				LuaEvents.DiplomacyUI_ResetAnimations();
			else
				Close();
			end
		elseif (wParam == Keys.VK_F4) then
			Close();
		end
	end
end
ContextPtr:SetInputHandler(InputHandler);

function OnSummary()
	Events.SerialEventGameMessagePopup
	{ 
		Type = ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_SUMMARY,
		Data1 = -1,
		Data2 = 1 -- Flag indicating we are raising this from the diplo UI.
	};
end
Controls.SummaryButton:RegisterCallback(Mouse.eLClick, OnSummary);

-------------------------------------------------
-- Event Listeners
-------------------------------------------------
function RefreshData()
	if (m_player:GetNetDiplomaticCapitalPerTurn() >= 0) then
		Controls.MyDiploLabel:SetText("[ICON_DIPLO_CAPITAL]" .. m_player:GetDiplomaticCapital() .. "(+" .. m_player:GetNetDiplomaticCapitalPerTurn() .. ")");
	else
		Controls.MyDiploLabel:SetText("[ICON_DIPLO_CAPITAL]" .. m_player:GetDiplomaticCapital() .. "[COLOR_RED](" .. m_player:GetNetDiplomaticCapitalPerTurn() .. ")");
	end
	
	Controls.MyDiploCapitalContainer:SetSizeX(Controls.MyDiploLabel:GetSizeX()+5);
	Controls.MySupremacyLabel:SetText("[ICON_SUPREMACY]"  .. m_player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE));
	Controls.MySupremacyContainer:SetSizeX(Controls.MySupremacyLabel:GetSizeX()+5);
	Controls.MyPurityLabel:SetText("[ICON_PURITY]"  .. m_player:GetAffinityLevel(PURITY_AFFINITY_TYPE));
	Controls.MyPurityContainer:SetSizeX(Controls.MyPurityLabel:GetSizeX()+5);
	Controls.MyHarmonyLabel:SetText("[ICON_HARMONY]"  .. m_player:GetAffinityLevel(HARMONY_AFFINITY_TYPE));
	Controls.MyHarmonyContainer:SetSizeX(Controls.MyHarmonyLabel:GetSizeX()+5);
	Controls.HeaderYieldStack:CalculateSize();
	Controls.HeaderYieldStack:ReprocessAnchoring();
end

function OnPlayerSelected(playerType : number, dontChangeState : boolean)
	-- Change the state to Actions
	if (not dontChangeState) then
		if (not DoNextPendingTransactionForPlayer(playerType)) then
			local isAtWar : boolean = Teams[m_player:GetTeam()]:IsAtWar(Players[playerType]:GetTeam());

			if (isAtWar and Players[playerType]:IsAlive()) then
				SetDiplomacyUIState(g_diplomacyUIStates.WAR, playerType);
				Events.LeaderSetVisible();
			else
				SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, playerType);
				Events.LeaderSetVisible();
			--	InitWordBubble();
			end
		end
	end

	InitInfoCard(m_selectedPlayerInfoCardInstance, m_selectedPlayer:GetID());
	InitInfoCard(m_activePlayerInfoCardInstance, m_player:GetID());

	UpdatePlayerRibbon();
end

function OnStateChanged(state : number, selectedPlayer : number)
	if (m_popupInfo == nil) then
		return;
	end

	m_selectedPlayer = Players[selectedPlayer];

	m_selectedPlayerActivityInstance.Content:SetHide(true);

	if (m_popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS and
		Game.GetNumPendingTransactionsWithReceivingPlayer(m_player:GetID()) == 0 and
		not m_transmissionCloseOverride) 
	then
		Close();	
	end

	-- Show or hide info cards
	if (state == g_diplomacyUIStates.ACTIONS) then
		m_selectedPlayerInfoCardInstance.Content:SetHide(not m_selectedPlayer:IsAlive());
		m_activePlayerInfoCardInstance.Content:SetHide(true);

		if (m_selectedPlayer ~= m_player) then
			if (m_selectedPlayer:IsAlive()) then
				m_selectedPlayerActivityInstance.Content:SetHide(false);
				m_selectedPlayerActivityInstance.CardAlphaAnim:SetToBeginning();
				m_selectedPlayerActivityInstance.CardAlphaAnim:Play();
				m_selectedPlayerActivityInstance.CardSlideAnim:SetToBeginning();
				m_selectedPlayerActivityInstance.CardSlideAnim:Play();
			end
		end
	elseif (state == g_diplomacyUIStates.AFFINITY) then
		m_selectedPlayerInfoCardInstance.Content:SetHide(not m_selectedPlayer:IsAlive());
		m_activePlayerInfoCardInstance.Content:SetHide(true);
	elseif (state == g_diplomacyUIStates.WAR or
			state == g_diplomacyUIStates.CONFRONTATION) 
	then
		m_selectedPlayerInfoCardInstance.Content:SetHide(not m_selectedPlayer:IsAlive());
		m_activePlayerInfoCardInstance.Content:SetHide(false);
	elseif (state == g_diplomacyUIStates.AGREEMENTS or 
			state == g_diplomacyUIStates.AGREEMENTS_FROM_ALL_SERVICES) 
	then
		if (m_selectedPlayer == m_player) then
			m_selectedPlayerInfoCardInstance.Content:SetHide(true);
			m_activePlayerInfoCardInstance.Content:SetHide(true);
		else
			m_selectedPlayerInfoCardInstance.Content:SetHide(false);
			m_activePlayerInfoCardInstance.Content:SetHide(false);
		end
	elseif (state == g_diplomacyUIStates.RELATIONSHIP) then
		m_selectedPlayerActivityInstance.Content:SetHide(true);
		m_selectedPlayerInfoCardInstance.Content:SetHide(false);
		m_activePlayerInfoCardInstance.Content:SetHide(false);
	else
		m_selectedPlayerInfoCardInstance.Content:SetHide(true);
		m_activePlayerInfoCardInstance.Content:SetHide(true);
	end

	UpdateLeaderCards();
	UpdateRecentActivity();	
	UpdateBreadcrumbs();
	UpdatePlayerRibbon();
end

function OnStatePushed(state : number)
	UpdateBreadcrumbs();
	RefreshData();
end

function OnStatePopped(state : number)
	UpdateBreadcrumbs();
	RefreshData();
end

function OnShowTutorialIntro(tutorialType : number, introTextKey : string)
	Controls.AdvisorCloseButton:RegisterCallback(Mouse.eLClick, function() 
		Controls.Advisor:SetHide(true);
	end);

	if (tutorialType ~= -1) then
		Controls.AdvisorShowMeButton:SetHide(false);
		Controls.AdvisorShowMeButton:RegisterCallback(Mouse.eLClick, function() 
			Controls.Advisor:SetHide(true);

			Events.SerialEventGameMessagePopup{
				Type = ButtonPopupTypes.BUTTONPOPUP_TUTORIAL,
				Data1 = tutorialType,
				Data2 = 1,
			};
		end);
	else
		Controls.AdvisorShowMeButton:SetHide(true);
	end

	Controls.AdvisorButtonStack:CalculateSize();
	Controls.AdvisorButtonStack:ReprocessAnchoring();

	Controls.AdvisorText:SetText(Locale.Lookup(introTextKey));

	Controls.Advisor:SetHide(false);
end

function OnAgreementCreated(agreementID : number)
	UpdateLeaderCards();
	RefreshData();
end

function OnDiplomacyRelationshipChanged(playerAType : number, playerBType : number, relationship : number)
	UpdateLeaderCards();
	UpdatePlayerRibbon();
	RefreshData();
end

function OnTraitLeveledUp(playerType : number, traitType : number, level : number)
	UpdateLeaderCards();
	RefreshData();
end

function OnTraitAdded(playerType : number, traitType : number)
	UpdateLeaderCards();
	RefreshData();
end

function OnTransactionCreated(id : number, showUI : boolean)
	if (not showUI) then
		return;
	end

	RefreshData();

	-- Trigger immediate popup in singleplayer.  Multiplayer will handle this thru the already sent notification.
	local transaction : object = Game.GetTransaction(id);
	if (not Game:IsNetworkMultiPlayer() and transaction:GetReceivingPlayer() == m_player:GetID()) then
		Events.SerialEventGameMessagePopup
		{
			Type = ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_PENDING_TRANSACTIONS,
			Data2 = transaction:GetSendingPlayer(),
			Data3 = id,
		};
	end
end

function OnActivePlayerChanged( iActivePlayer : number, iPrevActivePlayer : number )
	m_player = Players[iActivePlayer]; 	-- Update m_player
	RefreshData(); 						-- RefreshData using new m_player
	SelectPlayer(iActivePlayer); 		-- Select the active player so the screen looks fresh.
end

-------------------
-- Initialization
-------------------
function InitControls()
	-- Player's icon
	Controls.PlayerRibbon_PlayerButton:RegisterCallback(Mouse.eLClick, function() 
		m_transmissionCloseOverride = true;
		SelectPlayer(m_player:GetID());
	end);

	-- Build Leader Ribbon
	Controls.PlayerRibbon_Stack:DestroyAllChildren();
	m_playerRibbonEntryInstances = {};

	for playerType : number = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		local player : object = Players[playerType];
			
		if (not player:IsMinorCiv() and player:IsEverAlive()) then
			local instance : table = {};
				
			ContextPtr:BuildInstanceForControl("PlayerRibbonEntry", instance, Controls.PlayerRibbon_Stack);
			m_playerRibbonEntryInstances[playerType] = instance;
		end
	end

	Controls.PlayerRibbon_Stack:CalculateSize();
	Controls.PlayerRibbon_Stack:ReprocessAnchoring();

	-- Build selected player info
	m_selectedPlayerInfoCardInstance = {};
	ContextPtr:BuildInstanceForControl("InfoCard", m_selectedPlayerInfoCardInstance, Controls.SelectedPlayerInfoCardPlaceholder);
	m_selectedPlayerInfoCardInstance.Content:SetHide(true);

	-- Build active player info
	m_activePlayerInfoCardInstance = {};
	ContextPtr:BuildInstanceForControl("InfoCard", m_activePlayerInfoCardInstance, Controls.ActivePlayerInfoCardPlaceholder);
	m_activePlayerInfoCardInstance.Content:SetHide(true);
	m_activePlayerInfoCardInstance.Content:SetAnchor("R,T");

	-- Build recent activity\
	m_selectedPlayerActivityInstance = {};
	ContextPtr:BuildInstanceForControl("RecentActivity", m_selectedPlayerActivityInstance, Controls.SelectedPlayerActivityPlaceholder);
	m_selectedPlayerActivityInstance.Content:SetHide(true);

	local cardSize = 780;
	local cardOffsetX = 0;
	local cardOffsetY = 180;

	--Special sizing of the info cards for different screen resolutions
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	cardOffsetX = screenSizeX*.11;
	
	if((screenSizeX-cardOffsetX*2)<1940) then
		cardOffsetX = screenSizeX*.085;
		cardOffsetY = 120;
	else
		cardSize = (screenSizeX-2*cardOffsetX-200)/2;
	end

	--Size the bottom bar appropriately FOR SQUARE RESOLUTIONS
	if((screenSizeX/screenSizeY)==1.25) then
		Controls.BottomBox:SetSizeY(620);
	end

	Controls.SelectedPlayerActivityPlaceholder:SetOffsetX(cardOffsetX);
	Controls.SelectedPlayerActivityPlaceholder:SetOffsetY(cardOffsetY);
	
	m_selectedPlayerActivityInstance.Content:SetSizeX(cardSize+90);
	m_selectedPlayerActivityInstance.CardBacking:SetSizeX(cardSize);
	m_selectedPlayerActivityInstance.CardBackingDropShadow:SetSizeX(cardSize+90);


--	RefreshData();
end

function InitPlayerActivityInstance(instance : table, player : object)

	if (instance.CommuniqueEntriesInstanceManager == nil) then
		instance.CommuniqueEntriesInstanceManager = InstanceManager:new("CommuniqueEntry", "Content", instance.RecentActivityStack);
	end

	if (player:IsHuman()) then
		instance.Content:SetHide(true);
		return;
	end

	instance.CommuniqueEntriesInstanceManager:ResetInstances();
	
	if (player:GetNumCommuniqueRecords(m_player:GetID()) > 0) then
		local records : table = player:GetCommuniqueRecords(m_player:GetID());
		if (table.count(records) == 0 ) then	
			instance.NoCommuniques:SetHide(false);
		else
			instance.NoCommuniques:SetHide(true);
		end

		for i : number, record : object in ipairs(records) do
			local recordInstance = instance.CommuniqueEntriesInstanceManager:GetInstance();
			recordInstance.NewIndicator:SetHide(true);
			local reactionInfo = GameInfo.Reactions[record:GetReactionType()];
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
			end
			recordInstance.RespectDeltaContainer:SetToolTipString(tooltipString);
			recordInstance.RespectDelta:SetText(iconStr);
			recordInstance.Header:SetText( Locale.Lookup(reactionInfo.CommuniqueSubject));
			recordInstance.Message:SetText(Locale.Lookup(record:GetMessageTextKey()));
			local entryPadding = 30;
			if(record:GetTurnSent() == Game.GetGameTurn()) then
				recordInstance.NewIndicator:SetHide(false);
				recordInstance.NewIndicator:SetSizeX(recordInstance.NewLabel:GetSizeX()+30);
				recordInstance.DeltaAnim:Play();
			else
				recordInstance.DeltaAnim:SetToBeginning();
				recordInstance.DeltaAnim:Stop();
			end
			recordInstance.Message:SetWrapWidth(recordInstance.Content:GetSizeX()-10);
			recordInstance.Content:SetSizeY(recordInstance.Header:GetSizeY() + recordInstance.Message:GetSizeY() + entryPadding);
			recordInstance.ContentStack:CalculateSize();
			recordInstance.ContentStack:ReprocessAnchoring();
		end
	end

	instance.RecentActivityStack:CalculateSize()
	instance.RecentActivityStack:ReprocessAnchoring();
	instance.RecentActivityScrollPanel:ReprocessAnchoring();
	instance.RecentActivityScrollPanel:CalculateInternalSize();
end

function InitPlayerRibbonEntryInstance(instance : table, playerType : number)
	local player : object = Players[playerType];
	local leaderInfo : table = GameInfo.Leaders[player:GetLeaderType()];
	local civInfo : table = GameInfo.Civilizations[player:GetCivilizationType()];
	local relationshipInfo:table = GameInfo.RelationshipLevels[Game.GetRelationship(playerType, m_player:GetID())];

	instance.Content:SetHide(m_player:GetID() == playerType or not player:HasMadePlanetfall() or not Teams[m_player:GetTeam()]:IsHasMet(player:GetTeam()));
	
	-- Basic stuff
	IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, instance.Icon);
	instance.Name:SetText(Locale.Lookup(player:GetNameKey()));
	IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);
	instance.CivName:SetText(Locale.Lookup(player:GetCivilizationDescriptionKey()));

	if (player:IsAlive()) then
		instance.Icon:SetColor(0xffffffff);
	else
		instance.Icon:SetColor(0xff555555);
	end

	-- Relationship
	if (playerType ~= m_player:GetID() and Players[playerType]:IsAlive()) then
		instance.Relationship:SetHide(false);

		local str : string = "[COLOR_".. relationshipInfo.Type.. "]" .. Locale.Lookup("{"..relationshipInfo.Description..":upper}");
		if (Players[playerType]:GetTeam() == m_player:GetTeam()) then
			str = str .. " (" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_TEAMMATE") .. ")";
		end

		instance.Relationship:SetText(str);
	else
		instance.Relationship:SetHide(true);
	end

	if (OptionsManager.GetDiploShowRelativeRelationships_Cached() and 
		playerType ~= m_selectedPlayer:GetID() and 
		m_selectedPlayer:GetID() ~= m_player:GetID() and
		Players[playerType]:IsAlive() and
		m_selectedPlayer:IsAlive()) 
	then
		instance.RelationshipToOthers:SetHide(false);
		local relationshipLevelToSelected : number = Game.GetRelationship(playerType, m_selectedPlayer:GetID());
		local relationshipToSelectedInfo = GameInfo.RelationshipLevels[relationshipLevelToSelected];
		local relationshipStrKey : string = relationshipToSelectedInfo.Description;
		-- Override description in case of war for proper grammar
		if (relationshipToSelectedInfo.Type == "RELATIONSHIP_LEVEL_WAR") then
			relationshipStrKey = "TXT_KEY_DO_AT_WAR";
		end
		local selectedPlayer = Players[m_selectedPlayer:GetID()];
		local currPlayer = Players[playerType];
		local relationshipToOthersOffset : number = relationshipLevelToSelected * 30 * 2;
		instance.RelationshipToOthers:SetTextureOffsetVal(0, relationshipToOthersOffset);
		instance.RelationshipToOthers:SetToolTipString(Locale.Lookup("TXT_KEY_DIPLO_RELATIONSHIPWITH", selectedPlayer:GetNameKey(), relationshipToSelectedInfo.Type, relationshipStrKey, currPlayer:GetNameKey()));
	else
		instance.RelationshipToOthers:SetHide(true);
	end

	-- Traits stack
	local traits : table = player:GetPersonalityTraits();
	for i : number, trait : object in ipairs(traits) do
		if (instance.TraitInstances == nil) then
			instance.TraitInstances = {};
		end

		if (instance.TraitInstances[i] == nil) then
			local traitInstance : table = {};
			ContextPtr:BuildInstanceForControl("SmallTraitEntry", traitInstance, instance.TraitsStack);
			instance.TraitInstances[i] = traitInstance;
		else
			
		end
		InitSmallTraitEntryInstance(instance.TraitInstances[i], trait);
	end

	instance.TraitsStack:CalculateSize();
	instance.TraitsStack:ReprocessAnchoring();

	-- Callbacks
	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		m_transmissionCloseOverride = true;
		SelectPlayer(player:GetID());
	end);
end

function SetFearAndRespect(instance: table, playerID: number)
	-- Fear and Respect intercepted during War!
	local player : object = Players[playerID];
	if (Teams[m_player:GetTeam()]:IsAtWar(player:GetTeam())) then
		instance.RespectContainer:SetHide(true);
		instance.FearContainer:SetHide(true);
		return;
	else
		instance.RespectContainer:SetHide(player:IsHuman());
		instance.FearContainer:SetHide(player:IsHuman());
	end

	local fearID = Players[playerID]:GetFearStage(m_player:GetID());
	local respectID = Players[playerID]:GetRespectStage(m_player:GetID());
	
	local fearStageInfo : table = GameInfo.Stages[fearID];
	local fearStages : table = GetFearStageInfos();
	local fearStageVal : number = fearStageInfo.UIOrder;

	
	local respectStageInfo : table = GameInfo.Stages[respectID];
	local respectStages : table = GetRespectStageInfos();
	local respectStageVal : number= respectStageInfo.UIOrder;

	instance.FearLVLValue:SetText(fearStageVal);
	instance.FearPossValue:SetText("/".. table.count(fearStages)-1);
	instance.RespectLVLValue:SetText(respectStageVal);
	instance.RespectPossValue:SetText("/".. table.count(respectStages)-1);

	local respectVal = Players[playerID]:GetRespect(m_player:GetID());
	local respectPercent = respectVal / 100;
	instance.RespectMeter:SetPercent(respectPercent);
	local fearVal = Players[playerID]:GetFear(m_player:GetID());
	local fearPercent = fearVal / 100;
	instance.FearMeter:SetPercent(fearPercent);
end

function round(num, idp)
  if idp and idp>0 then
    local mult = 10^idp
    return math.floor(num * mult + 0.5) / mult
  end
  return math.floor(num + 0.5)
end


function InitInfoCard(instance : table, playerType : number)
	local player : object = Players[playerType];
	local civInfo : table = GameInfo.Civilizations[player:GetCivilizationType()];
	local relationshipInfo : table = GameInfo.RelationshipLevels[Game.GetRelationship(player:GetID(), m_player:GetID())];
	-- 
	local cardSize = 780;
	local cardOffsetX = 0;
	local cardOffsetY = 180;

	--Special sizing of the info cards for different screen resolutions
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	cardOffsetX = screenSizeX*.11;
	
	if((screenSizeX-cardOffsetX*2)<1940) then
		cardOffsetX = screenSizeX*.085;
		cardOffsetY = 120;
	else
		cardSize = (screenSizeX-2*cardOffsetX-200)/2;
	end

	Controls.SelectedPlayerInfoCardPlaceholder:SetOffsetX(cardOffsetX);
	Controls.ActivePlayerInfoCardPlaceholder:SetOffsetX(cardOffsetX);
	Controls.SelectedPlayerActivityPlaceholder:SetOffsetX(cardOffsetX);
	Controls.SelectedPlayerInfoCardPlaceholder:SetOffsetY(cardOffsetY);
	Controls.ActivePlayerInfoCardPlaceholder:SetOffsetY(cardOffsetY);
	Controls.SelectedPlayerActivityPlaceholder:SetOffsetY(cardOffsetY);
	
	instance.Content:SetSizeX(cardSize+90);
	instance.CardBacking:SetSizeX(cardSize);
	instance.CardBackingDropShadow:SetSizeX(cardSize+90);
	
	-- Icons and basic info
	CivIconHookup( player:GetID(), 64, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
	IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);
	instance.Name:SetText(Locale.Lookup(player:GetNameKey()));
	instance.CivName:SetText(Locale.Lookup(player:GetCivilizationDescriptionKey()));
	if(instance.Name:GetSizeX() > instance.CardBacking:GetSizeX()-120) then
		instance.Name:SetHide(true);
		instance.NameSmall:SetHide(false);
		instance.NameSmall:SetText(Locale.Lookup(player:GetNameKey()));
	else
		instance.Name:SetHide(false);
		instance.NameSmall:SetHide(true);
	end
	
	if(instance.CivName:GetSizeX() > instance.CardBacking:GetSizeX()-120) then
		instance.CivName:SetHide(true);
		instance.CivNameSmall:SetHide(false);
		instance.CivNameSmall:SetText(Locale.Lookup(player:GetCivilizationDescriptionKey()));
		instance.CivNameSmall:SetWrapWidth(instance.CardBacking:GetSizeX()-120);
	else
		instance.CivName:SetHide(false);
		instance.CivNameSmall:SetHide(true);
		instance.CivName:SetWrapWidth(instance.CardBacking:GetSizeX()-120);
	end
	

	-- Relationship
	if (playerType ~= m_player:GetID()) then				
		instance.Relationship:SetHide(false);

		local str : string = "[COLOR_".. relationshipInfo.Type.. "]" .. Locale.Lookup("{"..relationshipInfo.Description..":upper}");
		if (Players[playerType]:GetTeam() == m_player:GetTeam()) then
			str = str .. " (" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_TEAMMATE") .. ")";
		end
		instance.Relationship:SetText(str);
		
		SetFearAndRespect(instance, playerType);
	else
		instance.Relationship:SetHide(true);
		instance.FearContainer:SetHide(true);
		instance.RespectContainer:SetHide(true);
	end

	-- Stats
	
	if (player:GetNetDiplomaticCapitalPerTurn() >= 0) then
		instance.DiploLabel:SetText("[ICON_DIPLO_CAPITAL]" .. player:GetDiplomaticCapital() .. "(+" .. player:GetNetDiplomaticCapitalPerTurn() .. ")");
	else
		instance.DiploLabel:SetText("[ICON_DIPLO_CAPITAL]" .. player:GetDiplomaticCapital() .. "[COLOR_RED](" .. player:GetNetDiplomaticCapitalPerTurn() .. ")");
	end
	instance.DiploCapitalContainer:SetSizeX(instance.DiploLabel:GetSizeX()+5);
	instance.SupremacyLabel:SetText("[ICON_SUPREMACY]"  .. player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE));
	instance.SupremacyContainer:SetSizeX(instance.SupremacyLabel:GetSizeX()+5);
	instance.PurityLabel:SetText("[ICON_PURITY]"  .. player:GetAffinityLevel(PURITY_AFFINITY_TYPE));
	instance.PurityContainer:SetSizeX(instance.PurityLabel:GetSizeX()+5);
	instance.HarmonyLabel:SetText("[ICON_HARMONY]"  .. player:GetAffinityLevel(HARMONY_AFFINITY_TYPE));
	instance.HarmonyContainer:SetSizeX(instance.HarmonyLabel:GetSizeX()+5);
	instance.YieldStack:CalculateSize();
	instance.YieldStack:ReprocessAnchoring();

	-- Show relationship check
	if (m_player:GetID() ~= playerType) then
		OptionsManager.SetDiploShowRelativeRelationships_Cached(true);
		OptionsManager.CommitGameOptions();
	end

	-- Traits
	if (instance.TraitsInstanceManager == nil) then
		instance.TraitsInstanceManager = InstanceManager:new("SmallTraitEntry", "Content", instance.TraitsStack);
	end
	instance.TraitsInstanceManager:ResetInstances();
	
	local traits : table = player:GetPersonalityTraits();
	for i : number, trait : object in ipairs(traits) do
		local traitInstance : table = instance.TraitsInstanceManager:GetInstance();			
		InitSmallTraitEntryInstance(traitInstance, trait);
		if(playerType ~= m_player:GetID()) then
			traitInstance.Button:SetDisabled(true);
		else
			traitInstance.Button:SetDisabled(false);
			traitInstance.Button:RegisterCallback(Mouse.eLClick, function() 
				PushDiplomacyUIState(g_diplomacyUIStates.TRAITS, m_player:GetID());
				Events.LeaderSetVisible();
			end);
		end
	end

	instance.TraitsStack:CalculateSize();
	instance.TraitsStack:ReprocessAnchoring();

	-- Agreements
	if (instance.AgreementsInstanceManager == nil) then
		instance.AgreementsInstanceManager = InstanceManager:new("SmallAgreementEntry", "Content", instance.AgreementsStack);
	end
	instance.AgreementsInstanceManager:ResetInstances();

	local agreements : table = Game.GetAgreementsWithProposingPlayer(player:GetID());
	if (#agreements > 0) then
		instance.OtherLeaderHasNoAgreements:SetHide(true);
		for i : number, agreement : object in ipairs(agreements) do
			if (not agreement:IsCanceled()) then
				local agreementInstance : table = instance.AgreementsInstanceManager:GetInstance();
				InitSmallAgreementEntryInstance(agreementInstance, agreement);
				--  This is supposed to take you to the generic BROWSE SERVICES page, when it gets implemented
				--	<3, WB
		--		instance["PurchaseServiceButton"..i]:RegisterCallback(Mouse.eLClick, function() 
		--		end);
				
			end
		end
	else
		if(playerType ~= m_player:GetID()) then
			instance.OtherLeaderHasNoAgreements:SetHide(false);
			instance.OtherLeaderHasNoAgreements:SetText(Locale.Lookup(player:GetNameKey()).." "..Locale.Lookup("{TXT_KEY_DIPLOMACYUI_OTHERSPONSORHASNOAGREEMENTS}"));
		end
	end

	if(playerType ~= m_player:GetID()) then
		instance.EmptyServicesStack:SetHide(true);
	else
		instance.OtherLeaderHasNoAgreements:SetHide(true);
		instance.EmptyServicesStack:SetHide(false);
	end

	instance.AgreementsStack:CalculateSize();
	instance.AgreementsStack:ReprocessAnchoring();
end

function InitSmallTraitEntryInstance(instance : table, trait : object)
	local traitInfo : table = GameInfo.PersonalityTraits[trait:GetType()];
	local perkInfo : table = FindPerkForTrait(traitInfo, trait:GetLevel());
	
	IconHookup(traitInfo.PortraitIndex, 32, traitInfo.IconAtlas, instance.Icon);
	
	local traitTipStr : string = Locale.Lookup(traitInfo.Description);
	
	local helpStr : string = nil;
	if (traitInfo.Unique) then
		helpStr = Locale.Lookup("TXT_KEY_CHARACTER_TRAIT_HELP");
	else
		helpStr = Locale.Lookup(traitInfo.Help);
	end
	traitTipStr = traitTipStr.."[NEWLINE][NEWLINE]"..helpStr;

	if (perkInfo ~= nil) then
		local perkStr : string = Locale.Lookup("TXT_KEY_DIPLOMACYUI_BONUS_HEADER", trait:GetLevel()) .. "[NEWLINE]" .. Locale.Lookup(perkInfo.Help)
		traitTipStr = traitTipStr.."[NEWLINE][NEWLINE]"..perkStr;
	end

	instance.Icon:SetToolTipString(traitTipStr);
end

function InitSmallAgreementEntryInstance(instance : table, agreement : object)
	local policyInfo : table = GameInfo.ForeignPolicies[agreement:GetForeignPolicy()];
	local targetPlayer : object = Players[agreement:GetTargetPlayer()];

	instance.PolicyIcon:SetToolTipString(GetAgreementToolTip(agreement));
	instance.CivIconFrame:SetToolTipString(Locale.Lookup(targetPlayer:GetName()));
	local civInfo : table = GameInfo.Civilizations[targetPlayer:GetCivilizationType()];
	-- Icons and basic info
	CivIconHookup( targetPlayer:GetID(), 32, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
	IconHookup( policyInfo.PortraitIndex, 32, policyInfo.IconAtlas, instance.PolicyIcon);
end

function InitBreadcrumbEntryInstance(instance : table, state : number, breadcrumbString : string)
	instance.Label:SetText(breadcrumbString);
	local x = instance.Label:GetSizeX() + 35;
	instance.Button:SetSizeX(x);
	instance.Button:SetSizeY(56);
	instance.Content:SetSizeX(x);
	instance.Content:SetSizeY(56);
end
