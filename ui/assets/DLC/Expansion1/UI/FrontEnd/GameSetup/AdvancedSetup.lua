-------------------------------------------------
-- Advanced Settings Screen
-------------------------------------------------
--[[
	Design Overview
	The UI is made up of a table of *ScreenOptions* which are tables themselves consisting of a common interface.
	These common methods are called one after the other when certain events occur to ensure that the data is 
	up-to-date and valid.
	
	ScreenOption overview
	Each option structure contains the following functions:
		FullSync()		--	Refreshes all possible values and current value from the game.
							This is also where event handlers for controls are typically assigned.
		PartialSync()	--	Refreshes only the current value from the game.
		Validate(args)	--	Verifies that current value is a valid value (if not, will assign args.Valid = false)

	When the screen is shown, a partial sync is performed to ensure values are update.
	
	Full syncs are performed either when the screen is initialized or when mods change the game state.
----------------------------------------------------------------------------------------------------------------------]]
include( "IconSupport" );
include( "UniqueBonuses" );
include( "InstanceManager" );
include( "LoadoutUtils" );


-------------------------------------------------
-- Globals
-------------------------------------------------
g_SlotInstances = {};	-- Container for all player slots 
g_GameOptionsManager		= InstanceManager:new("GameOptionInstance",		"GameOptionRoot", Controls.GameOptionsStack);
g_DropDownOptionsManager	= InstanceManager:new("DropDownOptionInstance", "DropDownOptionRoot", Controls.DropDownOptionsStack);
g_VictoryCondtionsManager	= InstanceManager:new("GameOptionInstance",		"GameOptionRoot", Controls.VictoryConditionsStack);

local MAX_NAME_SIZE		= 220;

------------------------------------------------------------------------------------------------------
-- Complex Methods
-- Pulled out from Screen Options since they were so long
------------------------------------------------------------------------------------------------------
-- Refreshes all dynamic drop down game options
function RefreshDropDownGameOptions()
	g_DropDownOptionsManager:ResetInstances();

	local currentMapScript = PreGame.GetMapScript();
	if(PreGame.IsRandomMapScript())then
		currentMapScript = nil;
	end
	
	local options = {};
	for option in DB.Query("select * from MapScriptOptions where exists (select 1 from MapScriptOptionPossibleValues where FileName = MapScriptOptions.FileName and OptionID = MapScriptOptions.OptionID) and Hidden = 0 and FileName = ?", currentMapScript) do
		options[option.OptionID] = {
			ID = option.OptionID,
			Name = Locale.ConvertTextKey(option.Name),
			ToolTip = (option.Description) and Locale.ConvertTextKey(option.Description) or nil,
			Disabled = (option.ReadOnly == 1) and true or false,
			DefaultValue = option.DefaultValue,
			SortPriority = option.SortPriority,
			Values = {},
		}; 
	end
	
	for possibleValue in DB.Query("select * from MapScriptOptionPossibleValues where FileName = ? order by SortIndex ASC", currentMapScript) do
		if(options[possibleValue.OptionID] ~= nil) then
			table.insert(options[possibleValue.OptionID].Values, {
				Name	= Locale.ConvertTextKey(possibleValue.Name),
				ToolTip = (possibleValue.Description) and Locale.ConvertTextKey(possibleValue.Description) or nil,
				Value	= possibleValue.Value,
			});
		end
	end
	
	local sortedOptions = {};
	for k,v in pairs(options) do
		table.insert(sortedOptions, v);
	end
	 
	-- Sort the options
	table.sort(sortedOptions, function(a, b) 
		if(a.SortPriority == b.SortPriority) then
			return Locale.Compare(a.Name, b.Name) == -1; 
		else
			return a.SortPriority < b.SortPriority;
		end
	end);
	
	-- Update the UI!
	for _, option in ipairs(sortedOptions) do
	
		local gameOption = g_DropDownOptionsManager:GetInstance();
				
		gameOption.OptionName:SetText(option.Name);			
		--gameOption.OptionName:SetToolTipString(option.ToolTip or nil);					
		
		gameOption.OptionDropDown:SetDisabled(option.Disabled);
		local dropDownButton = gameOption.OptionDropDown:GetButton();
		
		gameOption.OptionDropDown:ClearEntries();
		for _, possibleValue in ipairs(option.Values) do
			controlTable = {};
			gameOption.OptionDropDown:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetText(possibleValue.Name);
			controlTable.Button:SetToolTipString(possibleValue.ToolTip or option.ToolTip or nil);
			
			controlTable.Button:RegisterCallback(Mouse.eLClick, function()
				dropDownButton:SetText(possibleValue.Name);
				dropDownButton:SetToolTipString(possibleValue.ToolTip or option.ToolTip or nil);
				PreGame.SetMapOption(option.ID, possibleValue.Value);
			end);
		end
		
		--Assign the currently selected value.
		local savedValue = PreGame.GetMapOption(option.ID);
		local defaultValue;
		if(savedValue ~= -1) then
			defaultValue = option.Values[savedValue];
		else
			defaultValue = option.Values[option.DefaultValue];
		end
		
		if(defaultValue ~= nil) then
			dropDownButton:SetText(defaultValue.Name);
			dropDownButton:SetToolTipString(defaultValue.ToolTip or option.ToolTip or nil);
		end
	
		if(option.Disabled) then
			dropDownButton:SetDisabled(true);
		end
		
		gameOption.OptionDropDown:CalculateInternals();
	end
	
	Controls.DropDownOptionsStack:CalculateSize();
	Controls.DropDownOptionsStack:ReprocessAnchoring();

	Controls.OptionsScrollPanel:CalculateInternalSize();
end
------------------------------------------------------------------------------------------------------
-- Refreshes all dynamic checkbox game options
function RefreshCheckBoxGameOptions()
	g_GameOptionsManager:ResetInstances();

	---------------------------------
	-- General Game Options
	local options = {};
	-- First, Gather a list of all options
	for option in GameInfo.GameOptions{Visible = 1} do
		local option = {
			Type = option.Type,
			Name = Locale.ConvertTextKey(option.Description),
			ToolTip = (option.Help) and Locale.ConvertTextKey(option.Help) or nil,
			Checked = (option.Default == 1) and true or false,
			Disabled = false,
			GameOption = true,
			SortPriority = 0, 
			SupportsSinglePlayer = option.SupportsSinglePlayer,
		};
		
		local savedValue = PreGame.GetGameOption(option.Type);
		if(savedValue ~= nil) then
			option.Checked = savedValue == 1;
		end
		
		-- Only display options that support singleplayer.
		if( option.SupportsSinglePlayer ) then
			table.insert(options, option);
		end
	end
	
	for option in DB.Query("select * from MapScriptOptions where not exists (select 1 from MapScriptOptionPossibleValues where FileName = MapScriptOptions.FileName and OptionID = MapScriptOptions.OptionID) and Hidden = 0 and FileName = ?", PreGame.GetMapScript()) do
		local option = {
			ID = option.OptionID,
			Name = Locale.ConvertTextKey(option.Name),
			ToolTip = (option.Description) and Locale.ConvertTextKey(option.Description) or nil,
			Checked = (option.DefaultValue == 1) and true or false,
			Disabled = (option.ReadOnly == 1) and true or false,
			GameOption = false,
			SortPriority = option.SortPriority,
		};
		
		local savedValue = PreGame.GetMapOption(option.ID);
		if(savedValue ~= nil) then
			option.Checked = savedValue == 1;
		end
		
		table.insert(options, option);
	end
	
	-- Sort the options alphabetically
	table.sort(options, function(a, b) 
		if(a.SortPriority == b.SortPriority) then
			return Locale.Compare(a.Name, b.Name) == -1;
		else
			return a.SortPriority < b.SortPriority;
		end
	end);
	
	-- Add Options to UI.
	local sizeY = 0;
	for _, option in ipairs(options) do
		local gameOption = g_GameOptionsManager:GetInstance();
		
		local gameOptionTextButton = gameOption.GameOptionRoot:GetTextButton();
		gameOptionTextButton:SetText(option.Name);
								
		if(option.ToolTip ~= nil) then
			gameOption.GameOptionRoot:SetToolTipString(option.ToolTip);
		end
		
		gameOption.GameOptionRoot:SetDisabled(option.Disabled);
		gameOption.GameOptionRoot:SetCheck(option.Checked);
		sizeY = sizeY + gameOption.GameOptionRoot:GetSizeY();
		if(option.GameOption == true) then
			gameOption.GameOptionRoot:RegisterCheckHandler( function(bCheck)
				PreGame.SetGameOption(option.Type, bCheck);
			end);
		else
			gameOption.GameOptionRoot:RegisterCheckHandler( function(bCheck)
				PreGame.SetMapOption(option.ID, bCheck);
			end);
		end	
	end	
	
	Controls.DropDownOptionsStack:CalculateSize();
	Controls.DropDownOptionsStack:ReprocessAnchoring();
		
	Controls.MaxTurnStack:CalculateSize();
	Controls.MaxTurnStack:ReprocessAnchoring();
	
	Controls.GameOptionsStack:CalculateSize();
	Controls.GameOptionsStack:ReprocessAnchoring();
	
	Controls.GameOptionsFullStack:CalculateSize();
	Controls.GameOptionsFullStack:ReprocessAnchoring();

	Controls.OptionsScrollPanel:CalculateInternalSize();
