-------------------------------------------------
-- Multiplayer Turn Panel
-------------------------------------------------
include( "IconSupport" ); -- for civ icon hookups
include( "TurnStatusBehavior" ); -- for turn status button behavior
include( "InstanceManager" );

-------------------------------------------------
-- Local Variables
-------------------------------------------------
local turnEnded = true; -- indicates that we have ended our turn, changing the colors of the turn timer.

-- Turn Queue Data
local g_InstanceManager = InstanceManager:new( "TurnQueueEntry", "Root", Controls.TurnQueueStack );
local g_TeamData = {};				-- Static list of player teams
local g_TurnQueueEntries = {};		-- List of turn queue controls 
local g_SortTable = {};

-- Determine wrap size for Turn Queue.
local INFOCORNER_GUESS = 400;		 -- estimated size of the unit panel
local MINIMAP_GUESS = 400;			 -- estimated size of the minimap panel
local TURNQUEUE_MINMARGIN = 0; -- combined minimum required margin size between the turn queue and the unit/minimap panels.

local g_iconSizes = {};
g_iconSizes["Standard"]	= { mainSize = {x = 64, y = 64}, iconSize = {x = 48, y = 48} };
g_iconSizes["Small"]	= { mainSize = {x = 32, y = 32}, iconSize = {x = 24, y = 24} };

local g_curIconSize = g_iconSizes["Standard"];

-----------------------------------------------------
-- Utility Functions
-------------------------------------------------
function GetPlayer ()
	local iPlayerID = Game.GetActivePlayer();
	if (iPlayerID < 0) then
		print("Error - player index not correct");
		return nil;
	end

	if (not Players[iPlayerID]:IsHuman()) then
		return nil;
	end;

	return Players[iPlayerID];
end

----------------------------------------------
function CalcScreenSizes()
	local screenX, _ = UIManager:GetScreenSizeVal();

	local turnPanelWrap = screenX - INFOCORNER_GUESS - MINIMAP_GUESS - TURNQUEUE_MINMARGIN;
	Controls.TurnQueueStack:SetWrapWidth(turnPanelWrap);

	if(screenX > 1024) then
		g_curIconSize = g_iconSizes["Standard"];
	else
		g_curIconSize = g_iconSizes["Small"];
	end
end

-------------------------------------------------------------------------
-- Turn Queue Functions
-------------------------------------------------------------------------
function TurnQueueSort( a, b )
     local aScore = g_SortTable[ tostring( a ) ];
     local bScore = g_SortTable[ tostring( b ) ];
        
     return aScore < bScore;
end

----------------------------------------------
-- Update Turn Queue (for a given Player ID)
function UpdateTurnQueueForPlayerID( playerID )
-- Update the turn queue based on a change for the given player ID.
    UpdateTurnQueueData( Players[ playerID ], g_TurnQueueEntries[ playerID ] );
end

----------------------------------------------
function UpdateTurnQueueData( pPlayer, controlTable )
	if controlTable == nil then
		return;
	end
	
	local activePlayer = Players[Game.GetActivePlayer()];
	local activeTeam = Teams[activePlayer:GetTeam()];
	
	local playerTeam = pPlayer:GetTeam();
	
	-- Observer players pretend to have met everyone for this panel.
	local bMet = activeTeam:IsHasMet(playerTeam) or activePlayer:IsObserver(); 
	
	CivIconHookup( bMet and pPlayer:GetID() or -1, g_curIconSize.mainSize.x, controlTable.CivIcon, controlTable.CivIconBG, nil, false, false, controlTable.CivIconHighlight);
	 
	-- Determine Turn Queue sort value
	if(pPlayer:IsSimultaneousTurns()) then
		if(not pPlayer:IsHuman()) then
			-- when playing simultaneously, AI players always go first
			g_SortTable[ tostring( controlTable.Root ) ] = -2;
		else
			-- when playing simultaneously, human players always go second
			g_SortTable[ tostring( controlTable.Root ) ] = -1;
		end
	else
		-- sequential turn players are sorted by player id
		g_SortTable[ tostring( controlTable.Root ) ] = pPlayer:GetID();
	end
	
	local playerName;
	if(pPlayer:IsHuman()) then
		local MAX_NAME_CHARS= 20;
		playerName = TruncateStringByLength(pPlayer:GetNickName(), MAX_NAME_CHARS);
	else
		if(bMet) then
			playerName = pPlayer:GetName();
		else
			playerName = Locale.Lookup("TXT_KEY_UNMET_PLAYER_SHORT");
		end
	end
			
	-- Update the turn status
	UpdateTurnStatus( pPlayer, controlTable.CivIconFrame, controlTable.ActiveTurnAnim, g_TurnQueueEntries );
	   
  controlTable.CivIconFrame:SetToolTipString(playerName);
