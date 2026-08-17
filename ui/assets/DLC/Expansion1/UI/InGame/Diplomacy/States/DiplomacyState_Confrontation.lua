-------------------------------------------------
-- Confrontation Diplomacy State
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
local m_waitingForTransaction : boolean = false;
local DEFEAT_REACTION_ID = GameInfo.Reactions["REACTION_DEFEATED_CONFRONTATION"].ID;

function Update()
	InitWordBubble();

	local pendingTransactions : table = Game.GetPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID());

	if (#pendingTransactions == 0) then
		LuaEvents.Diplomacy_Close();
		return;
	end

	local transaction : object = pendingTransactions[1];
	if (transaction:GetReceivingPlayer() ~= m_player:GetID() or transaction:GetReaction() == -1) then
		LuaEvents.Diplomacy_Close();
		return;
	end

	-- Get the line name
	local line : string = nil;
	for reaction_line : table in GameInfo.Reaction_Line{ ReactionType = GameInfo.Reactions[transaction:GetReaction()].Type } do
		line = reaction_line.DialogueLine;
		break;
	end

	-- Say the line
	SayLine(line, transaction:GetSendingPlayer(), m_player:GetID(), Controls.TheirResponse);

	-- Player response line
	local responseLine : string = GetPlayerResponseLineForReaction(transaction:GetReaction());
	Controls.OptionButton1:SetHide(false);
	Controls.OptionButton1:SetText( Locale.Lookup(responseLine) );
	Controls.OptionButton1:RegisterCallback(Mouse.eLClick, function() 
		local didAccept : boolean = true;
		m_waitingForTransaction = true;

		-- Intercept in the case of the Defeat confrontation, as that has a second step
		-- to resolve War Spoils before the transaction is considered resolved		
		if (transaction:GetReaction() == DEFEAT_REACTION_ID and NeedsWarStatusResolution(m_player:GetID(), m_selectedPlayer:GetID())) then
			LuaEvents.DiplomacyUI_ShowWarSpoilsBuilder(m_player:GetID(), m_selectedPlayer:GetID(), function(didConfirm : boolean) 
				if (didConfirm) then
					Game.ResolveWarElimination(m_player:GetID(), m_selectedPlayer:GetID());
					Network.SendResolveTransaction(transaction:GetID(), didAccept);
				end
			end)
		else
			Network.SendResolveTransaction(transaction:GetID(), didAccept);
		end
	end);

	UpdateConversationControlSizes();
end

function UpdateConversationControlSizes()
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	local headerSize= 144;
	local bubblePadding = 80;
	local cardOffsetY = 180;
	local cardOffsetX = screenSizeX*.11;
	local cardHeight = 320;
	local headerY = 144;
	local bubbleNubCorrection = 16;
	local myBubblePadding = 76;
	if((screenSizeX-cardOffsetX*2)<1940) then
		cardOffsetX = screenSizeX*.085;	
		cardOffsetY = 120;
	end

--	Controls.MySpeechBubbleStack:CalculateSize();
--	Controls.MySpeechBubbleStack:ReprocessAnchoring();
--	Controls.MySpeechBubble:SetSizeY(Controls.MySpeechBubbleStack:GetSizeY());
	--Horizontal sizing for their speech bubble
	Controls.TheirSpeechBubble:SetSizeX(screenSizeX/2);
	Controls.TheirResponse:SetWrapWidth((screenSizeX/2)-40);
	--Vertical sizing for their speech bubble
	Controls.TheirSpeechBubbleStack:CalculateSize();
	Controls.TheirSpeechBubbleStack:ReprocessAnchoring();
	local theirBubbleY = 138;
	if(Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding > 138) then
		theirBubbleY = Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding;
	end
	Controls.TheirSpeechBubble:SetSizeY(theirBubbleY);

	Controls.ButtonStack:CalculateSize();
	Controls.ButtonStack:ReprocessAnchoring();
	local bubbleWindowHeight = screenSizeY-theirBubbleY-headerSize-cardOffsetY-cardHeight-Controls.ButtonStack:GetSizeY();
--	Controls.BubbleWindow:SetSizeY(bubbleWindowHeight);
	Controls.BubbleContentStack:CalculateSize();
	Controls.BubbleContentStack:ReprocessAnchoring();
	Controls.BubbleWindowBacking:SetSizeY(Controls.BubbleContentStack:GetSizeY());
	
	Controls.MySpeechBubble:SetOffsetY(cardOffsetY+cardHeight-bubbleNubCorrection);
	Controls.MySpeechBubble:SetSizeY(bubbleWindowHeight+bubbleNubCorrection+Controls.ButtonStack:GetSizeY());
end

function InitWordBubble()
	--Assign the correct text string
	if (m_selectedPlayer:GetID() ~= m_player:GetID()) then
		--Position bubble for screen resolution
		local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
		local cardOffsetX = screenSizeX*.11;
		local headerY = 144;
		Controls.TheirSpeechBubble:SetOffsetY(headerY);
		Controls.TheirSpeechBubble:SetOffsetX(cardOffsetX + 36);

		--Horizontal sizing for TheirSpeechBubble
		Controls.TheirSpeechBubble:SetSizeX(screenSizeX/2);
		Controls.TheirResponse:SetWrapWidth((screenSizeX/2)-40);

		--Vertical sizing for TheirSpeechBubble
		local bubblePadding = 80;
		Controls.TheirSpeechBubbleStack:CalculateSize();
		Controls.TheirSpeechBubbleStack:ReprocessAnchoring();
		local theirBubbleY = 138;
		if(Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding > 138) then
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
		Update();
		Events.LeaderSetVisible();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function OnInitialize(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];

	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	LuaEvents.DiplomacyUI_ResetAnimations.Add(ResetAnimations);
	Events.TransactionResolved.Add(OnTransactionResolved);

	--Size and position speech bubble and services list
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	local cardSize = 780;
	local cardOffsetX = screenSizeX*.11;
	local cardOffsetY = 180;
	local cardHeight = 320;
	local headerY = 144;
	if((screenSizeX-cardOffsetX*2)<1940) then
		cardOffsetX = screenSizeX*.085;
		cardOffsetY = 120;
	else
		cardSize = (screenSizeX-2*cardOffsetX-200)/2;
		if(cardSize>980) then
			Controls.MySpeechBubble:SetOffsetX(cardOffsetX + 44);
			Controls.MySpeechBubble:SetOffsetY(cardOffsetY+cardHeight);
			Controls.MySpeechBubble:SetSizeX(cardSize);
			Controls.BubbleWindowBacking:SetSizeX(cardSize);
		else
			Controls.MySpeechBubble:SetSizeX(cardSize+cardOffsetX + 44);
		end
	end
	Controls.TheirSpeechBubble:SetOffsetY(headerY);
	Controls.TheirSpeechBubble:SetOffsetX(cardOffsetX + 36);

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
	if (state == g_diplomacyUIStates.CONFRONTATION) then
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
	if (transaction:GetReaction() == -1) then
		return;
	end

	m_waitingForTransaction = false;

	if (transaction:GetSendingPlayer() == m_selectedPlayer:GetID()) then
		DoNextPendingTransaction();
	end
end

function OnDiplomacyConfrontationResolved(playerType : number, reactionIndex : number)
	local nextReaction : table = m_player:GetNextPendingConfrontationReaction();
	if (nextReaction ~= nil) then
		SetDiplomacyUIState(g_diplomacyUIStates.CONFRONTATION, nextReaction.PlayerType);
		Events.LeaderSetVisible();
	else
		LuaEvents.Diplomacy_Close();
	end
end

-------------------------------------------------
-- Initialization
-------------------------------------------------