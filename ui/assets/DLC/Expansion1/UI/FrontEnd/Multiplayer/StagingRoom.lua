-- ===========================================================================
--
--	Staging Room Screen
--	(Really the "Lobby" of a multiplayer game, where players meet up to get started.)
--
-- ===========================================================================
include( "InstanceManager" );
include( "IconSupport" );
include( "SupportFunctions"  );
include( "TabSupport" );
include( "UniqueBonuses" );
include( "MPGameOptions" );
include( "TurnStatusBehavior" ); -- for turn status button behavior
include( "VoiceChatLogic" );



-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local m_debugShowAll = false;	-- When set, show all element despite actual state (for laying out components)

local MAX_TEAMS		 = 8;		-- More than max?

-- slot type pulldown options for the local player
local g_localSlotTypeOptions = {	"TXT_KEY_SLOTTYPE_OPEN", 
									"TXT_KEY_SLOTTYPE_OBSERVER" }

-- slot type pulldown options for non-local players
local g_slotTypeOptions = { "TXT_KEY_SLOTTYPE_OPEN", 
							"TXT_KEY_SLOTTYPE_HUMANREQ", 
							"TXT_KEY_SLOTTYPE_AI",
							"TXT_KEY_SLOTTYPE_OBSERVER",
							"TXT_KEY_SLOTTYPE_CLOSED" }
														
-- Associates an int value with our slotTypes so that we can index them in different pulldowns  											
local g_slotTypeData = {};
g_slotTypeData["TXT_KEY_SLOTTYPE_OPEN"]		= { tooltip = "TXT_KEY_SLOTTYPE_OPEN_TT",		index=0 };
g_slotTypeData["TXT_KEY_SLOTTYPE_HUMANREQ"]	= { tooltip = "TXT_KEY_SLOTTYPE_HUMANREQ_TT",	index=1 };
g_slotTypeData["TXT_KEY_PLAYER_TYPE_HUMAN"]	= { tooltip = "TXT_KEY_SLOTTYPE_HUMAN_TT",		index=2 };
g_slotTypeData["TXT_KEY_SLOTTYPE_AI"]		= { tooltip = "TXT_KEY_SLOTTYPE_AI_TT",			index=3 };
g_slotTypeData["TXT_KEY_SLOTTYPE_OBSERVER"]	= { tooltip = "TXT_KEY_SLOTTYPE_OBSERVER_TT",	index=4 };
g_slotTypeData["TXT_KEY_SLOTTYPE_CLOSED"]	= { tooltip = "TXT_KEY_SLOTTYPE_CLOSED_TT",		index=5 };		

local hoursStr				= Locale.ConvertTextKey( "TXT_KEY_HOURS" );
local secondsStr			= Locale.ConvertTextKey( "TXT_KEY_SECONDS" );	
local PlayerConnectedStr	= Locale.ConvertTextKey( "TXT_KEY_MP_PLAYER_CONNECTED" );
local PlayerConnectingStr	= Locale.ConvertTextKey( "TXT_KEY_MP_PLAYER_CONNECTING" );
local PlayerNotConnectedStr = Locale.ConvertTextKey( "TXT_KEY_MP_PLAYER_NOTCONNECTED" );	

local g_modsActivating = false;						


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_SlotInstances		= {};
local m_ChatInstances		= {};
local m_civTraits			= {};

local g_AdvancedOptionIM	= InstanceManager:new( "GameOption", "Text", Controls.AdvancedOptions );
local g_AdvancedOptionsList = {};

local m_HostID;
local m_bIsHost;
local m_NextSlotToBuild;

local m_MaxPlayerNum		= 12; 	
local m_PlayerNames			= {};
local m_bLaunchReady		= false;
local m_bTeamsValid			= false;
local m_bEditOptions		= false;	-- Tabs
local m_bInit				= false;
local g_fCountdownTimer		= -1;		-- Start game countdown timer.  Set to -1 when not in use.
local g_fCountdownTickTime	= -1;		-- when was the last time we make a countdown tick sound?

																	
-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-------------------------------------------------
-- Determine if the screen is for the dedicated server ingame screen										
-------------------------------------------------
function IsInGameScreen()
	if(	PreGame.GameStarted() 
			and Matchmaking.IsHost() 
			and PreGame.GetSlotStatus(Matchmaking.GetLocalID()) == SlotStatus.SS_OBSERVER ) then
			return true;
	end
	
	return false;
end

-------------------------------------------------
-- retrieve player names
-------------------------------------------------
function BuildPlayerNames()
    local playerList = Matchmaking.GetPlayerList();
    
    if( playerList ~= nil ) then
        m_PlayerNames = {};
        
        for i = 1, #playerList do
            m_PlayerNames[ playerList[i].playerID ] = playerList[i].playerName;
        end
    end
end


-------------------------------------------------
-------------------------------------------------
function OnEditHost()
    UIManager:PushModal( Controls.SetCivNames );
	LuaEvents.SetCivNameEditSlot(0);
end
Controls.LocalEditButton:RegisterCallback( Mouse.eLClick, OnEditHost );

-------------------------------------------------
-------------------------------------------------
function ShowHideExitButton()
	local bShow = IsInGameScreen();
	Controls.ExitButton:SetHide( not bShow );
end

-------------------------------------------------
-------------------------------------------------
function OnExitGame()
	Events.UserRequestClose();
end
Controls.ExitButton:RegisterCallback( Mouse.eLClick, OnExitGame );

-------------------------------------------------
-------------------------------------------------
function ShowHideBackButton()
	local bShow = not IsInGameScreen();
	Controls.BackButton:SetHide( not bShow );
end

-------------------------------------------------
-------------------------------------------------
function ShowHideInviteButton()
	local bShow = PreGame.IsInternetGame() and not Network.IsDedicatedServer();
	Controls.InviteButton:SetHide( not bShow );
end
-------------------------------------------------
-------------------------------------------------
function OnInviteButton()
    Steam.ActivateInviteOverlay();
end
Controls.InviteButton:RegisterCallback( Mouse.eLClick, OnInviteButton );

-------------------------------------------------
-------------------------------------------------
function ShowHideSaveButton()
	local bDisable = g_fCountdownTimer ~= -1; -- Disable the save game button while the countdown is active.
	local bShow = Matchmaking.IsHost();
	Controls.SaveButton:SetHide(not bShow);
	if( bDisable ) then
		Controls.SaveButton:SetDisabled( true );
		Controls.SaveButton:SetAlpha( 0.5 );
	else
		Controls.SaveButton:SetDisabled( false );
		Controls.SaveButton:SetAlpha( 1.0 );
	end
  
	-- Only show the game configuration tooltip if we'd be saving the game configuration vs. an actual game save.
	if(PreGame.GameStarted()) then 
		Controls.SaveButton:LocalizeAndSetToolTip( "" );
	else
		Controls.SaveButton:LocalizeAndSetToolTip( "TXT_KEY_SAVE_GAME_CONFIGURATION_TT" );
	end

	Controls.LowerButtonStack:CalculateSize();
	Controls.LowerButtonStack:ReprocessAnchoring();
end
-------------------------------------------------
-------------------------------------------------
function OnSaveButton()
    UIManager:QueuePopup( Controls.SaveMenu, PopupPriority.SaveMenu );
end
Controls.SaveButton:RegisterCallback( Mouse.eLClick, OnSaveButton );


--[[ ??TRON remove, no strategic view in CivBE

function ShowHideStrategicViewButton()
	local bShow = IsInGameScreen();
	Controls.StrategicViewButton:SetHide( not bShow );
end

function OnStrategicView()
	local eViewType = GetGameViewRenderType();
	if (eViewType == GameViewTypes.GAMEVIEW_NONE) then
		SetGameViewRenderType(GameViewTypes.GAMEVIEW_STANDARD);			
	else
		SetGameViewRenderType(GameViewTypes.GAMEVIEW_NONE);
	end
end
Controls.StrategicViewButton:RegisterCallback( Mouse.eLClick, OnStrategicView );
]]

