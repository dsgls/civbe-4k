-------------------------------------------------
-- Agreements Diplomacy State
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");
include("ConversationSystem");

local m_player : object = nil;
local m_selectedPlayer : object = nil;
local m_shown : boolean = false;
local m_selectedPolicyInfo : table = nil;
local m_waitingForTransaction : boolean = false;
local m_tabs : table = nil;

local SortAllServicesBy : table = 
{
	SPONSOR = 1,
	SERVICE = 2,
	COST = 3,
};

local SortOrder : table =
{
	ASCENDING = 1,
	DESCENDING = 2,
};

local m_sortAllServicesBy : number = SortAllServicesBy.SPONSOR;
local m_sortOrder : number = SortOrder.ASCENDING;

local m_acceptedPolicyInstance : table = {};
local m_proposedPolicyInstance : table = {};
local m_foreignPolicyEntryInstanceManager : table = InstanceManager:new("ForeignPolicyEntry", "Content", Controls.MyProposePolicyStack);
local m_myAgreementEntryInstanceManager : table = InstanceManager:new("AgreementEntry", "Content", Controls.AgreementsStack);
local m_theirAgreementEntryInstanceManager : table = InstanceManager:new("AgreementEntry", "Content", Controls.AgreementsMadeWithMeStack);
local m_incomeAgreementEntryInstanceManager : table = InstanceManager:new("IncomeAgreementEntry", "Content", Controls.IncomeAgreementsStack);
local m_allServicesAgreementEntryInstanceManager : table = InstanceManager:new("AgreementEntry", "Content", Controls.AllServicesStack);

