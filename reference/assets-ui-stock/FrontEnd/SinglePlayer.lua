-------------------------------------------------
-- Main Menu
-------------------------------------------------
include("LoadoutUtils");

-------------------------------------------------
-- Script Body
-------------------------------------------------
local bHideUITest = true;
local bHideLoadGame = true;
local bHidePreGame = true;
local fTime = 0;
local iFTUESponsorID = GameInfo.Civilizations["CIVILIZATION_KAVITHAN"].ID;
local iFTUECargoID = GameInfo.Cargo["CARGO_WEAPONRY"].ID;
local iFTUEColonistID = GameInfo.Colonists["COLONIST_ENGINEERS"].ID;
local iFTUESpacecraftID = GameInfo.Spacecraft["SPACECRAFT_FUSION_REACTOR"].ID;
local animControls = {"PlayNow","Seeded","Load","Scenarios","Tutorial","Back"};


-- ===========================================================================
--
-- ===========================================================================
function Initialize()
end


-- ===========================================================================
function ResetGameOption()
	-- Reset some of the advanced settings for PreGame.
	-- This is to ensure that play now doesn't get borked or that Mutiplayer settings do not carry over.
	PreGame.SetPrivateGame(false);
	PreGame.SetGameType(GameTypes.GAME_SINGLE_PLAYER);
	PreGame.ResetSlots();
	PreGame.ResetGameOptions();
	PreGame.ResetMapOptions();
	PreGame.LoadPreGameSettings();
end

-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsHide ) then
	
		ResetGameOption();	
		    
        Controls.CivBELogo:SetTexture( "CivilizationBE_Logo.dds" );
        for _,animControl in pairs(animControls) do
			Controls[animControl.."Slide"]:SetToBeginning();
			Controls[animControl.."Alpha"]:SetToBeginning();
			Controls[animControl.."Slide"]:Play();
			Controls[animControl.."Alpha"]:Play();
			Events.AudioPlay2DSound("AS2D_INTERFACE_MENU_ITEM_SLIDE_4");
		end
		Controls.ButtonsFadeIn:SetToBeginning();
		Controls.ButtonsFadeIn:Play();
        local str = Locale.ConvertTextKey( "TXT_KEY_PLAY_NOW_SETTINGS" ) .. "[NEWLINE]";
		      
        local civIndex = PreGame.GetCivilization( 0 );
        if( civIndex ~= -1 ) then
            civ = GameInfo.Civilizations[ civIndex ];
			local leader = nil;
			for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
				leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
			end
			local leaderDescription = leader.Description;
            
            str = str .. Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER_CIV", Locale.ConvertTextKey( leaderDescription ), Locale.ConvertTextKey( civ.ShortDescription )) .. "[NEWLINE]";
        else
            str = str .. Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER" ) .. "[NEWLINE]";
        end
        
        str = str .. Locale.ConvertTextKey( "TXT_KEY_MAP_SCRIPT" ) .. ": ";
        if( not PreGame.IsRandomMapScript() ) then 
        	local savedMapScript = PreGame.GetMapScript();
        	local foundScript = false;
		
			for mapScript in GameInfo.MapScripts() do
				if(mapScript.FileName == savedMapScript) then
					str = str .. Locale.ConvertTextKey( mapScript.Name or mapScript.Description ) .. "[NEWLINE]";
					foundScript = true;
				end
			end
            
			if(not foundScript) then
				local mapData = UI.GetMapPreview(savedMapScript);
				if(mapData ~= nil) then
					str = str .. Locale.ConvertTextKey(mapData.Name) .. "[NEWLINE]";
				else
					PreGame.SetRandomMapScript(true);
				end
			end
        end
           
        local info = nil;
        if(PreGame.IsRandomMapScript()) then
            str = str .. Locale.ConvertTextKey( "TXT_KEY_RANDOM_MAP_SCRIPT" ) .. "[NEWLINE]";
        end

        if( not PreGame.IsRandomWorldSize() ) then
            info = GameInfo.Worlds[ PreGame.GetWorldSize() ];
            if(info ~= nil) then
				str = str .. Locale.ConvertTextKey( "TXT_KEY_MAP_SIZE_FORMAT", Locale.ConvertTextKey( info.Description )) .. "[NEWLINE]";
			end
        else
            str = str .. Locale.ConvertTextKey( "TXT_KEY_MAP_SIZE_FORMAT", Locale.ConvertTextKey( "TXT_KEY_RANDOM_MAP_SIZE" )) .. "[NEWLINE]";
        end

		if( not PreGame.IsRandomPlanet() ) then
			info = GameInfo.Planets[ PreGame.GetPlanet() ];
			if(info ~= nil) then
				str = str .. Locale.ConvertTextKey( "TXT_KEY_MAP_TERRAIN_FORMAT", Locale.ConvertTextKey( info.Description )) .. "[NEWLINE]";
			end
		else
			str = str .. Locale.ConvertTextKey( "TXT_KEY_MAP_TERRAIN_FORMAT", Locale.ConvertTextKey( "TXT_KEY_RANDOM_MAP_TERRAIN" )) .. "[NEWLINE]";
		end
      
        info = GameInfo.HandicapInfos[ PreGame.GetHandicap( 0 ) ];
        if(info ~= nil) then
	        str = str .. Locale.ConvertTextKey( "TXT_KEY_AD_HANDICAP_SETTING", Locale.ConvertTextKey( info.Description )) .. "[NEWLINE]";
        end
        
		info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
        if(info ~= nil) then
			str = str .. Locale.ConvertTextKey( "TXT_KEY_AD_GAME_SPEED_SETTING", Locale.ConvertTextKey( info.Description ));	
		end        

		local maxTurns = PreGame.GetMaxTurns();
		if(maxTurns ~= 0) then
			str = str .. "[NEWLINE]" .. Locale.ConvertTextKey( "TXT_KEY_AD_SETUP_MAX_TURNS_1", maxTurns );
		end
        
        Controls.StartGameButton:SetToolTipString( str );
    else
        Controls.CivBELogo:UnloadTexture();
    end
    
    local bHideScenariosButton = true;
    for row in Modding.GetInstalledFiraxisScenarios() do
		bHideScenariosButton = false;
		break;
	end
		
    Controls.ScenariosButton:SetHide(bHideScenariosButton);    
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------
-- StartGame Button Handler
-------------------------------------------------
function StartGameClick()

	PreGame.SetUsingFirstTimeUserExperience( false );

	-- Make sure game rules aren't whack...

	-- At least 2 teams.
	local uniqueTeams = false;
	local playerTeam = PreGame.GetTeam(0);	    
	for i = 1, GameDefines.MAX_MAJOR_CIVS-1 do
		if( PreGame.GetSlotStatus(i) == SlotStatus.SS_COMPUTER ) then
        	if( PreGame.GetTeam(i) ~= playerTeam ) then
				uniqueTeams = true;
				i = GameDefines.MAX_MAJOR_CIVS-1;	-- short circuit loop
        	end
    	end
	end
	if not uniqueTeams then
		for i = 1, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
			PreGame.SetCivilization(i, -1);
			PreGame.SetTeam(i, i);
		end
	end
	
	Events.SerialEventStartGame();
	UIManager:SetUICursor( 1 );
