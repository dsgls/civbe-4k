include( "InstanceManager" );
include( "IconSupport" );
include( "SupportFunctions" );
include( "UniqueBonuses" );
include( "MapUtilities" );

-- Global Constants
g_InstanceManager = InstanceManager:new( "LoadButton", "InstanceRoot", Controls.LoadFileButtonStack );
g_ReferencedPackages = InstanceManager:new("ReferencedPackageInstance", "Label", Controls.ReferencedPackagesStack);

-- Global Variables
g_ShowCloudSaves = false;
g_ShowAutoSaves = false;

g_CloudSaves = {};

g_FileList = {};
g_SortTable = {};
g_InstanceList = {};

g_GameType = GameTypes.GAME_SINGLE_PLAYER;
g_IsInGame = false;
g_iSelected = -1;
g_SavedGameModsRequired = nil;	-- The required mods for the currently selected save.
g_SavedGameDLCRequired = nil;	-- The required DLC for the currently selected save.

g_CurrentSort = nil;	-- The current sorting technique.
----------------------------------------------------------------        
----------------------------------------------------------------        
function OnStartButton()
	
	if g_GameType == GameTypes.GAME_SINGLE_PLAYER or g_GameType == GameTypes.GAME_HOTSEAT_MULTIPLAYER then
		UIManager:SetUICursor( 1 );
		if(g_ShowCloudSaves) then
			Events.PlayerChoseToLoadGame(Steam.GetCloudSaveFileName(g_iSelected), true);
			Controls.StartButton:SetDisabled( true );
			Controls.StartButtonLabel:SetColor(0xff474441,0); 
			UIManager:DequeuePopup( ContextPtr );
		else
			local thisLoadFile = g_FileList[ g_iSelected ];
			if(thisLoadFile) then
				Events.PlayerChoseToLoadGame(thisLoadFile);
    			Controls.StartButton:SetDisabled( true );
				Controls.StartButtonLabel:SetColor(0xff474441,0); 
    			UIManager:DequeuePopup( ContextPtr );
			end
		end
	else
		-- Multiplayer
		local header = nil;
		if(g_ShowCloudSaves) then
			local thisLoadFile = Steam.GetCloudSaveFileName(g_iSelected);
			if (thisLoadFile) then
				PreGame.SetLoadFileName( thisLoadFile, true );
				header = PreGame.GetFileHeader( thisLoadFile, true );
			end
		else
			local thisLoadFile = g_FileList[ g_iSelected ];
			if (thisLoadFile) then
				PreGame.SetLoadFileName( thisLoadFile );
				header = PreGame.GetFileHeader( thisLoadFile );
			end
		end
		
		if (header ~= nil) then
			local worldInfo = GameInfo.Worlds[ header.WorldSize ];
			PreGame.SetWorldSize( worldInfo.ID );

			local strGameName = ""; -- TODO

			if (Network.IsDedicatedServer()) then
				PreGame.SetGameOption("GAMEOPTION_PITBOSS", true);
				local bResult, bPending = Matchmaking.HostServerGame( strGameName, PreGame.ReadActiveSlotCountFromSaveGame(), false );
			else	
				if PreGame.IsInternetGame() then
					local bResult, bPending = Matchmaking.HostInternetGame( strGameName, PreGame.ReadActiveSlotCountFromSaveGame() );
				else
					if (PreGame.IsHotSeatGame()) then					
						local bResult, bPending = Matchmaking.HostHotSeatGame( strGameName, PreGame.ReadActiveSlotCountFromSaveGame() );
					else
						local bResult, bPending = Matchmaking.HostLANGame( strGameName, PreGame.ReadActiveSlotCountFromSaveGame() );
					end
				end
			end
			UIManager:DequeuePopup( ContextPtr );	
		end
	end
end
Controls.StartButton:RegisterCallback( Mouse.eLClick, OnStartButton );

