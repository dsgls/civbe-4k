-- ===========================================================================
-- QuestPopup
-- ===========================================================================
local m_PopupInfo = nil;
local m_NextPopupInfo = nil;

local m_PopupShown = false;

-- ===========================================================================
-- Constants
-- ===========================================================================
local newQuestRecievedTitleTextKey : string = "TXT_KEY_QUEST_OBJECTIVE_RECEIVED_FIRST_POPUP_TITLE";
local newQuestObjectiveRecievedTitleTextKey : string = "TXT_KEY_QUEST_OBJECTIVE_RECEIVED_OTHER_POPUP_TITLE";

local marvelQuestBannerImage : string = "Popup_Image_Marvel.dds";

local dominationVictoryHarmonyBannerImage : string = "";
local dominationVictoryPurityBannerImage : string = "";
local dominationVictorySupremacyBannerImage : string = "";

local contactVictoryBannerImage : string = "GameOverBannerContact.dds";
local promisedLandVictoryBannerImage : string = "GameOverBannerPurity.dds";
local emancipationVictoryBannerImage : string = "GameOverBannerSupremacy.dds";
local transcendenceVictoryBannerImage : string = "GameOverBannerHarmony.dds";

local transcendenceVictoryType : number = GameInfo.Quests["QUEST_VICTORY_TRANSCENDENCE"].ID;

-- ===========================================================================
--	Functions
-- ===========================================================================


-- ===========================================================================
function OnPopup(popupInfo)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_QUEST_OBJECTIVE_RECEIVED) then
		return;
	end

	if (OptionsManager.IsNoRewardPopups()) then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(popupInfo.Type, 0);
		return;
	end

	-- Don't show the quest complete dialog for the first objective of victory quests
	local playerType = popupInfo.Data1;
	local questIndex = popupInfo.Data2;
	local quest = Players[playerType]:GetQuestWithIndex(questIndex);
	local objectives = quest:GetObjectives();

	if(quest:GetType() == transcendenceVictoryType) then
		
		-- this popup does not support non-deterministic quests (quests in which the objectives can be completed in any order)
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(popupInfo.Type, 0);
		return;
	end

	if(	GameInfo.Quests[quest:GetType()].Victory and
		#objectives == 1)
	then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(popupInfo.Type, 0);
		return;
	end

	if(	GameInfo.Quests[quest:GetType()].Marvel and
		#objectives == 1)
	then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(popupInfo.Type, 0);
		return;
	end

	-- queue up additional popups
	if (m_PopupInfo ~= nil) then
		if (m_NextPopupInfo == nil) then
			m_NextPopupInfo = {};
		end

		table.insert( m_NextPopupInfo, popupInfo );

		return;
	end

	m_PopupInfo = popupInfo;

	--ShowWindow();
	UIManager:QueuePopup( ContextPtr, PopupPriority.InGameUtmost );
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

function ShowHideHandler(isHide : boolean, isInit : boolean)
	if (isInit) then
		return;
	end

	if (not isHide) then
		if( not m_PopupShown ) then
			m_PopupShown = true;
			Events.BlurStateChange(0);
			print("QuestObjectiveReceivedPopup, Blur On");
			ShowWindow();
		end
	else
		if( m_PopupShown ) then

			m_PopupShown = false;

			Events.BlurStateChange(1);
			print("QuestObjectiveReceivedPopup, Blur Off");

			if (m_PopupInfo ~= nil) then
				Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
			end
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

-- ===========================================================================
-- 'Active' (local human) player has changed
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		HideWindow();
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);


-- ===========================================================================
function InputHandler(msg, param1, param2)
	if (msg == KeyEvents.KeyDown) then
		if (param1 == Keys.VK_ESCAPE or param1 == Keys.VK_RETURN) then
			HideWindow();
			return true;
		end
	end
end
ContextPtr:SetInputHandler(InputHandler);


-- ===========================================================================
function HideWindow()
	if (m_PopupInfo ~= nil) then

		local playerType = m_PopupInfo.Data1;
		local questIndex = m_PopupInfo.Data2;
		local objectiveIndex = m_PopupInfo.Data3;
		local quest = Players[playerType]:GetQuestWithIndex(questIndex);
		local objectives = quest:GetObjectives();
		local newObjective = objectives[objectiveIndex];
		local objectiveType = newObjective:GetType();
		
		LuaEvents.QuestObjectiveAcknowledged(objectiveType);

		ContextPtr:SetHide(true);

		UIManager:DequeuePopup( ContextPtr );

		m_PopupInfo = nil;

		if( m_NextPopupInfo ~= nil ) then
			Events.SerialEventGameMessagePopup( table.remove( m_NextPopupInfo, 1) );

			if( #m_NextPopupInfo == 0 ) then
				m_NextPopupInfo = nil;
			end
		end
	end
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, HideWindow);		--??TRON remove, redundant
Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, HideWindow);


