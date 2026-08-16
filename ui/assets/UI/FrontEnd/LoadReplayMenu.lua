include( "InstanceManager" );
include( "IconSupport" );
include( "SupportFunctions" );
include( "UniqueBonuses" );
include( "MapUtilities" );

-- Global Constants
g_InstanceManager = InstanceManager:new( "LoadButton", "InstanceRoot", Controls.LoadFileButtonStack );
g_ReferencedPackages = InstanceManager:new("ReferencedPackageInstance", "Label", Controls.ReferencedPackagesStack);

-- Global Variables
g_FileList = {};
g_SortTable = {};
g_InstanceList = {};

g_iSelected = -1;
g_ReplayModsRequired = nil;	-- The required mods for the currently selected replay.
g_ReplayDLCRequired = nil;	-- The required DLC for the currently selected replay.

g_CurrentSort = nil;	-- The current sorting technique
----------------------------------------------------------------        
----------------------------------------------------------------        
function OnSelectReplay()
	local replayFile = g_FileList[ g_iSelected ];
	UIManager:SetUICursor(1);
	Modding.ActivateModsAndDLCForReplay(replayFile);
	UIManager:SetUICursor(0);

	UIManager:DequeuePopup( ContextPtr );
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "Replay", replayFile );

end
Controls.SelectReplayButton:RegisterCallback( Mouse.eLClick, OnSelectReplay );


function OnReplayLoaded( nStep : number, sReplayFile : string )

	if( nStep == 1 ) then
		UIManager:QueuePopup( Controls.ReplayViewer, PopupPriority.eUtmost);
		UIManager:DequeuePopup( ContextPtr );
		LuaEvents.ReplayViewer_LoadReplay(sReplayFile);
	end
end
LuaEvents.ReplayLoaded.Add( OnReplayLoaded );

---------------------------------------------------------------        
----------------------------------------------------------------
function OnDelete( )
	Controls.DeleteConfirm:SetHide(false);
end
Controls.DeleteButton:RegisterCallback( Mouse.eLClick, OnDelete );

function OnYes( )
	Controls.DeleteConfirm:SetHide(true);
	UI.DeleteReplayFile( g_FileList[ g_iSelected ] );
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

	UIManager:SetUICursor(1);
	Modding.DeactivateMods();
	UIManager:SetUICursor(0);
    UIManager:DequeuePopup( ContextPtr );
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );


----------------------------------------------------------------   
-- Referenced Packages popup     
----------------------------------------------------------------   
Controls.ShowModsButton:RegisterCallback(Mouse.eLClick, function()
	g_ReferencedPackages:ResetInstances();
	
	Controls.ReferencedPackagesPrompt:LocalizeAndSetText("TXT_KEY_LOAD_MENU_REQUIRED_MODS");
	for i,v in ipairs(g_ReplayModsRequired) do
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
	
	Controls.ReferencedPackagesPrompt:LocalizeAndSetText("TXT_KEY_SHELL_REPLY_REQUIRED_DLC");
	for i,v in ipairs(g_ReplayDLCRequired) do
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
    
    g_iSelected = index;

    if( g_iSelected ~= -1 ) then

		Controls.Message:SetHide( true );

        g_InstanceList[ g_iSelected ].SelectHighlight:SetHide( false );
		
		local header = UI.GetReplayFileHeader(g_FileList[g_iSelected]);
		
		Controls.SelectReplayButton:SetDisabled(header == nil);		
		if(header ~= nil) then

			local civ = GameInfo.Civilizations[ header.PlayerCivilization ];

			local name = Path.GetFileNameWithoutExtension(g_FileList[g_iSelected]);
			
			--Set Replay File Text
			TruncateString(Controls.SaveFileName, Controls.DetailsBox:GetSizeX(), name); 
			local turnNum		= tonumber(header.TurnNumber);
			local currentTurns	= Locale.ConvertTextKey("TXT_KEY_CUR_TURNS_FORMAT", turnNum );
			Controls.CurrentTurn:SetText( currentTurns );
			
			-- Set Replay file time
			local date = UI.GetReplayModificationTime(g_FileList[ g_iSelected ]);
			if(date ~= nil) then
				Controls.TimeSaved:SetText(date);	
			else
				Controls.TimeSaved:SetText("");
			end		  
	
			--First, default it to unkown values.
			local civName = Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN");
			local leaderDescription = Locale.ConvertTextKey("TXT_KEY_MISC_UNKNOWN");
			
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
				
				Controls.LeaderName:SetColor(RGBAObjectToABGRHex(primaryColorRaw), 0);
				Controls.LeaderName:SetColor(RGBAObjectToABGRHex(secondaryColorRaw), 1);

				local leader = nil;
				for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
					leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
				end
				if(leader ~= nil) then
					leaderDescription = Locale.ConvertTextKey(leader.Description);
				end
			end
			
			-- Leader name and color
			if(header.LeaderName ~= nil and header.LeaderName ~= "")then
				leaderDescription = header.LeaderName;
			end
			
			-- Civilization name
			if(header.CivilizationName ~= nil and header.CivilizationName ~= "")then
				civName = header.CivilizationName;
			end

			Controls.LeaderName:SetText(Locale.ToUpper(leaderDescription));
			Controls.SponsorName:SetText(civName);
	        
	        local mapInfo = MapUtilities.GetBasicInfo(header.MapScript);
			Controls.TypeLabel:SetText(Locale.Lookup(mapInfo.Name));
							
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
			
			local canLoadReplayResult = Modding.CanLoadReplay(g_FileList[g_iSelected]);
			  	
			-- Obtain all of the required mods for the replay
			g_ReplayDLCRequired, g_ReplayModsRequired = Modding.GetReplayRequirements(g_FileList[g_iSelected]);
			
			Controls.ShowModsButton:SetHide(g_ReplayModsRequired == nil or #g_ReplayModsRequired == 0);
			Controls.ShowDLCButton:SetHide(g_ReplayDLCRequired == nil or #g_ReplayDLCRequired == 0);
								
			local tooltip = nil;
			if(canLoadReplayResult > 0) then
				local errorTooltips = {};
				errorTooltips[1] = nil;
				errorTooltips[2] = "TXT_KEY_MODDING_ERROR_SAVE_MISSING_DLC";
				errorTooltips[3] = "TXT_KEY_MODDING_ERROR_SAVE_DLC_NOT_PURCHASED";
				errorTooltips[4] = "TXT_KEY_MODDING_ERROR_SAVE_MISSING_MODS";
				errorTooltips[5] = "TXT_KEY_MODDING_ERROR_SAVE_INCOMPATIBLE_MODS";

				tooltip = Locale.ConvertTextKey(errorTooltips[canLoadReplayResult]);
			end
			
			Controls.SelectReplayButton:SetToolTipString(tooltip);
			Controls.SelectReplayButton:SetDisabled(canLoadReplayResult > 0);  
			
			Controls.DeleteButton:SetDisabled(false); 
			
		else
			SetSaveInfoToNone(true);
		end
	else -- No saves are selected
		SetSaveInfoToNone(false);
    end
end

function SetSaveInfoToNone(isInvalid)
	-- Disable ability to enter game if none are selected
	Controls.SelectReplayButton:SetDisabled(true);
	Controls.SelectReplayButton:SetToolTipString("");
	
	Controls.DeleteButton:SetDisabled(true);
	
	Controls.ShowDLCButton:SetHide(true);
	Controls.ShowModsButton:SetHide(true);
	
	Controls.Message:SetHide( false );

	-- Empty all text fields
	if(not isInvalid) then
		Controls.Message:LocalizeAndSetText("TXT_KEY_LOAD_REPLAY_MENU_PLEASE_SELECT_REPLAY");
	else
		Controls.Message:LocalizeAndSetText("TXT_KEY_LOAD_REPLAY_MENU_INVALID_REPLAY_FILE");
		Controls.DeleteButton:SetDisabled(false);
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
function SetupFileButtonList()
    SetSelected( -1 );
    g_InstanceManager:ResetInstances();
    
    -- build a table of all save file names that we found
    g_SortTable = {};
    g_InstanceList = {};
    
    
    g_FileList = UI.GetReplayFiles();
	for i, v in ipairs(g_FileList) do
		local controlTable = g_InstanceManager:GetInstance();
		g_InstanceList[i] = controlTable;
	    
		-- chop the part that we are going to display out of the bigger string
		local displayName = Path.GetFileNameWithoutExtension(v); 
        
		TruncateString(controlTable.ButtonText, controlTable.Button:GetSizeX(), displayName);
         
		controlTable.Button:SetVoid1( i );
		controlTable.Button:RegisterCallback( Mouse.eLClick, SetSelected );
		
		local high, low = UI.GetReplayModificationTimeRaw(v);
		g_SortTable[ tostring( controlTable.InstanceRoot ) ] = {Title = displayName, LastModified = {High = high, Low = low} };
		
		
		Controls.NoGames:SetHide( true );
	end
	
	Controls.LoadFileButtonStack:SortChildren( g_CurrentSort );
	
	Controls.LoadFileButtonStack:CalculateSize();
    Controls.ScrollPanel:CalculateInternalSize();
    Controls.LoadFileButtonStack:ReprocessAnchoring();
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
        SetupFileButtonList();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------        
---------------------------------------------------------------- 

----------------------------------------------------------------        
----------------------------------------------------------------        
function SortByName( a, b ) 
    local oa = g_SortTable[ tostring( a ) ];
    local ob = g_SortTable[ tostring( b ) ];
    
    if( oa == nil ) then
        return true;
    elseif( ob == nil ) then
        return false;
    end
    
    return Locale.Compare(oa.Title, ob.Title) == -1;
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
