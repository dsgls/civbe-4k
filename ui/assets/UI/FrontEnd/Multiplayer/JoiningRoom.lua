-- ===========================================================================
--	Joinging Room
--	Intermediate screen when joining (or establishing) a match
-- ===========================================================================

local g_modsActivating = false;		
local g_exiting = false;

-- ===========================================================================
-- ===========================================================================
function CanManuallyExitGame()
	if (g_modsActivating) then -- Can't manually exit while activating mods.
		return false;
	end

	return true;
end

function OnCancel()
	if(CanManuallyExitGame()) then
		HandleExitRequest();
	end
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )

	if uiMsg == KeyEvents.KeyDown then
		if (wParam == Keys.VK_ESCAPE) then
			if(CanManuallyExitGame()) then
				HandleExitRequest();
			end
			return true;
		end
	end

	return false;

end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------
-- Leave the game we're trying to join.
-------------------------------------------------
function HandleExitRequest()
	g_exiting = true;
	Matchmaking.LeaveMultiplayerGame();
	UIManager:DequeuePopup( ContextPtr );
end

-------------------------------------------------
-- Start transition to the Staging room screen.  Assumes that we've already fully connected to multiplayer game.
-------------------------------------------------
function TransitionToStagingRoom()
	-- Attempt to configure game data if we need to for this multiplayer game. 
	if (not ContextPtr:IsHotLoad()) then
		local prevCursor = UIManager:SetUICursor( 1 );
		local bChanged = Modding.ActivateAllowedDLC();		
		UIManager:SetUICursor( prevCursor );
	end

	-- Send out an event to send us to the staging room after configuring game data.	
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "StagingRoom" );  
end

function OnSystemUpdateUI( type, tag )
	if( type == SystemUpdateUIType.RestoreUI) then
		if (tag == "StagingRoom") then
			-- If the staging room is being restored, we're done and need to go away.
			UIManager:DequeuePopup( ContextPtr );    
		end
	end
end
Events.SystemUpdateUI.Add( OnSystemUpdateUI );


-------------------------------------------------
-- Event Handler: MultiplayerJoinRoomComplete
-------------------------------------------------
function OnJoinRoomComplete()
	if (not ContextPtr:IsHidden()) then
		if Matchmaking.IsHost() then
			-- If the host, we're already fully in our own game, go to the staging room.
			TransitionToStagingRoom();
		else
			Controls.JoiningLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_JOINING_HOST" ));
		end
	end
end
Events.MultiplayerJoinRoomComplete.Add( OnJoinRoomComplete );


-------------------------------------------------
-- Event Handler: MultiplayerJoinRoomFailed
-------------------------------------------------
function OnJoinRoomFailed( iExtendedError, aExtendedErrorText )
	if (not ContextPtr:IsHidden()) then
		if iExtendedError == NetErrors.MISSING_REQUIRED_DATA then
			local szText = Locale.ConvertTextKey("TXT_KEY_MP_JOIN_FAILED_MISSING_RESOURCES");
		
			-- The aExtendedErrorText will contain an array of the IDs of the resources (DLC/Mods) needed by the game.
			local count = table.count(aExtendedErrorText);
			if(count > 0) then
				szText = szText .. "[NEWLINE]";
					for index, value in pairs(aExtendedErrorText) do 		
					szText = szText .. "[NEWLINE] [ICON_BULLET]" .. Locale.ConvertTextKey(value);
				end
			end
			Events.FrontEndPopup.CallImmediate( szText );
		elseif iExtendedError == NetErrors.ROOM_FULL then
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_ROOM_FULL" );
		else
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_JOIN_FAILED" );
		end
		Matchmaking.LeaveMultiplayerGame();
		UIManager:DequeuePopup( ContextPtr );
	end
end
Events.MultiplayerJoinRoomFailed.Add( OnJoinRoomFailed );

-------------------------------------------------
-- Event Handler: MultiplayerConnectionFailed
-------------------------------------------------
function OnMultiplayerConnectionFailed()
	if (not ContextPtr:IsHidden()) then
		-- We should only get this if we couldn't complete the connection to the host of the room	
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_JOIN_FAILED" );
		Matchmaking.LeaveMultiplayerGame();
		UIManager:DequeuePopup( ContextPtr );
	end