-- ===========================================================================
function ShowWindow()
	local playerType = m_PopupInfo.Data1;
	local questIndex = m_PopupInfo.Data2;
	local objectiveIndex = m_PopupInfo.Data3;

	local player = Players[playerType];
	local quest = player:GetQuestWithIndex(questIndex);
	local objectives = quest:GetObjectives();
	local newObjective = objectives[objectiveIndex];
	local questInfo = GameInfo.Quests[quest:GetType()];

	local previousObjective = nil;
	if(#objectives > 1) then
		previousObjective = objectives[objectiveIndex - 1];
	end

	Controls.AlphaAnim:SetToBeginning();
	Controls.AlphaAnim:Play();
	
	-- banner art
	local image : string = "Popup_Image_Quest.dds";
	if(questInfo.Marvel) then
		image = marvelQuestBannerImage;
	elseif(questInfo.Victory) then
		if(questInfo.VictoryType == "VICTORY_DOMINATION") then
			-- This case should never actually be true (since the Domination victory only has one quest objective), but it's supported here nonetheless.
			local dominantAffinityType : number = player:GetDominantAffinityType();
			if(dominantAffinityType == -1) then
				image = dominationVictoryHarmonyBannerImage;
			elseif(dominantAffinityType == GameInfo.Affinities["AFFINITY_HARMONY"].ID)then
				image = dominationVictoryHarmonyBannerImage;
			elseif(dominantAffinityType == GameInfo.Affinities["AFFINITY_PURITY"].ID)then
				image = dominationVictoryPurityBannerImage;
			elseif(dominantAffinityType == GameInfo.Affinities["AFFINITY_SUPREMACY"].ID)then
				image = dominationVictorySupremacyBannerImage;
			end
		elseif(questInfo.VictoryType == "VICTORY_CONTACT") then
			image = contactVictoryBannerImage;
		elseif(questInfo.VictoryType == "VICTORY_PROMISED_LAND") then
			image = promisedLandVictoryBannerImage;
		elseif(questInfo.VictoryType == "VICTORY_EMANCIPATION") then
			image = emancipationVictoryBannerImage;
		elseif(questInfo.VictoryType == "VICTORY_TRANSCENDENCE") then
			image = transcendenceVictoryBannerImage;
		end
	end

	if(image ~= nil) then
		Controls.Banner:SetTexture(image);
	end

	-- quest name
	local name : string = "";
	local nameOverride : string = quest:GetNameOverride();
	if nameOverride ~= nil then
		name = nameOverride;
	else
		name = Locale.Lookup(GameInfo.Quests[quest:GetType()].Description);
	end

	Controls.QuestName:SetText(Locale.ToUpper(name));
	
	-- summary text
	local newQuestReceived : boolean = false;
	local titleText : string;
	if(#objectives == 1) then
		summaryText = quest:GetPrologue();
		newQuestReceived = true;
	else
		summaryText = previousObjective:GetEpilogue()
	end

	Controls.EpilogueText:LocalizeAndSetText(summaryText);

	-- set different text if this is the first objective in a quest, vs. later objectives
	if(newQuestReceived) then
		Controls.TitleText:LocalizeAndSetText(newQuestRecievedTitleTextKey);
	else
		Controls.TitleText:LocalizeAndSetText(newQuestObjectiveRecievedTitleTextKey);
	end

	Controls.ObjectiveStack:DestroyAllChildren(); 
	if (newObjective) then
		local objectiveInstance = {};		
		ContextPtr:BuildInstanceForControl("ObjectiveInstance", objectiveInstance, Controls.ObjectiveStack);
		objectiveInstance.Objective:SetText(Locale.ConvertTextKey(newObjective:GetSummary()));

		if(newObjective:AreSuccessConditionsMet())then
			objectiveInstance.ActiveCheckBox:SetTextureOffsetVal(0, 32);	-- 2nd texture in strip is checked
		end
	end

	Controls.EpilogueStack:CalculateSize();
	Controls.EpilogueScrollPanel:CalculateInternalSize();
	Controls.ObjectiveStack:CalculateSize(); 
	Controls.ObjectiveStack:ReprocessAnchoring(); 
	Controls.TextStack:CalculateSize();
	Controls.TextStack:ReprocessAnchoring();

	local textHeight = Controls.TextStack:GetSizeY() + Controls.ObjectiveStack:GetSizeY();

	Controls.Popup:SetSizeY(textHeight + 250);

	Controls.Popup:ReprocessAnchoring();

	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
end