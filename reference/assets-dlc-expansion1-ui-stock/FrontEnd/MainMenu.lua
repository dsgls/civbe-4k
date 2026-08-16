-- ===========================================================================
-- Main Menu
-- ===========================================================================
include( "MPGameDefaults" );

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local bHideUITest			= true;
local bHideLoadGame			= true;
local bHidePreGame			= true;
local m_animControls		= {"SinglePlayer","MultiPlayer","Mods","Options","Other","DLC","Exit"};
local m_isFirstShow			= true;


-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsHide ) then

		ShowWindow();
	    -- This is a catch all to ensure that mods are not activated at this point in the UI.
        -- Also, since certain maps and settings will only be available in either the modding or multiplayer
        -- screen, we want to ensure that "safe" settings are loaded that can be used for either SP, MP or Mods.
        -- Activating the DLC (there doesn't have to be any) will make sure no mods are active and all the user's
        -- purchased content is available
        if (not ContextPtr:IsHotLoad()) then
			UIManager:SetUICursor( 1 );
			Modding.ActivateAllowedDLC();
			UIManager:SetUICursor( 0 );
			
			-- Send out an event to continue on, as the ActivateDLC may have swapped out the UI	
			--Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "MainMenu" );
		end
    else
        Controls.CivBELogo:UnloadTexture();
    end
end


-- ===========================================================================
function StartAnimating()

	m_isFirstShow = false;

	local animControl;    
	for _,animControl in pairs(m_animControls) do
		Controls[animControl.."Slide"]:SetToBeginning();
		Controls[animControl.."Alpha"]:SetToBeginning();
		Controls[animControl.."Slide"]:Play();
		Controls[animControl.."Alpha"]:Play();
		Events.AudioPlay2DSound("AS2D_INTERFACE_MENU_ITEM_SLIDE_7");
	end
	
	Controls.ButtonsFadeIn:SetToBeginning();	
	Controls.ButtonsFadeIn:Play();
end


-- ===========================================================================
--	First time the main menu has come up...wait until load delay is complete
--	before animating in menu. 
-- ===========================================================================
function OnReadyToStartAnimating()
	StartAnimating();
end

-- ===========================================================================
function ShowWindow()
	Controls.CivBELogo:SetTexture( "CivilizationBE_RisingTide_Logo.dds" );
	if ( m_isFirstShow ) then		
		Controls.FirstShowDelay:SetToBeginning();
		Controls.FirstShowDelay:RegisterEndCallback( OnReadyToStartAnimating );
		Controls.FirstShowDelay:Play();
	else		
		StartAnimating();
	end
end


------------------------------------------------
-- Event Handler: ConnectedToNetworkHost
-------------------------------------------------

-------------------------------------------------
-- StartGame Button Handler
-------------------------------------------------
function SinglePlayerClick()
	UIManager:QueuePopup( Controls.SinglePlayerScreen, PopupPriority.SinglePlayerScreen );
end
Controls.SinglePlayerButton:RegisterCallback( Mouse.eLClick, SinglePlayerClick );

-------------------------------------------------
-- Multiplayer Button Handler
-------------------------------------------------
function MultiplayerClick()
    UIManager:QueuePopup( Controls.MultiplayerSelectScreen, PopupPriority.MultiplayerSelectScreen );
end
Controls.MultiplayerButton:RegisterCallback( Mouse.eLClick, MultiplayerClick );


-------------------------------------------------
-- Mods button handler
-------------------------------------------------
function ModsButtonClick()
    UIManager:QueuePopup( Controls.ModsEULAScreen, PopupPriority.ModsEULAScreen );
end
Controls.ModsButton:RegisterCallback( Mouse.eLClick, ModsButtonClick );


-------------------------------------------------
-- UITest Button Handler
-------------------------------------------------
--[[
function UITestRClick()
    bHideUITest = not bHideUITest;
    Controls.UITestScreen:SetHide( bHideUITest );
end
Controls.OptionsButton:RegisterCallback( Mouse.eRClick, UITestRClick );
--]]


-------------------------------------------------
-- Options Button Handler
-------------------------------------------------
function OptionsClick()
    UIManager:QueuePopup( Controls.OptionsMenu_FrontEnd, PopupPriority.OptionsMenu );
end
Controls.OptionsButton:RegisterCallback( Mouse.eLClick, OptionsClick );


-------------------------------------------------
-- Hall Of Fame Button Handler
-------------------------------------------------
function OtherClick()
    UIManager:QueuePopup( Controls.Other, PopupPriority.OtherMenu );
end
Controls.OtherButton:RegisterCallback( Mouse.eLClick, OtherClick );


-------------------------------------------------
-- DLC Button Handler
-------------------------------------------------
function OnDLCClick()
    UIManager:QueuePopup( Controls.PremiumContentScreen, PopupPriority.DLCMenu );
end
Controls.DLCButton:RegisterCallback( Mouse.eLClick, OnDLCClick );

-------------------------------------------------
-- My2K / Firaxis Live
-------------------------------------------------
function OnMy2KClick()
	Events.Begin2KLoginProcess();
end
Controls.My2KLogin:RegisterCallback( Mouse.eLClick, OnMy2KClick );