end
------------------------------------------------------------------------------------------------------
-- Refreshes all of the player data.
function RefreshPlayerList()

	RefreshHumanPlayer();

	local count = 1;
	if(PreGame.IsRandomWorldSize()) then
		Controls.ListingScrollPanel:SetHide(true);
		Controls.UnknownPlayers:SetHide(false);
		Controls.AddAIButton:SetDisabled(true);
	else
		Controls.UnknownPlayers:SetHide(true);
		Controls.ListingScrollPanel:SetHide(false);
		Controls.AddAIButton:SetDisabled(false);
		
		for i = 1, GameDefines.MAX_MAJOR_CIVS-1 do
			if( PreGame.GetSlotStatus( i ) ~= SlotStatus.SS_COMPUTER ) then
				g_SlotInstances[i].Root:SetHide( true );
			else
    			-- Player Listing Entry
    			local controlTable = g_SlotInstances[i];
				controlTable.Root:SetHide( false );
				controlTable.PlayerNameLabel:SetHide( true );
				
				if(i ~= 1) then --Don't allow player to delete first AI so games will always have at least 2 players
					controlTable.RemoveButton:SetHide(false);
					controlTable.RemoveButton:RegisterCallback( Mouse.eLClick, function()
					
						if( PreGame.GetSlotStatus(i) == SlotStatus.SS_COMPUTER) then
							PreGame.SetSlotStatus(i, SlotStatus.SS_CLOSED);
						end
						PerformPartialSync();
						PerformValidation();

					end);
				else
					controlTable.RemoveButton:SetHide(true);
				end
	            
				local civIndex = PreGame.GetCivilization( i );

				if( civIndex ~= -1 ) then
					local civ = GameInfo.Civilizations[ civIndex ];

					controlTable.CivNumberIndex:LocalizeAndSetText("TXT_KEY_NUMBERING_FORMAT", count + 1);
					
					-- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
					local leader = nil;
					for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
						leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
					end
					local leaderDescription = leader.Description;
					local leaderButton		= controlTable.CivPulldown:GetButton();
					local leaderName		= Locale.ConvertTextKey("TXT_KEY_RANDOM_LEADER_CIV", Locale.ConvertTextKey(leaderDescription), Locale.ConvertTextKey(civ.ShortDescription));
					local MAX_NAME_SIZE		= 220;
					TruncateStringWithTooltip( leaderButton, MAX_NAME_SIZE, leaderName );

					IconHookup( civ.PortraitIndex, 64, civ.IconAtlas, controlTable.Icon );
			
				else
  					controlTable.CivNumberIndex:LocalizeAndSetText("TXT_KEY_NUMBERING_FORMAT", count + 1);
					controlTable.CivPulldown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_SPONSOR");
					controlTable.CivPulldown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_LEADER_HELP");

					SimpleCivIconHookup(-1, 64, controlTable.Icon);
				end
				count = count + 1;
			end
		end
	end
	
	Controls.CivCount:SetText(  Locale.ConvertTextKey("TXT_KEY_AD_SETUP_CIVILIZATION", count) );

	Controls.SlotStack:CalculateSize();
	Controls.SlotStack:ReprocessAnchoring();
	Controls.ListingScrollPanel:CalculateInternalSize();

