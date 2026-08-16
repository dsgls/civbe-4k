-- ===========================================================================
--
--	SelectPlanet.lua
--	Choose which planet to land on for Seeded Start.
--
--	REFERENCE:
--	http://en.wikipedia.org/wiki/Star_catalogue
--	http://en.wikipedia.org/wiki/Gliese_Catalogue_of_Nearby_Stars
--	http://nssdc.gsfc.nasa.gov/nmc/
--  http://phl.upr.edu/press-releases/kapteyn
-- ===========================================================================


-- ===========================================================================
--	Includes
-- ===========================================================================
include("UniqueBonuses");
include("InstanceManager");
include("LoadoutUtils");
include("IconSupport");
include("UIExtras");


-- ===========================================================================
--	Constants
-- ===========================================================================
local ICON_INDEX_RESCAN			= 24;		-- Atlas index of icon for rescanning (choose new names)
local XML_CONTENT_HEIGHT		= 110;
local m_isUseSuffixNumbers		= true;
local m_isUseSuffixLetters		= true;
local RANDOM_ITEM_ID			= "Random";


-- ===========================================================================
--	GLOBAL / MEMBER variables
-- ===========================================================================
local m_selectedID		= nil;
local m_currentFolder	= nil;
local m_randomNumber	= 0;
local m_manualRandomed  = 0;
local m_planetNames		= {};
local m_isHidden		= true;
local g_InstanceManager = InstanceManager:new("ItemInstance", "Content", Controls.Stack);



