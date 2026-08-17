include( "InstanceManager" );
include( "IconSupport" );
include( "SupportFunctions" );
include( "UniqueBonuses" );
include( "MapUtilities" );

local g_IsSingle = true;
local g_IsAuto   = false;
local g_IsDeletingFile = true;

-- Global Constants
g_InstanceManager = InstanceManager:new( "LoadButton", "Button", Controls.LoadFileButtonStack );
s_maxCloudSaves = Steam.GetMaxCloudSaves();

-- Global Variables
g_SavedGames = {};			-- A list of all saved game entries.
g_SelectedEntry = nil;		-- The currently selected entry.


function GetSaveFromNameBox()
	local saveName = Controls.NameBox:GetText();

	return (saveName:gsub("^%s*(.-)%s*$", "%1"))
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnSave()
	if(g_SelectedEntry == nil) then
		local newSave = GetSaveFromNameBox();
		for i, v in ipairs(g_SavedGames) do
			if(v.DisplayName ~= nil and Locale.Length(v.DisplayName) > 0) then
				if(Locale.ToUpper(newSave) == Locale.ToUpper(v.DisplayName)) then
					g_SelectedEntry = v;		
				end
			end
		end
	end
	
	if(g_SelectedEntry ~= nil) then
		if(g_SelectedEntry.SaveData == nil and g_SelectedEntry.IsCloudSave) then
			for i, v in ipairs(g_SavedGames) do
				if(v == g_SelectedEntry) then
					if (PreGame.IsMultiplayerGame() and PreGame.GameStarted()) then
						Steam.CopyLastAutoSaveToSteamCloud( i );
					else
						Steam.SaveGameToCloud(i);
					end
					break;
				end
			end
		else
			g_IsDeletingFile = false;
			Controls.Message:SetText( Locale.ConvertTextKey("TXT_KEY_OVERWRITE_TXT") );
			Controls.DeleteConfirm:SetHide(false);
			return;
		end
	else
		if (PreGame.IsMultiplayerGame() and PreGame.GameStarted()) then
			UI.CopyLastAutoSave( GetSaveFromNameBox() );
		else
			UI.SaveGame( GetSaveFromNameBox() );
		end
	end
	
	Controls.NameBox:ClearString();
	SetupFileButtonList();
	OnBack();
end
Controls.SaveButton:RegisterCallback( Mouse.eLClick, OnSave );
Controls.ArrowButton:RegisterCallback( Mouse.eLClick, OnSave );


function GetDefaultSaveName()
	if (PreGame.GameStarted()) then 
		local iPlayer = Game.GetActivePlayer();
		local leaderName = PreGame.GetLeaderName(iPlayer);
		local civ = PreGame.GetCivilization();
		local civInfo = GameInfo.Civilizations[civ];
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civInfo.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
	
		-- Use custom name if set.
		local leaderDescription = Locale.ConvertTextKey(leader.Description);
		if leaderName ~= nil and leaderName ~= ""then
			leaderDescription = leaderName;
		end
	        
		return leaderDescription .. "_TURN " .. Game.GetGameTurn();
	else
		-- Saving before the game starts, this will just save the setup data
		return Locale.ConvertTextKey("TXT_KEY_DEFAULT_GAME_CONFIGURATION_NAME");
	end
end


