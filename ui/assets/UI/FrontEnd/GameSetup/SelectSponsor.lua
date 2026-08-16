------------------------------------------------------------------------------
-- Select Sponsor
------------------------------------------------------------------------------
include("UniqueBonuses");
include("InstanceManager");
include("LoadoutUtils");
include("IconSupport");
include("UIExtras");
include("SeededStartCommon");


-- ===========================================================================
-- Global Variables
-- ===========================================================================
local g_bIsScenario 		= false;
local g_bWasScenario 		= true;
local g_bRefreshCivs 		= true;
local g_sponsors			= {};		-- list of sponsors w/ attributes
local g_traitsQuery			= nil;		-- database query for sponsor traits

local m_ItemInstanceManager = InstanceManager:new("ItemInstance", "Content", Controls.Stack);


-- ===========================================================================
function ShowHideHandler( bIsHide )
	local isWBMap = LoadoutUtils.IsWBMap(PreGame.GetMapScript());
	g_bIsScenario = (PreGame.GetLoadWBScenario() and isWBMap);
	if(g_bWasScenario ~= g_bIsScenario) then
		g_bRefreshCivs = true;
	end
	g_bWasScenario = g_bIsScenario;

	if( not bIsHide ) then

		-- Fixes list item over-run in one rare case of x768 screen going from full screen to windowed.
		local screenWidth, screenHeight = UIManager:GetScreenSizeVal();	
		Controls.ScrollPanel:SetSizeY( screenHeight - 204 );

		UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
--	RETURN: The newly created "random choice" UI instance that was inserted 
--			into the list.
-- ===========================================================================
function AddRandomEntry()
	local currentSponsor= PreGame.GetCivilization(LoadoutUtils.GetPlayerID());
	local instance		= m_ItemInstanceManager:GetInstance();
	SetRandomSeededListItem( currentSponsor, instance );

	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		PreGame.SetCivilization(LoadoutUtils.GetPlayerID(), ID_EXPLICITLY_RANDOM );
		UpdateWindow();
		LuaEvents.SponsorSelected();
	end);

	return instance;
end


-- ===========================================================================
function UpdateWindow()
	
	m_ItemInstanceManager:ResetInstances();
	local uiList = {};
	
	local randomInstance = AddRandomEntry();
	table.insert( uiList, randomInstance );

	local currentSponsor = PreGame.GetCivilization(LoadoutUtils.GetPlayerID());

	RefreshCivs()

	for i,v in ipairs(g_sponsors) do
		local sponsor = v[2];

		local instance = m_ItemInstanceManager:GetInstance();
		table.insert( uiList, instance );

		-- Retrieve text for gameplay trait
		local traitText = "";
		if (g_traitsQuery ~= nil) then
			for row in g_traitsQuery(sponsor.LeaderType) do
				traitText = row.Description;
			end
		end

		instance.Highlight:SetHide(sponsor.ID ~= currentSponsor);
		instance.CheckMark:SetHide(sponsor.ID ~= currentSponsor);
		instance.NameLabel:LocalizeAndSetText(sponsor.ShortDescription);
		instance.DescriptionLabel:LocalizeAndSetText(traitText);
		IconHookup(sponsor.PortraitIndex, 64, sponsor.IconAtlas, instance.Portrait);

		local sponsorID = sponsor.ID;
		instance.Button:RegisterCallback(Mouse.eLClick, function() 
			PreGame.SetCivilization(LoadoutUtils.GetPlayerID(), sponsorID);
			UpdateWindow();
			LuaEvents.SponsorSelected();
		end);
	end

	Controls.Stack:CalculateSize();
	Controls.Stack:ReprocessAnchoring();
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

end

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function RefreshCivs()
	if (not g_bRefreshCivs) then
		return;
	end

	g_traitsQuery = DB.CreateQuery([[SELECT Description, ShortDescription FROM Traits inner join 
										 Leader_Traits ON Traits.Type = Leader_Traits.TraitType 
										 WHERE Leader_Traits.LeaderType = ? LIMIT 1]]);
	local populateUniqueBonuses = PopulateUniqueBonuses_CreateCached();
										 
	local civEntries = {};
													 
	if(g_bIsScenario) then
		local civList = UI.GetMapPlayers(PreGame.GetMapScript());
		print(civList);
		if(civList ~= nil) then
			
			local sql = [[	SELECT 
							Civilizations.ID, 
							Civilizations.Type, 
							Civilizations.Description, 
							Civilizations.ShortDescription, 
							Civilizations.PortraitIndex, 
							Civilizations.IconAtlas, 
							Leaders.Type AS LeaderType,
							Leaders.Description as LeaderDescription, 
							Leaders.PortraitIndex as LeaderPortraitIndex, 
							Leaders.IconAtlas as LeaderIconAtlas 
							FROM Civilizations, Leaders, Civilization_Leaders WHERE
							Civilizations.ID = ? AND
							Civilizations.Type = Civilization_Leaders.CivilizationType AND
							Leaders.Type = Civilization_Leaders.LeaderheadType
							LIMIT 1
						]];
						
			local scenarioCivQuery = DB.CreateQuery(sql);

			for i, v in pairs(civList) do
				if(v.Playable) then
					for row in scenarioCivQuery(v.CivType) do
						table.insert(civEntries, {Locale.Lookup(row.LeaderDescription), row, i - 1});
					end
				end
			end
			
			-- Sort by leader description;
			table.sort(civEntries, function(a, b) return Locale.Compare(a[1], b[1]) == -1 end);
		end
	else	
		-- Determine the civilizations via a unique join determining leaders vs. countries
		local sql = [[	SELECT 
						Civilizations.ID, 
						Civilizations.Type, 
						Civilizations.Description, 
						Civilizations.ShortDescription, 
						Civilizations.PortraitIndex, 
						Civilizations.IconAtlas, 
						Leaders.Type 		   as LeaderType,
						Leaders.Description    as LeaderDescription, 
						Leaders.PortraitIndex  as LeaderPortraitIndex, 
						Leaders.IconAtlas 	   as LeaderIconAtlas 
						FROM 
						Civilizations, Leaders, Civilization_Leaders 
						WHERE
						Civilizations.Type = Civilization_Leaders.CivilizationType AND
						Leaders.Type = Civilization_Leaders.LeaderheadType AND
						Civilizations.Playable = 1
					]];
		for row in DB.Query(sql) do
			table.insert(civEntries, {Locale.Lookup(row.LeaderDescription), row});
		end
		
		-- Sort by leader description;
		table.sort(civEntries, function(a, b) return Locale.Compare(a[1], b[1]) == -1 end);

	end

	g_sponsors = civEntries;
	g_bRefreshCivs = false;
end

Events.AfterModsActivate.Add(function()
	g_bRefreshCivs = true;
end);

Events.AfterModsDeactivate.Add(function()
	g_bRefreshCivs = true;
end);

------------------------------------------------------------------------------
--	Accept the selected Spacecraft
------------------------------------------------------------------------------
function OnAcceptSelectedSponsor()		
	LuaEvents.NextLoadout();
end
Controls.SelectButton:RegisterCallback( Mouse.eLClick, OnAcceptSelectedSponsor );

