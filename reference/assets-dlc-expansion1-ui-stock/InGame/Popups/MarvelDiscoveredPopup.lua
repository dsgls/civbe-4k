-- ===========================================================================
-- QuestPopup
-- ===========================================================================
local m_PopupInfo = nil;



-- ===========================================================================
--	Functions
-- ===========================================================================


-- ===========================================================================
function OnPopup(popupInfo)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_MARVEL_DISCOVERED) then
		return;
	end

	m_PopupInfo = popupInfo;

	-- Don't show the quest complete dialog for victories
	local playerType = m_PopupInfo.Data1;

	if (playerType ~= Game.GetActivePlayer()) then
		return;
	end
	
	local questIndex = m_PopupInfo.Data2;
	local quest = Players[playerType]:GetQuestWithIndex(questIndex);

	if (GameInfo.Quests[quest:GetType()].Victory) then
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
		Events.BlurStateChange(0);
		print("MarvelDiscoveredPopup, Blur On");
	else
		Events.BlurStateChange(1);
		print("MarvelDiscoveredPopup, Blur Off");
	end
end
--ContextPtr:SetShowHideHandler(ShowHideHandler);

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

	local titleText : string = "TXT_KEY_QUEST_MARVEL_DISCOVERED_POPUP_TITLE";
	Controls.TitleText:SetText(Locale.ConvertTextKey("{"..titleText..":upper}"));

	Controls.PrologueText:LocalizeAndSetText(quest:GetPrologue());

	Controls.ObjectiveStack:DestroyAllChildren(); 
	if (lastObjective) then
		local objectiveInstance = {};		
		ContextPtr:BuildInstanceForControl("ObjectiveInstance", objectiveInstance, Controls.ObjectiveStack);
		objectiveInstance.Objective:SetText(Locale.ConvertTextKey(lastObjective:GetSummary()));
	end

	Controls.PrologueStack:CalculateSize();
	Controls.PrologueScrollPanel:CalculateInternalSize();
	Controls.ObjectiveStack:CalculateSize(); 
	Controls.ObjectiveStack:ReprocessAnchoring(); 
	Controls.TextStack:CalculateSize();
	Controls.TextStack:ReprocessAnchoring();

	local textHeight = Controls.TextStack:GetSizeY() + Controls.ObjectiveStack:GetSizeY();

	local width : number, height : number = UIManager.GetScreenSizeVal();
	local maxHeight : number = 1162;
	local minHeight : number = 768;

	local ratio : number = (100 - 0) / (maxHeight - minHeight);
	local bufferDisanceY : number = (0 + ((height - minHeight) * ratio));

	local popupOffset : number = Controls.Popup:GetOffsetY();

	Controls.Popup:SetOffsetY(popupOffset + bufferDisanceY);


	Controls.Popup:SetSizeY(textHeight + 250);

	Controls.Popup:ReprocessAnchoring();

	UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
end