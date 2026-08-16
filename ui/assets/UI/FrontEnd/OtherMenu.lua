-------------------------------------------------
-- Main Menu
-------------------------------------------------

-------------------------------------------------
-- Script Body
-------------------------------------------------
local bHideUITest = true;
local bHideLoadGame = true;
local bHidePreGame = true;
local fTime = 0;


function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsHide ) then
        Controls.CivBELogo:SetTexture( "CivilizationBE_Logo.dds" );
		for animControl=1,7 do
			Controls[animControl.."Slide"]:SetToBeginning();
			Controls[animControl.."Alpha"]:SetToBeginning();
			Controls[animControl.."Slide"]:Play();
			Controls[animControl.."Alpha"]:Play();
			Events.AudioPlay2DSound("AS2D_INTERFACE_MENU_ITEM_SLIDE_6");
		end
		Controls.ButtonsFadeIn:SetToBeginning();
		Controls.ButtonsFadeIn:Play();
        Controls.MainMenuScreenUI:SetHide( false );
    else
        Controls.CivBELogo:UnloadTexture();
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------
-- Latest News Button Handler
-------------------------------------------------
Controls.LatestNewsButton:RegisterCallback( Mouse.eLClick, function()

	Steam.ActivateGameOverlayToWebPage("http://store.steampowered.com/news/?appids=65980");
end);

-------------------------------------------------
-- Civilopedia Button Handler
-------------------------------------------------
Controls.CivilopediaButton:RegisterCallback( Mouse.eLClick, function()
	UIManager:QueuePopup(Controls.Civilopedia, PopupPriority.HallOfFame);
end);


-------------------------------------------------
-- HoF Button Handler
-------------------------------------------------
function HallOfFameClick()
	UIManager:QueuePopup( Controls.HallOfFame, PopupPriority.HallOfFame );
end
Controls.HallOfFameButton:RegisterCallback( Mouse.eLClick, HallOfFameClick );

-------------------------------------------------
-- View Replays Handler
-------------------------------------------------
function ViewReplaysButtonClick()
	UIManager:QueuePopup( Controls.LoadReplayMenu, PopupPriority.HallOfFame );
end
Controls.ViewReplaysButton:RegisterCallback( Mouse.eLClick, ViewReplaysButtonClick );

----------------------------------------------------------------        
---------------------------------------------------------------- 
-- Because the Replay menu is defered loading, we need to show the replay menu
-- And then tell the replay menu to show this particular replay.
function OnSystemUpdateUI( type, tag, iData1, iData2, strData1  )
    if( type == SystemUpdateUIType.RestoreUI and tag == "Replay") then
		-- Restore after a UI reset
		--UIManager:QueuePopup( Controls.LoadReplayMenu, PopupPriority.HallOfFame );
		--UIManager:QueuePopup( Controls.ReplayViewer, PopupPriority.eUtmost );
		--LuaEvents.ReplayViewer_LoadReplay(strData1); -- replay file name is in the strData1 field
	end
end
Events.SystemUpdateUI.Add( OnSystemUpdateUI );
-------------------------------------------------
-- Credits Button Handler
-------------------------------------------------
function CreditsClicked()
    UIManager:QueuePopup( Controls.Credits, PopupPriority.Credits );
end
Controls.CreditsButton:RegisterCallback( Mouse.eLClick, CreditsClicked );

-------------------------------------------------
-- Leaderboard Button Handler
-------------------------------------------------
function LeaderboardClick()
	UIManager:QueuePopup( Controls.Leaderboard, PopupPriority.Leaderboard );
end
Controls.LeaderboardButton:RegisterCallback( Mouse.eLClick, LeaderboardClick );

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function BackButtonClick()

    UIManager:DequeuePopup( ContextPtr );
    Events.AudioPlay2DSound("AS2D_INTERFACE_BUTTON_CLICK_BACK");
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );


-------------------------------------------------
-- Replay Loaded
-------------------------------------------------
function OnReplayLoaded( nStep : number, sReplayFile : string )

	if( nStep == 0 ) then
		UIManager:QueuePopup( Controls.LoadReplayMenu, PopupPriority.HallOfFame );
		LuaEvents.ReplayLoaded( 1, sReplayFile );
	end
end
LuaEvents.ReplayLoaded.Add( OnReplayLoaded );

----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            BackButtonClick();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );