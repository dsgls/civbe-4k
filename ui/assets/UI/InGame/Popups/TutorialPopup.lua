-------------------------------------------------
-- QuestPopup
-------------------------------------------------
include("InstanceManager");

local m_PopupInfo = nil;
local m_TutorialInfo = nil;
local m_StepInfos = nil;
local m_CurrentStepInfo = nil;
local m_CurrentStepInfoIndex = 1;
local m_Shown = false;

local m_StepInstanceManager = InstanceManager:new("StepInstance", "Content", Controls.StepsStack);
local m_HighlightInstanceManager = InstanceManager:new("HighlightInstance", "Content", Controls.Highlights);

------------------------------------------------
-- Functions
------------------------------------------------
function OnPopup(popupInfo)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TUTORIAL) then
		return;
	end

	m_PopupInfo = popupInfo;
	m_TutorialInfo = GameInfo.Tutorials[m_PopupInfo.Data1];

	ResetSteps();

	ShowWindow();
	Events.SerialEventGameMessagePopupShown(m_PopupInfo);	
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

function InputHandler(msg, wParam, lParam)
	if (msg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN) then
			HideWindow();

			return true;
		end
	end
end
ContextPtr:SetInputHandler(InputHandler);

function ResetSteps()
	m_StepInfos = {};
	for stepInfo in GameInfo.Tutorial_Steps("TutorialType = \"" .. m_TutorialInfo.Type .. "\" ORDER BY StepNumber") do
		table.insert(m_StepInfos, stepInfo);
	end

	m_CurrentStepInfoIndex = 1;
	m_CurrentStepInfo = m_StepInfos[m_CurrentStepInfoIndex];
end

function HideWindow()
	if (m_PopupInfo ~= nil) then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
	end
	
	if (m_Shown == true) then
		m_Shown = false;
		Events.BlurStateChange(1);
		print("TutorialPopup, Blur Off");
	end

	m_PopupInfo = nil;
	m_TutorialInfo = nil;
	m_StepInfos = nil;
	m_CurrentStepInfo = nil;
	m_CurrentStepInfoIndex = 1;

	Controls.Image:UnloadTexture();

	UIManager:DequeuePopup(ContextPtr);

	if (m_TutorialInfo ~= nil) then
		UI.SetTutorialHasBeenSeen(m_TutorialInfo.Type, true);
	end
end
--Controls.CloseButton:RegisterCallback(Mouse.eLClick, HideWindow);

function ShowWindow()
	UpdateWindow();
	
	if (m_Shown == false) then
		m_Shown = true;
		Events.BlurStateChange(0);
		print("TutorialPopop, Blur On");
	end

	UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
end

function Proceed()
	m_CurrentStepInfoIndex = m_CurrentStepInfoIndex + 1;
	m_CurrentStepInfo = m_StepInfos[m_CurrentStepInfoIndex];

	if (m_CurrentStepInfo ~= nil) then
		UpdateWindow();
	else
		if (m_TutorialInfo.NextTutorial ~= nil) then
			m_TutorialInfo = GameInfo.Tutorials[m_TutorialInfo.NextTutorial];

			Controls.Image:UnloadTexture();
			
			ResetSteps();
			UpdateWindow();
		else
			HideWindow();
		end
	end
end
Controls.ProceedButton:RegisterCallback(Mouse.eLClick, Proceed);

function UpdateWindow()
	m_StepInstanceManager:ResetInstances();
	m_HighlightInstanceManager:ResetInstances();
	
	Controls.TitleLabel:LocalizeAndSetText(Locale.ConvertTextKey("{"..m_TutorialInfo.Description..":upper}"));

	if (m_CurrentStepInfo.Image ~= nil) then
		Controls.Image:UnloadTexture();
		Controls.Image:SetTexture(m_CurrentStepInfo.Image);
	end

	if (m_TutorialInfo.ProTip ~= nil) then
		Controls.ProTip:SetText(Locale.ConvertTextKey(m_TutorialInfo.ProTip));
		--scale the pro tip box to fit the text if it's larger than the default.
		if (Controls.ProTip:GetSizeY() > Controls.ProTipBox:GetSizeY()) then
			Controls.ProTipBox:SetSizeY(Controls.ProTip:GetSizeY() + 32);
		end
	else
		Controls.ProTip:SetText("");
	end

	--make sure the scroll panel doesn't overlap the pro tip box
	local scrollPanelHeight = Controls.StepsContainer:GetSizeY() - (  Controls.StepsScrollPanel:GetOffsetY() + Controls.ProTipBox:GetSizeY() )
	Controls.StepsScrollPanel:SetSizeY( scrollPanelHeight - 12);
	Controls.PanelBacking:SetSizeY( scrollPanelHeight + 20 )

	if (m_TutorialInfo ~= nil and m_StepInfos ~= nil) then
		-- Build the list of steps
		for i,stepInfo in ipairs(m_StepInfos) do
			if (i > m_CurrentStepInfoIndex) then
				break;
			end

			local instance = m_StepInstanceManager:GetInstance();

			instance.StepTextLabel:SetText(Locale.ConvertTextKey(stepInfo.Text));
			local newSize : number = instance.StepTextLabel:GetSizeY() + 30;
			if (newSize < 64) then
				newSize = 64;
			end
			instance.Content:SetSizeY(newSize);
			instance.StepNumberLabel:SetText(stepInfo.StepNumber);
		end

		-- Highlights
		for i,stepInfo in ipairs(m_StepInfos) do
			if (i > m_CurrentStepInfoIndex) then
				break;
			end

			local instance = m_HighlightInstanceManager:GetInstance();

			instance.StepNumberLabel:SetText(stepInfo.StepNumber);
			instance.Content:SetOffsetVal(stepInfo.CoordX, stepInfo.CoordY);
		end
	else
		error("Invalid tutorial data");
	end

	Controls.StepsStack:CalculateSize();
	Controls.StepsStack:ReprocessAnchoring();
	Controls.StepsScrollPanel:CalculateInternalSize();
	Controls.StepsScrollPanel:SetScrollValue(1);
end

