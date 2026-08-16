-------------------------------------------------
-- New Turn Popup
-------------------------------------------------
include( "IconSupport" );
include( "SupportFunctions" );
include( "GameplayUtilities" );

------------------------------------------------------------
------------------------------------------------------------
-- utility functions
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

-------------------------------------------------
-- OnTurnStart
-------------------------------------------------
function OnTurnStart ()

	-- if this is not the human player, ignore the turn ending
	local player = GetPlayer();
	if (player == nil) then
		return;	
	end

	if (not player:IsTurnActive()) then
		return;
	end

	-- Set Civ Icon
	--CivIconHookup(  Game.GetActivePlayer(), 64, Controls.CivIcon, Controls.CivIconBG, Controls.CivIconShadow, false, true); 
		
	-- Update Turn
	local strTurn : string  = Locale.ConvertTextKey("TXT_KEY_TIME_TURN_SAVE", Game.GetGameTurn());
	local player : object = Players[Game.GetActivePlayer()];
	local strInfo : string = GameplayUtilities.GetLocalizedLeaderTitle(player);
	
	Controls.Anim:			SetHide( false );
	Controls.Anim:			BranchResetAnimation();
	Controls.NewTurn:		SetText(strTurn);
	Controls.NewTurnInfo:	SetText(strInfo);

	UIManager:SetUICursor( 0 );

end
Events.ActivePlayerTurnStart.Add( OnTurnStart );