----------------------------------------------------------------        
----------------------------------------------------------------
function OnEditBoxChange( _, _, bIsEnter )	
	local text = Controls.NameBox:GetText();
	
	if( g_SelectedEntry ~= nil ) then
		g_SelectedEntry.Instance.SelectHighlight:SetHide( true );
		local iPlayer = 0;
		if (PreGame.GameStarted()) then
			local iPlayer = Game.GetActivePlayer();
			SetSaveInfoToCiv(PreGame.GetCivilization(), PreGame.GetGameSpeed(), PreGame.GetEra(), 0, 
							 PreGame.GetHandicap(), PreGame.GetWorldSize(), PreGame.GetMapScript(), nil, 
							 PreGame.GetLeaderName(iPlayer),PreGame.GetCivilizationDescription(iPlayer), Players[iPlayer]:GetCurrentEra(), PreGame.GetGameType() );
		else
			local iPlayer = Matchmaking.GetLocalID();
			SetSaveInfoToCiv(PreGame.GetCivilization(), PreGame.GetGameSpeed(), PreGame.GetEra(), 0, 
							 PreGame.GetHandicap(), PreGame.GetWorldSize(), PreGame.GetMapScript(), nil, 
							 PreGame.GetLeaderName(iPlayer),PreGame.GetCivilizationDescription(iPlayer), PreGame.GetEra(), PreGame.GetGameType() );
		end
						 
		g_SelectedEntry = nil;
	end
	
	if(not ValidateText(text)) then
		bIsEnter = false;
		Controls.SaveButton:SetDisabled(true);
		Controls.SaveButtonLabel:SetColor(0xff474441,0); 
		Controls.ArrowButton:SetDisabled(true);
	else
		Controls.SaveButton:SetDisabled(false);
		Controls.SaveButtonLabel:SetColor(0xffffffff,0); 
		Controls.ArrowButton:SetDisabled(false);
	end	
	Controls.Delete:SetDisabled(true);
	Controls.DeleteLabel:SetColor(0xff474441,0); 
	
	if( bIsEnter ) then
	    OnSave();
	end
end
Controls.NameBox:RegisterCallback( OnEditBoxChange )

Controls.NameBox:RegisterStringChangedCallback(
	function()
		OnEditBoxChange( "", "", false );
	end
);

----------------------------------------------------------------        
----------------------------------------------------------------
function OnDelete()
	g_IsDeletingFile = true;
	Controls.Message:SetText( Locale.ConvertTextKey("TXT_KEY_CONFIRM_TXT") );
	Controls.DeleteConfirm:SetHide(false);
	Controls.BGBlock:SetHide(true);
end
Controls.Delete:RegisterCallback( Mouse.eLClick, OnDelete );

----------------------------------------------------------------        
----------------------------------------------------------------
function OnYes()
	Controls.DeleteConfirm:SetHide(true);
	Controls.BGBlock:SetHide(false);
	if(g_IsDeletingFile) then
		UI.DeleteSavedGame( g_SelectedEntry.FileName );
	else
		if(g_SelectedEntry.IsCloudSave) then
			for i, v in ipairs(g_SavedGames) do
				if(v == g_SelectedEntry) then
					Steam.SaveGameToCloud(i);
					break;
				end
			end
		else
			UI.SaveGame( Controls.NameBox:GetText() );
		end
		
		OnBack();
	end
	
	SetupFileButtonList();
	Controls.NameBox:ClearString();
	Controls.SaveButton:SetDisabled(true);
	Controls.SaveButtonLabel:SetColor(0xff474441,0); 
	Controls.ArrowButton:SetDisabled(true);
	Controls.OverwriteFile:SetHide(true);
	Controls.LoadFileButtonStack:CalculateSize();
	Controls.LoadFileButtonStack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();
end
Controls.Yes:RegisterCallback( Mouse.eLClick, OnYes );

----------------------------------------------------------------        
----------------------------------------------------------------
function OnNo( )
	Controls.DeleteConfirm:SetHide(true);
	Controls.BGBlock:SetHide(false);
end
Controls.No:RegisterCallback( Mouse.eLClick, OnNo );
-------------------------------------------------
-------------------------------------------------
function OnBack()
	-- Test if we are modal or a popup
	if (UIManager:IsModal( ContextPtr )) then
		UIManager:PopModal( ContextPtr );
	else
		UIManager:DequeuePopup( ContextPtr );
	end
    Controls.NameBox:ClearString();
	Controls.OverwriteFile:SetHide(true);
    SetSelected( nil );
	Controls.LoadFileButtonStack:CalculateSize();
	Controls.LoadFileButtonStack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBack );
-------------------------------------------------
-------------------------------------------------
Controls.CloudCheck:RegisterCheckHandler(function(checked)

	if(checked) then
		Controls.NameBox:ClearString();
	else
		Controls.NameBox:SetText(GetDefaultSaveName());
	end
	SetSelected( nil );
	SetupFileButtonList();
end);
-------------------------------------------------
-------------------------------------------------
function SetSelected( entry )
	if( g_SelectedEntry == entry and entry ~= nil) then
		entry.Instance.SelectHighlight:SetHide( true );
		g_SelectedEntry = nil;
		Controls.Delete:SetDisabled(true);
		Controls.DeleteLabel:SetColor(0xff474441,0); 
		Controls.OverwriteFile:SetHide(true);
	else
		if( g_SelectedEntry ~= nil ) then
			g_SelectedEntry.Instance.SelectHighlight:SetHide( true );
		end
    
		g_SelectedEntry = nil;
    
		if( entry ~= nil) then
			Controls.NameBox:SetText( entry.DisplayName );
			entry.Instance.SelectHighlight:SetHide( false );

			g_SelectedEntry = entry;
		
			if(entry.SaveData == nil and entry.FileName ~= nil and not entry.IsCloudSave) then
				entry.SaveData = PreGame.GetFileHeader(entry.FileName);
			end
		
			if(entry.SaveData ~= nil) then
				local header = entry.SaveData;
			
				local date;
				if(entry.FileName) then
					date = UI.GetSavedGameModificationTime(entry.FileName);
				end
				Controls.OverwriteFile:SetHide(false);
				SetSaveInfoToCiv(header.PlayerCivilization, nil, header.StartEra, header.TurnNumber, nil, nil, nil, date, header.LeaderName, header.CivilizationName, header.CurrentEra, header.GameType);
				Controls.Delete:SetDisabled(false); 
				Controls.DeleteLabel:SetColor(0xffffffff,0); 
		
			elseif(entry.IsCloudSave) then
				SetSaveInfoToEmptyCloudSave();
			else
				SetSaveInfoToNone();
			end
		
			Controls.SaveButton:SetDisabled(false);  
			Controls.SaveButtonLabel:SetColor(0xffffffff,0);
			Controls.ArrowButton:SetDisabled(false);
			
		else -- No saves are selected
			local cloudChecked = Controls.CloudCheck:IsChecked();
			if (Controls.CloudCheck:IsChecked() == false) then
				Controls.SaveButton:SetDisabled(false);  
				Controls.SaveButtonLabel:SetColor(0xffffffff,0);
				Controls.ArrowButton:SetDisabled(false);
			end

			if (PreGame.GameStarted()) then
				local iPlayer = Game.GetActivePlayer();
				SetSaveInfoToCiv(PreGame.GetCivilization(), PreGame.GetGameSpeed(), PreGame.GetEra(), Game.GetElapsedGameTurns(), 
								 PreGame.GetHandicap(), PreGame.GetWorldSize(), PreGame.GetMapScript(), nil,
								 PreGame.GetLeaderName(iPlayer), PreGame.GetCivilizationDescription(iPlayer), Players[iPlayer]:GetCurrentEra(), PreGame.GetGameType() );
			else
				local iPlayer = Matchmaking.GetLocalID();
				SetSaveInfoToCiv(PreGame.GetCivilization(), PreGame.GetGameSpeed(), PreGame.GetEra(), 0, 
								 PreGame.GetHandicap(), PreGame.GetWorldSize(), PreGame.GetMapScript(), nil,
								 PreGame.GetLeaderName(iPlayer), PreGame.GetCivilizationDescription(iPlayer), PreGame.GetEra(), PreGame.GetGameType() );
			end
			Controls.Delete:SetDisabled(true);
			Controls.DeleteLabel:SetColor(0xff474441,0); 
			Controls.OverwriteFile:SetHide(true);
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function SetSaveInfoToCiv(civType, gameSpeed, era, turn, difficulty, mapSize, mapScript, date, leaderName, civName, curEra, gameType)
	
	local PlayerMe;
	local myLeaderName;
	local mySponsorName;
	local myCiv = -1;

	if (Game ~= nil) then
		PlayerMe		= Game.GetActivePlayer();
		myLeaderName	= PreGame.GetLeaderName(PlayerMe);
		mySponsorName	= PreGame.GetCivilizationDescription(PlayerMe);
		myCiv			= PreGame.GetCivilization();
	else
		if(civType ~= -1) then
			PlayerMe		= civType;
			myLeaderName	= PreGame.GetLeaderName(PlayerMe);
			mySponsorName	= PreGame.GetCivilizationDescription(PlayerMe);
			myCiv			= PreGame.GetCivilization();
		end
	end
		
	local myCivInfo = GameInfo.Civilizations[myCiv];
	if ( myCivInfo ~= nil ) then
		IconHookup( myCivInfo.PortraitIndex, 64, myCivInfo.IconAtlas,  Controls.CivIcon );
	else
		CivIconHookup( 0, 64, Controls.CivIcon, nil, nil, false, true ); -- Random icon
	end

	-- Icon Hookup for Overwrite File
    local thisCiv = GameInfo.Civilizations[civType];
	if ( thisCiv ~= nil ) then
		IconHookup( thisCiv.PortraitIndex, 32, thisCiv.IconAtlas,  Controls.SavedCivIcon );
	else
		CivIconHookup( 0, 32, Controls.SavedCivIcon, nil, nil, false, true ); -- Random icon
	end

	-- Set Civ Leader & Icon Tool tips (only valid in game, not when saving configruation from hot seat.)
	if (PreGame.GameStarted()) then
		--Set primary and secondary color for current Save File
		local pPlayer				= Players[ Game.GetActivePlayer() ];
		local colorRaw1, colorRaw2	= pPlayer:GetPlayerColors();
		local primaryColor			= RGBAObjectToABGRHex(colorRaw1);
		local secondaryColor		= RGBAObjectToABGRHex(colorRaw2);
		Controls.LeaderName:SetColor(primaryColor,0);
		Controls.LeaderName:SetColor(secondaryColor,1);

		--Set primary and secondary color for Overwrite File sponsor name
		local primaryColorType	= GameInfo.PlayerColors[thisCiv.DefaultPlayerColor].PrimaryColor;
		local secondaryColorType= GameInfo.PlayerColors[thisCiv.DefaultPlayerColor].SecondaryColor;
		local primaryColorInfo	= GameInfo.Colors[primaryColorType];
		local secondaryColorInfo= GameInfo.Colors[secondaryColorType];
		local primaryColorRaw			= {x=primaryColorInfo.Red, y=primaryColorInfo.Green, z=primaryColorInfo.Blue, w=primaryColorInfo.Alpha};
		local secondaryColorRaw			= {x=secondaryColorInfo.Red, y=secondaryColorInfo.Green, z=secondaryColorInfo.Blue, w=secondaryColorInfo.Alpha};
		Controls.SavedLeaderName:SetColor(RGBAObjectToABGRHex(primaryColorRaw), 0);
		Controls.SavedLeaderName:SetColor(RGBAObjectToABGRHex(secondaryColorRaw), 1);
	end	

	local leader				= nil;
	local myLeader				= nil;
	local myLeaderDescription	= "";
	local leaderDescription		= "";
	local mySponsorDescription	= "";
	local savedSponsorDescription = "";
	if (thisCiv ~= nil ) then
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = thisCiv.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		if (myCivInfo ~= nil) then
			for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = myCivInfo.Type} do
				myLeader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
			end
		end

		if leader ~= nil then
			leaderDescription	= Locale.ConvertTextKey(leader.Description);
		end

		local leaderTrait		= GameInfo.Leader_Traits( "LeaderType ='" .. leader.Type .. "'" )();
		if (leaderTrait ~= nil) then
			local gameTrait			= GameInfo.Traits[ leaderTrait.TraitType ];
			Controls.CivIcon:SetToolTipString( Locale.ConvertTextKey( thisCiv.ShortDescription ) .. "     " .. Locale.ConvertTextKey( gameTrait.ShortDescription ) .. "[NEWLINE]" .. Locale.ConvertTextKey( gameTrait.Description ) );
		else
			Controls.CivIcon:SetToolTipString( Locale.ConvertTextKey( thisCiv.ShortDescription ) );
		end
	else
		Controls.CivIcon:SetToolTipType( nil );
	end
	if leaderName ~= nil and leaderName ~= "" then
		leaderDescription = leaderName;
	end	


	if myCivInfo ~= nil then
		mySponsorDescription = Locale.ConvertTextKey(myCivInfo.Description);
	end
	if mySponsorName ~= nil and mySponsorName ~= "" then
		mySponsorDescription = mySponsorName;
	end

	if thisCiv ~= nil then
		savedSponsorDescription = Locale.ConvertTextKey(thisCiv.Description);
	end
	if ( civName ~= nil and civName ~= "" ) then
		savedSponsorDescription = civName;
	end

	Controls.LeaderName:SetText( Locale.ToUpper(myLeaderDescription) );	
	Controls.SponsorName:SetText( mySponsorDescription );
	Controls.SavedLeaderName:SetText( Locale.ToUpper(leaderDescription) );	
	Controls.SavedSponsorName:SetText( savedSponsorDescription );

	-- Set Map Type
	local mapScript = PreGame.GetMapScript();
	local mapInfo = MapUtilities.GetBasicInfo(mapScript);
	local planet = PreGame.GetPlanet();
	Controls.TypeLabel:SetText(MapUtilities.GetPlanetTypeDescription(mapInfo.Name, planet));

	-- Set Map Size
	local info = GameInfo.Worlds[ PreGame.GetWorldSize() ];
	if ( info ~= nil ) then
		Controls.SizeLabel:SetString( Locale.ConvertTextKey( info.Description ) );
	else
		Controls.SizeLabel:SetString( Locale.ConvertTextKey( "TXT_KEY_RANDOM_MAP_SIZE" ) );
	end

	-- Set Difficulty		
    if ( difficulty ~= nil ) then
		info = GameInfo.HandicapInfos[ difficulty ];
        IconHookup( info.PortraitIndex, 64, info.IconAtlas, Controls.DifficultyIcon );
		Controls.DifficultyLabel:SetString( Locale.ConvertTextKey( info.Description ) );
    else
		--Controls.DifficultyLabel:SetHide(true);
		--Contols.DifficultyName:SetHide(true);
    end

    -- Set Game Pace
    info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
    if ( info ~= nil ) then
        IconHookup( info.PortraitIndex, 64, info.IconAtlas, Controls.SpeedIcon );
		Controls.SpeedLabel:SetString( Locale.ConvertTextKey( info.Description )  );
    else
		Controls.SpeedLabel:SetHide(true);
		Controls.SpeedName:SetHide(true);
    end

	local currentEra;
	local startEra;
		
	if(curEra ~= "") then
		currentEra = GameInfo.Eras[curEra];
	end
	
	if(era ~= "") then
		startEra = GameInfo.Eras[era];
	end
	Controls.CurrentTurn:LocalizeAndSetText("TXT_KEY_CUR_TURNS_FORMAT", turn);
							  
	-- Set Save file time
	if(date ~= nil) then
		Controls.TimeSaved:SetText(date);
	else
		Controls.TimeSaved:SetText("");
	end
	
	if (gameType == GameTypes.GAME_HOTSEAT_MULTIPLAYER) then
		Controls.GameType:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_HOTSEAT_GAME") );
	else
		if (gameType == GameTypes.GAME_NETWORK_MULTIPLAYER) then
			Controls.GameType:SetText(  Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_STRING") );
		else
			if (gameType == GameTypes.GAME_SINGLE_PLAYER) then
				Controls.GameType:SetText(  Locale.ConvertTextKey("TXT_KEY_SINGLE_PLAYER") );
			else
				Controls.GameType:SetText( "" );
			end
		end
	end	

	Controls.SavedInfoStack:CalculateSize();

end

function SetSaveInfoToNone()
	-- Disable ability to enter game if none are selected
	if(Controls.CloudCheck:IsChecked()) then
		Controls.SaveButton:SetDisabled(true);
		Controls.SaveButtonLabel:SetColor(0xff474441,0); 
		Controls.ArrowButton:SetDisabled(true);
	end
	Controls.Delete:SetDisabled(true);
	Controls.DeleteLabel:SetColor(0xff474441,0); 
	
	-- Empty all text fields
	Controls.Title:SetText( "" );
	Controls.CurrentTurn:SetText( "" );
	Controls.TimeSaved:SetText( "" );
	Controls.GameType:SetText( "" );
end

function SetSaveInfoToEmptyCloudSave()
	
	-- Empty all text fields
	Controls.Title:LocalizeAndSetText("TXT_KEY_STEAM_EMPTY_SAVE");
	Controls.CurrentTurn:SetText("");
	Controls.TimeSaved:SetText("");
	Controls.GameType:SetText("");
end
----------------------------------------------------------------        
----------------------------------------------------------------
function ChopFileName(file)
	_, _, chop = string.find(file,"\\.+\\(.+)%."); 
	return chop;
end

----------------------------------------------------------------        
----------------------------------------------------------------
function ValidateText(text)

	if text == nil or #text == 0 then
		return false;
	end

	-- If all spaces, ignore
	local trimText = text:gsub("%s+", "");
	if trimText == nil or #trimText == 0 then
		return false;
	end

	-- If starts with sapces, ignore
	local isAllWhiteSpace = true;
	for i = 1, #text, 1 do
		if (string.byte(text, i) ~= 32) then
			isAllWhiteSpace = false;
			break;
		end
	end
	
	if (isAllWhiteSpace) then
		return false;
	end

	-- don't allow % character
	for i = 1, #text, 1 do
		if string.byte(text, i) == 37 then
			return false;
		end
	end

	local invalidCharArray = { '\"', '<', '>', '|', '\b', '\0', '\t', '\n', '/', '\\', '*', '?', ':' };

	for i, ch in ipairs(invalidCharArray) do
		if (string.find(text, ch) ~= nil) then
			return false;
		end
	end

	-- don't allow control characters
	for i = 1, #text, 1 do
		if (string.byte(text, i) < 32) then
			return false;
		end
	end

	return true;
end

----------------------------------------------------------------        
----------------------------------------------------------------
function SetupFileButtonList()
	SetSelected( nil );
    g_InstanceManager:ResetInstances();
    
    SetSaveInfoToNone();
    
    local bUsingSteamCloud = Controls.CloudCheck:IsChecked();
    
    if(bUsingSteamCloud) then
		local cloudSaveData = Steam.GetCloudSaves();
		
		local sortTable = {};
		
		for i = 1, s_maxCloudSaves, 1 do
			
			local instance = g_InstanceManager:GetInstance();
			local data = cloudSaveData[i];
			
			g_SavedGames[i] = {
				Instance = instance,
				SaveData = data,
				IsCloudSave = true,
			}
			
			
			local title = Locale.ConvertTextKey("TXT_KEY_STEAM_EMPTY_SAVE");
			if(data ~= nil) then
			
				local civName = Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN");
				local leaderDescription = Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN");
				
				local civ = GameInfo.Civilizations[ data.PlayerCivilization ];
				if(civ ~= nil) then
					local leader = nil;
					for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
						leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
					end
					leaderDescription = Locale.Lookup(leader.Description);
					civName = Locale.Lookup(civ.Description);
				end

				if(not Locale.IsNilOrWhitespace(data.CivilizationName)) then
					civName = data.CivilizationName;
				end
				
				if(not Locale.IsNilOrWhitespace(data.LeaderName)) then
					leaderDescription = data.LeaderName;
				end
				
				title = Locale.ConvertTextKey("TXT_KEY_RANDOM_LEADER_CIV", leaderDescription, civName );
				
			end
			local cloudSave = Locale.ConvertTextKey("TXT_KEY_STEAMCLOUD_SAVE", i, title);
			TruncateString(instance.ButtonText, (instance.Button:GetSizeX()-60), cloudSave); 
			instance.Button:RegisterCallback( Mouse.eLClick, function() SetSelected(g_SavedGames[i]); end);
		end
    else
        -- build a table of all save file names that we found
        local savedGames = {};
        local gameType = GameTypes.GAME_SINGLE_PLAYER;
        if (PreGame.IsMultiplayerGame()) then
			gameType = GameTypes.GAME_NETWORK_MULTIPLAYER;
        elseif (PreGame.IsHotSeatGame()) then
			gameType = GameTypes.GAME_HOTSEAT_MULTIPLAYER;
        end
		UI.SaveFileList( savedGames, gameType, false);
	   
		-- Reset this table! Otherwise, if there were MORE saved games before than there are now, they won't be replaced.
		g_SavedGames = {};

		for i, v in ipairs(savedGames) do
    		local instance = g_InstanceManager:GetInstance();
    		
    		-- chop the part that we are going to display out of the bigger string
			local displayName = Path.GetFileNameWithoutExtension(v);
						
			g_SavedGames[i] = {
				Instance = instance,
				FileName = v,
				DisplayName = displayName,
			}
	    	
			TruncateString(instance.ButtonText, (instance.Button:GetSizeX()-60), displayName); 
			
			instance.Button:SetVoid1( i );
			instance.Button:RegisterCallback( Mouse.eLClick, function() SetSelected(g_SavedGames[i]); end);
		end
    end
    
	Controls.Delete:SetHide(bUsingSteamCloud);
	Controls.NameBoxFrame:SetHide(bUsingSteamCloud);
	
	Controls.LoadFileButtonStack:CalculateSize();
    Controls.LoadFileButtonStack:ReprocessAnchoring();
    Controls.ScrollPanel:CalculateInternalSize();
end


----------------------------------------------------------------        
---------------------------------------------------------------- 
--[[  We may decide to add back save map functionality at a later date.
function OnSaveMap()
    UIManager:QueuePopup( Controls.SaveMapMenu, PopupPriority.SaveMapMenu );
end
Controls.SaveMapButton:RegisterCallback( Mouse.eLClick, OnSaveMap );
]]--

----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
			if(Controls.DeleteConfirm:IsHidden())then
				OnBack();
			else
				Controls.DeleteConfirm:SetHide(true);
            	Controls.BGBlock:SetHide(false);
			end
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );

----------------------------------------------------------------        
----------------------------------------------------------------
function ShowHideHandler( isHide )
	if( not isHide ) then
		if (PreGame.GameStarted()) then    	
			-- If the lock mods option is on then disable the save map button    	
			if( PreGame.IsMultiplayerGame() or
    		Modding.AnyActivatedModsContainPropertyValue( "DisableSaveMapOption", "1" ) or
					PreGame.GetGameOption( GameOptionTypes.GAMEOPTION_LOCK_MODS ) ~= 0 or
					UIManager:IsModal( ContextPtr ) ) then
			end
		end
    		
		Controls.NameBox:SetText(GetDefaultSaveName());
		Controls.NameBox:TakeFocus();
		SetupFileButtonList();
		OnEditBoxChange();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );