-- ===========================================================================
--	VICTORY (or defeat) Screen
--
-- ===========================================================================
include( "IconSupport" );
include( "TabSupport" );
include( "CommonBehaviors" );


-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_isDebugTest	= false;
local m_strAudio	= nil;
local m_bAllowBack	= true;
--[[
local m_tabs;
--]]


-- ===========================================================================
function Initialize()
	--[[
	m_tabs = CreateTabs( Controls.TabRow, 64, 32 );
	m_tabs.AddTab( Controls.GameOverTab,	OnGameOver );
	m_tabs.AddTab( Controls.RankingTab,		OnRanking );
	m_tabs.CenterAlignTabs( 10 );	
	m_tabs.SelectTab( Controls.GameOverTab );
	--]]
end


-- ===========================================================================
function OnMainMenu()
	UIManager:DequeuePopup( ContextPtr );

	if (Game.IsHotSeat() and Game.CountHumanPlayersAlive() > 0) then
		local iActivePlayer = Game.GetActivePlayer();
		local pPlayer = Players[iActivePlayer];

		-- If the player is not alive, but there are other humans in the game that are
		-- find the next human player alive and make them the active player
		if (not pPlayer:IsAlive()) then
			local bFound = false;
			
			local iNextPlayer = iActivePlayer + 1;
			for iPlayerLoop = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do		
				if (iNextPlayer >= GameDefines.MAX_MAJOR_CIVS) then
					iNextPlayer = 0;
				end 
				pPlayer = Players[iNextPlayer];
				if (iActivePlayer ~= iNextPlayer and pPlayer:IsAlive() and pPlayer:IsHuman()) then
					Game.SetActivePlayer( iNextPlayer );
					-- Restore the game state
					Game.SetGameState(GameplayGameStateTypes.GAMESTATE_ON);
					bFound = true;
					break;
				end
				iNextPlayer = iNextPlayer + 1;
			end
							
			UIManager:DequeuePopup( ContextPtr );
			Controls.BackgroundImage:UnloadTexture();	
			
			if (not bFound) then
				-- Fail safe
				Events.ExitToMainMenu();
			end
		else
			Events.ExitToMainMenu();
		end		
	else
		Events.ExitToMainMenu();
	end
end
Controls.MainMenuButton:RegisterCallback( Mouse.eLClick, OnMainMenu );


-- ===========================================================================
--	One... More... Turn...
-- ===========================================================================
function OnBack()
	if (m_bAllowBack) then
		Network.SendExtendedGame();
		UIManager:DequeuePopup( ContextPtr );
		Controls.BackgroundImage:UnloadTexture();	
	end
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );


-- ===========================================================================
function GetVictoryAudio (strName) 
	for v in GameInfo.Victories() do 
		if (v.Type == strName) then
			return v.Audio;
		end
	end	
	return nil;
end


-- ===========================================================================
local m_fTime = 0;
local deferredDisplayTime = 0;

function OnUpdate( fDTime )
	
	-- Cap the delta time to eliminate overshooting because of delays in processing.
	local fMaxDTime = fDTime;
	if (fMaxDTime > 0.1) then
		fMaxDTime = 0.1;
	end

	-- Delaying the display so we can see some animation?	
	if (deferredDisplayTime > 0) then
		-- Yes, hide the UI
		Controls.BGBlock:SetHide(true);
		Controls.BGWin:SetHide(true);
		deferredDisplayTime = deferredDisplayTime - fMaxDTime;
		if (deferredDisplayTime <= 0) then	
			Controls.BGBlock:SetHide(false);
			Controls.BGWin:SetHide(false);
			deferredDisplayTime = 0;
		end
	else
		local fNewTime = m_fTime + fMaxDTime;
		if (m_strAudio and m_fTime < 2 and fNewTime >= 2) then
			-- print("Play audio: " .. m_strAudio);
			Events.AudioPlay2DSound(m_strAudio);
		end
		
		if (g_AnimUpdate ~= nil) then
			if (g_AnimUpdate(fMaxDTime)) then
				g_AnimUpdate = nil;
			end
		end
		
		m_fTime = fNewTime;
	end	
	
end
-- If animation is added back in, look to do this only via control, as OnUpdate is an expensive
-- operation in terms of the memory (small allocations) LUA makes!
--ContextPtr:SetUpdate( OnUpdate );