-------------------------------------------------
-------------------------------------------------
function OnCancel()
	Controls.RemoveButton:SetHide(true);

	PreGame.SetLeaderName( Matchmaking.GetLocalID(), "" );
	PreGame.SetCivilizationDescription( Matchmaking.GetLocalID(), "" );
	PreGame.SetCivilizationShortDescription( Matchmaking.GetLocalID(), "" );
	PreGame.SetCivilizationAdjective( Matchmaking.GetLocalID(), "" );
	
	local civIndex = PreGame.GetCivilization( Matchmaking.GetLocalID() );
    if( civIndex ~= -1 ) then
        civ = GameInfo.Civilizations[ civIndex ];

        -- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		local leaderDescription = leader.Description;
		
		PlayerLeader = Locale.ConvertTextKey( leaderDescription );
		PlayerCiv = Locale.ConvertTextKey( civ.ShortDescription );
		Controls.Title:SetText( Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER_CIV", Locale.ConvertTextKey( leaderDescription ), Locale.ConvertTextKey( civ.ShortDescription ) ) );
	else
		PlayerLeader = Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER" );
        PlayerCiv = Locale.ConvertTextKey( "TXT_KEY_RANDOM_SPONSOR" );
        Controls.Title:SetText( Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER_CIV", PlayerLeader, PlayerCiv ) );

	end
end
Controls.RemoveButton:RegisterCallback( Mouse.eLClick, OnCancel );


-------------------------------------------------
-- Context OnUpdateCountdown
-------------------------------------------------
function OnUpdateCountdown( fDTime )
	-- OnUpdateCountdown only runs when the game start countdown is ticking down.
	g_fCountdownTimer = g_fCountdownTimer - fDTime;
	if( not Network.IsEveryoneConnected() ) then
		-- not all players are connected anymore.  This is probably due to a player join in progress.
		StopCountdown();
		ContextPtr:SetUpdate( nil );

	elseif( g_fCountdownTimer <= 0 ) then
			-- Timer elapsed, launch the game if we're the host.
	    if(m_bIsHost) then
				LaunchGame();
			end
			
			StopCountdown();
	else
		local intTime = math.floor(g_fCountdownTimer);
		if( g_fCountdownTimer < g_fCountdownTickTime) then
			g_fCountdownTickTime = g_fCountdownTickTime-1; -- set countdown tick for next second.
			Events.AudioPlay2DSound( "AS2D_INTERFACE_MULTIPLAYER_MATCH_TICK_COUNTDOWN" );
		end
		local countdownString = Locale.ConvertTextKey("TXT_KEY_GAMESTART_COUNTDOWN_FORMAT", intTime );
		Controls.CountdownButton:SetHide(false);
		Controls.CountdownButton:SetText( countdownString );
	end
end

-------------------------------------------------
-- Start Game Launch Countdown
-------------------------------------------------
function StartCountdown()
	g_fCountdownTimer = 10;
	g_fCountdownTickTime = g_fCountdownTimer - 3; -- start countdown ticks in 3 seconds.
	ContextPtr:SetUpdate( OnUpdateCountdown );
	Events.AudioPlay2DSound( "AS2D_INTERFACE_MULTIPLAYER_MATCH_START_COUNTDOWN" );	
	Controls.BackButton:SetDisabled(true);
end

-------------------------------------------------
-- Stop Game Launch Countdown
-------------------------------------------------
function StopCountdown()
	Controls.CountdownButton:SetHide(true);
	g_fCountdownTimer = -1;
	ContextPtr:ClearUpdate();
	Controls.BackButton:SetDisabled(false);
end


-------------------------------------------------
-- Launch Game
-------------------------------------------------
function LaunchGame()

	if (PreGame.IsHotSeatGame()) then
		-- In case they changed the DLC.  This won't do anything if it is already setup properly.
		local prevCursor = UIManager:SetUICursor( 1 );
		Modding.ActivateAllowedDLC();
		UIManager:SetUICursor( prevCursor );
	end
	Matchmaking.LaunchMultiplayerGame();

end
Controls.LaunchButton:RegisterCallback( Mouse.eLClick, LaunchGame );

-------------------------------------------------
-------------------------------------------------
function GetPlayerIDBySelectionIndex(selectionIndex)
	if(selectionIndex == 0) then
		return Matchmaking.GetLocalID();
	end

	return m_SlotInstances[selectionIndex].playerID;
end

-------------------------------------------------
-------------------------------------------------
function CivSelected( selectionIndex, civID )
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	if( playerID >= 0 ) then
		PreGame.SetCivilization( playerID, civID );
		Network.BroadcastPlayerInfo();
		UpdateDisplay();
	end
end


-------------------------------------------------
-------------------------------------------------
function InviteSelected( selectionIndex, playerChoiceID )

	local slotInstance = m_SlotInstances[ selectionIndex ];

	if slotInstance then

		if ( playerChoiceID == -1 ) then -- AI

    		slotInstance.InvitePulldown:GetButton():LocalizeAndSetText( "TXT_KEY_AI_NICKNAME" );

		else -- TODO: Send Invite and Lock Slot

			slotInstance.InvitePulldown:GetButton():SetText( Locale.ConvertTextKey("TXT_KEY_WAITING_FOR_INVITE_RESPONSE", "TEMP" ) );
		end

	end
end


-------------------------------------------------
-------------------------------------------------
function OnKickPlayer( selectionIndex )
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	UIManager:PushModal(Controls.ConfirmKick, true);	
	local playerName = m_SlotInstances[selectionIndex].PlayerNameLabel:GetText();
	LuaEvents.SetKickPlayer(playerID, playerName);
end

-------------------------------------------------
-------------------------------------------------
function OnEditPlayer( selectionIndex )
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	UIManager:PushModal(Controls.SetCivNames);
	LuaEvents.SetCivNameEditSlot(playerID);
	UpdateDisplay();
end


-- ===========================================================================
function OnSwapPlayer( selectionIndex )
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	Network.SetPlayerDesiredSlot(playerID);
end


-- ===========================================================================
function OnReadyCheck( bChecked )

	local TEXTURE_OFFSET_CHECK_ON	= 0;
	local TEXTURE_OFFSET_CHECK_OFF	= 64 * 2;
	local uiButton					= Controls.LocalReadyCheck:GetButton();

	if bChecked then
		uiButton:SetTextureOffsetVal( 0, TEXTURE_OFFSET_CHECK_OFF );
	else
		uiButton:SetTextureOffsetVal( 0, TEXTURE_OFFSET_CHECK_ON );
	end

	PreGame.SetReady( Matchmaking.GetLocalID(), bChecked );
	Network.BroadcastPlayerInfo();
	UpdateDisplay();
	CheckGameAutoStart();	
	ShowHideSaveButton();	
end
Controls.LocalReadyCheck:RegisterCheckHandler( OnReadyCheck );


-- ===========================================================================
function OnSelectTeam( selectionIndex, playerChoiceID )
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	PreGame.SetTeam(playerID, playerChoiceID);
	local slotInstance = m_SlotInstances[selectionIndex];
	local teamID = playerChoiceID + 1; -- Real programmers count from zero.
	if( slotInstance ~= nil ) then
		slotInstance.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", teamID );
	else
		Controls.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", teamID );
	end
	Network.BroadcastPlayerInfo();
	
	DoCheckTeams();
end


--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
function DoCheckTeams()

    m_bTeamsValid = false;
    local teamTest = -1;
    
    -- Find the team of the first valid player.  We can't simply use the host's team because they could be an observer.
		-- Human required slots count towards the team check but do not block game start.
    for i = 0, m_MaxPlayerNum do
			if( PreGame.GetSlotStatus( i ) == SlotStatus.SS_COMPUTER 
			or PreGame.GetSlotStatus( i ) == SlotStatus.SS_TAKEN 
			or (PreGame.GetSlotStatus( i ) == SlotStatus.SS_OPEN -- human required slot
				and PreGame.GetSlotClaim( i ) == SlotClaim.SLOTCLAIM_RESERVED) ) then
				teamTest = PreGame.GetTeam( i );
        break;
    	end
    end
    
    for i = 0, m_MaxPlayerNum do
        if( PreGame.GetSlotStatus( i ) == SlotStatus.SS_COMPUTER 
				or PreGame.GetSlotStatus( i ) == SlotStatus.SS_TAKEN
				or (PreGame.GetSlotStatus( i ) == SlotStatus.SS_OPEN -- human required slot
					and PreGame.GetSlotClaim( i ) == SlotClaim.SLOTCLAIM_RESERVED) ) then
        	if( PreGame.GetTeam( i ) ~= teamTest ) then
        	    m_bTeamsValid = true;
        	    break;
        	end
    	end
    end
    
end


-------------------------------------------------
-------------------------------------------------
function OnHandicapTeam( selectionIndex, handicap )
	local listingEntry = m_SlotInstances[selectionIndex];

	if(listingEntry ~= nil) then
		listingEntry.HandicapLabel:LocalizeAndSetText( GameInfo.HandicapInfos[handicap].Description );
	else
		Controls.HandicapLabel:LocalizeAndSetText( GameInfo.HandicapInfos[handicap].Description );
	end
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	PreGame.SetHandicap(playerID, handicap);
	Network.BroadcastPlayerInfo();
end

-------------------------------------------------
-------------------------------------------------
function OnPlayerName( selectionIndex, id )
	local playerID = GetPlayerIDBySelectionIndex(selectionIndex);
	if (id == 0) then 
		PreGame.SetSlotStatus( playerID, SlotStatus.SS_COMPUTER );
		PreGame.SetHandicap( playerID, 1 );
		PreGame.SetNickName( playerID, "" );
	else
		PreGame.SetSlotStatus( playerID, SlotStatus.SS_TAKEN );
		if (PreGame.GetNickName(playerID) == "") then
			PreGame.SetNickName( playerID, Locale.ConvertTextKey( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID + 1 ) );
		end
	end
	Network.BroadcastPlayerInfo();

end

-------------------------------------------------
-------------------------------------------------
function SetSlotToHuman(playerID)
	-- Sets the given playerID slot to be human. Assumes that slot hasn't already been done so.
	PreGame.SetSlotStatus( playerID, SlotStatus.SS_TAKEN );
	PreGame.SetHandicap( playerID, 3 );
	if (PreGame.GetNickName(playerID) == "") then
		PreGame.SetNickName( playerID, Locale.ConvertTextKey( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID + 1 ) );
	end
end

function OnSlotType( playerID, id )
	-- NOTE: Slot type pulldowns store the slot's playerID rather than the selection Index in their voids.
	--print("OnSlotType ID:" .. id);
	--print("	Player ID:" .. playerID);
	local resetReadyStatus = false; -- In most cases, changing a slottype resets the player's ready status.

	if(id == g_slotTypeData["TXT_KEY_SLOTTYPE_OPEN"].index) then
		-- TXT_KEY_SLOTTYPE_OPEN - Open human player slot.
		if(not Network.IsPlayerConnected(playerID)) then
			-- Can't open a slot occupied by a human.
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_OPEN );
			PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_ASSIGNED );		
			resetReadyStatus = true;
		end
	elseif(id == g_slotTypeData["TXT_KEY_PLAYER_TYPE_HUMAN"].index) then
		-- TXT_KEY_PLAYER_TYPE_HUMAN
		if(PreGame.GetSlotStatus( playerID ) ~= SlotStatus.SS_TAKEN) then
			SetSlotToHuman(playerID);
			resetReadyStatus = true;
		end
	elseif(id == g_slotTypeData["TXT_KEY_SLOTTYPE_HUMANREQ"].index) then
		-- TXT_KEY_SLOTTYPE_HUMANREQ 
		if(not Network.IsPlayerConnected(playerID)) then
			-- Don't open the slot if someone is already occupying it.
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_OPEN );	
			resetReadyStatus = true;
		elseif(Network.IsPlayerConnected(playerID) and PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OBSERVER) then
			-- Setting human required on an human occupied observer slot switches them to normal player mode.
			SetSlotToHuman(playerID);
			resetReadyStatus = true;
		end
		PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_RESERVED );
	elseif(id == g_slotTypeData["TXT_KEY_SLOTTYPE_AI"].index) then
		-- TXT_KEY_SLOTTYPE_AI
		local bCanEnableAISlots = PreGame.GetMultiplayerAIEnabled();
		if(bCanEnableAISlots and not Network.IsPlayerConnected(playerID)) then
			-- only switch to AI if AI are enabled in multiplayer.
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_COMPUTER );
    	PreGame.SetHandicap( playerID, 1 );
    	resetReadyStatus = true;
			if ( PreGame.IsHotSeatGame() ) then
				-- Reset so the player can force a rebuild
				PreGame.SetNickName( playerID, "" );
				PreGame.SetLeaderName( playerID, "" );
				PreGame.SetCivilizationDescription( playerID, "" );
				PreGame.SetCivilizationShortDescription( playerID, "" );
				PreGame.SetCivilizationAdjective( playerID, "" );
			end
		end
	elseif(id == g_slotTypeData["TXT_KEY_SLOTTYPE_OBSERVER"].index) then
		-- TXT_KEY_SLOTTYPE_OBSERVER
		PreGame.SetSlotStatus( playerID, SlotStatus.SS_OBSERVER );
		resetReadyStatus = true;
	elseif(id == g_slotTypeData["TXT_KEY_SLOTTYPE_CLOSED"].index) then
		-- TXT_KEY_SLOTTYPE_CLOSED
		if(not Network.IsPlayerConnected(playerID)) then
			PreGame.SetSlotStatus( playerID, SlotStatus.SS_CLOSED );
			PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_ASSIGNED );
			resetReadyStatus = true;
		end
	end
	
	if(resetReadyStatus) then
		PreGame.SetReady(playerID, false);
	end	

	UpdateDisplay();
	Network.BroadcastPlayerInfo();
end


-------------------------------------------------
-- Refresh Player List
-------------------------------------------------
function RefreshPlayerList()
    m_HostID  = Matchmaking.GetHostID();
    m_bIsHost = Matchmaking.IsHost();
	m_bLaunchReady = true;
	
	-- Get the Current Player List
	local playerTable = Matchmaking.GetPlayerList();
	
	for i = 1, #m_SlotInstances do
		m_SlotInstances[i].Root:SetHide( true );
	end

	-- Display Each Player
	if( playerTable ) then
		for i, playerInfo in ipairs( playerTable ) do
		  local playerID = playerInfo.playerID;
		    
		  m_SlotInstances[i].playerID = playerTable[i].playerID;

			if( playerInfo.playerID == Matchmaking.GetLocalID() ) then
				UpdateLocalPlayer( playerInfo );
			else	
				UpdatePlayer( m_SlotInstances[ i ], playerInfo );
			end
		end
	end

	Controls.NameInfoStack:CalculateSize();
	Controls.SlotStack:CalculateSize();
	Controls.SlotStack:ReprocessAnchoring();
	Controls.ListingScrollPanel:CalculateInternalSize();
	Controls.ListingScrollPanel:ReprocessAnchoring();	
end