end

-------------------------------------------------------------------------
-- Build the Turn Queue Controls
-------------------------------------------------------------------------
function SetupIconSize(controlTable)
	controlTable.Root:SetSize(g_curIconSize.mainSize);
	controlTable.CivIconFrame:SetSize(g_curIconSize.mainSize);

	controlTable.CivIconBG:SetSize(g_curIconSize.mainSize);
	controlTable.CivIconBG:SetTextureSizeVal(g_curIconSize.mainSize.x, g_curIconSize.mainSize.y);
	--controlTable.CivIconBG:NormalizeTexture();
	
	controlTable.CivIconHighlight:SetSize(g_curIconSize.mainSize);
	controlTable.CivIconHighlight:SetTextureSizeVal(g_curIconSize.mainSize.x, g_curIconSize.mainSize.y);
	--controlTable.CivIconHighlight:NormalizeTexture();
	
	controlTable.CivIcon:SetSize(g_curIconSize.iconSize);
	controlTable.CivIcon:SetTextureSizeVal(g_curIconSize.iconSize.x, g_curIconSize.iconSize.y);
	--controlTable.Icon:NormalizeTexture();
end

function BuildTurnQueue()
	-- print("BuildTurnQueue Start");
	if(not PreGame.IsMultiplayerGame()) then
		-- Turn Queue is multiplayer only
		return;
	end

	g_InstanceManager:ResetInstances();
	g_TurnQueueEntries = {};
	
	-- print("BuildTurnQueue Starting Construction");
    for iTeam, teamData in pairs( g_TeamData ) do
        local pTeam = Teams[ iTeam ];

        if( pTeam:GetNumMembers() == 1 ) then

            -- single member team
            local pPlayer = teamData;

            -- Make sure they're alive
            if( pPlayer:IsAlive() ) then
                local controlTable = g_InstanceManager:GetInstance();
                g_TurnQueueEntries[ pPlayer:GetID() ] = controlTable;
                SetupIconSize(controlTable);
                UpdateTurnQueueData( pPlayer, controlTable );
            end
        else
            for _, pPlayer in pairs( teamData ) do
                
                if( pPlayer:IsEverAlive() ) then
										local controlTable = g_InstanceManager:GetInstance();
                    g_TurnQueueEntries[ pPlayer:GetID() ] = controlTable;
                    SetupIconSize(controlTable);
                    UpdateTurnQueueData( pPlayer, controlTable );
                end
            end
        end
    end
    
    -- sort players based on turn order
    Controls.TurnQueueStack:SortChildren( TurnQueueSort );
    
    Controls.TurnQueueStack:CalculateSize(); 
    Controls.TurnQueueStack:ReprocessAnchoring();
    
    -- Size the Turn Queue grid and make it visible.
    local turnQueueSizeX;
    local turnQueueSizeY;
    turnQueueSizeX = Controls.TurnQueueStack:GetSizeX();
	if (turnQueueSizeX < 200 ) then
		turnQueueSizeX = 200;
	end	
    turnQueueSizeY = Controls.TurnQueueStack:GetSizeY();
    Controls.TurnQueueGrid:SetSizeX(turnQueueSizeX);
    Controls.TurnQueueGrid:SetSizeY(turnQueueSizeY);
    Controls.TurnQueueGridFrame:SetSizeX(turnQueueSizeX);
    Controls.TurnQueueGridFrame:SetSizeY(turnQueueSizeY);
    Controls.TurnQueueGrid:SetHide(false);
    
    -- Resize overall multiplayer hud elements stack
    Controls.MultiplayerStack:CalculateSize(); 
    Controls.MultiplayerStack:ReprocessAnchoring();

end