----------------------------------------------------------------        
----------------------------------------------------------------        
Controls.AutoCheck:RegisterCheckHandler( function(checked)
    g_ShowAutoSaves = checked;
    if(g_ShowAutoSaves) then
		Controls.SortByPullDown:SetHide(true);
		g_ShowCloudSaves = false;
	else
		Controls.SortByPullDown:SetHide(false);	
    end
    
    UpdateControlStates();
    SetupFileButtonList();
end);
----------------------------------------------------------------
----------------------------------------------------------------
Controls.CloudCheck:RegisterCheckHandler( function(checked)
	g_ShowCloudSaves = checked;
	
	if(g_ShowCloudSaves) then
		Controls.SortByPullDown:SetHide(true);	
		g_ShowAutoSaves = false;
	else
		Controls.SortByPullDown:SetHide(false);	
	end
	
	UpdateControlStates();
	SetupFileButtonList();
end);

----------------------------------------------------------------        
----------------------------------------------------------------
function OnDelete( )
	Controls.DeleteConfirm:SetHide(false);
end
Controls.Delete:RegisterCallback( Mouse.eLClick, OnDelete );

function OnYes( )
	Controls.DeleteConfirm:SetHide(true);
	UI.DeleteSavedGame( g_FileList[ g_iSelected ] );
	SetupFileButtonList();
end
Controls.Yes:RegisterCallback( Mouse.eLClick, OnYes );

function OnNo( )
	Controls.DeleteConfirm:SetHide(true);
end
Controls.No:RegisterCallback( Mouse.eLClick, OnNo );
----------------------------------------------------------------        
----------------------------------------------------------------        
function OnBack()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBack );


----------------------------------------------------------------   
-- Referenced Packages popup     
----------------------------------------------------------------   
Controls.ShowModsButton:RegisterCallback(Mouse.eLClick, function()
	g_ReferencedPackages:ResetInstances();
	
	Controls.ReferencedPackagesPrompt:LocalizeAndSetText("TXT_KEY_LOAD_MENU_REQUIRED_MODS");
	for i,v in ipairs(g_SavedGameModsRequired) do
		local referencedPackage = g_ReferencedPackages:GetInstance();

		local name = v.Title;
		if(Locale.HasTextKey(name)) then
			name = Locale.ConvertTextKey(name);
		end
		
		local truncateWidth = 72;
		if(#name > truncateWidth) then
			name = string.format("%s... ", string.sub(name, 1, truncateWidth));
		end 
		--We always want to at least supply 1 argument.
		local text = string.format("[ICON_BULLET] %s (v. %i)", name, v.Version);
			
		referencedPackage.Label:SetText(text);
	end
	
	Controls.ReferencedPackagesStack:CalculateSize();
	Controls.ReferencedPackagesScrollPanel:CalculateInternalSize();
	Controls.ReferencedPackagesWindow:SetHide(false);
end);
----------------------------------------------------------------  
Controls.ShowDLCButton:RegisterCallback(Mouse.eLClick, function()
	g_ReferencedPackages:ResetInstances();
	
	Controls.ReferencedPackagesPrompt:LocalizeAndSetText("TXT_KEY_LOAD_MENU_REQUIRED_DLC");
	for i,v in ipairs(g_SavedGameDLCRequired) do
		local referencedPackage = g_ReferencedPackages:GetInstance();

		local name;
		print(v.DescriptionKey);
		if(v.DescriptionKey and Locale.HasTextKey(v.DescriptionKey)) then
			name = Locale.ConvertTextKey(v.DescriptionKey);
		else
			name = v.Title;
			if(Locale.HasTextKey(name)) then
				name = Locale.ConvertTextKey(name);
			end
		end
		
		local truncateWidth = 72;
		if(#name > truncateWidth) then
			name = string.format("%s... ", string.sub(name, 1, truncateWidth));
		end 
		
		--We always want to at least supply 1 argument.
		local text = "[ICON_BULLET] " .. name;
		referencedPackage.Label:SetText(text);
	end
	
	Controls.ReferencedPackagesStack:CalculateSize();
	Controls.ReferencedPackagesScrollPanel:CalculateInternalSize();
	Controls.ReferencedPackagesWindow:SetHide(false);
end);
----------------------------------------------------------------  
Controls.CloseReferencedPackagesButton:RegisterCallback(Mouse.eLClick, function()
	Controls.ReferencedPackagesWindow:SetHide(true);
end);
----------------------------------------------------------------        
----------------------------------------------------------------        
function SetSelected( index )
    if( g_iSelected ~= -1 ) then
        g_InstanceList[ g_iSelected ].SelectHighlight:SetHide( true );
    end
    
	Controls.Message:SetText("");
	Controls.GameInfo:SetHide( false );
    g_iSelected = index;

    if( g_iSelected ~= -1 ) then
        g_InstanceList[ g_iSelected ].SelectHighlight:SetHide( false );
		
		local header;
		if(g_ShowCloudSaves) then
			header = g_CloudSaves[g_iSelected];
		else
			header = PreGame.GetFileHeader(g_FileList[g_iSelected]);
		end
		if(header == nil or header.GameType ~= g_GameType)
		then
			Controls.StartButton:SetDisabled( true );		
			Controls.StartButtonLabel:SetColor(0xff474441,0); 
		else
			Controls.StartButton:SetDisabled( false );	
			Controls.StartButtonLabel:SetColor(0xffffffff,0); 	
		end
		if(header ~= nil) then

			local civ = GameInfo.Civilizations[ header.PlayerCivilization ];

			local name;
			if(g_ShowCloudSaves) then
				name = "";--Locale.ConvertTextKey("TXT_KEY_STEAMCLOUD");
			else
				name = GetDisplayName(g_FileList[g_iSelected]);
			end

			--Set Save File Text
			local truncateWidth = Controls.DetailsBox:GetSizeX() - 40;
			TruncateStringWithTooltip(Controls.SaveFileName, truncateWidth, name); 

			Controls.CurrentTurn:LocalizeAndSetText("TXT_KEY_CUR_TURNS_FORMAT", header.TurnNumber );


			if (header.GameType == GameTypes.GAME_HOTSEAT_MULTIPLAYER) then
				Controls.GameType:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_HOTSEAT_GAME") );
			else
				if (header.GameType == GameTypes.GAME_NETWORK_MULTIPLAYER) then
					Controls.GameType:SetText(  Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_STRING") );
				else
					if (header.GameType == GameTypes.GAME_SINGLE_PLAYER) then
						Controls.GameType:SetText(  Locale.ConvertTextKey("TXT_KEY_SINGLE_PLAYER") );
					else
						Controls.GameType:SetText( "" );
					end
				end
			end
			
			-- Set Save file time
			local date;
			if(not g_ShowCloudSaves) then
				date = UI.GetSavedGameModificationTime(g_FileList[ g_iSelected ]);
			end
			
			
			if(date ~= nil) then
				Controls.TimeSaved:SetText(date);	
			else
				Controls.TimeSaved:SetText("");
			end		  
	
			--First, default it to unkown values.
			local civName = Locale.ConvertTextKey("TXT_KEY_RANDOM");
			local leaderDescription = Locale.ConvertTextKey("TXT_KEY_RANDOM");
			local primaryColorRaw = {x=128/255, y=144/255, z=162/255, w=255/255};
			local secondaryColorRaw = {x=0/255, y=0/255, z=0/255, w=100/255};
			
			Controls.CivIcon:SetTexture(questionTextureSheet);
			Controls.CivIcon:SetTextureOffset(questionOffset);
			Controls.CivIcon:SetToolTipString(unknownString);
			
			-- ? leader icon
			--IconHookup( 22, 128, "LEADER_ATLAS", Controls.Portrait );
			
			if(civ ~= nil) then
				-- Sets civ icon and tool tip
				civName = Locale.ConvertTextKey(civ.Description);
				local textureOffset, textureAtlas = IconLookup( civ.PortraitIndex, 64, civ.IconAtlas );
				if textureOffset ~= nil then       
					Controls.CivIcon:SetTexture( textureAtlas );
					Controls.CivIcon:SetTextureOffset( textureOffset );
					Controls.CivIcon:SetToolTipString( Locale.ConvertTextKey( civ.ShortDescription) );
				end	

				local primaryColorType	= GameInfo.PlayerColors[civ.DefaultPlayerColor].PrimaryColor;
				local secondaryColorType= GameInfo.PlayerColors[civ.DefaultPlayerColor].SecondaryColor;
				local primaryColorInfo	= GameInfo.Colors[primaryColorType];
				local secondaryColorInfo= GameInfo.Colors[secondaryColorType];
				primaryColorRaw			= {x=primaryColorInfo.Red, y=primaryColorInfo.Green, z=primaryColorInfo.Blue, w=primaryColorInfo.Alpha};
				secondaryColorRaw		= {x=secondaryColorInfo.Red, y=secondaryColorInfo.Green, z=secondaryColorInfo.Blue, w=secondaryColorInfo.Alpha};

				local leader = nil;
				for row in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
					leader = GameInfo.Leaders[ row.LeaderheadType ];
				end
				
				if(leader ~= nil) then
					leaderDescription = Locale.ConvertTextKey(leader.Description);
				end
			end
			
			-- Leader name and color
			if(header.LeaderName ~= nil and header.LeaderName ~= "")then
				leaderDescription = header.LeaderName;
			end
			Controls.LeaderName:SetColor(RGBAObjectToABGRHex(primaryColorRaw), 0);
			Controls.LeaderName:SetColor(RGBAObjectToABGRHex(secondaryColorRaw), 1);
			
			-- Civilization name
			if(header.CivilizationName ~= nil and header.CivilizationName ~= "")then
				civName = header.CivilizationName;
			end

			Controls.LeaderName:SetText(Locale.ToUpper(leaderDescription));
			Controls.SponsorName:SetText(civName);
	        
	        local mapInfo = MapUtilities.GetBasicInfo(header.MapScript);
			--Controls.TypeLabel:SetText(Locale.Lookup(mapInfo.Name));
			local planet = PreGame.GetPlanet();
			if( header.PlanetType ~= nil ) then
				planet = header.PlanetType;
			end

			Controls.TypeLabel:SetText(MapUtilities.GetPlanetTypeDescription(mapInfo.Name, planet));
	        				
			-- Sets map size icon and tool tip
			info = GameInfo.Worlds[ header.WorldSize ];
			if(info ~= nil) then
				IconHookup( info.PortraitIndex, 64, info.IconAtlas, Controls.MapSize );
				Controls.SizeLabel:SetText(Locale.ConvertTextKey( info.Description));
			else
				if(questionOffset ~= nil) then
					Controls.SizeLabel:SetText(unknownString);
				end
			end
			
			-- Sets handicap icon and tool tip
			info = GameInfo.HandicapInfos[ header.Difficulty ];
			if(info ~= nil) then
				Controls.DifficultyLabel:SetText(Locale.ConvertTextKey( info.Description ));
			else
				if(questionOffset ~= nil) then
					Controls.DifficultyLabel:SetText(unknownString);
				end
			end
			
			-- Sets game pace icon and tool tip
			info = GameInfo.GameSpeeds[ header.GameSpeed ];
			if(info ~= nil) then
				Controls.SpeedLabel:SetText(Locale.ConvertTextKey( info.Description ));
			else
				if(questionOffset ~= nil) then
					Controls.SpeedLabel:SetText(questionString);
				end
			end		
			
			local canLoadSaveResult;
			if(g_ShowCloudSaves) then
				canLoadSaveResult = Modding.CanLoadCloudSave(g_iSelected);
			else
				canLoadSaveResult = Modding.CanLoadSavedGame(g_FileList[g_iSelected]);
			end	
			  	
			  	
			  	
			-- Obtain all of the required mods for the save
			if(g_ShowCloudSaves) then
				g_SavedGameDLCRequired, g_SavedGameModsRequired = Modding.GetCloudSaveRequirements(g_iSelected);
			else
				g_SavedGameDLCRequired, g_SavedGameModsRequired = Modding.GetSavedGameRequirements(g_FileList[g_iSelected]);
			end
			
			Controls.ShowModsButton:SetHide(g_SavedGameModsRequired == nil or #g_SavedGameModsRequired == 0);

			Controls.ShowDLCButton:SetSizeX(Controls.DLCtext:GetSizeX() + 20);
			Controls.ShowDLCButton:SetHide(g_SavedGameDLCRequired == nil or #g_SavedGameDLCRequired == 0);
								
			local tooltip = nil;
			if(canLoadSaveResult > 0) then
				local errorTooltips = {};
				errorTooltips[1] = nil;
				errorTooltips[2] = "TXT_KEY_MODDING_ERROR_SAVE_MISSING_DLC";
				errorTooltips[3] = "TXT_KEY_MODDING_ERROR_SAVE_DLC_NOT_PURCHASED";
				errorTooltips[4] = "TXT_KEY_MODDING_ERROR_SAVE_MISSING_MODS";
				errorTooltips[5] = "TXT_KEY_MODDING_ERROR_SAVE_INCOMPATIBLE_MODS";

				tooltip = Locale.ConvertTextKey(errorTooltips[canLoadSaveResult]);
			end
			
			Controls.StartButton:SetToolTipString(tooltip);
			if(canLoadSaveResult > 0 or header.GameType ~= g_GameType)
			then
				Controls.StartButton:SetDisabled( true );		
				Controls.StartButtonLabel:SetColor(0xff474441,0); 
			else
				Controls.StartButton:SetDisabled( false );	
				Controls.StartButtonLabel:SetColor(0xffffffff,0); 	
			end
			
			Controls.Delete:SetDisabled(false); 
			Controls.DeleteLabel:SetColor(0xffffffff,0); 

			Controls.GameInfo:ReprocessAnchoring();
			Controls.GameInfo:CalculateSize();
			Controls.GameDetailsStack:ReprocessAnchoring();
			Controls.GameDetailsStack:CalculateSize();

			
		else
			SetSaveInfoToNone(true);
		end
	else -- No saves are selected
		SetSaveInfoToNone(false);
    end
end

function SetSaveInfoToNone(isInvalid)
	-- Disable ability to enter game if none are selected
	Controls.StartButton:SetDisabled(true);
	Controls.StartButtonLabel:SetColor(0xff474441,0); 
	Controls.StartButton:SetToolTipString("");
	
	Controls.Delete:SetDisabled(true);
	Controls.DeleteLabel:SetColor(0xff474441,0); 
	
	Controls.ShowDLCButton:SetHide(true);
	Controls.ShowModsButton:SetHide(true);
	
	-- Empty all text fields
	if(g_ShowCloudSaves) then
		Controls.Message:SetHide(false);
		Controls.Message:LocalizeAndSetText("TXT_KEY_STEAM_EMPTY_SAVE");
	elseif(not isInvalid) then
		Controls.Message:SetHide(false);
		Controls.Message:LocalizeAndSetText("TXT_KEY_SELECT_SAVE_GAME");
	else
		Controls.Message:SetHide(false);
		Controls.Message:LocalizeAndSetText("TXT_KEY_INVALID_SAVE_GAME");
		Controls.Delete:SetDisabled(false);
		Controls.DeleteLabel:SetColor(0xffffffff,0); 
	end
	
	Controls.GameInfo:SetHide( true );
	Controls.NoGames:SetHide( isInvalid );
	Controls.SaveFileName:SetText( "" );
	Controls.CurrentTurn:SetText( "" );
	Controls.GameType:SetText( "" );
	Controls.TimeSaved:SetText( "" );
	Controls.SponsorName:SetText( "" );
	Controls.LeaderName:SetText( "" );	
end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function GetDisplayName(file)
	return Path.GetFileNameWithoutExtension(file);
end
----------------------------------------------------------------        
----------------------------------------------------------------        
function SetupFileButtonList()
    SetSelected( -1 );
    g_InstanceManager:ResetInstances();
    
    -- build a table of all save file names that we found
    g_FileList = {};
    g_SortTable = {};
    g_InstanceList = {};
    
    if(g_ShowCloudSaves) then
		Controls.NoGames:SetHide( true );
		local strEmptyCloudSave = Locale.ConvertTextKey("TXT_KEY_STEAM_EMPTY_SAVE");
		
		for i = 1, Steam.GetMaxCloudSaves(), 1 do
			local controlTable = g_InstanceManager:GetInstance();
			g_InstanceList[i] = controlTable;
			
			local name = strEmptyCloudSave;
			local saveData = g_CloudSaves[i];

			if(saveData ~= nil) then
			
				local civName = Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN");
				local leaderDescription = Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN");
				
				local civ = GameInfo.Civilizations[ saveData.PlayerCivilization ];
				if(civ ~= nil) then
					civName = Locale.ConvertTextKey(civ.Description);

					local leader = nil;

					for row in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
						leader = GameInfo.Leaders[ row.LeaderheadType ];
					end
				
					if(leader ~= nil) then
						leaderDescription = Locale.ConvertTextKey(leader.Description);
					end
				end
				
				if(saveData.CivilizationName ~= nil and saveData.CivilizationName ~= "")then
					civName = saveData.CivilizationName;
				end
				
				if(saveData.LeaderName ~= nil and saveData.LeaderName ~= "")then
					leaderDescription = saveData.LeaderName;
				end
			
				name = Locale.ConvertTextKey("TXT_KEY_RANDOM_LEADER_CIV", leaderDescription, civName );				
			end
			
			local entryName = Locale.ConvertTextKey("TXT_KEY_STEAMCLOUD_SAVE", i, name);
			TruncateString(controlTable.ButtonText, controlTable.Button:GetSizeX(), entryName);
	         
	        controlTable.Button:SetVoid1( i );
			controlTable.Button:RegisterCallback( Mouse.eLClick, SetSelected );

			g_SortTable[tostring(controlTable.InstanceRoot)] = i;
	    end
		
		Controls.LoadFileButtonStack:SortChildren( CloudSaveSort );
		
    else  
		UI.SaveFileList( g_FileList, g_GameType, g_ShowAutoSaves);
		for i, v in ipairs(g_FileList) do
			local controlTable = g_InstanceManager:GetInstance();
			g_InstanceList[i] = controlTable;
		    
			local displayName = GetDisplayName(v); 
	        
			TruncateString(controlTable.ButtonText, controlTable.Button:GetSizeX(), displayName);
	         
			controlTable.Button:SetVoid1( i );
			controlTable.Button:RegisterCallback( Mouse.eLClick, SetSelected );
			
			local high, low = UI.GetSavedGameModificationTimeRaw(v);

			g_SortTable[ tostring( controlTable.InstanceRoot ) ] = {Title = displayName, LastModified = {High = high, Low = low} };
			Controls.NoGames:SetHide( true );
		end
		
		Controls.LoadFileButtonStack:SortChildren( g_CurrentSort );
	end
	
	Controls.LoadFileButtonStack:CalculateSize();
    Controls.ScrollPanel:CalculateInternalSize();
    Controls.LoadFileButtonStack:ReprocessAnchoring();
end
----------------------------------------------------------------
----------------------------------------------------------------
function UpdateControlStates()

	Controls.AutoCheck:SetCheck(g_ShowAutoSaves);
	Controls.CloudCheck:SetCheck(g_ShowCloudSaves);
	Controls.Delete:SetHide(g_ShowCloudSaves);

    if( UI.GetCurrentGameState() == GameStateTypes.CIVBE_GS_MAINGAMEVIEW ) then
        Controls.BGBlock:SetHide( false );
	else
        Controls.BGBlock:SetHide( true );
    end
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function CloudSaveSort( a, b ) 

    local aOrder = g_SortTable[ tostring( a ) ];
    local bOrder = g_SortTable[ tostring( b ) ];
    
	if( aOrder == nil and bOrder == nil ) then
		return Locale.Compare(tostring(a), tostring(b)) == -1;
    elseif( aOrder == nil ) then
        return true;
    elseif( bOrder == nil ) then
        return false;
    end
    
	return aOrder < bOrder;
end

function AlphabeticalSort( a, b ) 
    local oa = g_SortTable[ tostring( a ) ];
    local ob = g_SortTable[ tostring( b ) ];

	if( oa == nil and ob == nil ) then
		return Locale.Compare(tostring(oa), tostring(ob)) == -1;
    elseif( oa == nil ) then    
        return true;
    elseif( ob == nil ) then
        return false;
    end
    
    return Locale.Compare(oa.Title, ob.Title) == -1;
end

function ReverseAlphabeticalSort( a, b ) 
    local oa = g_SortTable[ tostring( a ) ];
    local ob = g_SortTable[ tostring( b ) ];
    
	if( oa == nil and ob == nil ) then
		return Locale.Compare(tostring(ob), tostring(oa)) == -1;
    elseif( oa == nil ) then    
        return false;
    elseif( ob == nil ) then
        return true;
    end
    
    return Locale.Compare(ob.Title, oa.Title) == -1;
end

function SortByName(a, b)
	if(g_ShowAutoSaves) then
		return ReverseAlphabeticalSort(a,b);
	else
		return AlphabeticalSort(a,b);
	end 
end

function SortByLastModified(a, b)
	local oa = g_SortTable[tostring(a)];
	local ob = g_SortTable[tostring(b)];
	
	if( oa == nil ) then
        return false;
    elseif( ob == nil ) then
        return true;
    end
    
	local result = UI.CompareFileTime(oa.LastModified.High, oa.LastModified.Low, ob.LastModified.High, ob.LastModified.Low);
    return result == 1;
end


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
			end
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );

----------------------------------------------------------------        
----------------------------------------------------------------        
function ShowHideHandler(isHide)
    if( not isHide ) then
		if (Controls.AlphaAnim:IsReversing()) then
			Controls.AlphaAnim:Reverse();
		end
		Controls.AlphaAnim:SetToBeginning();
		Controls.AlphaAnim:Play();

		if( g_IsInGame ) then
            if( Game:IsGameMultiPlayer() ) then
				if( Game:IsNetworkMultiPlayer() ) then
					g_GameType = GameTypes.GAME_NETWORK_MULTIPLAYER;
				else
					g_GameType = GameTypes.GAME_HOTSEAT_MULTIPLAYER;
				end
            else
				g_GameType = GameTypes.GAME_SINGLE_PLAYER;
            end
        end
		
		g_CloudSaves = Steam.GetCloudSaves();
        
        UpdateControlStates();
		SetupFileButtonList();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

local contextID = ContextPtr:LookUpControl(".."):GetID();

g_IsInGame = (contextID == "GameMenu");
if (contextID == "ModdingSinglePlayer" or contextID == "SinglePlayerScreen") then
	g_GameType = GameTypes.GAME_SINGLE_PLAYER;
else
	if PreGame.IsHotSeatGame() then
		g_GameType = GameTypes.GAME_HOTSEAT_MULTIPLAYER;
	else
		g_GameType = GameTypes.GAME_NETWORK_MULTIPLAYER;
	end
end

local sortOptions = {
	{"TXT_KEY_SORTBY_LASTMODIFIED", SortByLastModified},
	{"TXT_KEY_SORTBY_NAME", SortByName},
};

local sortByPulldown = Controls.SortByPullDown;
sortByPulldown:ClearEntries();
for i, v in ipairs(sortOptions) do
	local controlTable = {};
	sortByPulldown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:LocalizeAndSetText(v[1]);
	
	controlTable.Button:RegisterCallback(Mouse.eLClick, function()
		sortByPulldown:GetButton():LocalizeAndSetText(v[1]);
		Controls.LoadFileButtonStack:SortChildren( v[2] );
		
		g_CurrentSort = v[2];
	end);
	
end
sortByPulldown:CalculateInternals();

sortByPulldown:GetButton():LocalizeAndSetText(sortOptions[1][1]);
g_CurrentSort = sortOptions[1][2];

g_IsModVersion = (contextID == "ModdingSinglePlayer");