end
------------------------------------------------------------------------------------------------------
-- Refreshes all of the human player data (called by RefreshPlayerList)
function RefreshHumanPlayer()
	local civIndex = PreGame.GetCivilization(0);

	-- Specific civ index or random (either implicit or explicit?)
    if( civIndex ~= -1 and civIndex ~= -2) then
        local civ = GameInfo.Civilizations[civIndex];

        -- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		
		local customName		= PreGame.GetLeaderName(0);
		local customCivName		= PreGame.GetCivilizationShortDescription(0);
		local customCivLongName = PreGame.GetCivilizationDescription(0);
		local customCivAdj		= PreGame.GetCivilizationAdjective(0);
		
		local leaderName = leader.Description;
		local civName = civ.ShortDescription;
		
		-- Check if the user customized the leader and civ name and update the UI appropriately.
		local bIsCustom = false;
		if(customName and customName ~= "") then
			leaderName = customName;
			bIsCustom = true;
		end

		if(customCivName and customCivName ~= "") then
			civName = customCivName;
			bIsCustom = true;
		end

		-- Even though these aren't used, check if they've been customized.
		if((customCivLongName and customCivLongName ~= "") or (customCivAdj and customCivAdj ~= "")) then
			bIsCustom = true;
		end

		local leaderName = Locale.ConvertTextKey("TXT_KEY_RANDOM_LEADER_CIV", leaderName, civName);
			
		if(bIsCustom) then
			Controls.CivPulldown:SetHide(true);
			Controls.CivName:SetHide(false);
			--Controls.CivName:SetText(leaderName);
			TruncateStringWithTooltip( Controls.CivName, MAX_NAME_SIZE, leaderName );
			Controls.RemoveButton:SetHide(false);
		else
			Controls.CivPulldown:SetHide(false);
			Controls.CivName:SetHide(true);
			Controls.RemoveButton:SetHide(true);

			-- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
			local leaderButton		= Controls.CivPulldown:GetButton();
			TruncateStringWithTooltip( leaderButton, MAX_NAME_SIZE, leaderName );
		end

		IconHookup( civ.PortraitIndex, 64, civ.IconAtlas, Controls.Icon );
	else
		Controls.CivNumberIndex:LocalizeAndSetText("TXT_KEY_NUMBERING_FORMAT", 1);
		local name = PreGame.GetLeaderName(0);
		local civName = PreGame.GetCivilizationShortDescription(0);
		
		if(name ~= "") then
			Controls.CivPulldown:SetHide(true);
			Controls.CivName:SetHide(false);
			Controls.CivName:SetText( Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER_CIV", name, civName ));
			Controls.RemoveButton:SetHide(false);
		else
			Controls.CivName:SetHide(true);
			Controls.RemoveButton:SetHide(true);
			Controls.CivPulldown:SetHide(false);
			Controls.CivPulldown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_SPONSOR");
		end

		SimpleCivIconHookup(-1, 64, Controls.Icon);
    end
end
------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
-- Screen Options
------------------------------------------------------------------------------------------------------
ScreenOptions = {

----------------------------------------------------------------
["Civs"] = {
	FullSync = function()
	
		function GetPlayableCivInfo()
			local civs = {};
			local sql = [[Select	Civilizations.ID as CivID, 
									Leaders.ID as LeaderID, 
									Civilizations.Description, 
									Civilizations.ShortDescription, 
									Leaders.Description as LeaderDescription 
									from Civilizations, Leaders, Civilization_Leaders 
									where Civilizations.Playable = 1 and CivilizationType = Civilizations.Type and LeaderheadType = Leaders.Type]];
	
			for row in DB.Query(sql) do
				table.insert(civs, {
					CivID = row.CivID,
					LeaderID = row.LeaderID,
					LeaderDescription = Locale.Lookup(row.LeaderDescription),
					ShortDescription = Locale.Lookup(row.ShortDescription),
					Description = row.Description,
				});
			end
			
			table.sort(civs, function(a,b) return Locale.Compare(a.LeaderDescription, b.LeaderDescription) == -1; end);
			
			return civs;
		end
	
		function PopulateCivPulldown( playableCivs, pullDown, playerID )

			-- Reset pulldown display
			pullDown:ClearEntries();
			pullDown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_LEADER_HELP");

			-- set up the random slot
			local controlTable = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetVoids( playerID, -1 );
			controlTable.Button:LocalizeAndSetText("TXT_KEY_RANDOM_SPONSOR");
			controlTable.Button:LocalizeAndSetToolTip("TXT_KEY_RANDOM_LEADER_HELP");
	
			for id, civ in ipairs(playableCivs) do
				local controlTable = {};
				pullDown:BuildEntry( "InstanceOne", controlTable );

				controlTable.Button:SetVoids( playerID, id );
				controlTable.Button:LocalizeAndSetText("TXT_KEY_RANDOM_LEADER_CIV", civ.LeaderDescription, civ.ShortDescription);
			end    
		    
			pullDown:CalculateInternals();
			pullDown:RegisterSelectionCallback(function(playerID, id)
				local civID = playableCivs[id] and playableCivs[id].CivID or -1;
			
				PreGame.SetCivilization( playerID, civID);
				PerformPartialSync();
			end);
		end
		
		local playableCivs = GetPlayableCivInfo();
		PopulateCivPulldown(playableCivs, Controls.CivPulldown, 0 );
		for i = 1, GameDefines.MAX_MAJOR_CIVS-1, 1 do
			PopulateCivPulldown(playableCivs, g_SlotInstances[i].CivPulldown, i );
		end
	end,
	
	PartialSync = function()
		RefreshPlayerList();
	end,
	
},
----------------------------------------------------------------

----------------------------------------------------------------
["CustomOptions"] = {
	FullSync = function()
		RefreshDropDownGameOptions();
		RefreshCheckBoxGameOptions();
	end,
	
	PartialSync = function()
		-- Still doing a full sync here..
		RefreshDropDownGameOptions();
		RefreshCheckBoxGameOptions();
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["TerrainTypes"] = {
	FullSync = function()
		local pullDown = Controls.MapTerrainPullDown;
		pullDown:ClearEntries();

		local instance = {};
		pullDown:BuildEntry( "InstanceOne", instance );
		instance.Button:LocalizeAndSetText("TXT_KEY_RANDOM_MAP_TERRAIN");
		instance.Button:LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_TERRAIN_HELP");
		instance.Button:SetVoid1( -1 );

		for info in GameInfo.Planets("ID >= 0 ORDER BY ID") do

			local instance = {};
			pullDown:BuildEntry( "InstanceOne", instance );
			instance.Button:LocalizeAndSetText(info.Description);
			instance.Button:LocalizeAndSetToolTip(info.ToolTip);
			
			local tipString : string = Locale.Lookup(info.ToolTip);
			for row in GameInfo.PlanetEffects{ PlanetType = info.Type } do
				if (row.ToolTip ~= nil) then
					tipString = tipString .. "[NEWLINE][NEWLINE]" .. Locale.Lookup(row.ToolTip);
				end
			end
			instance.Button:SetToolTipString(tipString);

			instance.Button:SetVoid1( info.ID );
		end

		pullDown:CalculateInternals();
		
		pullDown:RegisterSelectionCallback( function(id)

			PreGame.SetPlanet( id );
			if( id < 0 ) then
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_TERRAIN");
				pullDown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_TERRAIN_HELP");
			else
				local info = GameInfo.Planets[id];
				pullDown:GetButton():LocalizeAndSetText(info.Description);
				pullDown:GetButton():LocalizeAndSetToolTip(info.ToolTip);
				local tipString : string = Locale.Lookup(info.ToolTip);
				for row in GameInfo.PlanetEffects{ PlanetType = info.Type } do
					if (row.ToolTip ~= nil) then
						tipString = tipString .. "[NEWLINE][NEWLINE]" .. Locale.Lookup(row.ToolTip);
					end
				end
				pullDown:GetButton():SetToolTipString(tipString);
			end

			PerformPartialSync();
		end);
	end,
	
	PartialSync = function()

		local planet = PreGame.GetPlanet();		
		
		local info = nil;		
		if (planet ~= nil ) then		
			info = GameInfo.Planets[ planet ];
		end

		if ( info ~= nil ) then
			
			Controls.MapTerrainPullDown:GetButton():LocalizeAndSetText(info.Description);
			Controls.MapTerrainPullDown:GetButton():LocalizeAndSetToolTip(info.ToolTip);		
			local tipString : string = Locale.Lookup(info.ToolTip);
			for row in GameInfo.PlanetEffects{ PlanetType = info.Type } do
				if (row.ToolTip ~= nil) then
					tipString = tipString .. "[NEWLINE][NEWLINE]" .. Locale.Lookup(row.ToolTip);
				end
			end
			Controls.MapTerrainPullDown:GetButton():SetToolTipString(tipString);

			local filename = PreGame.GetMapScript();

			-- Get map icon
			for row in GameInfo.MapScripts{FileName = fileName, SupportsSinglePlayer = 1, Hidden = 0} do
				if row.FileName == filename then
					local IconIndex	= row.IconIndex or 0;
					local IconSize	= 64;
					local IconAtlas = row.IconAtlas;

					-- Tell seeded start
					--LuaEvents.PlanetSelected( { IconIndex, IconSize, IconAtlas });
				end
			end

		else
			Controls.MapTerrainPullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_TERRAIN");
			Controls.MapTerrainPullDown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_TERRAIN_HELP");						
		end   
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["GameSpeeds"] = {
	FullSync = function()
		local pullDown = Controls.GameSpeedPullDown;
		
		pullDown:ClearEntries();
	
		local gameSpeeds = {};
		for row in GameInfo.GameSpeeds() do
			table.insert(gameSpeeds, row);
		end
		table.sort(gameSpeeds, function(a, b) return b.GrowthPercent > a.GrowthPercent end);

		for _, v in ipairs(gameSpeeds) do
			local instance = {};
			pullDown:BuildEntry( "InstanceOne", instance );
		    
			instance.Button:SetText( Locale.ConvertTextKey( v.Description ) );
			instance.Button:SetToolTipString( Locale.ConvertTextKey( v.Help ) );
			instance.Button:SetVoid1( v.ID );
		end
		pullDown:CalculateInternals();
		
		pullDown:RegisterSelectionCallback( function(id)
			PreGame.SetGameSpeed( id );
			local gameSpeed = GameInfo.GameSpeeds[id];
			pullDown:GetButton():LocalizeAndSetText(gameSpeed.Description);
			pullDown:GetButton():SetToolTipString( Locale.ConvertTextKey( gameSpeed.Help ) );
			PerformPartialSync();
		end);
	end,
	
	PartialSync = function()
		local info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
		Controls.GameSpeedPullDown:GetButton():LocalizeAndSetText(info.Description);
		Controls.GameSpeedPullDown:GetButton():SetToolTipString( Locale.ConvertTextKey( info.Help ) );
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["Handicaps"] = {
	FullSync = function()
		local pullDown = Controls.HandicapPullDown;
		pullDown:ClearEntries();

		

		-- Must loop through once to find max (since some types aren't counted)
		local max	= 0; 
		for info in GameInfo.HandicapInfos() do
			if ( info.Type ~= "HANDICAP_AI_DEFAULT" ) then
				max = max + 1;
			end
		end

		local i	= 0;
		for info in GameInfo.HandicapInfos() do
			
			if ( info.Type ~= "HANDICAP_AI_DEFAULT" ) then

				i = i + 1;				

				local instance = {};
				pullDown:BuildEntry( "InstanceOne", instance );

				local difficultyName = Locale.ConvertTextKey( info.Description );
				if i == 1 then
					difficultyName = difficultyName .. " (" .. Locale.ConvertTextKey("TXT_KEY_HANDICAP_HINT_EASIER") .. ")";
				elseif i == max then
					difficultyName = difficultyName .. " (" .. Locale.ConvertTextKey("TXT_KEY_HANDICAP_HINT_HARDER") .. ")";
				end

				instance.Button:LocalizeAndSetText( difficultyName );
				instance.Button:LocalizeAndSetToolTip(info.Help);
				instance.Button:SetVoid1( info.ID );			
			end
		end
		
		pullDown:CalculateInternals();
		
		pullDown:RegisterSelectionCallback(function(id)
			local handicap = GameInfo.HandicapInfos[id];
			PreGame.SetHandicap( 0, id );
			pullDown:GetButton():LocalizeAndSetText(handicap.Description);
			pullDown:GetButton():LocalizeAndSetToolTip(handicap.Help);
		
			PerformPartialSync();
		end);
	end,
	
	PartialSync = function()
		local info = GameInfo.HandicapInfos[PreGame.GetHandicap(0)];
		Controls.HandicapPullDown:GetButton():LocalizeAndSetText(info.Description);
		Controls.HandicapPullDown:GetButton():LocalizeAndSetToolTip(info.Help);
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["MapSizes"] = {
	FullSync = function()
		local pullDown = Controls.MapSizePullDown;
		pullDown:ClearEntries();
		
		
		local mapType;
		if(not PreGame.IsRandomMapScript()) then
			local filename = PreGame.GetMapScript();	
			for row in GameInfo.Map_Sizes() do
				if(Path.GetFileNameWithoutExtension(filename) == Path.GetFileNameWithoutExtension(row.FileName)) then
					mapType = row.MapType;
					break;
				end
			end
		end
		
		if(mapType ~= nil) then
			local numMapSizes = 0;
			local mapSizes = {};
			for row in GameInfo.Map_Sizes{MapType = mapType} do
				mapSizes[row.WorldSizeType] = row.FileName;
				numMapSizes = numMapSizes + 1;
			end
			
			if(numMapSizes > 1) then
				local instance = {};
				pullDown:BuildEntry( "InstanceOne", instance );
				instance.Button:LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
				instance.Button:LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
				instance.Button:SetVoid1( -1 );
			end
			
			for info in GameInfo.Worlds("ID >= 0 ORDER BY ID") do
				local sizeEntry = mapSizes[info.Type];
				if(sizeEntry ~= nil) then
					local instance = {};
					pullDown:BuildEntry( "InstanceOne", instance );
					instance.Button:LocalizeAndSetText(info.Description);
					instance.Button:LocalizeAndSetToolTip(info.Help);
					instance.Button:SetVoid1( info.ID );
				end
			end			
		else
			local instance = {};
			pullDown:BuildEntry( "InstanceOne", instance );
			instance.Button:LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
			instance.Button:LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
			instance.Button:SetVoid1( -1 );

			for info in GameInfo.Worlds("ID >= 0 ORDER BY ID") do
				local instance = {};
				pullDown:BuildEntry( "InstanceOne", instance );
				instance.Button:LocalizeAndSetText(info.Description);
				instance.Button:LocalizeAndSetToolTip(info.Help);
				instance.Button:SetVoid1( info.ID );
			end
		
		end	

		pullDown:CalculateInternals();
		
		pullDown:RegisterSelectionCallback( function(id)
				
			if( id == -1 ) then
				PreGame.SetRandomWorldSize( true );
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
				pullDown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
			else
				
				local mapFilter;
				if(PreGame.IsRandomMapScript() == false) then
					 local mapScript = PreGame.GetMapScript();
					 for row in GameInfo.Map_Sizes() do 
						if(Path.GetFileName(mapScript) == Path.GetFileName(row.FileName)) then
							mapFilter = row.MapType;
							break;
						end
					end
				end
		        
				local world = GameInfo.Worlds[id];
				PreGame.SetRandomWorldSize( false );
				PreGame.SetWorldSize( id );
				PreGame.SetNumMinorCivs( world.DefaultMinorCivs );
				
				pullDown:GetButton():LocalizeAndSetText(world.Description);
				pullDown:GetButton():LocalizeAndSetToolTip(world.Help);
				
				if(mapFilter ~= nil) then		
					for row in GameInfo.Map_Sizes{MapType = mapFilter, WorldSizeType = world.Type} do
						PreGame.SetMapScript(row.FileName);
						
						local wb = UI.GetMapPreview(row.FileName);
						if(wb ~= nil) then
							
							PreGame.SetEra(wb.StartEra);
							PreGame.SetGameSpeed(wb.DefaultSpeed);
							PreGame.SetMaxTurns(wb.MaxTurns);
							PreGame.SetInitialMaxTurns(wb.MaxTurns);
							PreGame.SetNumMinorCivs(wb.CityStateCount);
							PreGame.SetRandomWorldSize(false);
							PreGame.SetWorldSize(wb.MapSize);
							PreGame.SetRandomWorldSize(false);
							PreGame.SetNumMinorCivs(-1);
							
							local victories = {};
							for _, v in ipairs(wb.VictoryTypes) do
								victories[v] = true;
							end
							
							for row in GameInfo.Victories() do
								PreGame.SetVictory(row.ID, victories[row.Type]);
							end
							
							local numPlayers = wb.PlayerCount;
							if(numPlayers == 0) then
								numPlayers = GameInfo.Worlds[wb.MapSize].DefaultPlayers	
							end
							
							for i = numPlayers, GameDefines.MAX_MAJOR_CIVS - 1 do
								if( PreGame.GetSlotStatus(i) == SlotStatus.SS_COMPUTER) then
									PreGame.SetSlotStatus(i, SlotStatus.SS_OPEN);
								end
							end
						end		
					end
				end
			end
			
			PerformValidation();
			ScreenOptions["Teams"].FullSync();
			PerformPartialSync();			
		end);
	end,
	
	PartialSync = function()
	
		--Determine if map type is a WB map or script.
		local bDisableMapSize = not PreGame.IsRandomMapScript();
		local filename = PreGame.GetMapScript();
		for row in GameInfo.MapScripts{FileName = filename} do
			ScreenOptions["MapSizes"].FullSync();
			bDisableMapSize = false;
		end	
		
		local mapType = nil;
		for row in GameInfo.Map_Sizes{FileName = filename} do
			if mapType == nil then
				ScreenOptions["MapSizes"].FullSync();			
				mapType = row.MapType;
			end
		end
		
		if(mapType ~= nil) then
			local mapSizeCount = 0;
			for row in GameInfo.Map_Sizes{MapType = mapType} do
				mapSizeCount = mapSizeCount + 1
			end
			if(mapSizeCount > 1) then
				bDisableMapSize = false;
			end
		end
		
		Controls.MapSizePullDown:GetButton():SetDisabled(bDisableMapSize);
		if( not PreGame.IsRandomWorldSize() ) then
			local info = GameInfo.Worlds[ PreGame.GetWorldSize() ];
			Controls.MapSizePullDown:GetButton():LocalizeAndSetText(info.Description);
			Controls.MapSizePullDown:GetButton():LocalizeAndSetToolTip(info.Help);
		else
			Controls.MapSizePullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
			Controls.MapSizePullDown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
		end   
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["MapTypes"] = {
	FullSync = function()
		local pullDown = Controls.MapTypePullDown;
		pullDown:ClearEntries();
	
		local mapScripts = {
			[0] = {
				Name = Locale.ConvertTextKey( "TXT_KEY_RANDOM_MAP_SCRIPT" ),
				Description = Locale.ConvertTextKey( "TXT_KEY_RANDOM_MAP_SCRIPT_HELP" ),
			},
		};

		-- Filter out maps deprecated in BE:RT
		local mapsToFilter = {
			"Skirmish.lua",
		};

		for row in GameInfo.MapScripts{SupportsSinglePlayer = 1, Hidden = 0} do
			local bFilter : boolean = false;
			for i, mapFile in ipairs(mapsToFilter) do
				if(Path.GetFileName(row.FileName) == mapFile) then
					print("Filtering out " .. mapFile.." because it is not supported in BE:RT");
					bFilter = true;
					break;
				end
			end
		
			if ( ( row.RequiresMy2K == 1 and not FiraxisLive.IsConnected() ) or ( row.FiraxisLiveKey ~= nil and FiraxisLive.GetKeyValue(row.FiraxisLiveKey) ~= 1 ) ) then
				print("Filtering out " .. row.FileName .. " because it requires My2K or a FiraxisLiveKey." );
				bFilter = true;
			end

			if not( bFilter ) then
				print("Adding " .. row.FileName);
				local script = {};
				script.FileName = row.FileName;
				script.Name = Locale.ConvertTextKey(row.Name);
				script.Description = row.Description and Locale.ConvertTextKey(row.Description) or "";
			
				table.insert(mapScripts, script);
			else
				print("Filtering out " .. row.FileName .. " because it requires My2K or a FiraxisLiveKey." );
			end
		end	
		
		for row in GameInfo.Maps() do	
			local script = {
				Name = Locale.Lookup(row.Name),
				Description = Locale.Lookup(row.Description),			
				MapType = row.Type,
			};		
			table.insert(mapScripts, script);	
		end
		
		
		-- Filter out map files that are part of size groups.
		local worldBuilderMapsToFilter = {};
		for row in GameInfo.Map_Sizes() do
			table.insert(worldBuilderMapsToFilter, row.FileName);
		end
		
		for _, map in ipairs(Modding.GetMapFiles()) do
			
			local bExclude = false;
			for i,v in ipairs(worldBuilderMapsToFilter) do
				if(v == map.File) then
					bExclude = true;
					break;
				end
			end 
		
			if(not bExclude) then
				local mapData = UI.GetMapPreview(map.File);
				
				local name, description;
				local isError = nil;
				
				if(mapData) then
					
					if(not Locale.IsNilOrWhitespace(map.Name)) then
						name = map.Name;
					
					elseif(not Locale.IsNilOrWhitespace(mapData.Name)) then
						name = Locale.Lookup(mapData.Name);
					
					else
						name = Path.GetFileNameWithoutExtension(map.File);
					end
					
					if(map.Description and #map.Description > 0) then
						description = map.Description;
					else
						description = Locale.ConvertTextKey(mapData.Description);
					end
				else
					local _;
					_, _, name = string.find(map.File, "\\.+\\(.+)%.");
					
					local nameTranslation = Locale.ConvertTextKey("TXT_KEY_INVALID_MAP_TITLE", name);
					if(nameTranslation and nameTranslation ~= "TXT_KEY_INVALID_MAP_TITLE") then
						name = nameTranslation;
					else
						name = "[COLOR_RED]" .. name .. "[ENDCOLOR]";
					end
					
					local descTranslation = Locale.ConvertTextKey("TXT_KEY_INVALID_MAP_DESC");
					if(descTranslation and descTranslation ~= "TXT_KEY_INVALID_MAP_DESC") then
						description = descTranslation;
					end
					
					isError = true;
				end
				
				local entry = {
					Name = name,
					Description = description,
					FileName = map.File,
					WBMapData = mapData,
					Error = isError,
				};
				
				table.insert(mapScripts, entry);
			end
		end
		
		table.sort(mapScripts, function(a, b) return Locale.Compare(a.Name, b.Name) == -1; end);
		
		for i, script in ipairs(mapScripts) do
		
			controlTable = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );
		    
			controlTable.Button:SetText(script.Name);
			controlTable.Button:SetToolTipString(script.Description);
			controlTable.Button:SetVoid1(i);
		end
		pullDown:CalculateInternals();

		pullDown:RegisterSelectionCallback( function(id)
			local mapScript = mapScripts[id];
			-- If this is an "error" entry (invalid WB file for example), do nothing.
			if(mapScript.Error) then
				return;
			end
			
			PreGame.SetLoadWBScenario(false);
			
			if( id == 0 or mapScript == nil) then
				PreGame.SetRandomMapScript(true);
				
			elseif(mapScript.MapType ~= nil) then
			
				local mapType = mapScript.MapType;
				PreGame.SetRandomMapScript(false);
		
				local mapSizes = {};
				
				for row in GameInfo.Map_Sizes{MapType = mapType} do
					local world = GameInfo.Worlds[row.WorldSizeType];
					
					mapSizes[world.ID] = row.FileName; 
				end
				
				local worldSize = PreGame.GetWorldSize();
				
				if(mapSizes[worldSize] ~= nil) then
					local world = GameInfo.Worlds[worldSize];
					
					--Adjust Map Size
					PreGame.SetMapScript(mapSizes[worldSize]);
					PreGame.SetRandomWorldSize( false );
					PreGame.SetWorldSize( worldSize );
					PreGame.SetNumMinorCivs( world.DefaultMinorCivs );						
				else
					-- Not Found, pick random size and set filename to smallest world size.
					for row in GameInfo.Worlds("ID >= 0 ORDER BY ID") do
						local file = mapSizes[row.ID];
						if(file ~= nil) then
						
							PreGame.SetRandomWorldSize( false );
							PreGame.SetMapScript(file);
							PreGame.SetWorldSize( row.ID );
							PreGame.SetNumMinorCivs( row.DefaultMinorCivs );	
							break;
						end
					end
				end
			
			else
				PreGame.SetRandomMapScript(false);
				PreGame.SetMapScript(mapScript.FileName);
				
				-- If it's a WB Map, we have more to do.
				if(mapScript.WBMapData ~= nil) then
					local wb = mapScript.WBMapData;
						
					PreGame.SetEra(wb.StartEra);
					PreGame.SetGameSpeed(wb.DefaultSpeed);
					PreGame.SetMaxTurns(wb.MaxTurns);
					PreGame.SetInitialMaxTurns(wb.MaxTurns);
					PreGame.SetNumMinorCivs(wb.CityStateCount);
					PreGame.SetRandomWorldSize(false);
					PreGame.SetWorldSize(wb.MapSize);
					PreGame.SetRandomWorldSize(false);
					PreGame.SetNumMinorCivs(-1);
					
					local victories = {};
					for _, v in ipairs(wb.VictoryTypes) do
						victories[v] = true;
					end
					
					for row in GameInfo.Victories() do
						PreGame.SetVictory(row.ID, victories[row.Type]);
					end
					
					local numPlayers = wb.PlayerCount;
					if(numPlayers == 0) then
						numPlayers = GameInfo.Worlds[wb.MapSize].DefaultPlayers	
					end
					
					for i = numPlayers, GameDefines.MAX_MAJOR_CIVS - 1 do
						if( PreGame.GetSlotStatus(i) == SlotStatus.SS_COMPUTER) then
							PreGame.SetSlotStatus(i, SlotStatus.SS_OPEN);
						end
					end
					
					ScreenOptions["Teams"].FullSync();
				end				
			end
			
			PerformPartialSync();

		end);	
	end,
	
	PartialSync = function()
		local pullDown = Controls.MapTypePullDown;
		if( not PreGame.IsRandomMapScript() ) then 
			
			local bFound = false;
			local mapScriptFileName = PreGame.GetMapScript();
			for row in GameInfo.MapScripts{FileName = mapScriptFileName} do
				if not bFound then
					pullDown:GetButton():LocalizeAndSetText(row.Name);
					pullDown:GetButton():LocalizeAndSetToolTip(row.Description or "");

					LuaEvents.PlanetSelected( { row.IconIndex, 64, row.IconAtlas });
					bFound = true;
				end
			end
			
			if(not bFound) then
				for row in GameInfo.Map_Sizes{FileName = mapScriptFileName} do
					local mapEntry = GameInfo.Maps[row.MapType];
					if(mapEntry ~= nil) then
						local pullDownButton = pullDown:GetButton();
						pullDownButton:LocalizeAndSetText(mapEntry.Name);
						pullDownButton:LocalizeAndSetToolTip(mapEntry.Description or "");
						bFound = true;
					end
				end
			end
			
			if(not bFound) then
				for _, map in ipairs(Modding.GetMapFiles()) do
					if(map.File == mapScriptFileName) then
						
						local mapData = UI.GetMapPreview(map.File);
						local name = "";
						local description = "";
					
						if(not Locale.IsNilOrWhitespace(map.Name)) then
							name = map.Name;
						elseif(not Locale.IsNilOrWhitespace(mapData.Name)) then
							name = mapData.Name;
						else
							name = Path.GetFileNameWithoutExtension(map.File);
						end
						
						if(not Locale.IsNilOrWhitespace(map.Description)) then
							description = map.Description;
						elseif(mapData.Description and #mapData.Description > 0) then
							description = mapData.Description;
						end
					
						pullDown:GetButton():LocalizeAndSetText(name);
						pullDown:GetButton():LocalizeAndSetToolTip(description);
						bFound = true;
						break;
					end
				end
			end
	        
			if(not bFound) then
				PreGame.SetRandomMapScript(true);
			end
		elseif(PreGame.IsRandomMapScript()) then
			pullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SCRIPT");
			pullDown:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SCRIPT_HELP");
		else
			pullDown:GetButton():LocalizeAndSetText("TXT_KEY_UNSELECTED");
			pullDown:GetButton():LocalizeAndSetToolTip("");
			LuaEvents.PlanetSelected( {nil, nil, nil} );
		end
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["MaxTurns"] = {
	FullSync = function()
		Controls.MaxTurnsCheck:RegisterCallback( Mouse.eLClick, function()
			if(Controls.MaxTurnsCheck:IsChecked()) then
				Controls.MaxTurnsEditbox:SetHide(false);
			else
				Controls.MaxTurnsEditbox:SetHide(true);
				PreGame.SetMaxTurns(0);
				PreGame.SetInitialMaxTurns(0);
			end
			
			PerformPartialSync();
		end);

		Controls.MaxTurnsEdit:RegisterCharCallback(function()
			local turnsNum = tonumber(Controls.MaxTurnsEdit:GetText());
			PreGame.SetMaxTurns( turnsNum );
			PreGame.SetInitialMaxTurns( turnsNum );
		end);
		
		ScreenOptions["MaxTurns"].PartialSync();
	end,
	
	PartialSync = function()
		local maxTurns = PreGame.GetMaxTurns();
		if(maxTurns > 0) then
			Controls.MaxTurnsCheck:SetCheck(true);
		end
		Controls.MaxTurnsEditbox:SetHide(not Controls.MaxTurnsCheck:IsChecked());
		Controls.MaxTurnsEdit:SetText(maxTurns);
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["Teams"] = {
	FullSync = function()
		function PopulateTeamPulldown( pullDown, playerID )
			local count = 0;

			pullDown:ClearEntries();
			
			-- Display Each Player
			local controlTable = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );
			
			controlTable.Button:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", 1);
			controlTable.Button:SetVoids( playerID, 0 );
			
			for i = 1, GameDefines.MAX_MAJOR_CIVS-1, 1 do
				if( PreGame.GetSlotStatus( i ) == SlotStatus.SS_COMPUTER ) then
					local controlTable = {};
					pullDown:BuildEntry( "InstanceOne", controlTable );
					
					controlTable.Button:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", i + 1);
					controlTable.Button:SetVoids( playerID, i );
				end
			end    

			pullDown:CalculateInternals();
			pullDown:RegisterSelectionCallback(function(playerID, playerChoiceID)
				
				PreGame.SetTeam(playerID, playerChoiceID);
				local slotInstance = g_SlotInstances[playerID];
				
				if( slotInstance ~= nil ) then
					slotInstance.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", PreGame.GetTeam(playerID) + 1 );
				else
					Controls.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", PreGame.GetTeam(playerID) + 1 );
				end	

				PerformValidation();
			end);

			local pullDownButton = pullDown:GetButton();
			pullDownButton:RegisterCallback(Mouse.eLClick, function( control )
				local gridControl		= pullDown:GetGrid();
				local _, screenHeight 	= UIManager:GetScreenSizeVal();
			end);
			
			local team			= PreGame.GetTeam(playerID);
			local slotInstance	= g_SlotInstances[playerID];
			
			if( slotInstance ~= nil ) then
				slotInstance.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", team + 1 );
			else
				Controls.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", team + 1 );
			end

		end
	
		PopulateTeamPulldown( Controls.TeamPullDown, 0);
		for i = 1, GameDefines.MAX_MAJOR_CIVS-1, 1 do
			PopulateTeamPulldown( g_SlotInstances[i].TeamPullDown, i);
		end		
	end,
	
	PartialSync = function()
		Controls.TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", PreGame.GetTeam(0) + 1 );
		for i = 1, GameDefines.MAX_MAJOR_CIVS-1, 1 do
			local team = PreGame.GetTeam(i);
			g_SlotInstances[i].TeamLabel:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", team + 1 );
		end		
	end,
	
	Validate = function(args)
		local playerTeam = PreGame.GetTeam(0);
	    
		for i = 1, GameDefines.MAX_MAJOR_CIVS-1 do
			if( PreGame.GetSlotStatus(i) == SlotStatus.SS_COMPUTER ) then
        		if( PreGame.GetTeam(i) ~= playerTeam ) then
        			return;
        		end
    		end
		end
		
		args.Valid = false;
		args.Reason = "TXT_KEY_BAD_TEAMS";
	end,
},
-------------------------------------------------

----------------------------------------------------------------
["VictoryConditions"] =	{
	FullSync = function()
		g_VictoryCondtionsManager:ResetInstances();
	
		for row in GameInfo.Victories() do
			local victoryCondition = g_VictoryCondtionsManager:GetInstance();
			
			local victoryConditionTextButton = victoryCondition.GameOptionRoot:GetTextButton();
			victoryConditionTextButton:LocalizeAndSetText(row.Description);
			
			victoryCondition.GameOptionRoot:SetCheck(PreGame.IsVictory(row.ID));
			if (row.Permanent) then 
				-- User is not able to change "permanent" victory types. (Time victory)
				victoryCondition.GameOptionRoot:SetDisabled(true);
				victoryCondition.GameOptionRoot:SetAlpha( 0.0 );			--HACK for ZBR, hiding time victory condition completely
			else
				victoryCondition.GameOptionRoot:SetDisabled( false );
				victoryCondition.GameOptionRoot:SetAlpha( 1.0 );
			end
			
			victoryCondition.GameOptionRoot:RegisterCheckHandler( function(bCheck)
				PreGame.SetVictory(row.ID, bCheck);
			end);
		end
		
		Controls.VictoryConditionsStack:CalculateSize();
		Controls.VictoryConditionsStack:ReprocessAnchoring();
	end,
	
	PartialSync = function()
		ScreenOptions["VictoryConditions"].FullSync();
	end,
},
----------------------------------------------------------------

----------------------------------------------------------------
["SeededStart"] =	{
	FullSync = function()
		local PullDown = {};

		pullDown = Controls.SelectColonists;
		pullDown:ClearEntries();		
		local controlTable = {};
		pullDown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText( Locale.ConvertTextKey("TXT_KEY_RANDOM") );
		controlTable.Button:SetVoid1( -2 );
		for colonist in GameInfo.Colonists() do
			local available = false;

			-- Unlocked through Firaxis Live?
			if (colonist.FiraxisLiveUnlockKey ~= nil) then
				local value = FiraxisLive.GetKeyValue(colonist.FiraxisLiveUnlockKey);
				available = (value ~= 0);
			else
				available = true;
			end

			if ( available ) then
		        local controlTable = {};
		        pullDown:BuildEntry( "InstanceOne", controlTable );
				controlTable.Button:LocalizeAndSetText( colonist.ShortDescription );
				controlTable.Button:SetToolTipString( Locale.ConvertTextKey(colonist.Description) );
				controlTable.Button:SetVoid1( colonist.ID );
			end			
		end		
		pullDown:CalculateInternals();		
		pullDown:RegisterSelectionCallback( function(id)
			PreGame.SetLoadoutColonist(LoadoutUtils.GetPlayerID(), id);	
			PerformPartialSync();
		end);


		pullDown = Controls.SelectSpacecraft;
		pullDown:ClearEntries();
		local controlTable = {};
		pullDown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText( Locale.ConvertTextKey("TXT_KEY_RANDOM") );
		controlTable.Button:SetVoid1( -2 );
		for spacecraft in GameInfo.Spacecraft() do
			local available = false;

			-- Unlocked through Firaxis Live?
			if (spacecraft.FiraxisLiveUnlockKey ~= nil) then
				local value = FiraxisLive.GetKeyValue(spacecraft.FiraxisLiveUnlockKey);
				available = (value ~= 0);
			else
				available = true;
			end

			if ( available ) then
		        local controlTable = {};
		        pullDown:BuildEntry( "InstanceOne", controlTable );
				controlTable.Button:LocalizeAndSetText( spacecraft.ShortDescription );
				controlTable.Button:SetToolTipString( Locale.ConvertTextKey(spacecraft.Description) );
				controlTable.Button:SetVoid1( spacecraft.ID );
			end			
		end		
		pullDown:CalculateInternals();		
		pullDown:RegisterSelectionCallback( function(id)
			PreGame.SetLoadoutSpacecraft(LoadoutUtils.GetPlayerID(), id);	
			PerformPartialSync();
		end);


		pullDown = Controls.SelectCargo;
		pullDown:ClearEntries();
		local controlTable = {};
		pullDown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText( Locale.ConvertTextKey("TXT_KEY_RANDOM") );
		controlTable.Button:SetVoid1( -2 );
		for cargo in GameInfo.Cargo() do
			local available = false;

			-- Unlocked through Firaxis Live?
			if (cargo.FiraxisLiveUnlockKey ~= nil) then
				local value = FiraxisLive.GetKeyValue(cargo.FiraxisLiveUnlockKey);
				available = (value ~= 0);
			else
				available = true;
			end

			if ( available ) then
		        local controlTable = {};
		        pullDown:BuildEntry( "InstanceOne", controlTable );
				controlTable.Button:LocalizeAndSetText( cargo.ShortDescription );
				controlTable.Button:SetToolTipString( Locale.ConvertTextKey(cargo.Description) );
				controlTable.Button:SetVoid1( cargo.ID );
			end			
		end		
		pullDown:CalculateInternals();		
		pullDown:RegisterSelectionCallback( function(id)
			PreGame.SetLoadoutCargo(LoadoutUtils.GetPlayerID(), id);	
			PerformPartialSync();
		end);
	end,


	PartialSync = function()
		ScreenOptions["SeededStart"].FullSync();

		local pullDown = Controls.SelectColonists;
		local id = PreGame.GetLoadoutColonist(LoadoutUtils.GetPlayerID());
		if( id < 0 ) then
			if ( id == -1 ) then
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_UNSELECTED");
			else				
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_COLONISTS");
			end
			pullDown:GetButton():LocalizeAndSetToolTip("");
		else
			local info = GameInfo.Colonists[id];
			pullDown:GetButton():LocalizeAndSetText(info.ShortDescription);
			pullDown:GetButton():LocalizeAndSetToolTip(info.Description);
		end
		
		pullDown = Controls.SelectSpacecraft;
		id = PreGame.GetLoadoutSpacecraft(LoadoutUtils.GetPlayerID());
		if( id < 0 ) then
			if ( id == -1 ) then
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_UNSELECTED");
			else				
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_SPACECRAFT");
			end
			pullDown:GetButton():LocalizeAndSetToolTip("");
		else
			local info = GameInfo.Spacecraft[id];
			pullDown:GetButton():LocalizeAndSetText(info.ShortDescription);
			pullDown:GetButton():LocalizeAndSetToolTip(info.Description);
		end

		pullDown = Controls.SelectCargo;
		id = PreGame.GetLoadoutCargo(LoadoutUtils.GetPlayerID());
		if( id < 0 ) then
			if ( id == -1 ) then
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_UNSELECTED");
			else				
				pullDown:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_CARGO");
			end
			pullDown:GetButton():LocalizeAndSetToolTip("");
		else
			local info = GameInfo.Cargo[id];
			pullDown:GetButton():LocalizeAndSetText(info.ShortDescription);
			pullDown:GetButton():LocalizeAndSetToolTip(info.Description);
		end
	end,
},


}
-- ===========================================================================
-- END ScreenOptions
-- ===========================================================================



----------------------------------------------------------------
-- ScreenOptions methods
-- Used to manage the entries in ScreenOptions
----------------------------------------------------------------
function ForEachScreenOption(func, ...)
	for _,v in pairs(ScreenOptions) do
		if(v[func]) then
			v[func](...);
		end
	end
end
------------------------------------------------------------------
function PerformFullSync()
	ForEachScreenOption("FullSync");
end
------------------------------------------------------------------
function PerformPartialSync()
	ForEachScreenOption("PartialSync");	
end
------------------------------------------------------------------
function PerformValidation()
	local args = {Valid = true};
	ForEachScreenOption("Validate", args);
	
	Controls.StartButton:SetDisabled(not args.Valid);
	
	if(not args.Valid) then
		Controls.StartButton:LocalizeAndSetToolTip(args.Reason);
	else
		Controls.StartButton:SetToolTipString(nil);
	end
end
------------------------------------------------------------------

------------------------------------------------------------------
-- Edit Player Details
------------------------------------------------------------------
Controls.EditButton:RegisterCallback( Mouse.eLClick, function()
	UIManager:PushModal(Controls.SetCivNames);
end);
-------------------------------------------------
function OnCancelEditPlayerDetails()
	Controls.RemoveButton:SetHide(true);
	Controls.CivName:SetHide(true);
	Controls.CivPulldown:SetHide(false);

	PreGame.SetLeaderName( 0, "");
	PreGame.SetCivilizationDescription( 0, "");
	PreGame.SetCivilizationShortDescription( 0, "");
	PreGame.SetCivilizationAdjective( 0, "");
	
	local civIndex = PreGame.GetCivilization( 0 );
    if( civIndex ~= -1 ) then
		local civ = GameInfo.Civilizations[ civIndex ];

        -- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		local leaderDescription = leader.Description;
	
		local leaderName = Locale.Lookup("TXT_KEY_RANDOM_LEADER_CIV", leaderDescription, civ.ShortDescription);
		local MAX_NAME_SIZE		= 220;
		TruncateStringWithTooltip( Controls.CivPulldown:GetButton(), MAX_NAME_SIZE, leaderName );
	else
		local leaderName = Locale.Lookup("TXT_KEY_RANDOM_SPONSOR");
		local MAX_NAME_SIZE		= 220;
		TruncateStringWithTooltip( Controls.CivPulldown:GetButton(), MAX_NAME_SIZE, leaderName );
	end
end
Controls.RemoveButton:RegisterCallback( Mouse.eLClick, OnCancelEditPlayerDetails );
------------------------------------------------------------------



   
---------------------------------------------------------------- 
-- Add AI Button Handler
---------------------------------------------------------------- 
function OnAdAIClicked()
    -- skip player 0 

	local maxPlayers = GameDefines.MAX_MAJOR_CIVS;
	local worldSize = PreGame.GetWorldSize();
	if(worldSize ~= -1) then
		local defaultPlayers = GameInfo.Worlds[worldSize].DefaultPlayers;
		maxPlayers = defaultPlayers + math.floor(defaultPlayers * 0.5);

		-- Clamp to 10
		if (maxPlayers > 10) then
			maxPlayers = 10;
		end
	end

    for i = 1, maxPlayers-1, 1 do
        if( PreGame.GetSlotStatus(i) ~= SlotStatus.SS_COMPUTER) then
            PreGame.SetSlotStatus(i, SlotStatus.SS_COMPUTER);
            PreGame.SetCivilization(i, -1);
            break;
        end
    end
	ScreenOptions["Teams"].FullSync();
    PerformPartialSync();
    PerformValidation();
end
Controls.AddAIButton:RegisterCallback(Mouse.eLClick, OnAdAIClicked);


---------------------------------------------------------------- 
-- Back Button Handler
---------------------------------------------------------------- 
function OnBackClicked()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.BackButton:RegisterCallback(Mouse.eLClick, OnBackClicked);

---------------------------------------------------------------- 
-- Start Button Handler
---------------------------------------------------------------- 
function OnStartClicked()

	local playerID		= LoadoutUtils.GetPlayerID();
	local sponsorID		= PreGame.GetCivilization( playerID );
	local colonistsID	= PreGame.GetLoadoutColonist( playerID );
	local cargoID		= PreGame.GetLoadoutCargo( playerID );
	local spacecraftID	= PreGame.GetLoadoutSpacecraft( playerID );
	
	-- Ignore planet selected as using map type info.
	local canStart = sponsorID ~= -1 and colonistsID ~= -1 and cargoID ~= -1 and spacecraftID ~= -1;

	if canStart then
		StartGame();
	else
		ShowWarningDialog();
	end
end
Controls.StartButton:RegisterCallback(Mouse.eLClick, OnStartClicked);

---------------------------------------------------------------- 
function StartGame()
	PreGame.SetPersistSettings(true);	
	Events.SerialEventStartGame();
	UIManager:SetUICursor( 1 );
end

---------------------------------------------------------------- 
function ShowWarningDialog()
	Controls.WarningDialog:SetHide( false );
end


---------------------------------------------------------------- 
function OnWarningOkClicked()
	Controls.WarningDialog:SetHide( true );
	StartGame();
end
Controls.WarningDialogOk:RegisterCallback( Mouse.eLClick, OnWarningOkClicked );


---------------------------------------------------------------- 
function OnWarningCancelClicked()
	Controls.WarningDialog:SetHide( true );
end
Controls.WarningDialogCancel:RegisterCallback( Mouse.eLClick, OnWarningCancelClicked );




---------------------------------------------------------------- 
-- Defaults Button Handler
---------------------------------------------------------------- 
function OnDefaultsClicked()
	Controls.RemoveButton:SetHide(true);

	-- Default custom civ names
	PreGame.SetLeaderName( 0, "");
	PreGame.SetCivilizationDescription( 0, "");
	PreGame.SetCivilizationShortDescription( 0, "");
	PreGame.SetCivilizationAdjective( 0, "");
	
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		PreGame.SetCivilization(i, -1);
		PreGame.SetTeam(i, i);
	end
	
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
	
	local mapScript = nil
	for row in GameInfo.MapScripts{FileName = "Assets\\Maps\\Continents.lua"} do
		if mapScript == nil then
			mapScript = row;
		end
	end
	if(mapScript ~= nil) then
		PreGame.SetRandomMapScript(false);
		PreGame.SetMapScript(mapScript.FileName);
	else
		PreGame.SetRandomMapScript(true);
	end
	
	-- Default Map Terrain
	local mapTerrain = GameInfo.Planets["PLANET_DEFAULT"];
	if(mapTerrain == nil) then
		gameSpeed = GameInfo.Planets()();
	end
	PreGame.SetPlanet(mapTerrain.ID);
	
	-- Default Game Pace
	local gameSpeed = GameInfo.GameSpeeds["GAMESPEED_STANDARD"];
	if(gameSpeed == nil) then
		gameSpeed = GameInfo.GameSpeeds()();
	end
	PreGame.SetGameSpeed(gameSpeed.ID);
	
	-- Default Start Era
	local era = GameInfo.Eras["ERA_ANCIENT"];
	if(era == nil) then
		era = GameInfo.Eras()();
	end
	PreGame.SetEra(era.ID);
	
	--Default Difficulty to Beginner-level
	local handicap = GameInfo.HandicapInfos["HANDICAP_MERCURY"];
	if(handicap == nil) then
		handicap = GameInfo.HandicapInfos()(); --Get first handicap info found.
	end
	PreGame.SetHandicap( 0, handicap.ID );
	

	for row in GameInfo.Victories() do
		PreGame.SetVictory(row.ID, true);
	end
		
	-- Reset Max Turns
	PreGame.SetMaxTurns(0);
	PreGame.SetInitialMaxTurns(0);
	
	PreGame.ResetGameOptions();
	PreGame.ResetMapOptions();

	-- Update elements
	PerformPartialSync();
	PerformValidation();

	-- Make callback that colonists are now reset (will update display).
	LuaEvents.SponsorSelected();
	LuaEvents.PlanetSelected( { nil, nil, nil } );

	PerformFullSync();
end
Controls.DefaultButton:RegisterCallback( Mouse.eLClick, OnDefaultsClicked );
---------------------------------------------------------------- 

----------------------------------------------------------------
-- Input Handler
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
		    OnBackClicked();
        	return true;
		end
	end
	
end
ContextPtr:SetInputHandler( InputHandler );
----------------------------------------------------------------     

----------------------------------------------------------------
-- Visibility Handler
---------------------------------------------------------------- 
function ShowHideHandler( bIsHide, bInit )
	if (not bIsHide) then
		PerformPartialSync();
		PerformValidation();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
---------------------------------------------------------------- 

-----------------------------------------------------------------
-- Adjust for resolution
-----------------------------------------------------------------
function AdjustScreenSize()
    
	--local _, screenY = UIManager:GetScreenSizeVal();
   	
    Controls.ListingScrollPanel:CalculateInternalSize();
    Controls.OptionsScrollPanel:CalculateInternalSize();
	Controls.MainGrid:ReprocessAnchoring();

	-- Fix scrollbar mis-sized.
	local scrollBar = Controls.ListingScrollPanel:GetScrollBar();
	scrollBar:SetSizeY( Controls.ListingScrollPanel:GetSizeY() );
end

-------------------------------------------------
-------------------------------------------------
function OnUpdateUI( type )
    if( type == SystemUpdateUIType.ScreenResize ) then
        AdjustScreenSize();
    end
end
Events.SystemUpdateUI.Add( OnUpdateUI );


-- When mods affect game state, perform a full sync.
Events.AfterModsActivate.Add(function()
	PerformFullSync();
end);

Events.AfterModsDeactivate.Add(function()
	PerformFullSync();
end);

Events.My2KActivate.Add(function(activated)
	PerformFullSync();
end);

-- This is a one time initialization function for UI elements.
-- It should NEVER be called more than once.
function CreateSlotInstances()
	for i = 1, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		g_SlotInstances[i] = {};
		ContextPtr:BuildInstanceForControl( "PlayerSlot", g_SlotInstances[i], Controls.SlotStack );
		g_SlotInstances[i].Root:SetHide( true );	
	end
end

AdjustScreenSize();
CreateSlotInstances();
PerformFullSync();