-- ===========================================================================
--	Create a fictional name of a planet.
--
--	Misc notes:
--		NORMAL:		Terran (Earth-like), Protean (one ocean), Atlantean (Islands)
--		ADVANCE:	Aridean (hot, large continents), Tilted xis (freezing tundra, arid deserts), Vulcan (Almost all land)
--		EXO:		Oceania
-- ===========================================================================
function MakeFictionalPlanetName( planetTypeName )
	local hash					= UIManager:GetHash( planetTypeName );
	local planetNumber			= (m_randomNumber + hash + (m_manualRandomed * 7) );
	local name					= "";
	local root					= "";
	local separator				= "";
	local number				= "";
	local letter				= "";

	-- Build root
	local index	= (planetNumber % #m_planetNames) + 1;
	root		= Locale.ConvertTextKey( m_planetNames[index].Description );

	-- Build number
	if ( m_isUseSuffixNumbers ) then		
		separator = "-";
		number = tostring( (planetNumber % 700) + 1 );		
	end

	-- Build letter suffix
	if ( m_isUseSuffixLetters ) then				
		separator = "-";
		-- Letters represent planet # closest to start (e.g., 'b' is one closer than 'c')
		local distanceSuffixes	= { "b", "b", "b", "b", "c", "c", "c", "d", "d", "e", "f", "g", "h" };
		local letterIndex		= (planetNumber % #distanceSuffixes) + 1;
		letter = " " .. distanceSuffixes[letterIndex];			
	end
	name = root .. separator .. number .. letter;
	
	return name;
end


-- ===========================================================================
function SelectItem(uniqueId)
	m_selectedID = uniqueId;
end

-- ===========================================================================
function OnPlanetSelected( icon )

	if ( icon[1] == nil ) then
		m_selectedID = nil;
		return;
	end
	
	if ( PreGame.IsRandomMapScript() ) then
		if ( PreGame.IsRandomPlanet() ) then
			-- random
			-- Should be handled above
		else
			-- unselected
			-- Should be handled above
		end
	else
		m_selectedID = PreGame.GetMapScript();	
	end

end
LuaEvents.PlanetSelected.Add( OnPlanetSelected );

-- ===========================================================================
function OnMultiSizeMapSelected(mapEntry)
	if(mapEntry == nil) then
		PreGame.SetRandomMapScript(true);
	else
		PreGame.SetRandomMapScript(false);
		
		local mapSizes = {};
		
		for row in GameInfo.Map_Sizes{MapType = mapEntry.Type} do
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
		
			-- print("NOT FOUND");
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
	end
end


------------------------------------------------------------------------------
------------------------------------------------------------------------------
function OnMapScriptSelected(script)

	if(script == nil) then
		PreGame.SetRandomMapScript(true);
	else
		PreGame.SetRandomMapScript(false);
		
		local mapScript = "";
		if(type(script) == "string") then
			mapScript = script;
		else
			mapScript = script.FileName;
		end
		
		PreGame.SetMapScript(mapScript);
		
		if(LoadoutUtils.IsWBMap(mapScript)) then
		
			local mapInfo = UI.GetMapPreview(mapScript);
			if(mapInfo ~= nil) then		
				local world = GameInfo.Worlds[mapInfo.MapSize];
			
				--Adjust Map Size
				PreGame.SetRandomWorldSize( false );
				PreGame.SetWorldSize( mapInfo.MapSize );
				PreGame.SetNumMinorCivs( world.DefaultMinorCivs );	
				
			end
		end
	end	
end


------------------------------------------------------------------------------
------------------------------------------------------------------------------
function ShowHideHandler( bIsHide )
    if( not bIsHide ) then

		-- Every time a selection is made, the SeededStart will update all 
		-- subsections with Show/Hide... locally track if this was hidden
		-- to prevent scrolling back to the top each selection.
		if ( m_isHidden ) then
   			local screenWidth, screenHeight = UIManager:GetScreenSizeVal();	
   			Controls.ScrollPanel:SetSizeY( screenHeight - 204 );
			Controls.ScrollPanel:SetScrollValue( 0 );
		end
		m_isHidden = false;
        Refresh();
	else
		m_isHidden = true;
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

Events.My2KActivate.Add(function(activate)
	Refresh();
end);

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function Refresh()
	
	-- Build Folder Hierarchy
	local folders = {};
	local rootFolder = {
		Items = {},
		Icon = {0, 64, "WORLDTYPE_ATLAS"},
	};

	m_currentFolder = rootFolder;

	-- Add base folder items (these will NOT be sorted).
	table.insert(rootFolder.Items, {
		Id			= "NewSelection",
		Name		= (not PreGame.IsMultiplayerGame()) and Locale.Lookup("TXT_KEY_SCAN_FOR_DIFFERNT_PLANETS"),
		Description = (not PreGame.IsMultiplayerGame()) and Locale.Lookup("TXT_KEY_SCAN_FOR_DIFFERNT_PLANETS_HELP"),
		Icon		= { ICON_INDEX_RESCAN, 64, "WORLDTYPE_ATLAS"},
		Callback	= function() m_manualRandomed = m_manualRandomed + 1; m_selectedID=nil; Refresh(); end,
		}
	);

	function AddMapScriptByFileName(fileName)
		for row in GameInfo.MapScripts{FileName = fileName--[[, SupportsSinglePlayer = 1, Hidden = 0]]} do
			
			local uniqueId = row.FileName;
			table.insert(rootFolder.Items, {
				Id			= uniqueId,
				Name		= MakeFictionalPlanetName( row.Name ),  --Locale.ConvertTextKey(row.Name),
				MapType		= Locale.ConvertTextKey("TXT_KEY_MAP_WORLD_TYPE", row.Type),
				Description = Locale.ConvertTextKey(row.Description or ""),
				Icon		= {row.IconIndex or 0, 64, row.IconAtlas},
				Callback	= function() OnMapScriptSelected(row.FileName); SelectItem(uniqueId); end,
				}
			);	
		end
	end	

	AddMapScriptByFileName("Assets\\Maps\\Terran.lua");
	AddMapScriptByFileName("Assets\\Maps\\Protean.lua");
	AddMapScriptByFileName("Assets\\Maps\\Atlantean.lua");

	-- Add base folder items (these will NOT be sorted).
	table.insert(rootFolder.Items, {
		Id			= RANDOM_ITEM_ID,
		Name		= (not PreGame.IsMultiplayerGame()) and Locale.Lookup("TXT_KEY_RANDOM_MAP_SCRIPT") or Locale.Lookup("TXT_KEY_ANY_MAP_SCRIPT"),
		Description = (not PreGame.IsMultiplayerGame()) and Locale.Lookup("TXT_KEY_RANDOM_MAP_SCRIPT_HELP") or Locale.Lookup("TXT_KEY_ANY_MAP_SCRIPT_HELP"),
		Icon		= {4, 64, "WORLDTYPE_ATLAS"},
		Callback	= function() OnMapScriptSelected();	SelectItem(RANDOM_ITEM_ID); end,
		}
	);
		
	for folder in GameInfo.Map_Folders() do
	
		local folder = {
			Type		= folder.Type,
			ParentType	= folder.ParentType,
			Name		= Locale.Lookup(folder.Title),
			Description = Locale.Lookup(folder.Description),
			--Icon		= {folder.IconIndex, 64, folder.IconAtlas},
			Items		= {},	
		}
		
		folder.Callback = function() View(folder); end
		folders[folder.Type] = folder;
	end
		
	local additionalMapsFolder = folders["MAP_FOLDER_ADDITIONAL"];
	
	for row in GameInfo.Maps() do
		local folder = rootFolder;
		if(row.FolderType ~= nil) then
			folder = folders[row.FolderType];
		end
		
		local uniqueId = row;
		table.insert(folder.Items, {
			Id = uniqueId,
			Name = Locale.Lookup(row.Name),
			--MapType	= Locale.ConvertTextKey("TXT_KEY_MAP_WORLD_TYPE", row.Name),
			Description = Locale.Lookup(row.Description),
			Callback = function() 
				OnMultiSizeMapSelected(row); 
				SelectItem(uniqueId);
			end,
			Icon = {row.IconIndex, 64, row.IconAtlas},
		});

		-- If this is the selected item, use its folder as the current folder.
		if(uniqueId == m_selectedID) then
			m_currentFolder = folder;
		end	
	end
	
	local mapsToFilter = {};
	for row in GameInfo.Map_Sizes() do
		table.insert(mapsToFilter, Path.GetFileName(row.FileName));
	end
	
	local maps = Modding.GetMapFiles();
	for _, map in ipairs(maps) do
	
		local bFilter = false;
		for i, mapFile in ipairs(mapsToFilter) do
		
			if(Path.GetFileName(map.File) == mapFile) then
				bFilter = true;
				break;
			end
		end
		
		if(not bFilter) then
			
			local mapData = UI.GetMapPreview(map.File);
			
			local name, description, mapType;
			local isError = nil;
			
			if(mapData) then
				if(not Locale.IsNilOrWhitespace(map.Name)) then
					name = map.Name;
				elseif(not Locale.IsNilOrWhitespace(mapData.Name)) then
					name = Locale.Lookup(mapData.Name);
					--mapType = Locale.ConvertTextKey("TXT_KEY_MAP_WORLD_TYPE", map.Name);
				else
					name = Path.GetFileNameWithoutExtension(map.File);
				end
				
				if(not Locale.IsNilOrWhitespace(map.Description)) then
					description = map.Description;
				else
					description = Locale.Lookup(mapData.Description);
				end
				
				--print(name);
			else
				name = Path.GetFileNameWithoutExtension(map.File);
				
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
			
			local entryCallback = nil;
			
			local uniqueId = map.File;

			if(not isError) then
				entryCallback = function() 
					OnMapScriptSelected(map.File);
					SelectItem(uniqueId);
				end;
			end

			
			
			table.insert(additionalMapsFolder.Items, {
				Id = uniqueId,
				Name = name,
				Description = description,
				--MapType = mapType,
				Callback = entryCallback,
				Icon = {4, 64, "WORLDTYPE_ATLAS"},	
			});			
			
			-- If this is the selected item, use its folder as the current folder.
			if(uniqueId == m_selectedID) then
				m_currentFolder = additionalMapsFolder;
			end	
		end
	end
	
	--Add Map Scripts!
	-- Filter out these since we already added them explicitly.
	local mapsToFilter = {
		"Terran.lua",
		"Protean.lua",
		"Atlantean.lua",
	};
	
	for row in GameInfo.MapScripts{SupportsSinglePlayer = 1, Hidden = 0} do
		
		local bFilter = false;
		for i, mapFile in ipairs(mapsToFilter) do
			if(Path.GetFileName(row.FileName) == mapFile) then
				print("Filtering out " .. mapFile);
				bFilter = true;
				break;
			end
		end
		
		if ( ( row.RequiresMy2K == 1 and not FiraxisLive.IsConnected() ) or ( row.FiraxisLiveKey ~= nil and FiraxisLive.GetKeyValue(row.FiraxisLiveKey) ~= 1 ) ) then
			print("Filtering out " .. row.FileName .. " because it requires My2K or a FiraxisLiveKey." );
			bFilter = true;
		end
	
		if(not bFilter) then
			local folder = (row.FolderType ~= nil) and folders[row.FolderType] or nil;
			folder = (folder) and folder or additionalMapsFolder;
			
			print("Adding " .. row.FileName);
			local uniqueId = row.FileName;
			table.insert(folder.Items, {
				Id = uniqueId,
				Name = Locale.Lookup(row.Name),
				--MapType = Locale.ConvertTextKey("TXT_KEY_MAP_WORLD_TYPE", row.Name),
				Description = Locale.ConvertTextKey(row.Description or ""),
				Icon = {row.IconIndex or 0, 64, row.IconAtlas},
				Callback = function() 
					OnMapScriptSelected(row.FileName);
					SelectItem(uniqueId);					
				end,
			});

			-- If this is the selected item, use its folder as the current folder.
			if(uniqueId == m_selectedID) then
				m_currentFolder = folder;
			end	
		end
	end
		
	local sorted_root_folders = {};
	for _ , folder in pairs(folders) do
		if (folder.ParentType ~= nil) then
			local parentFolder = folders[folder.ParentType];
			folder.ParentFolder = parentFolder;
			table.insert(folders[folder.ParentType].Items, folder);
		else
			folder.ParentFolder = rootFolder;
			table.insert(sorted_root_folders, folder);
		end
	end
	
	table.sort(sorted_root_folders, function(a, b)
		return Locale.Compare(a.Name, b.Name) == -1;
	end);
	
	for i,v in ipairs(sorted_root_folders) do
		table.insert(rootFolder.Items, v);
	end
	
	-- SORT (ignore root folder)
	for k, v in pairs(folders) do
		if(v.Items and #v.Items > 0) then
			table.sort(v.Items, function(a, b)
				if(a.Items ~= nil and b.Items == nil) then
					return true;
				else
					if(a.Items == nil and b.Items ~= nil) then
						return false;
					end
					
					return Locale.Compare(a.Name, b.Name) == -1;
				end
			end);
		end
	end
	
	View(m_currentFolder);
end


------------------------------------------------------------------------------
------------------------------------------------------------------------------
function View(folder)
	
	m_currentFolder = folder;
	
	g_InstanceManager:ResetInstances();
	local uiList = {};

	-- Instance manager doesn't really 'reset' instances..
	-- So when we get an instance, we need to force it to be in a 'reset' state.
	function GetInstance()
		local item = g_InstanceManager:GetInstance();
		item.CheckMark:SetHide(true);
		item.Highlight:SetHide(true);
		item.Icon:SetHide(false);
		item.Name:SetOffsetVal(160,30);		
		item.Name:SetText("");
		item.MapTypeLabel:SetText("");
		item.DescriptionLabel:SetText("");
		table.insert( uiList, item );
		return item;
	end
	
	if(folder.ParentFolder ~= nil and #folder.Items > 8) then
		local item = GetInstance();
		item.Icon:SetHide(true);
		item.Name:LocalizeAndSetText("[ICON_ARROW_LEFT] {TXT_KEY_SELECT_MAP_TYPE_BACK}");
		item.Name:SetOffsetVal(20,20);
		item.DescriptionLabel:LocalizeAndSetText("TXT_KEY_SELECT_MAP_TYPE_BACK_HELP");
		item.Button:RegisterCallback(Mouse.eLClick, function() View(folder.ParentFolder); end);
	end
	
	for i, v in ipairs(folder.Items) do
		
		-- Hide empty folders.
		if(v.Items == nil or #v.Items > 0) then
			local item = GetInstance();
				
			-- Set item/folder name
			if(v.Items and #v.Items >0) then
				item.Name:SetText(v.Name .. " [ICON_ARROW_RIGHT]");
			else
				if ( v.Name ~= nil ) then
					TruncateStringWithTooltip( item.Name, 600, v.Name );
				end
			end
			
			if(v.Icon ~= nil) then
				IconHookup(v.Icon[1], v.Icon[2], v.Icon[3], item.Icon);
				item.Icon:SetHide(false);
			else
				item.Icon:SetHide(true);
				item.Name:SetOffsetVal(20,20);
			end
			
			if v.MapType ~= nil then
				item.MapTypeLabel:SetText(v.MapType);
			else
				item.MapTypeLabel:SetText("");
			end


			item.DescriptionLabel:SetText( v.Description );
	
			--If the item's unique identifier matches our selected id, show it as highlighted.
			if(m_selectedID == v.Id and v.Id ~= nil) then
				item.Highlight:SetHide(false);
				item.CheckMark:SetHide(false);
			else
				item.Highlight:SetHide(true);
				item.CheckMark:SetHide(true);
			end

			-- If description pushed past allocated size, increase height.
			local PADDING = 10;
			local contentHeight = math.max( XML_CONTENT_HEIGHT, (item.DescriptionLabel:GetOffsetY() + item.DescriptionLabel:GetSizeY() ) + PADDING );
			item.Content:SetSizeY( contentHeight );
			item.Button:SetSizeY( contentHeight );
			item.Highlight:SetSizeY( contentHeight );


			if(v.Callback ~= nil) then
				item.Button:RegisterCallback( Mouse.eLClick, function()

					v.Callback();								-- Execute the item's callback.

					-- Make callback if there is an icon selected.
					if(v.Icon ~= nil ) then
						if v.Icon[1] ~= ICON_INDEX_RESCAN then	-- scan for new planets?
							-- WARNING: This will indirectly call Refresh() because GameSetupScreen calls Hide/Show on the UI.
							LuaEvents.PlanetSelected( v.Icon );
						else
							-- Send Icon object of nil's to reset planet
							LuaEvents.PlanetSelected( {nil,nil,nil} );	
						end						
					end
				end);
			end
		end
	end
	
	if(folder.ParentFolder ~= nil) then
		local item = GetInstance();
		item.Icon:SetHide(true);
		item.Name:SetOffsetVal(20,20);
		item.Name:LocalizeAndSetText("[ICON_ARROW_LEFT] {TXT_KEY_SELECT_MAP_TYPE_BACK}");
		item.DescriptionLabel:LocalizeAndSetText("TXT_KEY_SELECT_MAP_TYPE_BACK_HELP");
		item.Button:RegisterCallback(Mouse.eLClick, function() View(folder.ParentFolder); end);
	end

	Controls.Stack:ReprocessAnchoring();
	Controls.Stack:CalculateSize();
	Controls.ScrollPanel:CalculateInternalSize();


	-- Hack for nice UI with dynamic scrollbars on the inside of art.
	-- Need to set explicitly as ResetInstances() above pools the old LUA instances so
	-- if the width is shrunk based on GetSizeX (from XML) then subsequent calls will keep shriting it.
	local NORMAL_WIDTH		= 395;
	local SCROLLING_WIDTH	= 381;
	local sizeX				= NORMAL_WIDTH;
	if IsScrollbarShowing( Controls.ScrollPanel ) then
		sizeX = SCROLLING_WIDTH;
	end
	for _,uiItem in pairs(uiList) do
		uiItem.Content:SetSizeX( sizeX );
		uiItem.Highlight:SetSizeX( sizeX );
		uiItem.Button:SetSizeX( sizeX );
		uiItem.DescriptionLabel:SetWrapWidth( sizeX - 85 );
	end
	Controls.ScrollPanel:CalculateInternalSize();	-- Once more.

	--Controls.ScrollPanel:SetScrollValue(0);
end

------------------------------------------------------------------------------
--	Accept the selected Spacecraft
------------------------------------------------------------------------------
function OnAcceptSelectedPlanet()		
	LuaEvents.NextLoadout();
	--Controls.NextButton:SetText( Locale.ConvertTextKey("{TXT_KEY_START:upper}"));
end
Controls.SelectButton:RegisterCallback( Mouse.eLClick, OnAcceptSelectedPlanet );



-- ===========================================================================
function Initialize()

	m_randomNumber  = PreGame.GetMapSeed();

	-- Don't alter this: it uses Language_en_US just to get the text key -- it will be localized back in native
	local query = "select Tag from Language_en_US WHERE Tag LIKE \"TXT_KEY_GENERATED_PLANET_NAME%\"";

	-- Build planet names.
	m_planetNames = {};
	for row in DB.Query(query) do	
		table.insert( m_planetNames, 
		{
			Description		= Locale.ConvertTextKey(row.Tag)
		});
	end		

end
Initialize();
