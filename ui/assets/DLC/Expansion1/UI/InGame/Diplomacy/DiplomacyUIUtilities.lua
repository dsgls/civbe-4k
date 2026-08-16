include("TabSupport");
include("ConversationSystem");

g_diplomacyUIStates = 
{
	ACTIONS			= 1,
	TRAITS			= 2,
	AGREEMENTS		= 3,
	AGREEMENTS_FROM_ALL_SERVICES = 4,
	ALL_SERVICES	= 5,
	RELATIONSHIP	= 6,
	CONFRONTATION	= 7,
	AFFINITY		= 8,
	WAR				= 9,
};

g_responseLines = 
{
	Neutral = {
		"TXT_KEY_DIPLOMACYUI_THANK_YOU",
		"TXT_KEY_DIPLOMACYUI_UNDERSTOOD",
		"TXT_KEY_DIPLOMACYUI_VERY_WELL",
	},
	Negative = {
		"TXT_KEY_DIPLOMACYUI_SO_BE_IT",
		"TXT_KEY_DIPLOMACYUI_VERY_WELL",
	}
};

function SetDiplomacyUIState(state : number, selectedPlayer : number)
	UI.SetDiplomacyUIState(state, selectedPlayer);
	LuaEvents.DiplomacyUI_StateChanged(state, selectedPlayer);
end

function PushDiplomacyUIState(state : number, selectedPlayer : number)
	UI.PushDiplomacyUIState(state, selectedPlayer);
	LuaEvents.DiplomacyUI_StatePushed(state, selectedPlayer);
	LuaEvents.DiplomacyUI_StateChanged(state, selectedPlayer);
end

