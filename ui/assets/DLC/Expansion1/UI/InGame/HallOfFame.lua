-------------------------------------------------
-- Hall of Fame
-------------------------------------------------
include( "IconSupport" );
include( "InstanceManager" );
include( "MapUtilities" );
----------------------------------------------------------------        
----------------------------------------------------------------        
local m_bIsEndGame = (ContextPtr:GetID() == "EndGameHallOfFame");

local g_GamesIM = InstanceManager:new( "GameInstance", "GameItem", Controls.GameStack );

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnBack()
	UIManager:DequeuePopup( ContextPtr );
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );

----------------------------------------------------------------        
----------------------------------------------------------------
function PopulateGameResults()
	g_GamesIM:ResetInstances();
	
	local gameEntries = {};
	
	local games = UI.GetHallofFameData();
	
	for i, v in pairs(games) do
	
		local civ = GameInfo.Civilizations[v.PlayerCivilizationType];
		if(civ ~= nil) then
			
			-- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
			local leader = nil;
			for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
				leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
			end
			if(leader ~= nil) then
			
				local controlTable = g_GamesIM:GetInstance();
				table.insert(gameEntries, controlTable);
				
				-- Fill In Player Info
				--if(v.PlayerTeamWon)then
				--	controlTable.DidWin:LocalizeAndSetText("TXT_KEY_VICTORY_BANG");
				--else
				--	controlTable.DidWin:LocalizeAndSetText("TXT_KEY_DEFEAT_BANG");
				--end
								
				local leaderDescription = leader.Description;

				--IconHookup( leader.PortraitIndex, 64, leader.IconAtlas, controlTable.LeaderPortrait );
				IconHookup( civ.PortraitIndex, 45, civ.IconAtlas, controlTable.CivSymbol );
				
				--Get Civ colors
				local primaryColorType	= GameInfo.PlayerColors[civ.DefaultPlayerColor].PrimaryColor;
				local secondaryColorType= GameInfo.PlayerColors[civ.DefaultPlayerColor].SecondaryColor;
				local primaryColorInfo	= GameInfo.Colors[primaryColorType];
				local secondaryColorInfo= GameInfo.Colors[secondaryColorType];
				primaryColorRaw			= {x=primaryColorInfo.Red, y=primaryColorInfo.Green, z=primaryColorInfo.Blue, w=primaryColorInfo.Alpha};
				secondaryColorRaw		= {x=secondaryColorInfo.Red, y=secondaryColorInfo.Green, z=secondaryColorInfo.Blue, w=secondaryColorInfo.Alpha};

				--If no custom name
				if(v.LeaderName == nil or v.LeaderName == "")then
					controlTable.LeaderName:LocalizeAndSetText(Locale.ToUpper(leaderDescription));
					controlTable.LeaderName:SetColor(RGBAObjectToABGRHex(primaryColorRaw), 0);
					controlTable.LeaderName:SetColor(RGBAObjectToABGRHex(secondaryColorRaw), 1);
					controlTable.SponsorName:LocalizeAndSetText(civ.ShortDescription);
				else
					controlTable.LeaderName:LocalizeAndSetText(Locale.ToUpper(v.LeaderName));
					controlTable.SponsorName:LocalizeAndSetText(v.CivilizationName);
				end

				controlTable.LeaderStack:CalculateSize();
				controlTable.LeaderStack:ReprocessAnchoring();
				
				local info = GameInfo.HandicapInfos[ v.PlayerHandicapType ];
				if( info ~= nil) then
					--IconHookup( info.PortraitIndex, 32, info.IconAtlas, controlTable.Difficulty );
					controlTable.Difficulty:SetText( Locale.ConvertTextKey( info.Description ) );	
				else
					controlTable.Difficulty:SetHide(true);
				end
				controlTable.Score:SetText(v.Score);

				-- Fill In Game Info
				local civ = nil;
				if(v.WinningTeamLeaderCivilizationType ~= nil) then
					civ = GameInfo.Civilizations[v.WinningTeamLeaderCivilizationType];
				end
				
				if(v.PlayerTeamWon)then
					controlTable.WinningSponsorName:LocalizeAndSetText("TXT_KEY_YOU");
				else
					if(civ)then
						controlTable.WinningSponsorName:LocalizeAndSetText(civ.ShortDescription);
					else
						controlTable.WinningSponsorName:LocalizeAndSetText("TXT_KEY_CITY_STATE_NOBODY");
					end
				end
						
				if(v.VictoryType)then
					local victory = GameInfo.Victories[v.VictoryType];
					if (victory) then
						controlTable.WinType:LocalizeAndSetText(victory.VictoryStatement);
					end
				else
					controlTable.WinType:LocalizeAndSetText("");
				end
				
				local mapInfo = MapUtilities.GetBasicInfo(v.MapName);				
				local planetInfo = GameInfo.Planets[v.PlanetType];
				local planetTypeStr : string = MapUtilities.GetPlanetTypeDescription(mapInfo.Name, planetInfo.ID);

				controlTable.MapType:SetText( planetTypeStr );
				
				info = GameInfo.Worlds[ v.WorldSize ];
				if ( info ~= nil ) then
					controlTable.MapSize:SetText( Locale.ConvertTextKey( info.Description ) );
				end
				
				info = GameInfo.GameSpeeds[ v.GameSpeedType ];
				if ( info ~= nil ) then
					controlTable.Speed:SetText( Locale.ConvertTextKey( info.Description ) );
				end
				
				--controlTable.MaxTurns:LocalizeAndSetText("TXT_KEY_MAX_TURN_FORMAT", v.WinningTurn);
				
				info = GameInfo.Eras[ v.StartEraType ];
				if ( info ~= nil ) then
					controlTable.StartEraTurns:LocalizeAndSetText("TXT_KEY_CUR_TURNS_FORMAT", v.WinningTurn);
					controlTable.TimeFinished:SetText(v.GameEndTime);
				end

				controlTable.TimeStampStack:CalculateSize();
				controlTable.TimeStampStack:ReprocessAnchoring();
				
				controlTable.SettingStack:CalculateSize();
				controlTable.SettingStack:ReprocessAnchoring();
				
				--local itemY = controlTable.SettingStack:GetSizeY();
				--controlTable.GameItem:SetSizeY(itemY-20);
			end
		end
	end
	
	Controls.HallOfFameEmpty:SetHide( table.count(gameEntries) > 0 );
	
	Controls.GameStack:CalculateSize();
	Controls.GameStack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();
end

----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
    if( uiMsg == KeyEvents.KeyDown )
    then
        if( wParam == Keys.VK_RETURN or wParam == Keys.VK_ESCAPE ) then
			OnBack();
        end
    end
    return true;
end
if( not m_bIsEndGame ) then
	ContextPtr:SetInputHandler( InputHandler );
	Controls.Background:SetHide(false);
end

-------------------------------------------------
-------------------------------------------------
function ShowHideHandler( bIsHide )
	if(not bIsHide)then
		PopulateGameResults();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------------------------
-- If we hear a multiplayer game invite was sent, exit
-- so we don't interfere with the transition
-------------------------------------------------
function OnMultiplayerGameInvite()
   	if( ContextPtr:IsHidden() == false ) then
		OnBack();
	end
end

Events.MultiplayerGameLobbyInvite.Add( OnMultiplayerGameInvite );
Events.MultiplayerGameServerInvite.Add( OnMultiplayerGameInvite );
----------------------------------------------------------------        
----------------------------------------------------------------        

if( m_bIsEndGame ) then
    Controls.FrontEndFrame:SetHide( true );
    Controls.Background:SetHide(true);
end