function ShowHideHandler(isHide : boolean)
	if (not isHide) then
		m_waitingForTransaction = false;

		if (m_selectedPlayer == m_player) then
			Controls.ConversationContent:SetHide(true);
			
			local state : number = UI.GetCurrentDiplomacyUIState();
			if (state == g_diplomacyUIStates.AGREEMENTS or state == g_diplomacyUIStates.AGREEMENTS_FROM_ALL_SERVICES) then
				Controls.AllServicesContent:SetHide(true);
				Controls.AgreementsOverviewContent:SetHide(false);
				UpdateMyAgreements();

				ShowDiploTutorial("DIPLOMACY_MY_AGREEMENTS", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_MY_AGREEMENTS"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_MY_AGREEMENTS");
			elseif (state == g_diplomacyUIStates.ALL_SERVICES) then
				Controls.AllServicesContent:SetHide(false);
				Controls.AgreementsOverviewContent:SetHide(true);
				UpdateAllPolicies();

				ShowDiploTutorial("DIPLOMACY_BROWSE_ALL_AGREEMENTS", -1, "TXT_KEY_DIPLOMACYUI_TUTORIAL_BROWSE_ALL_AGREEMENTS");
			else
				error("Unhandled state");
			end
		else
			local numOutstandingRequests : number = Game.GetNumPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID());
			local numIncomingRequests : number = Game.GetNumPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID());
			local areAgreementsAvailable : boolean = Game.AreAnyAgreementsAvailable(m_player:GetID(), m_selectedPlayer:GetID());

			if (numIncomingRequests > 0 and numOutstandingRequests == 0) then
				local pendingTransactions : table = Game.GetPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID());
				for i : number, transaction : object in ipairs(pendingTransactions) do
					if (transaction:GetForeignPolicy() ~= -1) then
						DoThinkingAboutIt(false);
						return;
					end
				end
			end
			
			if (numOutstandingRequests > 0) then
				local transactions : table = Game.GetPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID());
				for i : number, transaction : object in ipairs(transactions) do
					if (transaction:GetForeignPolicy() ~= -1) then
						DoResolveAgreementTransaction(transaction);
						return;
					end
				end

				DoSelectPolicy();
			elseif (Game.AreAnyAgreementsAvailable(m_player:GetID(), m_selectedPlayer:GetID())) then
				if (Game.GetNumAgreementsWithProposingPlayer(m_player:GetID()) < GameDefines.DIPLO_MAX_AGREEMENTS) then
					Controls.AllServicesContent:SetHide(true);
					Controls.ConversationContent:SetHide(false);
					Controls.AgreementsOverviewContent:SetHide(true);

					DoSelectPolicy();
				else 
					Controls.AllServicesContent:SetHide(true);
					Controls.ConversationContent:SetHide(false);
					Controls.AgreementsOverviewContent:SetHide(true);

					DoTooManyAgreements();
				end
			else
				Controls.AllServicesContent:SetHide(true);
				Controls.ConversationContent:SetHide(false);
				Controls.AgreementsOverviewContent:SetHide(true);

				DoNotAcceptingAgreements();
			end

			ShowDiploTutorial("DIPLOMACY_MAKING_AGREEMENTS", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_MAKING_AGREEMENTS"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_MAKING_AGREEMENTS");
		end

		UpdateConversationControlSizes();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function UpdateAllPolicies()
	m_allServicesAgreementEntryInstanceManager:ResetInstances();

	local policyData : table = {};
	for otherPlayerType : number = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		if (otherPlayerType ~= m_player:GetID() and 
			Teams[m_player:GetTeam()]:IsHasMet(Players[otherPlayerType]:GetTeam()) and 
			Players[otherPlayerType]:IsAlive()) 
		then
			local otherPlayer : object = Players[otherPlayerType];
			local relationshipLevel : number = Game.GetRelationship(m_player:GetID(), otherPlayerType);
			local policyTypes : table = otherPlayer:GetForeignPolicies();

			for i : number, policyType : number in ipairs(policyTypes) do
				if (not (Game.HasMadeAgreementWithPolicy(m_player:GetID(), otherPlayerType, policyType))) then
					table.insert(policyData, 
					{
						PolicyType = policyType;
						OtherPlayerType = otherPlayerType;
						RelationshipLevel = relationshipLevel;
					});
				end
			end
		end
	end

	table.sort(policyData, function(a, b) 
		if (m_sortAllServicesBy == SortAllServicesBy.SPONSOR) then
			local playerA : table = Players[a.OtherPlayerType];
			local playerB : table = Players[b.OtherPlayerType];
			local otherLeaderInfoA : table = GameInfo.Leaders[playerA:GetLeaderType()];
			local otherLeaderInfoB : table = GameInfo.Leaders[playerB:GetLeaderType()];
			
			if (m_sortOrder == SortOrder.ASCENDING) then
				return Locale.Compare(Locale.Lookup(otherLeaderInfoA.Description), Locale.Lookup(otherLeaderInfoB.Description)) == -1;
			else
				return Locale.Compare(Locale.Lookup(otherLeaderInfoA.Description), Locale.Lookup(otherLeaderInfoB.Description)) == 1;
			end
		elseif (m_sortAllServicesBy == SortAllServicesBy.NAME) then
			local policyInfoA : table = GameInfo.ForeignPolicies[a.PolicyType];
			local policyInfoB : table = GameInfo.ForeignPolicies[b.PolicyType];

			if (m_sortOrder == SortOrder.ASCENDING) then
				return Locale.Compare(Locale.Lookup(policyInfoA.Description), Locale.Lookup(policyInfoB.Description)) == -1;
			else
				return Locale.Compare(Locale.Lookup(policyInfoA.Description), Locale.Lookup(policyInfoB.Description)) == 1;
			end
		elseif (m_sortAllServicesBy == SortAllServicesBy.COST) then
			if (m_sortOrder == SortOrder.ASCENDING) then
				return m_player:GetForeignPolicyPurchaseCapitalCost(a.PolicyType) < m_player:GetForeignPolicyPurchaseCapitalCost(b.PolicyType);
			else
				return m_player:GetForeignPolicyPurchaseCapitalCost(a.PolicyType) > m_player:GetForeignPolicyPurchaseCapitalCost(b.PolicyType);
			end
		else
			error("Unhandled sort");
		end
	end);

	for i : number, data : table in ipairs(policyData) do
		local otherPlayer : object = Players[data.OtherPlayerType];
		local relationshipInfo : table = GameInfo.RelationshipLevels[data.RelationshipLevel];
		local policyInfo : table = GameInfo.ForeignPolicies[data.PolicyType];
		local civInfo : table = GameInfo.Civilizations[otherPlayer:GetCivilizationType()];
		local leaderInfo : table = GameInfo.Leaders[otherPlayer:GetLeaderType()];
		local instance : table = m_allServicesAgreementEntryInstanceManager:GetInstance();
		local policyType : number = data.PolicyType;
		local blockedTooltipString : string = "[COLOR_FearGradient]";
		local tooltipString : string = InitForeignPolicyEntry(instance, policyInfo, relationshipInfo, m_player, otherPlayer);
		local isBlocked : boolean = false;

		instance.CancelButton:SetHide(true);
		instance.NumberIcon:SetHide(true);
		--Resizing the All Policies agreement container to fit the width of the sorting bar FOR SQUARE RESOLUTIONS
		instance.AgreementContainer:SetSizeX(instance.Content:GetSizeX()-87);

		local canAfford : boolean = m_player:GetDiplomaticCapital() >= m_player:GetForeignPolicyPurchaseCapitalCost(policyInfo.ID);
		local canMake : boolean = Game.CanMakeAgreement(m_player:GetID(), otherPlayer:GetID(), policyType);
		local hasAgreementAlready : boolean = Game.IsPlayerReceivingPolicyFromAgreement(m_player:GetID(), policyInfo.ID);

		local isConsidering : boolean = false;
		local pendingTransactions : table = Game.GetPendingTransactions(m_player:GetID(), otherPlayer:GetID());
		for i : number, transaction : object in ipairs(pendingTransactions) do
			if (not transaction:WasResolved() and transaction:GetForeignPolicy() ~= -1) then
				isConsidering = true;
				break;
			end
		end

		instance.LeaderName:SetText(Locale.Lookup(otherPlayer:GetName()));
		local relationshipOffset : number = 75*relationshipInfo.ID;
		instance.RelationshipIndicator:SetTextureOffsetVal(50,relationshipOffset);
		instance.CivName:SetText(Locale.Lookup(civInfo.Description));
		CivIconHookup(otherPlayer:GetID(), 32, instance.CivIcon, nil, nil, true, false, nil);
		IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, instance.LeaderIcon);
		IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);
		instance.CivInfo:SetOffsetX(-30);
		instance.Content:SetColor(0x00000000);
		instance.Content:SetSizeY(75);
		instance.Button:SetDisabled(true);
		instance.Button:SetColor(0x77ffffff);
		instance.Relationship:SetText("[COLOR_"..relationshipInfo.Type.."]"..Locale.Lookup(relationshipInfo.Description));

		instance.Button:SetDisabled(not canAfford or not canMake or isConsidering);
		instance.RelationshipRequirement:SetHide(true);
		instance.RelationshipRequirementAnim:SetHide(true);
		if (Game.GetForeignPolicyMinRelationshipLevel(policyType)>relationshipInfo.ID) then
			blockedTooltipString = blockedTooltipString.. Locale.Lookup("TXT_KEY_DIPLOMACYUI_RELATIONSHIPATLEAST", GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Type, GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Description);
			isBlocked = true;
			instance.RelationshipRequirement:SetHide(false);
			instance.RelationshipRequirementAnim:SetHide(false);
			instance.Description:SetText(Locale.Lookup(policyInfo.Help));
			local relationshipLevelToSelected : number = GameInfo.RelationshipLevels[policyInfo.MinRelationshipLevelType].ID;
			local relationshipToOthersOffset : number = relationshipLevelToSelected * 30;
			instance.RelationshipRequirement:SetTextureOffsetVal(0, relationshipToOthersOffset);
		end

		if (not canAfford or isConsidering or hasAgreementAlready) then
			if (isBlocked) then
				blockedTooltipString = blockedTooltipString .. "[NEWLINE]";
			end

			if (not canAfford) then
				blockedTooltipString = blockedTooltipString .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_NOT_ENOUGH_CAPITAL") .. "[ENDCOLOR]";
				instance.Cost:SetColor(0xff000066,0);
				instance.Cost:SetColor(0x550000ff,1);
				instance.Cost:SetColor(0xff0000ff,2);
				instance.CostPerTurn:SetColor(0xff555555,0);
				instance.CostPerTurn:SetColor(0xff000000,1);
				instance.CostPerTurn:SetColor(0xff555555,2);
			end

			if (isConsidering) then
				blockedTooltipString = blockedTooltipString .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_LEADER_STILL_THINKING") .. "[ENDCOLOR]";
			end

			if (hasAgreementAlready and not isConsidering) then
				blockedTooltipString = blockedTooltipString .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_HAS_AGREEMENT_ALREADY") .. "[ENDCOLOR]";
			end

			isBlocked = true;
		else
			instance.Cost:SetColor(0xffd1362e,0);
			instance.Cost:SetColor(0x77d1362e,1);
			instance.Cost:SetColor(0xfffa8b50,2);
			instance.CostPerTurn:SetColor(0xffd1362e,0);
			instance.CostPerTurn:SetColor(0x77d1362e,1);
			instance.CostPerTurn:SetColor(0xfffa8b50,2);
		end

		if (isBlocked) then
			instance.Button:SetToolTipString(blockedTooltipString.. "[NEWLINE][NEWLINE]" ..tooltipString);
		end

		local tempPlayerType : number = data.OtherPlayerType; -- WRM: For lambda capture
		local tempPolicyInfo : table = policyInfo; -- WRM: For lambda capture
		instance.Button:RegisterCallback(Mouse.eLClick, function() 
			SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, tempPlayerType);
			PushDiplomacyUIState(g_diplomacyUIStates.AGREEMENTS_FROM_ALL_SERVICES, tempPlayerType);
			m_selectedPolicyInfo = tempPolicyInfo;
			DoProposeAgreement();
			Events.LeaderSetVisible();
		end);
	end

	Controls.AllServicesStack:CalculateSize();
	Controls.AllServicesStack:ReprocessAnchoring();
	Controls.AllServicesScrollPanel:CalculateInternalSize();
	Controls.AllServicesScrollPanel:ReprocessAnchoring();
