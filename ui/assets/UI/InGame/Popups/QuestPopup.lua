-- ===========================================================================
--	QuestPopup
--	Select which quest option.
-- ===========================================================================

include( "SupportFunctions"  );


local m_PopupInfo			= nil;
local m_acceptHandler		= nil
local m_Shown				= false;
local m_xmlPopupFrameSizeY	= 0;		-- set on init


-- ===========================================================================
function Initialize()
	m_xmlPopupFrameSizeY = Controls.PopupFrame:GetSizeY();
end

-- ===========================================================================
function OnPopup(popupInfo)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_QUEST_PROMPT) then
		return;
	end

	m_PopupInfo = popupInfo;

	local isShowRequest = true;

	-- Toggle?
	if ( popupInfo.Data1 == 1 ) and ( ContextPtr:IsHidden() == false ) then
		isShowRequest = false;		
	end

	if isShowRequest then
		-- SHOW
		if (not m_Shown) then
			LuaEvents.SubDiploPanelOpen( self );
			ShowWindow();
		end
	else
		-- HIDE
		if (m_Shown) then
			HideWindow();
		end
	end
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
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
	m_Shown = false;
	print("QuestPopup, Blur Off");
	Events.BlurStateChange(1);
	Controls.Image:UnloadTexture();
	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, HideWindow);

-- ===========================================================================
function ShowWindow()

	m_Shown = true;
	
	m_acceptHandler = nil;

	-- Clears out any in-progress UI state (like range attack/bombard)
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	UI.ClearSelectedCities();
	
	Events.BlurStateChange(0);
	print("QuestPopup, Blur On");
	
	if (Controls.AlphaAnim:IsReversing()) then
		Controls.AlphaAnim:Reverse();
	end

	Controls.AlphaAnim:SetToBeginning();
	Controls.AlphaAnim:Play();

	ResetWindow();
	UpdateWindow();
	ResizeWindow();
	UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
end

-- ===========================================================================
function ShowHideHandler(isHide)
	if (not isHide) then
		if ( m_Shown == false ) then
			Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			UpdateWindow();
		end
	else
		if ( m_Shown == true ) then
			HideWindow();
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

-- ===========================================================================
function ResetWindow()
	local i = 1;
	local radioOption = nil
	repeat
		radioOption = Controls["RadioOption" .. i];
		if (radioOption ~= nil) then
			radioOption:SetCheck(false);
			radioOption:SetHide(true);
		end
		i = i + 1;
	until radioOption == nil;

	Controls.AcceptButton:SetDisabled(true);
	ResizeWindow();
end

-- ===========================================================================
function UpdateWindow()
	if (m_PopupInfo == nil) then
		return;
	end

	local playerType = m_PopupInfo.Data1;
	local questIndex = m_PopupInfo.Data2;
	local objectiveIndex = m_PopupInfo.Data3;

	local player = Players[playerType];
	local quest = player:GetQuestWithIndex(questIndex);
	local objective = quest:GetObjectiveWithIndex(objectiveIndex);
	local strTitle = objective:GetSummary();
		
	-- Prompt text
	local MAX_SIZE_TITLE = 650;
	TruncateStringWithTooltip(Controls.TitleText, MAX_SIZE_TITLE, Locale.ToUpper(strTitle) );

	--Controls.TitleText:SetText(Locale.ToUpper(strTitle));
	Controls.BodyText:LocalizeAndSetText(objective:GetPrompt());
		
	-- Image
	local bannerImagePath = objective:GetPromptImagePath();
	if (bannerImagePath ~= nil and bannerImagePath ~= "") then
		Controls.Image:SetTexture(bannerImagePath);
	else
		Controls.Image:SetTexture("QuestPromptDefault.dds");
	end
		
	-- Choice A
	local optionA = objective:GetPromptOptionA();
	if (optionA ~= nil and optionA ~= "") then
		local choice = 1;
		local handler =  function() 
			m_acceptHandler = function ()
				Network.SendQuestAction(playerType, questIndex, objectiveIndex, choice);
				HideWindow();
			end
			Controls.AcceptButton:SetDisabled( false );
		end
		local choiceButton = AddChoiceButton(optionA, handler);
		if choiceButton ~= nil then
			-- option tooltip string
			local tooltipA = objective:GetPromptTooltipA();
			if tooltipA ~= nil then
				choiceButton:SetToolTipString(tooltipA);
			end
		end
	end

	-- Choice B
	local optionB = objective:GetPromptOptionB();
	if (optionB ~= nil and optionB ~= "") then
		local choice = 2;
		local handler = function() 
			m_acceptHandler = function ()
				Network.SendQuestAction(playerType, questIndex, objectiveIndex, choice);
				HideWindow();
			end
			Controls.AcceptButton:SetDisabled( false );
		end
		local choiceButton = AddChoiceButton(optionB, handler);
		if choiceButton ~= nil then
			-- option tooltip string
			local tooltipB = objective:GetPromptTooltipB();
			if tooltipB ~= nil then
				choiceButton:SetToolTipString(tooltipB);
			end
		end
	end

	-- Choice C
	local optionC = objective:GetPromptOptionC();
	if (optionC ~= nil and optionC ~= "") then
		local choice = 3;
		local handler =  function() 
			m_acceptHandler = function ()
				Network.SendQuestAction(playerType, questIndex, objectiveIndex, choice);
				HideWindow();
			end
			Controls.AcceptButton:SetDisabled( false );
		end
		local choiceButton = AddChoiceButton(optionC, handler);
		if choiceButton ~= nil then
			-- option tooltip string
			local tooltipC = objective:GetPromptTooltipC();
			if tooltipC ~= nil then
				choiceButton:SetToolTipString(tooltipC);
			end
		end
	end

end

-- ===========================================================================
function ResizeWindow()

	local imageSize = Controls.Image:GetSizeY();
	local textSize	= Controls.BodyText:GetSizeY();
	local max		= math.max( imageSize, textSize );

	Controls.BodyContainer:SetSizeY( max );

	Controls.ChoicesStack:CalculateSize();
	Controls.ChoicesStack:ReprocessAnchoring();
	
	Controls.StoryStack:CalculateSize();
	Controls.StoryStack:ReprocessAnchoring();
	
	local PADDING	= 80;
	local totalY	= Controls.StoryStack:GetSizeY() + Controls.StoryStack:GetOffsetY() + PADDING;
	if ( totalY > Controls.PopupFrame:GetSizeY() ) then
		Controls.PopupFrame:SetSizeY( totalY );
	else
		Controls.PopupFrame:SetSizeY( m_xmlPopupFrameSizeY );
	end
end

-- ===========================================================================
--	Find next available button and add the choice.
-- ===========================================================================
function AddChoiceButton(buttonText, choiceHandler)
	local i = 1;
	repeat
		local radioOption = Controls["RadioOption" .. i];
		if radioOption and radioOption:IsHidden() then
			local button = radioOption:GetTextButton();
			button:SetText( Locale.ConvertTextKey(buttonText) );
			radioOption:RegisterCheckHandler( choiceHandler );
			radioOption:SetHide(false);
			return radioOption;
		end
		i = i + 1;
	until radioOption == nil;
	print("ERROR: Ran out of buttons at #" ..tostring(i-1).." when populating quest choices.  For choice:",buttonText);
end


-- ===========================================================================
function OnAcceptButton()
	if ( m_acceptHandler == nil ) then
		print("ERROR: Attempt to accept an option but no handler is setup!");
		return;
	end
	m_acceptHandler();
end
Controls.AcceptButton:RegisterCallback(Mouse.eLClick, OnAcceptButton);

Initialize();