-------------------------------------------------
-------------------------------------------------
function UpdatePlayer( slotInstance, playerInfo )

	local bIsPitboss = PreGame.GetGameOption("GAMEOPTION_PITBOSS");
	
	-- Player Listing Entry
	if(slotInstance ~= nil) then
		slotInstance.Root:SetHide( false );

		local playerName = playerInfo.playerName or Locale.ConvertTextKey( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", playerID + 1);
		local playerID   = playerInfo.playerID;

		--------------------------------------------------------------
		-- Set Team
		local teamID = PreGame.GetTeam(playerID) + 1; -- Real programmers count from zero.
		slotInstance.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", teamID );
		--------------------------------------------------------------
		
		--------------------------------------------------------------
		-- Set Handicap
		local tHandicap = GameInfo.HandicapInfos( "ID = '" .. PreGame.GetHandicap( playerID ) .. "'" )();
		if (tHandicap ~= nil) then
			slotInstance.HandicapLabel:LocalizeAndSetText( tHandicap.Description );
		end
		--------------------------------------------------------------
		
		-- Update Turn Status
		UpdateTurnStatusForPlayerID(playerID);
					
		-- Refresh slottype pulldown
		PopulateSlotTypePulldown( slotInstance.SlotTypePulldown, playerID, g_slotTypeOptions );
		
		-- Update Civ Attributes
		UpdateGameInfoIcon( slotInstance.CivIcon,			GameInfo.Civilizations,	PreGame.GetCivilization(playerID),		"GAME_SETUP_ATLAS", 2);
		UpdateGameInfoIcon( slotInstance.ColonistIcon,		GameInfo.Colonists,		PreGame.GetLoadoutColonist(playerID),	"GAME_SETUP_ATLAS", 4);
		UpdateGameInfoIcon( slotInstance.SpacecraftIcon,	GameInfo.Spacecraft,	PreGame.GetLoadoutSpacecraft(playerID), "GAME_SETUP_ATLAS", 1);
		UpdateGameInfoIcon( slotInstance.CargoIcon,			GameInfo.Cargo,			PreGame.GetLoadoutCargo(playerID),		"GAME_SETUP_ATLAS", 0);
		
	
        local bIsHuman  = (PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_TAKEN);
        local bIsLocked = (PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_RESERVED) or
                          (PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_ASSIGNED);
        local bIsClosed = (PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_CLOSED);
        local bIsObserver = PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OBSERVER;

				-- You can't change this slot's options.
        local bIsDisabled = (	(PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_CLOSED) or 
								(PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OBSERVER) or
								((PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OPEN)
									and not (PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_RESERVED)) );
														
		local bIsEmptyHumanRequiredSlot = (PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OPEN 
										 and PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_RESERVED);
        local bIsHotSeat = PreGame.IsHotSeatGame();
        local bIsReady;
        local bCantChangeCiv;		-- Can't change civilization
        local bCantChangeTeam;	-- can't change teams
        
		local bSlotTypeDisabled;

        if( bIsHuman ) then	

			slotInstance.InvitePulldown:GetButton():SetText( Locale.ToUpper(playerName) );
					
			-- You can only change the slot's civ/team if you're in hotseat mode.
			if( bIsHotSeat ) then 
				bIsReady = PreGame.IsReady( m_HostID ); -- same ready status as host (local player)
				bCantChangeCiv = PreGame.IsReady( m_HostID );
				bCantChangeTeam = PreGame.IsReady( m_HostID );
			else
				bIsReady = PreGame.IsReady( playerID );
				bCantChangeCiv = true;
				bCantChangeTeam = not m_bIsHost or PreGame.IsReady( m_HostID ); -- The host can override human's team selection
			end
					
			bSlotTypeDisabled = not m_bIsHost or PreGame.IsReady( m_HostID ); -- The host can override slot types
        else
			bIsReady = not bIsEmptyHumanRequiredSlot and -- Empty human required slots block game readiness.
						(bIsObserver and (PreGame.IsReady( playerID ) or (not Network.IsPlayerConnected( playerID ) and PreGame.IsReady( m_HostID ))) or -- human observers manually ready up if occupied or ready up with the host if empty.
						(not bIsObserver and PreGame.IsReady( m_HostID )) or -- non-observers share ready status with the host.
						(PreGame.GetLoadFileName() ~= "" and PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_CLOSED)); -- prevent closed player slots from blocking game startup when loading save games -tsmith
            
			if( m_bIsHost ) then
				bSlotTypeDisabled = PreGame.IsReady( m_HostID );
						
				-- Host can't change the team/civ of open/closed slots.
				bCantChangeCiv = bIsDisabled or PreGame.IsReady( m_HostID ) or bIsEmptyHumanRequiredSlot;
				bCantChangeTeam = bIsDisabled or PreGame.IsReady( m_HostID );
			else
				bSlotTypeDisabled = true;
				bCantChangeCiv = true;
				bCantChangeTeam = true;
			end
          
			if (Network.IsPlayerConnected(playerID)) then 
				-- Use the player name if a player is network connected to the game (observers only)
				slotInstance.InvitePulldown:GetButton():SetText( Locale.ToUpper(playerName) );
			else
				-- The default for non-humans is to display the slot type as the player name.
				local playerNameTextKey = GetSlotTypeString(playerID);
				playerName = Locale.ConvertTextKey(playerNameTextKey);
				slotInstance.InvitePulldown:GetButton():LocalizeAndSetText( Locale.ToUpper(playerName) );
			end      
        end


		-- Set player/host label area, with truncation...
		local bHideHostLabel = playerID ~= m_HostID;
		slotInstance.HostLabel:SetHide( bHideHostLabel );
		local playerLabelMaxWidth = 480;
		if (not bHideHostLabel) then  
			playerLabelMaxWidth = playerLabelMaxWidth - Controls.HostLabel:GetSizeX();
		end
		TruncateString( slotInstance.PlayerNameLabel, playerLabelMaxWidth, Locale.ToUpper( playerName ) ); 
		slotInstance.PlayerNameLabel:SetToolTipString( playerName );

        
        if(PreGame.GameStarted()) then 
			-- Can't change anything after the game has been started.
			bCantChangeCiv = true;
			bCantChangeTeam = true;
			bSlotTypeDisabled = true;
		end
        
		-- You can't auto launch the game if someone isn't ready.
        if( not bIsReady ) then
			m_bLaunchReady = false;
        end
        
        if( bIsDisabled ) then
        	slotInstance.EnableCheck:SetCheck( false );
        	slotInstance.EnableCheck:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_MP_ENABLE_SLOT" ) );	
    	else
        	slotInstance.EnableCheck:SetCheck( true );
        	slotInstance.EnableCheck:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_MP_DISABLE_SLOT" ) );
    	end

    	if( bIsLocked ) then
        	slotInstance.LockCheck:SetCheck( true );
        	slotInstance.LockCheck:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_MP_UNLOCK_SLOT" ) );
    	else
        	slotInstance.LockCheck:SetCheck( false );
            slotInstance.LockCheck:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_MP_LOCK_SLOT" ) );
        end

		local isHideHighlight = not (bIsReady and (bIsObserver or not bIsDisabled));
        slotInstance.ReadyHighlight:SetHide( isHideHighlight );

		slotInstance.PlayerNameLabel:SetHide( false );
		slotInstance.InvitePulldown:SetHide( true ); 
		   
		 		  
		local isSystemReady = (PreGame.GetLoadFileName() ~= "") or PreGame.GameStarted();

		-- Note: You can't change player slot attributes after the game has started.   
		slotInstance.TeamPulldown:SetHide(					(bCantChangeTeam	or	isSystemReady) and not m_debugShowAll );
		slotInstance.SlotTypePulldown:SetHide(				(bSlotTypeDisabled	or	isSystemReady) and not m_debugShowAll );
		slotInstance.CivSelectPulldown:SetDisabled(			(bCantChangeCiv		or	isSystemReady) and not m_debugShowAll );
		slotInstance.ColonistSelectPulldown:SetDisabled(	(bCantChangeCiv		or	isSystemReady) and not m_debugShowAll );
		slotInstance.SpacecraftSelectPulldown:SetDisabled(	(bCantChangeCiv		or	isSystemReady) and not m_debugShowAll );
		slotInstance.CargoSelectPulldown:SetDisabled(		(bCantChangeCiv		or	isSystemReady) and not m_debugShowAll );
    
		-- Hide civ setting for open/closed slots
		slotInstance.TeamLabel:SetHide(bIsDisabled);
		slotInstance.CivSelectPulldown:SetHide(bIsDisabled);
		slotInstance.ColonistSelectPulldown:SetHide(bIsDisabled);
		slotInstance.SpacecraftSelectPulldown:SetHide(bIsDisabled);
		slotInstance.CargoSelectPulldown:SetHide(bIsDisabled);

		if ( bIsHuman ) then
			slotInstance.HandicapLabel:SetHide( false );
			slotInstance.HandicapPulldown:SetHide( bCantChangeCiv and not m_debugShowAll );
			slotInstance.PingTimeLabel:SetHide( false );
		else
			slotInstance.HandicapLabel:SetHide( true );
			slotInstance.HandicapPulldown:SetHide( true and not m_debugShowAll  );
			slotInstance.PingTimeLabel:SetHide( true );
		end

        --slotInstance.DisableBlock:SetHide( not bIsDisabled );
        
		if( m_bIsHost ) then
			if( bIsHotSeat ) then
				slotInstance.KickButton:SetHide( true );
				slotInstance.EditButton:SetHide( bIsDisabled or not bIsHuman );				
				--slotInstance.EnableCheck:SetHide( false );
				slotInstance.PingTimeLabel:SetHide( true );
				slotInstance.LockCheck:SetHide( true );				
			else
				--slotInstance.EnableCheck:SetHide( bIsHuman or bCantChangeCiv );
				slotInstance.LockCheck:SetHide( bIsHuman or bCantChangeCiv );
				slotInstance.KickButton:SetHide( not bIsHuman and not Network.IsPlayerConnected(playerID));
				slotInstance.EditButton:SetHide( true );
			end
		else
			--slotInstance.EnableCheck:SetHide( true );
			slotInstance.LockCheck:SetHide( true );
			slotInstance.KickButton:SetHide( true );
			slotInstance.EditButton:SetHide( true );
		end
		
		-- Handle swap button highlight
		local highlightSwap = Network.GetPlayerDesiredSlot(Matchmaking.GetLocalID()) == playerID; -- We want to switch to this slot
		local flashSwap = Network.GetPlayerDesiredSlot(playerID) == Matchmaking.GetLocalID(); -- They want to switch with us.
		
		local isHidingSwapButton = 
			bIsHotSeat or 
			PreGame.IsReady(Matchmaking.GetLocalID()) or 
			not (PreGame.GetLoadFileName() ~= "" or PreGame.GameStarted()) or -- To avoid user confusion, only show swap button when hot joining or loading a save.
			(PreGame.GetSlotStatus(playerID) == SlotStatus.SS_CLOSED) or 
			(PreGame.GetSlotStatus(playerID) == SlotStatus.SS_OPEN);

		slotInstance.SwapButton:SetHide( isHidingSwapButton );  
		slotInstance.SwapButtonFlashAlpha:SetHide( not flashSwap );  
		slotInstance.SwapHighlight:SetHide( not highlightSwap );  

		if(PreGame.GetSlotStatus(playerID) == SlotStatus.SS_TAKEN) then
			slotInstance.SwapButton:LocalizeAndSetToolTip("TXT_KEY_MP_SWAP_WITH_PLAYER_BUTTON_TT");
		else
			slotInstance.SwapButton:LocalizeAndSetToolTip("TXT_KEY_MP_SWAP_BUTTON_TT");
		end
		  
        --TEMP: S.S, hiding lock since it doesn't do anything and too many people believe it's the cause of MP probs.
        slotInstance.LockCheck:SetHide( true );        
        slotInstance.HostLabel:SetHide( playerID ~= m_HostID );						
        
		 -- Player connected indicator
		if(not bIsHotSeat and (bIsHuman or bIsObserver)) then
			slotInstance.ConnectionStatus:SetHide(false);

			if(Network.IsPlayerHotJoining(playerID)) then
				-- Player is hot joining.
				slotInstance.ConnectionStatus:SetTextureOffsetVal(0,64);
				slotInstance.ConnectionStatus:SetToolTipString( PlayerConnectingStr );
			elseif(Network.IsPlayerConnected(playerID)) then
				-- fully connected
				slotInstance.ConnectionStatus:SetTextureOffsetVal(0,0);
				slotInstance.ConnectionStatus:SetToolTipString( PlayerConnectedStr );
			else
				-- Not connected
				slotInstance.ConnectionStatus:SetTextureOffsetVal(0,192);
				slotInstance.ConnectionStatus:SetToolTipString( PlayerNotConnectedStr );		
			end		

		else
			slotInstance.ConnectionStatus:SetHide(true);
		end
        
        if ( not bIsHotSeat and bIsHuman ) then
			UpdatePingTimeLabel( slotInstance.PingTimeLabel, playerID );
        end
	end

	slotInstance.NameInfoStack:CalculateSize();
	slotInstance.SlotButons:CalculateSize();

end

----------------------------------------------
function UpdateTurnStatusForPlayerID( iPlayerID )
	if(Players ~= nil) then
		local pPlayer = Players[iPlayerID];
		if(iPlayerID == Matchmaking.GetLocalID()) then
			UpdateTurnStatus(pPlayer, Controls.CivIcon, Controls.ActiveTurnAnim, m_SlotInstances);
		else
			local slotInstance = nil;
			for iSlot, slotElement in pairs( m_SlotInstances ) do
				local slotPlayerID = GetPlayerIDBySelectionIndex(iSlot);
				if(slotPlayerID == iPlayerID) then
					slotInstance = slotElement;
					break;
				end
			end
			if(slotInstance ~= nil) then -- minor civs don't have slot instances.
				UpdateTurnStatus(pPlayer, slotInstance.CivIcon, slotInstance.ActiveTurnAnim, m_SlotInstances);
			end
		end
	end
end

-- Here are all the events for which we need to update a given player's turn status.
Events.AIProcessingStartedForPlayer.Add( UpdateTurnStatusForPlayerID );
Events.AIProcessingEndedForPlayer.Add( UpdateTurnStatusForPlayerID );


-- ===========================================================================
function UpdateTurnStatusForAll()
	UpdateTurnStatusForPlayerID(Matchmaking.GetLocalID());
	for iSlot, slotInstance in pairs( m_SlotInstances ) do
		UpdateTurnStatusForPlayerID(slotInstance.playerID);
	end
end
Events.NewGameTurn.Add( UpdateTurnStatusForAll );
Events.RemotePlayerTurnEnd.Add( UpdateTurnStatusForAll );


-- ===========================================================================
function UpdateLocalPlayer( playerInfo )
	
	-- Fill In Slot Info
	local playerName = playerInfo.playerName or Locale.ConvertTextKey( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", Matchmaking.GetLocalID() + 1);
	
	Controls.RemoveButton:SetHide( true );
	
		-- Determine turn completed status.
	UpdateTurnStatusForPlayerID(Matchmaking.GetLocalID());
  	
	-- Set Team
	local teamID = PreGame.GetTeam(Matchmaking.GetLocalID()) + 1; -- Real programmers count from zero.
	Controls.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", teamID );
		
	-- Set Handicap
	Controls.HandicapLabel:LocalizeAndSetText( GameInfo.HandicapInfos( "ID = '" .. PreGame.GetHandicap( Matchmaking.GetLocalID() ) .. "'" )().Description );
	
	-- Refresh slottype pulldown
	PopulateSlotTypePulldown( Controls.SlotTypePulldown, Matchmaking.GetLocalID(), g_localSlotTypeOptions );
 
	-- Update Civ Attributes
	UpdateGameInfoIcon( Controls.CivIcon,			GameInfo.Civilizations, PreGame.GetCivilization(Matchmaking.GetLocalID()),		"GAME_SETUP_ATLAS", 2);
	UpdateGameInfoIcon( Controls.ColonistIcon,		GameInfo.Colonists,		PreGame.GetLoadoutColonist(Matchmaking.GetLocalID()),	"GAME_SETUP_ATLAS", 4);
	UpdateGameInfoIcon( Controls.SpacecraftIcon,	GameInfo.Spacecraft,	PreGame.GetLoadoutSpacecraft(Matchmaking.GetLocalID()), "GAME_SETUP_ATLAS", 1);
	UpdateGameInfoIcon( Controls.CargoIcon,			GameInfo.Cargo,			PreGame.GetLoadoutCargo(Matchmaking.GetLocalID()),		"GAME_SETUP_ATLAS", 0);


	
	local bIsHotSeat = PreGame.IsHotSeatGame();
	local bIsObserver = ( (PreGame.GetSlotStatus( Matchmaking.GetLocalID() ) == SlotStatus.SS_OBSERVER) );

	-----------------------------------------------------------
	-- Ready Button Update
	local lastReadyDisabled = Controls.LocalReadyCheck:IsDisabled();
	if(not m_bTeamsValid) then
		Controls.LocalReadyCheck:LocalizeAndSetToolTip( "TXT_KEY_MP_READY_CHECK_INVAID_TEAMS" );
		Controls.LocalReadyCheck:SetDisabled(true);	
	elseif (not PreGame.CanReadyLocalPlayer()) then
		Controls.LocalReadyCheck:LocalizeAndSetToolTip( "TXT_KEY_MP_READY_CHECK_UNAVAILABLE_DATA_HELP" );	
		Controls.LocalReadyCheck:SetDisabled(true);				
	else
		Controls.LocalReadyCheck:LocalizeAndSetToolTip( "TXT_KEY_MP_READY_CHECK" );	
		Controls.LocalReadyCheck:SetDisabled(false);				
	end
	if(Controls.LocalReadyCheck:IsDisabled() and lastReadyDisabled ~= Controls.LocalReadyCheck:IsDisabled()
		and PreGame.IsReady(Matchmaking.GetLocalID())) then
		-- We just disabled the ability to be ready and we're currently ready, unready ourself.
		PreGame.SetReady( Matchmaking.GetLocalID(), false );
		Network.BroadcastPlayerInfo();
	end

	local bIsReady = PreGame.IsReady( Matchmaking.GetLocalID() );
	Controls.LocalReadyCheck:SetHide(false);
	if( not bIsReady ) then
		m_bLaunchReady = false;
	end
	
	Controls.HotJoinPopup:SetHide(not bIsReady or not Network.IsPlayerHotJoining(Matchmaking.GetLocalID()));
	
	local bCantChangeCiv	= bIsReady or (PreGame.GetLoadFileName() ~= "") or bIsObserver or PreGame.GameStarted();
	local bCantChangeTeam	= bIsReady or (PreGame.GetLoadFileName() ~= "") or bIsObserver or PreGame.GameStarted();
	local bSlotTypeDisabled = bIsReady or (PreGame.GetLoadFileName() ~= "") or bIsHotSeat or Network.IsDedicatedServer() or PreGame.GameStarted();
	
	-- Hide Civ/Team/Handicap labels for observers
	Controls.TeamLabel:SetHide(bIsObserver);
	Controls.HandicapLabel:SetHide(bIsObserver);
	Controls.CivSelectPulldown:SetHide(bIsObserver);
	Controls.ColonistSelectPulldown:SetHide(bIsObserver);
	Controls.SpacecraftSelectPulldown:SetHide(bIsObserver);
	Controls.CargoSelectPulldown:SetHide(bIsObserver);

	Controls.LocalEditButton:SetHide( not bIsHotSeat );
	Controls.LocalReadyCheck:SetCheck( bIsReady );
	Controls.ReadyHighlight:SetHide( not bIsReady );
	Controls.LocalReadyAnim:SetHide( bIsReady );

	-- Set player/host label area, with truncation...
	local bHideHostLabel = (Matchmaking.GetLocalID() ~= m_HostID);
	Controls.HostLabel:SetHide( bHideHostLabel );
	local playerLabelMaxWidth = 480;
	if (not bHideHostLabel) then  
		playerLabelMaxWidth = playerLabelMaxWidth - Controls.HostLabel:GetSizeX();
	end
	TruncateString( Controls.PlayerNameLabel, playerLabelMaxWidth, Locale.ToUpper( playerName ) ); 
	Controls.PlayerNameLabel:SetToolTipString( playerName );

	Controls.TeamPulldown:SetHide( bCantChangeTeam );
	Controls.SlotTypePulldown:SetHide( bSlotTypeDisabled );
	Controls.CivSelectPulldown:SetDisabled( bCantChangeCiv );
	Controls.ColonistSelectPulldown:SetDisabled( bCantChangeCiv );
	Controls.SpacecraftSelectPulldown:SetDisabled( bCantChangeCiv );
	Controls.CargoSelectPulldown:SetDisabled( bCantChangeCiv );
	Controls.HandicapPulldown:SetHide( bCantChangeCiv );
	
end



-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function CanManuallyExitGame()
	
	if (Matchmaking.IsLaunchingGame() ) then
		-- We're the host and we're launching
		return false;
	end

	if( g_fCountdownTimer ~= -1 ) then
		-- Can't manually exit game while the countdown timer is ticking.
		return false;
	end

	if (UI:IsLoadedGame() and not PreGame.IsHotSeatGame()) then
		-- If IsLoadedGame is set in multiplayer, we have already started the 
		-- load game process and can't abort.  This is a hacky use of the 
		-- IsLoadedGame bool based on its current functionality.
		return false;
	end

	return true;
end

function BackButtonClick()
	if (CanManuallyExitGame()) then
		HandleExitRequest();
	end
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );
Controls.HotJoinCancelButton:RegisterCallback( Mouse.eLClick, BackButtonClick );

function OnSerialEventGameInitFinished()
	-- If we get this event on the staging room, we have finished setting up GameCore and we're about 
	-- to transition to the load game state.  Disable the exit buttons so the player knows they can't
	-- leave now!
	-- Note: This event is published normally and therefore has a builtin frame delay.  
	-- 				As such, we need to check CanManuallyExitGame() whenever we process a manual exit game 
	--				request to account for the possible frame delay.
	Controls.BackButton:SetDisabled(true);
	Controls.HotJoinCancelButton:SetDisabled(true);
end
Events.SerialEventGameInitFinished.Add(OnSerialEventGameInitFinished);


-------------------------------------------------
-- Options Button Handler
-------------------------------------------------
function OptionsClick()
	-- Unready the player.
	if(PreGame.IsReady(Matchmaking.GetLocalID())) then
		PreGame.SetReady( Matchmaking.GetLocalID(), false );
		Network.BroadcastPlayerInfo();
	end

	UIManager:QueuePopup( Controls.OptionsMenu_StagingRoom, PopupPriority.OptionsMenu );
end
Controls.OptionsButton:RegisterCallback( Mouse.eLClick, OptionsClick );


-------------------------------------------------
-- Leave the Game
-------------------------------------------------
function HandleExitRequest()
	
	StopCountdown(); -- Make sure there is no countdown going.
	Controls.ChatStack:DestroyAllChildren(); -- delete the chat log.
	
	local isHost = Matchmaking.IsHost();
	Matchmaking.LeaveMultiplayerGame();
	if ( not PreGame.IsHotSeatGame() ) then
		-- Refresh the lobby as we enter it
		if ( PreGame.IsInternetGame() and not isHost ) then
			Matchmaking.RefreshInternetGameList();
		elseif ( not PreGame.IsInternetGame() and not isHost ) then
			Matchmaking.RefreshLANGameList();
		end
	end

	-- Reset the game information
	local bIsInternet = PreGame.IsInternetGame();
	local eGameType = PreGame.GetGameType();
			
	PreGame.Reset();
			
	PreGame.SetInternetGame( bIsInternet );
	PreGame.SetGameType(eGameType);
	PreGame.ResetSlots();

	UIManager:DequeuePopup( ContextPtr );
end


----------------------------------------------------------------
-- Connection Established
----------------------------------------------------------------
function OnConnect( playerID )
    if( ContextPtr:IsHidden() == false ) then
	   	UpdateDisplay();
		BuildPlayerNames();
    	OnChat( playerID, -1, Locale.ConvertTextKey( "TXT_KEY_CONNECTED" ) );
    end
end
Events.ConnectedToNetworkHost.Add( OnConnect );


----------------------------------------------------------------
----------------------------------------------------------------
function OnDisconnectOrPossiblyUpdate()
	if( ContextPtr:IsHidden() == false ) then
		BuildPlayerNames(); -- Player names need to be rebuilt because this event could have been for a player ID swap.
		UpdateDisplay();
		UpdatePageTabView(true);
		ShowHideInviteButton();
		ShowHideSaveButton();
		CheckGameAutoStart(); -- Player disconnects can affect the game start countdown.
	end
end
Events.MultiplayerGamePlayerUpdated.Add( OnDisconnectOrPossiblyUpdate );

----------------------------------------------------------------
Events.MultiplayerGameHostMigration.Add( function(newHost)
	if( ContextPtr:IsHidden() == false and IsInLobby() and Matchmaking.IsHost()) then

		--PreGame.LoadPreGameSettings();
		RefreshMapScripts();
		RefreshDropDownOptions();
		RefreshGameOptions();
		UpdateGameOptionsDisplay();
		SendGameOptionChanged();

		OnDisconnectOrPossiblyUpdate();
	end
end );


----------------------------------------------------------------
----------------------------------------------------------------
function OnDisconnect( playerID )
    if( ContextPtr:IsHidden() == false ) then
		if(Network.IsPlayerKicked(playerID)) then
			OnChat( playerID, -1, Locale.ConvertTextKey( "TXT_KEY_KICKED" ) );
		else
    		OnChat( playerID, -1, Locale.ConvertTextKey( "TXT_KEY_DISCONNECTED" ) );
		end
    	ShowHideInviteButton();
	end
end
Events.MultiplayerGamePlayerDisconnected.Add( OnDisconnect );

----------------------------------------------------------------
----------------------------------------------------------------
function OnHostMigration( playerID )
    if( ContextPtr:IsHidden() == false ) then
    	OnChat( playerID, -1, Locale.ConvertTextKey( "TXT_KEY_HOST_MIGRATION" ) );
	end
end
Events.MultiplayerGameHostMigration.Add( OnHostMigration );

----------------------------------------------------------------
----------------------------------------------------------------
function UpdateVoiceChatForPlayerID( iPlayerID, chatting, teamChat )
  print("UpdateVoiceChatForPlayerID() IPlayerID: " .. tostring(iPlayerID) .. " chatting: " .. tostring(chatting) .. " teamChat: " .. tostring(teamChat));
	if(iPlayerID == Matchmaking.GetLocalID()) then
		UpdateVoiceChat(iPlayerID, Controls.VoiceChatIcon, chatting, teamChat);
	else
		local slotInstance = nil;
		for iSlot, slotElement in pairs( m_SlotInstances ) do
			local slotPlayerID = GetPlayerIDBySelectionIndex(iSlot);
			if(slotPlayerID == iPlayerID) then
				slotInstance = slotElement;
				break;
			end
		end
		if(slotInstance ~= nil) then 
			UpdateVoiceChat(iPlayerID, slotInstance.VoiceChatIcon, chatting, teamChat);
		end
	end
end



function OnMultiplayerVoiceChatStart( iPlayerID, teamChat )
  UpdateVoiceChatForPlayerID(iPlayerID, true, teamChat);
end
Events.MultiplayerVoiceChatStart.Add( OnMultiplayerVoiceChatStart );

function OnMultiplayerVoiceChatEnd( iPlayerID, teamChat )
  UpdateVoiceChatForPlayerID(iPlayerID, false, false);
end
Events.MultiplayerVoiceChatEnd.Add( OnMultiplayerVoiceChatEnd );


----------------------------------------------------------------
-- UPDATE CURRENT SETTINGS
----------------------------------------------------------------
function UpdateDisplay()
	if( ContextPtr:IsHidden() == false ) then
		UpdateOptions();
		DoCheckTeams(); -- Check team validity before refreshing the player list so that
										-- the local player ready status will be reflect the current team validity state.
		RefreshPlayerList();

		-- Allow the host to manually start the game when loading a game.
		if(m_bIsHost and PreGame.GetLoadFileName() ~= "" and not IsInGameScreen()) then
			Controls.LaunchButton:SetHide( false );	
			Controls.LaunchButton:SetDisabled( not Network.IsEveryoneConnected() );
			
			-- Set launch button tool tip.
			if ( not Network.IsEveryoneConnected() ) then
				-- Launch button is blocked by a player joining the game.
				Controls.LaunchButton:LocalizeAndSetToolTip( "TXT_KEY_LAUNCH_GAME_BLOCKED_PLAYER_JOINING" );
			else
				-- Launch button is functional.  No tooltip needed.
				Controls.LaunchButton:SetToolTipString();
			end	        
		else
			Controls.LaunchButton:SetHide( true );
		end
	end
end


-------------------------------------------------
-- CHECK FOR GAME AUTO START
-------------------------------------------------
function CheckGameAutoStart()
-- Check to see if we should start/stop the multiplayer game.

	-- Check to make sure we don't have too many players for this map.
	local totalPlayers = 0;
	for i = 0, m_MaxPlayerNum do
		if( PreGame.GetSlotStatus( i ) == SlotStatus.SS_COMPUTER or PreGame.GetSlotStatus( i ) == SlotStatus.SS_TAKEN ) then
			if( PreGame.GetSlotClaim( i ) == SlotClaim.SLOTCLAIM_ASSIGNED ) then
				totalPlayers = totalPlayers + 1;
			end
		end
	end
	local maxPlayers = GetMaxPlayersForCurrentMap();
	local bPlayerCountValid = (totalPlayers <= maxPlayers);
		
	if(m_bLaunchReady and m_bTeamsValid and bPlayerCountValid and not PreGame.GameStarted() and Network.IsEveryoneConnected()) then
		-- Everyone has readied up and we can start.
		if(PreGame.IsHotSeatGame()) then
			-- Hotseat skips the countdown.
			LaunchGame();
		elseif(g_fCountdownTimer == -1) then
			StartCountdown();
		end
	else
		-- We can't autostart now, stop the countdown incase we started it earlier.
		StopCountdown();
	end
end


-------------------------------------------------
-------------------------------------------------
function OnPreGameDirty()
    if( ContextPtr:IsHidden() == false ) then
	    UpdateDisplay();
		UpdatePageTabView(true);
		CheckGameAutoStart();  -- Check for autostart because this event could to due to a ready status changing.
	end
end
Events.PreGameDirty.Add( OnPreGameDirty );

-------------------------------------------------
-------------------------------------------------
function UpdatePingTimeLabel( kLabel, playerID )
	local iPingTime = Network.GetPingTime( playerID );
	if (iPingTime >= 0) then
		iPingTime = math.clamp(iPingTime, 0, 99999); --limit value to something that can be displayed in 5 chars.
		kLabel:SetHide( false );
		if (iPingTime == 0) then
			kLabel:LocalizeAndSetText("TXT_KEY_TIME_UNDER_1_MS");
		else
			if (iPingTime < 1000) then
				kLabel:LocalizeAndSetText("TXT_KEY_TIME_MILLISECONDS", iPingTime);
			else
				kLabel:LocalizeAndSetText("TXT_KEY_TIME_SECONDS", (iPingTime / 1000));
			end
		end
	else
		kLabel:SetHide( true );
	end			
end
-------------------------------------------------
-------------------------------------------------
function OnPingTimesChanged()
    if( ContextPtr:IsHidden() == false and not PreGame.IsHotSeatGame()) then

		-- Get the Current Player List
		local playerTable = Matchmaking.GetPlayerList();
		
		-- Display Each Player
		if( playerTable ) then
			for i, playerInfo in ipairs( playerTable ) do
				local playerID = playerInfo.playerID;

				if( playerID ~= Matchmaking.GetLocalID() ) then
					local slotInstance = m_SlotInstances[ i ];				
					if (slotInstance ~= nil and not slotInstance.Root:IsHidden()) then

						local bIsHuman  = (PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_TAKEN ) or
										  (PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OPEN );
				        
						if ( bIsHuman ) then
							UpdatePingTimeLabel( slotInstance.PingTimeLabel, playerID );
						end
					end
				end
			end	
		end
    end
end
Events.MultiplayerPingTimesChanged.Add( OnPingTimesChanged );

----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	if(g_modsActivating) then
		-- ignore input while mods are activating.
		return true;
	end

	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			if (CanManuallyExitGame()) then
				HandleExitRequest();
			end
			return true;
		end
	end
	
  if( uiMsg == KeyEvents.KeyUp ) then
		if(wParam == Keys.VK_TAB or wParam == Keys.VK_RETURN) then
      Controls.ChatEntry:TakeFocus();
      return true;
		end
	end

	return VoiceChatInputHandler( uiMsg, wParam, lParam );
end
ContextPtr:SetInputHandler( InputHandler );

-------------------------------------------------
-------------------------------------------------
function UpdatePageTitle()
	local bIsModding = (ContextPtr:LookUpControl("../.."):GetID() == "ModMultiplayerSelectScreen");
	if(IsInGameScreen()) then
		Controls.TitleLabel:LocalizeAndSetText( "{TXT_KEY_MULTIPLAYER_DEDICATED_SERVER_ROOM:upper}" );	
	elseif(m_bEditOptions) then
		if(bIsModding) then
			Controls.TitleLabel:LocalizeAndSetText( "TXT_KEY_MOD_MP_GAME_SETUP_HEADER" );
		else
			Controls.TitleLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_GAME_SETUP_HEADER" );	
		end
	else
		Controls.TitleLabel:LocalizeAndSetText( "{TXT_KEY_MULTIPLAYER_STAGING_ROOM:upper}" );
	end
end

-- ===========================================================================
--	bUpdateOnly,	Update the view only, don't send across changes to Multiplayer
-- ===========================================================================
function UpdatePageTabView( bUpdateOnly )

	Controls.AllPlayerContents:SetHide( m_bEditOptions );
	Controls.GameOptionsContents:SetHide( not m_bEditOptions );
--	Controls.Host:SetHide( m_bEditOptions );
--	Controls.ListingScrollPanel:SetHide( m_bEditOptions );	
--	Controls.OptionsScrollPanel:SetHide( not m_bEditOptions );
--	Controls.OptionsPageTabHighlight:SetHide( not m_bEditOptions );
--	Controls.PlayersPageTabHighlight:SetHide( m_bEditOptions );
--	Controls.GameOptionsSummary:SetHide( m_bEditOptions );
--	Controls.GameOptionsSummaryTitle:SetHide( m_bEditOptions );
	
	UpdatePageTitle();
	if (m_bEditOptions) then
		Controls.OptionsScrollPanel:CalculateInternalSize();
		
		bIsModding = (ContextPtr:LookUpControl("../.."):GetID() == "ModMultiplayerSelectScreen");
		if(bIsModding) then
			Controls.ModsButton:SetHide( false );
		else
			Controls.ModsButton:SetHide( true );
		end
		
		PopulateMapSizePulldown();
		PopulateMapTerrainPulldown();

		RefreshMapScripts();	
		PreGame.SetRandomMapScript(false);	-- Random map scripts is not supported in multiplayer
		UpdateGameOptionsDisplay(bUpdateOnly);	
	else
		if (PreGame.IsHotSeatGame()) then
			-- In case they changed the DLC
			local prevCursor = UIManager:SetUICursor( 1 );
			local bChanged = Modding.ActivateAllowedDLC();																		
			UIManager:SetUICursor( prevCursor );
			
			Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "StagingRoom" );
		end
	end