end

function UpdatePolicies()
	local foreignPolicies : table = m_selectedPlayer:GetForeignPolicies();

	m_foreignPolicyEntryInstanceManager:ResetInstances();
	
	for i : number, policyType : number in ipairs(foreignPolicies) do
		if (not Game.HasMadeAgreementWithPolicy(m_player:GetID(), m_selectedPlayer:GetID(), policyType)) then
			local policyInfo : table = GameInfo.ForeignPolicies[policyType];
			local currentRelationship : number = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
			local relationshipInfo : table = GameInfo.RelationshipLevels[currentRelationship];
			local blockedTooltipString : string = "";
			local isBlocked : boolean = false;
			local instance : table = m_foreignPolicyEntryInstanceManager:GetInstance();
			local tooltipString : string = InitForeignPolicyEntry(instance, policyInfo, relationshipInfo, m_player, m_selectedPlayer);

			local canAfford : boolean = m_player:GetDiplomaticCapital() >= m_player:GetForeignPolicyPurchaseCapitalCost(policyInfo.ID);
			local canMake : boolean = Game.CanMakeAgreement(m_player:GetID(), m_selectedPlayer:GetID(), policyType);
			local hasAgreementAlready : boolean = Game.IsPlayerReceivingPolicyFromAgreement(m_player:GetID(), policyInfo.ID);

			local isConsidering : boolean = false;
			local pendingTransactions : table = Game.GetPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID());
			for i : number, transaction : object in ipairs(pendingTransactions) do
				if (not transaction:WasResolved() and transaction:GetForeignPolicy() ~= -1) then
					isConsidering = true;
					break;
				end
			end

			instance.Button:SetDisabled(not canAfford or not canMake or isConsidering);
			instance.RelationshipRequirement:SetHide(true);
			if (Game.GetForeignPolicyMinRelationshipLevel(policyType)>relationshipInfo.ID) then
				--blockedTooltipString = blockedTooltipString.. Locale.Lookup("{TXT_KEY_DIPLOMACYUI_RELATIONSHIPATLEAST}").. "[ENDCOLOR]"
				--	.. " [COLOR_" .. GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Type .. "]"
				--	.. Locale.Lookup(GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Description)
				--	.. "[ENDCOLOR]".."[ICON_".. GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Type.."]";
				blockedTooltipString = blockedTooltipString.. Locale.Lookup("TXT_KEY_DIPLOMACYUI_RELATIONSHIPATLEAST", GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Type, GameInfo.RelationshipLevels[Game.GetForeignPolicyMinRelationshipLevel(policyType)].Description);
				isBlocked = true;
				instance.RelationshipRequirement:SetHide(false);
				instance.Description:SetText(Locale.Lookup(policyInfo.Help));
				local relationshipLevelToSelected : number = GameInfo.RelationshipLevels[policyInfo.MinRelationshipLevelType].ID;
				local relationshipToOthersOffset : number = relationshipLevelToSelected * 30;
				instance.RelationshipRequirement:SetTextureOffsetVal(0, relationshipToOthersOffset);
			end

			if (not canAfford or isConsidering or hasAgreementAlready) then
				if (isBlocked) then
					blockedTooltipString = blockedTooltipString .. "[NEWLINE]";
				end

				if (not canAfford) then
					blockedTooltipString = blockedTooltipString .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_NOT_ENOUGH_CAPITAL") .. "[ENDCOLOR]";
					instance.Cost:SetColor(0xff000066,0);
					instance.Cost:SetColor(0x550000ff,1);
					instance.Cost:SetColor(0xff0000ff,2);
					instance.CostPerTurn:SetColor(0xff555555,0);
					instance.CostPerTurn:SetColor(0xff000000,1);
					instance.CostPerTurn:SetColor(0xff555555,2);
				end

				if (isConsidering) then
					blockedTooltipString = blockedTooltipString .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_LEADER_STILL_THINKING") .. "[ENDCOLOR]";
				end

				if (hasAgreementAlready and not isConsidering) then
					blockedTooltipString = blockedTooltipString .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_HAS_AGREEMENT_ALREADY") .. "[ENDCOLOR]";
				end

				isBlocked = true;
			else
				instance.Cost:SetColor(0xffd1362e,0);
				instance.Cost:SetColor(0x77d1362e,1);
				instance.Cost:SetColor(0xfffa8b50,2);
				instance.CostPerTurn:SetColor(0xffd1362e,0);
				instance.CostPerTurn:SetColor(0x77d1362e,1);
				instance.CostPerTurn:SetColor(0xfffa8b50,2);
			end

			if (isBlocked) then
				instance.Button:SetToolTipString(blockedTooltipString.. "[NEWLINE][NEWLINE]" ..tooltipString);
			end

			instance.Button:RegisterCallback(Mouse.eLClick, function() 
				m_selectedPolicyInfo = policyInfo;
				DoProposeAgreement();
				Events.LeaderSetVisible();
			end);
		end
	end

	Controls.MyProposePolicyStack:CalculateSize();
	Controls.MyProposePolicyStack:ReprocessAnchoring();
	Controls.MyProposePolicyScrollPanel:CalculateInternalSize();
end

