-------------------------------------------------
-------------------------------------------------
function ResetMultiplayerOptions()

	-- Default custom civ names
	PreGame.SetLeaderName( 0, "");
	PreGame.SetCivilizationDescription( 0, "");
	PreGame.SetCivilizationShortDescription( 0, "");
	PreGame.SetCivilizationAdjective( 0, "");
	
		-- Default Map Size
	local worldSize = GameInfo.Worlds["WORLDSIZE_SMALL"];
	if(worldSize == nil) then
		worldSize = GameInfo.Worlds()(); -- Get first world size found.
	end
	PreGame.SetRandomWorldSize( false );
	PreGame.SetWorldSize( worldSize.ID );
	PreGame.SetNumMinorCivs( worldSize.DefaultMinorCivs );
	
	-- Default Map Type
	PreGame.SetLoadWBScenario(false);
	PreGame.SetRandomMapScript(false);
	local mapScript = nil;
	for row in GameInfo.MapScripts{FileName = "Assets\\Maps\\Protean.lua"} do
		if mapScript == nil then
			mapScript = row;
		end
	end
	if(mapScript ~= nil) then
		PreGame.SetMapScript(mapScript.FileName);
	else
		local bFound = false;
		-- This shouldn't happen.  The backup plan is to find the first map script that supports multiplayer.
		for row in GameInfo.MapScripts{SupportsMultiplayer = 1} do
			if not( ( row.RequiresMy2K == 1 and not FiraxisLive.IsConnected() ) or ( row.FiraxisLiveKey ~= nil and FiraxisLive.GetKeyValue(row.FiraxisLiveKey) ~= 1 ) ) then
				if not bFound then
				print("Adding " .. row.FileName);
					PreGame.SetMapScript(row.FileName);
					bFound = true;
				end
			else
				print("Filtering out " .. row.FileName .. " because it requires My2K or a FiraxisLiveKey." );
			end
		end
	end

	-- Default Planet
	PreGame.SetPlanet( -1 );  -- NO_PLANET

	-- Default Game Pace
	PreGame.SetGameSpeed(0);

	-- Default Start Era
	PreGame.SetEra(0);

	-- Reset Max Turns
	PreGame.SetMaxTurns(0);
	PreGame.SetInitialMaxTurns(0);

	PreGame.ResetGameOptions();
	PreGame.ResetMapOptions();
	
	-- Default Game Options
	if (PreGame.IsHotSeatGame()) then
		PreGame.SetGameOption("GAMEOPTION_DYNAMIC_TURNS", false);
		PreGame.SetGameOption("GAMEOPTION_SIMULTANEOUS_TURNS", false);
	else
		PreGame.SetGameOption("GAMEOPTION_DYNAMIC_TURNS", true);
		PreGame.SetGameOption("GAMEOPTION_SIMULTANEOUS_TURNS", false);
	end

	-- Default Staggered Player Start to off until we can come up with a good design for humans
	-- hot joining into staggered ai players.
	PreGame.SetGameOption("GAMEOPTION_NO_STAGGERED_START", false);

	-- Default these to their state in the options manager
	PreGame.SetQuickCombat( OptionsManager.GetMultiplayerQuickCombatEnabled() );
	PreGame.SetQuickMovement( OptionsManager.GetMultiplayerQuickMovementEnabled() );
end

-------------------------------------------------
-------------------------------------------------