end


-- ===========================================================================
function OnPlayersPageTab()
	if (m_bEditOptions) then
		m_bEditOptions = false;
		BuildSlots();
		UpdatePageTabView(true);
	end
end

-- ===========================================================================
function OnOptionsPageTab()
	if (not m_bEditOptions) then
		m_bEditOptions = true;
		UpdatePageTabView(true);
	end
end


-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )

		--print("ShowHideHandler Hide: " .. tostring(bIsHide) .. " Init: " .. tostring(bIsInit));
    -- Create slot instances.
    if ( bIsInit ) then
			CreateSlots();
			RefreshMapScripts();
		end
    
    
    if( not bIsHide ) then

			Controls.BackButton:SetDisabled(false);
			Controls.HotJoinCancelButton:SetDisabled(false);

		if( Matchmaking.IsHost() and
			not IsInGameScreen() and
			PreGame.GetGameOption("GAMEOPTION_PITBOSS") == 1 and
			OptionsManager.GetTurnNotifySmtpHost_Cached() ~= "" and
			OptionsManager.GetTurnNotifySmtpPassword_Cached() == "" ) then
			-- Display email smtp password prompt if we're hosting a pitboss game and the password is blank.
			UIManager:PushModal(Controls.ChangeSmtpPassword, true);		
		end
    			
		if ( PreGame.IsHotSeatGame() ) then		
			-- If Hot Seat, just 'ready' the host
			Controls.LocalReadyCheck:SetHide(true);
			PreGame.SetReady( Matchmaking.GetLocalID() );
			-- Hide the chat panel		
			Controls.ChatPanel:SetHide( true );
		else
			Controls.ChatPanel:SetHide( false );
		end
		
		SetInLobby( true );
		m_bEditOptions = false;
		ShowHideExitButton();
		ShowHideBackButton();
		ShowHideInviteButton();		
		--ShowHideStrategicViewButton();
		UpdatePageTabView(true);
		StopCountdown(); -- Make sure the countdown is stopped if we're toggling the hide status of the screen.
			
		AdjustScreenSize();
	
		ValidateCivSelections();
		RefreshMapTypeDisplay();
   		BuildSlots();		-- Populate the civs for the slots.  This can change so it must be done every time.
        BuildPlayerNames();
		UpdateDisplay();
		ShowHideSaveButton();
		UIManager:SetUICursor( 0 );
		Controls.LowerButtonStack:CalculateSize();
		Controls.LowerButtonStack:ReprocessAnchoring();
	else
		-- If any of the pulldowns are open, close them now.
		Controls.HandicapPulldown:ForceClose();
		Controls.CivSelectPulldown:ForceClose();
		Controls.ColonistSelectPulldown:ForceClose();
		Controls.SpacecraftSelectPulldown:ForceClose();
		Controls.CargoSelectPulldown:ForceClose();
		Controls.SlotTypePulldown:ForceClose();
		Controls.TeamPulldown:ForceClose();
		Controls.MapTypePullDown:ForceClose();
		Controls.MapSizePullDown:ForceClose();
		Controls.MapTerrainPullDown:ForceClose();
		Controls.GameSpeedPullDown:ForceClose();
		Controls.TurnModePull:ForceClose();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );




-- ===========================================================================
function UpdateOptions()

	-- Set Game Name
	local strGameName = Matchmaking.GetCurrentGameName();
	TruncateString( Controls.NameLabel, 520, strGameName ); 
	Controls.NameLabel:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_GAME_NAME") .. " " .. strGameName );

	-- Game State Indicator
	if( PreGame.GameStarted() ) then
		Controls.HotJoinBox:SetHide( false );
		Controls.LoadingBox:SetHide( true );	
	elseif( PreGame.GetLoadFileName() ~= "" ) then
		Controls.HotJoinBox:SetHide( true );
	  Controls.LoadingBox:SetHide( false );
	else
		Controls.HotJoinBox:SetHide( true );
	  Controls.LoadingBox:SetHide( true );
	end
	
	-- Set Max Turns if set
	local maxTurns = PreGame.GetMaxTurns();
	if(maxTurns == 0 or maxTurns == GetDefaultMaxTurns()) then
		Controls.MaxTurns:SetHide(true);
	else
		Controls.MaxTurns:SetHide(false);
		Controls.MaxTurns:SetText(Locale.ConvertTextKey("TXT_KEY_MAX_TURNS", maxTurns));
	end
	
	-- Show turn timer value if set.
	if(PreGame.GetGameOption("GAMEOPTION_END_TURN_TIMER_ENABLED") == 1) then
		Controls.TurnTimer:SetHide(false);
		local turnTimerStr = Locale.ConvertTextKey("TXT_KEY_MP_OPTION_TURN_TIMER");
		local pitBossTurnTime = PreGame.GetPitbossTurnTime();
		if(pitBossTurnTime > 0) then
			turnTimerStr = turnTimerStr .. ": " .. pitBossTurnTime;
			if(PreGame.GetGameOption("GAMEOPTION_PITBOSS") == 1) then
				turnTimerStr = turnTimerStr .. " " .. hoursStr;
			else
				turnTimerStr = turnTimerStr .. " " .. secondsStr;
			end
		end
		Controls.TurnTimer:SetText(turnTimerStr);	
	else
		Controls.TurnTimer:SetHide(true);
	end
				
	-- Set Turn Mode
	local turnModeStr = GetTurnModeStr();
	Controls.TurnModeLabel:LocalizeAndSetText(turnModeStr);
	Controls.TurnModeLabel:LocalizeAndSetToolTip(GetTurnModeToolTipStr(turnModeStr));

	-- Set Game Map Type
	if( not PreGame.IsRandomMapScript() ) then   
		local mapScriptFileName = Locale.ToLower(PreGame.GetMapScript());
		local mapScript = nil;
        
		for row in GameInfo.MapScripts{FileName = mapScriptFileName} do
			if mapScript == nil then
				mapScript = row;
			end
		end
		
		if(mapScript ~= nil) then
			Controls.MapTypeLabel:LocalizeAndSetText( mapScript.Name );
			Controls.MapTypeLabel:LocalizeAndSetToolTip( mapScript.Description );
		else
			local mapInfo = UI.GetMapPreview(mapScriptFileName);
			if(mapInfo ~= nil) then
				Controls.MapTypeLabel:LocalizeAndSetText(mapInfo.Name);
				Controls.MapTypeLabel:LocalizeAndSetToolTip(mapInfo.Description);
			else
				-- print("Cannot get info for map or map script - " .. tostring(mapScriptFileName));
				Controls.MapTypeLabel:SetText("[COLOR_RED]" .. Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN") .. "[ENDCOLOR]");
				Controls.MapTypeLabel:LocalizeAndSetToolTip("TXT_KEY_FILE_INFO_NOT_FOUND");
			end	
		end
	end
    
	if(PreGame.IsRandomMapScript()) then
		Controls.MapTypeLabel:LocalizeAndSetText( "TXT_KEY_RANDOM_MAP_SCRIPT" );
		Controls.MapTypeLabel:LocalizeAndSetToolTip( "TXT_KEY_RANDOM_MAP_SCRIPT_HELP" );
	end
	
	-- Set Map Size
	if(not PreGame.IsRandomWorldSize() ) then
		info = GameInfo.Worlds[ PreGame.GetWorldSize() ];
		Controls.MapSizeLabel:LocalizeAndSetText( info.Description );
		Controls.MapSizeLabel:LocalizeAndSetToolTip( info.Help );
	else
		Controls.MapSizeLabel:LocalizeAndSetText( "TXT_KEY_RANDOM_MAP_SIZE" );
		Controls.MapSizeLabel:LocalizeAndSetToolTip( "TXT_KEY_RANDOM_MAP_SIZE_HELP" );
	end

	-- Set Planet
	local planet = PreGame.GetPlanet();		
	local info = nil;		
	if (planet ~= nil ) then		
		info = GameInfo.Planets[ planet ];
	end
	
	if ( planet ~= -1 and info == nil ) then
		Controls.MapTerrainLabel:SetText("[COLOR_RED]" .. Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN") .. "[ENDCOLOR]");
		Controls.MapTerrainLabel:LocalizeAndSetToolTip("TXT_KEY_PLANET_BIOME_NOT_FOUND");
	elseif ( (info ~= nil) and (not PreGame.IsRandomMapScript()) ) then
		Controls.MapTerrainLabel:LocalizeAndSetText(info.Description);
		Controls.MapTerrainLabel:LocalizeAndSetToolTip(info.ToolTip);		
	else
		Controls.MapTerrainLabel:LocalizeAndSetText("TXT_KEY_RANDOM_MAP_TERRAIN");
		Controls.MapTerrainLabel:LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_TERRAIN_HELP");
	end   
	
    -- Set Game Pace Slot
    info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
	Controls.GameSpeedLabel:LocalizeAndSetText( info.Description );
	Controls.GameSpeedLabel:LocalizeAndSetToolTip( info.Help );
	
	-- Game Options
	g_AdvancedOptionIM:ResetInstances();
	g_AdvancedOptionsList = {};
	
    local count = 1;
    -- When there's 8 or more players connected to us (9 player game), warn that it's an unsupported game.
    
    local totalPlayers = 0;
    for i = 0, m_MaxPlayerNum do
        if( PreGame.GetSlotStatus( i ) == SlotStatus.SS_COMPUTER or PreGame.GetSlotStatus( i ) == SlotStatus.SS_TAKEN ) then
			if( PreGame.GetSlotClaim( i ) == SlotClaim.SLOTCLAIM_ASSIGNED ) then
				totalPlayers = totalPlayers + 1;
			end
		end
	end

	-- Is it a private game?
    if(PreGame.IsPrivateGame()) then
		local controlTable = g_AdvancedOptionIM:GetInstance();
		g_AdvancedOptionsList[count] = controlTable;
		controlTable.Text:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_PRIVATE_GAME");
		count = count + 1;
    end
	
    if(totalPlayers > 8) then
		local controlTable = g_AdvancedOptionIM:GetInstance();
		g_AdvancedOptionsList[count] = controlTable;
		controlTable.Text:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_UNSUPPORTED_NUMBER_OF_PLAYERS");
		count = count + 1;
    end
    
    for option in GameInfo.GameOptions{Visible = 1} do	
		if( option.Type ~= "GAMEOPTION_END_TURN_TIMER_ENABLED" 
				and option.Type ~= "GAMEOPTION_SIMULTANEOUS_TURNS"
				and option.Type ~= "GAMEOPTION_DYNAMIC_TURNS") then 
			local savedValue = PreGame.GetGameOption(option.Type);
			if(savedValue ~= nil and savedValue == 1) then
				local controlTable = g_AdvancedOptionIM:GetInstance();
				g_AdvancedOptionsList[count] = controlTable;
				controlTable.Text:LocalizeAndSetText(option.Description);
				count = count + 1;
			end
		end
	end
		
	-- Update scrollable panel
	Controls.AdvancedOptions:CalculateSize();
	Controls.GameOptionsSummary:CalculateInternalSize();
end


-------------------------------------------------
-- TODO: This only gets called once.  We need something more dynamic.
-------------------------------------------------
function PopulateInvitePulldown( pullDown, playerID )

	local controlTable = {};
	
	pullDown:ClearEntries();
	
	pullDown:BuildEntry( "InstanceOne", controlTable );

	controlTable.Button:SetText( Locale.ConvertTextKey("TXT_KEY_AI_NICKNAME") );
	controlTable.Button:SetVoids( playerID, -1 );

	local friendList = Matchmaking.GetFriendList();

	if friendList then

		-- Populate with Steam friends.
		for i = 1, #friendList do

			local controlTable = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );

			controlTable.Button:SetText( "Invite " .. Locale.ToUpper( friendList[i].playerName ));
			controlTable.Button:SetVoids( playerID, friendList[i].steamID );

		end

	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( InviteSelected );

end


-------------------------------------------------
-------------------------------------------------
function PopulateTeamPulldown( pullDown, playerID )

	local playerTable = Matchmaking.GetPlayerList();

	pullDown:ClearEntries();

	-- Display Each Player
	if playerTable then
		
		for i = 1, MAX_TEAMS, 1 do

			local controlTable = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );
			
			controlTable.Button:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", i) );
			controlTable.Button:SetVoids( playerID, i-1 ); -- TODO: playerID is really more like the slot position.

			if ( i > #playerTable ) then
				controlTable.Button:SetHide( true );
			end

		end

		pullDown:CalculateInternals();
		pullDown:RegisterSelectionCallback( OnSelectTeam );
	end

end


-------------------------------------------------
-------------------------------------------------
function PopulateHandicapPulldown( pullDown, playerID )

	pullDown:ClearEntries();

	for info in GameInfo.HandicapInfos() do
		if ( info.Type ~= "HANDICAP_AI_DEFAULT" ) then
			local controlTable = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );

			controlTable.Button:SetText( Locale.ConvertTextKey(info.Description) );
			controlTable.Button:LocalizeAndSetToolTip(info.Help);
			controlTable.Button:SetVoids( playerID, info.ID );
		end
	end    

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnHandicapTeam );

end

-------------------------------------------------
-------------------------------------------------
function PopulateSlotTypePulldown( pullDown, playerID, slotTypeOptions )

	pullDown:ClearEntries();
	
	local controlTable = {};
	local isEntryAbleToBeCreated;
	for i, typeName in ipairs(slotTypeOptions) do
		controlTable = {};
		isEntryAbleToBeCreated = true;
		
		if(PreGame.IsHotSeatGame()) then
			if(typeName == "TXT_KEY_SLOTTYPE_HUMANREQ") then
				-- "Human Required" slot type is the "Human" slot type in hotseat mode.
				typeName = "TXT_KEY_PLAYER_TYPE_HUMAN";
			elseif(typeName == "TXT_KEY_SLOTTYPE_OBSERVER") then
				-- observer mode not allowed in hotseat mode.
				isEntryAbleToBeCreated = false;
			elseif(typeName == "TXT_KEY_SLOTTYPE_OPEN") then
				-- open mode is redundent in hotseat mode.
				isEntryAbleToBeCreated = false;
			end
		elseif(Network.IsPlayerConnected(playerID)) then
			-- player is actively occupying this slot
			if(typeName == "TXT_KEY_SLOTTYPE_OPEN") then
				-- transform open slottype position to human (for changing from an observer to normal human player)
				typeName = "TXT_KEY_PLAYER_TYPE_HUMAN";
			elseif(typeName == "TXT_KEY_SLOTTYPE_CLOSED" or typeName == "TXT_KEY_SLOTTYPE_AI") then
				-- Don't allow those types on human occupied slots.
				isEntryAbleToBeCreated = false;
			end
		end
				
		if (isEntryAbleToBeCreated == true) then
			pullDown:BuildEntry( "InstanceOne", controlTable );
					
			controlTable.Button:SetText( Locale.ConvertTextKey(typeName) );
			controlTable.Button:LocalizeAndSetToolTip( g_slotTypeData[typeName].tooltip );
			controlTable.Button:SetVoids( playerID, g_slotTypeData[typeName].index );	
		end
	end

		
	-- Set Slot Type
	--local slotTypeStr = GetSlotTypeString(Matchmaking.GetLocalID());
	--Controls.SlotTypeLabel:LocalizeAndSetText( slotTypeStr );
	--Controls.SlotTypeLabel:LocalizeAndSetToolTip( g_slotTypeData[slotTypeStr].tooltip );		

	-- Set Slot Type
	--local slotTypeStr = GetSlotTypeString(playerID);
	--slotInstance.SlotTypeLabel:LocalizeAndSetText( slotTypeStr );
	--slotInstance.SlotTypeLabel:LocalizeAndSetToolTip( g_slotTypeData[slotTypeStr].tooltip );		
	
	local button = pullDown:GetButton();
	local slotTypeStr = GetSlotTypeString(playerID);
	button:SetText( Locale.ConvertTextKey(slotTypeStr) );
	button:LocalizeAndSetToolTip( g_slotTypeData[slotTypeStr].tooltip );
	button:SetVoids( playerID, g_slotTypeData[slotTypeStr].index );	

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnSlotType);

