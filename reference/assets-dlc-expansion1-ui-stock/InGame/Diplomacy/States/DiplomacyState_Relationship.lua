-------------------------------------------------
-- Relationship Diplomacy State
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");

local m_player : object = nil;
local m_selectedPlayer : object = nil;
local m_shown : boolean = false;
local m_relationshipLevelInstances : table = {};
local m_relationshipChoiceInstanceManager : table = InstanceManager:new("RelationshipChoice", "Button", Controls.RelationshipChoicesStack);
local m_relationshipLevelColors = {0xff1e17c6, 0xff2123a0, 0xffba815c, 0xff338354, 0xff19d24e};
local m_relationshipUpdated: boolean = false;
local m_holdArrowFlyout : boolean = false;

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

	--Vertical sizing for MySpeechBubble
	Controls.RelationshipChoicesStack:CalculateSize();
	Controls.RelationshipChoicesStack:ReprocessAnchoring();
	Controls.MySpeechBubbleStack:CalculateSize();
	Controls.MySpeechBubbleStack:ReprocessAnchoring();
	local bubbleWindowHeight = Controls.MySpeechBubbleStack:GetSizeY();
	Controls.BubbleWindowBacking:SetSizeY(bubbleWindowHeight);
	Controls.MySpeechBubble:SetOffsetY(cardOffsetY+cardHeight-bubbleNubCorrection);
	Controls.MySpeechBubble:SetSizeY(bubbleWindowHeight+bubbleNubCorrection+Controls.MySpeechBubbleStack:GetSizeY());

	--Horizontal sizing for TheirSpeechBubble
	Controls.TheirSpeechBubble:SetSizeX(screenSizeX/2);
	Controls.TheirResponse:SetWrapWidth((screenSizeX/2)-20);

	--Vertical sizing for TheirSpeechBubble
	Controls.TheirSpeechBubbleStack:CalculateSize();
	Controls.TheirSpeechBubbleStack:ReprocessAnchoring();
	local theirBubbleY = 69;
	if(Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding > 69) then
		theirBubbleY = Controls.TheirSpeechBubbleStack:GetSizeY() + bubblePadding;
	end
	Controls.TheirSpeechBubble:SetSizeY(theirBubbleY);
end

function UpdateCurrentRelationship()
	if (m_player == nil or m_selectedPlayer == nil) then
		error("Invalid players");
	end
	local relationshipInfo = GameInfo.RelationshipLevels[Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID())];
	Controls.Relationship:SetText(Locale.Lookup("TXT_KEY_DIPLO_CURRENTRELATIONSHIP").. ": [COLOR_".. relationshipInfo.Type.. "]" .. Locale.Lookup("{"..relationshipInfo.Description..":upper}"));
end