end
Controls.StartGameButton:RegisterCallback( Mouse.eLClick, StartGameClick );


-- ===========================================================================
--	Raise Game Setup
-- ===========================================================================
function OnSeededStartClicked()
	--UIManager:QueuePopup( Controls.PreGameScreen, PopupPriority.PreGameScreen );
	UIManager:QueuePopup( Controls.GameSetupScreen, PopupPriority.GameSetupScreen );
end
Controls.SeededStartButton:RegisterCallback( Mouse.eLClick, OnSeededStartClicked );


-------------------------------------------------
-- Toggle FTUE - First Time User Experience
-------------------------------------------------
--function OnFTUEClicked()		
	--local isUsingFTUE = not PreGame.IsUsingFirstTimeUserExperience();
--	PreGame.SetUsingFirstTimeUserExperience( true );
	
	-- Use predefined loadout
--	local playerID = LoadoutUtils.GetPlayerID();
--	PreGame.SetCivilization(playerID, iFTUESponsorID);
--	PreGame.SetLoadoutCargo(playerID, iFTUECargoID);
--	PreGame.SetLoadoutColonist(playerID, iFTUEColonistID);
--	PreGame.SetLoadoutSpacecraft(playerID, iFTUESpacecraftID);
--	PreGame.SetUsingFirstTimeUserExperience(playerID, true);

--	Events.SerialEventStartGame();
--	UIManager:SetUICursor( 1 );
--end
--Controls.StartWithFTUE:RegisterCallback( Mouse.eLClick, OnFTUEClicked );

-------------------------------------------------
-- Scenarios Button Handler
-------------------------------------------------
--function ScenariosClicked()
--	UIManager:QueuePopup( Controls.ScenariosScreen, PopupPriority.GameSetupScreen );
--end
--Controls.ScenariosButton:RegisterCallback( Mouse.eLClick, ScenariosClicked );


-------------------------------------------------
-- LoadGame Button Handler
-------------------------------------------------
function LoadGameClick()
    UIManager:QueuePopup( Controls.LoadGameScreen, PopupPriority.LoadGameScreen );
end
Controls.LoadGameButton:RegisterCallback( Mouse.eLClick, LoadGameClick );

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function BackButtonClick()

    UIManager:DequeuePopup( ContextPtr );

    Events.AudioPlay2DSound("AS2D_INTERFACE_BUTTON_CLICK_BACK");

end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );


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


-- ===========================================================================
Initialize();