-------------------------------------------------------------------------
-- Static Teams List Functions
-------------------------------------------------------------------------
function BuildStaticTeamForPlayer(pPlayer)
    if( pPlayer:IsAlive() ) then
        local iTeam = pPlayer:GetTeam();
        local pTeam = Teams[ iTeam ];
        
        if( pTeam:GetNumMembers() == 1 ) then
            g_TeamData[ iTeam ] = pPlayer;
        else
            if( g_TeamData[ iTeam ] == nil ) then
                g_TeamData[ iTeam ] = {};
            end
            table.insert( g_TeamData[ iTeam ], pPlayer );
        end
    end
end

function BuildStaticTeamsList()
	-- Add teams for all major civs
    for iPlayer = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local pPlayer = Players[ iPlayer ];
		BuildStaticTeamForPlayer(pPlayer);
    end
    
    -- Add a team for the barbarians
    local pBarbPlayer = Players[ GameDefines.ALIEN_PLAYER ];
    BuildStaticTeamForPlayer(pBarbPlayer);
end

-------------------------------------------------------------------------
-- Turn Timer Functions
-------------------------------------------------------------------------
function showEndTurnTimer()
	return Game.IsOption(GameOptionTypes.GAMEOPTION_END_TURN_TIMER_ENABLED);
end


-------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------

----------------------------------------------
function OnActivePlayerTurnEnd()
	turnEnded = true;
end
Events.ActivePlayerTurnEnd.Add( OnActivePlayerTurnEnd );

----------------------------------------------
function OnRemotePlayerTurnEnd()
    -- Someone changed their player turn end status.  Update our end turn status because this event could be for us.
    local pPlayer = GetPlayer();
    if( pPlayer:HasReceivedNetTurnComplete() or not pPlayer:IsAlive() or not pPlayer:IsTurnActive() ) then
		turnEnded = true;
	else
		turnEnded = false;
	end
	UpdateTurnQueue();
end
Events.RemotePlayerTurnEnd.Add( OnRemotePlayerTurnEnd );

----------------------------------------------
function OnEndTurnTimerUpdate(percentComplete)
	if( turnEnded == true ) then
		Controls.EndTurnTimeMeter_TurnEnded:SetHide( false );
		Controls.EndTurnTimeMeter_TurnEnded:SetPercents( percentComplete, percentComplete );
		Controls.EndTurnTimeMeter:SetHide( true );
		Controls.EndTurnTimerButton:SetToolTipString(TurnTimerWaitingTooltipString);
		Controls.EndTurnTimerMyTurnAnim:SetHide( true );
	else
		Controls.EndTurnTimeMeter_TurnEnded:SetHide( true );
		Controls.EndTurnTimeMeter:SetHide( false );
		Controls.EndTurnTimeMeter:SetPercents( percentComplete, percentComplete );
		Controls.EndTurnTimerButton:SetToolTipString(TurnTimerActiveTooltipString);
		Controls.EndTurnTimerMyTurnAnim:SetHide( false );
	end
	timeLeft = math.ceil(getEndTurnTimerLength() - (getEndTurnTimerLength() * percentComplete));
	if timeLeft < 1 then
		timeLeft = 0;
	end
	
	-- Format the time remaining string based on how much time we have left.
	-- We manually floor our values using floor and % operations to prevent the localization system 
	-- from rounding the values up.
	local secs = timeLeft % 60;
	local mins = timeLeft / 60;
	local hours = timeLeft / 3600;
	local days = timeLeft / 86400;
	if(days >= 1) then
		-- Days remaining
		days = math.floor(days);
		hours = hours % 24; -- cap hours
		Controls.TimerCountDown:LocalizeAndSetText("TXT_KEY_TIME_DAYS_HOURS", days, hours);
	elseif(hours >= 1) then
		-- hours left
		hours = math.floor(hours);
		mins = mins % 60; -- cap mins
		Controls.TimerCountDown:LocalizeAndSetText("TXT_KEY_TIME_HOURS_MINUTES", hours, mins);
	elseif(mins >= 1) then
		-- mins left
		mins = math.floor(mins);
		Controls.TimerCountDown:LocalizeAndSetText("TXT_KEY_TIME_MINS_SECONDS", mins, secs);
	else
		-- secs left
		Controls.TimerCountDown:LocalizeAndSetText("TXT_KEY_TIME_SECONDS", secs);
	end
		
	-- Resize Turn Time Text Panel
	local timeTextSizeX;
  local timeTextSizeY;
  local padSizeX = 40;
  local padSizeY = 20;
  timeTextSizeX = Controls.TimerCountDown:GetSizeX() + padSizeX;
  timeTextSizeY = Controls.TimerCountDown:GetSizeY() + padSizeY;
  --Controls.TurnTimeRoot:SetSizeX(timeTextSizeX);
  --Controls.TurnTimeRoot:SetSizeY(timeTextSizeY);
  --Controls.TurnTimeGridFrame:SetSizeX(timeTextSizeX);
  --Controls.TurnTimeGridFrame:SetSizeY(timeTextSizeY);
  --Controls.TurnTimeRoot:ReprocessAnchoring();
  
  -- Resize overall multiplayer hud elements stack because we resized the Turn Time Panel.
  Controls.MultiplayerStack:CalculateSize(); 
  Controls.MultiplayerStack:ReprocessAnchoring();
