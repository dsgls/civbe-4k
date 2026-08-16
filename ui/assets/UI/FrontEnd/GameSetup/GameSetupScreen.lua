-- ===========================================================================
--	Select Difficulty / Game Speed
-- ===========================================================================
include("LoadoutUtils");
include("SeededStartCommon");

local m_sortSpeeds = {}      
local m_worldInfos = {};

-- ===========================================================================
-- ===========================================================================
function Initialize()
	
	for row in GameInfo.GameSpeeds() do
		table.insert(m_sortSpeeds, row);
	end
	table.sort(m_sortSpeeds, function(a, b) return b.GrowthPercent > a.GrowthPercent end);

	for row in GameInfo.Worlds() do
		table.insert(m_worldInfos, row);
	end
	table.sort(m_worldInfos, function(a, b) return b.GridWidth * b.GridHeight > a.GridWidth * a.GridHeight end);
end


-- ===========================================================================
function OnDifficultyChange( id )
	PreGame.SetHandicap( 0, id );
	local info = GameInfo.HandicapInfos[PreGame.GetHandicap(0)];
	Controls.DifficultyPull:GetButton():LocalizeAndSetText(info.Description);
	Controls.DifficultyPull:GetButton():LocalizeAndSetToolTip(info.Help);
end

-- ===========================================================================
function OnSpeedChange( id )
	PreGame.SetGameSpeed( id );
	local info = GameInfo.GameSpeeds[id];
	Controls.SpeedPull:GetButton():LocalizeAndSetText(info.Description);
	Controls.SpeedPull:GetButton():LocalizeAndSetToolTip(info.Help);
end

-- ===========================================================================
function OnMapSizeChange( id )
	if (id == -1) then
		PreGame.SetRandomWorldSize(true);
		Controls.MapSizePull:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
		Controls.MapSizePull:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
	else
		local mapFilter;
		if (PreGame.IsRandomMapScript() == false) then
			local mapScript = PreGame.GetMapScript();
			for row in GameInfo.Map_Sizes() do
				if (Path.GetFileName(mapScript) == Path.GetFileName(row.FileName)) then
					mapFilter = row.MapType;
					break;
				end
			end
		end

		local world = GameInfo.Worlds[id];
		PreGame.SetRandomWorldSize(false);
		PreGame.SetWorldSize(id);
		PreGame.SetNumMinorCivs(world.DefaultMinorCivs);

		Controls.MapSizePull:GetButton():LocalizeAndSetText(world.Description);
		Controls.MapSizePull:GetButton():LocalizeAndSetToolTip(world.Help);

		if (mapFilter ~= nil) then
			for row in GameInfo.Map_Sizes{MapType = mapFilter, WorldSizeType = worldType} do
				PreGame.SetMapScript(row.FileName);

				local wb = UI.GetMapPreview(row.FileName);
				if (wb ~= nil) then
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
end

-- ===========================================================================
function UpdateDisplay()

	local pulldown;


	-- ===== Difficulty =====

	pulldown = Controls.DifficultyPull;
	pulldown:ClearEntries();
	local max = 0; 
	for info in GameInfo.HandicapInfos() do
		if ( info.Type ~= "HANDICAP_AI_DEFAULT" ) then
			max = max + 1;
		end
	end	
	local i = 0;
	for info in GameInfo.HandicapInfos() do
		if ( info.Type ~= "HANDICAP_AI_DEFAULT" ) then

			i = i + 1;

			local controlTable = {};
			pulldown:BuildEntry( "InstanceOne", controlTable );

			local difficultyName = Locale.ConvertTextKey( info.Description );
			if i == 1 then
				difficultyName = difficultyName .. " (" .. Locale.ConvertTextKey("TXT_KEY_HANDICAP_HINT_EASIER") .. ")";
			elseif i == max then
				difficultyName = difficultyName .. " (" .. Locale.ConvertTextKey("TXT_KEY_HANDICAP_HINT_HARDER") .. ")";
			end


			--IconHookup( info.PortraitIndex, 64, info.IconAtlas, controlTable.Icon );
			--controlTable.Help:SetText( Locale.ConvertTextKey( info.Help ) );
			controlTable.Button:SetText( difficultyName );
			controlTable.Button:SetToolTipString( Locale.ConvertTextKey( info.Help ) );
			controlTable.Button:SetVoid1( info.ID );
		end
	end

	pulldown:RegisterSelectionCallback( function(id) OnDifficultyChange( id ); end );
	info = GameInfo.HandicapInfos[PreGame.GetHandicap(0)];
	pulldown:GetButton():LocalizeAndSetText(info.Description);
	pulldown:GetButton():LocalizeAndSetToolTip(info.Help);
	pulldown:CalculateInternals();


	-- ===== Speed =====

	pulldown = Controls.SpeedPull;
	pulldown:ClearEntries();	
	for i, info in ipairs(m_sortSpeeds) do
		local controlTable = {};

		pulldown:BuildEntry( "InstanceOne", controlTable );

		controlTable.Button:SetText( Locale.ConvertTextKey( info.Description ) );
		controlTable.Button:SetToolTipString( Locale.ConvertTextKey( info.Help ) );
		controlTable.Button:SetVoid1( info.ID );
	end
	pulldown:RegisterSelectionCallback( function(id) OnSpeedChange( id ); end );
	info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
	pulldown:GetButton():LocalizeAndSetText(info.Description);
	pulldown:GetButton():LocalizeAndSetToolTip(info.Help);
	pulldown:CalculateInternals();

	-- ===== Map Size =====
	pulldown = Controls.MapSizePull;
	pulldown:ClearEntries();
	
	local mapType;
	if (not PreGame.IsRandomMapScript()) then
		local filename = PreGame.GetMapScript();
		for row in GameInfo.Map_Sizes() do
			if (Path.GetFileNameWithoutExtension(filename) == Path.GetFileNameWithoutExtension(row.FileName)) then
				mapType = row.MapType;
				break;
			end
		end
	end

	if (mapType ~= nil) then
		local numMapSizes = 0;
		local mapSizes = {};
		for row in GameInfo.Map_Sizes{MapType = mapType} do
			mapSizes[row.WorldSizeType] = row.FileName;
			numMapSizes = numMapSizes + 1;
		end

		if (numMapSizes > 1) then
			local instance = {};
			pulldown:BuildEntry("InstanceOne", instance);
			instance.Button:LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
			instance.Button:LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
			instance.Button:SetVoid1(-1);
		end

		for info in GameInfo.Worlds("ID >= 0 ORDER BY ID") do
			local sizeEntry = mapSizes[info.Type];
			if (sizeEntry ~= nil) then
				local instance = {};
				pulldown:BuildEntry("InstanceOne", instance);
				instance.Button:LocalizeAndSetText(info.Description);
				instance.Button:LocalizeAndSetToolTip(info.Help);
				instance.Button:SetVoid1(info.ID);
			end
		end
	else
		local instance = {};
		pulldown:BuildEntry("InstanceOne", instance);
		instance.Button:LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
		instance.Button:LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
		instance.Button:SetVoid1(-1);

		for info in GameInfo.Worlds("ID >= 0 ORDER BY ID") do
			local instance = {};
			pulldown:BuildEntry("InstanceOne", instance);
			instance.Button:LocalizeAndSetText(info.Description);
			instance.Button:LocalizeAndSetToolTip(info.Help);
			instance.Button:SetVoid1(info.ID);
		end
	end

	pulldown:RegisterSelectionCallback(function(id) OnMapSizeChange(id); end);
	pulldown:CalculateInternals();
	SetMapSize();
