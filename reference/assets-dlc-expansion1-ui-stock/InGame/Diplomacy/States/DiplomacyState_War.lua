-------------------------------------------------
-- War Diplomacy State
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");
include("ConversationSystem");

local HARMONY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID;
local PURITY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID;
local SUPREMACY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID;

local m_player : object = nil;
local m_selectedPlayer : object = nil;
local m_shown : boolean = false;
local m_waitingforTransaction : boolean = false;

local m_peaceTermInstanceManager : table = InstanceManager:new("PeaceTermItem", "Content", Controls.PeaceTermsStack);

function DoOptions()
	InitWordBubble();
	local greetingLine : string = "LINE_DIPLO_WAR_GREETING";	
	Events.LeaderSetVisible();

	local peaceAcceptable : boolean, rejectionStatus : number = m_selectedPlayer:IsPeaceAcceptable(m_player:GetID());

	if (peaceAcceptable or m_selectedPlayer:IsHuman()) then
		ShowOptionButton(1, Locale.Lookup("TXT_KEY_DIPLOMACYUI_OFFER_PEACE"), false, function() 
			if (not m_waitingForTransaction) then
				local warStatus : object = Game.GetWarStatus(m_player:GetID(), m_selectedPlayer:GetID());
				local playerScore : number = warStatus:GetPlayerScore(m_player:GetID());
				local selectedPlayerScore : number = warStatus:GetPlayerScore(m_selectedPlayer:GetID());

				if (playerScore ~= selectedPlayerScore) then
					if (warStatus:GetAdvantagePlayer() == -1) then
						SendPeaceOffer();	
					else
						LuaEvents.DiplomacyUI_ShowWarSpoilsBuilder(m_player:GetID(), m_selectedPlayer:GetID(), function(didConfirm : boolean) 
							if (didConfirm) then
								SendPeaceOffer();
							end

							UpdateWarStatus();
						end)
					end
				else
					SendPeaceOffer();
				end
			end
		end);
	else
		HideOptionButton(1);

		greetingLine = "LINE_DIPLO_WAR_GREETING_NO_PEACE_TOO_SOON";

		if (rejectionStatus ~= nil and rejectionStatus ~= PeaceRejectionStatuses.NO_PEACE_REJECTION_STATUS) then
			if (rejectionStatus == PeaceRejectionStatuses.PEACE_REJECTION_STILL_HOPE) then
				greetingLine = "LINE_DIPLO_WAR_GREETING_NO_PEACE_STILL_HOPE";
			elseif (rejectionStatus == PeaceRejectionStatuses.PEACE_REJECTION_STALEMATE) then
				greetingLine = "LINE_DIPLO_WAR_GREETING_NO_PEACE_STALEMATE";
			end
		end
	end

	HideOptionButton(2);

	SayLine(greetingLine, m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	UpdateWarStatus();
	UpdateConversationControlSizes();
end

function SendPeaceOffer()
	if (m_waitingForTransaction) then
		return;
	end

	Game.MakePeaceProposal(m_player:GetID(), m_selectedPlayer:GetID());

	if (m_selectedPlayer:IsHuman()) then
		DoOtherPlayerThinkingAboutPeace();
	end
					
	m_waitingForTransaction = true;
end

function DoOtherPlayerAcceptedPeace()
	InitWordBubble();

	m_waitingForTransaction = false;
	
	SayLine("LINE_DIPLO_PEACE_ACCEPT", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	ShowOptionButton(1, Locale.Lookup("TXT_KEY_DIPLOMACYUI_GOODBYE"), false, function()
		SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, m_selectedPlayer:GetID());
		Events.LeaderSetVisible();
	end);
	HideOptionButton(2);

	--UpdateWarStatus();
	UpdateConversationControlSizes();
end

function DoOtherPlayerRejectedPeace()
	InitWordBubble();

	m_waitingForTransaction = false;

	SayLine("LINE_DIPLO_PEACE_REJECT", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	HideOptionButton(1);
	HideOptionButton(2);

	UpdateWarStatus();
	UpdateConversationControlSizes();
end

function DoOtherPlayerThinkingAboutPeace()
	InitWordBubble();

	m_waitingForTransaction = false;

	SayLine("LINE_DIPLO_LET_ME_THINK", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	HideOptionButton(1);
	HideOptionButton(2);

	UpdateWarStatus();
	UpdateConversationControlSizes();
end

function DoOtherPlayerStillThinkingAboutPeace()
	InitWordBubble();

	m_waitingForTransaction = false;

	SayLine("LINE_DIPLO_STILL_THINKING", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	HideOptionButton(1);
	HideOptionButton(2);

	UpdateWarStatus();
	UpdateConversationControlSizes();
end

function DoOtherPlayerOfferedPeace(transaction : object)
	InitWordBubble();

	SayLine("LINE_DIPLO_PEACE_OFFER", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	ShowOptionButton(1, Locale.Lookup("TXT_KEY_DIPLOMACYUI_ACCEPT_PEACE"), false, function() 
		Network.SendResolveTransaction(transaction:GetID(), true);
		m_waitingForTransaction = true;
	end);

	ShowOptionButton(2, Locale.Lookup("TXT_KEY_DIPLOMACYUI_REJECT_PEACE"), false, function() 
		Network.SendResolveTransaction(transaction:GetID(), false);
		m_waitingForTransaction = true;
	end);

	local isPeaceOffer : boolean = true;
	UpdateWarStatus(isPeaceOffer);
	UpdateConversationControlSizes();
end

function DoAcceptedOtherPlayersPeace()
	InitWordBubble();

	m_waitingForTransaction = false;

	SayLine("LINE_DIPLO_PEACE_HAPPY_YOU_ACCEPTED", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	ShowOptionButton(1, Locale.Lookup("TXT_KEY_DIPLOMACYUI_GOODBYE"), false, function()
		SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, m_selectedPlayer:GetID());
		Events.LeaderSetVisible();
	end);
	HideOptionButton(2);

	UpdateWarStatus();
	UpdateConversationControlSizes();
end

function DoRejectedOtherPlayersPeace()
	InitWordBubble();

	m_waitingForTransaction = false;

	SayLine("LINE_DIPLO_PEACE_SAD_YOU_REJECTED", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	Events.LeaderSetVisible();

	ShowOptionButton(1, Locale.Lookup("TXT_KEY_DIPLOMACYUI_GOODBYE"), false, function()
		SetDiplomacyUIState(g_diplomacyUIStates.ACTIONS, m_selectedPlayer:GetID());
		Events.LeaderSetVisible();
	end);
	HideOptionButton(2);

	UpdateWarStatus();
	UpdateConversationControlSizes();
end

function UpdateWarStatus(isPeaceOffer : boolean)
	m_peaceTermInstanceManager:ResetInstances();

	local myCivKey : string = m_player:GetCivilizationShortDescriptionKey();
	local theirCivKey : string = m_selectedPlayer:GetCivilizationShortDescriptionKey();
	Controls.MyWarScoreLabel:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_ME", myCivKey));
	Controls.TheirWarScoreLabel:SetText(Locale.Lookup(theirCivKey));

	-- Update banner
	local affinityType : number = m_selectedPlayer:GetDominantAffinityType();
	if (affinityType == HARMONY_AFFINITY_TYPE) then
		Controls.Banner:SetTexture("War_Harmony.dds");
	elseif (affinityType == PURITY_AFFINITY_TYPE) then
		Controls.Banner:SetTexture("War_Purity.dds");
	elseif (affinityType == SUPREMACY_AFFINITY_TYPE) then
		Controls.Banner:SetTexture("War_Supremacy.dds");
	else
		Controls.Banner:SetTexture("War_Purity.dds");
	end

	-- Update Score and Status
	local warStatus : object = Game.GetWarStatus(m_player:GetID(), m_selectedPlayer:GetID());
	if (warStatus ~= nil) then
		local myWarScore : number = warStatus:GetPlayerScore(m_player:GetID());
		local theirWarScore : number = warStatus:GetPlayerScore(m_selectedPlayer:GetID());
		Controls.MyWarScoreValue:SetText(myWarScore);
		Controls.TheirWarScoreValue:SetText(theirWarScore);
	
		local favorStr : string = Locale.Lookup("TXT_KEY_WAR_FAVORING")..": ";
		local advantagePlayer : number = warStatus:GetAdvantagePlayer();
		local advantageStrength : number = warStatus:GetAdvantageStrength();
		-- Difference between the scores favors neither side
		if (advantagePlayer == -1) then
			favorStr = favorStr..Locale.Lookup("TXT_KEY_WAR_NEITHER_SIDE");
		else
			-- Difference is high, dominating
			if (advantageStrength >= 70) then
				favorStr = Locale.Lookup("TXT_KEY_WAR_DOMINATING")..": ";
			end
		
			-- Which side has advantage
			if (advantagePlayer == m_player:GetID()) then
				favorStr = favorStr.."[COLOR_GREEN]"..Locale.Lookup(myCivKey).."[ENDCOLOR]";
			else
				favorStr = favorStr.."[COLOR_RED]"..Locale.Lookup(theirCivKey).."[ENDCOLOR]";
			end
		end
		Controls.WarFavoringLabel:SetText(Locale.ToUpper(favorStr));

		local peaceAcceptable : boolean, rejectionStatus : number = m_selectedPlayer:IsPeaceAcceptable(m_player:GetID());
		if (peaceAcceptable or isPeaceOffer or m_selectedPlayer:IsHuman()) then
			-- Peace Terms items
			local peaceTermsCities : table = warStatus:GetPeaceTermsCities();
			local peaceTermsTechs : table = warStatus:GetPeaceTermsTechs();
			local peaceTermsEnergy : number = warStatus:GetPeaceTermsLumpEnergy();
			local peaceTermsCapital : number = warStatus:GetPeaceTermsLumpCapital();
			local noTerms : boolean = true;

			Controls.WhitePeaceSummaryStack:SetHide(true);
			Controls.PeaceTermItemsContainer:SetHide(false);

			-- Cities
			for i,peaceTermCity in ipairs(peaceTermsCities) do
				local city : object = Players[peaceTermCity.Loser]:GetCityByID(peaceTermCity.CityID);
				if (city ~= nil) then
					local instance : table = m_peaceTermInstanceManager:GetInstance();

					local surrenderStr : string = Locale.ConvertTextKey("TXT_KEY_PEACE_TERM_CITY", 
						Players[peaceTermCity.Loser]:GetCivilizationShortDescriptionKey(),
						Players[peaceTermCity.Winner]:GetCivilizationShortDescriptionKey(),
						city:GetNameKey());

					instance.Summary:SetText(surrenderStr);
					noTerms = false;
				end
			end
			-- Techs
			for i : number, techType : number in ipairs(peaceTermsTechs) do
				local instance : table = m_peaceTermInstanceManager:GetInstance();
				local techInfo : table = GameInfo.Technologies[techType];
				local surrenderStr : string = Locale.ConvertTextKey("TXT_KEY_PEACE_TERM_TECH", 
						Players[warStatus:GetDisadvantagePlayer()]:GetCivilizationShortDescriptionKey(),
						Players[warStatus:GetAdvantagePlayer()]:GetCivilizationShortDescriptionKey(),
						techInfo.Description);

				instance.Summary:SetText(surrenderStr);
				noTerms = false;
			end

			-- Energy
			local peaceTermEnergy : number = warStatus:GetPeaceTermsLumpEnergy();
			if (peaceTermEnergy > 0) then
				local instance = m_peaceTermInstanceManager:GetInstance();

				local surrenderStr : string = Locale.ConvertTextKey("TXT_KEY_PEACE_TERM_YIELD", 
						Players[warStatus:GetDisadvantagePlayer()]:GetCivilizationShortDescriptionKey(),
						Players[warStatus:GetAdvantagePlayer()]:GetCivilizationShortDescriptionKey(),
						peaceTermEnergy,
						GameInfo.Yields["YIELD_ENERGY"].IconString,
						GameInfo.Yields["YIELD_ENERGY"].Description);

				instance.Summary:SetText(surrenderStr);
				noTerms = false;
			end
			
			-- Capital
			local peaceTermCapital : number = warStatus:GetPeaceTermsLumpCapital();
			if (peaceTermCapital > 0) then
				local instance = m_peaceTermInstanceManager:GetInstance();

				local surrenderStr : string = Locale.ConvertTextKey("TXT_KEY_PEACE_TERM_YIELD", 
						Players[warStatus:GetDisadvantagePlayer()]:GetCivilizationShortDescriptionKey(),
						Players[warStatus:GetAdvantagePlayer()]:GetCivilizationShortDescriptionKey(),
						peaceTermCapital,
						GameInfo.Yields["YIELD_CAPITAL"].IconString,
						GameInfo.Yields["YIELD_CAPITAL"].Description);

				instance.Summary:SetText(surrenderStr);
				noTerms = false;
			end


			-- No terms?
			if (noTerms) then
				Controls.WhitePeaceSummaryStack:SetHide(false);
				Controls.PeaceTermItemsContainer:SetHide(true);

				-- Total surrender, or just nothing earned yet?			
				if (warStatus:IsTotalSurrender()) then
					Controls.WhitePeaceSummary:SetText(Locale.Lookup("TXT_KEY_TOTAL_SURRENDER"));
				else
					-- Winning or losing?
					if (advantagePlayer == -1) then
						Controls.WhitePeaceSummary:SetText(Locale.Lookup("TXT_KEY_WHITE_PEACE_TERMS"));
					elseif (advantagePlayer == m_player:GetID()) then
						Controls.WhitePeaceSummary:SetText(Locale.Lookup("TXT_KEY_NO_TERMS_WINNER"));
					else
						Controls.WhitePeaceSummary:SetText(Locale.Lookup("TXT_KEY_NO_TERMS_LOSER"));
					end
				end
			end

			Controls.PeaceTermsStack:CalculateSize();
			Controls.PeaceTermsStack:ReprocessAnchoring();
			Controls.PeaceTermsScrollPanel:CalculateInternalSize();
		else			
			Controls.PeaceTermItemsContainer:SetHide(true);
			Controls.WhitePeaceSummary:SetText(Locale.Lookup("TXT_KEY_NO_PEACE_OFFERS", theirCivKey));
			Controls.WhitePeaceSummaryStack:SetHide(Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID()) ~= RelationshipLevels.RELATIONSHIP_WAR);
		end
	else
		-- No war status or too early to have valid data, treat as "Too Soon, No Peace"
		Controls.MyWarScoreValue:SetText("0");
		Controls.TheirWarScoreValue:SetText("0");
		Controls.WarFavoringLabel:SetText(Locale.ToUpper(Locale.Lookup("TXT_KEY_WAR_FAVORING")..": "..Locale.Lookup("TXT_KEY_WAR_NEITHER_SIDE")));	
		Controls.PeaceTermItemsContainer:SetHide(true);
		Controls.WhitePeaceSummary:SetText(Locale.Lookup("TXT_KEY_NO_PEACE_OFFERS", theirCivKey));		
		Controls.WhitePeaceSummaryStack:SetHide(Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID()) ~= RelationshipLevels.RELATIONSHIP_WAR);
	end
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
end

function ShowOptionButton(index : number, str : string, disabled : boolean, callback : ifunction)
	local control : object = Controls["OptionButton" .. index];

	control:SetHide(false);
	control:SetDisabled(disabled);
	control:SetText(str);
	control:RegisterCallback(Mouse.eLClick, callback);
end

function HideOptionButton(index : number)
	local control : object = Controls["OptionButton" .. index];
	
	control:SetHide(true);
end

function InitWordBubble()
	--Assign the correct text string
	if (m_selectedPlayer:GetID() ~= m_player:GetID() and m_selectedPlayer:IsAlive()) then
		--Position bubble for screen resolution
		local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
		local cardOffsetX = screenSizeX*.11;
		local headerY = 72;
		Controls.TheirSpeechBubble:SetOffsetY(headerY);
		Controls.TheirSpeechBubble:SetOffsetX(cardOffsetX + 18);

		--Horizontal sizing for TheirSpeechBubble
		Controls.TheirSpeechBubble:SetSizeX(screenSizeX/2);
		Controls.TheirResponse:SetWrapWidth((screenSizeX/2)-20);

		--Vertical sizing for TheirSpeechBubble
		local bubblePadding = 40;
		Controls.TheirSpeechBubbleStack:CalculateSize();
		Controls.TheirSpeechBubbleStack:ReprocessAnchoring();
		local theirBubbleY = 69;
		if(Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding > 69) then
			theirBubbleY = Controls.TheirResponse:GetSizeY() + bubblePadding;
		end
		Controls.TheirSpeechBubble:SetSizeY(theirBubbleY);

		--Replay Animations and show
		Controls.TheirSpeechBubble:SetHide(false);
		Controls.BubbleAlpha:SetToBeginning();
		Controls.BubbleAlpha:Play();
		Controls.BubbleSlide:SetToBeginning();
		Controls.BubbleSlide:Play();
	else
		Controls.TheirSpeechBubble:SetHide(true);
	end
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function ShowHideHandler(isHide : boolean)
	if (not isHide) then
		m_player = Players[Game.GetActivePlayer()];

		if (Game.GetNumPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID()) > 0) then
			local transactions : table = Game.GetPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID());
			for i : number, transaction : object in ipairs(transactions) do
				if (transaction:GetMakePeace()) then
					DoOtherPlayerStillThinkingAboutPeace();
					return;
				end
			end
		end

		if (Game.GetNumPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID()) > 0) then
			local transactions : table = Game.GetPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID());
			for i : number, transaction : object in ipairs(transactions) do
				if (transaction:GetMakePeace()) then
					DoOtherPlayerOfferedPeace(transaction);
					return;
				end
			end
		end

		ShowDiploTutorial("DIPLOMACY_WAR", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_WAR"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_WAR");

		DoOptions();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function OnInitialize(isHotload : boolean)
	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	LuaEvents.DiplomacyUI_ResetAnimations.Add(ResetAnimations);
	Events.TransactionResolved.Add(OnTransactionResolved);

	--Size and position speech bubble and services list
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
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
			Controls.BubbleWindowBacking:SetSizeX(cardSize);
		else
			Controls.MySpeechBubble:SetSizeX(cardSize+cardOffsetX + 22);
		end
	end
	Controls.TheirSpeechBubble:SetOffsetY(headerY);
	Controls.TheirSpeechBubble:SetOffsetX(cardOffsetX + 18);

	ContextPtr:SetHide(true);
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
	LuaEvents.DiplomacyUI_ResetAnimations.Remove(ResetAnimations);
	Events.TransactionResolved.Remove(OnTransactionResolved);
end
ContextPtr:SetShutdown(OnShutdown)

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function ResetAnimations()
	Controls.MyBubbleAlphaAnim:SetToBeginning();
	Controls.MyBubbleAlphaAnim:Play();
	Controls.MyBubbleSlideAnim:SetToBeginning();
	Controls.MyBubbleSlideAnim:Play();
end

function OnStateChanged(state : number, selectedPlayer : number)
	if (state == g_diplomacyUIStates.WAR) then
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

function OnTransactionResolved(id : number)
	if (not m_shown or not m_waitingForTransaction) then
		return;
	end

	local transaction : object = Game.GetTransaction(id);
	if (not transaction:GetMakePeace()) then
		return;
	end

	if (transaction:GetSendingPlayer() == m_selectedPlayer:GetID()) then
		-- I have accepted peace that the other player proposed
		if (transaction:WasAccepted()) then
			DoAcceptedOtherPlayersPeace();
		else
			DoRejectedOtherPlayersPeace();
		end
	else
		-- The other player has accepted peace that I proposed
		if (transaction:WasAccepted()) then
			DoOtherPlayerAcceptedPeace();
		else
			DoOtherPlayerRejectedPeace();
		end
	end
end