end
Events.EndTurnTimerUpdate.Add(OnEndTurnTimerUpdate);

----------------------------------------------
function OnPlayerChangedEvent()
	if not Controls.TurnTimeRoot:IsHidden() then
		OnEndTurnTimerUpdate(0);
	end
end
Events.GameplaySetActivePlayer.Add( OnPlayerChangedEvent );

----------------------------------------------
-- A player's AI processing has begun.
function OnAITurnStart(iPlayerID, szTag)
	--This also indicates that this player's turn is active.  Update the turn queue for them.
	UpdateTurnQueueForPlayerID(iPlayerID);
end
Events.AIProcessingStartedForPlayer.Add( OnAITurnStart );

----------------------------------------------
-- A player's AI processing has finished.
function OnAITurnEnd(iPlayerID, szTag)

	
	--This also indicates that this player's turn is inactive.  Update the turn queue for them.
	UpdateTurnQueueForPlayerID(iPlayerID);
end
Events.AIProcessingEndedForPlayer.Add( OnAITurnEnd );

----------------------------------------------
-- Human player's turn (remote or local)
function OnActivePlayerTurnStart()
	-- Show the turn timer if needed
	turnEnded = false;
	
	-- Play "It's Your Turn" Sound in multiplayer games.
	if(PreGame.IsMultiplayerGame()) then
		Events.AudioPlay2DSound("AS2D_EVENT_ACTIVE_PLAYER_TURN_START");
	end
end
Events.ActivePlayerTurnStart.Add( OnActivePlayerTurnStart );

----------------------------------------------
-- Update Turn Queue (for all players)
function UpdateTurnQueue()
    for iPlayer, controlTable in pairs( g_TurnQueueEntries ) do
        UpdateTurnQueueData( Players[ iPlayer ], controlTable );
    end
    
    -- sort players based on turn order
    Controls.TurnQueueStack:SortChildren( TurnQueueSort );
end
Events.NewGameTurn.Add( UpdateTurnQueue );

----------------------------------------------
function ShowHide( isHide )
	Controls.TurnTimeRoot:SetHide(not showEndTurnTimer());
end
ContextPtr:SetShowHideHandler( ShowHide );

----------------------------------------------
function OnUpdateUI( type )
	--This should be SystemUpdateUIType.ScreenResize but the new CivBE renderer split most of the SystemUpdateUI 
	--events into a seperate events channel that isn't exposed to lua.  The local machine version of
	--SystemUpdateUI only sends SystemUpdateUIType.ReprocessAnchoring on screen resize.
	if( type == SystemUpdateUIType.ReprocessAnchoring ) then
		-- Screen resolution changed.
		CalcScreenSizes(); -- recalc sizes for elements.
		BuildTurnQueue(); -- rebuild the turn queue.
	end
end
Events.SystemUpdateUI.Add( OnUpdateUI );


-------------------------------------------------------------------------
-- Callbacks
-------------------------------------------------------------------------
function OnEndTurnTimerClicked()
	UI.interruptTurnTimer();
end
Controls.EndTurnTimerButton:RegisterCallback( Mouse.eLClick, OnEndTurnTimerClicked );





-------------------------------------------------------------------------
-- Initial Execution
-------------------------------------------------------------------------
CalcScreenSizes();
BuildStaticTeamsList();
BuildTurnQueue();

