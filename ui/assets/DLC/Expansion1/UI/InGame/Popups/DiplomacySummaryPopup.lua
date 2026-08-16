-------------------------------------------------
-- Diplomacy Summary
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");
include("UIExtras");

local HARMONY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID;
local PURITY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID;
local SUPREMACY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID;

local SortBy : table =
{
	LEADER = 1,
	SCORE = 2,
	WONDERS = 3,
};

local SortOrder : table =
{
	ASCENDING = 1,
	DESCENDING = 2,
};

local m_popupInfo : table = nil;
local m_player : object = nil;
local m_sortBy : number = SortBy.LEADER;
local m_sortOrder : number = SortOrder.ASCENDING;
local m_players : table = {};
local m_topThree : table = {};
local m_shownInGame : boolean = true; -- Whether we are being shown from diplo screen or in-game

local m_gameParentControl : object = nil;
local m_diploParentControl : object = nil;

local m_entriesInstanceManager : table = InstanceManager:new("Entry", "Content", Controls.EntriesStack);

-------------------------------------------------
-- Functions
-------------------------------------------------
function Update()
	SetParent();
	SortPlayers(m_sortBy);

	m_entriesInstanceManager:ResetInstances();

	for i : number, player : object in ipairs(m_players) do
		if (Teams[m_player:GetTeam()]:IsHasMet(player:GetTeam()) and player:HasMadePlanetfall()) then
			local instance : table = m_entriesInstanceManager:GetInstance();
			InitEntryInstance(instance, player);
			instance.ContentStack:CalculateSize();
			instance.ContentStack:ReprocessAnchoring();
		end
	end
	
	Controls.EntriesStack:CalculateSize();
	Controls.EntriesStack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();

	if (IsScrollbarShowing(Controls.ScrollPanel)) then
		Controls.Grid:SetSizeX(1008+16);
	else
		Controls.Grid:SetSizeX(1008);
	end

	Controls.Grid:ReprocessAnchoring();
end

function SetParent()
	if (m_gameParentControl == nil or m_diploParentControl == nil) then
		m_gameParentControl = ContextPtr:LookUpControl("/InGame/SummaryPlaceholder");
		m_diploParentControl = ContextPtr:LookUpControl("/LeaderHeadRoot/Diplomacy/SummaryPlaceholder");
	end

	if (m_shownInGame) then
		ContextPtr:ChangeParent(m_gameParentControl);
	else
		ContextPtr:ChangeParent(m_diploParentControl);
	end

	Controls.BlockerInGame:SetHide(not m_shownInGame);
	Controls.BlockerDiplo:SetHide(m_shownInGame);
end

function SortPlayers(sortBy : number)
	table.sort(m_players, function(a, b) 
		if (sortBy == SortBy.LEADER) then
			if (m_sortOrder == SortOrder.ASCENDING) then
				return Locale.Compare(Locale.Lookup(a:GetName()), Locale.Lookup(b:GetName())) == -1;
			else
				return Locale.Compare(Locale.Lookup(a:GetName()), Locale.Lookup(b:GetName())) == 1;
			end
		elseif (sortBy == SortBy.SCORE) then
			if (m_sortOrder == SortOrder.ASCENDING) then
				return a:GetScore() > b:GetScore();
			else
				return a:GetScore() < b:GetScore();
			end
		elseif (sortBy == SortBy.WONDERS) then
			if (m_sortOrder == SortOrder.ASCENDING) then
				return a:GetNumWorldWonders() > b:GetNumWorldWonders();
			else
				return a:GetNumWorldWonders() < b:GetNumWorldWonders();
			end
		else
			error("Unhandled filter state");
		end
	end);
end