function DoChangeRelationship(relationship : number)
	local currentRelationship = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
	Network.SendCreateRelationshipProposalTransaction(m_player:GetID(), m_selectedPlayer:GetID(), relationship);

	Controls.AcceptButton:SetHide(true);
	Controls.RejectButton:SetHide(true);
	Controls.CancelButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_NEVERMIND"));
	Controls.CancelButton:SetHide(false);

	local audioRelationshipChange;
	if(currentRelationship < relationship) then
		audioRelationshipChange = "AS2D_INTERFACE_RELATIONSHIP_UP";
	else
		audioRelationshipChange = "AS2D_INTERFACE_RELATIONSHIP_DOWN";
	end

	-- If we're talking to a human and we're upgrading our relationship,
	-- tell the player we'll think about it.
	if (m_selectedPlayer:IsHuman() and relationship > currentRelationship) then
		-- Hide buttons
		Controls.RelationshipChoicesStack:SetHide(true);
		SayLine("LINE_DIPLO_LET_ME_THINK", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
		Controls.CancelButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_LET_ME_THINK_DEFAULT_1"));
	else
		Events.AudioPlay2DSound(audioRelationshipChange);
	end

	UpdateConversationControlSizes();
end

function DoAreYouSure(relationship : number)
	Controls.RelationshipChoicesStack:SetHide(true);
	Controls.AcceptButton:SetHide(false);
	Controls.RejectButton:SetHide(true);
	Controls.AcceptButton:SetText(Locale.Lookup("TXT_KEY_DECLARE_WAR_YES"));
	Controls.CancelButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_NEVERMIND"));
	Controls.CancelButton:SetHide(false);

	Controls.AcceptButton:RegisterCallback(Mouse.eLClick, function() 
		DoChangeRelationship(relationship);
		if (relationship == RelationshipLevels.RELATIONSHIP_WAR) then
			PushDiplomacyUIState(g_diplomacyUIStates.WAR, m_selectedPlayer:GetID());
		end

		for j=1,5,1 do
			m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
			m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
		end

		m_holdArrowFlyout = false;
		HideRelationshipFlyout();
		Events.LeaderSetVisible();
	end);

	Controls.CancelButton:RegisterCallback(Mouse.eLClick, function() 
		DoDiscussRelationship();
		Events.LeaderSetVisible();

		for j=1,5,1 do
			m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
			m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
		end

		HideRelationshipFlyout();
		m_holdArrowFlyout = false;
	end);

	local currentRelationship : number = Game.GetRelationship(m_selectedPlayer:GetID(), m_player:GetID());

	if (relationship == RelationshipLevels.RELATIONSHIP_WAR) then
		SayLine("LINE_DIPLO_RELATIONSHIP_ARE_YOU_SURE_WAR", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	elseif (relationship > currentRelationship) then
		SayLine("LINE_DIPLO_RELATIONSHIP_ARE_YOU_SURE_POSITIVE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	else
		SayLine("LINE_DIPLO_RELATIONSHIP_ARE_YOU_SURE_NEGATIVE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
	end

	m_holdArrowFlyout = true;

	for j=1,5,1 do
		m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
		m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
	end

	if(relationship > currentRelationship) then
		for j=currentRelationship+1,relationship,1 do
			m_relationshipLevelInstances[j].ArrowRight:SetToBeginning();
			m_relationshipLevelInstances[j].ArrowRight:Play();
			m_relationshipLevelInstances[j].ArrowRightImage:SetColor(m_relationshipLevelColors[relationship+1]);
			m_relationshipLevelInstances[j].ArrowRight:SetHide(false);
		end
	else
		for j=relationship+2,currentRelationship+1,1 do
			m_relationshipLevelInstances[j].ArrowLeft:SetToBeginning();
			m_relationshipLevelInstances[j].ArrowLeft:Play();
			m_relationshipLevelInstances[j].ArrowLeftImage:SetColor(m_relationshipLevelColors[relationship+1]);
			m_relationshipLevelInstances[j].ArrowLeft:SetHide(false);
		end
	end
	ShowRelationshipFlyout(relationship);

	UpdateConversationControlSizes();
end

function DoChangeAlreadyPending()
	-- Hide buttons
	Controls.RelationshipChoicesStack:SetHide(true);
	Controls.AcceptButton:SetHide(true);
	Controls.RejectButton:SetHide(true);
	Controls.AcceptButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_ACCEPT"));
	Controls.CancelButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_NEVERMIND"));
	Controls.CancelButton:SetHide(false);

	SayLine("LINE_DIPLO_STILL_THINKING", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	Controls.CancelButton:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_TAKE_YOUR_TIME"));

	UpdateConversationControlSizes();
end

function DoDiscussRelationship()
	SayLine("LINE_DIPLO_RELATIONSHIP_INTRO", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);

	Controls.AcceptButton:SetHide(true);
	Controls.RejectButton:SetHide(true);
	Controls.AcceptButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_ACCEPT"));
	Controls.CancelButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_NEVERMIND"));
	Controls.CancelButton:SetHide(false);

	Controls.CancelButton:RegisterCallback(Mouse.eLClick, function() 
		PopDiplomacyUIState();
	end);

	UpdateRelationshipOptions();
	UpdateRelationshipMeter();
	UpdateConversationControlSizes();
end

function OnFearRespectTooltip( respectStageVal,reqRespectStageVal,fearStageVal,reqFearStageVal,reqImageOffsetY )
	local tipControlTable = {};
	TTManager:GetTypeControlTable("FearReqTooltip", tipControlTable);
	tipControlTable.FearReq:SetText(reqFearStageVal);
	tipControlTable.FearVal:SetText(fearStageVal);
	tipControlTable.RespectReq:SetText(reqRespectStageVal);
	tipControlTable.RespectVal:SetText(respectStageVal);
	tipControlTable.RespectImage:SetTextureOffsetVal(0,reqImageOffsetY);
	tipControlTable.FearImage:SetTextureOffsetVal(0,reqImageOffsetY+34);
	if(respectStageVal < reqRespectStageVal) then
		tipControlTable.RespectCheck:SetHide(true);
		tipControlTable.RespectHeaderStack:SetOffsetX(2);
		tipControlTable.RespectExplanation:SetHide(false);
	else
		tipControlTable.RespectCheck:SetHide(false);
		tipControlTable.RespectHeaderStack:SetOffsetX(32);
		tipControlTable.RespectExplanation:SetHide(true);
	end
	if(fearStageVal < reqFearStageVal) then
		tipControlTable.FearCheck:SetHide(true);
		tipControlTable.FearHeaderStack:SetOffsetX(2);
		tipControlTable.FearExplanation:SetHide(false);
	else
		tipControlTable.FearCheck:SetHide(false);
		tipControlTable.FearHeaderStack:SetOffsetX(32);
		tipControlTable.FearExplanation:SetHide(true);
	end
	local headerString : string = Locale.Lookup("{TXT_KEY_DIPLOMACYUI_REQUIREMENTS:upper}");
	if(fearStageVal >= reqFearStageVal or respectStageVal >= reqRespectStageVal) then
		headerString = headerString.. " - [COLOR_RELATIONSHIP_LEVEL_ALLIED]".. Locale.Lookup("{TXT_KEY_DIPLOMACYUI_PASSED:upper}");
		tipControlTable.PassFailBanner:SetColor(0x55138f3c);
	else
		headerString = headerString.. " - [COLOR_RELATIONSHIP_LEVEL_WAR]".. Locale.Lookup("{TXT_KEY_DIPLOMACYUI_FAILED:upper}");
		tipControlTable.PassFailBanner:SetColor(0x551714a0);
	end
	tipControlTable.TooltipHeader:SetText(headerString);
	tipControlTable.FearExplanationText:SetWrapWidth(tipControlTable.TooltipHeader:GetSizeX()-5);
	tipControlTable.RespectExplanationText:SetWrapWidth(tipControlTable.TooltipHeader:GetSizeX()-5);
	tipControlTable.FearExplanation:SetSizeY(tipControlTable.FearExplanationText:GetSizeY());
	tipControlTable.RespectExplanation:SetSizeY(tipControlTable.RespectExplanationText:GetSizeY());
	tipControlTable.FearExplanation:SetSizeX(tipControlTable.TooltipHeader:GetSizeX()+100);
	tipControlTable.RespectExplanation:SetSizeX(tipControlTable.TooltipHeader:GetSizeX()+100);
	tipControlTable.FearExplanationText:SetWrapWidth(tipControlTable.FearExplanation:GetSizeX()-5);
	tipControlTable.RespectExplanationText:SetWrapWidth(tipControlTable.RespectExplanation:GetSizeX()-5);
	tipControlTable.ContentStack:CalculateSize();
	tipControlTable.ContentStack:ReprocessAnchoring();
	tipControlTable.TooltipFrame:SetSizeY(tipControlTable.ContentStack:GetSizeY());
	tipControlTable.TooltipFrame:SetSizeX(tipControlTable.TooltipHeader:GetSizeX()+100);
end

local m_relationships : table = {};
for relationship in GameInfo.RelationshipLevels() do
	table.insert(m_relationships, relationship);
end
table.sort(m_relationships, function(a, b) 
	return a.UIOrder < b.UIOrder;
end);

function UpdateRelationshipOptions()
	local currentRelationship : number = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
	local relationships : table = {};
	Controls.RelationshipChoicesStack:SetHide(false);

	m_relationshipChoiceInstanceManager:ResetInstances();
	
	for i : number, relationship : table in ipairs(m_relationships) do
		local instance : table = m_relationshipChoiceInstanceManager:GetInstance();
		local cost : number = Game.GetRelationshipChangeCost(m_player:GetID(), m_selectedPlayer:GetID(), relationship.ID);
		local canAfford : boolean = cost <= m_player:GetDiplomaticCapital();
		local canChange : boolean = Game.CanChangeRelationshipLevel(m_player:GetID(), m_selectedPlayer:GetID(), relationship.ID);
		local tooLowForTeam : boolean = m_player:GetTeam() == m_selectedPlayer:GetTeam() and relationship.ID < RelationshipLevels.RELATIONSHIP_NEUTRAL
		local isDowngrade : boolean = relationship.ID < currentRelationship;
		local areInPeaceTreaty : boolean  = Game.ArePlayersInPeaceTreaty(m_player:GetID(), m_selectedPlayer:GetID());

		instance.FearRespectRequirements:SetHide(true);
		local blockedTooltipString : string = "";
		if (not m_selectedPlayer:IsHuman() and not isDowngrade) then
			local currentFearStageType : number = m_selectedPlayer:GetFearStage(m_player:GetID());
			local currentRespectStageType : number = m_selectedPlayer:GetRespectStage(m_player:GetID());
			local reqFearStageType : number = m_selectedPlayer:GetRelationshipMinFearStage(relationship.ID);
			local reqRespectStageType : number = m_selectedPlayer:GetRelationshipMinRespectStage(relationship.ID);
			local fearStageVal : number = GameInfo.Stages[currentFearStageType].UIOrder;
			local respectStageVal : number = GameInfo.Stages[currentRespectStageType].UIOrder;
			local reqFearStageVal : number = GameInfo.Stages[reqFearStageType].UIOrder;
			local reqRespectStageVal : number = GameInfo.Stages[reqRespectStageType].UIOrder;

			instance.FearRespectRequirements:SetHide(false);

			instance.FearRequirement:SetText("[ICON_FEAR]"..GameInfo.Stages[reqFearStageType].UIOrder);
			instance.RespectRequirement:SetText("[ICON_RESPECT]"..GameInfo.Stages[reqRespectStageType].UIOrder);

			local reqImageOffsetY : number = 0;
			local offsetIncrementY : number = 67;
			local tooltipString : string = "";
			local isBlockekd : boolean = false;
			if (respectStageVal >= reqRespectStageVal and fearStageVal < reqFearStageVal) then
				reqImageOffsetY = 1*offsetIncrementY;
			elseif (respectStageVal < reqRespectStageVal and fearStageVal >= reqFearStageVal) then
				reqImageOffsetY = 2*offsetIncrementY;
			elseif (respectStageVal < reqRespectStageVal and fearStageVal < reqFearStageVal) then
				reqImageOffsetY = 3*offsetIncrementY;
				blockedTooltipString = blockedTooltipString .. Locale.Lookup("TXT_KEY_DIPLO_BLOCKEDSERVICEREQ_TT");
				isBlocked = true;
			end

--			instance.FearRespectRequirements:SetTextureOffsetVal(0,reqImageOffsetY);
			instance.FearRespectRequirements:SetToolTipCallback(function(control)
				OnFearRespectTooltip(respectStageVal,reqRespectStageVal,fearStageVal,reqFearStageVal,reqImageOffsetY);
			end)
		end

		instance.Cost:SetText(cost);
		instance.CostStack:CalculateSize();
		instance.CostStack:ReprocessAnchoring();
		local containerSizeX : number = 58;
		if (instance.CostStack:GetSizeX()+22>58) then
			containerSizeX = instance.CostStack:GetSizeX()+22;
		end
		instance.CostContainer:SetSizeX(containerSizeX);

		local toolTipStr : string = "";
		if (not canAfford or not canChange or tooLowForTeam) then
			if (relationship.ID == RelationshipLevels.RELATIONSHIP_WAR and areInPeaceTreaty) then
				local team : object = Teams[m_player:GetTeam()];
				local turnMadePeace : number = team:GetTurnMadePeaceWithTeam(m_selectedPlayer:GetTeam());
				local turnsLeftInTreaty = GameDefines.PEACE_TREATY_LENGTH - (Game.GetGameTurn() - turnMadePeace);
				toolTipStr = toolTipStr .. "[COLOR_RED]" .. Locale.ConvertTextKey("TXT_KEY_DIPLOMACYUI_IN_PEACE_TREATY", turnsLeftInTreaty) .. "[ENDCOLOR][NEWLINE][NEWLINE]";
			elseif (not canAfford) then
				toolTipStr = toolTipStr .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_NOT_ENOUGH_CAPITAL") .. "[ENDCOLOR][NEWLINE][NEWLINE]";
			elseif (tooLowForTeam) then
				toolTipStr = toolTipStr .. "[COLOR_RED]" .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_CANT_LOWER_RELATIONSHIP_BECAUSE_TEAM") .. "[ENDCOLOR][NEWLINE][NEWLINE]";
			elseif (not canChange) then
				toolTipStr = toolTipStr .."[COLOR_RED]" ..  Locale.Lookup("TXT_KEY_DIPLOMACYUI_DOESNT_MEET_FEAR_RESPECT_REQS") .. "[ENDCOLOR][NEWLINE][NEWLINE]";
			end
		end

		toolTipStr = toolTipStr .. Locale.Lookup(relationship.Help);

		instance.Button:SetToolTipString(toolTipStr);

		if (canAfford) then
			instance.Cost:SetColor(0xffd1362e,0);
			instance.Cost:SetColor(0x77d1362e,1);
			instance.Cost:SetColor(0xfffa8b50,2);
			if (not tooLowForTeam) then
				--instance.Button:SetToolTipString(nil);
			end
		else
			instance.Cost:SetColor(0xff000066,0);
			instance.Cost:SetColor(0x550000ff,1);
			instance.Cost:SetColor(0xff0000ff,2);
		end

		-- Set and Color Button text
		instance.Button:SetHide(relationship.ID == currentRelationship);
		local disabledColor = "";
		if(not canAfford or not canChange) then
			instance.Button:SetDisabled(true);
			disabledColor = "[COLOR_HeaderGradientDisabled]";
		else
			instance.Button:SetDisabled(false);
		end

		instance.Button:SetText(disabledColor..Locale.Lookup("TXT_KEY_DIPLO_"..relationship.Type));	
		local buttonLabel = instance.Button:GetTextControl();
		buttonLabel:SetWrapWidth(instance.Button:GetSizeX()-120);

		local temp : number = relationship.ID; -- for lambda capture
		-- Register button callbacks
		instance.Button:RegisterCallback(Mouse.eLClick, function() 
			HideRelationshipFlyout();

			DoAreYouSure(temp);
			Events.LeaderSetVisible();
		end);
		instance.Button:RegisterCallback(Mouse.eMouseEnter, function() 
			if(canAfford and canChange) then
				if(temp > currentRelationship) then
					for j=currentRelationship+1,temp,1 do
						m_relationshipLevelInstances[j].ArrowRight:SetToBeginning();
						m_relationshipLevelInstances[j].ArrowRight:Play();
						m_relationshipLevelInstances[j].ArrowRightImage:SetColor(m_relationshipLevelColors[temp+1]);
						m_relationshipLevelInstances[j].ArrowRight:SetHide(false);
					end
				else
					for j=temp+2,currentRelationship+1,1 do
						m_relationshipLevelInstances[j].ArrowLeft:SetToBeginning();
						m_relationshipLevelInstances[j].ArrowLeft:Play();
						m_relationshipLevelInstances[j].ArrowLeftImage:SetColor(m_relationshipLevelColors[temp+1]);
						m_relationshipLevelInstances[j].ArrowLeft:SetHide(false);
					end
				end
				ShowRelationshipFlyout(temp);
			end
		end);
		instance.Button:RegisterCallback(Mouse.eMouseExit, function() 
			if (m_holdArrowFlyout) then
				return;
			end

			if(canAfford and canChange and not m_relationshipUpdated) then
				for j=1,5,1 do
					m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
					m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
				end
				HideRelationshipFlyout();
			else
				m_relationshipUpdated = false;
			end
		end);
	end
	Controls.RelationshipChoicesStack:CalculateSize();
	Controls.RelationshipChoicesStack:ReprocessAnchoring();
	Controls.MySpeechBubbleStack:CalculateSize();
	Controls.MySpeechBubbleStack:ReprocessAnchoring();
end


function DoResolveRelationshipTransaction(transaction : object)
	local relationshipInfo = GameInfo.RelationshipLevels[transaction:GetRelationshipLevel()];
	local currentRelationship : number = Game.GetRelationship(m_player:GetID(), transaction:GetSendingPlayer());

	SayLine("LINE_DIPLO_RELATIONSHIP_PROPOSE_CHANGE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse, relationshipInfo.Description);

	Controls.RelationshipChoicesStack:SetHide(true);
	Controls.MySpeechBubbleStack:CalculateSize();
	Controls.MySpeechBubbleStack:ReprocessAnchoring();
	
	Controls.AcceptButton:SetHide(false);
	Controls.RejectButton:SetHide(false);
	Controls.CancelButton:SetHide(true);

	--[[
	local proposedRelationship : number = transaction:GetRelationshipLevel();
	if(proposedRelationship > currentRelationship) then
		for j=currentRelationship+1,proposedRelationship,1 do
			m_relationshipLevelInstances[j].ArrowRight:SetToBeginning();
			m_relationshipLevelInstances[j].ArrowRight:Play();
			m_relationshipLevelInstances[j].ArrowRightImage:SetColor(m_relationshipLevelColors[proposedRelationship+1]);
			m_relationshipLevelInstances[j].ArrowRight:SetHide(false);
		end
	else
		for j=proposedRelationship+2,currentRelationship+1,1 do
			m_relationshipLevelInstances[j].ArrowLeft:SetToBeginning();
			m_relationshipLevelInstances[j].ArrowLeft:Play();
			m_relationshipLevelInstances[j].ArrowLeftImage:SetColor(m_relationshipLevelColors[proposedRelationship+1]);
			m_relationshipLevelInstances[j].ArrowLeft:SetHide(false);
		end
	end
	ShowRelationshipFlyout(proposedRelationship);]]

	Controls.AcceptButton:RegisterCallback(Mouse.eLClick, function() 
		local didAccept : boolean = true;	
		Network.SendResolveTransaction(transaction:GetID(), didAccept);
		Controls.RelationshipChoicesStack:SetHide(false);
		Controls.AcceptButton:SetHide(true);
		Controls.RejectButton:SetHide(true);
		HideRelationshipFlyout();
	end);

	Controls.RejectButton:RegisterCallback(Mouse.eLClick, function() 
		local didAccept : boolean = false;	
		Network.SendResolveTransaction(transaction:GetID(), didAccept);
		Controls.RelationshipChoicesStack:SetHide(false);
		Controls.AcceptButton:SetHide(true);
		Controls.RejectButton:SetHide(true);
		for j=1,5,1 do
			m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
			m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
		end
		HideRelationshipFlyout();
	end);

	UpdateRelationshipMeter();
	UpdateConversationControlSizes();

	local currentRelationship : number = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
	local relationship = relationshipInfo.ID;
	if(relationship > currentRelationship) then
		for j=currentRelationship+1,relationship,1 do
			m_relationshipLevelInstances[j].ArrowRight:SetToBeginning();
			m_relationshipLevelInstances[j].ArrowRight:Play();
			m_relationshipLevelInstances[j].ArrowRightImage:SetColor(m_relationshipLevelColors[relationship+1]);
			m_relationshipLevelInstances[j].ArrowRight:SetHide(false);
		end
	else
		for j=relationship+2,currentRelationship+1,1 do
			m_relationshipLevelInstances[j].ArrowLeft:SetToBeginning();
			m_relationshipLevelInstances[j].ArrowLeft:Play();
			m_relationshipLevelInstances[j].ArrowLeftImage:SetColor(m_relationshipLevelColors[relationship+1]);
			m_relationshipLevelInstances[j].ArrowLeft:SetHide(false);
		end
	end
	ShowRelationshipFlyout(relationship);
end

function ShowRelationshipFlyout(relationshipLevel : number)
	for i : number, instance : table in ipairs(m_relationshipLevelInstances) do
		if(instance.RelationshipLevel ~= relationshipLevel) then
			instance.Flyout:SetHide(true);
		else
			if(relationshipLevel == 4) then
				instance.FlyoutText:SetAnchor("R,C");
				instance.FlyoutText:SetOffsetX(-80);
			end
			instance.FlyoutAlpha:SetToBeginning();
			instance.FlyoutAlpha:Play();
			instance.FlyoutSlide:SetToBeginning();
			instance.FlyoutSlide:Play();
			instance.Flyout:SetHide(false);
		end
	end
end

function HideRelationshipFlyout()
	for i : number, instance : table in ipairs(m_relationshipLevelInstances) do
		instance.Flyout:SetHide(true);
	end
end

function UpdateRelationshipMeter()
	local currentRelationship : number = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
	local currentRelationshipInfo : table = GameInfo.RelationshipLevels[currentRelationship];

	Controls.Relationship:SetText(Locale.Lookup("TXT_KEY_DIPLO_CURRENTRELATIONSHIP").. ": [COLOR_".. currentRelationshipInfo.Type.. "]" .. Locale.Lookup("{"..currentRelationshipInfo.Description..":upper}"));

	for i : number, instance : table in ipairs(m_relationshipLevelInstances) do
		instance.Highlight:SetHide(currentRelationship ~= instance.RelationshipLevel);
	end
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function ShowHideHandler(isHide : boolean)
	if (not isHide) then
		if (Game.GetNumPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID()) > 0) then
			local pendingTransactions : table = Game.GetPendingTransactions(m_player:GetID(), m_selectedPlayer:GetID());
			for i : number, transaction : object in ipairs(pendingTransactions) do
				if (transaction:GetRelationshipLevel() ~= -1) then
					DoChangeAlreadyPending();
					return;
				end
			end
		end
		
		if (Game.GetNumPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID()) > 0) then
			local transactions : table = Game.GetPendingTransactions(m_selectedPlayer:GetID(), m_player:GetID());
			for i : number, transaction : object in ipairs(transactions) do
				if (transaction:GetRelationshipLevel() ~= -1) then
					DoResolveRelationshipTransaction(transaction);
					return;
				end
			end

			DoDiscussRelationship();
		else
			DoDiscussRelationship();
		end

		ShowDiploTutorial("DIPLOMACY_RELATIONSHIP", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_RELATIONSHIP"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_RELATIONSHIP");

		UpdateCurrentRelationship();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function OnInitialize(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];

	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	LuaEvents.DiplomacyUI_ResetAnimations.Add(ResetAnimations);
	Events.DiplomacyRelationshipChanged.Add(OnDiplomacyRelationshipChanged);
	Events.TransactionResolved.Add(OnTransactionResolved);

	Controls.CancelButton:RegisterCallback(Mouse.eLClick, function() 
		PopDiplomacyUIState();
	end);

	-- Init relationship meter
	for relationshipLevel in GameInfo.RelationshipLevels() do
		local instance = {};
		ContextPtr:BuildInstanceForControl("RelationshipLevel", instance, Controls.RelationshipMeterStack);
		instance.RelationshipLevel = relationshipLevel.ID;
		instance.Pip:SetTextureOffsetVal(0,30*relationshipLevel.ID);
		instance.FlyoutText:SetText(Locale.Lookup("TXT_KEY_DIPLO_PROPOSING").. ":  [COLOR_".. relationshipLevel.Type.. "]" .. Locale.Lookup("{"..relationshipLevel.Description..":upper}"));
		instance.Flyout:SetHide(true);
		instance.Flyout:SetSizeX(instance.FlyoutText:GetSizeX() + 10);
		table.insert(m_relationshipLevelInstances, instance);
	end

	Controls.RelationshipMeterStack:CalculateSize();
	Controls.RelationshipMeterStack:ReprocessAnchoring();

	ContextPtr:SetHide(true);

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
	Controls.ChoicesStack:CalculateSize();
	Controls.ChoicesStack:ReprocessAnchoring();
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
	LuaEvents.DiplomacyUI_ResetAnimations.Remove(ResetAnimations);
	Events.DiplomacyRelationshipChanged.Remove(OnDiplomacyRelationshipChanged);
	Events.TransactionResolved.Remove(OnTransactionResolved);
end
ContextPtr:SetShutdown(OnShutdown);

-------------------------------------------------
-- Event Handlers
-------------------------------------------------
function ResetAnimations()
	Controls.MyBubbleAlphaAnim:SetToBeginning();
	Controls.MyBubbleAlphaAnim:Play();
	Controls.MyBubbleSlideAnim:SetToBeginning();
	Controls.MyBubbleSlideAnim:Play();
	HideRelationshipFlyout();
	for j=1,5,1 do
		m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
		m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
	end
end

function OnStateChanged(state : number, selectedPlayer : number)
	if (state == g_diplomacyUIStates.RELATIONSHIP) then
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

function OnDiplomacyRelationshipChanged(playerAType : number, playerBType : number, relationship : number, previousRelationship : number)
	if (m_shown) then
		m_relationshipUpdated = true;
		UpdateRelationshipOptions();
		UpdateRelationshipMeter();
	end
end

function OnTransactionResolved(id : number)
	if (not m_shown) then
		return;
	end

	local transaction : object = Game.GetTransaction(id);
	
	if (transaction:GetRelationshipLevel() ~= -1) then
		local previousRelationship : number = Game.GetPreviousRelationship(m_player:GetID(), m_selectedPlayer:GetID());
		local currentRelationship : number = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());
		local isImprovement : boolean = currentRelationship > previousRelationship;
		
		if (transaction:GetSendingPlayer() == m_player:GetID() and transaction:GetReceivingPlayer() == m_selectedPlayer:GetID()) then
			-- If they are responding to our request
			if (transaction:WasAccepted()) then
				if (currentRelationship == RelationshipLevels.RELATIONSHIP_WAR) then
					SayLine("LINE_DIPLO_RELATIONSHIP_ACCEPT_VERY_NEGATIVE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);			
				else
					if (isImprovement) then
						SayLine("LINE_DIPLO_RELATIONSHIP_ACCEPT_POSITIVE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
					else
						SayLine("LINE_DIPLO_RELATIONSHIP_ACCEPT_NEGATIVE", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
					end
				end 
			else
				SayLine("LINE_DIPLO_RELATIONSHIP_REJECT", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
				-- WRM: TODO: Added reject angry line to this
			end
		elseif (transaction:GetSendingPlayer() == m_selectedPlayer:GetID() and transaction:GetReceivingPlayer() == m_player:GetID()) then
			-- If we are responding to their request
			if (transaction:WasAccepted()) then
				SayLine("LINE_DIPLO_RELATIONSHIP_HAPPY_YOU_ACCEPTED", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
			else
				SayLine("LINE_DIPLO_RELATIONSHIP_SAD_YOU_REJECTED", m_selectedPlayer:GetID(), m_player:GetID(), Controls.TheirResponse);
			end
		end

		local currentRelationship = Game.GetRelationship(m_player:GetID(), m_selectedPlayer:GetID());

		Controls.RelationshipChoicesStack:SetHide(true);

		Controls.AcceptButton:SetText(Locale.Lookup("TXT_KEY_DIPLO_ACCEPT"));

		Controls.AcceptButton:SetHide(false);
		Controls.RejectButton:SetHide(true);
		Controls.CancelButton:SetHide(true);

		Controls.ChoicesStack:CalculateSize();
		Controls.ChoicesStack:ReprocessAnchoring();

		Controls.AcceptButton:RegisterCallback(Mouse.eLClick, function() 
			Controls.RelationshipChoicesStack:SetHide(false);
			for j=1,5,1 do
				m_relationshipLevelInstances[j].ArrowLeft:SetHide(true);
				m_relationshipLevelInstances[j].ArrowRight:SetHide(true);
			end
			DoNextPendingTransaction();
		end);

		UpdateRelationshipMeter();
		UpdateConversationControlSizes();
	end
end
