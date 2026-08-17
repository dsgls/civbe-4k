-- ===========================================================================
--	Advisor Pop-up
--
--	Somes special open/close logic is here as this can be opened from the
--	system and sometimes needs to be temporarly hidden if a player decides to 
--	looks at detailed information.
-- ===========================================================================


-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local bModal			= false;
local m_bIsOpen			= false;	-- Is it still considered open
local m_TutorialQueue	= {};		-- Queue of Advisor Messages!
local AdvisorConcept1	= "";
local AdvisorConcept2	= "";
local AdvisorConcept3	= "";

local advisorIconControls = {
	[0] = Controls.MilitaryRecommendation;
	[1] = Controls.EconomicRecommendation;
	[2] = Controls.ForeignRecommendation;
	[3] = Controls.ScienceRecommendation;
}

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function OnAdvisorButton( button )
    if( button == Mouse.eLClick ) then
        if(not  IsAdvisorDisplayOpen() ) then
    		-- this should be reconsidered        		
			local popupInfo = {
				Type = ButtonPopupTypes.BUTTONPOPUP_ADVISOR_COUNSEL,
			}
			Events.SerialEventGameMessagePopup(popupInfo);
    		
    	end
    else
		Events.AdvisorDisplayHide();
    end
end
LuaEvents.AdvisorButtonEvent.Add( OnAdvisorButton );


-- ===========================================================================
function AdvisorOpen()
	m_bIsOpen = true;

	-- If a player starts a game with advisors off, planetfalls, goes to options
	-- and turns advisors on, the advisor window will pop-up infront of the
	-- in game menu before the return.  For this one case... check to be sure
	-- the game menu isn't up before deciding if show/hiding...
	local uiGameMenu = ContextPtr:LookUpControl( "../GameMenu" );
	if ( uiGameMenu ~= nil ) then
		ContextPtr:SetHide( not uiGameMenu:IsHidden() );
	end	
end

-- ===========================================================================
-- Do not call this directly.  You should call Events.AdvisorDisplayHide() instead.
function AdvisorClose()

	m_bIsOpen = false;

	--[[
	if(m_TutorialQueue[1] ~= nil and Controls.DontShowAgainCheckbox:IsChecked()) then
		UI.SetAdvisorMessageHasBeenSeen(m_TutorialQueue[1].IDName, true);
	end]]
	
	table.remove(m_TutorialQueue, 1);

	ContextPtr:SetHide(true);
	if (bModal) then
		print("Popping Advisor UI");
		UIManager:PopModal(ContextPtr);
	end
end


-- ===========================================================================
function IsAdvisorDisplayOpen()
	return m_bIsOpen and (not ContextPtr:IsHidden());
end


-- ===========================================================================
function ResetAdvisorDisplay ()
	Controls.ActivateButton:SetHide(true);
	Controls.Question1String:SetHide(true);
	Controls.Question2String:SetHide(true);
	Controls.Question3String:SetHide(true);
	Controls.Question4String:SetHide(true);

	Controls.AdvisorHeaderText:SetText( Locale.ConvertTextKey( "{TXT_KEY_ADVISOR_RESET_TITLE:upper}" ));
	Controls.AdvisorBodyText:SetText( Locale.ConvertTextKey( "TXT_KEY_ADVISOR_RESET_TEXT" ));
end


-- ===========================================================================
function OnAdvisorHelpClicked ()
	local popupInfo = 
	{
		Type  = 99997,
	};
	Events.SerialEventGameMessagePopup(popupInfo);
end
Controls.ActivateButton:RegisterCallback( Mouse.eLClick, OnAdvisorHelpClicked );


-- ===========================================================================
function OnAdvisorDismissClicked ()
	Events.AdvisorDisplayHide();
end
--Controls.AdvisorDismissButton:RegisterCallback( Mouse.eLClick, OnAdvisorDismissClicked );

-- ===========================================================================
function OnQuestion1Clicked ()
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO,
		Text = AdvisorConcept1,
		Priority = PopupPriority.Current,
	}
	Events.SerialEventGameMessagePopup(popupInfo);
end
Controls.Question1String:RegisterCallback( Mouse.eLClick, OnQuestion1Clicked);

-- ===========================================================================
function OnQuestion2Clicked ()
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO,
		Text = AdvisorConcept2,
		Priority = PopupPriority.Current,
	}
	Events.SerialEventGameMessagePopup(popupInfo);
end
Controls.Question2String:RegisterCallback( Mouse.eLClick, OnQuestion2Clicked);