function InitEntryInstance(instance : table, player : object)
	local civInfo : table = GameInfo.Civilizations[player:GetCivilizationType()];
	local relationshipInfo : table = GameInfo.RelationshipLevels[Game.GetRelationship(player:GetID(), m_player:GetID())];
	local leaderInfo : table = GameInfo.Leaders[player:GetLeaderType()];

	-- Instance managers
	if (instance.TraitsInstanceManager == nil) then
		instance.TraitsInstanceManager = InstanceManager:new("SmallTraitEntry", "Content", instance.TraitsStack)
	end
	instance.TraitsInstanceManager:ResetInstances();

	if (instance.AgreementsInstanceManager == nil) then
		instance.AgreementsInstanceManager = InstanceManager:new("SmallAgreementEntry", "Content", instance.AgreementsStack);
	end
	instance.AgreementsInstanceManager:ResetInstances();

	-- Leader
	if (player == m_player) then
		instance.Name:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_ME", player:GetName()));
	else
		instance.Name:SetText(player:GetName());
	end
	instance.CivName:SetText(Locale.Lookup(civInfo.Description));
	CivIconHookup(player:GetID(), 64, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight);

	IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, instance.Icon);
	IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);
	instance.CivName:SetText(Locale.Lookup(civInfo.Description));

	local relationshipOffset : number = 75*relationshipInfo.ID;
	instance.RelationshipIndicator:SetTextureOffsetVal(50,relationshipOffset);

	if (player:IsAlive()) then
		instance.Icon:SetColor(0xffffffff);
	else
		instance.Icon:SetColor(0x55ffffff);
	end

	local numPendingTransaction : number = Game.GetNumPendingTransactions(player:GetID(), m_player:GetID());
	instance.TalkIndicator:SetHide(numPendingTransaction == 0);

	-- Traits
	instance.TraitsInstanceManager:ResetInstances();
	local traits : table = player:GetPersonalityTraits();
	for i : number, trait : object in ipairs(traits) do
		local traitInstance : table = instance.TraitsInstanceManager:GetInstance();
		InitSmallTraitEntryInstance(traitInstance, trait);
		traitInstance.Button:RegisterCallback(Mouse.eLClick, function()		
			if (m_shownInGame) then
				Events.SerialEventGameMessagePopup {
					Type = ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW,
					Data2 = player:GetID(),
				};
			else
				SetDiplomacyUIState(g_diplomacyUIStates.TRAITS, m_player:GetID());
				Events.LeaderSetVisible();
			end

			OnClose();
		end);
	end
	instance.TraitsStack:CalculateSize();
	instance.TraitsStack:ReprocessAnchoring();

	-- Stats
	if (player:GetID() ~= m_player:GetID()) then
		instance.Relationship:SetHide(false);
		instance.Relationship:SetText("[COLOR_".. relationshipInfo.Type.. "]" .. Locale.Lookup("{"..relationshipInfo.Description..":upper}"));
		SetFearAndRespect(instance, player:GetID());
	else
		instance.Relationship:SetHide(true);
		instance.FearContainer:SetHide(true);
		instance.RespectContainer:SetHide(true);
	end

	local capitalPerTurn : number = player:GetNetDiplomaticCapitalPerTurn();
	if (capitalPerTurn > 0) then
		instance.Capital:SetText("[ICON_DIPLO_CAPITAL]" .. player:GetDiplomaticCapital() .. "(+" .. capitalPerTurn .. ")");
	else
		instance.Capital:SetText("[ICON_DIPLO_CAPITAL]" .. player:GetDiplomaticCapital() .. "([COLOR_RED]" .. capitalPerTurn .. "[ENDCOLOR])");
	end
	
	instance.HarmonyAffinity:SetText("[ICON_HARMONY]" .. player:GetAffinityLevel(HARMONY_AFFINITY_TYPE));
	instance.PurityAffinity:SetText("[ICON_PURITY]" .. player:GetAffinityLevel(PURITY_AFFINITY_TYPE));
	instance.SupremacyAffinity:SetText("[ICON_SUPREMACY]" .. player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE));

	-- Score
	instance.Rank:SetHide(true);
	for i=1,3 do
		if(m_topThree[i] ~= nil and m_topThree[i] == player:GetID()) then
			instance.Rank:SetHide(false);
			instance.Rank:SetTextureOffsetVal(0,(i-1)*56);
		end
	end
	instance.Score:SetText(player:GetScore());

	local scoreBreakdown : table = {};
	GetPlayersScorePieces(player, scoreBreakdown);
	local scoreTooltip : string = table.concat(scoreBreakdown, "[NEWLINE]");
	instance.Score:SetToolTipString(scoreTooltip);

	-- Wonders
	instance.Wonders:SetText(player:GetNumWorldWonders());
	local wondersBuilt : table = {};
	for building : table in GameInfo.BuildingClasses() do
		if (building.MaxGlobalInstances == 1 and player:GetBuildingClassCount(building.ID) > 0) then
			table.insert(wondersBuilt, building);
		end
	end

	local wondersTT : string = "";
	if (#wondersBuilt > 0) then
		for i : number, info : table in ipairs(wondersBuilt) do
			if (i > 1) then
				wondersTT = wondersTT .. "[NEWLINE]";
			end
			wondersTT = wondersTT .. "[ICON_BULLET]" .. Locale.Lookup(info.Description);

		end
	end
	instance.WondersContainer:SetToolTipString(wondersTT);

	-- Agreements
	instance.AgreementsInstanceManager:ResetInstances();
	local agreements : table = Game.GetAgreementsWithProposingPlayer(player:GetID());
	if (#agreements > 0) then
		instance.NoAgreements:SetHide(true);

		for i : number, agreement : object in ipairs(agreements) do
			local agreementInstance : table = instance.AgreementsInstanceManager:GetInstance();
			InitSmallAgreementEntryInstance(agreementInstance, agreement);
		end
	else
		instance.NoAgreements:SetHide(false);
	end

	-- Button
	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		if (m_shownInGame) then
			Events.SerialEventGameMessagePopup {
				Type = ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_OVERVIEW,
				Data2 = player:GetID(),
			};
		else
			local relationship : number = Game.GetRelationship(m_player:GetID(), player:GetID());

			if (not DoNextPendingTransactionForPlayer(player:GetID())) then
				if (relationship == RelationshipLevels.RELATIONSHIP_WAR and player:IsAlive()) then
					SetDiplomacyUIState(g_diplomacyUIStates.WAR, player:GetID());
				else
					SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, player:GetID());
				end
			end

			Events.LeaderSetVisible();
		end

		OnClose();
	end);

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
	local fearStageVal = 0;
	local fearStageInfo: table = GameInfo.Stages[fearID];
	local fearStages: table = GetFearStageInfos();
	for i=1,table.count(fearStages),1 do
		if (fearStages[i].Type == fearStageInfo.Type) then
			fearStageVal = i-1;
			break;
		end
	end
	local respectStageVal = 0;
	local respectStageInfo: table = GameInfo.Stages[respectID];
	local respectStages: table = GetRespectStageInfos();
	for i=1,table.count(respectStages),1 do
		if (respectStages[i].Type == respectStageInfo.Type) then
			respectStageVal = i-1;
		end
	end
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