function PopDiplomacyUIState()
	UI.PopDiplomacyUIState();
	LuaEvents.DiplomacyUI_StatePopped();

	local statesData : table = UI.GetDiplomacyUIStates();
	if (#statesData == 0) then
		PushDiplomacyState(g_diplomacyUIStates.ACTIONS, Game.GetActivePlayer());
	else
		LuaEvents.DiplomacyUI_StateChanged(statesData[#statesData].State, statesData[#statesData].SelectedPlayer);
	end
end

function PopDiplomacyUIStates(num : number)
	if (num > UI.GetNumDiplomacyUIStates()) then
		error("UI Diplo state overflow");
	end

	for i : number = 1,num,1 do
		UI.PopDiplomacyUIState();
	end

	local statesData : table = UI.GetDiplomacyUIStates();
	if (#statesData == 0) then
		PushDiplomacyState(g_diplomacyUIStates.ACTIONS, Game.GetActivePlayer());
	else
		LuaEvents.DiplomacyUI_StateChanged(statesData[#statesData].State, statesData[#statesData].SelectedPlayer);
	end
end

function GetDiplomacyStates()
	return UI.GetDiplomacyStates();
end

function SayLine(lineName : string, speakingPlayerType : number, listeningPlayerType : number, labelControl : object, ...)
	local textKey : string;
	local animationIndex : number;

	textKey, animationIndex = GetLineAndAnimation(lineName, speakingPlayerType, listeningPlayerType);

	local lineString : string = nil;
	if (textKey ~= nil) then
		if (arg ~= nil and arg.n > 0) then
			lineString = Locale.Lookup(textKey, unpack(arg));
		else
			lineString = Locale.Lookup(textKey);
		end
	else
		lineString = "ERROR: NO TEXT KEY FOUND FOR " .. lineName;
	end

	SetLineAndAnimation(lineString, animationIndex, speakingPlayerType, labelControl);
end

function SayLineForReaction(reactionType : number, speakingPlayerType : number, listeningPlayerType : number, labelControl : object, ...)
	local textKey : string;
	local animationIndex : number;

	textKey, animationIndex = GetLineAndAnimationForReaction(reactionType, speakingPlayerType, listeningPlayerType);

	local lineString : string = nil;
	if (arg ~= nil and arg.n > 0) then
		lineString = Locale.Lookup(textKey, unpack(arg));
	else
		lineString = Locale.Lookup(textKey);
	end

	SetLineAndAnimation(lineString, animationIndex, speakingPlayerType, labelControl);
end

function SetLineAndAnimation(lineString : string, animationIndex : number, speakingPlayerType : number, labelControl : object)
	if (labelControl ~= nil) then
		labelControl:SetText(lineString);
	end

	Events.LeaderSetAnimation(speakingPlayerType, animationIndex);
	--Events.LeaderSetVisible();
end

function GetPlayerResponseLineForReaction(reactionID : number)
	local line : string = "TXT_KEY_DIPLOMACYUI_VERY_WELL";
	local reactionInfo : table = GameInfo.Reactions[reactionID];
	if (reactionInfo ~= nil) then
		if (reactionInfo.RespectChange >= 0) then
			line = g_responseLines.Neutral[math.random(#g_responseLines.Neutral)];
		else
			line = g_responseLines.Negative[math.random(#g_responseLines.Negative)];
		end
	end
	return line;
end

function FindTrait(traits : table, traitType : number)
	for i : number, trait : object in ipairs(traits) do
		if (trait:GetType() == traitType) then
			return trait;
		end
	end

	return nil;
end

function FindPerkForTrait(traitInfo : table, level : number)
	for traitToPerk : table in GameInfo.PersonalityTraits_Perks{PersonalityTraitType = traitInfo.Type, Level = level} do
		local perkTypeName : string = traitToPerk.PlayerPerkType;
		return GameInfo.PlayerPerks[perkTypeName];
	end

	return nil;
end

function FindPerkInfoForPolicyAtRelationshipLevel(policyInfo : table, relationshipLevel : number)
	local relationshipInfo : table = GameInfo.RelationshipLevels[relationshipLevel];
	for foreignPolicies_Perk : table in GameInfo.ForeignPolicies_Perks{ForeignPolicyType = policyInfo.Type, RelationshipLevelType = relationshipInfo.Type} do
		return GameInfo.PlayerPerks[foreignPolicies_Perk.PlayerPerkType];
	end

	return nil;
end

function GetAgreementToolTip(agreement : object)
	local policyInfo : table = GameInfo.ForeignPolicies[agreement:GetForeignPolicy()];
	local relationshipLevel : number = Game.GetRelationship(agreement:GetTargetPlayer(), agreement:GetProposingPlayer());
	local relationshipInfo : table = GameInfo.RelationshipLevels[relationshipLevel];
	local perkInfo : table = FindPerkInfoForPolicyAtRelationshipLevel(policyInfo, relationshipLevel);

	if (perkInfo ~= nil) then
		return Locale.Lookup(policyInfo.Description) ..
			"[NEWLINE]" .. Locale.Lookup("TXT_KEY_AGREEMENT_RELATIONSHIP_HEADER", relationshipInfo.Description) ..
			"[NEWLINE][NEWLINE]" .. Locale.Lookup(perkInfo.Help);
	else
		return Locale.Lookup(policyInfo.Description) .. "[NEWLINE]" .. Locale.Lookup("TXT_KEY_AGREEMENT_RELATIONSHIP_HEADER", relationshipInfo.Description);
	end
end

function InitTraitLevelEntryInstance(instance : table, perkInfo : table, levelCost : number)
	instance.Description:SetText(Locale.Lookup(perkInfo.Help));
	if (levelCost ~= nil) then
		instance.Cost:SetHide(false);
		instance.Cost:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_TRAIT_LEVEL_COST", levelCost));
	else
		instance.Cost:SetHide(true);	
	end
end

function InitForeignPolicyEntry(instance : table, foreignPolicyInfo : table, relationshipLevelInfo : table, buyingPlayer : object, sellingPlayer : object)
	local perkInfo : table = {};
	local relationshipInfo = GameInfo.RelationshipLevels[Game.GetRelationship(buyingPlayer:GetID(), sellingPlayer:GetID())];
	local tooltipString : string = "";
	local statusString : string = "";
	local currentPerkIndex = 0;
	local indexCtr = 1;
	for foreignPolicies_Perk : table in GameInfo.ForeignPolicies_Perks{ForeignPolicyType = foreignPolicyInfo.Type} do
		perkInfo[indexCtr] = GameInfo.PlayerPerks[foreignPolicies_Perk.PlayerPerkType];
		if (indexCtr > 1) then
			tooltipString = tooltipString .. "[NEWLINE]";
		end
		if( relationshipLevelInfo.Type == foreignPolicies_Perk.RelationshipLevelType ) then
			currentPerkIndex = indexCtr;
			tooltipString = tooltipString .. "[ICON_".. foreignPolicies_Perk.RelationshipLevelType.."]" .."[COLOR_".. foreignPolicies_Perk.RelationshipLevelType.."]" 
						.. Locale.Lookup("TXT_KEY_AGREEMENT_TT_CURRENTLY", GameInfo.RelationshipLevels[foreignPolicies_Perk.RelationshipLevelType].Description).."[ENDCOLOR]: ".. Locale.Lookup(perkInfo[indexCtr].Help);
		else
			tooltipString = tooltipString .. "[ICON_".. foreignPolicies_Perk.RelationshipLevelType.."]" .."[COLOR_".. foreignPolicies_Perk.RelationshipLevelType.."]" 
						.. Locale.Lookup("TXT_KEY_AGREEMENT_TT_WHEN", GameInfo.RelationshipLevels[foreignPolicies_Perk.RelationshipLevelType].Description).."[ENDCOLOR]: ".. Locale.Lookup(perkInfo[indexCtr].Help);
		end
		indexCtr = indexCtr + 1;
	end

	local purchaseCapitalCost : number = buyingPlayer:GetForeignPolicyPurchaseCapitalCost(foreignPolicyInfo.ID);
	local perTurnCapitalCost : number = buyingPlayer:GetForeignPolicyPerTurnCapitalCost(foreignPolicyInfo.ID);

	IconHookup(foreignPolicyInfo.PortraitIndex, 64, foreignPolicyInfo.IconAtlas, instance.Icon);
	instance.Name:SetText(Locale.Lookup(foreignPolicyInfo.Description));
	if (perkInfo[currentPerkIndex] ~= nil) then
		instance.Description:SetText(Locale.Lookup(perkInfo[currentPerkIndex].Help));
	else
		instance.Description:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NO_PERK_AT_RELATIONSHIP_LEVEL"));
	end
	instance.Cost:SetText(purchaseCapitalCost);
	instance.CostContainer:SetSizeX(instance.CostStack:GetSizeX() + 22);
	instance.CostPerTurn:SetText(perTurnCapitalCost .. "[ICON_DIPLO_CAPITAL]");
	instance.CostStack:CalculateSize();
	instance.CostStack:ReprocessAnchoring();
	instance.AllCostStack:CalculateSize();
	instance.AllCostStack:ReprocessAnchoring();

	instance.InfoStack:CalculateSize();
	instance.InfoStack:ReprocessAnchoring();
	instance.Button:SetToolTipString(tooltipString);
	instance.Button:ReprocessAnchoring();
	

	if(relationshipInfo.ID == 3) then
		instance.BoostedIndicator:SetHide(false);
		instance.BoostedIndicator:SetTexture("Agreements_BoostedCooperative.dds");
		instance.BoostedIndicator:SetToolTipString(Locale.Lookup("TXT_KEY_SERVICE_COOPERATIVE_TT"));
	elseif(relationshipInfo.ID == 4) then
		instance.BoostedIndicator:SetHide(false);
		instance.BoostedIndicator:SetTexture("Agreements_BoostedAllied.dds");
		instance.BoostedIndicator:SetToolTipString(Locale.Lookup("TXT_KEY_SERVICE_ALLIED_TT"));
	else
		instance.BoostedIndicator:SetHide(true);
	end 

	return tooltipString;
end

function DoNextPendingTransaction()
	local activePlayerType : number = Game.GetActivePlayer();

	for playerType : number = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		if (DoNextPendingTransactionForPlayer(playerType, -1)) then
			return;
		end
	end

	SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, activePlayerType);
	Events.LeaderSetVisible();
end

function DoNextPendingTransactionForPlayer(selectedPlayerType : number, transactionID : number)
	local activePlayerType : number = Game.GetActivePlayer();

	local transaction : object = nil;
	if (transactionID ~= nil and transactionID ~= -1) then
		transaction = Game.GetTransaction(transactionID);
	else
		local pendingTransactions : table = Game.GetPendingTransactions(selectedPlayerType, activePlayerType);

		if (#pendingTransactions == 0) then
			return false;
		end

		transaction = pendingTransactions[1];
		if (transaction:GetReceivingPlayer() ~= activePlayerType) then
			error("Wrong transaction");
		end
	end

	if (transaction:GetRelationshipLevel() ~= -1) then
		SetDiplomacyUIState(g_diplomacyUIStates.RELATIONSHIP, transaction:GetSendingPlayer());
		Events.LeaderSetVisible();
	elseif (transaction:GetForeignPolicy() ~= -1) then
		SetDiplomacyUIState(g_diplomacyUIStates.AGREEMENTS, transaction:GetSendingPlayer());
		Events.LeaderSetVisible();
	elseif (transaction:GetReaction() ~= -1) then
		SetDiplomacyUIState(g_diplomacyUIStates.CONFRONTATION, transaction:GetSendingPlayer());
		Events.LeaderSetVisible();
	elseif (transaction:GetMakePeace()) then
		SetDiplomacyUIState(g_diplomacyUIStates.WAR, transaction:GetSendingPlayer());
		Events.LeaderSetVisible();
	else
		error("Invalid transaction");
	end

	return true;
end

function ShowDiploTutorial(name : string, tutorialType : number, introTextKey : string)
	if (Game.GetTutorialLevel() > 2 or UI.HasTutorialBeenSeen(name) or Game.IsGameMultiPlayer()) then
		return;
	end

	UI.SetTutorialHasBeenSeen(name, true);

	if (introTextKey ~= nil) then	
		local tutorialInfo : table = GameInfo.Tutorials[tutorialType];
		LuaEvents.DiplomacyUI_ShowTutorialIntro(tutorialType, introTextKey);
	else
		Events.SerialEventGameMessagePopup{
			Type = ButtonPopupTypes.BUTTONPOPUP_TUTORIAL,
			Data1 = tutorialType,
			Data2 = 1,
		};
	end
end
-- ===========================================================================
--	Is there an active, meaningful war status between these players that needs
--	resolution?
--	[Called By] Confrontation UI upon player elimination/game end
-- ===========================================================================
function NeedsWarStatusResolution(playerAType : number, playerBType : number)
	local warStatus : object = Game.GetWarStatus(playerAType, playerBType);
	-- No actual war going on
	if (warStatus == nil) then
		return false;
	end
		
	local playerAScore : number = warStatus:GetPlayerScore(playerAType) or 0;
	local playerBScore : number = warStatus:GetPlayerScore(playerBType) or 0;
	-- War just started
	if (playerAScore <= 0 and playerBScore <= 0) then
		return false;
	end
	-- War tied / no value to convert to spoils
	if (playerAScore == playerBScore) then
		return false;
	end

	return true;
end

-- ===========================================================================
--	Fill a table up with the pieces that determine a player's score
--	player			Player to get score pieces from
--	outScoreTable	Table to contain scores entries.
-- ===========================================================================
function GetPlayersScorePieces( player, outScoreTable  )

	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_CITIES",			player:GetScoreFromCities()));
	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_POPULATION",		player:GetScoreFromPopulation()));
	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_LAND",			player:GetScoreFromLand()));
	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_WONDERS",			player:GetScoreFromWonders()));

	if (not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_TECH",		player:GetScoreFromTechs()));
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_FUTURE_TECH", player:GetScoreFromFutureTech()));
	end
	if (not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)) then
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_POLICIES",	player:GetScoreFromPolicies()));
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_FUTURE_POLICIES", player:GetScoreFromFuturePolicies()));
	end
end