-- ===========================================================================
function OnQuestion3Clicked ()
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO,
		Text = AdvisorConcept3,
		Priority = PopupPriority.Current,
	}
	Events.SerialEventGameMessagePopup(popupInfo);
end
Controls.Question3String:RegisterCallback( Mouse.eLClick, OnQuestion3Clicked);


-- ===========================================================================
function ShouldThisHideForThePopupEvent( eventInfo )




end


-- ===========================================================================
function OnAdvisorDisplayShow (eventInfo)

	table.insert(m_TutorialQueue, eventInfo);
	
	ResetAdvisorDisplay();

	AdvisorConcept1 = eventInfo.Concept1;
	AdvisorConcept2 = eventInfo.Concept2;
	AdvisorConcept3 = eventInfo.Concept3;

	Controls.TutorialRecommendation:SetHide(true);
	for i,control in ipairs(advisorIconControls) do
		control:SetHide(true);
	end

	if (eventInfo.Advisor ~= nil) then
		if (advisorIconControls[eventInfo.Advisor] ~= nil) then
			advisorIconControls[eventInfo.Advisor]:SetHide(false);
		end
	else
		Controls.TutorialRecommendation:SetHide(false);
	end

	-- NOTE: This doesn't take into account pesturing tutorials which should never be marked.
	print("Marking " .. eventInfo.IDName .. " as seen");
	UI.SetAdvisorMessageHasBeenSeen(eventInfo.IDName, true);
		
--	Controls.DontShowAgainCheckbox:SetCheck(false);
	
	Controls.AdvisorHeaderText:LocalizeAndSetText(Locale.ToUpper(eventInfo.TitleText));
	Controls.AdvisorBodyText:LocalizeAndSetText(eventInfo.BodyText);
	
	Controls.AdvisorDismissLabel:SetText(Locale.ConvertTextKey("TXT_KEY_ADVISOR_THANK_YOU"));

	-- If there's a tutorial specified, show the Show Me How button
	if ( eventInfo.Tutorial ~= nil and eventInfo.Tutorial ~= "" and GameInfo.Tutorials[eventInfo.Tutorial] ~= nil) then
		local tutorialType = GameInfo.Tutorials[eventInfo.Tutorial].ID;
		
		-- Guided experience check
		if (PreGame.IsUsingFirstTimeUserExperience()) then
			Controls.ShowMeButton:SetHide(true);
			Controls.AdvisorDismissLabel:SetText(Locale.ConvertTextKey("TXT_KEY_ADVISOR_SHOW_ME"));
		else
			Controls.ShowMeButton:SetHide(false);
		end

		Controls.ShowMeButton:RegisterCallback(Mouse.eLClick, function()
			Events.SerialEventGameMessagePopup{
				Type = ButtonPopupTypes.BUTTONPOPUP_TUTORIAL,
				Data1 = tutorialType,
			};

			Events.AdvisorDisplayHide();
		end);

	else
		Controls.ShowMeButton:SetHide(true);
		Controls.AdvisorDismissLabel:SetText(Locale.ConvertTextKey("TXT_KEY_ADVISOR_THANK_YOU"));
	end

	Controls.AdvisorDismissButton:RegisterCallback(Mouse.eLClick, function()
		OnAdvisorDismissClicked()

		if (eventInfo.Tutorial ~= nil and eventInfo.Tutorial ~= "" and PreGame.IsUsingFirstTimeUserExperience()) then
					
			Events.SerialEventGameMessagePopup{
				Type = ButtonPopupTypes.BUTTONPOPUP_TUTORIAL,
				Data1 = GameInfo.Tutorials[eventInfo.Tutorial].ID,
			};
		end
	end);

	if (eventInfo.ActivateButtonText ~= nil and eventInfo.ActivateButtonText ~= "") then
		Controls.ActivateButtonText:SetText(eventInfo.ActivateButtonText);
		Controls.ActivateButton:SetHide(false);
	else 
		Controls.ActivateButton:SetHide(true);
	end
	
	if (eventInfo.Concept1 ~= nil and eventInfo.Concept1 ~= "") then
		local concept = GameInfo.Concepts[eventInfo.Concept1];
		if(concept ~= nil) then
			Controls.Question1String:SetHide(false);
			Controls.Question1String:SetText(Locale.ConvertTextKey(concept.AdvisorQuestion));
		else
			Controls.Question1String:SetHide(true);
			print("Could not find concept. " .. eventInfo.Concept1);
		end
	else
		Controls.Question1String:SetHide(true);
	end

	if (eventInfo.Concept2 ~= nil and eventInfo.Concept2 ~= "") then
		local concept = GameInfo.Concepts[eventInfo.Concept2];
		if(concept ~= nil) then
			Controls.Question2String:SetHide(false);
			Controls.Question2String:SetText(Locale.ConvertTextKey(concept.AdvisorQuestion));
		else
			Controls.Question2String:SetHide(true);
			print("Could not find concept. " .. eventInfo.Concept2);
		end
	else
		Controls.Question2String:SetHide(true);
	end

	if (eventInfo.Concept3 ~= nil and eventInfo.Concept3 ~= "") then
		local concept = GameInfo.Concepts[eventInfo.Concept3];
		if(concept ~= nil) then
			Controls.Question3String:SetHide(false);
			Controls.Question3String:SetText(Locale.ConvertTextKey(concept.AdvisorQuestion));		
		else
			Controls.Question3String:SetHide(true);
			print("Could not find concept. " .. eventInfo.Concept3);
		end
	else
		Controls.Question3String:SetHide(true);
	end
	
	if (eventInfo.Modal) then
		UIManager:PushModal(ContextPtr);	
		bModal = true;
	end
	
	--Resize the window
	local sizeY = 1000;
	Controls.AdvisorStack:CalculateSize();
	Controls.AdvisorStack:ReprocessAnchoring();
	sizeY = Controls.AdvisorStack:GetSizeY();
	Controls.AdvisorGrid:SetSizeY(sizeY + 10);
	Controls.AdvisorGrid:ReprocessAnchoring();

	AdvisorOpen();