function UpdateMyAgreements()
	-- Update capital breakdown
	local capitalBanked : number = m_player:GetDiplomaticCapital();
	local capitalIncome : number = m_player:GetTotalDiplomaticCapitalPerTurn();
	local capitalOutgoing : number = m_player:GetTotalDiplomaticCapitalCostsPerTurn();
	local capitalNet : number = m_player:GetNetDiplomaticCapitalPerTurn();
	local capitalFromCities : number = m_player:GetDiplomaticCapitalPerTurnFromCities();
	local capitalFromAgreements : number = m_player:GetDiplomaticCapitalPerTurnFromAgreements();

	if (capitalIncome > 0) then
		Controls.CapitalIncome:SetText("+"..capitalIncome);
	else
		Controls.CapitalIncome:SetText(" "..capitalIncome);
	end
	if (capitalOutgoing < 0) then
		Controls.CapitalOutgoing:SetText("-"..capitalOutgoing);
	else
		Controls.CapitalOutgoing:SetText(" "..capitalOutgoing);
	end

	Controls.CapitalBanked:SetText(capitalBanked);	
	Controls.CapitalFromServices:SetWrapWidth(Controls.SubIncomeContainer:GetSizeX()-90);
	Controls.CapitalFromServices:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_CAPITAL_FROM_AGREEMENTS:upper}"));
	
	if (capitalFromAgreements > 0) then
		Controls.CapitalFromServicesNumber:SetText("+"..capitalFromAgreements);
	else
		Controls.CapitalFromServicesNumber:SetText(" "..capitalFromAgreements);
	end

	local capitalTipLines = {};
	local capitalFromAgreements : number = m_player:GetAgreementsDiploCapitalChange();
	if (capitalFromAgreements > 0) then
		table.insert(capitalTipLines, Locale.ConvertTextKey("TXT_KEY_DIPLOMACYUI_BONUS_CAPITAL_PER_AGREEMENT", capitalFromAgreements));
	end
	if (#capitalTipLines > 0) then
		Controls.CapitalFromServicesNumber:SetToolTipString(table.concat(capitalTipLines,"[NEWLINE]"));
	end

	if(capitalNet>0) then
		Controls.CapitalNet:SetColor(0xffd1362e,0);
		Controls.CapitalNet:SetColor(0x77d1362e,1);
		Controls.CapitalNet:SetColor(0xfffa8b50,2);
		Controls.CapitalNet:SetText("(+"..capitalNet..")");
	else
		Controls.CapitalNet:SetColor(0xff0000cc,0);
		Controls.CapitalNet:SetColor(0xaa0000cc,1);
		Controls.CapitalNet:SetColor(0xff0000cc,2);		
		Controls.CapitalNet:SetText("("..capitalNet..")");
	end
	Controls.CapitalStack:CalculateSize();
	Controls.CapitalStack:ReprocessAnchoring();

	m_incomeAgreementEntryInstanceManager:ResetInstances();
	for proposingPlayerType : number = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		local hasAgreements : boolean = Game.GetNumAgreementsWithPlayers(proposingPlayerType, m_player:GetID()) > 0;
		if (proposingPlayerType ~= m_player:GetID() and hasAgreements == true) then
			local instance : table = m_incomeAgreementEntryInstanceManager:GetInstance();
			InitIncomeAgreementEntryInstance(instance, proposingPlayerType);
		end
	end
	Controls.IncomeAgreementsStack:CalculateSize();
	Controls.IncomeAgreementsStack:ReprocessAnchoring();

	-- Update my agreements list
	m_myAgreementEntryInstanceManager:ResetInstances();	
	local myProposedAgreements : table = Game.GetAgreementsWithProposingPlayer(m_selectedPlayer:GetID());
	for i : number, agreement : object in ipairs(myProposedAgreements) do
		if (not agreement:IsCanceled()) then
			local targetPlayer : object = Players[agreement:GetTargetPlayer()];
			local civInfo : table = GameInfo.Civilizations[targetPlayer:GetCivilizationType()];
			local leaderInfo : table = GameInfo.Leaders[targetPlayer:GetLeaderType()];
			local relationshipInfo : table = GameInfo.RelationshipLevels[Game.GetRelationship(m_player:GetID(), targetPlayer:GetID())];
			local foreignPolicyInfo : table = GameInfo.ForeignPolicies[agreement:GetForeignPolicy()];
			local agreementID : number = agreement:GetID();

			local instance : table = m_myAgreementEntryInstanceManager:GetInstance();
			local relationshipOffset : number = 75*relationshipInfo.ID;
			instance.RelationshipIndicator:SetTextureOffsetVal(50,relationshipOffset);
			instance.LeaderName:SetText(Locale.Lookup(targetPlayer:GetName()));
			instance.CivName:SetText(Locale.Lookup(civInfo.Description));
			CivIconHookup(targetPlayer:GetID(), 32, instance.CivIcon, nil, nil, true, false, nil);
			IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, instance.LeaderIcon);
			IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);
			instance.Button:SetDisabled(true);
			instance.Button:SetColor(0x77ffffff);
			instance.Relationship:SetText("[COLOR_"..relationshipInfo.Type.."]"..Locale.Lookup(relationshipInfo.Description));
			instance.CancelButton:RegisterCallback(Mouse.eLClick, function()
				DoConfirmAgreementCancel(agreementID, m_player:GetID());
				--Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_CANCEL");
				--Network.SendCancelAgreement(agreementID, m_player:GetID());
			end);
			instance.CancelButton:SetDisabled(not m_player:IsTurnActive());
			--instance.DiscussRelationshipButton:RegisterCallback(Mouse.eLClick, function() 
			--	local dontChangeState : boolean = true;
			--	PushDiplomacyUIState(g_diplomacyUIStates.RELATIONSHIP, agreement:GetTargetPlayer());
			--end);
			instance.CostContainer:SetHide(true);
			InitForeignPolicyEntry(instance, foreignPolicyInfo, relationshipInfo, m_player,m_selectedPlayer);
			instance.CancelAnim:SetSizeX(instance.AgreementContainer:GetSizeX());
			instance.NumberIcon:SetTextureOffsetVal(0, 56*(i-1));
		end
	end

	-- Update agreements made with me list
	m_theirAgreementEntryInstanceManager:ResetInstances();
	local agreementsMadeWithMe : table = Game.GetAgreementsWithTargetPlayer(m_player:GetID());
	for i : number, agreement : object in ipairs(agreementsMadeWithMe) do
		if (not agreement:IsCanceled()) then
			local proposingPlayer : object = Players[agreement:GetProposingPlayer()];
			local civInfo : table = GameInfo.Civilizations[proposingPlayer:GetCivilizationType()];
			local leaderInfo : table = GameInfo.Leaders[proposingPlayer:GetLeaderType()];
			local relationshipInfo : table = GameInfo.RelationshipLevels[Game.GetRelationship(m_player:GetID(), proposingPlayer:GetID())];
			local foreignPolicyInfo : table = GameInfo.ForeignPolicies[agreement:GetForeignPolicy()];
			local agreementID : number = agreement:GetID();

			local instance : table = m_theirAgreementEntryInstanceManager:GetInstance();
			local relationshipOffset : number = 75*relationshipInfo.ID;
			instance.NumberIcon:SetHide(true);
			instance.RelationshipIndicator:SetTextureOffsetVal(50,relationshipOffset);
			instance.LeaderName:SetText(Locale.Lookup(proposingPlayer:GetName()));
			instance.CivName:SetText(Locale.Lookup(civInfo.Description));
			CivIconHookup(proposingPlayer:GetID(), 32, instance.CivIcon, nil, nil, true, false, nil);
			IconHookup(leaderInfo.PortraitIndex, 64, leaderInfo.IconAtlas, instance.LeaderIcon);
			IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, instance.BigCivIcon);
			instance.Button:SetDisabled(true);
			instance.Button:SetColor(0x77ffffff);
			instance.Relationship:SetText("[COLOR_"..relationshipInfo.Type.."]"..Locale.Lookup(relationshipInfo.Description));
			instance.CancelButton:RegisterCallback(Mouse.eLClick, function()
				Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_CANCEL");
				Network.SendCancelAgreement(agreementID, m_player:GetID());
			end);
			instance.CancelButton:SetDisabled(not m_player:IsTurnActive());
			instance.CostContainer:SetHide(true);
			InitForeignPolicyEntry(instance, foreignPolicyInfo, relationshipInfo, proposingPlayer,m_player);
			instance.CancelAnim:SetSizeX(instance.AgreementContainer:GetSizeX());
			instance.NumberIcon:SetTextureOffsetVal(0, 56*(i-1));
		end
	end

	Controls.AgreementsMadeWithMeStack:CalculateSize();
	Controls.AgreementsMadeWithMeStack:ReprocessAnchoring();
	Controls.AgreementsMadeWithMeScrollPanel:CalculateInternalSize();
	Controls.AgreementsMadeWithMeScrollPanel:ReprocessAnchoring();

	Controls.AgreementsStack:CalculateSize();
	Controls.AgreementsStack:ReprocessAnchoring();
	--Controls.AgreementsScrollPanel:CalculateInternalSize();
