-------------------------------------------------
-- Turn Processing Popup
-------------------------------------------------
include( "IconSupport" );
include( "SupportFunctions" );

local ms_IsShowingMinorPower = false;
------------------------------------------------------------
------------------------------------------------------------
function GetPlayer (iPlayerID)
	if (iPlayerID < 0) then
		return nil;
	end

	if (Players[iPlayerID]:IsHuman()) then
		return nil;
	end;

	return Players[iPlayerID];
end

-------------------------------------------------
-- OnAITurnStart
-------------------------------------------------
function OnAITurnStart(iPlayerID)
	
	if(PreGame.IsMultiplayerGame()) then
		-- Turn Queue UI (see ActionInfoPanel.lua) replaces the turn processing UI in multiplayer.  
		return;
	end

	if( ContextPtr:IsHidden() ) then
		ContextPtr:SetHide( false );
		Controls.Anim:SetHide( true );
		ms_IsShowingMinorPower = false;
	end
	
	local player = GetPlayer(iPlayerID);
	if (player == nil) then
		return;	
	end

	-- Determine if the local player has met this player, else we will just a generic processing message
	local pLocalPlayer = Players[ Game.GetActivePlayer() ];
	local pLocalTeam = Teams[ pLocalPlayer:GetTeam() ];
    local bMet = pLocalTeam:IsHasMet( player:GetTeam() ) or pLocalPlayer:IsObserver();

	local bIsNeutralProxy = player:IsNeutralProxy();
	
	if (bIsNeutralProxy and ms_IsShowingMinorPower) then
		-- If we are already showing the Minor Civ processing, just exit.  We don't show them individually because they are usually quick to process
		return;
	end

	local civDescription;
	local bIsAlien = player:IsAlien();
	if (bIsAlien and Game.IsOption(GameOptionTypes.GAMEOPTION_NO_BARBARIANS)) then
		-- Even if there are no aliens, we will get this call, just skip out if they are turned off
		return;
	end

	local showMetIcon = false;
	if (bMet or bIsNeutralProxy or bIsAlien) then	
		showMetIcon = true;
		if (bIsNeutralProxy) then
			civDescription = Locale.ConvertTextKey( "TXT_KEY_PROCESSING_MINOR_POWERS" );
			ms_IsShowingMinorPower = true;
		else
			local civType = player:GetCivilizationType();
			local civInfo = GameInfo.Civilizations[civType];
			local strCiv = Locale.ConvertTextKey(civInfo.ShortDescription);
			ms_IsShowingMinorPower = false;
			if(strCiv and #strCiv > 0) then
				civDescription = Locale.ConvertTextKey(strCiv);
			else	
				civDescription = Locale.ConvertTextKey( "TXT_KEY_MULTIPLAYER_DEFAULT_PLAYER_NAME", iPlayerID + 1 );
			end
				
			civDescription = Locale.ConvertTextKey( "TXT_KEY_PROCESSING_TURN_FOR", civDescription );
		end
	else
		civDescription = Locale.ConvertTextKey( "TXT_KEY_PROCESSING_TURN_FOR_UNMET_PLAYER", iPlayerID + 1 );
		ms_IsShowingMinorPower = false;
	end	

	CivIconHookup(showMetIcon and iPlayerID or -1, 64, Controls.CivIcon, Controls.CivIconBG, nil, false, false, Controls.CivIconHighlight );
		
	if (Controls.Anim:IsHidden()) then
		Controls.Anim:SetHide( false );
		Controls.Anim:BranchResetAnimation();
	end
	Controls.TurnProcessingTitle:SetText(civDescription);

end
Events.PlayerProcessingTurnStart.Add( OnAITurnStart );
-------------------------------------------------------------------------
-- OnPlayerTurnStart
-- Human player's turn, hide the UI
-------------------------------------------------------------------------
function OnPlayerTurnStart()
	if (not ContextPtr:IsHidden()) then
		Controls.Anim:Reverse();
		Controls.Anim:Play();
	end
end
Events.ActivePlayerTurnStart.Add( OnPlayerTurnStart );
Events.RemotePlayerTurnStart.Add( OnPlayerTurnStart );

-------------------------------------------------------------------------
-- Callback while the alpha animation is playing.
-- It will also be called once, when the animation stops.
function OnAlphaAnim()
	if (Controls.Anim:IsStopped() and Controls.Anim:GetAlpha() == 0.0) then
		Controls.Anim:SetHide( true );
		ContextPtr:SetHide( true );
		--print("Hiding TurnProcessing");
	end
end
Controls.Anim:RegisterAnimCallback( OnAlphaAnim );