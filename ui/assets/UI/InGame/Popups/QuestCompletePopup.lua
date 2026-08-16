-- ===========================================================================
-- QuestPopup
-- ===========================================================================
local m_PopupInfo = nil;
local m_bShown = false;


-- ===========================================================================
--	Functions
-- ===========================================================================


-- ===========================================================================
function OnPopup(popupInfo)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_QUEST_COMPLETE) then
		return;
	end

	m_PopupInfo = popupInfo;

	-- Don't show the quest complete dialog for victories
	local playerType = m_PopupInfo.Data1;
	local questIndex = m_PopupInfo.Data2;
	local quest = Players[playerType]:GetQuestWithIndex(questIndex);
	if (GameInfo.Quests[quest:GetType()].Victory or OptionsManager.IsNoRewardPopups()) then
		return;
	end

	ShowWindow();
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

function ShowHideHandler(isHide : boolean, isInit : boolean)
	if (isInit) then
		return;
	end

	if (not isHide) then
		if (not m_bShown) then
			m_bShown = true;
			Events.BlurStateChange(0);
			print("QuestComplete, Blur On");
		end
	else
		if (m_bShown) then
			m_bShown = false;
			Events.BlurStateChange(1);
			print("QuestComplete, Blur Off");
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
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
	end

	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, HideWindow);		--??TRON remove, redundant
Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, HideWindow);


-- ===========================================================================
function ShowWindow()
	local playerType = m_PopupInfo.Data1;
	local questIndex = m_PopupInfo.Data2;
	local quest = Players[playerType]:GetQuestWithIndex(questIndex);
	local objectives = quest:GetObjectives();
	local lastObjective = objectives[#objectives];

	Controls.AlphaAnim:SetToBeginning();
	Controls.AlphaAnim:Play();
	
	local name : string = "";
	local nameOverride : string = quest:GetNameOverride();
	if nameOverride ~= nil then
		name = nameOverride;
	else
		name = Locale.Lookup(GameInfo.Quests[quest:GetType()].Description);
	end

	Controls.QuestName:SetText(Locale.ToUpper(name));
	Controls.EpilogueText:LocalizeAndSetText(lastObjective:GetEpilogue());
	Controls.RewardHeader:SetText(Locale.ConvertTextKey("TXT_KEY_QUEST_COMPLETE_POPUP_REWARD"));
	
	-- Rewards
	local rewardStrings = {quest:GetReward()};
	local noReward		= "$NO REWARD$";				-- defined in CvLuaQuest.cpp

    
	Controls.RewardsStack:DestroyAllChildren(); 

	if (quest:DidSucceed()) then					
		if (#rewardStrings > 0) and (not ( #rewardStrings == 1 and rewardStrings[1] == noReward )) then
			for i,reward in pairs(rewardStrings) do
				local rewardInstance = {};
				ContextPtr:BuildInstanceForControl("RewardInstance", rewardInstance, Controls.RewardsStack);
				rewardInstance.Reward:SetText( Locale.ConvertTextKey(reward) );
			end
		end
	end

	Controls.RewardsStack:CalculateSize(); 
	Controls.RewardsStack:ReprocessAnchoring(); 
	Controls.TextStack:CalculateSize();
	Controls.TextStack:ReprocessAnchoring();

	local textHeight = Controls.TextStack:GetSizeY() + Controls.RewardsStack:GetSizeY();
	Controls.Popup:SetSizeY(textHeight + 250);

	Controls.Popup:ReprocessAnchoring();

	UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);

	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
end