end

function DoConfirmAgreementCancel(agreementID : number, playerType : number)
	Controls.ConfirmAgreementCancelAlphaAnim:SetToBeginning();
	Controls.ConfirmAgreementCancelAlphaAnim:Play();

	Controls.ConfirmAgreementCancel:SetHide(false);
	Controls.CancelAgreementNoButton:RegisterCallback(Mouse.eLClick, function() 
		Controls.ConfirmAgreementCancel:SetHide(true);
	end);
	Controls.CancelAgreementYesButton:RegisterCallback(Mouse.eLClick, function() 
		Controls.ConfirmAgreementCancel:SetHide(true);
		Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_CANCEL");
		Network.SendCancelAgreement(agreementID, playerType);
	end);
end

function DoThinkingAboutIt(firstTime : boolean)
	if (firstTime) then
		SayLine("LINE_DIPLO_LET_ME_THINK", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	else
		SayLine("LINE_DIPLO_STILL_THINKING", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	end
	
	Controls.ConversationContent:SetHide(false);
	Controls.AgreementsOverviewContent:SetHide(true);
	Controls.AllServicesContent:SetHide(true);
	Controls.MyProposedPolicyContent:SetHide(true);
	Controls.TheirPolicyContent:SetHide(true);
	Controls.BubbleWindow:SetHide(true);
	Controls.TheirSpeechBubble:SetHide(false);

	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_GOODBYE"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 		
		PopDiplomacyUIState();
	end);

	Controls.OptionButton2:SetHide(true);
	Controls.OptionButton3:SetHide(true);

	UpdateConversationControlSizes();
end

function DoResolveAgreementTransaction(transaction : object)
	local policyInfo : table = GameInfo.ForeignPolicies[transaction:GetForeignPolicy()];
	local relationshipLevel : number = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
	local relationshipInfo : table = GameInfo.RelationshipLevels[relationshipLevel];

	SayLine("LINE_DIPLO_AGREEMENT_PROPOSE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	Controls.ConversationContent:SetHide(false);
	Controls.AgreementsOverviewContent:SetHide(true);
	Controls.AllServicesContent:SetHide(true);
	Controls.MyProposedPolicyContent:SetHide(true);
	Controls.TheirPolicyContent:SetHide(false);
	Controls.BubbleWindow:SetHide(true);
	InitForeignPolicyEntry(m_acceptedPolicyInstance, policyInfo, relationshipInfo, m_selectedPlayer, m_player);
	Controls.TheirPolicyLabel:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_THEY_GET"));
	Controls.TheirPolicyCostLabel:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_YOU_GET"));
	
	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_ACCEPT_AGREEMENT_PROPOSAL"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 		
		DoFinishProposal(transaction, true);
		Events.LeaderSetVisible();
	end);

	Controls.OptionButton2:SetHide(false);
	Controls.OptionButton2:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_REJECT_AGREEMENT_PROPOSAL"));
	Controls.OptionButton2:RegisterCallback(Mouse.eLClick, function() 
		DoFinishProposal(transaction, false);
		Events.LeaderSetVisible();
	end);
	Controls.OptionButton3:SetHide(true);

	UpdateConversationControlSizes();
end

function DoFinishProposal(transaction : object, didAccept : boolean)
	Network.SendResolveTransaction(transaction:GetID(), didAccept);

	if (didAccept) then
		Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_GET");
		SayLine("LINE_DIPLO_AGREEMENT_HAPPY_YOU_ACCEPTED", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	else
		SayLine("LINE_DIPLO_AGREEMENT_SAD_YOU_REJECTED", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	end

	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_GOODBYE"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 		
		DoNextPendingTransaction();
		Events.LeaderSetVisible();
	end);

	Controls.OptionButton2:SetHide(true);
	Controls.OptionButton3:SetHide(true);

	UpdateConversationControlSizes();
end

function DoSelectPolicy()
	m_selectedPolicyInfo = nil;

	Controls.MyProposePolicyStack:SetHide(false);
	Controls.MyProposedPolicyContent:SetHide(true);
	Controls.TheirPolicyContent:SetHide(true);
	Controls.BubbleWindow:SetHide(false);
	
	SayLine("LINE_DIPLO_DISCUSS_AGREEMENTS", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	-- See all services option
	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_ALL_SERVICES"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 
		SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, m_player:GetID());
		PushDiplomacyUIState(g_diplomacyUIStates.ALL_SERVICES, m_player:GetID());
		Events.LeaderSetVisible();
	end);

	-- Nevermind option
	Controls.OptionButton2:SetHide(false);
	Controls.OptionButton2:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NEVERMIND"));
	Controls.OptionButton2:RegisterCallback(Mouse.eLClick, function() 
		LuaEvents.DiplomacyUI_ResetAnimations();
		PopDiplomacyUIState();
	end);

	Controls.OptionButton3:SetHide(true);

	UpdatePolicies();
	UpdateConversationControlSizes();
end

function DoProposeAgreement()
	Controls.MyProposedPolicyContent:SetHide(false);
	Controls.TheirPolicyContent:SetHide(true);
	Controls.AgreementsOverviewContent:SetHide(true);
	Controls.AllServicesContent:SetHide(true);

	Controls.BubbleWindow:SetHide(true);
	local relationshipInfo : table = GameInfo.RelationshipLevels[Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID())];
	InitForeignPolicyEntry(m_proposedPolicyInstance, m_selectedPolicyInfo, relationshipInfo, m_player,m_selectedPlayer);

	SayLine("LINE_DIPLO_AGREEMENT_CONFIRM", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_MAKEDEAL"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 
		--Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_GET");
		m_waitingForTransaction = true;
		Network.SendCreateAgreementProposalTransaction(m_player:GetID(), m_selectedPlayer:GetID(), m_selectedPolicyInfo.ID);
		if (m_selectedPlayer:IsHuman()) then
			DoThinkingAboutIt(true);
		end
		Events.LeaderSetVisible();
	end);

	Controls.OptionButton2:SetHide(false);
	Controls.OptionButton2:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NEVERMIND"));
	Controls.OptionButton2:RegisterCallback(Mouse.eLClick, function() 
		m_selectedPolicyInfo = nil
		
		local currentState : number = UI.GetCurrentDiplomacyUIState();
		if (currentState == g_diplomacyUIStates.AGREEMENTS) then
			DoSelectPolicy();
			Events.LeaderSetVisible();
		elseif (currentState == g_diplomacyUIStates.AGREEMENTS_FROM_ALL_SERVICES) then
			SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, m_player:GetID());
			PushDiplomacyUIState(g_diplomacyUIStates.ALL_SERVICES, m_player:GetID());
			Events.LeaderSetVisible();
		else
			PopDiplomacyUIState();
		end
	end);
	Controls.OptionButton3:SetHide(true);

	UpdateConversationControlSizes();