-------------------------------------------------
-- Exit Button Handler
-------------------------------------------------
function OnExitGame()
	Events.UserRequestClose();

    Events.AudioPlay2DSound("AS2D_INTERFACE_BUTTON_CLICK_BACK");
end
Controls.ExitButton:RegisterCallback( Mouse.eLClick, OnExitGame );


----------------------------------------------------------------        
----------------------------------------------------------------
Steam.SetOverlayNotificationPosition( "bottom_left" );


-- Returns -1 if time1 < time2, 0 if equal, 1 if time1 > time 2
function CompareTime(time1, time2)
	
	--First, convert the table into a single numerical value
	-- YYYYMMDDHH
	function convert(t)
		local r = 0;
		if(t.year ~= nil) then
			r = r + t.year * 1000000
		end
		
		if(t.month ~= nil) then
			r = r + t.month * 10000
		end
		
		if(t.day ~= nil) then
			r = r + t.day * 100
		end
		
		if(t.hour ~= nil) then
			r = r + t.hour;
		end
		
		return r;
	end
	
	local ct1 = convert(time1);
	local ct2 = convert(time2);
	
	if(ct1 < ct2) then
		return -1;
	elseif(ct1 > ct2) then
		return 1;
	else
		return 0;
	end
end

-------------------------------------------------------------------------------
function OnSystemUpdateUI( type, tag, iData1, iData2, strData1 )
    if( type == SystemUpdateUIType.RestoreUI) then
		if (tag == "MainMenu") then
			-- Look for any cached invite
			UI:CheckForCommandLineInvitation();    		
			
			if (Network.IsDedicatedServer()) then
					ResetMultiplayerOptions(); 
			    UIManager:QueuePopup( ContextPtr:LookUpControl( "DedicatedServerScreen" ), PopupPriority.LobbyScreen );
			end
		elseif (tag == "StagingRoom") then
			if (UIManager:GetVisibleNamedContext("StagingRoom") == nil) then
				UIManager:QueuePopup( Controls.StagingRoomScreen, PopupPriority.StagingScreen );
			end
		elseif (tag == "ScenariosMenuReset") then			
			local pScenarioScreen = ContextPtr:LookUpControl( "SinglePlayerScreen/ScenariosScreen" );
			if (pScenarioScreen ~= nil) then
				if (pScenarioScreen:IsHidden()) then						
					UIManager:QueuePopup( pScenarioScreen, PopupPriority.GameSetupScreen );
				end
			end
		elseif (tag == "ModsBrowserReset") then
			local pModsBrowser = ContextPtr:LookUpControl("ModsEULAScreen/ModsBrowser" );
			if(pModsBrowser ~= nil) then
				if(pModsBrowser:IsHidden()) then
					UIManager:QueuePopup( pModsBrowser, PopupPriority.ModsBrowserScreen );
				end
			end 
		elseif (tag == "ModsMenu" ) then
			local pModsMenu = ContextPtr:LookUpControl("ModsEULAScreen/ModsBrowser/ModsMenu" );
			if(pModsMenu ~= nil) then
				if(pModsMenu:IsHidden()) then
					UIManager:QueuePopup( pModsMenu, PopupPriority.ModsMenuScreen) ;
				end
			end 
		elseif (tag == "Replay" ) then
			local pOtherScreen = ContextPtr:LookUpControl( "Other" );
			if( pOtherScreen ~= nil) then
				if(pOtherScreen:IsHidden()) then
					UIManager:QueuePopup( pOtherScreen, PopupPriority.OtherMenu );
					LuaEvents.ReplayLoaded( 0, strData1 );
				end
			end
	    end
	end
end

-------------------------------------------------------------------------------
if(UI.IsTouchScreenEnabled()) then
	function OnTouchHelpButton()
		Controls.TouchControlsMenu:SetHide( false );
	end		
	Controls.TouchHelpButton:RegisterCallback( Mouse.eLClick, OnTouchHelpButton );
	Controls.TouchHelpButton:SetHide(false);

	if( not OptionsManager.GetHideTouchHelp() ) then
		OnTouchHelpButton();
	end
else
	Controls.TouchHelpButton:SetHide(true);
	
end


-- ===========================================================================
function OnInitialize( isHotload )
	if isHotload then
		ContextPtr:SetHide( false );
		ShowWindow();
	end
end


-- ===========================================================================
function Initialize()

	local i1, i2		= string.find( UI.GetVersionInfo(), " " );
	local versionNumber	= string.sub(UI.GetVersionInfo(), 1, i2-1);
	Controls.VersionNumber:SetText(versionNumber);	

	local animControl;
	for _,animControl in pairs(m_animControls) do
		Controls[animControl.."Slide"]:Stop();
		Controls[animControl.."Alpha"]:Stop();
	end
	Controls.ButtonsFadeIn:Stop();

	m_isFirstShow = true;

	-- EVENTS
	ContextPtr:SetInitHandler( OnInitialize );
	ContextPtr:SetShowHideHandler( ShowHideHandler );
	Events.SystemUpdateUI.Add( OnSystemUpdateUI );	
end
Initialize();