include("TabSupport");
include("GameplayUtilities");
-------------------------------------------------
-- Options Menu
-------------------------------------------------
local m_FullscreenResList = {};
local m_iResolutionCount;
local m_maxX, m_maxY = OptionsManager.GetMaxResolution();
local m_tabs;
local m_currentTab;
local m_tabControls = {};
m_tabControls[1] = Controls.GameButton;
m_tabControls[2] = Controls.IFaceButton;
m_tabControls[3] = Controls.VideoButton;
m_tabControls[4] = Controls.AudioButton;
m_tabControls[5] = Controls.MultiplayerButton;

local m_bInGameQuickCombatState_Cached = false;
local m_bInGameQuickMovementState_Cached = false;

local passwordsMatchString			= Locale.ConvertTextKey( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_MATCH" );
local passwordsMatchTooltipString	= Locale.ConvertTextKey( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_MATCH_TT" );
local passwordsNotMatchString		= Locale.ConvertTextKey( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_NOT_MATCH" );
local passwordsNotMatchTooltipString= Locale.ConvertTextKey( "TXT_KEY_OPSCREEN_TURN_NOTIFY_SMTP_PASSWORDS_NOT_MATCH_TT" );

local MAX_SQUELCH_LEVEL = 5000;

----------------------------------------------------------------
----------------------------------------------------------------
local m_WindowResList = {
{ x=2560, y=2048, bWide=false },
{ x=2560, y=1600, bWide=true },
{ x=1920, y=1200, bWide=true },
{ x=1920, y=1080, bWide=true },
{ x=1680, y=1050, bWide=true },
{ x=1600, y=1200, bWide=false },
{ x=1440, y=900,  bWide=true  },
{ x=1400, y=1050, bWide=true  },
{ x=1366, y=768,  bWide=true },
{ x=1280, y=1024, bWide=false },
{ x=1280, y=960,  bWide=true  },
{ x=1280, y=800,  bWide=true  },
{ x=1024, y=768,  bWide=false }, 
};

-- Store array of supported languages.
g_Languages = Locale.GetSupportedLanguages();
g_SpokenLanguages = Locale.GetSupportedSpokenLanguages();

-------------------------------------------------
-------------------------------------------------
local iMusicVolumeKnobID	= GetVolumeKnobIDFromName("USER_VOLUME_MUSIC");
local iSFXVolumeKnobID		= GetVolumeKnobIDFromName("USER_VOLUME_SFX");
local iSpeechVolumeKnobID	= GetVolumeKnobIDFromName("USER_VOLUME_SPEECH");
local iAmbienceVolumeKnobID	= GetVolumeKnobIDFromName("USER_VOLUME_AMBIENCE");
local iVoiceChatVolumeKnobID= GetVolumeKnobIDFromName("USER_VOLUME_VOICECHAT");

local m_cachedMusicVolumeKnob = nil;
local m_cachedSFXVolumeKnob = nil;
local m_cachedSpeechVolumeKnob = nil;
local m_cachedAmbienceVolumeKnob = nil;
local m_cachedHeadsetVolumeKnob = nil;

function CacheAudioVolumes()
m_cachedMusicVolumeKnob = GetVolumeKnobValue(iMusicVolumeKnobID);
m_cachedSFXVolumeKnob = GetVolumeKnobValue(iSFXVolumeKnobID);
m_cachedSpeechVolumeKnob = GetVolumeKnobValue(iSpeechVolumeKnobID);
m_cachedAmbienceVolumeKnob = GetVolumeKnobValue(iAmbienceVolumeKnobID);
m_cachedHeadsetVolumeKnob = GetVolumeKnobValue(iVoiceChatVolumeKnobID);
end

-------------------------------------------------
-------------------------------------------------
function RevertToCachedAudioVolumes()
	if( m_cachedMusicVolumeKnob ~= nil and m_cachedSFXVolumeKnob ~= nil and m_cachedSpeechVolumeKnob ~= nil 
	        and m_cachedAmbienceVolumeKnob ~= nil and m_cachedHeadsetVolumeKnob ~= nil) then
		SetVolumeKnobValue(iMusicVolumeKnobID, m_cachedMusicVolumeKnob);
		SetVolumeKnobValue(iSFXVolumeKnobID, m_cachedSFXVolumeKnob);
		SetVolumeKnobValue(iSpeechVolumeKnobID, m_cachedSpeechVolumeKnob);
		SetVolumeKnobValue(iAmbienceVolumeKnobID, m_cachedAmbienceVolumeKnob);
		SetVolumeKnobValue(iVoiceChatVolumeKnobID, m_cachedHeadsetVolumeKnob);
	end
end

-------------------------------------------------
-------------------------------------------------
--function SetDefaultGameTabOptions()
--	OptionsManager.SetNoRewardPopups(false);
--	OptionsManager.SetNoTileRecommendations(false);
--	OptionsManager.SetCivilianYields(false);
--	m_cachedSinglePlayerEndTurnTimerEnabled = false;
--	m_cachedMultiPlayerEndTurnTimerEnabled = true;
--	OptionsManager.SetTooltip1Seconds( 150 );
--	OptionsManager.SetTooltip2Seconds( 500 );
--	OptionsManager.SetTutorialLevel(0);
--end

-------------------------------------------------
-------------------------------------------------
function SetDefaultAudioVolumes()
	SetVolumeKnobValue(iMusicVolumeKnobID, 1);
	SetVolumeKnobValue(iSFXVolumeKnobID, 1);
	SetVolumeKnobValue(iSpeechVolumeKnobID, 1);
	SetVolumeKnobValue(iAmbienceVolumeKnobID, 1);
  SetVolumeKnobValue(iVoiceChatVolumeKnobID, 1);
end


-- We only need to do this check one time (at load) and cache it.
local contextId = ContextPtr:GetID();
local g_bIsInGameOptionsMenu = (contextId == "OptionsMenu_InGame");
local g_bIsStagingRoomOptionsMenu = (contextId == "OptionsMenu_StagingRoom");

-- Is this the in-game options menu?
function IsInGameOptionsMenu()
	return g_bIsInGameOptionsMenu
end

-- Is this the in-game options menu or the staging room options menu?
function IsInGameOrStagingRoomOptionsMenu()
	return (g_bIsInGameOptionsMenu or g_bIsStagingRoomOptionsMenu);
end

-------------------------------------------------
-------------------------------------------------
function OnOK()
	OptionsManager.CommitGameOptions();
	OptionsManager.CommitGraphicsOptions();
    SaveAudioOptions();
    
    local bIsInGame = IsInGameOrStagingRoomOptionsMenu();
    
    if (bIsInGame) then
		local bCanCommit = false;
		if (PreGame.IsMultiplayerGame()) then
			if (Matchmaking.IsHost()) then
				-- If we are the host of a game, we can change the quick states
				bCanCommit = true;
			end
		else
			bCanCommit = true;
		end
		
		if (bCanCommit) then
			local options = {};
			if (m_bInGameQuickCombatState_Cached ~= PreGame.GetQuickCombat()) then
				table.insert(options, { "GAMEOPTION_QUICK_COMBAT", m_bInGameQuickCombatState_Cached });
			end
			
			if (m_bInGameQuickMovementState_Cached ~= PreGame.GetQuickMovement()) then
				table.insert(options, { "GAMEOPTION_QUICK_MOVEMENT", m_bInGameQuickMovementState_Cached });
			end
			
			Network.SendGameOptions(options);				

			UI:RequestMinimapBroadcast();
		end
	end
				
    --update local caches because the hide handler will set values back to cached versions
    CacheAudioVolumes();
    
    local bResolutionChanged = OptionsManager.HasUserChangedResolution();
    local bGraphicsChanged = OptionsManager.HasUserChangedGraphicsOptions();
    
    if( bResolutionChanged ) then
		OnApplyRes();
	end
	
	if( bGraphicsChanged ) then
		if ( OptionsManager.AreGraphics32BitNotDefault() ) then
			Controls.GraphicsNotDefaultPopup:SetHide(false);
		else
			Controls.GraphicsChangedPopup:SetHide(false);
		end
    end
    
    if( (not bGraphicsChanged) and (not bResolutionChanged) ) then
		OnBack();
	end
end
Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnOK );

-------------------------------------------------
-------------------------------------------------
function OnNonDefaultAccept()
	Controls.GraphicsNotDefaultPopup:SetHide(true);
	Controls.GraphicsChangedPopup:SetHide(false);
end
Controls.GraphicsNotDefaultOK:RegisterCallback( Mouse.eLClick, OnNonDefaultAccept );

-------------------------------------------------
-------------------------------------------------
function OnNonDefaultRevert()
	Controls.GraphicsNotDefaultPopup:SetHide(true);
	OptionsManager.ResetDefaultGraphicsOptions();
	UpdateOptionsDisplay();
end
Controls.GraphicsNotDefaultRevert:RegisterCallback( Mouse.eLClick, OnNonDefaultRevert );

-------------------------------------------------
-------------------------------------------------
function OnCancel()
	OptionsManager.SyncGameOptionsCache();
	OptionsManager.SyncGraphicsOptionsCache();
	OptionsManager.SyncResolutionOptionsCache();
	RevertToCachedAudioVolumes();
	OnBack();
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCancel );

-------------------------------------------------
-------------------------------------------------
function OnDefault()
	OptionsManager.ResetDefaultGameOptions();
	if ( not IsInGameOptionsMenu()) then
		OptionsManager.ResetDefaultGraphicsOptions();
	end

	if (bIsInGame) then
		if (PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()) then
			m_bInGameQuickCombatState_Cached = OptionsManager.GetMultiplayerQuickCombatEnabled_Cached();
			m_bInGameQuickMovementState_Cached = OptionsManager.GetMultiplayerQuickMovementEnabled_Cached();
		else
			m_bInGameQuickCombatState_Cached = OptionsManager.GetSinglePlayerQuickCombatEnabled_Cached();
			m_bInGameQuickMovementState_Cached = OptionsManager.GetSinglePlayerQuickMovementEnabled_Cached();
		end
	else
		m_bInGameQuickCombatState_Cached = false;
		m_bInGameQuickMovementState_Cached = false;
	end

	SetDefaultAudioVolumes();
	UpdateOptionsDisplay();

end
Controls.DefaultButton:RegisterCallback( Mouse.eLClick, OnDefault );

-------------------------------------------------
-------------------------------------------------
local fullscreenRes;
local windowedRes = {0,0};
local msaaSetting;
local bFullscreen;

function SavePreviousResolutionSettings()
	fullscreenRes = OptionsManager.GetResolution_Cached();
	windowedRes[1], windowedRes[2] = OptionsManager.GetWindowResolution_Cached();
	msaaSetting = OptionsManager.GetAASamples_Cached();
	bFullscreen = OptionsManager.GetFullscreen_Cached();
end

-------------------------------------------------
-------------------------------------------------
function RestorePreviousResolutionSettings()
	OptionsManager.SetResolution_Cached(fullscreenRes);
	OptionsManager.SetWindowResolution_Cached(windowedRes[1], windowedRes[2]);
	OptionsManager.SetAASamples_Cached(msaaSetting);
	OptionsManager.SetFullscreen_Cached(bFullscreen);
	if OptionsManager.HasUserChangedResolution() then
		OptionsManager.CommitResolutionOptions();
	end
	UpdateGraphicsOptionsDisplay();
end

-------------------------------------------------
-- If we hear a multiplayer game invite was sent, exit
-- so we don't interfere with the transition
-------------------------------------------------
function OnMultiplayerGameInvite()
   	if( ContextPtr:IsHidden() == false ) then
		OnCancel();
	end
end

Events.MultiplayerGameLobbyInvite.Add( OnMultiplayerGameInvite );
Events.MultiplayerGameServerInvite.Add( OnMultiplayerGameInvite );

-------------------------------------------------
-------------------------------------------------
local g_fTimer;
function OnUpdate( fDTime )
	Controls.CountdownTimer:SetText( Locale.ConvertTextKey("20") );
	
	g_fTimer = g_fTimer - fDTime;
	if( g_fTimer <= 0 ) then
	    ContextPtr:ClearUpdate();
        OnCountdownNo();
    else
    	Controls.CountdownTimer:SetText( string.format( "%i", g_fTimer + 1 ) );
	end
end
	
	
-------------------------------------------------
-------------------------------------------------
g_bIsResolutionCountdown = false;
function ShowResolutionCountdown()
	g_fTimer = 20;
	ContextPtr:SetUpdate( OnUpdate );
	Controls.Countdown:SetHide(false);
	Controls.CountdownMessage:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_RESOLUTION_TIMER") );
	Controls.CountYes:SetText( Locale.ConvertTextKey("TXT_KEY_YES_BUTTON") );
	Controls.CountNo:SetText( Locale.ConvertTextKey("TXT_KEY_NO_BUTTON") );
	Controls.CountdownTimer:SetText( "20" );
	Controls.LabelStack:CalculateSize();
	Controls.LabelStack:ReprocessAnchoring();
	g_bIsResolutionCountdown = true;
end

-------------------------------------------------
-------------------------------------------------
g_chosenLanguage = 0;
function ShowLanguageCountdown()
	g_fTimer = 20;
	ContextPtr:SetUpdate( OnUpdate );
	Controls.Countdown:SetHide(false);
	Controls.CountdownMessage:SetText( Locale.LookupLanguage(g_Languages[g_chosenLanguage].Type, "TXT_KEY_OPSCREEN_LANGUAGE_TIMER") );
	
	local YesText = string.format( "%s (%s)",
		Locale.LookupLanguage( g_Languages[g_chosenLanguage].Type, "TXT_KEY_YES_BUTTON"), 
		Locale.ConvertTextKey( "TXT_KEY_YES_BUTTON" ) );
	Controls.CountYes:SetText( YesText );
	
	local NoText = string.format( "%s (%s)",
		Locale.LookupLanguage( g_Languages[g_chosenLanguage].Type, "TXT_KEY_NO_BUTTON"), 
		Locale.ConvertTextKey( "TXT_KEY_NO_BUTTON" ) );
	Controls.CountNo:SetText( NoText );
	
	Controls.CountdownTimer:SetText( "20" );
	Controls.LabelStack:CalculateSize();
	Controls.LabelStack:ReprocessAnchoring();
	g_bIsResolutionCountdown = false;
end

-------------------------------------------------
-------------------------------------------------
function OnApplyRes()
	if( OptionsManager.HasUserChangedResolution() ) then
		ShowResolutionCountdown()
		OptionsManager.CommitResolutionOptions();
		UpdateGraphicsOptionsDisplay();
	end
end
Controls.ApplyResButton:RegisterCallback( Mouse.eLClick, OnApplyRes );

-------------------------------------------------
-------------------------------------------------
function OnResetTutorial()
	OptionsManager.ResetTutorial();
end
Controls.ResetTutorialButton:RegisterCallback( Mouse.eLClick, OnResetTutorial);

-------------------------------------------------
-------------------------------------------------
function OnResetMy2KMessages()
	OptionsManager.ResetMy2KMessages();
end
Controls.ResetMy2KMessagesButton:RegisterCallback( Mouse.eLClick, OnResetMy2KMessages);

-------------------------------------------------
-------------------------------------------------
function OnOptionsEvent()
    UIManager:QueuePopup( ContextPtr, PopupPriority.OptionsMenu );
end

-------------------------------------------------
-------------------------------------------------
local bRegisteredOptions = false;
function ShowHideHandler( bIsHide, bIsInit )

	if( bIsInit and IsInGameOptionsMenu() and not bRegisteredOptions) then
		Events.EventOpenOptionsScreen.Add( function() print("OPTIONS EVENTTTTT"); print(ContextPtr:GetID()); OnOptionsEvent(); end);
		bRegisteredOptions = true;
	end

	local bIsInGame =  IsInGameOrStagingRoomOptionsMenu();
    
	if( not bIsHide ) then
		RefreshTutorialLevelOptions();
				--options menu is being shown
		OptionsManager.SyncGameOptionsCache();
		OptionsManager.SyncGraphicsOptionsCache();
		OptionsManager.SyncResolutionOptionsCache();
		
		if (bIsInGame) then 
			m_bInGameQuickCombatState_Cached = PreGame.GetQuickCombat();
			m_bInGameQuickMovementState_Cached = PreGame.GetQuickMovement();
		end
		
		CacheAudioVolumes();
		SavePreviousResolutionSettings();
		UpdateOptionsDisplay();
        
		if( bIsInGame and (PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()) )then
				Controls.TutorialPull:SetDisabled( true );
				Controls.TutorialPull:SetAlpha( 0.5 );
				Controls.ResetTutorialButton:SetDisabled(true);
				Controls.ResetTutorialButton:SetAlpha( 0.5 );
		else
				Controls.TutorialPull:SetDisabled( false );
				Controls.TutorialPull:SetAlpha( 1.0 );
				Controls.ResetTutorialButton:SetDisabled(false);
				Controls.ResetTutorialButton:SetAlpha( 1.0 );
		end
        
		if( bIsInGame and PreGame.IsMultiplayerGame() and not Matchmaking.IsHost()) then
			-- Not this host, disable
			Controls.MPQuickCombatCheckbox:SetDisabled( true );
			Controls.MPQuickCombatCheckbox:SetAlpha( 0.5 );
			Controls.MPQuickMovementCheckbox:SetDisabled(true);
			Controls.MPQuickMovementCheckbox:SetAlpha( 0.5 );
		else
			Controls.MPQuickCombatCheckbox:SetDisabled( false );
			Controls.MPQuickCombatCheckbox:SetAlpha( 1.0 );
			Controls.MPQuickMovementCheckbox:SetDisabled(false);
			Controls.MPQuickMovementCheckbox:SetAlpha( 1.0 );
		end			        
        
		if( bIsInGame )then
				Controls.BGBlock:SetHide( false );
				Controls.VideoPanelBlock:SetHide( false );
				Controls.LanguagePull:SetDisabled( true );
				Controls.LanguagePull:SetAlpha( 0.5 );
				Controls.SpokenLanguagePull:SetDisabled(true);
				Controls.SpokenLanguagePull:SetAlpha( 0.5 );
				--Controls.AutoUIAssetsCheck:SetDisabled( true );
				--Controls.AutoUIAssetsCheck:SetAlpha( 0.5 );
				--Controls.SmallUIAssetsCheck:SetDisabled( true );
				--Controls.SmallUIAssetsCheck:SetAlpha( 0.5 );
		else
				Controls.VideoPanelBlock:SetHide( true );
				Controls.BGBlock:SetHide( true );
		end
		-- If in-game, disable changing resolution (works for most UI pieces, but not all)
		Controls.GraphicsProfilePull:SetDisabled( bIsInGame );
		Controls.FSResolutionPull:SetDisabled( bIsInGame );
		Controls.WResolutionPull:SetDisabled( bIsInGame );
		Controls.MSAAPull:SetDisabled( bIsInGame );
		Controls.FullscreenCheck:SetDisabled( bIsInGame );
		Controls.ApplyResButton:SetDisabled( bIsInGame );
		Controls.VSyncCheck:SetDisabled( bIsInGame );
		Controls.FadeShadowsCheck:SetDisabled( bIsInGame );
		Controls.ThreadedRenderingCheck:SetDisabled( bIsInGame );
		Controls.UIBlurCheck:SetDisabled( bIsInGame );
	else
		--options menu is being hidden
		RevertToCachedAudioVolumes();

		-- Make sure that the voice chat test mode is off.
		Network.SetVoiceChatTestMode(false);
		Controls.VoiceChatTestCheckbox:SetCheck(false);

		if( g_bIsResolutionCountdown ) then
			Controls.GraphicsChangedPopup:SetHide(true);
			OnCountdownNo();
		end
	end

	LuaEvents.IgnoreTutorialUpdate( not bIsHide );
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------------------------
-------------------------------------------------
function OnBack()
	if( Controls.GraphicsChangedPopup:IsHidden() and
		Controls.Countdown:IsHidden() ) then	
		UIManager:DequeuePopup( ContextPtr );
	end
	
	Controls.GraphicsChangedPopup:SetHide(true);
	OnCountdownNo();	
end



-------------------------------------------------
-------------------------------------------------
function OnCategory( which )

	-- Disable the "Default" button in the options screen when in game.
	Controls.DefaultButton:SetDisabled(false);
	if( which == 3 and IsInGameOrStagingRoomOptionsMenu() ) then
		Controls.DefaultButton:SetDisabled(true);
	end

    Controls.GamePanel:SetHide(  which ~= 1 );
    Controls.IFacePanel:SetHide( which ~= 2 );
    Controls.VideoPanel:SetHide( which ~= 3 );
    Controls.AudioPanel:SetHide( which ~= 4 );
    Controls.MultiplayerPanel:SetHide( which ~= 5 );

    Controls.TitleLabel:SetText( m_PanelNames[ which ] );
	m_currentTab = m_tabControls[ which ];
end
Controls.GameButton:SetVoid1(  1 );
Controls.IFaceButton:SetVoid1( 2 );
Controls.VideoButton:SetVoid1( 3 );
Controls.AudioButton:SetVoid1( 4 );
Controls.MultiplayerButton:SetVoid1( 5 );


m_PanelNames = {};
m_PanelNames[ 1 ] = Locale.ConvertTextKey( "TXT_KEY_GAME_OPTIONS" );
m_PanelNames[ 2 ] = Locale.ConvertTextKey( "TXT_KEY_INTERFACE_OPTIONS" );
m_PanelNames[ 3 ] = Locale.ConvertTextKey( "TXT_KEY_VIDEO_OPTIONS" );
m_PanelNames[ 4 ] = Locale.ConvertTextKey( "TXT_KEY_AUDIO_OPTIONS" );
m_PanelNames[ 5 ] = Locale.ConvertTextKey( "TXT_KEY_MULTIPLAYER_OPTIONS" );

OnCategory( 1 );


-------------------------------------------------
-- Volume control
-------------------------------------------------


function UpdateVolumeSliders()
  Controls.MusicVolumeSlider:SetValue(	GetVolumeKnobValue(iMusicVolumeKnobID) );
  Controls.EffectsVolumeSlider:SetValue(	GetVolumeKnobValue(iSFXVolumeKnobID) );
  Controls.SpeechVolumeSlider:SetValue(	GetVolumeKnobValue(iSpeechVolumeKnobID) );
  Controls.AmbienceVolumeSlider:SetValue( GetVolumeKnobValue(iAmbienceVolumeKnobID) );
  Controls.VoiceChatVolumeSlider:SetValue( GetVolumeKnobValue(iVoiceChatVolumeKnobID) );

  Controls.MusicVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MUSIC_SLIDER", Locale.ToPercent(GetVolumeKnobValue(iMusicVolumeKnobID)) ) );
  Controls.EffectsVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SF_SLIDER", Locale.ToPercent(GetVolumeKnobValue(iSFXVolumeKnobID)) ) );
  Controls.SpeechVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SPEECH_SLIDER", Locale.ToPercent(GetVolumeKnobValue(iSpeechVolumeKnobID)) ) );
  Controls.AmbienceVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_AMBIANCE_SLIDER", Locale.ToPercent(GetVolumeKnobValue(iAmbienceVolumeKnobID)) ) );
  Controls.VoiceChatVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_VOICECHAT_SLIDER", Locale.ToPercent(GetVolumeKnobValue(iVoiceChatVolumeKnobID)) ) );
end


function OnGameChangedVolumeLevel( iVolumeKnobID, fNewVolume )

	-- NOTE: testing controls by name is more hardcoded than we'd like
	-- it would be better to put the slider controls in an array and then test their void1's.
	
	-- NOTE: we may get messages for volume controls that are not user volume controls, just ignore them
	
	fRealVolume = GetVolumeKnobValue(iVolumeKnobID);
	
	local newVolume = Locale.ToPercent(fNewVolume);
	if Controls.MusicVolumeSlider:GetVoid1() == iVolumeKnobID then
		Controls.MusicVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MUSIC_SLIDER", newVolume ) );
	elseif Controls.EffectsVolumeSlider:GetVoid1() == iVolumeKnobID then
		Controls.EffectsVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SF_SLIDER", newVolume ) );
	elseif Controls.SpeechVolumeSlider:GetVoid1() == iVolumeKnobID then
		Controls.SpeechVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SPEECH_SLIDER", newVolume ) );
	elseif Controls.AmbienceVolumeSlider:GetVoid1() == iVolumeKnobID then
		Controls.AmbienceVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_AMBIANCE_SLIDER", newVolume ) );
	elseif Controls.VoiceChatVolumeSlider:GetVoid1() == iVolumeKnobID then
		Controls.VoiceChatVolumeSlider:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_VOICECHAT_SLIDER", newVolume ) );
	end
end
--Events.AudioVolumeChanged.Add( OnGameChangedVolumeLevel );

function OnUIVolumeSliderValueChanged( fNewVolumeLevel, void1 )
    SetVolumeKnobValue(void1, fNewVolumeLevel);
    
    local newVolume = Locale.ToPercent(fNewVolumeLevel);
	if Controls.MusicVolumeSlider:GetVoid1() == void1 then
		Controls.MusicVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MUSIC_SLIDER", newVolume ) );
	elseif Controls.EffectsVolumeSlider:GetVoid1() == void1 then
		Controls.EffectsVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SF_SLIDER", newVolume ) );
	elseif Controls.SpeechVolumeSlider:GetVoid1() == void1 then
		Controls.SpeechVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SPEECH_SLIDER", newVolume ) );
	elseif Controls.AmbienceVolumeSlider:GetVoid1() == void1 then
		Controls.AmbienceVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_AMBIANCE_SLIDER", newVolume ) );
	elseif Controls.VoiceChatVolumeSlider:GetVoid1() == void1 then
		Controls.VoiceChatVolumeSliderValue:SetText( Locale.ConvertTextKey("TXT_KEY_OPSCREEN_VOICECHAT_SLIDER", newVolume ) );
	end
end

Controls.MusicVolumeSlider:RegisterSliderCallback(		OnUIVolumeSliderValueChanged );
Controls.EffectsVolumeSlider:RegisterSliderCallback(	OnUIVolumeSliderValueChanged );
Controls.SpeechVolumeSlider:RegisterSliderCallback(		OnUIVolumeSliderValueChanged );
Controls.AmbienceVolumeSlider:RegisterSliderCallback(	OnUIVolumeSliderValueChanged );
Controls.VoiceChatVolumeSlider:RegisterSliderCallback(	OnUIVolumeSliderValueChanged );

Controls.MusicVolumeSlider:SetVoid1(	iMusicVolumeKnobID );
Controls.EffectsVolumeSlider:SetVoid1(	iSFXVolumeKnobID );
Controls.SpeechVolumeSlider:SetVoid1(	iSpeechVolumeKnobID );
Controls.AmbienceVolumeSlider:SetVoid1(	iAmbienceVolumeKnobID );
Controls.VoiceChatVolumeSlider:SetVoid1(	iVoiceChatVolumeKnobID );

UpdateVolumeSliders();

-------------------------------------------------
-------------------------------------------------
function Tooltip1TimerSliderChanged(value)
	
	--print("value: " .. value);
	
	i = math.floor(value * 10);
	i = i * 100;
	--print("i: " .. i);
	Controls.Tooltip1TimerLength:SetText(Locale.ConvertTextKey("TXT_KEY_OPSCREEN_TOOLTIP_1_TIMER_LENGTH", math.floor(i / 100) ));
	OptionsManager.SetTooltip1Seconds_Cached(i);
end
Controls.Tooltip1TimerSlider:RegisterSliderCallback(Tooltip1TimerSliderChanged)
Controls.Tooltip1TimerSlider:SetValue(OptionsManager.GetTooltip1Seconds()/1000);


-------------------------------------------------
-------------------------------------------------
--[[
function Tooltip2TimerSliderChanged(value)
	i = math.floor(value * 100);
	i = i * 10;
	Controls.Tooltip2TimerLength:SetText(Locale.ConvertTextKey("TXT_KEY_OPSCREEN_TOOLTIP_2_TIMER_LENGTH", i / 100));
	OptionsManager.SetTooltip2Seconds_Cached(i);
end
Controls.Tooltip2TimerSlider:RegisterSliderCallback(Tooltip2TimerSliderChanged)
Controls.Tooltip2TimerSlider:SetValue(OptionsManager.GetTooltip2Seconds()/1000);
--]]


-------------------------------------------------
-- Countdown handlers
-------------------------------------------------
function OnCountdownYes()
	if g_bIsResolutionCountdown == true then
		--just hide the menu
		Controls.Countdown:SetHide(true);
		SavePreviousResolutionSettings();
	else
		--apply language, reload UI
		Locale.SetCurrentLanguage( g_Languages[g_chosenLanguage].Type );
		Events.SystemUpdateUI( SystemUpdateUIType.ReloadUI );
	end
	--turn off timer
	ContextPtr:ClearUpdate();
end
Controls.CountYes:RegisterCallback( Mouse.eLClick, OnCountdownYes );

function OnCountdownNo()
	if g_bIsResolutionCountdown == true then
		--here we revert resolution options to some old options
		Controls.Countdown:SetHide(true);
		RestorePreviousResolutionSettings();
	else
		--revert language to current setting
		Controls.Countdown:SetHide(true);
		Controls.LanguagePull:GetButton():SetText(Locale.GetCurrentLanguage().DisplayName);
	end
	--turn off timer
	ContextPtr:ClearUpdate();
end
Controls.CountNo:RegisterCallback( Mouse.eLClick, OnCountdownNo );

function OnGraphicsChangedOK()
	--close the menu
	Controls.GraphicsChangedPopup:SetHide(true);
	OnBack();
end
Controls.GraphicsChangedOK:RegisterCallback( Mouse.eLClick, OnGraphicsChangedOK );

----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            OnBack();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );

m_GraphicsProfileText = {};
m_GraphicsProfileText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MINIMUM");
m_GraphicsProfileText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_GraphicsProfileText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_GraphicsProfileText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");
m_GraphicsProfileText[ 4 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_ULTRA");
m_GraphicsProfileText[ 5 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_CUSTOM");

m_LeaderText = {};
m_LeaderText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MINIMUM");
m_LeaderText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_LeaderText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_LeaderText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");

m_OverlayText = {};
m_OverlayText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_OverlayText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_OverlayText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");
    
m_ShadowText = {};
m_ShadowText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_OFF");
m_ShadowText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_ShadowText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");
   
m_FOWText = {};
m_FOWText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_FOWText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");

m_WaterText = {};
m_WaterText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MINIMUM");
m_WaterText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_WaterText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_WaterText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");

m_VFXText = {};
m_VFXText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_VFXText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");

m_TerrainDetailText = {};
m_TerrainDetailText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MINIMUM");
m_TerrainDetailText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_TerrainDetailText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_TerrainDetailText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");
  
m_TerrainTessText = {};
m_TerrainTessText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_TerrainTessText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_TerrainTessText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");

m_TerrainShadowText = {};
m_TerrainShadowText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_OFF");
m_TerrainShadowText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_LOW");
m_TerrainShadowText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_MEDIUM");
m_TerrainShadowText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_SETTINGS_HIGH");

m_BindMouseText = {};
m_BindMouseText[ 0 ] = Locale.ConvertTextKey( "TXT_KEY_NEVER" );
m_BindMouseText[ 1 ] = Locale.ConvertTextKey( "TXT_KEY_FULLSCREEN_ONLY" );
m_BindMouseText[ 2 ] = Locale.ConvertTextKey( "TXT_KEY_ALWAYS" );

m_MSAAText = {};
m_MSAAText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MSAA_OFF");
m_MSAAText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MSAA_2X");
m_MSAAText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MSAA_4X");
m_MSAAText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MSAA_8X");

m_EQAAText = {};
m_EQAAText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MSAA_OFF");
m_EQAAText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_EQAA_2X");
m_EQAAText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_EQAA_4X");
m_EQAAText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_EQAA_8X");

m_CSAAText = {};
m_CSAAText[ 0 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_MSAA_OFF");
m_CSAAText[ 1 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_CSAA_2X");
m_CSAAText[ 2 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_CSAA_4X");
m_CSAAText[ 3 ] = Locale.ConvertTextKey("TXT_KEY_OPSCREEN_CSAA_8X");

m_MSAAMap = {};
m_MSAAMap[ 0 ] = 1;
m_MSAAMap[ 1 ] = 2;
m_MSAAMap[ 2 ] = 4;
m_MSAAMap[ 3 ] = 8;

m_MSAAInvMap = {};
m_MSAAInvMap[ 0 ] = 0;
m_MSAAInvMap[ 1 ] = 0;
m_MSAAInvMap[ 2 ] = 1;
m_MSAAInvMap[ 4 ] = 2;
m_MSAAInvMap[ 8 ] = 3;

----------------------------------------------------------------
-- Display updating
----------------------------------------------------------------

function UpdateGameOptionsDisplay()

	local bIsInGame =  IsInGameOrStagingRoomOptionsMenu();
	
    --Controls.NoCitizenWarningCheckbox:SetCheck( OptionsManager.IsNoCitizenWarning() );
    Controls.AutoWorkersDontReplaceCB:SetCheck( OptionsManager.IsAutoWorkersDontReplace_Cached() );
    Controls.AutoWorkersDontRemoveFeaturesCB:SetCheck( OptionsManager.IsAutoWorkersDontRemoveFeatures_Cached() );
    Controls.NoRewardPopupsCheckbox:SetCheck( OptionsManager.IsNoRewardPopups_Cached() );
    Controls.NoTileRecommendationsCheckbox:SetCheck( OptionsManager.IsNoTileRecommendations_Cached() );
    Controls.CivilianYieldsCheckbox:SetCheck( OptionsManager.IsCivilianYields_Cached() );
	Controls.HideAdvisorIntroCheckBox:SetCheck( OptionsManager.GetHideAdvisorIntro_Cached() );
    Controls.SinglePlayerAutoEndTurnCheckBox:SetCheck(OptionsManager.GetSinglePlayerAutoEndTurnEnabled_Cached());
	Controls.MultiplayerAutoEndTurnCheckbox:SetCheck(OptionsManager.GetMultiplayerAutoEndTurnEnabled_Cached());
    Controls.QuickSelectionAdvCheckbox:SetCheck( OptionsManager.GetQuickSelectionAdvanceEnabled_Cached() );
	Controls.DisablePlanetfallFXCheckbox:SetCheck( OptionsManager.GetPlanetfallFXDisabled_Cached() );
	Controls.AutoLoginFiraxisLiveCheckbox:SetCheck( OptionsManager.GetAutoLoginFiraxisLiveEnabled_Cached() );
	
	if (bIsInGame) then
		if (PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()) then
			Controls.SPQuickCombatCheckBox:SetCheck(OptionsManager.GetSinglePlayerQuickCombatEnabled_Cached());
			Controls.SPQuickMovementCheckBox:SetCheck(OptionsManager.GetSinglePlayerQuickMovementEnabled_Cached());
			Controls.MPQuickCombatCheckbox:SetCheck(m_bInGameQuickCombatState_Cached);
			Controls.MPQuickMovementCheckbox:SetCheck(m_bInGameQuickMovementState_Cached);
		else
			Controls.SPQuickCombatCheckBox:SetCheck(m_bInGameQuickCombatState_Cached);
			Controls.SPQuickMovementCheckBox:SetCheck(m_bInGameQuickMovementState_Cached);
			Controls.MPQuickCombatCheckbox:SetCheck(OptionsManager.GetMultiplayerQuickCombatEnabled_Cached());
			Controls.MPQuickMovementCheckbox:SetCheck(OptionsManager.GetMultiplayerQuickMovementEnabled_Cached());
		end
	else
		Controls.SPQuickCombatCheckBox:SetCheck(OptionsManager.GetSinglePlayerQuickCombatEnabled_Cached());
		Controls.SPQuickMovementCheckBox:SetCheck(OptionsManager.GetSinglePlayerQuickMovementEnabled_Cached());
		Controls.MPQuickCombatCheckbox:SetCheck(OptionsManager.GetMultiplayerQuickCombatEnabled_Cached());
		Controls.MPQuickMovementCheckbox:SetCheck(OptionsManager.GetMultiplayerQuickMovementEnabled_Cached());
	end

	Controls.Tooltip1TimerLength:SetText(Locale.ConvertTextKey("TXT_KEY_OPSCREEN_TOOLTIP_1_TIMER_LENGTH", math.floor(OptionsManager.GetTooltip1Seconds_Cached() / 100) ));
 	--Controls.Tooltip2TimerLength:SetText(Locale.ConvertTextKey("TXT_KEY_OPSCREEN_TOOLTIP_2_TIMER_LENGTH", OptionsManager.GetTooltip2Seconds_Cached() / 100));

    Controls.ZoomCheck:SetCheck( OptionsManager.GetStraightZoom_Cached() );
    Controls.AutoUnitCycleCheck:SetCheck( OptionsManager.GetAutoUnitCycle_Cached() );
    Controls.ScoreListCheck:SetCheck( OptionsManager.GetScoreList_Cached() );
    Controls.MPScoreListCheck:SetCheck( OptionsManager.GetMPScoreList_Cached() );
    
    Controls.AutosaveTurnsEdit:SetText( OptionsManager.GetTurnsBetweenAutosave_Cached() );
    Controls.AutosaveMaxEdit:SetText( OptionsManager.GetNumAutosavesKept_Cached() );
    Controls.BindMousePull:GetButton():SetText( m_BindMouseText[ OptionsManager.GetBindMouseMode_Cached() ] );
	    
    local iTutorialLevel = OptionsManager.GetTutorialLevel_Cached();
	if (iTutorialLevel < 0) then
		iTutorialLevel = #m_TutorialLevelText;		
	end
	Controls.TutorialPull:GetButton():SetText( m_TutorialLevelText[ iTutorialLevel ] );
    
    Controls.LanguagePull:GetButton():SetText(Locale.GetCurrentLanguage().DisplayName);
    Controls.SpokenLanguagePull:GetButton():SetText(Locale.GetCurrentSpokenLanguage().DisplayName); --TODO: make this work like its friends -KS
	
  UpdateVolumeSliders();

	Controls.DragSpeedSlider:SetValue( OptionsManager.GetDragSpeed_Cached() / 2 );
	Controls.DragSpeedValue:SetText( Locale.ConvertTextKey( "TXT_KEY_DRAG_SPEED", OptionsManager.GetDragSpeed_Cached() ) );
	Controls.PinchSpeedSlider:SetValue( OptionsManager.GetPinchSpeed_Cached() / 2 );
	Controls.PinchSpeedValue:SetText( Locale.ConvertTextKey( "TXT_KEY_PINCH_SPEED", OptionsManager.GetPinchSpeed_Cached() ) );
	
	--[[ Auto-Resize / small UI
	if( OptionsManager.GetAutoUIAssets_Cached() ) then
        Controls.AutoUIAssetsCheck:SetCheck( true );
        --Controls.SmallUIAssetsCheck:SetCheck( false );
        --Controls.SmallUIAssetsCheck:SetDisabled( true );
        --Controls.SmallUIAssetsCheck:SetAlpha( 0.5 );
    else
        Controls.AutoUIAssetsCheck:SetCheck( false );
        --Controls.SmallUIAssetsCheck:SetDisabled( false );
        --Controls.SmallUIAssetsCheck:SetAlpha( 1.0 );
        --Controls.SmallUIAssetsCheck:SetCheck( OptionsManager.GetSmallUIAssets_Cached() );
    end
	]]
	
    Controls.EnableMapInertiaCheck:SetCheck( OptionsManager.GetEnableMapInertia_Cached() );
    Controls.EnableTransparentMinimap:SetCheck( OptionsManager.GetEnableTransparentMinimap_Cached() );
    Controls.SkipIntroVideoCheck:SetCheck( OptionsManager.GetSkipIntroVideo_Cached() );
	
	Controls.Tooltip1TimerSlider:SetValue(OptionsManager.GetTooltip1Seconds_Cached()/1000);
	--Controls.Tooltip2TimerSlider:SetValue(OptionsManager.GetTooltip2Seconds_Cached()/1000);
end
Events.GameOptionsChanged.Add(UpdateGameOptionsDisplay);


----------------------------------------------------------------
----------------------------------------------------------------
function UpdateGraphicsOptionsDisplay()
	--resolution options
	BuildFSResPulldown();
	BuildWResPulldown();
	
    local bIsFullscreen = OptionsManager.GetFullscreen_Cached(); 
    Controls.FullscreenCheck:SetCheck( bIsFullscreen );
    Controls.FSResolutionPull:SetHide( not bIsFullscreen);
    Controls.WResolutionPull:SetHide( bIsFullscreen );
    
    local kResInfo = m_FullscreenResList[ OptionsManager.GetResolution_Cached() ];
    if( kResInfo ~= nil ) then
        Controls.FSResolutionPull:GetButton():SetText( kResInfo.Width .. "x" .. kResInfo.Height .. "   " .. kResInfo.Refresh .. " Hz" );
	end
    	
    local x, y = OptionsManager.GetWindowResolution_Cached();
    Controls.WResolutionPull:GetButton():SetText( x .. "x" .. y );

	local AASamples = OptionsManager.GetAASamples_Cached();
	local bFP16 = OptionsManager.LeaderAAEnabled();
	local bAdvancedAADisabled = OptionsManager.AdvancedAADisabled();

	if (not bAdvancedAADisabled) and OptionsManager.IsEQAA( AASamples, bFP16 ) then 
		Controls.MSAAPull:GetButton():SetText( m_EQAAText[ m_MSAAInvMap[AASamples] ] );
	else
		if (not bAdvancedAADisabled) and OptionsManager.IsCSAA( AASamples, bFP16 ) then
			Controls.MSAAPull:GetButton():SetText( m_CSAAText[ m_MSAAInvMap[AASamples] ] );
		else
			Controls.MSAAPull:GetButton():SetText( m_MSAAText[ m_MSAAInvMap[AASamples] ] );
		end
	end

    --graphics options
    Controls.VSyncCheck:SetCheck( OptionsManager.GetVSync_Cached() );
	Controls.ThreadedRenderingCheck:SetCheck( OptionsManager.GetThreadedRendering_Cached() );
	
	Controls.GraphicsProfilePull:GetButton():SetText( m_GraphicsProfileText[ OptionsManager.GetGraphicsProfile_Cached() ] );

	Controls.FadeShadowsCheck:SetCheck( OptionsManager.GetFadeShadows_Cached() );
    Controls.LeaderPull:GetButton():SetText( m_LeaderText[ OptionsManager.GetLeaderQuality_Cached() ] );
	Controls.OverlayPull:GetButton():SetText( m_OverlayText[ OptionsManager.GetOverlayLevel_Cached() ] );
	Controls.ShadowPull:GetButton():SetText( m_ShadowText[ OptionsManager.GetShadowLevel_Cached() ] );
	Controls.FOWPull:GetButton():SetText( m_FOWText[ OptionsManager.GetFOWLevel_Cached() ] );
	Controls.TerrainDetailPull:GetButton():SetText( m_TerrainDetailText[ OptionsManager.GetTerrainDetailLevel_Cached() ] );
	Controls.TerrainTessPull:GetButton():SetText( m_TerrainTessText[ OptionsManager.GetTerrainTessLevel_Cached() ] );
	Controls.TerrainShadowPull:GetButton():SetText( m_TerrainShadowText[ OptionsManager.GetTerrainShadowQuality_Cached() ] );
	Controls.WaterPull:GetButton():SetText( m_WaterText[ OptionsManager.GetWaterQuality_Cached() ] );
	Controls.VFXPull:GetButton():SetText( m_VFXText[ OptionsManager.GetVFXQuality_Cached() ] );

	Controls.UIBlurCheck:SetCheck( OptionsManager.GetUIBlur_Cached() );
	Controls.MapBlurCheck:SetCheck( OptionsManager.GetMapBlur_Cached() );
end
Events.GraphicsOptionsChanged.Add(UpdateGraphicsOptionsDisplay);


function 	UpdateVoiceChatTestCheckbox()
	local bIsDisabled = not OptionsManager.GetVoiceChat_Cached();
	Controls.VoiceChatTestCheckbox:SetDisabled(bIsDisabled);
	if(bIsDisabled) then
		Controls.VoiceChatTestCheckbox:SetAlpha( 0.5 );
	else
		Controls.VoiceChatTestCheckbox:SetAlpha( 1 );
	end
end


----------------------------------------------------------------
----------------------------------------------------------------
function UpdateMultiplayerOptionsDisplay()
	Controls.TurnNotifySteamInviteCheckbox:SetCheck(OptionsManager.GetTurnNotifySteamInvite_Cached());
	Controls.TurnNotifyEmailCheckbox:SetCheck(OptionsManager.GetTurnNotifyEmail_Cached());
	Controls.TurnNotifyEmailAddressEdit:SetText(OptionsManager.GetTurnNotifyEmailAddress_Cached());
	Controls.TurnNotifySmtpEmailEdit:SetText(OptionsManager.GetTurnNotifySmtpEmailAddress_Cached());
	Controls.TurnNotifySmtpHostEdit:SetText(OptionsManager.GetTurnNotifySmtpHost_Cached());
	Controls.TurnNotifySmtpPortEdit:SetText(OptionsManager.GetTurnNotifySmtpPort_Cached());
	Controls.TurnNotifySmtpUserEdit:SetText(OptionsManager.GetTurnNotifySmtpUsername_Cached());
	Controls.TurnNotifySmtpPassEdit:SetText(OptionsManager.GetTurnNotifySmtpPassword_Cached());
	Controls.TurnNotifySmtpPassRetypeEdit:SetText(OptionsManager.GetTurnNotifySmtpPassword_Cached());
	Controls.TurnNotifySmtpTLS:SetCheck(OptionsManager.GetTurnNotifySmtpTLS_Cached());
	Controls.LANNickNameEdit:SetText(OptionsManager.GetLANNickName_Cached());
	Controls.VoiceChatEnabledCheckbox:SetCheck(OptionsManager.GetVoiceChat_Cached());
	Controls.PushToTalkCheckbox:SetCheck(OptionsManager.GetVoiceChatPushToTalk_Cached());
	UpdateVoiceChatTestCheckbox();

	local squelchLevel = OptionsManager.GetVoiceChatSquelch_Cached();
	local squelchPercent = squelchLevel/MAX_SQUELCH_LEVEL;

	--print("squelchLevel: " .. tostring(squelchLevel) .. " squelchPercent: ".. tostring(squelchPercent));
	Controls.VoiceChatSquelchSlider:SetValue(squelchPercent);
	ValidateSmtpPassword(); -- Update passwords match label
end


----------------------------------------------------------------
----------------------------------------------------------------
function UpdateOptionsDisplay()
    UpdateGameOptionsDisplay();
    UpdateGraphicsOptionsDisplay();
    UpdateMultiplayerOptionsDisplay();
end


----------------------------------------------------------------
-- Game Options Handlers
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
function OnNoCitizenWarningCheckbox( bIsChecked )
    OptionsManager.SetNoCitizenWarning_Cached( bIsChecked );
end
--Controls.NoCitizenWarningCheckbox:RegisterCheckHandler( OnNoCitizenWarningCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnAutoWorkersDontReplaceCheckbox( bIsChecked )
    OptionsManager.SetAutoWorkersDontReplace_Cached( bIsChecked );
end
Controls.AutoWorkersDontReplaceCB:RegisterCheckHandler( OnAutoWorkersDontReplaceCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnAutoWorkersDontRemoveFeaturesCheckbox( bIsChecked )
	OptionsManager.SetAutoWorkersDontRemoveFeatures_Cached( bIsChecked );
end
Controls.AutoWorkersDontRemoveFeaturesCB:RegisterCheckHandler( OnAutoWorkersDontRemoveFeaturesCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnNoRewardPopupsCheckbox( bIsChecked )
    OptionsManager.SetNoRewardPopups_Cached( bIsChecked );
end
Controls.NoRewardPopupsCheckbox:RegisterCheckHandler( OnNoRewardPopupsCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnNoTileRecommendationsCheckbox( bIsChecked )
    OptionsManager.SetNoTileRecommendations_Cached( bIsChecked );
end
Controls.NoTileRecommendationsCheckbox:RegisterCheckHandler( OnNoTileRecommendationsCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnCivilianYieldsCheckbox( bIsChecked )
    OptionsManager.SetCivilianYields_Cached( bIsChecked );
end
Controls.CivilianYieldsCheckbox:RegisterCheckHandler( OnCivilianYieldsCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnQuickSelectionAdvCheckbox( bIsChecked )
    OptionsManager.SetQuickSelectionAdvanceEnabled_Cached( bIsChecked );
end
Controls.QuickSelectionAdvCheckbox:RegisterCheckHandler( OnQuickSelectionAdvCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnAutosaveTurnsChanged( string )
    OptionsManager.SetTurnsBetweenAutosave_Cached( string );
end
Controls.AutosaveTurnsEdit:RegisterCallback( OnAutosaveTurnsChanged );

----------------------------------------------------------------
----------------------------------------------------------------
function OnDisablePlanetfallFXCheckbox( bIsChecked )
    OptionsManager.SetPlanetfallFXDisabled_Cached( bIsChecked );
end
Controls.DisablePlanetfallFXCheckbox:RegisterCheckHandler( OnDisablePlanetfallFXCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnAutoLoginCheckbox( bIsChecked )
    OptionsManager.SetAutoLoginFiraxisLiveEnabled_Cached( bIsChecked );
end
Controls.AutoLoginFiraxisLiveCheckbox:RegisterCheckHandler( OnAutoLoginCheckbox );

----------------------------------------------------------------
----------------------------------------------------------------
function OnAutosaveMaxChanged( string )
    OptionsManager.SetNumAutosavesKept_Cached( string );
end
Controls.AutosaveMaxEdit:RegisterCallback( OnAutosaveMaxChanged );


----------------------------------------------------------------
----------------------------------------------------------------
function OnZoomCheck( bIsChecked )
    OptionsManager.SetStraightZoom_Cached( bIsChecked );
end
Controls.ZoomCheck:RegisterCheckHandler( OnZoomCheck );


----------------------------------------------------------------
----------------------------------------------------------------
function OnGridCheck( bIsChecked )
    OptionsManager.SetGridOn_Cached( bIsChecked );
end
--Controls.GridCheck:RegisterCheckHandler( OnGridCheck );

----------------------------------------------------------------
----------------------------------------------------------------
function OnHideAdvisorIntroCheck( bIsChecked )
	OptionsManager.SetHideAdvisorIntro_Cached(bIsChecked);
end
Controls.HideAdvisorIntroCheckBox:RegisterCheckHandler(OnHideAdvisorIntroCheck)

----------------------------------------------------------------
----------------------------------------------------------------
function OnSinglePlayerAutoEndTurnCheck( bIsChecked )
	OptionsManager.SetSinglePlayerAutoEndTurnEnabled_Cached(bIsChecked);
end
Controls.SinglePlayerAutoEndTurnCheckBox:RegisterCheckHandler(OnSinglePlayerAutoEndTurnCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnMultiplayerAutoEndTurnCheck( bIsChecked )
	OptionsManager.SetMultiplayerAutoEndTurnEnabled_Cached(bIsChecked);
end
Controls.MultiplayerAutoEndTurnCheckbox:RegisterCheckHandler(OnMultiplayerAutoEndTurnCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnSinglePlayerQuickCombatCheck( bIsChecked )
	local bIsInGame =  IsInGameOrStagingRoomOptionsMenu();
	if (bIsInGame) then
		if (not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then
			-- In a single player game, store for updating the current game option
			m_bInGameQuickCombatState_Cached = bIsChecked;
		end
	end
	OptionsManager.SetSinglePlayerQuickCombatEnabled_Cached(bIsChecked);
end
Controls.SPQuickCombatCheckBox:RegisterCheckHandler(OnSinglePlayerQuickCombatCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnSinglePlayerQuickMovementCheck( bIsChecked )
	local bIsInGame =  IsInGameOrStagingRoomOptionsMenu();
	if (bIsInGame) then
		if (not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then
			-- In a single player game, store for updating the current game option
			m_bInGameQuickMovementState_Cached = bIsChecked;
		end
	end
	OptionsManager.SetSinglePlayerQuickMovementEnabled_Cached(bIsChecked);
end
Controls.SPQuickMovementCheckBox:RegisterCheckHandler(OnSinglePlayerQuickMovementCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnMultiplayerQuickCombatCheck( bIsChecked )
	local bIsInGame =  IsInGameOrStagingRoomOptionsMenu();
	if (bIsInGame) then
		if (PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()) then
			-- In a multiplayer game, store for updating the current game option
			m_bInGameQuickCombatState_Cached = bIsChecked;
		end
	end
	OptionsManager.SetMultiplayerQuickCombatEnabled_Cached(bIsChecked);
end
Controls.MPQuickCombatCheckbox:RegisterCheckHandler(OnMultiplayerQuickCombatCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnMultiplayerQuickMovementCheck( bIsChecked )
	local bIsInGame =  IsInGameOrStagingRoomOptionsMenu();
	if (bIsInGame) then
		if (PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()) then
			-- In a multiplayer game, store for updating the current game option
			m_bInGameQuickMovementState_Cached = bIsChecked;
		end
	end
	OptionsManager.SetMultiplayerQuickMovementEnabled_Cached(bIsChecked);
end
Controls.MPQuickMovementCheckbox:RegisterCheckHandler(OnMultiplayerQuickMovementCheck);

----------------------------------------------------------------
--[[ Deprecated, auto-size is used to automatically determine if small UI should be used; BE doesn't utilize a "small" UI.
function OnAutoUI( bIsChecked )
    OptionsManager.SetAutoUIAssets_Cached( bIsChecked );
    --mini dispaly update here
    if( bIsChecked ) then
		--Controls.SmallUIAssetsCheck:SetCheck( false );
        --Controls.SmallUIAssetsCheck:SetDisabled( true );
        --Controls.SmallUIAssetsCheck:SetAlpha( 0.5 );
    elseif( UI.GetCurrentGameState() == GameStateTypes.CIVBE_GS_MAIN_MENU ) then
        --Controls.SmallUIAssetsCheck:SetDisabled( false );
        --Controls.SmallUIAssetsCheck:SetAlpha( 1.0 );
        --Controls.SmallUIAssetsCheck:SetCheck( OptionsManager.GetSmallUIAssets_Cached() );
    end
end
Controls.AutoUIAssetsCheck:RegisterCheckHandler( OnAutoUI );
]]

----------------------------------------------------------------
----------------------------------------------------------------
function OnSmallUI( bIsChecked )
    OptionsManager.SetSmallUIAssets_Cached( bIsChecked );
end
--Controls.SmallUIAssetsCheck:RegisterCheckHandler( OnSmallUI );


----------------------------------------------------------------
----------------------------------------------------------------
function OnBindMousePull( level )
	OptionsManager.SetBindMouseMode_Cached( level );
    Controls.BindMousePull:GetButton():SetText( m_BindMouseText[ OptionsManager.GetBindMouseMode_Cached() ] );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnLanguagePull(level)
	level = level + 1; --offset because the pulldown is 0-based.
	Controls.LanguagePull:GetButton():SetText( g_Languages[level].DisplayName );
	g_chosenLanguage = level;
	ShowLanguageCountdown();
end

function OnSpokenLanguagePull(level) --TODO: hook this up too! -KS
	level = level + 1;
	Locale.SetCurrentSpokenLanguage( g_SpokenLanguages[level].Type );
	Controls.SpokenLanguagePull:GetButton():SetText( g_SpokenLanguages[level].DisplayName );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnAutoUnitCycleCheck( bIsChecked )
    OptionsManager.SetAutoUnitCycle_Cached( bIsChecked );
end
Controls.AutoUnitCycleCheck:RegisterCheckHandler( OnAutoUnitCycleCheck );


----------------------------------------------------------------
----------------------------------------------------------------
function OnScoreListCheck( bIsChecked )
    OptionsManager.SetScoreList_Cached( bIsChecked );
end
Controls.ScoreListCheck:RegisterCheckHandler( OnScoreListCheck );

----------------------------------------------------------------
----------------------------------------------------------------
function OnMPScoreListCheck( bIsChecked )
    OptionsManager.SetMPScoreList_Cached( bIsChecked );
end
Controls.MPScoreListCheck:RegisterCheckHandler( OnMPScoreListCheck );

----------------------------------------------------------------
----------------------------------------------------------------
function OnEnableMapInertia( bIsChecked )
    OptionsManager.SetEnableMapInertia_Cached( bIsChecked );
end
Controls.EnableMapInertiaCheck:RegisterCheckHandler( OnEnableMapInertia );

----------------------------------------------------------------
----------------------------------------------------------------
function OnEnableTransparentMinimap( bIsChecked )
    OptionsManager.SetEnableTransparentMinimap_Cached( bIsChecked );
end
Controls.EnableTransparentMinimap:RegisterCheckHandler( OnEnableTransparentMinimap );


----------------------------------------------------------------
----------------------------------------------------------------
function OnSkipIntroVideo( bIsChecked )
    OptionsManager.SetSkipIntroVideo_Cached( bIsChecked );
end
Controls.SkipIntroVideoCheck:RegisterCheckHandler( OnSkipIntroVideo );

----------------------------------------------------------------
----------------------------------------------------------------
function OnTutorialPull( level )
    local iTutorialLevel = level;
 
 --[[   
    local bExpansion2Active = ContentManager.IsActive("6DA07636-4123-4018-B643-6575B4EC336B", ContentType.GAMEPLAY);
    local bExpansion1Active = ContentManager.IsActive("0E3751A1-F840-4e1b-9706-519BF484E59D", ContentType.GAMEPLAY);
	if(bExpansion1Active and not bExpansion2Active) then
		if (iTutorialLevel == 4) then
			iTutorialLevel = -1;
		end
	elseif(bExpansion2Active) then
		if(iTutorialLevel == 5) then
			iTutorialLevel = -1;
		end
	else
		if (iTutorialLevel == 3) then
			iTutorialLevel = -1;
		end
    end]]
    OptionsManager.SetTutorialLevel_Cached(iTutorialLevel);
	Controls.TutorialPull:GetButton():SetText( m_TutorialLevelText[ level ] );
end


----------------------------------------------------------------
-- Graphics Options Handlers
----------------------------------------------------------------

----------------------------------------------------------------
----------------------------------------------------------------
function OnFadeShadows( bIsChecked )
	OptionsManager.SetFadeShadows_Cached( bIsChecked );
	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end
Controls.FadeShadowsCheck:RegisterCheckHandler( OnFadeShadows );

----------------------------------------------------------------
----------------------------------------------------------------
function OnFullscreen( bIsChecked )
	OptionsManager.SetFullscreen_Cached( bIsChecked );
    Controls.FSResolutionPull:SetHide( not bIsChecked );
    Controls.WResolutionPull:SetHide( bIsChecked );
end
Controls.FullscreenCheck:RegisterCheckHandler( OnFullscreen );


----------------------------------------------------------------
----------------------------------------------------------------
function OnVSync( bIsChecked )
    OptionsManager.SetVSync_Cached( bIsChecked );
end
Controls.VSyncCheck:RegisterCheckHandler( OnVSync );

----------------------------------------------------------------
----------------------------------------------------------------
function OnThreadedRendering( bIsChecked )
    OptionsManager.SetThreadedRendering_Cached( bIsChecked );
end
Controls.ThreadedRenderingCheck:RegisterCheckHandler( OnThreadedRendering );

----------------------------------------------------------------
----------------------------------------------------------------
function OnShowAdvancedOptions( bIsChecked )
	Controls.AdvancedGraphicsStack:SetHide( not bIsChecked );
end
Controls.AdvancedOptionsCheck:RegisterCheckHandler( OnShowAdvancedOptions );

----------------------------------------------------------------
----------------------------------------------------------------
function OnGraphicsProfilePull( level )
	OptionsManager.SetGraphicsProfile_Cached( level );
	Controls.GraphicsProfilePull:GetButton():SetText( m_GraphicsProfileText[ level ] );

	UpdateGraphicsOptionsDisplay();
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnLeaderPull( level )
    OptionsManager.SetLeaderQuality_Cached( level );
	Controls.LeaderPull:GetButton():SetText( m_LeaderText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnOverlayPull( level )
    OptionsManager.SetOverlayLevel_Cached( level );
	Controls.OverlayPull:GetButton():SetText( m_OverlayText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnShadowPull( level )
    OptionsManager.SetShadowLevel_Cached( level );
	Controls.ShadowPull:GetButton():SetText( m_ShadowText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnFOWPull( level )
    OptionsManager.SetFOWLevel_Cached( level );
	Controls.FOWPull:GetButton():SetText( m_FOWText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnTerrainDetailPull( level )
    OptionsManager.SetTerrainDetailLevel_Cached( level );
	Controls.TerrainDetailPull:GetButton():SetText( m_TerrainDetailText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnTerrainTessPull( level )
    OptionsManager.SetTerrainTessLevel_Cached( level );
	Controls.TerrainTessPull:GetButton():SetText( m_TerrainTessText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnTerrainShadowPull( level )
    OptionsManager.SetTerrainShadowQuality_Cached( level );
	Controls.TerrainShadowPull:GetButton():SetText( m_TerrainShadowText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnWaterPull( level )
    OptionsManager.SetWaterQuality_Cached( level );
	Controls.WaterPull:GetButton():SetText( m_WaterText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnVFXPull( level )
  OptionsManager.SetVFXQuality_Cached( level );
	Controls.VFXPull:GetButton():SetText( m_VFXText[ level ] );

	OptionsManager.SetGraphicsProfile_Cached( 5 );
	OnGraphicsProfilePull( 5 );
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnUIBlur( bIsChecked )
    OptionsManager.SetUIBlur_Cached( bIsChecked );
end
Controls.UIBlurCheck:RegisterCheckHandler( OnUIBlur );

----------------------------------------------------------------
----------------------------------------------------------------
function OnMapBlur( bIsChecked )
    OptionsManager.SetMapBlur_Cached( bIsChecked );
end
Controls.MapBlurCheck:RegisterCheckHandler( OnMapBlur );



----------------------------------------------------------------
----------------------------------------------------------------
function OnWResolutionPull( index )
    local kResInfo = m_WindowResList[ index ];

    if( kResInfo ~= nil ) then
        OptionsManager.SetWindowResolution_Cached( kResInfo.x, kResInfo.y );
    	Controls.WResolutionPull:GetButton():SetText( kResInfo.x .. "x" .. kResInfo.y );
	end
end
Controls.WResolutionPull:RegisterSelectionCallback( OnWResolutionPull );


----------------------------------------------------------------
----------------------------------------------------------------
function OnFSResolutionPull( index )
    local kResInfo = m_FullscreenResList[ index ];
    
	if( kResInfo ~= nil ) then
		OptionsManager.SetResolution_Cached( index );
		Controls.FSResolutionPull:GetButton():SetText( kResInfo.Width .. "x" .. kResInfo.Height .. "   " .. kResInfo.Refresh .. " Hz" );
    
		OptionsManager.SetWindowResolution_Cached( kResInfo.Width, kResInfo.Height );
		Controls.WResolutionPull:GetButton():SetText( kResInfo.Width .. "x" .. kResInfo.Height );
	end
end
Controls.FSResolutionPull:RegisterSelectionCallback( OnFSResolutionPull );

----------------------------------------------------------------
----------------------------------------------------------------
function OnMSAAPull( level )
	OptionsManager.SetAASamples_Cached( m_MSAAMap[level] );

	local bFP16 = OptionsManager.LeaderAAEnabled();
	local bAdvancedAADisabled = OptionsManager.AdvancedAADisabled();

	if( (not bAdvancedAADisabled) and OptionsManager.IsEQAA( m_MSAAMap[level], bFP16 ) ) then 
		Controls.MSAAPull:GetButton():SetText( m_EQAAText[ level ] );
	else
		if( (not bAdvancedAADisabled) and OptionsManager.IsCSAA( m_MSAAMap[level], bFP16 ) ) then
			Controls.MSAAPull:GetButton():SetText( m_CSAAText[ level ] );
		else
			Controls.MSAAPull:GetButton():SetText( m_MSAAText[ level ] );
		end
	end
end
Controls.MSAAPull:RegisterSelectionCallback( OnMSAAPull );


----------------------------------------------------------------
-- Multiplayer Options Handlers
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifySteamInviteCheck( bIsChecked )
	OptionsManager.SetTurnNotifySteamInvite_Cached(bIsChecked);
end
Controls.TurnNotifySteamInviteCheckbox:RegisterCheckHandler(OnTurnNotifySteamInviteCheck);


----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifyEmailCheck( bIsChecked )
	OptionsManager.SetTurnNotifyEmail_Cached(bIsChecked);
end
Controls.TurnNotifyEmailCheckbox:RegisterCheckHandler(OnTurnNotifyEmailCheck);


----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifyEmailAddressChanged( string )
	OptionsManager.SetTurnNotifyEmailAddress_Cached( string );
end
Controls.TurnNotifyEmailAddressEdit:RegisterCallback( OnTurnNotifyEmailAddressChanged );

----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifySmtpEmailChanged( string )
	OptionsManager.SetTurnNotifySmtpEmailAddress_Cached( string );
end
Controls.TurnNotifySmtpEmailEdit:RegisterCallback( OnTurnNotifySmtpEmailChanged );

----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifySmtpHostChanged( string )
	OptionsManager.SetTurnNotifySmtpHost_Cached( string );
end
Controls.TurnNotifySmtpHostEdit:RegisterCallback( OnTurnNotifySmtpHostChanged );


----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifySmtpPortChanged( string )
	OptionsManager.SetTurnNotifySmtpPort_Cached( string );
end
Controls.TurnNotifySmtpPortEdit:RegisterCallback( OnTurnNotifySmtpPortChanged );


----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifySmtpUsernameChanged( string )
	OptionsManager.SetTurnNotifySmtpUsername_Cached( string );
end
Controls.TurnNotifySmtpUserEdit:RegisterCallback( OnTurnNotifySmtpUsernameChanged );


----------------------------------------------------------------
----------------------------------------------------------------
function OnLANNickNameChanged( string )
	OptionsManager.SetLANNickName_Cached( string );
end
Controls.LANNickNameEdit:RegisterCallback( OnLANNickNameChanged );

----------------------------------------------------------------
----------------------------------------------------------------
function ValidateSmtpPassword()
	if( Controls.TurnNotifySmtpPassEdit:GetText() and Controls.TurnNotifySmtpPassRetypeEdit:GetText() and
		Controls.TurnNotifySmtpPassEdit:GetText() == Controls.TurnNotifySmtpPassRetypeEdit:GetText() ) then
		-- password editboxes match.
		OptionsManager.SetTurnNotifySmtpPassword_Cached( Controls.TurnNotifySmtpPassEdit:GetText() );
		Controls.StmpPasswordMatchLabel:SetText(passwordsMatchString);
		Controls.StmpPasswordMatchLabel:SetToolTipString(passwordsMatchTooltipString);
		Controls.StmpPasswordMatchLabel:SetColorByName( "Green_Chat" );
	else
		-- password editboxes do not match.
		Controls.StmpPasswordMatchLabel:SetText(passwordsNotMatchString);
		Controls.StmpPasswordMatchLabel:SetToolTipString(passwordsNotMatchTooltipString);
		Controls.StmpPasswordMatchLabel:SetColorByName( "Magenta_Chat" );		
	end
end
Controls.TurnNotifySmtpPassEdit:RegisterCallback( ValidateSmtpPassword );
Controls.TurnNotifySmtpPassRetypeEdit:RegisterCallback( ValidateSmtpPassword );

----------------------------------------------------------------
----------------------------------------------------------------
function OnTurnNotifySmtpTLSCheck( bIsChecked )
	OptionsManager.SetTurnNotifySmtpTLS_Cached(bIsChecked);
end
Controls.TurnNotifySmtpTLS:RegisterCheckHandler(OnTurnNotifySmtpTLSCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnVoiceChatEnabledCheck( bIsChecked )
	OptionsManager.SetVoiceChat_Cached(bIsChecked);
	UpdateVoiceChatTestCheckbox();
end
Controls.VoiceChatEnabledCheckbox:RegisterCheckHandler(OnVoiceChatEnabledCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnPushToTalkCheck( bIsChecked )
	OptionsManager.SetVoiceChatPushToTalk_Cached(bIsChecked);
end
Controls.PushToTalkCheckbox:RegisterCheckHandler(OnPushToTalkCheck);

----------------------------------------------------------------
----------------------------------------------------------------
function OnVoiceChatSquelchSlider( fSpeed )
	local squelchLevel = fSpeed * MAX_SQUELCH_LEVEL;
	--print("fSpeed: " .. tostring(fSpeed) .. " squelchLevel: " .. tostring(squelchLevel));
	OptionsManager.SetVoiceChatSquelch_Cached( squelchLevel );
	OptionsManager.CommitGameOptions();
end
Controls.VoiceChatSquelchSlider:RegisterSliderCallback(OnVoiceChatSquelchSlider);

----------------------------------------------------------------
----------------------------------------------------------------
function OnVoiceChatTestCheck( bIsChecked )
	Network.SetVoiceChatTestMode( bIsChecked );
end
Controls.VoiceChatTestCheckbox:RegisterCheckHandler(OnVoiceChatTestCheck);


----------------------------------------------------------------
-- Pulldowns
----------------------------------------------------------------

----------------------------------------------------------------
----------------------------------------------------------------
function BuildSinglePulldown( pulldown, textTable )
    local controlTable;
    for i = 0, #textTable do
        controlTable = {};
        pulldown:BuildEntry( "InstanceOne", controlTable );
        controlTable.Button:LocalizeAndSetText( textTable[i] );
        controlTable.Button:SetVoid1( i );
    end
    pulldown:CalculateInternals();
end


----------------------------------------------------------------
----------------------------------------------------------------
function BuildLeaderQualityPulldown()
    
    local controlTable;
    
    local size = #m_LeaderText;
    if UI.IsDX9() then
        size = size-1;        -- disallow high leaders on DX9, across the board
    end
    
    for i = 0, size do
    
        controlTable = {};
        Controls.LeaderPull:BuildEntry( "InstanceOne", controlTable );
        controlTable.Button:LocalizeAndSetText( m_LeaderText[i] );
        controlTable.Button:SetVoid1( i );
        
        -- disallow medium leaders on certain low-end machines
        if (i == 2 and not UI.AreMediumLeadersAllowed()) then
            controlTable.Button:SetDisabled(true);
            controlTable.Button:SetAlpha(.3);
        end
    
    end
    
    Controls.LeaderPull:CalculateInternals();
    
end

----------------------------------------------------------------
----------------------------------------------------------------
function BuildMSAAPulldown()
    local controlTable;

	local bIsEQAA = false;
	local bIsCSAA = false;
	local bFP16 = OptionsManager.LeaderAAEnabled();
	local bAdvancedAADisabled = OptionsManager.AdvancedAADisabled();

    for i = 0, 3 do

        controlTable = {};
		Controls.MSAAPull:BuildEntry( "InstanceOne", controlTable );

		bIsEQAA = OptionsManager.IsEQAA( m_MSAAMap[i], bFP16 );
		bIsCSAA = OptionsManager.IsCSAA( m_MSAAMap[i], bFP16 );

		if (not bAdvancedAADisabled) and bIsEQAA then
			controlTable.Button:LocalizeAndSetText( m_EQAAText[i] );
		else
			if (not bAdvancedAADisabled) and bIsCSAA then
				controlTable.Button:LocalizeAndSetText( m_CSAAText[i] );
			else
				controlTable.Button:LocalizeAndSetText( m_MSAAText[i] );
			end
		end
		
		controlTable.Button:SetVoid1( i );
		if not OptionsManager.IsAALevelSupported(m_MSAAMap[i]) then
			controlTable.Button:SetDisabled(true);
			controlTable.Button:SetAlpha(.3);
		end
    end
    Controls.MSAAPull:CalculateInternals();
end

----------------------------------------------------------------
----------------------------------------------------------------
function BuildPulldowns()

    BuildFSResPulldown();
    BuildWResPulldown();
    BuildMSAAPulldown();
    
	BuildSinglePulldown( Controls.GraphicsProfilePull, m_GraphicsProfileText );
	Controls.GraphicsProfilePull:RegisterSelectionCallback( OnGraphicsProfilePull );

    --BuildSinglePulldown( Controls.TutorialPull, m_TutorialLevelText );
    Controls.TutorialPull:RegisterSelectionCallback( OnTutorialPull );
    
    BuildSinglePulldown( Controls.OverlayPull, m_OverlayText );
    Controls.OverlayPull:RegisterSelectionCallback( OnOverlayPull );
    
    BuildSinglePulldown( Controls.ShadowPull, m_ShadowText );
    Controls.ShadowPull:RegisterSelectionCallback( OnShadowPull );

    BuildSinglePulldown( Controls.FOWPull, m_FOWText );
    Controls.FOWPull:RegisterSelectionCallback( OnFOWPull );
  
    BuildSinglePulldown( Controls.TerrainDetailPull, m_TerrainDetailText );
    Controls.TerrainDetailPull:RegisterSelectionCallback( OnTerrainDetailPull );
  
    BuildSinglePulldown( Controls.TerrainTessPull, m_TerrainTessText );
    Controls.TerrainTessPull:RegisterSelectionCallback( OnTerrainTessPull );

    BuildSinglePulldown( Controls.TerrainShadowPull, m_TerrainShadowText );
    Controls.TerrainShadowPull:RegisterSelectionCallback( OnTerrainShadowPull );

    BuildSinglePulldown( Controls.WaterPull, m_WaterText );
    Controls.WaterPull:RegisterSelectionCallback( OnWaterPull );

	BuildSinglePulldown( Controls.VFXPull, m_VFXText );
    Controls.VFXPull:RegisterSelectionCallback( OnVFXPull );


    ----------------------------------------------------------------
    -- leader detail pull (special case)
    local controlTable;
    local count = #m_LeaderText
    
    BuildLeaderQualityPulldown();
    Controls.LeaderPull:RegisterSelectionCallback( OnLeaderPull );
    ----------------------------------------------------------------


    BuildSinglePulldown( Controls.BindMousePull, m_BindMouseText );
    Controls.BindMousePull:RegisterSelectionCallback( OnBindMousePull );
    
    local languageTable = {};
    for i,v in ipairs(g_Languages) do
		languageTable[i - 1] = v.DisplayName;
    end
    BuildSinglePulldown( Controls.LanguagePull, languageTable);
    Controls.LanguagePull:RegisterSelectionCallback( OnLanguagePull );
    
    
    local spokenLanguageTable = {};
    for i,v in ipairs(g_SpokenLanguages) do
		spokenLanguageTable[i - 1] = v.DisplayName;
    end
    
    BuildSinglePulldown( Controls.SpokenLanguagePull, spokenLanguageTable);
    Controls.SpokenLanguagePull:RegisterSelectionCallback( OnSpokenLanguagePull );
end


----------------------------------------------------------------
----------------------------------------------------------------
function BuildWResPulldown()
    Controls.WResolutionPull:ClearEntries();
    m_maxX, m_maxY = OptionsManager.GetMaxResolution();

    local bFound = false;
    for i, kResInfo in ipairs( m_WindowResList ) do
        if( kResInfo.x <= m_maxX and
            kResInfo.y <= m_maxY ) then
            
            local controlTable = {};
            Controls.WResolutionPull:BuildEntry( "InstanceOne", controlTable );
            
            controlTable.Button:SetText( kResInfo.x .. "x" .. kResInfo.y );
            controlTable.Button:SetVoid1( i );
        end
    end
    
    Controls.WResolutionPull:CalculateInternals();
end


----------------------------------------------------------------
----------------------------------------------------------------
function BuildFSResPulldown()

    Controls.FSResolutionPull:ClearEntries();
    local count = #m_FullscreenResList;
    
    for i = count, 0, -1 do
        local kResInfo = m_FullscreenResList[i];
                                                   
        local controlTable = {};
        Controls.FSResolutionPull:BuildEntry( "InstanceOne", controlTable );
            
        controlTable.Button:SetText( kResInfo.Width .. "x" .. kResInfo.Height .. "   " .. kResInfo.Refresh .. " Hz" );
        controlTable.Button:SetVoid1( i );
    end
    
    Controls.FSResolutionPull:CalculateInternals();
end


----------------------------------------------------------------
-- build the internal list of fullscreen modes
----------------------------------------------------------------
m_iResolutionCount = UIManager:GetResCount();
for i = 0, m_iResolutionCount-1, 1  do
    local width, height, refresh, scale, display, adapter = UIManager:GetResInfo( i );
    m_FullscreenResList[i] = { Width = width,
                            Height = height,
                            Refresh = refresh,
                            Display = display,
                            Adapter = adapter };

	--print( "Testing Mode: " .. width .. " " .. height .. " " .. refresh .. " " .. i );
end

function RefreshTutorialLevelOptions()
	TutorialLevels = GameplayUtilities.GetTutorialLevels();

	--[[
	local bExpansion1Active = ContentManager.IsActive("0E3751A1-F840-4e1b-9706-519BF484E59D", ContentType.GAMEPLAY);
	local bExpansion2Active = ContentManager.IsActive("6DA07636-4123-4018-B643-6575B4EC336B", ContentType.GAMEPLAY);
	
	if(bExpansion1Active or bExpansion2Active) then
		table.insert(TutorialLevels, Locale.Lookup("TXT_KEY_OPSCREEN_TUTORIAL_NEW_TO_XP"));
	end
	
	if(bExpansion2Active) then
		table.insert(TutorialLevels, Locale.Lookup("TXT_KEY_OPSCREEN_TUTORIAL_NEW_TO_XP2"));
	end]]

	m_TutorialLevelText = {};
	for i,v in ipairs(TutorialLevels) do
		m_TutorialLevelText[i - 1] = v;
	end
	
	Controls.TutorialPull:ClearEntries();
	BuildSinglePulldown(Controls.TutorialPull, m_TutorialLevelText);
end

----------------------------------------------------------------
-- add the machine's desktop resolution just in case they're
-- running something weird
----------------------------------------------------------------
local bFound = false;
for _, kResInfo in ipairs( m_WindowResList ) do
    if( kResInfo.x == m_maxX and
        kResInfo.y == m_maxY ) then
        bFound = true;
    end
end
if( bFound == false ) then
    m_WindowResList[0] = { x=m_maxX, y=m_maxY };
end


RefreshTutorialLevelOptions();
BuildPulldowns();
UpdateOptionsDisplay();

----------------------------------------------------------------
----------------------------------------------------------------
function OnDragSpeedSlider( fSpeed )

    --fSpeed = (fSpeed * 2) + 0.1;
	iSpeed = math.floor((fSpeed + 0.02) * 20) / 10;
	
    OptionsManager.SetDragSpeed_Cached( iSpeed );
	OptionsManager.CommitGameOptions();
	Controls.DragSpeedValue:SetText( Locale.ConvertTextKey( "TXT_KEY_DRAG_SPEED", iSpeed ) );
end
Controls.DragSpeedSlider:RegisterSliderCallback( OnDragSpeedSlider )
Controls.DragSpeedSlider:SetValue( OptionsManager.GetDragSpeed() / 2 );
Controls.DragSpeedValue:SetText( Locale.ConvertTextKey( "TXT_KEY_DRAG_SPEED", OptionsManager.GetDragSpeed() ) );


----------------------------------------------------------------
----------------------------------------------------------------
function OnPinchSpeedSlider( fSpeed )

    --fSpeed = (fSpeed * 2) + 0.1;
	iSpeed = math.floor((fSpeed + 0.02) * 20) / 10;

    OptionsManager.SetPinchSpeed_Cached( iSpeed );
	OptionsManager.CommitGameOptions();
	Controls.PinchSpeedValue:SetText( Locale.ConvertTextKey( "TXT_KEY_PINCH_SPEED", iSpeed ) );
end
Controls.PinchSpeedSlider:RegisterSliderCallback( OnPinchSpeedSlider );
Controls.PinchSpeedSlider:SetValue( OptionsManager.GetPinchSpeed() / 2 );
Controls.PinchSpeedValue:SetText( Locale.ConvertTextKey( "TXT_KEY_PINCH_SPEED", OptionsManager.GetPinchSpeed() ) );

function Initialize()
	m_tabs = CreateTabs( Controls.TabContainer, 64, 32 );
	m_tabs.AddTab( Controls.GameButton, function() OnCategory(1);end );
	m_tabs.AddTab( Controls.IFaceButton, function() OnCategory(2);end );
	m_tabs.AddTab( Controls.VideoButton, function() OnCategory(3);end );
	m_tabs.AddTab( Controls.AudioButton, function() OnCategory(4);end );
	m_tabs.AddTab( Controls.MultiplayerButton, function() OnCategory(5);end );
	m_tabs.CenterAlignTabs();
	m_tabs.SelectTab(Controls.GameButton);
end
Initialize();