end

function DoTooManyAgreements()
	Controls.MyProposedPolicyContent:SetHide(true);
	Controls.TheirPolicyContent:SetHide(true);
	Controls.AgreementsOverviewContent:SetHide(true);
	Controls.AllServicesContent:SetHide(true);
	Controls.MyProposePolicyStack:SetHide(false);
	Controls.TheirSpeechBubble:SetHide(false);
	Controls.BubbleWindow:SetHide(false);
	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NEVERMIND"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 
		LuaEvents.DiplomacyUI_ResetAnimations();
		PopDiplomacyUIState();
	end);

	Controls.OptionButton2:SetHide(true);
	Controls.OptionButton3:SetHide(true);

	UpdatePolicies();

	SayLine("LINE_DIPLO_TOO_MANY_AGREEMENTS", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	UpdateConversationControlSizes();
end

function DoNotAcceptingAgreements()
	Controls.MyProposedPolicyContent:SetHide(true);
	Controls.TheirPolicyContent:SetHide(true);
	Controls.AgreementsOverviewContent:SetHide(true);
	Controls.AllServicesContent:SetHide(true);
	Controls.MyProposePolicyStack:SetHide(false);
	Controls.TheirSpeechBubble:SetHide(false);
	Controls.BubbleWindow:SetHide(false);
	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NEVERMIND"));
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 
		LuaEvents.DiplomacyUI_ResetAnimations();
		PopDiplomacyUIState();
	end);

	Controls.OptionButton2:SetHide(true);
	Controls.OptionButton3:SetHide(true);

	UpdatePolicies();

	SayLine("LINE_DIPLO_NOT_MAKING_AGREEMENTS", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	UpdateConversationControlSizes();
end

-------------------------------------------------
-- Init
-------------------------------------------------
function InitIncomeAgreementEntryInstance(instance : table, proposingPlayerType : number)
	if (proposingPlayerType == m_player:GetID()) then
		error("Proposing player cannot be the same as the active player");
	end

	local proposingPlayer : object = Players[proposingPlayerType];

	local agreements = Game.GetAgreementsWithPlayers(proposingPlayerType, m_player:GetID());
	if (#agreements == 0) then
		error("No agreements");
	end

	local relationshipLevel : number = Game.GetRelationship(m_player:GetID(), proposingPlayerType);
	local proposingCivInfo : table = GameInfo.Civilizations[proposingPlayer:GetCivilizationType()];

	instance.NumAgreements:SetText(#agreements);
	
	CivIconHookup(proposingPlayerType, 32, instance.CivIcon, instance.CivIconBG, nil, false, false, nil);

	-- Tool tip
	instance.Content:SetToolTipCallback(function(toolTipControls : table) 
		InitIncomeAgreementToolTip(proposingPlayer, agreements);
	end);
end

local m_incomeAgreementToolTipControls : table = {}
TTManager:GetTypeControlTable("IncomeAgreementToolTip", m_incomeAgreementToolTipControls);
local m_incomeAgreementTTEntryInstanceManager : table = InstanceManager:new("IncomeAgreementTTEntry", "Content", m_incomeAgreementToolTipControls.PoliciesStack);
function InitIncomeAgreementToolTip(proposingPlayer : object, agreements : table)
	m_incomeAgreementToolTipControls.LeaderName:SetText(Locale.Lookup(proposingPlayer:GetName()));

	m_incomeAgreementTTEntryInstanceManager:ResetInstances();
	for i : number, agreement : object in ipairs(agreements) do
		local instance : table = m_incomeAgreementTTEntryInstanceManager:GetInstance();
		InitIncomeAgreementTTEntry(instance, agreement);
	end
	m_incomeAgreementToolTipControls.HasMadeAgreements:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_FROM_AGREEMENTS_TT", table.count(agreements)));
	m_incomeAgreementToolTipControls.PoliciesStack:CalculateSize();
	m_incomeAgreementToolTipControls.PoliciesStack:ReprocessAnchoring();

	m_incomeAgreementToolTipControls.ToolTipFrame:SetSizeY(m_incomeAgreementToolTipControls.PoliciesStack:GetSizeY() + 35);
end

function InitIncomeAgreementTTEntry(instance : table, agreement : object)
	local policyInfo : table = GameInfo.ForeignPolicies[agreement:GetForeignPolicy()];

	IconHookup(policyInfo.PortraitIndex, 32, policyInfo.IconAtlas, instance.PolicyIcon);

	instance.PolicyName:SetText(Locale.Lookup(policyInfo.Description));

	local policyCost : number = agreement:GetCapitalCostPerTurn(agreement:GetTargetPlayer());
	instance.Cost:SetText("+"..policyCost.."[ICON_DIPLO_CAPITAL]");
end

function UpdateConversationControlSizes()
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	local headerSize= 72;
	local bubblePadding = 40;
	local cardOffsetY = 90;
	local cardOffsetX = screenSizeX*.11;
	local cardHeight = 160;
	local headerY = 72;
	local bubbleNubCorrection = 8;
	local myBubblePadding = 38;
	if((screenSizeX-cardOffsetX*2)<970) then
		cardOffsetX = screenSizeX*.085;	
		cardOffsetY = 60;
	end

	Controls.MySpeechBubbleStack:CalculateSize();
	Controls.MySpeechBubbleStack:ReprocessAnchoring();
	Controls.MySpeechBubble:SetSizeY(Controls.MySpeechBubbleStack:GetSizeY());
	--Horizontal sizing for their speech bubble
	Controls.TheirSpeechBubble:SetSizeX(screenSizeX/2);
	Controls.TheirResponse:SetWrapWidth((screenSizeX/2)-20);
	--Vertical sizing for their speech bubble
	Controls.TheirSpeechBubbleStack:CalculateSize();
	Controls.TheirSpeechBubbleStack:ReprocessAnchoring();
	local theirBubbleY = 69;
	if(Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding > 69) then
		theirBubbleY = Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding;
	end
	Controls.TheirSpeechBubble:SetSizeY(theirBubbleY);

	Controls.ButtonStack:CalculateSize();
	Controls.ButtonStack:ReprocessAnchoring();
	local bubbleWindowHeight = screenSizeY-theirBubbleY-headerSize-cardOffsetY-cardHeight-Controls.ButtonStack:GetSizeY();
	Controls.BubbleWindow:SetSizeY(bubbleWindowHeight);
	Controls.BubbleContentStack:CalculateSize();
	Controls.BubbleContentStack:ReprocessAnchoring();
	Controls.BubbleWindowBacking:SetSizeY(Controls.BubbleContentStack:GetSizeY());
	
	Controls.MySpeechBubble:SetOffsetY(cardOffsetY+cardHeight-bubbleNubCorrection);
	Controls.MySpeechBubble:SetSizeY(bubbleWindowHeight+bubbleNubCorrection+Controls.ButtonStack:GetSizeY());
	
	
	Controls.MyProposePolicyScrollPanel:SetSizeY(bubbleWindowHeight-myBubblePadding);
	Controls.MyProposePolicyScrollPanel:CalculateInternalSize();
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function OnInitialize(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];

	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	Events.DiplomacyAgreementCreated.Add(OnAgreementCreated);
	Events.DiplomacyAgreementCanceled.Add(OnAgreementCanceled);
	Events.TransactionResolved.Add(OnTransactionResolved);
	LuaEvents.DiplomacyUI_ResetAnimations.Add(ResetAnimations);

	m_acceptedPolicyInstance = {};
	ContextPtr:BuildInstanceForControl("ForeignPolicyEntry", m_acceptedPolicyInstance, Controls.TheirPolicyPlaceholder);
	m_acceptedPolicyInstance.Button:SetDisabled(true);
	m_acceptedPolicyInstance.CostContainer:SetHide(true);
	Controls.TheirPolicyContent:SetHide(true);

	m_proposedPolicyInstance = {};
	ContextPtr:BuildInstanceForControl("ForeignPolicyEntry", m_proposedPolicyInstance, Controls.MyProposedPolicyPlaceholder);
	m_proposedPolicyInstance.Button:SetDisabled(true);
	Controls.MyProposedPolicyContent:SetHide(true);

	ContextPtr:SetHide(true);


	--Size and position View Agreements and Browse All Services
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	local paddingFromEdge = 0;
	local headerSize = 78;
	local footerSize = 116;
	local minimumReqHeight = 690;
	-- This is an approximation of the offset that the text should have from the side of the screen
	local offsetMultiplier = .00006*(screenSizeX)-.07;
	if(screenSizeX/screenSizeY > 1.5 and ((screenSizeY-headerSize-footerSize) > minimumReqHeight) and offsetMultiplier > .02) then
		paddingFromEdge = screenSizeX * offsetMultiplier;
		Controls.WindowAlpha:SetAnchor("R,T");
		Controls.WindowAlpha:SetOffsetX((screenSizeX/2)*(-1)+(Controls.MainWindow:GetSizeX()/2)+paddingFromEdge);
		Controls.MainWindow:SetSizeY(screenSizeY-194);
		Controls.AllServicesWindowAlpha:SetAnchor("R,T");
		Controls.AllServicesWindowAlpha:SetOffsetX((screenSizeX/2)*(-1)+(Controls.AllServicesWindow:GetSizeX()/2)+paddingFromEdge);
	else
		local windowWidth = (screenSizeX - 1024)/2+900;
		Controls.MainWindow:SetSizeX(windowWidth);
		Controls.MainWindowDropShadow:SetSizeX(windowWidth+90);	
		-- Repositioning and sizing the All Services window FOR SQUARE RESOLUTIONS
		Controls.AllServicesWindowDropShadow:SetSizeX(windowWidth+110);	
		Controls.AllServicesWindow:SetSizeX(windowWidth+20);
	end

	m_tabs = CreateTabs(Controls.TabRow, 250, 32);
	m_tabs.AddTab(Controls.MyAgreementsTab, function() 
		Controls.BreakdownOutgoing:SetHide(false);
		Controls.BreakdownStack:CalculateSize();
		Controls.BreakdownStack:ReprocessAnchoring();
		Controls.MyAgreementsContent:SetHide(false);
		Controls.AgreementsMadeWithMeContent:SetHide(true);
	end);
	m_tabs.AddTab(Controls.AgreementsWithMeTab, function() 
		Controls.BreakdownOutgoing:SetHide(true);
		Controls.BreakdownStack:CalculateSize();
		Controls.BreakdownStack:ReprocessAnchoring();
		Controls.MyAgreementsContent:SetHide(true);
		Controls.AgreementsMadeWithMeContent:SetHide(false);
	end);
	m_tabs.CenterAlignTabs();
	m_tabs.SelectTab(Controls.MyAgreementsTab);

	--Size and position speech bubble and services list
	local cardSize = 390;
	local cardOffsetX = screenSizeX*.11;
	local cardOffsetY = 90;
	local cardHeight = 160;
	local headerY = 72;
	if((screenSizeX-cardOffsetX*2)<970) then
		cardOffsetX = screenSizeX*.085;
		cardOffsetY = 60;
	else
		cardSize = (screenSizeX-2*cardOffsetX-100)/2;
		if(cardSize>490) then
			Controls.MySpeechBubble:SetOffsetX(cardOffsetX + 22);
			Controls.MySpeechBubble:SetOffsetY(cardOffsetY+cardHeight);
			Controls.MySpeechBubble:SetSizeX(cardSize);
			Controls.BubbleWindow:SetSizeX(cardSize);
			Controls.BubbleWindowBacking:SetSizeX(cardSize);
			Controls.ScrollPanelGradient:SetSizeX(cardSize-10);
			Controls.OptionButton1:SetSizeX(cardSize);
			Controls.OptionButton2:SetSizeX(cardSize);
			Controls.OptionButton3:SetSizeX(cardSize);
			Controls.ButtonStack:CalculateSize();
			Controls.ButtonStack:ReprocessAnchoring();
		else
			Controls.MySpeechBubble:SetSizeX(cardSize+cardOffsetX + 22);
		end
	end
	Controls.TheirSpeechBubble:SetOffsetY(headerY);
	Controls.TheirSpeechBubble:SetOffsetX(cardOffsetX + 18);
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
	Events.DiplomacyAgreementCreated.Remove(OnAgreementCreated);
	Events.DiplomacyAgreementCanceled.Remove(OnAgreementCanceled);
	Events.TransactionResolved.Remove(OnTransactionResolved);
	LuaEvents.DiplomacyUI_ResetAnimations.Remove(ResetAnimations);
end
ContextPtr:SetShutdown(OnShutdown);

function SwitchSortOrder()
	if (m_sortOrder == SortOrder.ASCENDING) then
		m_sortOrder = SortOrder.DESCENDING;
	else
		m_sortOrder = SortOrder.ASCENDING;
	end
end

function OnSortBySponsor()
	if (m_sortAllServicesBy == SortAllServicesBy.SPONSOR) then
		SwitchSortOrder()
	else
		m_sortAllServicesBy = SortAllServicesBy.SPONSOR;
		m_sortOrder = SortOrder.ASCENDING;
	end
	
	UpdateAllPolicies();
end
Controls.SortServicesBySponsor:RegisterCallback(Mouse.eLClick, OnSortBySponsor);

function OnSortByName()
	if (m_sortAllServicesBy == SortAllServicesBy.NAME) then
		SwitchSortOrder()
	else
		m_sortAllServicesBy = SortAllServicesBy.NAME;
		m_sortOrder = SortOrder.ASCENDING;
	end
	
	UpdateAllPolicies();
end
Controls.SortServicesByName:RegisterCallback(Mouse.eLClick, OnSortByName);

function OnSortByCost()
	if (m_sortAllServicesBy == SortAllServicesBy.COST) then
		SwitchSortOrder()
	else
		m_sortAllServicesBy = SortAllServicesBy.COST;
		m_sortOrder = SortOrder.ASCENDING;
	end
	
	UpdateAllPolicies();
end
Controls.SortServicesByCost:RegisterCallback(Mouse.eLClick, OnSortByCost);

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function ResetAnimations()
	Controls.MyBubbleAlphaAnim:SetToBeginning();
	Controls.MyBubbleAlphaAnim:Play();
	Controls.MyBubbleSlideAnim:SetToBeginning();
	Controls.MyBubbleSlideAnim:Play();
	Controls.WindowAlpha:SetToBeginning();
	Controls.WindowAlpha:Play();
	Controls.WindowSlide:SetToBeginning();
	Controls.WindowSlide:Play();
	Controls.AllServicesWindowAlpha:SetToBeginning();
	Controls.AllServicesWindowAlpha:Play();
	Controls.AllServicesWindowSlide:SetToBeginning();
	Controls.AllServicesWindowSlide:Play();
end

function OnStateChanged(state : number, selectedPlayer : number)
	if (state == g_diplomacyUIStates.AGREEMENTS or 
		state == g_diplomacyUIStates.ALL_SERVICES or 
		state == g_diplomacyUIStates.AGREEMENTS_FROM_ALL_SERVICES) 
	then
		m_player = Players[Game.GetActivePlayer()];
		m_selectedPlayer = Players[selectedPlayer];
		m_shown = true;
		ContextPtr:SetHide(false);
	else
		if (m_shown) then
			m_shown = false;
			ContextPtr:SetHide(true);
		end
	end
end

function OnAgreementCreated(agreementID : number)
	if (m_shown == false) then
		return;
	end
end

function OnAgreementCanceled(agreementID : number)
	if (m_shown == false) then
		return;
	end

	UpdateMyAgreements();
end

function OnTransactionResolved(id : number)
	if (not m_shown or not m_waitingForTransaction) then
		return;
	end

	local transaction : object = Game.GetTransaction(id);

	if (transaction:GetSendingPlayer() == m_player:GetID() and transaction:GetReceivingPlayer() == m_selectedPlayer:GetID() and transaction:GetForeignPolicy() ~= -1) then
		local relationshipInfo : table = GameInfo.RelationshipLevels[Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID())];

		Controls.MyProposedPolicyContent:SetHide(true);
		Controls.TheirPolicyContent:SetHide(false);
		InitForeignPolicyEntry(m_acceptedPolicyInstance, m_selectedPolicyInfo, relationshipInfo, m_player,m_selectedPlayer);
		Controls.TheirPolicyLabel:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_YOU_GET"));
		Controls.TheirPolicyCostLabel:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_THEY_GET"));

		if (transaction:WasAccepted()) then
			SayLine("LINE_DIPLO_AGREEMENT_ACCEPT", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
			Controls.TheirPolicyContent:SetHide(false);
			Controls.TheirPolicyLabel:SetHide(false);
			Controls.TheirPolicyCostLabel:SetHide(false);
		else
			SayLine("LINE_DIPLO_AGREEMENT_REJECT", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
			Controls.TheirPolicyContent:SetHide(true);
			Controls.TheirPolicyLabel:SetHide(true);
			Controls.TheirPolicyCostLabel:SetHide(true);
		end

		Controls.BubbleWindow:SetHide(true);

		Controls.OptionButton1:SetHide(false);
		Controls.OptionButton1:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_MAKEANOTHERDEAL"));
		Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 
			if (Game.GetNumAgreementsWithProposingPlayer(m_player:GetID()) < GameDefines.DIPLO_MAX_AGREEMENTS) then
				DoSelectPolicy();
				Events.LeaderSetVisible();
			else
				DoTooManyAgreements();
				Events.LeaderSetVisible();
			end
		end);

		Controls.OptionButton2:SetHide(false);
		Controls.OptionButton2:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_GOODBYE"));
		Controls.OptionButton2:RegisterCallback(Mouse.eLClick, function() 
			LuaEvents.DiplomacyUI_ResetAnimations();
			PopDiplomacyUIState();
		end);

		Controls.OptionButton3:SetHide(true);

		UpdateConversationControlSizes();

		if (transaction:WasAccepted()) then
			Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_GET");
		end
		
		m_waitingForTransaction = false;
	end
end