function GetVictoryBackground( victoryType, player : table )
	local victoryBackground = GameInfo.Victories[victoryType].VictoryBackground;

	if GameInfo.Victories[victoryType].VictoryBackgroundAffinityBased then
		local highestAffinityValue = -1;
		local highestAffinityType = "";

		for affinity in GameInfo.Affinity_Types() do
			local curLevel = player:GetAffinityLevel( affinity.ID );
			if (curLevel > highestAffinityValue) then
				highestAffinityValue = curLevel;
				highestAffinityType = affinity.Short;
			end
		end

		victoryBackground = victoryBackground .. "_" .. highestAffinityType;
	end

	victoryBackground = victoryBackground .. ".dds";

	return victoryBackground;
end

-- ===========================================================================
function OnDisplay( type, team )

	-- ??TRON wat?  Potentially remove (leaving commented out here in case of any side affects, because so far I haven't seen any...)
	--if(not ContextPtr:IsHidden()) then
	--	return;
	--end
	
	UIManager:SetUICursor( 0 );
	m_strAudio = nil;
	m_bAllowBack = true;

	local playerID		= Game.GetActivePlayer();
	local player		= Players[playerID];

	if( team == Game.GetActiveTeam() ) then
		Controls.GameOverReasonContainer:SetHide(true);
		Controls.VictoryText:SetHide(true);
    	Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_BANG" ) );
		local victoryType = nil;

		-- Normal Victories

		if( type == EndGameTypes.Time ) then
			Controls.VictoryText:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_VICTORY_TIME_BANG")));
			Controls.VictoryText:SetHide(false);
	    	Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_MESSAGE_TIME" ) );
	    	victoryType = "VICTORY_TIME";
		elseif( type == EndGameTypes.Domination ) then
	    	Controls.VictoryText:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_VICTORY_DOMINATION_BANG")));
			Controls.VictoryText:SetHide(false);
			Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_MESSAGE_DOMINATION" ) );
	    	victoryType = "VICTORY_DOMINATION";
		elseif( type == EndGameTypes.Contact ) then
	    	Controls.VictoryText:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_VICTORY_CONTACT_BANG")));
			Controls.VictoryText:SetHide(false);
			Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_MESSAGE_CONTACT" ) );
	    	victoryType = "VICTORY_CONTACT";		
		elseif( type == EndGameTypes.PromisedLand ) then
	    	Controls.VictoryText:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_VICTORY_PROMISED_LAND_BANG")));
			Controls.VictoryText:SetHide(false);
			Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_MESSAGE_PROMISED_LAND" ) );
	    	victoryType = "VICTORY_PROMISED_LAND";
		elseif( type == EndGameTypes.Emancipation ) then
	    	Controls.VictoryText:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_VICTORY_EMANCIPATION_BANG")));
			Controls.VictoryText:SetHide(false);
			Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_MESSAGE_EMANCIPATION" ) );
	    	victoryType = "VICTORY_EMANCIPATION";
		elseif( type == EndGameTypes.Transcendence ) then
	    	Controls.VictoryText:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_VICTORY_TRANSCENDENCE_BANG")));
			Controls.VictoryText:SetHide(false);
			Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_MESSAGE_TRANSCENDENCE" ) );
	    	victoryType = "VICTORY_TRANSCENDENCE";
		end
		
		-- Determine if "one more turn" is active.
		if(victoryType ~= nil and PreGame.GetGameOption("GAMEOPTION_NO_EXTENDED_PLAY") ~= 1)then
			m_bAllowBack = true;
		else
			m_bAllowBack = false;
		end
			
		if (victoryType) then
			m_strAudio = GetVictoryAudio(victoryType);
			Controls.BackgroundImage:SetTexture(GetVictoryBackground(victoryType, player));
		else
			m_strAudio = GetVictoryAudio("VICTORY_TIME");
			Controls.BackgroundImage:SetTexture(GameInfo.Victories["VICTORY_TIME"].VictoryBackground); 		
		end
	else
		m_bAllowBack = false;

		Controls.GameOverReasonContainer:SetHide( team == -1 );

		if( team ~= -1 ) then

			local winningCivNameKey = Teams[team]:GetNameKey();
		
			if( type == EndGameTypes.Time ) then
				Controls.EndGameReason:SetText(Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_TIME", winningCivNameKey));
			elseif( type == EndGameTypes.Domination ) then
	    		Controls.EndGameReason:SetText(Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_DOMINATION", winningCivNameKey));
			elseif( type == EndGameTypes.Contact ) then
	    		Controls.EndGameReason:SetText(Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_CONTACT", winningCivNameKey));	
			elseif( type == EndGameTypes.PromisedLand ) then
	    		Controls.EndGameReason:SetText(Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_PROMISED_LAND", winningCivNameKey));
			elseif( type == EndGameTypes.Emancipation ) then
	    		Controls.EndGameReason:SetText(Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_EMANCIPATION", winningCivNameKey));
			elseif( type == EndGameTypes.Transcendence ) then
	    		Controls.EndGameReason:SetText(Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_TRANSCENDENCE", winningCivNameKey));
			end
		end

    	Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_DEFEAT_BANG" ) );
    	Controls.EndGameText:SetText( Locale.ConvertTextKey( "TXT_KEY_VICTORY_FLAVOR_LOSS" ) );
    	Controls.BackgroundImage:UnloadTexture();
    	Controls.BackgroundImage:SetTexture( "Victory_Defeat.dds" );
		Events.AudioPlay2DSound("AS2D_DEFEAT_SPEECH");
		if (not Game:IsNetworkMultiPlayer() and player:IsAlive() and PreGame.GetGameOption("GAMEOPTION_NO_EXTENDED_PLAY") ~= 1) then
			if	( type == EndGameTypes.Contact ) or
				( type == EndGameTypes.PromisedLand ) or
				( type == EndGameTypes.Emancipation ) or
				( type == EndGameTypes.Transcendence ) or
				( type == EndGameTypes.Domination ) or
				( type == EndGameTypes.Time ) then
				--( type == EndGameTypes.Loss ) then	-- Also will be set if user chooses to retire game.
				m_bAllowBack = true;
			end
		end
	end 

	Controls.BackButton:SetDisabled( not m_bAllowBack );
		
	local PADDING	= 30;	
	local sizeY		= Controls.EndGameText:GetSizeY();
	Controls.GameOverContainer:SetSizeY( sizeY + PADDING );

	-- This does nothing other than tell other popups to close
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_END_MENU,
		Data1 = -1,
		Data2 = -1,
		Data3 = -1,
		Data4 = -1,
	}
	Events.SerialEventGameMessagePopup(popupInfo);

	--
	UIManager:QueuePopup( ContextPtr, PopupPriority.EndGameMenu );
	
end
--Events.EndGameShow.Add( OnDisplay );


-- ===========================================================================
function OnGameOver()
    Controls.Ranking:SetHide( true );
    Controls.EndGameReplay:SetHide( true );
    --Controls.EndGameDemographics:SetHide( true );
    Controls.GameOverContainer:SetHide( false );
    Controls.BackgroundImage:SetColor( 0xffffffff );
end


-- ===========================================================================
function OnRanking()
    Controls.Ranking:SetHide( false );
    Controls.EndGameReplay:SetHide( true );
    --Controls.EndGameDemographics:SetHide( true );
    Controls.GameOverContainer:SetHide( true );
	Controls.BackgroundImage:SetColor( 0x15ffffff );
end


-- ===========================================================================
-- Key Down Processing
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if( uiMsg == KeyEvents.KeyDown )
    then
        if( wParam == Keys.VK_RETURN or wParam == Keys.VK_ESCAPE ) then
			OnBack();
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )

	CivIconHookup( Game.GetActivePlayer(), 80, Controls.CivIcon, Controls.CivIconBG, Controls.CivIconShadow, false, true );
    if( not bIsInit ) then
        if( not bIsHide ) then
            UI.incTurnTimerSemaphore();
			-- Display a continue button if there are other players left in the game
			local pPlayer = Players[Game.GetActivePlayer()];
			if (Game.IsHotSeat() and Game.CountHumanPlayersAlive() > 0 and not pPlayer:IsAlive()) then
				Controls.MainMenuButton:SetText( Locale.ConvertTextKey( "TXT_KEY_MP_PLAYER_CHANGE_CONTINUE" ) );
			else
				Controls.MainMenuButton:SetText( Locale.ConvertTextKey( "TXT_KEY_MENU_EXIT_TO_MAIN" ) );
			end
            ContextPtr:SetUpdate( OnUpdate );
			m_fTime = 0;
        else
            UI.decTurnTimerSemaphore();
			UI.StopAllSpeech(true);
        end
    end

end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
if ( m_isDebugTest ) then
	--OnDisplay(EndGameTypes.Diplomatic, 1);
	OnDisplay(11, -1);
end

Initialize();