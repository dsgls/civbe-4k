-------------------------------------------------
-- Internet Lobby Screen
-------------------------------------------------
include( "SupportFunctions" );
include( "InstanceManager" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local m_bDebugFillWithFakeData = false;	-- Fill list with fake data

-- Hard coded DLC packages to ignore.
local DlcGuidsToIgnore = {
 "{8871E748-29A4-4910-8C57-8C99E32D0167}",
};



-- ===========================================================================
-- MEMBERS
-- ===========================================================================

-- Listing Box Buttons
local g_InstanceManager = InstanceManager:new( "ListingButtonInstance", "Button", Controls.ListingStack );
local g_InstanceList = {};

local LIST_LOBBIES = 0;
local LIST_SERVERS = 1;
local LIST_INVITES = 2;

local SEARCH_INTERNET	= 0;	-- Internet Servers/Lobbies
local SEARCH_LAN		= 1;		-- LAN Servers/Lobbies
local SEARCH_FRIENDS	= 2;
local SEARCH_FAVORITES	= 3;
local SEARCH_HISTORY	= 4;

local GAMELISTUPDATE_CLEAR		= 1;
local GAMELISTUPDATE_COMPLETE	= 2;
local GAMELISTUPDATE_ADD		= 3;
local GAMELISTUPDATE_UPDATE		= 4;
local GAMELISTUPDATE_REMOVE		= 5;
local GAMELISTUPDATE_ERROR		= 6;

--[[
-- The list type system is currently disable but might be reused in the future.				
local g_ListTypes = {};
g_ListTypes[1] = { txtKey =	"TXT_KEY_LIST_LOBBIES_INTERNET";	ttKey = "TXT_KEY_LIST_LOBBIES_INTERNET_TT"; listType = LIST_LOBBIES; searchType = SEARCH_INTERNET; };
g_ListTypes[2] = { txtKey =	"TXT_KEY_LIST_SERVERS_INTERNET";	ttKey = "TXT_KEY_LIST_SERVERS_INTERNET_TT"; listType = LIST_SERVERS; searchType = SEARCH_INTERNET; };
g_ListTypes[3] = { txtKey =	"TXT_KEY_LIST_SERVERS_LAN";			ttKey = "TXT_KEY_LIST_SERVERS_LAN_TT";		listType = LIST_SERVERS; searchType = SEARCH_LAN; };
g_ListTypes[4] = { txtKey =	"TXT_KEY_LIST_SERVERS_FRIENDS";		ttKey = "TXT_KEY_LIST_SERVERS_FRIENDS_TT";	listType = LIST_SERVERS; searchType = SEARCH_FRIENDS; };
g_ListTypes[5] = { txtKey =	"TXT_KEY_LIST_SERVERS_FAVORITES";	ttKey = "TXT_KEY_LIST_SERVERS_FAVORITES_TT";listType = LIST_SERVERS; searchType = SEARCH_FAVORITES; };
g_ListTypes[6] = { txtKey =	"TXT_KEY_LIST_SERVERS_HISTORY";		ttKey = "TXT_KEY_LIST_SERVERS_HISTORY_TT";	listType = LIST_SERVERS; searchType = SEARCH_HISTORY; };
--]]

local m_SelectedServerID= nil;
local m_Listings		= {};

-- Sort Option Data
-- Contains all possible buttons which alter the listings sort order.
g_SortOptions = {
	{
		Button = Controls.SortbyServer,
		Column = "ServerName",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.SortbyMapName,
		Column = "MapTypeCaption",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyMapSize,
		Column = "MapSizeCaption",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyMembers,
		Column = "MembersSort",
		DefaultDirection = "desc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
	{
		Button = Controls.SortbyDLCHosted,
		Column = "DLCSort",
		DefaultDirection = "desc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
};

g_SortFunction = nil;

-------------------------------------------------
-- Helper Functions
-------------------------------------------------
function IsUsingInternetGameList()
	local lobbyMode = UI.GetMultiplayerLobbyMode();
	if (lobbyMode == MultiplayerLobbyMode.LOBBYMODE_STANDARD_INTERNET 
		or lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET
		or lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_LAN) then
		return true;
	else
		return false;
	end
end

function IsUsingPitbossGameList()
	local lobbyMode = UI.GetMultiplayerLobbyMode();
	if (lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET
		or lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_LAN) then
		return true;
	else
		return false;
	end
end

function RefreshGameList()
		if (IsUsingInternetGameList()) then
			Matchmaking.RefreshInternetGameList(); -- Async
		else
			Matchmaking.RefreshLANGameList(); -- Async
		end
end


-------------------------------------------------
-- Server Listing Button Handler (Dynamic)
-------------------------------------------------
function ServerListingButtonClick( serverID )
	if serverID and serverID >= 0 then
		local bResult, bPending = Matchmaking.JoinMultiplayerGame( serverID );
	end
end


-------------------------------------------------
-- Host Game Button Handler
-------------------------------------------------
function HostButtonClick()
    UIManager:QueuePopup( Controls.MPGameSetupScreen, PopupPriority.MPGameSetupScreen );
end
Controls.HostButton:RegisterCallback( Mouse.eLClick, HostButtonClick );

-------------------------------------------------
function UpdateRefreshButton()

--[[
	-- List type has been disabled but it might be used in the future.
	if (PreGame.IsInternetGame()) then
		local listType, searchType = Matchmaking.GetMultiplayerGameListType();
		
		for i, entry in ipairs(g_ListTypes) do
			if (entry.listType == listType and entry.searchType == searchType) then
				Controls.ListTypeLabel:LocalizeAndSetText(entry.txtKey);
			end
		end
	end
--]]
	
	if (Matchmaking.IsRefreshingGameList()) then
		Controls.RefreshButtonLabel:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_STOP_REFRESH_GAME_LIST");
		Controls.RefreshButton:LocalizeAndSetToolTip("TXT_KEY_MULTIPLAYER_STOP_REFRESH_GAME_LIST_TT");
	else
		Controls.RefreshButtonLabel:LocalizeAndSetText("TXT_KEY_MULTIPLAYER_REFRESH_GAME_LIST");
		Controls.RefreshButton:LocalizeAndSetToolTip("TXT_KEY_MULTIPLAYER_REFRESH_GAME_LIST_TT");
	end
end

-------------------------------------------------
-- Refresh Game List Button Handler
-------------------------------------------------
function RefreshButtonClick()
	if (Matchmaking.IsRefreshingGameList()) then
		Matchmaking.StopRefreshingGameList();
	else
		RefreshGameList();
	end
	
	UpdateRefreshButton();
end
Controls.RefreshButton:RegisterCallback( Mouse.eLClick, RefreshButtonClick );

-------------------------------------------------
-- Connect to IP Handler
-------------------------------------------------
function OnConnectIPEdit()
	local ipAddress = Controls.ConnectIPEdit:GetText();
	if ( GetIPType( ipAddress ) == 4 ) then 
		Controls.IPStatusMessage:SetHide( true );	-- all good (so far), hide any error messages
		Matchmaking.JoinIPAddress( ipAddress );
	else
		print("Invalid IP4 address!");
		Controls.IPStatusMessage:SetHide( false );
		Controls.IPStatusMessage:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_INVALID_IP4_ADDRESS") );
	end
end
Controls.ConnectIPEdit:RegisterCommitCallback( OnConnectIPEdit );

--[[ Doesn't get called when ESC pressed (need new Forge functionality?)
function OnConnectIPEditChar( charValue )
	print("Just got", charValue );
end
Controls.ConnectIPEdit:RegisterCharCallback( OnConnectIPEditChar );
]]

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function BackButtonClick()
	HandleExitRequest();
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )

--[[ Doesn't get called when ESC 
	if uiMsg == 2 and wParam == Keys.VK_ESCAPE and Controls.ConnectIPEdit:HasFocus() then	
		Controls.IPStatusMessage:SetHide( true );
		return true;
	end
]]

	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			HandleExitRequest();
		end
	end

	return true;
end
ContextPtr:SetInputHandler( InputHandler );
						
---[[		
-- The list type system is currently disable but might be reused in the future.				
-------------------------------------------------
-------------------------------------------------
function PopulateListTypePulldown()

	if (PreGame.IsInternetGame()) then
		Controls.ListTypePulldown:ClearEntries();
		Controls.ListTypePulldown:SetHide( false );
		Controls.ListTypeLabel:SetHide( false );
		
		for i, entry in ipairs(g_ListTypes) do
			local controlTable = {};
			Controls.ListTypePulldown:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:LocalizeAndSetText(entry.txtKey);
			controlTable.Button:LocalizeAndSetToolTip(entry.ttKey);
			controlTable.Button:SetVoid1( i );
		end
		Controls.ListTypePulldown:CalculateInternals();
	else
--		Controls.ListTypePulldown:SetHide( true );
		Controls.ListTypeLabel:SetHide( true );
	end
	
--	Controls.BottomStack:CalculateSize();
--	Controls.BottomStack:ReprocessAnchoring();	
end

-------------------------------------------------
-------------------------------------------------
--[[ ??TRON Is list type utilized?
function OnListTypePull( id )
	Matchmaking.SetMultiplayerGameListType( g_ListTypes[id].listType, g_ListTypes[id].searchType );		
	
	if PreGame.IsInternetGame() then
		if (Matchmaking.GetMultiplayerGameCount() == 0) then
			-- If no games are listed, then refresh, else just show them the current list and they can refresh on their own.
			Matchmaking.RefreshInternetGameList(); -- Async
		end
	else
		Matchmaking.RefreshLANGameList(); -- Async
	end
	
	m_SelectedServerID = nil;
	UpdateRefreshButton();		
	UpdateGameList();
end
Controls.ListTypePulldown:RegisterSelectionCallback( OnListTypePull );
--]]

-------------------------------------------------
-- Event Handler: MultiplayerGameListClear
-------------------------------------------------
function OnGameListClear()
	m_SelectedServerID = nil;
	UpdateRefreshButton();
	UpdateGameList();
end
Events.MultiplayerGameListClear.Add( OnGameListClear );


-------------------------------------------------
-- Event Handler: MultiplayerGameListComplete
-------------------------------------------------
function OnGameListComplete()
	UpdateRefreshButton();
end
Events.MultiplayerGameListComplete.Add( OnGameListComplete );

-------------------------------------------------
-- Event Handler: MultiplayerGameListUpdated
-------------------------------------------------
function OnGameListUpdated(eAction, idLobby, eLobbyType, eSearchType)

	if (eAction == GAMELISTUPDATE_ADD) then
		local serverTable = Matchmaking.GetMultiplayerServerEntry(idLobby);		
		if (serverTable ~= nil) then 
			AddServer( serverTable[1] );
			bUpdate = true;
		end
	else
		if (eAction == GAMELISTUPDATE_REMOVE) then
			RemoveServer( idLobby );
			if (m_SelectedServerID == idLobby) then
				m_SelectedServerID = nil;
			end
			bUpdate = true;
		end
	end

	if (bUpdate) then
		SortAndDisplayListings();
	end
end
Events.MultiplayerGameListUpdated.Add( OnGameListUpdated );

-------------------------------------------------
-------------------------------------------------
function SelectGame( serverID )
	
	-- Reset the selection state of all the listings.
	if ( g_InstanceList ~= nil ) then
		for i,v in ipairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.JoinButton:SetHide( true );
			v.SelectHighlight:SetHide( true );
		end
	end

    if ( serverID ~= nil and g_InstanceList[ serverID ] ~= nil ) then
		g_InstanceList[ serverID ].JoinButton:SetHide( false );
		g_InstanceList[ serverID ].SelectHighlight:SetHide( false );
    end
    
    m_SelectedServerID = serverID;

	for _, listing in ipairs(m_Listings) do
		local controlTable = g_InstanceList[listing.ServerID];
		controlTable.SelectHighlight:SetHide( listing.ServerID ~= m_SelectedServerID);
		controlTable.JoinButton:SetHide( listing.ServerID ~= m_SelectedServerID);
	end

end

-------------------------------------------------
-------------------------------------------------
function AddServer(serverEntry)

	-- Check if server is already in the listings.
	for _,v in ipairs(m_Listings) do
		if(serverEntry.serverID == m_Listings.ServerID) then
			return;
		end
	end

	local listing = {
		ServerID = serverEntry.serverID,
		ServerName = serverEntry.serverName,
		MembersLabelCaption = serverEntry.numPlayers .. "/" .. serverEntry.maxPlayers,
		MembersLabelToolTip = ParseServerPlayers(serverEntry.Players),
		MembersSort = serverEntry.numPlayers,
	};
								
	-- Update Map Name
	do
			
		local serverMapFile = serverEntry.MapName;
		if(serverMapFile ~= nil and #serverMapFile > 0) then
					
			local bFound = false;			
			local serverMapFileName = Path.GetFileNameWithoutExtension(serverMapFile);
			
			-- First, attempt to discover the map name locally (for localization purposes).
			
			-- Check map scripts
			for row in GameInfo.MapScripts() do
				if not bFound then
					local mapFileName = Path.GetFileNameWithoutExtension(row.FileName);
				
					if(mapFileName == serverMapFileName) then
						local localizedMapName = Locale.ConvertTextKey(row.Name);
						listing.MapTypeCaption = localizedMapName;
						listing.MapTypeToolTip = row.Description and Locale.ConvertTextKey(row.Description) or "";
			
						bFound = true;
					end
				end
			end
			
			-- Check WB maps
			if(not bFound) then

				local mapData = UI.GetMapPreview(serverMapFile);
				if(mapData) then
				
					local name;
						
					if(not Locale.IsNilOrWhitespace(mapData.Name)) then
						name = Locale.Lookup(mapData.Name);
					else
						name = Path.GetFileNameWithoutExtension(serverMapFile);
					end
					
					listing.MapTypeCaption = name;
					listing.MapTypeToolTip = Locale.Lookup(mapData.Description);
					
				else
					-- Default to the filename.
					listing.MapTypeCaption = serverMapFileName;
				end
			end
		end
	end
	
	-- Update World Size Field
	do
		local serverWorldSize = serverEntry.WorldSize;
		local serverWorldSizeTranslated = serverEntry.WorldSizeTranslated;
		
		if(serverWorldSize ~= nil and #serverWorldSize > 0) then
			if(Locale.HasTextKey(serverWorldSize)) then
				listing.MapSizeCaption = Locale.Lookup(serverWorldSize);
			else
				listing.MapSizeCaption = serverWorldSizeTranslated;
			end
		else
			listing.MapSizeCaption = "";
		end
	end
		
	local filteredDLC = serverEntry.hostedDLC;
	
	-- Filter out any packages in DlcToIgnore
	local packages = ParseDlcString(serverEntry.hostedDLC);
	local filteredPackages = {};
	for _, package in ipairs(packages) do
		local shouldFilter = false;
		for _, filter in ipairs(DlcGuidsToIgnore) do
			if(package == filter) then
				shouldFilter = true;
				break;
			end
		end 
		
		if(not shouldFilter) then
			table.insert(filteredPackages, package);
		end
	end
		
	if ( #filteredPackages > 0) then
		listing.DLCHostedCaption = Locale.Lookup("TXT_KEY_MULTIPLAYER_LOBBY_YES");
		listing.DLCHostedToolTip = CreateDlcToolTip("TXT_KEY_LOBBY_REQUIRED_DLC", filteredPackages);
		
		if ( serverEntry.requiredDLCAvailable > 0 ) then
			listing.DLCHostedColorName = "Beige_Black";
			listing.DLCSort = 2;
		else
			listing.DLCHostedColorName = "Gray_Black";
			listing.DLCSort = 1;
		end
	else
		listing.DLCHostedCaption = Locale.Lookup("TXT_KEY_MULTIPLAYER_LOBBY_NO");
		listing.DLCHostedColorName = "Beige_Black";
		listing.DLCSort = 0;
	end	
	
	table.insert(m_Listings, listing);
end

-------------------------------------------------
-------------------------------------------------
function RemoveServer(serverID) 

	local index = nil;
	repeat
		index = nil;
		for i,v in ipairs(m_Listings) do
			if(v.ServerID == serverID) then
				index = i;
				break;
			end
		end
		if(index ~= nil) then
			table.remove(m_Listings, index);
		end
	until(index == nil);
	
end

function ParseDlcString(dlcString)
	local packages = {};

	local guidLength = 38;
	local nPackages = math.floor(#dlcString / guidLength);
	
	for i = 1, nPackages, 1 do
		local index = (i-1) * guidLength;
		local packageId = string.sub(dlcString, index + 1, index + guidLength);
		table.insert(packages, packageId);
	end
	
	return packages;
end

function CreateDlcToolTip(headerString, packages)
	local lines = {Locale.Lookup(headerString)};
	
	for _, packageId in ipairs(packages) do
		
		local dlcName, dlcDescription = Modding.GetDlcNameDescriptionKeys(packageId);
		table.insert(lines, "[ICON_BULLET]" .. Locale.Lookup(dlcName));
	end
	
	return table.concat(lines, "[NEWLINE]");
end

function ParseServerPlayers(playerList)
	-- replace comma separation with new lines.
	parsedPlayers = string.gsub(playerList, ", ", "[NEWLINE]"); 
	-- remove the unique network id that is post-script to each player's name. Example : "razorace@5868795"
	return string.gsub(parsedPlayers, "@(.-)%[NEWLINE%]", "[NEWLINE]");
end

-- ===========================================================================
function UpdateGameList() 

	m_Listings = {};
	m_SelectedServerID = nil;
	
	-- Get the Current Server List
	local serverTable = Matchmaking.GetMultiplayerGameList();
		
	-- Display Each Server
	if serverTable then
		for i,v in ipairs( serverTable ) do
			AddServer( v );
		end
	end
	
	SortAndDisplayListings();
end

-- ===========================================================================
function SortAndDisplayListings()

	table.sort(m_Listings, g_SortFunction);

	g_InstanceManager:ResetInstances();
	g_InstanceList = {};
	
	if ( m_bDebugFillWithFakeData ) then
		for i=1,3,1 do
			table.insert( m_Listings, { ServerName="FooBarBazSwagShowtimeWrexcil"..tostring(i), MembersLabelCaption="Foo1", MembersLabelToolTip="Foo TT", MapTypeCaption="FooMap", MapTypeToolTip="FooMap TT", MapSizeCaption="Foo caption", MapSizeToolTip="Foo TT", DLCHostedCaption="DLC foo caption", DLCHostedToolTip="foo TT", DLCHostedColorName="Red",	ServerID=1000+i } );
			--table.insert( m_Listings, { ServerName="Bar", MembersLabelCaption="Bar1", MembersLabelToolTip="Bar TT", MapTypeCaption="BarMap", MapTypeToolTip="BarMap TT", MapSizeCaption="Bar caption", MapSizeToolTip="Bar TT", DLCHostedCaption="DLC bar caption", DLCHostedToolTip="bar TT", DLCHostedColorName="Orange", ServerID=2001+i } );
		end
	end

	for _, listing in ipairs(m_Listings) do
		local controlTable = g_InstanceManager:GetInstance();
		g_InstanceList[listing.ServerID] = controlTable;
		
		TruncateString(controlTable.ServerNameLabel, controlTable.ServerNameBox:GetSizeX(), listing.ServerName); 
		controlTable.ServerNameLabel:SetColorByName( "Beige_Black" );
		controlTable.MembersLabel:SetText( listing.MembersLabelCaption);
		controlTable.MembersLabel:SetToolTipString(listing.MembersLabelToolTip);
		controlTable.MembersLabel:SetColorByName( "Beige_Black" );
		
		controlTable.ServerMapTypeLabel:SetText(listing.MapTypeCaption);
		controlTable.ServerMapTypeLabel:SetToolTipString(listing.MapTypeToolTip);
	
		controlTable.ServerMapSizeLabel:SetText(listing.MapSizeCaption);
		controlTable.ServerMapSizeLabel:SetToolTipString(listing.MapSizeToolTip);
		
		controlTable.DLCHostedLabel:SetText(listing.DLCHostedCaption);
		controlTable.DLCHostedLabel:SetToolTipString(listing.DLCHostedToolTip);
		controlTable.DLCHostedLabel:SetColorByName(listing.DLCHostedColorName);
		
		-- Enable the Button's Event Handler
		controlTable.Button:SetVoid1( listing.ServerID ); -- List ID
		controlTable.Button:RegisterCallback( Mouse.eLClick, SelectGame );
		
		-- Save the Server ID
		controlTable.JoinButton:SetVoid1( listing.ServerID ); -- Server ID
		controlTable.JoinButton:SetVoid2( 0 );

		-- Enable the Button's Event Handler
		controlTable.JoinButton:RegisterCallback( Mouse.eLClick, ServerListingButtonClick );
		
		if(listing.ServerID == m_SelectedServerID) then
			controlTable.JoinButton:SetHide(false);
			controlTable.SelectHighlight:SetHide(false);
		
		else
			controlTable.JoinButton:SetHide(true);
			controlTable.SelectHighlight:SetHide(true);
		end
	end
	
	Controls.ListingStack:CalculateSize();
	Controls.ListingStack:ReprocessAnchoring();
	Controls.ListingScrollPanel:CalculateInternalSize();
end

-------------------------------------------------
-- Leave the Lobby
-------------------------------------------------
function HandleExitRequest()
    UIManager:DequeuePopup( ContextPtr );
end


-------------------------------------------------
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )

	
	if bIsHide then
		if (not bIsInit) then
			UIManager:SetUICursor( 0 ); -- Normal
		end
		
		g_InstanceManager:ResetInstances();
		g_InstanceList = {};
		m_Listings = {};
	else	
	
		if (IsUsingInternetGameList()) then
			Matchmaking.InitInternetLobby();
		else
			Matchmaking.InitLanLobby();
		end
		
		local lobbyMode = UI.GetMultiplayerLobbyMode();
		if (lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET) then
			Matchmaking.SetMultiplayerGameListType( LIST_SERVERS, SEARCH_INTERNET );
		elseif (lobbyMode == MultiplayerLobbyMode.LOBBYMODE_PITBOSS_LAN) then 
			Matchmaking.SetMultiplayerGameListType( LIST_SERVERS, SEARCH_LAN );
		else
			Matchmaking.SetMultiplayerGameListType( LIST_LOBBIES, SEARCH_INTERNET );
		end
				
		-- list type selection is currently disabled but might be used in the future.
--		Controls.ListTypePulldown:SetHide( true );
--		Controls.ListTypeLabel:SetHide( true );
		-- PopulateListTypePulldown(); 

		RefreshButtonClick(); -- update refresh button and start a game list refresh.
		
		local bIsModding = (ContextPtr:LookUpControl(".."):GetID() == "ModMultiplayerSelectScreen");
		if IsUsingPitbossGameList() then
			Controls.TitleLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_PITBOSS_LOBBY") );
		elseif PreGame.IsInternetGame() then
			if(bIsModding) then
				Controls.TitleLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MOD_INTERNET_LOBBY") );
			else
				Controls.TitleLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_INTERNET_LOBBY") );
			end
		else
			if(bIsModding) then
				Controls.TitleLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MOD_LAN_LOBBY") );
			else
				Controls.TitleLabel:SetText( Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_LAN_LOBBY") );
			end
		end
		
		AdjustScreenSize();

		-- Setup Connect to IP
		Controls.ConnectIPBox:SetHide(lobbyMode ~= MultiplayerLobbyMode.LOBBYMODE_PITBOSS_INTERNET);
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler )


-------------------------------------------------
-------------------------------------------------
function AdjustScreenSize()
    Controls.ListingScrollPanel:CalculateInternalSize();
	Controls.InnerGridBG:ReprocessAnchoring();
end


-------------------------------------------------
-- Event Handler: MultiplayerGameLaunched
-------------------------------------------------
function OnGameLaunched()

	UIManager:DequeuePopup( ContextPtr );

end
Events.MultiplayerGameLaunched.Add( OnGameLaunched );

-------------------------------------------------------------------------------
-- Sorting Support
-------------------------------------------------------------------------------
function AlphabeticalSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == -1;
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == 1;
			end
		end
	end
end

function NumericSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;
			
			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(va) < tonumber(vb);
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;

			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(vb) < tonumber(va);
			end
		end
	end
end

function GetSortFunction(sortOptions)
	local orderBy = nil;
	for i,v in ipairs(sortOptions) do
		if(v.CurrentDirection ~= nil) then
			local secondarySort = nil;
			if(v.SecondaryColumn ~= nil) then
				if(v.SecondarySortType == "numeric") then
					secondarySort = NumericSortFunction(v.SecondaryColumn, v.SecondaryDirection)
				else
					secondarySort = AlphabeticalSortFunction(v.SecondaryColumn, v.SecondaryDirection);
				end
			end
		
			if(v.SortType == "numeric") then
				return NumericSortFunction(v.Column, v.CurrentDirection, secondarySort);
			else
				return AlphabeticalSortFunction(v.Column, v.CurrentDirection, secondarySort);
			end
		end
	end
	
	return nil;
end

-- Updates the sort option structure
function UpdateSortOptionState(sortOptions, selectedOption)
	-- Current behavior is to only have 1 sort option enabled at a time 
	-- though the rest of the structure is built to support multiple in the future.
	-- If a sort option was selected that wasn't already selected, use the default 
	-- direction.  Otherwise, toggle to the other direction.
	for i,v in ipairs(sortOptions) do
		if(v == selectedOption) then
			if(v.CurrentDirection == nil) then			
				v.CurrentDirection = v.DefaultDirection;
			else
				if(v.CurrentDirection == "asc") then
					v.CurrentDirection = "desc";
				else
					v.CurrentDirection = "asc";
				end
			end
		else
			v.CurrentDirection = nil;
		end
	end
end

-- Registers the sort option controls click events
function RegisterSortOptions()
	for i,v in ipairs(g_SortOptions) do
		if(v.Button ~= nil) then
			v.Button:RegisterCallback(Mouse.eLClick, function() SortOptionSelected(v); end);
		end
	end

	g_SortFunction = GetSortFunction(g_SortOptions);
end

-- Callback for when sort options are selected.
function SortOptionSelected(option)
	local sortOptions = g_SortOptions;
	UpdateSortOptionState(sortOptions, option);
	g_SortFunction = GetSortFunction(sortOptions);
	
	SortAndDisplayListings();
end

-- Initialize screen
RegisterSortOptions();