end

-------------------------------------------------
-------------------------------------------------
function UpdateGameInfoIcon( iconInstance, gameInfoList, gameInfoID, defaultIconAtlas, defaultIconIdx)
    local gameInfoRow = gameInfoList[gameInfoID];
    if(gameInfoRow ~= nil) then
      IconHookup(gameInfoRow.PortraitIndex, 64, gameInfoRow.IconAtlas, iconInstance);
    else
      IconHookup(defaultIconIdx, 64, defaultIconAtlas, iconInstance);
    end
end



local tipControlTable = {};
TTManager:GetTypeControlTable( "GameInfoToolTip", tipControlTable );

-- ===========================================================================
-- ===========================================================================
function PopulateGameInfoPulldown( pullDown, selectionIdx, getGameInfoFunc, gameInfoList, setGameInfoFunc, defaultIconIdx)

	local defaultIconAtlas = "GAME_SETUP_ATLAS";  -- default icon atlas filename.
	
	pullDown:ClearEntries();

	-- Put a Random option at the top.
	local randomEntry = {};
	pullDown:BuildEntry( "ShellMPLobbyPullInstance", randomEntry );
	randomEntry.NameLabel:LocalizeAndSetText("TXT_KEY_MAP_OPTION_RANDOM");
	randomEntry.DescriptionLabel:LocalizeAndSetText("TXT_KEY_MAP_OPTION_RANDOM");
	IconHookup( 24, 64, "CIV_COLOR_ATLAS", randomEntry.Portrait );
	randomEntry.Button:SetVoids( selectionIdx, -1);	

	for gameInfoRow in gameInfoList() do
		-- Is it unlocked by FiraxisLive?
		local available = false;
		if (gameInfoRow.FiraxisLiveUnlockKey ~= nil) then
			local value = FiraxisLive.GetKeyValue(gameInfoRow.FiraxisLiveUnlockKey);
			available = (value ~= 0);
		else
			available = true;
		end

		if (available) then
			-- Don't show minor/ai civs if creating civ pulldown.
			if(setGameInfoFunc ~= PreGame.SetCivilization or gameInfoRow.Playable) then 
				local pulldownEntry = {};
				pullDown:BuildEntry( "ShellMPLobbyPullInstance", pulldownEntry );

				if(pulldownEntry ~= nil) then
					pulldownEntry.NameLabel:LocalizeAndSetText(gameInfoRow.ShortDescription);

					if(setGameInfoFunc == PreGame.SetCivilization) then
						-- Civilizations list their civ bonuses as their description instead of their gameInfoList.Description.
						if( m_civTraits[gameInfoRow.Type] ~= nil) then
							pulldownEntry.DescriptionLabel:LocalizeAndSetText(m_civTraits[gameInfoRow.Type].Help);
						else
							pulldownEntry.DescriptionLabel:LocalizeAndSetText(" ");
						end
						
						-- Manually adjust size of entry to account for civs with longer civ traits description text.
						local sizeY : number = pulldownEntry.DescriptionLabel:GetSizeY() + 70;
						pulldownEntry.Button:SetSizeY(sizeY);
						pulldownEntry.Content:SetSizeY(sizeY);
					else
						pulldownEntry.DescriptionLabel:LocalizeAndSetText(gameInfoRow.Description);
					end
					IconHookup(gameInfoRow.PortraitIndex, 64, gameInfoRow.IconAtlas, pulldownEntry.Portrait);
					pulldownEntry.Button:SetVoids( selectionIdx, gameInfoRow.ID);	
				end
			end
		end

	-- Create a custon tooltip callback function using our function args.
	pullDown:SetToolTipCallback(function(control) 
		local playerID = GetPlayerIDBySelectionIndex(selectionIdx);
		local gameInfoID = getGameInfoFunc(playerID);
		print("tooltipcallback playerID " .. selectionIdx .. " gameInfoID " .. gameInfoID);
		local gameInfoRow = gameInfoList[gameInfoID];
		if(gameInfoRow ~= nil) then
			tipControlTable.NameLabel:LocalizeAndSetText(gameInfoRow.ShortDescription);
			if(setGameInfoFunc == PreGame.SetCivilization) then
				-- Civilizations list their civ bonuses as their description instead of their gameInfoList.Description.
				tipControlTable.DescriptionLabel:LocalizeAndSetText(m_civTraits[gameInfoRow.Type].Help);

				-- Manually adjust size of tooltip to account for civs with longer civ traits description text.
				local sizeY : number = tipControlTable.DescriptionLabel:GetSizeY() + 70;
				tipControlTable.CivTooltip:SetSizeY(sizeY);
			else
				tipControlTable.DescriptionLabel:LocalizeAndSetText(gameInfoRow.Description);
			end
			IconHookup(gameInfoRow.PortraitIndex, 64, gameInfoRow.IconAtlas, tipControlTable.Portrait);
		else
			tipControlTable.NameLabel:LocalizeAndSetText("TXT_KEY_MAP_OPTION_RANDOM");
			tipControlTable.DescriptionLabel:LocalizeAndSetText("TXT_KEY_MAP_OPTION_RANDOM");
			IconHookup(defaultIconIdx, 64, defaultIconAtlas, tipControlTable.Portrait);
		end
	end);
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback(
		function(selectID, giID)
			local playerID = GetPlayerIDBySelectionIndex(selectID);
			setGameInfoFunc(playerID, giID);
			UpdateDisplay();
			Network.BroadcastPlayerInfo();
		end);
end


-- ===========================================================================
--	Slot Type 
-- ===========================================================================
function GetSlotTypeString( playerID )
	if(		PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_COMPUTER) then		return "TXT_KEY_SLOTTYPE_AI";
	elseif(	PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_OBSERVER) then		return "TXT_KEY_SLOTTYPE_OBSERVER";
	elseif(	PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_CLOSED) then			return "TXT_KEY_SLOTTYPE_CLOSED";
	elseif(	PreGame.GetSlotStatus( playerID ) == SlotStatus.SS_TAKEN) then			return "TXT_KEY_PLAYER_TYPE_HUMAN";	
	elseif(	PreGame.GetSlotClaim( playerID ) == SlotClaim.SLOTCLAIM_RESERVED) then
		if (PreGame.IsHotSeatGame() ) then											return "TXT_KEY_PLAYER_TYPE_HUMAN";	-- reserved slots are human players in hotseat mode.
		else																		return "TXT_KEY_SLOTTYPE_HUMANREQ";	-- In normal multiplayer, reserved slots in the staging room indicate that this slot must be occupied by a human player for the game to start.			
		end
	end		
	return "TXT_KEY_SLOTTYPE_OPEN";
end


-- ===========================================================================
--	Chat
-- ===========================================================================
--local bFlipper = false;
function OnChat( fromPlayer, toPlayer, text, eTargetType )
	if( ContextPtr:IsHidden() == false and m_PlayerNames[ fromPlayer ] ~= nil ) then
		local controlTable = {};
		ContextPtr:BuildInstanceForControl( "ChatEntry", controlTable, Controls.ChatStack );
	    
		table.insert( m_ChatInstances, controlTable );
		if( #m_ChatInstances > 100 ) then
	    
			Controls.ChatStack:ReleaseChild( m_ChatInstances[ 1 ].Box );
			table.remove( m_ChatInstances, 1 );
		end
	    
		local PADDING   = 6;
		local timeString= os.date("%H:%M");	

		-- If a player's network name is long, truncate it and put it into the text message's tooltip		
		Controls.LuaMaxPlayerName:SetText( Locale.ToUpper(m_PlayerNames[ fromPlayer ]) ); 
		local isTruncated	= TruncateSelfWithTooltip( Controls.LuaMaxPlayerName );
		local playerName	= Controls.LuaMaxPlayerName:GetText();
		
		local chatString	= "[COLOR_CHAT_NAME]" .. playerName .. ":[ENDCOLOR] [COLOR_CHAT_MESSAGE]";
		--chatString			= chatString .. " [" .. timeString .. "]: [ENDCOLOR][COLOR_CHAT_MESSAGE]";
		--chatString			= chatString .. text .. "[ENDCOLOR]";
		chatString			= chatString .. text .. "[ENDCOLOR]";

		controlTable.String:SetText( Locale.ConvertTextKey( chatString) );		
		controlTable.Box:SetSizeY( controlTable.String:GetSizeY() + PADDING );
		controlTable.Box:ReprocessAnchoring();
		if ( isTruncated ) then
			controlTable.Box:SetToolTipString( Locale.ToUpper(m_PlayerNames[ fromPlayer ]) );
		end

		--if( bFlipper ) then
		--	controlTable.Box:SetColorChannel( 3, 0.4 );
		--end
		--bFlipper = not bFlipper;

		Events.AudioPlay2DSound( "AS2D_IF_MP_CHAT_DING" );		

		Controls.ChatStack:CalculateSize();
		Controls.ChatScroll:CalculateInternalSize();
		Controls.ChatScroll:SetScrollValue( 1 );
	end
end
Events.GameMessageChat.Add( OnChat );


-------------------------------------------------
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
        Network.SendChat( text );
    end
    Controls.ChatEntry:ClearString();
end
Controls.ChatEntry:RegisterCommitCallback( SendChat );


----------------------------------------------------------------
----------------------------------------------------------------
function OnEnable( bIsCheck, slotNumber )
	local playerID = GetPlayerIDBySelectionIndex( slotNumber );

	local bCanEnableAISlots = PreGame.GetMultiplayerAIEnabled();
	
	if(bCanEnableAISlots) then
		if( bIsCheck ) then
    		PreGame.SetSlotStatus( playerID, SlotStatus.SS_COMPUTER );
    		PreGame.SetHandicap( playerID, 1 );
			if ( PreGame.IsHotSeatGame() ) then
				-- Reset so the player can force a rebuild
				PreGame.SetNickName( playerID, "" );
				PreGame.SetLeaderName( playerID, "" );
				PreGame.SetCivilizationDescription( playerID, "" );
				PreGame.SetCivilizationShortDescription( playerID, "" );
				PreGame.SetCivilizationAdjective( playerID, "" );
			end
		else
    		PreGame.SetSlotStatus( playerID, SlotStatus.SS_CLOSED );
		end
	end
    UpdateDisplay();
    Network.BroadcastPlayerInfo();
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnLock( bIsCheck, slotNumber )

	local playerID = GetPlayerIDBySelectionIndex( slotNumber );
	
    if( bIsCheck ) then
    	PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_RESERVED );
	else
    	PreGame.SetSlotClaim( playerID, SlotClaim.SLOTCLAIM_UNASSIGNED );
	end

    UpdateDisplay();