end
Events.AdvisorDisplayShow.Add(OnAdvisorDisplayShow);


-- ===========================================================================
function OnClearAdvice()
	AdvisorClose();
	ResetAdvisorDisplay();
end
Events.AdvisorDisplayHide.Add( OnClearAdvice );


-- ===========================================================================
--	Mouse & Key Processing
-- ===========================================================================
function InputHandler(uiMsg, wParam, lParam)
    if( IsAdvisorDisplayOpen() and
        uiMsg == KeyEvents.KeyDown ) then
        if( wParam == Keys.VK_ESCAPE ) then
			Events.AdvisorDisplayHide();
            return true;
        end
    end
    
    return false;
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
--	Special case, in-game menu is raised
-- ===========================================================================
function OnGameMenuRaised()
	if ( m_bIsOpen ) then
		ContextPtr:SetHide( true );
	end	
end
LuaEvents.GameMenuRaised.Add( OnGameMenuRaised );

-- ===========================================================================
--	Special case, in-game menu is lowered
-- ===========================================================================
function OnGameMenuLowered()
	if ( m_bIsOpen ) then
		ContextPtr:SetHide( false );
	end
end
LuaEvents.GameMenuLowered.Add( OnGameMenuLowered);

-- ===========================================================================
--	Special case, Civilopedia shown
-- ===========================================================================
function OnCivilopediaShown()
	if ( m_bIsOpen ) then
		ContextPtr:SetHide( true );
	end
end
LuaEvents.CivilopediaShown.Add(OnCivilopediaShown);

-- ===========================================================================
--	Special case, Civilopedia hidden
-- ===========================================================================
function OnCivilopediaHidden()
	if ( m_bIsOpen ) then
		ContextPtr:SetHide( false );
	end
end
LuaEvents.CivilopediaHidden.Add(OnCivilopediaHidden);

-- ===========================================================================
--	If detailed advisor information is popping up, hide this box.
-- ===========================================================================
function OnShowingAdvisorDetails( popupInfo )

	if ( popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_TUTORIAL or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_COUNSEL or
		 popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO ) then
		if ( m_bIsOpen ) then
			ContextPtr:SetHide( true );
		end
	end
end
Events.SerialEventGameMessagePopupShown.Add( OnShowingAdvisorDetails );


-- ===========================================================================
--	If detailed advisor information is being dimissed, again show this.
-- ===========================================================================
function OnHidingAdvisorDetails( popupID )

	if ( popupID == ButtonPopupTypes.BUTTONPOPUP_TUTORIAL or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_COUNSEL or
		 popupID == ButtonPopupTypes.BUTTONPOPUP_ADVISOR_INFO ) then
		if ( m_bIsOpen ) then
			ContextPtr:SetHide( false );
		end
	end
end
Events.SerialEventGameMessagePopupProcessed.Add( OnHidingAdvisorDetails );


---------------------
ResetAdvisorDisplay();