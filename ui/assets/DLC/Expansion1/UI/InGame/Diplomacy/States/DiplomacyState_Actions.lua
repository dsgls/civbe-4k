-------------------------------------------------
-- Actions Diplomacy State
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");

local m_player : object = nil;
local m_selectedPlayer : object = nil;
local m_shown : boolean = false;

local m_actionEntryInstanceManager = InstanceManager:new("ActionEntry", "Button", Controls.ActionsStack);

function ShowHideHandler(isHide : boolean, isInit:boolean)
	if isInit then return; end

	if (not isHide) then
		if (m_selectedPlayer:IsAlive()) then
			DoActions();
		else
			if (m_player:GetNumPendingConfrontationReactionsWithPlayer(m_selectedPlayer:GetID())) then
				DoDead();
			else
				DoActions();
			end
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function DoActions()
	Controls.ChoiceArea:SetHide(false);
	Controls.PlayerDead:SetHide(true);

	m_actionEntryInstanceManager:ResetInstances();

	InitWordBubble();

	if (m_selectedPlayer == m_player) then
		AddAction("{TXT_KEY_DIPLOMACYUI_AFFINITY:upper}", g_diplomacyUIStates.AFFINITY, true);
		AddAction("{TXT_KEY_DIPLOMACYUI_MANAGEMYTRAITS:upper}", g_diplomacyUIStates.TRAITS, true);

		local hasMetAnyone : boolean = Teams[m_player:GetTeam()]:GetHasMetCivCount() > 0;
		if (hasMetAnyone or Teams[m_player:GetTeam()]:GetNumMembers() > 1) then
			AddAction("{TXT_KEY_DIPLOMACYUI_VIEWMYAGREEMENTS:upper}", g_diplomacyUIStates.AGREEMENTS, true);
			AddAction("{TXT_KEY_DIPLOMACYUI_ALL_SERVICES:upper}", g_diplomacyUIStates.ALL_SERVICES, m_player:IsTurnActive());
		end
	
		Events.LeaderSetAnimation(m_selectedPlayer:GetID(), LeaderheadAnimationTypes.LEADERHEAD_ANIM_NEUTRAL_IDLE);
	elseif (m_selectedPlayer ~= nil) then
		AddAction("{TXT_KEY_DIPLOMACYUI_DISCUSSMYAGREEMENTS:upper}" , g_diplomacyUIStates.AGREEMENTS, m_player:IsTurnActive());
		AddAction("{TXT_KEY_DIPLOMACYUI_CHANGERELATIONSHIP:upper}", g_diplomacyUIStates.RELATIONSHIP, m_player:IsTurnActive());

		SayLine("LINE_DIPLO_GREETING", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
		UpdateWordBubble();
	end

	Controls.ActionsStack:CalculateSize();
	Controls.ActionsStack:ReprocessAnchoring();

	Controls.StackArea:SetSizeY(Controls.ActionsStack:GetSizeY());
end

function DoDead()
	Controls.TheirSpeechBubble:SetHide(true);
	Controls.PlayerDead:SetHide(false);
	Events.LeaderSetAnimation(-1, 0);
	Events.LeaderSetVisible();
	Controls.ChoiceArea:SetHide(true);
end

function AddAction(actionString : string, state : number, enabled : boolean)
	local instance : table = m_actionEntryInstanceManager:GetInstance();
	InitActionEntryInstance(instance, actionString, state, enabled);
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function OnInitialize(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];

	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	LuaEvents.ShowDiplomacyOverviewUI.Add(ShowWindow);
	LuaEvents.DiplomacyUI_ResetAnimations.Add(ResetAnimations);

	local cardSize :number = 500;
	local screenSizeX:number, screenSizeY:number  = UIManager:GetScreenSizeVal();
	local cardOffsetX:number = screenSizeX*.12;
	if((screenSizeX-cardOffsetX*2)<1000) then
		cardOffsetX = screenSizeX*.05;
		cardSize=415;
	end
	cardOffsetX = math.floor(cardOffsetX);	-- If this isn't a whole number, lines may appear on certain glyphs of the contained font.
	Controls.ChoiceArea:SetSizeX(cardOffsetX+cardSize);
	Controls.StackArea:SetSizeX(cardOffsetX+cardSize);
	Controls.StackGlowAlpha:SetSizeX(cardOffsetX+cardSize);
	Controls.StackGlowImage:Resize(cardOffsetX+cardSize,215);
	Controls.ChoiceGlowImage:Resize(cardOffsetX+cardSize,215);
	--Set the size of the actions box to offset appropriately FOR SQUARE RESOLUTIONS
	if((screenSizeX/screenSizeY)==1.25) then
		Controls.ChoiceArea:SetSizeY(screenSizeY-230);
	end
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
	LuaEvents.ShowDiplomacyOverviewUI.Remove(ShowWindow);
	LuaEvents.DiplomacyUI_ResetAnimations.Remove(ResetAnimations);
end
ContextPtr:SetShutdown(OnShutdown)

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function ResetAnimations()
	Controls.ChoiceAreaAlpha:SetToBeginning();
	Controls.ChoiceAreaSlide:SetToBeginning();
	Controls.ChoiceAreaAlpha:Play();
	Controls.ChoiceAreaSlide:Play();
	Controls.StackAreaAlpha:SetToBeginning();
	Controls.StackAreaAlpha:Play();
	Controls.StackGlowAlpha:SetToBeginning();
	Controls.StackGlowAlpha:Play();
	Controls.GlowAlpha:SetToBeginning();
	Controls.GlowAlpha:Play();
end

function OnStateChanged(state : number, selectedPlayer : number)
	if (state == g_diplomacyUIStates.ACTIONS) then
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

function ShowWindow()
	Controls.ChoiceAreaAlpha:SetToBeginning();
	Controls.ChoiceAreaSlide:SetToBeginning();
	Controls.ChoiceAreaAlpha:Play();
	Controls.ChoiceAreaSlide:Play();
	Controls.StackAreaAlpha:SetToBeginning();
	Controls.StackAreaAlpha:Play();
	Controls.StackGlowAlpha:SetToBeginning();
	Controls.StackGlowAlpha:Play();
	Controls.GlowAlpha:SetToBeginning();
	Controls.GlowAlpha:Play();
end
-------------------------------------------------
-- Initialization
-------------------------------------------------
function InitActionEntryInstance(instance : table, textKey : string, state : number, enabled : boolean)
	instance.Button:SetText(Locale.Lookup(textKey));
	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		PushDiplomacyUIState(state, m_selectedPlayer:GetID());
		Events.LeaderSetVisible();
	end);
	instance.Button:SetDisabled(not enabled);
end

function UpdateWordBubble()
		--Horizontal sizing for TheirSpeechBubble
		local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
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

		UpdateWordBubble();

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