end

----------------------------------------------------------------
-- create the slots
----------------------------------------------------------------
function CreateSlots()
	for i = 1, m_MaxPlayerNum, 1 do

		local instance = {};
		ContextPtr:BuildInstanceForControl( "PlayerSlot", instance, Controls.SlotStack );
		instance.Root:SetHide( true );
	    
		instance.LockCheck:RegisterCheckHandler( OnLock );
		instance.EnableCheck:RegisterCheckHandler( OnEnable );
		instance.EnableCheck:SetVoid1( i );
		instance.KickButton:RegisterCallback( Mouse.eLClick, OnKickPlayer );
		instance.KickButton:SetVoid1( i );
		instance.EditButton:RegisterCallback( Mouse.eLClick, OnEditPlayer );
		instance.EditButton:SetVoid1( i );
		instance.SwapButton:RegisterCallback( Mouse.eLClick, OnSwapPlayer );
		instance.SwapButton:SetVoid1( i );
		m_SlotInstances[i] = instance;
	end
end

-- =========================================================================== 
--	Kick off the slot building
-- ===========================================================================
function BuildSlots()

	-- Setup Local Slot
	PopulateTeamPulldown(	  Controls.TeamPulldown,				0 );
	PopulateHandicapPulldown( Controls.HandicapPulldown,			0 );
  
	PopulateGameInfoPulldown( Controls.CivSelectPulldown,			0, PreGame.GetCivilization, GameInfo.Civilizations, PreGame.SetCivilization, 2);
	PopulateGameInfoPulldown( Controls.ColonistSelectPulldown,		0, PreGame.GetLoadoutColonist, GameInfo.Colonists, PreGame.SetLoadoutColonist, 4);
	PopulateGameInfoPulldown( Controls.SpacecraftSelectPulldown,	0,PreGame.GetLoadoutSpacecraft,  GameInfo.Spacecraft, PreGame.SetLoadoutSpacecraft, 1);
	PopulateGameInfoPulldown( Controls.CargoSelectPulldown,			0, PreGame.GetLoadoutCargo, GameInfo.Cargo, PreGame.SetLoadoutCargo, 0);

	m_NextSlotToBuild = 1;
	ContextPtr:SetUpdate( OnUpdateBuildNextSlot );

	-- Setup other player's slots...
	for i = 1, m_MaxPlayerNum, 1 do

		local instance = m_SlotInstances[i];
		instance.Root:SetHide( true );
	    
		PopulateInvitePulldown(	  instance.InvitePulldown,				i );
		PopulateTeamPulldown(	  instance.TeamPulldown,				i );
		PopulateHandicapPulldown( instance.HandicapPulldown,			i );
		PopulateGameInfoPulldown( instance.CivSelectPulldown,			i, PreGame.GetCivilization,			GameInfo.Civilizations, PreGame.SetCivilization, 2);
		PopulateGameInfoPulldown( instance.ColonistSelectPulldown,		i, PreGame.GetLoadoutColonist,		GameInfo.Colonists,		PreGame.SetLoadoutColonist, 4);
		PopulateGameInfoPulldown( instance.SpacecraftSelectPulldown,	i, PreGame.GetLoadoutSpacecraft,	GameInfo.Spacecraft,	PreGame.SetLoadoutSpacecraft, 1);
		PopulateGameInfoPulldown( instance.CargoSelectPulldown,			i, PreGame.GetLoadoutCargo,			GameInfo.Cargo,			PreGame.SetLoadoutCargo, 0);
		
		instance.EnableCheck:SetVoid1( i );
		instance.KickButton:SetVoid1( i );
		instance.EditButton:SetVoid1( i );	    
	end
end


-- ===========================================================================
--	Build one slot per update frame; allows user input to cancel during this
--	potentially expensive operation.
-- ===========================================================================
function FinishBuildNextSlot()
	if(g_fCountdownTimer ~= -1) then
		-- countdown timer was ticking, reengage standard OnUpdateCountdown()
		ContextPtr:SetUpdate( OnUpdateCountdown );
	else
		ContextPtr:ClearUpdate();
	end
end

function OnUpdateBuildNextSlot( fDTime )
	if(g_fCountdownTimer ~= -1) then
		-- the game start countdown is in effect, update the countdown because OnUpdateBuildNextSlot() is currently
		-- hogging the lua context update.
		OnUpdateCountdown(fDTime);
	end

	if ( m_NextSlotToBuild == -1 ) then
		print("ERROR: Callback OnBuildNextSlot is called but m_NextSlotToBuild is not set to a valid slot.");
		FinishBuildNextSlot();
		return;
	end

	local i			= m_NextSlotToBuild;
	local instance	= m_SlotInstances[i];
	instance.Root:SetHide( true );
	    
	PopulateInvitePulldown(	  instance.InvitePulldown,				i );
	PopulateTeamPulldown(	  instance.TeamPulldown,				i );
	PopulateHandicapPulldown( instance.HandicapPulldown,			i );
	PopulateGameInfoPulldown( instance.CivSelectPulldown,			i, PreGame.GetCivilization,			GameInfo.Civilizations, PreGame.SetCivilization, 2);
	PopulateGameInfoPulldown( instance.ColonistSelectPulldown,		i, PreGame.GetLoadoutColonist,		GameInfo.Colonists,		PreGame.SetLoadoutColonist, 4);
	PopulateGameInfoPulldown( instance.SpacecraftSelectPulldown,	i, PreGame.GetLoadoutSpacecraft,	GameInfo.Spacecraft,	PreGame.SetLoadoutSpacecraft, 1);
	PopulateGameInfoPulldown( instance.CargoSelectPulldown,			i, PreGame.GetLoadoutCargo,			GameInfo.Cargo,			PreGame.SetLoadoutCargo, 0);
		
	instance.EnableCheck:SetVoid1( i );
	instance.KickButton:SetVoid1( i );
	instance.EditButton:SetVoid1( i );	    

	RefreshPlayerList();

	-- Set next slot to build next update, if hit limit, stop update callback.
	m_NextSlotToBuild = m_NextSlotToBuild + 1;
	if ( m_NextSlotToBuild > m_MaxPlayerNum ) then
		m_NextSlotToBuild = -1;
		FinishBuildNextSlot();
	end
end


-- ===========================================================================
function OnBeforeModsDeactivate()
	g_modsActivating = true;
end
Events.BeforeModsDeactivate.Add( OnBeforeModsDeactivate );

function OnAfterModsActivate()
	g_modsActivating = false;
	RefreshCivTraits();
	RefreshMapScripts();	

	if( ContextPtr:IsHidden() == false ) then
		ValidateCivSelections();
		RefreshMapTypeDisplay();
		BuildSlots();		-- Populate the civs for the slots.  This can change so it must be done every time.
		UpdateDisplay();
	end
end
Events.AfterModsActivate.Add( OnAfterModsActivate );

-------------------------------------------------
-------------------------------------------------
function OnVersionMismatch( iPlayerID, playerName, bIsHost )
    if( bIsHost ) then
        Events.FrontEndPopup.CallImmediate( Locale.ConvertTextKey( "TXT_KEY_MP_VERSION_MISMATCH_FOR_HOST", Locale.ToUpper( playerName )) );
    	Matchmaking.KickPlayer( iPlayerID );
    else
        Events.FrontEndPopup.CallImmediate( Locale.ConvertTextKey( "TXT_KEY_MP_VERSION_MISMATCH_FOR_PLAYER" ) );
        HandleExitRequest();
    end
end
Events.PlayerVersionMismatchEvent.Add( OnVersionMismatch );


-----------------------------------------------------------------
-- Adjust for resolution
-----------------------------------------------------------------
function AdjustScreenSize()
    local _, screenY = UIManager:GetScreenSizeVal();
    
    local TOP_COMPENSATION = 52 + ((screenY - 768) * 0.3 );
    local TOP_FRAME = 108;
    local BOTTOM_COMPENSATION = 240;
    local LOCAL_SLOT_COMPENSATION = 113;

	if ( Controls.ChatPanel:IsHidden() ) then
		BOTTOM_COMPENSATION = 80;
	end

	-- Player Tab
	local parentY = screenY;		
	Controls.AllPlayerContents:SetSizeY( parentY - 336 );
	parentY = parentY - 336;
	Controls.PlayerListing:SetSizeY( parentY - 250 );
	parentY = parentY - 250;
	Controls.ListingScrollPanel:SetSizeY( parentY - 44 );
	Controls.ListingScrollPanel:CalculateInternalSize();

	-- Options Tab
	parentY = screenY;		
	Controls.GameOptionsContents:SetSizeY( parentY - 336 );
	parentY = parentY - 336;
	Controls.OptionsScrollPanel:SetSizeY( parentY - 44 );
	parentY = parentY - 44;
	Controls.GameOptionsFullStack:CalculateSize();
	
	
	-- Chat panel
	parentY = screenY;
	Controls.ChatPanel:SetSizeY( parentY - 1174 );
	Controls.ChatScroll:CalculateInternalSize();
	
    Controls.GameOptionsSummary:CalculateInternalSize();    
	Controls.LowerButtonStack:CalculateSize();

end


-- ===========================================================================
function RefreshCivTraits()
	-- Refresh/Create our Civilization->Traits table from the database.
	m_civTraits = {};
	local civTraitsQuery = DB.CreateQuery([[SELECT Civilizations.Type, PersonalityTraits.Description, PersonalityTraits.Help
												FROM Civilizations
												inner join Personalities ON Civilizations.Personality = Personalities.Type
												inner join PersonalityTraits ON Personalities.UniquePersonalityTrait = PersonalityTraits.Type ]]);
	for row in civTraitsQuery() do
		m_civTraits[row.Type] = { Description = Locale.Lookup(row.Description), Help = Locale.Lookup(row.Help), WaterStart = false };
	end

	for row in GameInfo.Civilization_Start_In_Water() do
		m_civTraits[row.CivilizationType].WaterStart = true;
		m_civTraits[row.CivilizationType].Help = m_civTraits[row.CivilizationType].Help .."[NEWLINE]"..Locale.Lookup("TXT_KEY_SPONSOR_MENU_WATER_START");
	end

	m_MaxPlayerNum = 12; -- GameDefines.MAX_MAJOR_CIVS;

end


-- ===========================================================================
function Initialize()
	-- If already initialized, bail.
	if ( m_bInit ) then
		print("ERROR: Initialize called more than once on StagingRoom!");
		return;
	end

	-- Setup tabs
	m_tabs = CreateTabs( Controls.TabContainer, 64, 32 );
	m_tabs.AddTab( Controls.PlayersTab, OnPlayersPageTab );
	m_tabs.AddTab( Controls.OptionsTab, OnOptionsPageTab );
	m_tabs.CenterAlignTabs(-10);
	m_tabs.SelectTab( Controls.PlayersTab );

	m_bInit = true;
end


-------------------------------------------------
-------------------------------------------------
function OnUpdateUI( type, tag, iData1, iData2, strData1 )
    if( type == SystemUpdateUIType.ScreenResize ) then
        AdjustScreenSize();
    end
end
Events.SystemUpdateUI.Add( OnUpdateUI );

-------------------------------------------------
function OnAbandoned(eReason)
	if( UI.GetCurrentGameState() == GameStateTypes.CIVBE_GS_MAIN_MENU ) then
		-- Still in the front end
		if (eReason == NetKicked.BY_HOST) then
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_KICKED" );
		elseif (eReason == NetKicked.NO_HOST) then
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_HOST_LOST" );
		elseif (eReason == NetKicked.NO_ROOM) then
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_ROOM_FULL" );
		else
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_NETWORK_CONNECTION_LOST");
		end
		HandleExitRequest();
	end
end
Events.MultiplayerGameAbandoned.Add( OnAbandoned );



-------------------------------------------------
AdjustScreenSize();
RefreshCivTraits();
Initialize();