-------------------------------------------------
-- Event Handlers
-------------------------------------------------
function OnPopup(popupInfo : table)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY_SUMMARY) then
		return;
	end

	m_popupInfo = popupInfo;
	m_shownInGame = m_popupInfo.Data2 ~= 1;

	SortPlayers(SortBy.SCORE);
	for i=1, 3 do
		if (m_players[i] ~= nil) then
			m_topThree[i] = m_players[i]:GetID();
		end
	end 

	if (m_popupInfo.Data1 == 1) then
		if (not ContextPtr:IsHidden()) then
			OnClose();
		else
			if (m_shownInGame) then
				UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
			else
				ContextPtr:SetHide(false);
			end
		end
	else
		if (m_shownInGame) then
			UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
		else
			ContextPtr:SetHide(false);
		end
	end
end

-------------------------------------------------
-- Callback Handlers
-------------------------------------------------
function OnInitialize(isHotLoad : boolean)
	m_players = {};
	m_topThree = {};
	for playerType : number = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		local player : object = Players[playerType];

		if (not player:IsMinorCiv() and player:IsEverAlive()) then
			table.insert(m_players, player);
		end
	end

	-- Register events
	Events.SerialEventGameMessagePopup.Add(OnPopup);
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	-- Unregister events
	Events.SerialEventGameMessagePopup.Remove(OnPopup);
end
ContextPtr:SetShutdown(OnShutdown);

function InputHandler(msg : number, wParam : number, lParam : number)
	if (msg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN) then
			OnClose();
			return true;
		elseif (wParam == Keys.VK_F4 and not m_shownInGame) then
			OnClose();
		end
	end
end
ContextPtr:SetInputHandler(InputHandler);

function ShowHideHandler(isHide: boolean)
	if (not isHide) then
		Controls.AlphaAnim:SetToBeginning();
		Controls.AlphaAnim:Play();

		m_player = Players[Game.GetActivePlayer()];
		Update();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)

function OnClose()
	if (m_shownInGame) then
		UIManager:DequeuePopup(ContextPtr);
	else
		ContextPtr:SetHide(true);
	end
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);

function SwitchSortOrder()
	if (m_sortOrder == SortOrder.ASCENDING) then
		m_sortOrder = SortOrder.DESCENDING;
	else
		m_sortOrder = SortOrder.ASCENDING;
	end
end

function OnSortByLeader()
	if (m_sortBy == SortBy.LEADER) then
		SwitchSortOrder();
	else
		m_sortBy = SortBy.LEADER;
		m_sortOrder = SortOrder.ASCENDING;
	end

	Update();
end
Controls.SortByLeaderButton:RegisterCallback(Mouse.eLClick, OnSortByLeader);

function OnSortByScore()
	if (m_sortBy == SortBy.SCORE) then
		SwitchSortOrder();
	else
		m_sortBy = SortBy.SCORE;
		m_sortOrder = SortOrder.ASCENDING;
	end

	Update();
end
Controls.SortByScoreButton:RegisterCallback(Mouse.eLClick, OnSortByScore);

function OnSortByWonders()
	if (m_sortBy == SortBy.WONDERS) then
		SwitchSortOrder();
	else
		m_sortBy = SortBy.WONDERS;
		m_sortOrder = SortOrder.ASCENDING;
	end

	Update();
end
Controls.SortByWondersButton:RegisterCallback(Mouse.eLClick, OnSortByWonders);