end
Events.MultiplayerConnectionFailed.Add( OnMultiplayerConnectionFailed );

-------------------------------------------------
-- Event Handler: MultiplayerGameAbandoned
-------------------------------------------------
function OnMultiplayerGameAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then
		if (eReason == NetKicked.BY_HOST) then
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_KICKED" );
		elseif (eReason == NetKicked.NO_ROOM) then
			Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_ROOM_FULL" );
		else
				Events.FrontEndPopup.CallImmediate( "TXT_KEY_MP_JOIN_FAILED" );
		end
		Matchmaking.LeaveMultiplayerGame();
		UIManager:DequeuePopup( ContextPtr );
	end
end
Events.MultiplayerGameAbandoned.Add( OnMultiplayerGameAbandoned );

-------------------------------------------------
-- Event Handler: ConnectedToNetworkHost
-------------------------------------------------
function OnHostConnect()
	if (not ContextPtr:IsHidden()) then
		Controls.JoiningLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_JOINING_PLAYERS" )); 
	end 
end
Events.ConnectedToNetworkHost.Add ( OnHostConnect );

-------------------------------------------------
-- Event Handler: MultiplayerConnectionComplete
-------------------------------------------------
function OnConnectionCompete()
	if (not ContextPtr:IsHidden()) then
		if not Matchmaking.IsHost() then
			TransitionToStagingRoom();
		end
	end    
end
Events.MultiplayerConnectionComplete.Add( OnConnectionCompete );

-------------------------------------------------
-- Event Handler: MultiplayerNetRegistered
-------------------------------------------------
function OnNetRegistered()
	if (not ContextPtr:IsHidden()) then
		Controls.JoiningLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_JOINING_GAMESTATE" )); 
	end   
end
Events.MultiplayerNetRegistered.Add( OnNetRegistered ); 

-------------------------------------------------
-- Event Handler: PlayerVersionMismatchEvent
-------------------------------------------------
function OnVersionMismatch( iPlayerID, playerName, bIsHost )
    if( bIsHost ) then
        Events.FrontEndPopup.CallImmediate( Locale.ConvertTextKey( "TXT_KEY_MP_VERSION_MISMATCH_FOR_HOST", playerName ) );
    	Matchmaking.KickPlayer( iPlayerID );
    else
        Events.FrontEndPopup.CallImmediate( Locale.ConvertTextKey( "TXT_KEY_MP_VERSION_MISMATCH_FOR_PLAYER" ) );
        HandleExitRequest();
    end
end
Events.PlayerVersionMismatchEvent.Add( OnVersionMismatch );

-------------------------------------------------
-- Event Handler: BeforeModsDeactivate/AfterModsActivate
-------------------------------------------------
function OnBeforeModsDeactivate()
	g_modsActivating = true;
end
Events.BeforeModsDeactivate.Add( OnBeforeModsDeactivate );

function OnAfterModsActivate()
	g_modsActivating = false;
end
Events.AfterModsActivate.Add( OnAfterModsActivate );

-------------------------------------------------
-- Show / Hide Handler
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
	if( not bIsInit ) then
		if not bIsHide then
			g_exiting = false;
			-- Activate only the DLC allowed for this MP game.  Mods will also deactivated/activate too.
			if (not ContextPtr:IsHotLoad()) then 
				local prevCursor = UIManager:SetUICursor( 1 );
				local bChanged = Modding.ActivateAllowedDLC();
				UIManager:SetUICursor( prevCursor );
				
				-- Send out an event to continue on, as the ActivateDLC may have swapped out the UI	
				Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "JoiningRoom" );
			end
						
    	Controls.JoiningLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_JOINING_ROOM" );
		end
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------
-------------------------------------------------
function OnUpdateUI( type, tag, iData1, iData2, strData1)   
	if (type == SystemUpdateUIType.RestoreUI and tag == "JoiningRoom" and not g_exiting) then
		LuaEvents.CloseAnyQueuedMy2KPopup();
		if (ContextPtr:IsHidden()) then			
			UIManager:QueuePopup(ContextPtr, PopupPriority.JoiningScreen );    
		end
	end
end
Events.SystemUpdateUI.Add( OnUpdateUI );