end


-- ===========================================================================
-- set the Difficulty
-- ===========================================================================
function DifficultySelected( id )
    PreGame.SetHandicap( 0, id );
    OnBack();
end


----------------------------------------------------------------        
---------------------------------------------------------------- 
function SetDifficulty()
    -- Set Difficulty Slot
    local info = GameInfo.HandicapInfos[ PreGame.GetHandicap( 0 ) ];
    if ( info ~= nil ) then
        IconHookup( info.PortraitIndex, 128, info.IconAtlas, Controls.DifficultyIcon );
        Controls.DifficultyHelp:SetText( Locale.ConvertTextKey( info.Help ) );
        Controls.DifficultyName:SetText( Locale.ConvertTextKey("TXT_KEY_AD_HANDICAP_SETTING", Locale.ConvertTextKey( info.Description ) ) );
    end
end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function SetGamePace()
    -- Set Game Pace Slot
    local info = GameInfo.GameSpeeds[ PreGame.GetGameSpeed() ];
    if ( info ~= nil ) then
        IconHookup( info.PortraitIndex, 128, info.IconAtlas, Controls.SpeedIcon );
        Controls.SpeedHelp:SetText( Locale.ConvertTextKey( info.Help ) );
        Controls.SpeedName:SetText( Locale.ConvertTextKey("TXT_KEY_AD_GAME_SPEED_SETTING", Locale.ConvertTextKey( info.Description ) ) );
    end
end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function SetMapSize()
	if (not PreGame.IsRandomWorldSize()) then
		local info = GameInfo.Worlds[PreGame.GetWorldSize()];
		Controls.MapSizePull:GetButton():LocalizeAndSetText(info.Description);
		Controls.MapSizePull:GetButton():LocalizeAndSetToolTip(info.Help);
	else
		Controls.MapSizePull:GetButton():LocalizeAndSetText("TXT_KEY_RANDOM_MAP_SIZE");
		Controls.MapSizePull:GetButton():LocalizeAndSetToolTip("TXT_KEY_RANDOM_MAP_SIZE_HELP");
	end
end

-- ===========================================================================
function OnBack()

	UIManager:DequeuePopup( ContextPtr );
    ContextPtr:SetHide( true );

	Events.AudioPlay2DSound("AS2D_INTERFACE_BUTTON_CLICK_BACK");
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );


-- ===========================================================================
function OnAccept()
	-- Going to setup, clear out any selected sponsor from previously raising
	-- shell items.
	PreGame.SetCivilization(LoadoutUtils.GetPlayerID(), ID_NO_SELECTED );

	UIManager:QueuePopup( Controls.PreGameScreen, PopupPriority.PreGameScreen );
end
Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept);


-- ===========================================================================
--	Input processing
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            OnBack();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
function OnShowHandler()
	UpdateDisplay();    
end
ContextPtr:SetShowHandler( OnShowHandler );


Initialize();

