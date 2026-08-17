-------------------------------------------------
-- Civilopedia screen
-------------------------------------------------
include( "InstanceManager" );
include( "IconSupport" );
include( "InfoTooltipInclude" );

-- table.sort method for sorting alphabetically.
function Alphabetically(a, b)
	return Locale.Compare(a.entryName, b.entryName) == -1;
end

local portraitSize = 128;
local buttonSize = 64;

-- various sizes of elements
local wideOuterFrameWidth		= 436;
local wideInnerFrameWidth		= 440;
local wideLabelWrapWidth		= 410
local superWideOuterFrameWidth	= 680;
local superWideInnerFrameWidth	= 680;
local superWideLabelWrapWidth	= 610;
local narrowOuterFrameWidth		= 234;
local narrowInnerFrameWidth		= 238;
local narrowLabelWrapWidth		= 210
local textPaddingFromInnerFrame = 34;
local offsetsBetweenFrames		= 4;
local quoteButtonOffset			= 60;
local numberOfButtonsPerRow		= 3;
local buttonPadding				= 8;
local buttonPaddingTimesTwo		= 16;

-- textures that will be used a lot
local defaultErrorTextureSheet = "TechAtlasSmall.dds";

local addToList = 1;
local dontAddToList = 0;

-- defines for the various categories of topics
local CategoryMain			= 1;
local CategoryConcepts	= 2;
local CategoryTech			= 3;
local CategoryUnits			= 4;
local CategoryUpgrades		= 5;
local CategoryBuildings		= 6;
local CategoryWonders		= 7;
local CategoryVirtues		= 8;
local CategoryEspionage		= 9;
local CategoryCivilizations = 10;
local CategoryQuests		= 11;
local CategoryTerrain		= 12;
local CategoryResources		= 13;
local CategoryImprovements	= 14;
local CategoryAffinities	= 15;
local CategoryStations		= 16;
local m_numCategories		= 16;

local m_selectedCategory = CategoryMain;
local CivilopediaCategory	= {};
local m_historyCurrentIndex	= 0;	-- Current topic index
local m_endTopic			= 0;	--
local m_listOfTopicsViewed	= {};

local sortedList			= {};
local otherSortedList		= {};
local searchableTextKeyList = {};
local searchableList		= {};
local m_categorizedListOfArticles = {};							-- All the articles!
local MAX_ENTRIES_PER_CATEGORY	= 10000;						-- All article are in a 1D array; but virtually are in a 2d array with this being the max per row.
local homePageOfCategoryID		= MAX_ENTRIES_PER_CATEGORY - 1;	-- Home page entries are last (possible) item in a category.


local ConceptBuildingSpecialistsId = nil;
do
	-- Hide this in a scope to prevent later references.
	local conceptBuildingSpecialists =  GameInfo.Concepts["CONCEPT_BUILDINGS_SPECIALISTS"];		
	
	-- If it's not nil, set it to the ID.			
	ConceptBuildingSpecialistsId = conceptBuildingSpecialists and conceptBuildingSpecialists.ID;
end

-- These projects were more of an implementation detail and not explicit projects
-- that the user can build.  So to avoid confusion, we shall ignore them from the pedia.
local projectsToIgnore = {
	PROJECT_SS_COCKPIT = true,
	PROJECT_SS_STASIS_CHAMBER = true,
	PROJECT_SS_ENGINE = true,
	PROJECT_SS_BOOSTER = true
};

-- Affinity images (TODO: Add to internal atlas system)
local m_textureAffinity		= {};
m_textureAffinity["AFFINITY_TYPE_PURITY"] 		= { atlas="TECHWEB_ATLAS_32x32", size=32, index=0};
m_textureAffinity["AFFINITY_TYPE_HARMONY"] 		= { atlas="TECHWEB_ATLAS_32x32", size=32, index=1};
m_textureAffinity["AFFINITY_TYPE_SUPREMACY"] 	= { atlas="TECHWEB_ATLAS_32x32", size=32, index=2};

local m_tooltipAffinity		= {};
m_tooltipAffinity["AFFINITY_TYPE_HARMONY"] 		= "TXT_KEY_TECHWEB_AFFINITY_ADDS_HARMONY";
m_tooltipAffinity["AFFINITY_TYPE_PURITY"] 		= "TXT_KEY_TECHWEB_AFFINITY_ADDS_PURITY";
m_tooltipAffinity["AFFINITY_TYPE_SUPREMACY"] 	= "TXT_KEY_TECHWEB_AFFINITY_ADDS_SUPREMACY";


-- the instance managers
local g_ListItemManager			= InstanceManager:new( "ListItemInstance", "ListItemButton", Controls.ListOfArticles );
local g_ListHeadingManager		= InstanceManager:new( "ListHeadingInstance", "ListHeadingButton", Controls.ListOfArticles );
local g_PrereqTechManager		= InstanceManager:new( "PrereqTechInstance", "PrereqTechButton", Controls.PrereqTechInnerFrame );
local g_ObsoleteTechManager		= InstanceManager:new( "ObsoleteTechInstance", "ObsoleteTechButton", Controls.ObsoleteTechInnerFrame );
local g_UpgradeManager			= InstanceManager:new( "UpgradeInstance", "UpgradeButton", Controls.UpgradeInnerFrame );
local g_LeadsToTechManager		= InstanceManager:new( "LeadsToTechInstance", "LeadsToTechButton", Controls.LeadsToTechInnerFrame );
local g_UnlockedUnitsManager	= InstanceManager:new( "UnlockedUnitInstance", "UnlockedUnitButton", Controls.UnlockedUnitsInnerFrame );
local g_UnlockedBuildingsManager= InstanceManager:new( "UnlockedBuildingInstance", "UnlockedBuildingButton", Controls.UnlockedBuildingsInnerFrame );
local g_RevealedResourcesManager= InstanceManager:new( "RevealedResourceInstance", "RevealedResourceButton", Controls.RevealedResourcesInnerFrame );
local g_RequiredResourcesManager= InstanceManager:new( "RequiredResourceInstance", "RequiredResourceButton", Controls.RequiredResourcesInnerFrame );
local g_WorkerActionsManager	= InstanceManager:new( "WorkerActionInstance", "WorkerActionButton", Controls.WorkerActionsInnerFrame );
local g_UnlockedProjectsManager = InstanceManager:new( "UnlockedProjectInstance", "UnlockedProjectButton", Controls.UnlockedProjectsInnerFrame );
local g_PromotionsManager		= InstanceManager:new( "PromotionInstance", "PromotionButton", Controls.FreePromotionsInnerFrame );
local g_SpecialistsManager		= InstanceManager:new( "SpecialistInstance", "SpecialistButton", Controls.SpecialistsInnerFrame );
local g_RequiredBuildingsManager= InstanceManager:new( "RequiredBuildingInstance", "RequiredBuildingButton", Controls.RequiredBuildingsInnerFrame );
local g_LocalResourcesManager	= InstanceManager:new( "LocalResourceInstance", "LocalResourceButton", Controls.LocalResourcesInnerFrame );
local g_RequiredPromotionsManager = InstanceManager:new( "RequiredPromotionInstance", "RequiredPromotionButton", Controls.RequiredPromotionsInnerFrame );
local g_RequiredPoliciesManager = InstanceManager:new( "RequiredPolicyInstance", "RequiredPolicyButton", Controls.RequiredPoliciesInnerFrame );
local g_FreeFormTextManager		= InstanceManager:new( "FreeFormTextInstance", "FFTextFrame", Controls.FFTextStack );
local g_BBTextManager			= InstanceManager:new( "BBTextInstance", "BBTextFrame", Controls.BBTextStack );
local g_LeadersManager			= InstanceManager:new( "LeaderInstance", "LeaderButton", Controls.LeadersInnerFrame );
local g_UniqueUnitsManager		= InstanceManager:new( "UniqueUnitInstance", "UniqueUnitButton", Controls.UniqueUnitsInnerFrame );
local g_UniqueBuildingsManager	= InstanceManager:new( "UniqueBuildingInstance", "UniqueBuildingButton", Controls.UniqueBuildingsInnerFrame );
local g_UniqueImprovementsManager = InstanceManager:new( "UniqueImprovementInstance", "UniqueImprovementButton", Controls.UniqueImprovementsInnerFrame );
local g_CivilizationsManager	= InstanceManager:new( "CivilizationInstance", "CivilizationButton", Controls.CivilizationsInnerFrame );
local g_TraitsManager			= InstanceManager:new( "TraitInstance", "TraitButton", Controls.TraitsInnerFrame );
local g_FeaturesManager			= InstanceManager:new( "FeatureInstance", "FeatureButton", Controls.FeaturesInnerFrame );
local g_ResourcesFoundManager	= InstanceManager:new( "ResourceFoundInstance", "ResourceFoundButton", Controls.ResourcesFoundInnerFrame );
local g_TerrainsManager			= InstanceManager:new( "TerrainInstance", "TerrainButton", Controls.TerrainsInnerFrame );
local g_ReplacesManager			= InstanceManager:new( "ReplaceInstance", "ReplaceButton", Controls.ReplacesInnerFrame );
local g_RevealTechsManager		= InstanceManager:new( "RevealTechInstance", "RevealTechButton", Controls.RevealTechsInnerFrame );
local g_ImprovementsManager		= InstanceManager:new( "ImprovementInstance", "ImprovementButton", Controls.ImprovementsInnerFrame );


-- ===========================================================================
--	CACHED tables
-- ===========================================================================

-- Keyed by UnitType
hstructure AffinityPrereq
	AffinityType	: string;
	Level			: number;
end
local CachedUnitAffinityPrereqs		= {};
local CachedBuildingAffinityPrereqs	= {};
for row in GameInfo.Unit_AffinityPrereqs() do
	CachedUnitAffinityPrereqs[row.UnitType] = hmake AffinityPrereq { AffinityType = row.AffinityType, Level = row.Level };
end
for row in GameInfo.Building_AffinityPrereqs() do
	CachedBuildingAffinityPrereqs[row.BuildingType] = hmake AffinityPrereq { AffinityType = row.AffinityType, Level = row.Level };
end




-- ===========================================================================
-- Dynamically resize frame based on contents.
--
function ShowAndSizeFrameToText( textString, textControl, gridInnerFrameControl, gridOutterFrameControl )
	local PADDING = 40;
	textControl:SetText( textString );
	local height = textControl:GetSizeY();				
	gridInnerFrameControl:SetSizeY( height + PADDING );
	gridInnerFrameControl:ReprocessAnchoring();
	if ( gridOutterFrameControl ~= nil ) then
		gridOutterFrameControl:SetHide( false );
		gridOutterFrameControl:SetSizeY( height + PADDING  );
		gridOutterFrameControl:ReprocessAnchoring();
	end
end



-- ===========================================================================
function SetSelectedCategory( thisCategory, isAddingToHistoryList )
	--print("SetSelectedCategory("..tostring(thisCategory)..")");
	if m_selectedCategory ~= thisCategory then

		m_selectedCategory = thisCategory;
		
		print(thisCategory);
		-- set up tab
		Controls.SelectedCategoryTab:SetOffsetVal(49 * (m_selectedCategory - 1), 0);
		Controls.SelectedCategoryTab:SetTexture( CivilopediaCategory[m_selectedCategory].buttonTexture );
		
		-- set up label for category
		Controls.CategoryLabel:SetText( Locale.ToUpper(CivilopediaCategory[m_selectedCategory].labelString) );
		
		-- populate the list of entries
		if CivilopediaCategory[m_selectedCategory].DisplayList then
			CivilopediaCategory[m_selectedCategory].DisplayList();
		else
			g_ListHeadingManager:DestroyInstances();
			g_ListItemManager:DestroyInstances();
		end
		Controls.ListOfArticles:CalculateSize();
		Controls.ListOfArticles:ReprocessAnchoring();

	end

	-- get first entry from list (this will be a special page)
	if CivilopediaCategory[m_selectedCategory].DisplayHomePage then
		CivilopediaCategory[m_selectedCategory].DisplayHomePage();		
		if isAddingToHistoryList == addToList then
			AddToNavigationHistory(m_selectedCategory, homePageOfCategoryID );
		end
	end	
	Controls.ScrollPanel:CalculateInternalSize();
	Controls.LeftScrollPanel:CalculateInternalSize();
end

-- ===========================================================================
--	Setup generic stuff for each category
-- ===========================================================================
for i = 1, m_numCategories, 1 do
	CivilopediaCategory[i] = {};
	CivilopediaCategory[i].tag = i;
	CivilopediaCategory[i].buttonClicked = function()
		SetSelectedCategory(CivilopediaCategory[i].tag, addToList );
	end
	local buttonName = "CategoryButton"..tostring(i);
	Controls[buttonName]:RegisterCallback( Mouse.eLClick, CivilopediaCategory[i].buttonClicked );
end

-------------------------------------------------------------------------------
-- setup the special case stuff for each category
-------------------------------------------------------------------------------
CivilopediaCategory[CategoryMain].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsGameplay.dds";
CivilopediaCategory[CategoryConcepts].buttonTexture	= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsSeededStart.dds";
CivilopediaCategory[CategoryTech].buttonTexture			= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsTechnology.dds";
CivilopediaCategory[CategoryUnits].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsUnit.dds";
CivilopediaCategory[CategoryUpgrades].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsUpgrades.dds";
CivilopediaCategory[CategoryBuildings].buttonTexture	= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsBuildings.dds";
CivilopediaCategory[CategoryWonders].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsWonders.dds";
CivilopediaCategory[CategoryVirtues].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsVirtues.dds";
CivilopediaCategory[CategoryEspionage].buttonTexture	= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsEspionage.dds";
CivilopediaCategory[CategoryCivilizations].buttonTexture= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsCivs.dds";
CivilopediaCategory[CategoryQuests].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsQuests.dds";
CivilopediaCategory[CategoryTerrain].buttonTexture		= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsTerrain.dds";
CivilopediaCategory[CategoryResources].buttonTexture	= "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsResourcesImprovements.dds";
CivilopediaCategory[CategoryImprovements].buttonTexture = "Assets/UI/Art/Civilopedia/CivilopediaTopButtonsImprovements.dds";
CivilopediaCategory[CategoryAffinities].buttonTexture	= "CivilopediaTopButtonsAffinities.dds";
CivilopediaCategory[CategoryStations].buttonTexture		= "CivilopediaTopButtonsStations.dds";

CivilopediaCategory[CategoryMain].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_1_LABEL" );
CivilopediaCategory[CategoryConcepts].labelString	= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_2_LABEL" );
CivilopediaCategory[CategoryTech].labelString			= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_3_LABEL" );
CivilopediaCategory[CategoryUnits].labelString			= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_4_LABEL" );
CivilopediaCategory[CategoryUpgrades].labelString		= Locale.ConvertTextKey( "TXT_KEY_UPGRADES_HEADING1_TITLE" );
CivilopediaCategory[CategoryBuildings].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_6_LABEL" );
CivilopediaCategory[CategoryWonders].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_7_LABEL" );
CivilopediaCategory[CategoryVirtues].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_8_LABEL" );
CivilopediaCategory[CategoryEspionage].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_9_LABEL" );
CivilopediaCategory[CategoryCivilizations].labelString	= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_10_LABEL" );
CivilopediaCategory[CategoryQuests].labelString			= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_11_LABEL" );
CivilopediaCategory[CategoryTerrain].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_12_LABEL" );
CivilopediaCategory[CategoryResources].labelString		= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_13_LABEL" );
CivilopediaCategory[CategoryImprovements].labelString	= Locale.ConvertTextKey( "TXT_KEY_PEDIA_CATEGORY_14_LABEL" );
CivilopediaCategory[CategoryAffinities].labelString		= Locale.Lookup("TXT_KEY_PEDIA_CATEGORY_15_LABEL");
CivilopediaCategory[CategoryStations].labelString		= Locale.Lookup("TXT_KEY_PEDIA_CATEGORY_16_LABEL");

CivilopediaCategory[CategoryMain].PopulateList = function()
	sortedList[CategoryMain] = {};

	sortedList[CategoryMain][1] = {}; -- there is only one section 
	local tableid = 1;		
	
		-- for each major category
 		for i=1, m_numCategories,1 do  
 		
			-- add an entry to a list (localized name, tag, etc.)
 			local article = {};
 			local compoundName = "TXT_KEY_PEDIA_CATEGORY_" .. tostring(i) .. "_LABEL" ;
 			local name = Locale.ConvertTextKey( compoundName );
			--antonjs: Remove this ugly exception once we can add text again
			if (i == 5) then
				name = Locale.ConvertTextKey("TXT_KEY_UPGRADES_HEADING1_TITLE");
			end
 			article.entryName = name;
 			article.entryID = i;
			article.entryCategory = CategoryMain;

			sortedList[CategoryMain][1][tableid] = article;
			tableid = tableid + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[compoundName] = article;
			m_categorizedListOfArticles[(CategoryMain * MAX_ENTRIES_PER_CATEGORY) + i] = article;
		end		
end

CivilopediaCategory[CategoryConcepts].PopulateList = function()
	sortedList[CategoryConcepts] = {};	
	local GameConceptsList = sortedList[CategoryConcepts];
	
	local conceptSections = {
		HEADER_AFFINITY = 1,
		HEADER_CITIES = 2,
		HEADER_COMBAT = 3,
		HEADER_TERRAIN = 4,
		HEADER_RESOURCES = 5,
		HEADER_IMPROVEMENTS = 6,
		HEADER_CITYGROWTH = 7,
		HEADER_TECHNOLOGY = 8,
		HEADER_CULTURE = 9,
		HEADER_DIPLOMACY = 10,
		HEADER_HEALTH = 11,
		HEADER_FOW = 12,
		HEADER_POLICIES = 13,
		HEADER_ENERGY = 14,
		HEADER_EXPLORER = 15,
		HEADER_ALIENS = 16,
		HEADER_UNITS = 17,
		HEADER_MOVEMENT = 18,
		HEADER_AIRCOMBAT = 19,
		HEADER_ESPIONAGE = 20,
		HEADER_TRADE = 21,
		HEADER_QUESTS = 22,
		HEADER_STATIONS = 23,
		HEADER_ORBITAL = 24,
		HEADER_ADVISORS = 25,
		HEADER_PEOPLE = 26,
		HEADER_VICTORY = 27,	
	}
	
	-- Create table.
	for i,v in pairs(conceptSections) do
		GameConceptsList[v] = {
			headingOpen = false,
		}; 
	end	
	
	-- for each concept
	for thisConcept in GameInfo.Concepts() do
		
		local sectionID = conceptSections[thisConcept.CivilopediaHeaderType];
		if(sectionID ~= nil) then
			-- add an article to the list (localized name, unit tag, etc.)
			local article = {};
			local name = Locale.ConvertTextKey( thisConcept.Description )
			article.entryName = name;
			article.entryID = thisConcept.ID;
			article.entryCategory = CategoryConcepts;
			article.InsertBefore = thisConcept.InsertBefore;
			article.InsertAfter = thisConcept.InsertAfter;
			article.Type = thisConcept.Type;

			table.insert(GameConceptsList[sectionID], article);
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[thisConcept.Description] = article;
			m_categorizedListOfArticles[(CategoryConcepts * MAX_ENTRIES_PER_CATEGORY) + thisConcept.ID] = article;
		end
	end
	
	-- In order to maintain the original order as best as possible,
	-- we assign "InsertBefore" values to all items that lack any insert.
	for _, conceptList in ipairs(GameConceptsList) do
		for i = #conceptList, 1, -1 do
			local concept = conceptList[i];
			
			if(concept.InsertBefore == nil and concept.InsertAfter == nil) then
				for ii = i - 1, 1, -1 do
					local previousConcept = conceptList[ii];
					if(previousConcept.InsertBefore == nil and previousConcept.InsertAfter == nil) then
						concept.InsertAfter = previousConcept.Type;
						break;
					end
				end
			end
		end
	end
	
	
	-- sort the articles by their dependencies.
	function DependencySort(articles)
		
		-- index articles by Topic
		local articlesByType= {};
		local dependencies = {};
		
		for i,v in ipairs(articles) do
			articlesByType[v.Type] = v;
			dependencies[v] = {};
		end
		
		for i,v in ipairs(articles) do
			
			local insertBefore = v.InsertBefore;
			if(insertBefore ~= nil) then
				local article = articlesByType[insertBefore];
				dependencies[article][v] = true;
			end
			
			local insertAfter = v.InsertAfter;
			if(insertAfter ~= nil) then
				local article = articlesByType[insertAfter];
				dependencies[v][article] = true;
			end
		end
		
		local sortedList = {};
		
		local articleCount = #articles;
		while(#sortedList < articleCount) do
			
			-- Attempt to find a node with 0 dependencies
			local article;
			for i,a in ipairs(articles) do
				if(dependencies[a] ~= nil and table.count(dependencies[a]) == 0) then
					article = a;
					break;
				end
			end
			
			if(article == nil) then
				print("Failed to sort articles topologically!! There are dependency cycles.");
				return nil;
			else
			
				-- Insert Node
				table.insert(sortedList, article);
				
				-- Remove node
				dependencies[article] = nil;
				for a,d in pairs(dependencies) do
					d[article] = nil;
				end
			end
		end
		
		return sortedList;
	end
		
	for i,v in ipairs(GameConceptsList) do
		local oldList = v;
		local newList = DependencySort(v);
	
		if(newList == nil) then
			newList = oldList;
		else
			newList.headingOpen = false;
		end
		
		GameConceptsList[i] = newList;
	end
end

CivilopediaCategory[CategoryTech].PopulateList = function()
	-- add the instances of the tech entries
	
	sortedList[CategoryTech] = {};
	local tableid = 1;

	for tech in GameInfo.Technologies() do
		-- add a tech entry to a list (localized name, unit tag, etc.)
 		local article	= {};
 		local name		= Locale.ConvertTextKey( tech.Description )

 		article.entryName		= name;
 		article.entryID			= tech.ID;
		article.entryCategory	= CategoryTech;			
		article.tooltipTextureOffset, article.tooltipTexture = IconLookup( tech.PortraitIndex, buttonSize, tech.IconAtlas );
		if not article.tooltipTextureOffset then
			article.tooltipTexture = defaultErrorTextureSheet;
			article.tooltipTextureOffset = nullOffset;
		end				
			
		sortedList[CategoryTech][tableid] = article;
		tableid = tableid + 1;
			
		-- Index into various lists by the appropriate keys
		searchableList[Locale.ToLower(name)]	= article;
		searchableTextKeyList[tech.Description] = article;
		m_categorizedListOfArticles[(CategoryTech * MAX_ENTRIES_PER_CATEGORY) + tech.ID] = article;
	end

	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryTech], Alphabetically);
		
end

CivilopediaCategory[CategoryUnits].PopulateList = function()
	-- add the instances of the unit entries
	sortedList[CategoryUnits] = {};
	local tableID = 1;

	for unit in GameInfo.Units() do
		local available : boolean = false;
		-- Unlocked through Firaxis Live?
		if (unit.FiraxisLiveUnlockKey ~= nil) then
			local value : number = FiraxisLive.GetKeyValue(unit.FiraxisLiveUnlockKey);
			available = (value ~= 0);
		else
			available = true;
		end

		if( available ) then
			local article = {};
			local name : string = Locale.ConvertTextKey( unit.Description )
			article.entryName = name;
			article.entryID = unit.ID;
			article.entryCategory = CategoryUnits;				

			local portraitIndex : number, portraitAtlas : string = UI.GetUnitPortraitIcon(unit.ID);

			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( portraitIndex, buttonSize, portraitAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				
		
			sortedList[CategoryUnits][tableID] = article;
			tableID = tableID + 1;
		
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[unit.Description] = article;
			m_categorizedListOfArticles[(CategoryUnits * MAX_ENTRIES_PER_CATEGORY) + unit.ID] = article;
		end
	end

	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryUnits], Alphabetically);
end


CivilopediaCategory[CategoryUpgrades].PopulateList = function()
	-- add the instances of the promotion entries
	sortedList[CategoryUpgrades] = {};
	
	local unitIndex = 1;
	for unit in GameInfo.Units() do
		local upgradeIndex = 1;
		for upgrade in GameInfo.UnitUpgrades("UnitType = '" .. unit.Type .. "' ORDER BY UpgradeTier") do
			if (sortedList[CategoryUpgrades][unitIndex] == nil) then
				sortedList[CategoryUpgrades][unitIndex] = {};
			end
			local article = {};
			local name = Locale.ConvertTextKey(upgrade.Description);
			article.entryName = name;
			article.entryID = upgrade.ID;
			article.entryCategory = CategoryUpgrades;

			local portraitIndex, portraitAtlas = UI.GetUnitPortraitIcon(unit.ID);
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( portraitIndex, buttonSize, portraitAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end

			sortedList[CategoryUpgrades][unitIndex][upgradeIndex] = article;
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[upgrade.Description] = article;
			m_categorizedListOfArticles[(CategoryUpgrades * MAX_ENTRIES_PER_CATEGORY) + upgrade.ID] = article;
			upgradeIndex = upgradeIndex + 1;
		end
		if (upgradeIndex > 1) then
			unitIndex = unitIndex + 1;
		end
	end
end


CivilopediaCategory[CategoryBuildings].PopulateList = function()
	-- add the instances of the building entries
	
	sortedList[CategoryBuildings] = {};
	local entryID = 1;
	
	for building in GameInfo.Buildings() do
	
	-- exclude wonders, etc.
	local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
		if thisBuildingClass.MaxGlobalInstances < 0 and thisBuildingClass.MaxPlayerInstances < 0 and thisBuildingClass.MaxTeamInstances < 0 then
			local article = {};
			local name = Locale.ConvertTextKey( building.Description )
			article.entryName = name;
			article.entryID = building.ID;
			article.entryCategory = CategoryBuildings;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( building.PortraitIndex, buttonSize, building.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				
			
			sortedList[CategoryBuildings][entryID] = article;
			entryID = entryID + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[building.Description] = article;
			m_categorizedListOfArticles[(CategoryBuildings * MAX_ENTRIES_PER_CATEGORY) + building.ID] = article;
		end
	end
		
	table.sort(sortedList[CategoryBuildings], Alphabetically);
end


CivilopediaCategory[CategoryWonders].PopulateList = function()
	-- add the instances of the Wonder, National Wonder, Team Wonder, and Project entries
	
	sortedList[CategoryWonders] = {};
	
	-- first Wonders
	sortedList[CategoryWonders][1] = {};
	local tableid = 1;

	for building in GameInfo.Buildings() do	
		-- exclude wonders etc.				
		local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
		if thisBuildingClass.MaxGlobalInstances > 0  then
			local article = {};
			local name = Locale.ConvertTextKey( building.Description )
			article.entryName = name;
			article.entryID = building.ID;
			article.entryCategory = CategoryWonders;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( building.PortraitIndex, buttonSize, building.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				
			
			sortedList[CategoryWonders][1][tableid] = article;
			tableid = tableid + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[building.Description] = article;
			m_categorizedListOfArticles[(CategoryWonders * MAX_ENTRIES_PER_CATEGORY) + building.ID] = article;
		end
	end
	
	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryWonders][1], Alphabetically);
			
	-- next National Wonders
	sortedList[CategoryWonders][2] = {};
	tableid = 1;

	for building in GameInfo.Buildings() do	
		local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
		if thisBuildingClass.MaxPlayerInstances == 1 and building.SpecialistCount == 0 then
			local article = {};
			local name = Locale.ConvertTextKey( building.Description )
			article.entryName = name;
			article.entryID = building.ID;
			article.entryCategory = CategoryWonders;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( building.PortraitIndex, buttonSize, building.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				
			
			sortedList[CategoryWonders][2][tableid] = article;
			tableid = tableid + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[building.Description] = article;
			m_categorizedListOfArticles[(CategoryWonders * MAX_ENTRIES_PER_CATEGORY) + building.ID] = article;
		end
	end
	
	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryWonders][2], Alphabetically);
	
	-- finally Projects
	sortedList[CategoryWonders][3] = {};
	tableid = 1;

	for building in GameInfo.Projects() do
		local bIgnore = projectsToIgnore[building.Type];	
		if(bIgnore ~= true) then
			local article = {};
			local name = Locale.ConvertTextKey( building.Description )
			article.entryName = name;
			article.entryID = building.ID + 1000;
			article.entryCategory = CategoryWonders;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( building.PortraitIndex, buttonSize, building.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				
			
			sortedList[CategoryWonders][3][tableid] = article;
			tableid = tableid + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[building.Description] = article;
			m_categorizedListOfArticles[(CategoryWonders * MAX_ENTRIES_PER_CATEGORY) + building.ID + 1000] = article;
		end
	end
	
	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryWonders][3], Alphabetically);
					
end

CivilopediaCategory[CategoryVirtues].PopulateList = function()
	-- add the instances of the policy entries
	
	sortedList[CategoryVirtues] = {};
	
	-- compose a list of ones that are kicker bonuses
	local kickers = {};
	for info in GameInfo.PolicyBranch_KickerPolicies() do
		kickers[info.PolicyType] = true;
	end
	for info in GameInfo.PolicyDepth_KickerPolicies() do
		kickers[info.PolicyType] = true;
	end

	-- for each policy branch
	for branch in GameInfo.PolicyBranchTypes() do
	
		local branchID = branch.ID;
	
		sortedList[CategoryVirtues][branchID] = {};
		local tableid = 1;
	
		-- for each policy in this branch
 		for policy in GameInfo.Policies("PolicyBranchType = '" .. branch.Type .. "'") do
 			-- don't show kickers
 			if (kickers[policy.Type] == nil) then
				local article = {};
				local name = Locale.ConvertTextKey( policy.Description )
				article.entryName = name;
				article.entryID = policy.ID;
				article.entryCategory = CategoryVirtues;
				article.tooltipTextureOffset, article.tooltipTexture = IconLookup( policy.PortraitIndex, buttonSize, policy.IconAtlas );				
				if not article.tooltipTextureOffset then
					article.tooltipTexture = defaultErrorTextureSheet;
					article.tooltipTextureOffset = nullOffset;
				end				
				
				sortedList[CategoryVirtues][branchID][tableid] = article;
				tableid = tableid + 1;
				
				-- index by various keys
				searchableList[Locale.ToLower(name)] = article;
				searchableTextKeyList[policy.Description] = article;
				m_categorizedListOfArticles[(CategoryVirtues * MAX_ENTRIES_PER_CATEGORY) + policy.ID] = article;
			end
		end

		-- sort this list alphabetically by localized name
		table.sort(sortedList[CategoryVirtues][branchID], Alphabetically);
	
	end
		
end

CivilopediaCategory[CategoryEspionage].PopulateList = function()
	local GetConceptPerk = function(conceptType)
		-- Check if there's a security project with this concept type
		for row in GameInfo.NationalSecurityProjects{Concept = conceptType} do
			return GameInfo.PlayerPerks[row.PlayerPerk];
		end

		-- Add more types of perk checks here

		return nil;
	end
	
	sortedList[CategoryEspionage] = {};
	local espionageList = sortedList[CategoryEspionage];

	-- for each concept
	for thisConcept in GameInfo.Concepts() do
		if(thisConcept.CivilopediaHeaderType == "HEADER_ESPIONAGE") then
			-- add an article to the list (localized name, unit tag, etc.)
			local article = {};
			local name = Locale.ConvertTextKey( thisConcept.Description )
			article.entryName = name;
			article.entryID = thisConcept.ID;
			article.entryCategory = CategoryEspionage;
			article.InsertBefore = thisConcept.InsertBefore;
			article.InsertAfter = thisConcept.InsertAfter;
			article.Type = thisConcept.Type;
			article.PlayerPerk = GetConceptPerk(article.Type);

			table.insert(espionageList, article);
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[thisConcept.Description] = article;
			m_categorizedListOfArticles[(CategoryEspionage * MAX_ENTRIES_PER_CATEGORY) + thisConcept.ID] = article;
		end
	end

	-- In order to maintain the original order as best as possible,
	-- we assign "InsertBefore" values to all items that lack any insert.
	for i = #espionageList, 1, -1 do
		local concept = espionageList[i];
		
		if(concept.InsertBefore == nil and concept.InsertAfter == nil) then
			for ii = i - 1, 1, -1 do
				local previousConcept = espionageList[ii];
				if(previousConcept.InsertBefore == nil and previousConcept.InsertAfter == nil) then
					concept.InsertAfter = previousConcept.Type;
					break;
				end
			end
		end
	end

	
	-- sort the articles by their dependencies.
	function DependencySort(articles)
		
		-- index articles by Topic
		local articlesByType= {};
		local dependencies = {};
		
		for i,v in ipairs(articles) do
			articlesByType[v.Type] = v;
			dependencies[v] = {};
		end
		
		for i,v in ipairs(articles) do
			
			local insertBefore = v.InsertBefore;
			if(insertBefore ~= nil) then
				local article = articlesByType[insertBefore];
				dependencies[article][v] = true;
			end
			
			local insertAfter = v.InsertAfter;
			if(insertAfter ~= nil) then
				local article = articlesByType[insertAfter];
				dependencies[v][article] = true;
			end
		end
		
		local sortedList = {};
		
		local articleCount = #articles;
		while(#sortedList < articleCount) do
			
			-- Attempt to find a node with 0 dependencies
			local article;
			for i,a in ipairs(articles) do
				if(dependencies[a] ~= nil and table.count(dependencies[a]) == 0) then
					article = a;
					break;
				end
			end
			
			if(article == nil) then
				print("Failed to sort articles topologically!! There are dependency cycles.");
				return nil;
			else
			
				-- Insert Node
				table.insert(sortedList, article);
				
				-- Remove node
				dependencies[article] = nil;
				for a,d in pairs(dependencies) do
					d[article] = nil;
				end
			end
		end
		
		return sortedList;
	end
		
	local oldList = espionageList;
	local newList = DependencySort(espionageList);

	if(newList == nil) then
		newList = oldList;
	else
		newList.headingOpen = false;
	end
	
	espionageList = newList;
	
end

CivilopediaCategory[CategoryCivilizations].PopulateList = function()
	-- add the instances of the Civilization and Leader entries
	
	sortedList[CategoryCivilizations] = {};
	
	-- first Civilizations
	sortedList[CategoryCivilizations][1] = {};
	local tableid = 1;

	for row in GameInfo.Civilizations() do
		if row.Playable == true or row.AIPlayable == true then
		--if row.Type ~= "CIVILIZATION_MINOR" and row.Type ~= "CIVILIZATION_ALIEN" and row.Type ~= "CIVILIZATION_NEUTRAL_PROXY" then
			local article = {};
			local name = Locale.ConvertTextKey( row.ShortDescription )
			article.entryName = name;
			article.entryID = row.ID;
			article.entryCategory = CategoryCivilizations;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( row.PortraitIndex, buttonSize, row.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				

			sortedList[CategoryCivilizations][1][tableid] = article;
			tableid = tableid + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[row.ShortDescription] = article;
			m_categorizedListOfArticles[(CategoryCivilizations * MAX_ENTRIES_PER_CATEGORY) + row.ID] = article;
		end
	end
	
	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryCivilizations][1], Alphabetically);
			
	-- next Leaders
	sortedList[CategoryCivilizations][2] = {};
	local tableid = 1;

	for row in GameInfo.Civilizations() do	
		if row.Playable == true or row.AIPlayable == true then
		--if row.Type ~= "CIVILIZATION_MINOR" and row.Type ~= "CIVILIZATION_ALIEN" and row.Type ~= "CIVILIZATION_NEUTRAL_PROXY" then
			local leader = nil;
			for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = row.Type} do
				leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
			end
			local article = {};
			local name = Locale.ConvertTextKey( leader.Description )
			article.entryName = name;
			article.entryID = row.ID + 1000;
			article.entryCategory = CategoryCivilizations;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( leader.PortraitIndex, buttonSize, leader.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				

			sortedList[CategoryCivilizations][2][tableid] = article;
			tableid = tableid + 1;
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[leader.Description] = article;
			m_categorizedListOfArticles[(CategoryCivilizations * MAX_ENTRIES_PER_CATEGORY) + row.ID + 1000] = article;
		end
	end
	
	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryCivilizations][2], Alphabetically);
					
end

CivilopediaCategory[CategoryQuests].PopulateList = function()
	sortedList[CategoryQuests] = {};
	local articlelist = sortedList[CategoryQuests];
		
	-- for each concept
	for thisConcept in GameInfo.Concepts() do
		if(thisConcept.CivilopediaHeaderType == "HEADER_QUESTS") then
			-- add an article to the list (localized name, unit tag, etc.)
			local article = {};
			local name = Locale.ConvertTextKey( thisConcept.Description )
			article.entryName = name;
			article.entryID = thisConcept.ID;
			article.entryCategory = CategoryQuests;
			article.InsertBefore = thisConcept.InsertBefore;
			article.InsertAfter = thisConcept.InsertAfter;
			article.Type = thisConcept.Type;

			table.insert(articlelist, article);
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[thisConcept.Description] = article;
			m_categorizedListOfArticles[(CategoryQuests * MAX_ENTRIES_PER_CATEGORY) + thisConcept.ID] = article;
		end
	end

	-- In order to maintain the original order as best as possible,
	-- we assign "InsertBefore" values to all items that lack any insert.
	for i = #articlelist, 1, -1 do
		local concept = articlelist[i];
		
		if(concept.InsertBefore == nil and concept.InsertAfter == nil) then
			for ii = i - 1, 1, -1 do
				local previousConcept = articlelist[ii];
				if(previousConcept.InsertBefore == nil and previousConcept.InsertAfter == nil) then
					concept.InsertAfter = previousConcept.Type;
					break;
				end
			end
		end
	end

	
	-- sort the articles by their dependencies.
	function DependencySort(articles)
		
		-- index articles by Topic
		local articlesByType= {};
		local dependencies = {};
		
		for i,v in ipairs(articles) do
			articlesByType[v.Type] = v;
			dependencies[v] = {};
		end
		
		for i,v in ipairs(articles) do
			
			local insertBefore = v.InsertBefore;
			if(insertBefore ~= nil) then
				local article = articlesByType[insertBefore];
				dependencies[article][v] = true;
			end
			
			local insertAfter = v.InsertAfter;
			if(insertAfter ~= nil) then
				local article = articlesByType[insertAfter];
				dependencies[v][article] = true;
			end
		end
		
		local sortedList = {};
		
		local articleCount = #articles;
		while(#sortedList < articleCount) do
			
			-- Attempt to find a node with 0 dependencies
			local article;
			for i,a in ipairs(articles) do
				if(dependencies[a] ~= nil and table.count(dependencies[a]) == 0) then
					article = a;
					break;
				end
			end
			
			if(article == nil) then
				print("Failed to sort articles topologically!! There are dependency cycles.");
				return nil;
			else
			
				-- Insert Node
				table.insert(sortedList, article);
				
				-- Remove node
				dependencies[article] = nil;
				for a,d in pairs(dependencies) do
					d[article] = nil;
				end
			end
		end
		
		return sortedList;
	end
		
	local oldList = articlelist;
	local newList = DependencySort(articlelist);

	if(newList == nil) then
		newList = oldList;
	else
		newList.headingOpen = false;
	end
	
	articlelist = newList;	
end

CivilopediaCategory[CategoryTerrain].PopulateList = function()
	-- add the instances of the Terrain and Features entries
	
	sortedList[CategoryTerrain] = {};
	
	-- first Specialists
	sortedList[CategoryTerrain][1] = {};
	local tableid = 1;

	for row in GameInfo.Terrains() do	
		if not row.GraphicalOnly then
			local article = {};
			local name = Locale.ConvertTextKey( row.Description )
			article.entryName = name;
			article.entryID = row.ID;
			article.entryCategory = CategoryTerrain;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( row.PortraitIndex, buttonSize, row.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				

			sortedList[CategoryTerrain][1][tableid] = article;
			tableid = tableid + 1;
		
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[row.Description] = article;
			m_categorizedListOfArticles[(CategoryTerrain * MAX_ENTRIES_PER_CATEGORY) + row.ID] = article; -- add a fudge factor
		end
	end
	
	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryTerrain][1], Alphabetically);
			
	-- next Features
	sortedList[CategoryTerrain][2] = {};
	tableid = 1;

	for row in GameInfo.Features() do	
		if not row.GraphicalOnly then
			local article = {};
			local name = Locale.ConvertTextKey( row.Description )
			article.entryName = name;
			article.entryID = row.ID + 1000;
			article.entryCategory = CategoryTerrain;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( row.PortraitIndex, buttonSize, row.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				

			sortedList[CategoryTerrain][2][tableid] = article;
			tableid = tableid + 1;
		
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[row.Description] = article;
			m_categorizedListOfArticles[(CategoryTerrain * MAX_ENTRIES_PER_CATEGORY) + row.ID + 1000] = article; -- add a fudge factor
		end
	end

	-- now for the fake features (river and lake)
	for row in GameInfo.FakeFeatures() do	
		if( row.DecorationOnly == false ) then
			local article = {};
			local name = Locale.ConvertTextKey( row.Description )
			article.entryName = name;
			article.entryID = row.ID + 2000;
			article.entryCategory = CategoryTerrain;
			article.tooltipTextureOffset, article.tooltipTexture = IconLookup( row.PortraitIndex, buttonSize, row.IconAtlas );				
			if not article.tooltipTextureOffset then
				article.tooltipTexture = defaultErrorTextureSheet;
				article.tooltipTextureOffset = nullOffset;
			end				

			sortedList[CategoryTerrain][2][tableid] = article;
			tableid = tableid + 1;
		
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[row.Description] = article;
			m_categorizedListOfArticles[(CategoryTerrain * MAX_ENTRIES_PER_CATEGORY) + row.ID + 2000] = article; -- add a fudge factor
		end
	end

	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryTerrain][2], Alphabetically);
					
end

CivilopediaCategory[CategoryResources].PopulateList = function()
	-- add the instances of the resource entries
	
	sortedList[CategoryResources] = {};
	
	-- for each type of resource

	for resourceClassInfo in GameInfo.ResourceClasses() do
		
		sortedList[CategoryResources][resourceClassInfo.ID] = {};
		local tableid = 1;
	
		-- for each type of resource
 		for resource in GameInfo.Resources( "ResourceClassType = '" .. resourceClassInfo.Type .. "'" ) do

			if resource.ShowInCivilopedia then
				-- add a tech entry to a list (localized name, tag, etc.)
 				local article = {};
 				local name = Locale.ConvertTextKey( resource.Description )
 				article.entryName = name;
 				article.entryID = resource.ID;
				article.entryCategory = CategoryResources;
				article.tooltipTextureOffset, article.tooltipTexture = IconLookup( resource.PortraitIndex, buttonSize, resource.IconAtlas );				
				if not article.tooltipTextureOffset then
					article.tooltipTexture = defaultErrorTextureSheet;
					article.tooltipTextureOffset = nullOffset;
				end				
			
				sortedList[CategoryResources][resourceClassInfo.ID][tableid] = article;
				tableid = tableid + 1;
			
				-- index by various keys
				searchableList[Locale.ToLower(name)] = article;
				searchableTextKeyList[resource.Description] = article;
				m_categorizedListOfArticles[(CategoryResources * MAX_ENTRIES_PER_CATEGORY) + resource.ID] = article;
			end
		end

		-- sort this list alphabetically by localized name
		table.sort(sortedList[CategoryResources][resourceClassInfo.ID], Alphabetically);
	
	end
					
end

CivilopediaCategory[CategoryImprovements].PopulateList = function()
	-- add the instances of the improvement entries
	
	sortedList[CategoryImprovements] = {};
	
	sortedList[CategoryImprovements][1] = {}; -- there is only one section (for now)
	local tableid = 1;
	
	-- for each improvement
	for row in GameInfo.Improvements() do	
		if not row.GraphicalOnly then
			-- Ignore entries without a civilopedia entry (e.g., "Partial" improvments omitted in BE or they appear twice in list.
			if ( row.Civilopedia ~= nil ) then 
				-- add an article to the list (localized name, unit tag, etc.)
				local article = {};
				local name = Locale.ConvertTextKey( row.Description );
				article.entryName = name;
				article.entryID = row.ID;
				article.entryCategory = CategoryImprovements;
				article.tooltipTextureOffset, article.tooltipTexture = IconLookup( row.PortraitIndex, buttonSize, row.IconAtlas );				
				if not article.tooltipTextureOffset then
					article.tooltipTexture = defaultErrorTextureSheet;
					article.tooltipTextureOffset = nullOffset;
				end				
			
				sortedList[CategoryImprovements][1][tableid] = article;
				tableid = tableid + 1;
			
				-- index by various keys
				searchableList[Locale.ToLower(name)] = article;
				searchableTextKeyList[row.Description] = article;
				m_categorizedListOfArticles[(CategoryImprovements * MAX_ENTRIES_PER_CATEGORY) + row.ID] = article;
			end
		end
	end
	
	--add roads and magrail
	for row in GameInfo.Routes() do
		local article = {};
		local name = Locale.ConvertTextKey( row.Description );
		article.entryName = name;
		article.entryID = row.ID + 1000;
		article.entryCategory = CategoryImprovements;
		article.tooltipTextureOffset, article.tooltipTexture = IconLookup( row.PortraitIndex, buttonSize, row.IconAtlas );				
		if not article.tooltipTextureOffset then
			article.tooltipTexture = defaultErrorTextureSheet;
			article.tooltipTextureOffset = nullOffset;
		end				
		
		sortedList[CategoryImprovements][1][tableid] = article;
		tableid = tableid + 1;
		
		-- index by various keys
		searchableList[Locale.ToLower(name)] = article;
		searchableTextKeyList[row.Description] = article;
		m_categorizedListOfArticles[(CategoryImprovements * MAX_ENTRIES_PER_CATEGORY) + 1000 + row.ID] = article;
	end

	-- sort this list alphabetically by localized name
	table.sort(sortedList[CategoryImprovements][1], Alphabetically);
			
end

CivilopediaCategory[CategoryAffinities].PopulateList = function()
	sortedList[CategoryAffinities] = {};
	local articlelist = sortedList[CategoryAffinities];
		
	-- for each concept
	for thisConcept in GameInfo.Concepts() do
		if(thisConcept.CivilopediaHeaderType == "HEADER_AFFINITY") then
			-- add an article to the list (localized name, unit tag, etc.)
			local article = {};
			local name = Locale.ConvertTextKey( thisConcept.Description )
			article.entryName = name;
			article.entryID = thisConcept.ID;
			article.entryCategory = CategoryAffinities;
			article.InsertBefore = thisConcept.InsertBefore;
			article.InsertAfter = thisConcept.InsertAfter;
			article.Type = thisConcept.Type;

			table.insert(articlelist, article);
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[thisConcept.Description] = article;
			m_categorizedListOfArticles[(CategoryAffinities * MAX_ENTRIES_PER_CATEGORY) + thisConcept.ID] = article;
		end
	end
	
		-- In order to maintain the original order as best as possible,
	-- we assign "InsertBefore" values to all items that lack any insert.
	for i = #articlelist, 1, -1 do
		local concept = articlelist[i];
		
		if(concept.InsertBefore == nil and concept.InsertAfter == nil) then
			for ii = i - 1, 1, -1 do
				local previousConcept = articlelist[ii];
				if(previousConcept.InsertBefore == nil and previousConcept.InsertAfter == nil) then
					concept.InsertAfter = previousConcept.Type;
					break;
				end
			end
		end
	end

	
	-- sort the articles by their dependencies.
	function DependencySort(articles)
		
		-- index articles by Topic
		local articlesByType= {};
		local dependencies = {};
		
		for i,v in ipairs(articles) do
			articlesByType[v.Type] = v;
			dependencies[v] = {};
		end
		
		for i,v in ipairs(articles) do
			
			local insertBefore = v.InsertBefore;
			if(insertBefore ~= nil) then
				local article = articlesByType[insertBefore];
				dependencies[article][v] = true;
			end
			
			local insertAfter = v.InsertAfter;
			if(insertAfter ~= nil) then
				local article = articlesByType[insertAfter];
				dependencies[v][article] = true;
			end
		end
		
		local sortedList = {};
		
		local articleCount = #articles;
		while(#sortedList < articleCount) do
			
			-- Attempt to find a node with 0 dependencies
			local article;
			for i,a in ipairs(articles) do
				if(dependencies[a] ~= nil and table.count(dependencies[a]) == 0) then
					article = a;
					break;
				end
			end
			
			if(article == nil) then
				print("Failed to sort articles topologically!! There are dependency cycles.");
				return nil;
			else
			
				-- Insert Node
				table.insert(sortedList, article);
				
				-- Remove node
				dependencies[article] = nil;
				for a,d in pairs(dependencies) do
					d[article] = nil;
				end
			end
		end
		
		return sortedList;
	end
		
	local oldList = articlelist;
	local newList = DependencySort(articlelist);

	if(newList == nil) then
		newList = oldList;
	else
		newList.headingOpen = false;
	end
	
	articlelist = newList;			
end

CivilopediaCategory[CategoryStations].PopulateList = function()
	sortedList[CategoryStations] = {};
	local articlelist = sortedList[CategoryStations];
		
	-- for each concept
	for thisConcept in GameInfo.Concepts() do
		if(thisConcept.CivilopediaHeaderType == "HEADER_STATIONS") then
			-- add an article to the list (localized name, unit tag, etc.)
			local article = {};
			local name = Locale.ConvertTextKey( thisConcept.Description )
			article.entryName = name;
			article.entryID = thisConcept.ID;
			article.entryCategory = CategoryStations;
			article.InsertBefore = thisConcept.InsertBefore;
			article.InsertAfter = thisConcept.InsertAfter;
			article.Type = thisConcept.Type;

			table.insert(articlelist, article);
			
			-- index by various keys
			searchableList[Locale.ToLower(name)] = article;
			searchableTextKeyList[thisConcept.Description] = article;
			m_categorizedListOfArticles[(CategoryStations * MAX_ENTRIES_PER_CATEGORY) + thisConcept.ID] = article;
		end
	end
	
		-- In order to maintain the original order as best as possible,
	-- we assign "InsertBefore" values to all items that lack any insert.
	for i = #articlelist, 1, -1 do
		local concept = articlelist[i];
		
		if(concept.InsertBefore == nil and concept.InsertAfter == nil) then
			for ii = i - 1, 1, -1 do
				local previousConcept = articlelist[ii];
				if(previousConcept.InsertBefore == nil and previousConcept.InsertAfter == nil) then
					concept.InsertAfter = previousConcept.Type;
					break;
				end
			end
		end
	end

	
	-- sort the articles by their dependencies.
	function DependencySort(articles)
		
		-- index articles by Topic
		local articlesByType= {};
		local dependencies = {};
		
		for i,v in ipairs(articles) do
			articlesByType[v.Type] = v;
			dependencies[v] = {};
		end
		
		for i,v in ipairs(articles) do
			
			local insertBefore = v.InsertBefore;
			if(insertBefore ~= nil) then
				local article = articlesByType[insertBefore];
				dependencies[article][v] = true;
			end
			
			local insertAfter = v.InsertAfter;
			if(insertAfter ~= nil) then
				local article = articlesByType[insertAfter];
				dependencies[v][article] = true;
			end
		end
		
		local sortedList = {};
		
		local articleCount = #articles;
		while(#sortedList < articleCount) do
			
			-- Attempt to find a node with 0 dependencies
			local article;
			for i,a in ipairs(articles) do
				if(dependencies[a] ~= nil and table.count(dependencies[a]) == 0) then
					article = a;
					break;
				end
			end
			
			if(article == nil) then
				print("Failed to sort articles topologically!! There are dependency cycles.");
				return nil;
			else
			
				-- Insert Node
				table.insert(sortedList, article);
				
				-- Remove node
				dependencies[article] = nil;
				for a,d in pairs(dependencies) do
					d[article] = nil;
				end
			end
		end
		
		return sortedList;
	end
		
	local oldList = articlelist;
	local newList = DependencySort(articlelist);

	if(newList == nil) then
		newList = oldList;
	else
		newList.headingOpen = false;
	end
	
	articlelist = newList;			
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function ResizeEtc()
	
	-- These top level pieces need processing in case a resolution change occurred.
	Controls.BackDrop:ReprocessAnchoring();
	Controls.MainBox:ReprocessAnchoring();
	Controls.MainBackground:ReprocessAnchoring();

	-- Determine size of the rest of the contents...

	Controls.FFTextStack:CalculateSize();
	Controls.NarrowStack:CalculateSize();
	Controls.BBTextStack:ReprocessAnchoring();
	Controls.BBTextStack:CalculateSize();
	Controls.FFTextStack:ReprocessAnchoring();
	Controls.NarrowStack:ReprocessAnchoring();
	Controls.WideStack:CalculateSize();
	Controls.WideStack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();
	
	-- ??TRON: Eventually remove once ControlBase auto-resizes based on parent/full as long as no explicit SetSize calls are made.
	-- Resize the viewable area, calculate internals, then calculate external visible area/scrollbar:
	-- adjust the various parts to fit the screen size
	local _, screenSizeY = UIManager:GetScreenSizeVal(); -- Controls.BackDrop:GetSize();

	Controls.LeftScrollPanel:SetSizeY( screenSizeY - 298 );
	Controls.ListOfArticles:CalculateSize();	
	Controls.LeftScrollPanel:CalculateInternalSize();

	Controls.ScrollPanel:SetSizeY( screenSizeY - 372 );	
	Controls.ScrollPanel:CalculateInternalSize();

	Controls.MainVerticalContentDivider:SetSizeY( screenSizeY - 298 );
	Controls.MainBackground:SetSizeY( screenSizeY - 208 );
end

--------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

CivilopediaCategory[CategoryMain].DisplayHomePage = function()

	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey("TXT_KEY_PEDIA_HOME_PAGE_LABEL") );	
	
	Controls.PortraitFrame:SetHide( true );
	
	g_BBTextManager:DestroyInstances();
	
	--Welcome and insert 1st manual paragraph
	UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_HOME_PAGE_BLURB_TEXT" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );

	--How to use the Pedia	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_HOME_PAGE_HELP_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_HOME_PAGE_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end		

	Controls.BBTextStack:SetHide( false );	
	ResizeEtc();
end;

CivilopediaCategory[CategoryConcepts].DisplayHomePage = function()

	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_GAME_CONCEPT_PAGE_LABEL" ));	
	
	Controls.PortraitFrame:SetHide( true );
	
	UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_GCONCEPTS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();

	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_GAME_CONCEPT_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_GAME_CONCEPT_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	
	Controls.BBTextStack:SetHide( false );
	
	--Did you know fact/tip of the day? Can be taken from rando advisor text.  Or link to random page or modding
	ResizeEtc();
end;

CivilopediaCategory[CategoryTech].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TECH_PAGE_LABEL" ));	
	
	local portraitIndex = 48;
	local portraitAtlas = "TECH_ATLAS_1";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Technologies ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_TECHS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
	
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TECH_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TECHNOLOGIES_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryUnits].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_UNITS_PAGE_LABEL" ));	
	
	local portraitIndex = 26;
	local portraitAtlas = "UNIT_ATLAS_1";
		
	for row in DB.Query("SELECT ID from Units  ORDER By Random() LIMIT 1") do
		portraitIndex, portraitAtlas = UI.GetUnitPortraitIcon(row.ID);
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_UNITS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
	
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_UNITS_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_UNITS_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryUpgrades].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_UPGRADES_HEADING1_TITLE" ));	
	
	local portraitIndex = 16;
	local portraitAtlas = "PROMOTION_ATLAS";

	for row in DB.Query("SELECT PortraitIndex, IconAtlas from UnitPerks ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_PROMOTIONS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_UPGRADES_HEADING1_TITLE" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_PROMOTIONS_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryBuildings].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_BUILDINGS_PAGE_LABEL" ));	
	
	local portraitIndex = 24;
	local portraitAtlas = "BW_ATLAS_1";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Buildings where WonderSplashImage IS NULL ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_BUILDINGS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_BUILDINGS_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_BUILDINGS_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryWonders].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_WONDERS_PAGE_LABEL" ));	
	
	local portraitIndex = 2;
	local portraitAtlas = "BW_ATLAS_2";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Buildings Where WonderSplashImage IS NOT NULL ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_WONDERS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
	
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_WONDERS_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_WONDERS_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryVirtues].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_POLICIES_PAGE_LABEL" ));	
	
	local portraitIndex = 25;
	local portraitAtlas = "POLICY_ATLAS";
		--
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Policies Where IconAtlas IS NOT NULL ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
		UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_POLICIES" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	else
		Controls.PortraitFrame:SetHide( true );
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_POLICIES" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	end
	
	
	g_BBTextManager:DestroyInstances();
	
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_POLICIES_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_SOCIAL_POL_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryEspionage].DisplayHomePage = function()
	ClearArticle();
	
	local espionageLabel = "TXT_KEY_PEDIA_ESPIONAGE_PAGE_LABEL";
	Controls.ArticleID:SetText( Locale.ConvertTextKey( espionageLabel ));	

	Controls.PortraitFrame:SetHide( true );
	UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_ESPIONAGE" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
		
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( espionageLabel ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_SPEC_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryCivilizations].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_CIVILIZATIONS_PAGE_LABEL" ));	
	
	local portraitIndex = 7;
	local portraitAtlas = "LEADER_ATLAS";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Leaders where Type <> \"LEADER_ALIEN\" ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_CIVS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_CIVILIZATIONS_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_CIVS_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryQuests].DisplayHomePage = function()
	ClearArticle();
	
	local articlelabel = Locale.Lookup("TXT_KEY_PEDIA_QUESTS_PAGE_LABEL");
	Controls.ArticleID:SetText(articlelabel);	

	Controls.PortraitFrame:SetHide( true );
	UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_QUESTS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
		
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText(articlelabel);
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUESTS_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryTerrain].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_PAGE_LABEL" ));	
	
	local portraitIndex = 9;
	local portraitAtlas = "TERRAIN_ATLAS";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Terrains ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_TERRAIN" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );	
	end	
	Controls.BBTextStack:SetHide( false );
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_FEATURES_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_FEATURES_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end
	ResizeEtc();
end;

CivilopediaCategory[CategoryResources].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCES_PAGE_LABEL" ));	
	
	local portraitIndex = 6;
	local portraitAtlas = "RESOURCE_ATLAS";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Resources ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_RESOURCES" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCES_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCES_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryImprovements].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPROVEMENTS_PAGE_LABEL" ));	
	
	--eventually make random?
	local portraitIndex = 1;
	local portraitAtlas = "BW_ATLAS_1";
		
	for row in DB.Query("SELECT PortraitIndex, IconAtlas from Improvements ORDER By Random() LIMIT 1") do
		portraitIndex = row.PortraitIndex;
		portraitAtlas = row.IconAtlas;
	end	
	
	if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end
	
	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_IMPROVEMENTS" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPROVEMENTS_PAGE_LABEL" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPROVEMENT_HELP_TEXT" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryAffinities].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_AFFINITIES_PAGE_LABEL" ));	
	
	local iconIndex;
	local iconAtlas;

	for row in DB.Query("SELECT IconIndex, IconAtlas from Affinity_Types ORDER By Random() LIMIT 1") do
		iconIndex = row.IconIndex;
		iconAtlas = row.IconAtlas;
	end	
	
	if IconHookup( iconIndex, portraitSize, iconAtlas, Controls.Portrait ) then
		Controls.PortraitFrame:SetHide( false );
	else
		Controls.PortraitFrame:SetHide( true );
	end

	UpdateTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_QUOTE_BLOCK_AFFINITIES" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_AFFINITIES_HOMEPAGE_LABEL1" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_AFFINITIES_HOMEPAGE_TEXT1" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;

CivilopediaCategory[CategoryStations].DisplayHomePage = function()
	ClearArticle();
	Controls.ArticleID:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_STATIONS_PAGE_LABEL" ));	
	
	Controls.PortraitFrame:SetHide(true);
	
	UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_STATIONS_HOMEPAGE_BLURB" ), Controls.HomePageBlurbLabel, Controls.HomePageBlurbInnerFrame, Controls.HomePageBlurbFrame );
	
	g_BBTextManager:DestroyInstances();
			
	--Basic Sectional Infos	
	local thisBBTextInstance = g_BBTextManager:GetInstance();
	if thisBBTextInstance then
		thisBBTextInstance.BBTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_STATIONS_HOMEPAGE_LABEL1" ));
		UpdateSuperWideTextBlock( Locale.ConvertTextKey( "TXT_KEY_PEDIA_STATIONS_HOMEPAGE_TEXT1" ), thisBBTextInstance.BBTextLabel, thisBBTextInstance.BBTextInnerFrame, thisBBTextInstance.BBTextFrame );
	end	
	Controls.BBTextStack:SetHide( false );
	ResizeEtc();
end;



--------------------------------------------------------------------------------------------------------
-- a few handy-dandy helper functions
--------------------------------------------------------------------------------------------------------

-- put text into a text block and resize the block
function UpdateTextBlock( localizedString, label, innerFrame, outerFrame )
	local contentSize;
	local frameSize = {};
	label:SetWrapWidth(wideLabelWrapWidth);
	label:SetText( localizedString );
	contentSize = label:GetSize();
	frameSize.x = wideInnerFrameWidth;
	frameSize.y = contentSize.y + textPaddingFromInnerFrame;
	innerFrame:SetSize( frameSize );
	frameSize.x = wideOuterFrameWidth;
	frameSize.y = contentSize.y + textPaddingFromInnerFrame - offsetsBetweenFrames;
	outerFrame:SetSize( frameSize );
	outerFrame:SetHide( false );
end

function UpdateNarrowTextBlock( localizedString, label, innerFrame, outerFrame )
	local contentSize;
	local frameSize = {};
	label:SetWrapWidth(narrowLabelWrapWidth);
	label:SetText( localizedString );
	contentSize = label:GetSize();
	frameSize.x = narrowInnerFrameWidth;
	frameSize.y = contentSize.y + textPaddingFromInnerFrame;
	innerFrame:SetSize( frameSize );
	frameSize.x = narrowOuterFrameWidth;
	frameSize.y = contentSize.y + textPaddingFromInnerFrame - offsetsBetweenFrames;
	outerFrame:SetSize( frameSize );
	outerFrame:SetHide( false );
end

function UpdateSuperWideTextBlock( localizedString, label, innerFrame, outerFrame )
	local contentSize;
	local frameSize = {};
	label:SetWrapWidth(superWideLabelWrapWidth);
	label:SetText( localizedString );
	contentSize = label:GetSize();
	frameSize.x = superWideInnerFrameWidth;
	frameSize.y = contentSize.y + textPaddingFromInnerFrame;
	innerFrame:SetSize( frameSize );
	frameSize.x = superWideOuterFrameWidth;
	frameSize.y = contentSize.y + textPaddingFromInnerFrame - offsetsBetweenFrames;
	outerFrame:SetSize( frameSize );
	outerFrame:SetHide( false );
end

function UpdateButtonFrame( numButtonsAdded, innerFrame, outerFrame )
	if numButtonsAdded > 0 then
		local frameSize = {};
		local h = (math.floor((numButtonsAdded - 1) / numberOfButtonsPerRow) + 1) * buttonSize + buttonPaddingTimesTwo;
		frameSize.x = narrowInnerFrameWidth;
		frameSize.y = h;
		innerFrame:SetSize( frameSize );
		frameSize.x = narrowOuterFrameWidth;
		frameSize.y = h - offsetsBetweenFrames;
		outerFrame:SetSize( frameSize );
		outerFrame:SetHide( false );
	end
end	

function UpdateSmallButton( buttonAdded, image, button, textureSheet, textureOffset, category, localizedText, buttonId )
	
	if(textureSheet ~= nil) then
		image:SetTexture( textureSheet );
	end
	
	if(textureOffset ~= nil) then
		image:SetTextureOffset( textureOffset );	
	end
	
	button:SetOffsetVal( (buttonAdded % numberOfButtonsPerRow) * buttonSize + buttonPadding, math.floor(buttonAdded / numberOfButtonsPerRow) * buttonSize + buttonPadding );				
	button:SetToolTipString( localizedText );
	
	if(category ~= nil) then
		button:SetVoids( buttonId, addToList );
		button:RegisterCallback( Mouse.eLClick, CivilopediaCategory[category].SelectArticle );
	end
end

-- this will need to be enhanced to look at the current language
function TagExists( tag )
	return Locale.HasTextKey(tag);
end


-- ===========================================================================
--	First page Index/TOC selects categories, much like buttons across the
--	top of the screen.
-- ===========================================================================
CivilopediaCategory[CategoryMain].SelectArticle = function( pageID, shouldAddToList )
	ClearArticle();	
	SetSelectedCategory( pageID, shouldAddToList );
	ResizeEtc();
end


-- ===========================================================================
--	Add a topic to the back/forward navigation history.
-- ===========================================================================
function AddToNavigationHistory( categoryIndex, itemID )
	m_historyCurrentIndex = m_historyCurrentIndex + 1;
	m_listOfTopicsViewed[m_historyCurrentIndex] = m_categorizedListOfArticles[(categoryIndex * MAX_ENTRIES_PER_CATEGORY) + itemID];
	for i = m_historyCurrentIndex + 1, m_endTopic, 1 do
		m_listOfTopicsViewed[i] = nil;
	end
	m_endTopic = m_historyCurrentIndex;
end

-- ===========================================================================
CivilopediaCategory[CategoryConcepts].SelectArticle = function( conceptID, shouldAddToList )
	print("CivilopediaCategory[CategoryConcepts].SelectArticle");
	if m_selectedCategory ~= CategoryConcepts then
		SetSelectedCategory(CategoryConcepts, dontAddToList );
	end
	
	ClearArticle();
		
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryConcepts, conceptID );
	end
	
	if conceptID ~= -1 then
		local thisConcept = GameInfo.Concepts[conceptID];
		
		if thisConcept then
		
			-- update the name
			local name = Locale.ConvertTextKey( thisConcept.Description ); 	
			Controls.ArticleID:SetText( name );
			
			-- portrait
			
			-- update the summary
			if thisConcept.Summary then
				UpdateSuperWideTextBlock( Locale.ConvertTextKey( thisConcept.Summary ), Controls.SummaryLabel, Controls.SummaryInnerFrame, Controls.SummaryFrame );
			end
			
			-- related images
			
			-- related concepts		
		end

	end	

	ResizeEtc();
end

-- ===========================================================================
CivilopediaCategory[CategoryTech].SelectArticle = function( techID, shouldAddToList )
	print("CivilopediaCategory[CategoryTech].SelectArticle");

	if m_selectedCategory ~= CategoryTech then
		SetSelectedCategory(CategoryTech, dontAddToList );
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryTech, techID );
	end
	
	if techID ~= -1 then
		local thisTech = GameInfo.Technologies[techID];
					
		local name = Locale.ConvertTextKey( thisTech.Description ); 	
		Controls.ArticleID:SetText( name );

		-- if we have one, update the tech picture
		if IconHookup( thisTech.PortraitIndex, portraitSize, thisTech.IconAtlas, Controls.Portrait ) then
			Controls.PortraitFrame:SetHide( false );
		else
			Controls.PortraitFrame:SetHide( true );
		end
		
		-- update the cost
		Controls.CostFrame:SetHide( false );

		local cost = thisTech.Cost;
		if(Game ~= nil) then
			local pPlayer = Players[Game.GetActivePlayer()];
			local pTeam = Teams[pPlayer:GetTeam()];
			local pTeamTechs = pTeam:GetTeamTechs();
			cost = pTeamTechs:GetResearchCost(techID);		
		end

		if (cost > 0) then
			Controls.CostLabel:SetText( tostring(cost).." [ICON_RESEARCH]" );
		else
			Controls.CostLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_FREE" ) );
		end
		
 		local contentSize;
 		local frameSize = {};
		local buttonAdded = 0;

		local techType = thisTech.Type;
		local condition = "TechType = '" .. techType .. "'";
		local prereqCondition = "PrereqTech = '" .. techType .. "'";
		local otherPrereqCondition = "TechPrereq = '" .. techType .. "'";
		local revealCondition = "TechReveal = '" .. techType .. "'";

		-- update the prereq techs
		g_PrereqTechManager:DestroyInstances();
		buttonAdded = 0;
		for row in GameInfo.Technology_PrereqTechs( condition ) do
			local prereq = GameInfo.Technologies[row.PrereqTech];
			local thisPrereqInstance = g_PrereqTechManager:GetInstance();
			if thisPrereqInstance then
				local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
				if textureOffset == nil then
					textureSheet = defaultErrorTextureSheet;
					textureOffset = nullOffset;
				end				
				UpdateSmallButton( buttonAdded, thisPrereqInstance.PrereqTechImage, thisPrereqInstance.PrereqTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
				buttonAdded = buttonAdded + 1;
			end			
		end
		UpdateButtonFrame( buttonAdded, Controls.PrereqTechInnerFrame, Controls.PrereqTechFrame );

		-- update the leads to techs
		g_LeadsToTechManager:DestroyInstances();
		buttonAdded = 0;
		for row in GameInfo.Technology_PrereqTechs( prereqCondition ) do
			local leadsTo = GameInfo.Technologies[row.TechType];
			local thisLeadsToInstance = g_LeadsToTechManager:GetInstance();
			if thisLeadsToInstance then
				local textureOffset, textureSheet = IconLookup( leadsTo.PortraitIndex, buttonSize, leadsTo.IconAtlas );				
				if textureOffset == nil then
					textureSheet = defaultErrorTextureSheet;
					textureOffset = nullOffset;
				end				
				UpdateSmallButton( buttonAdded, thisLeadsToInstance.LeadsToTechImage, thisLeadsToInstance.LeadsToTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( leadsTo.Description ), leadsTo.ID );
				buttonAdded = buttonAdded + 1;
			end			
		end
		-- update the units unlocked
		g_UnlockedUnitsManager:DestroyInstances();
		buttonAdded = 0;
		for thisUnitInfo in GameInfo.Units( prereqCondition ) do
			if thisUnitInfo.ShowInPedia then
				local thisUnitInstance = g_UnlockedUnitsManager:GetInstance();
				if thisUnitInstance then		
					local portraitIndex, iconAtlas  = UI.GetUnitPortraitIcon( thisUnitInfo.ID );
					local textureOffset, textureSheet = IconLookup( portraitIndex, buttonSize, iconAtlas );	
					UpdateSmallButton( buttonAdded, thisUnitInstance.UnlockedUnitImage, thisUnitInstance.UnlockedUnitButton, textureSheet, textureOffset, CategoryUnits, Locale.ConvertTextKey( thisUnitInfo.Description ), thisUnitInfo.ID );
					buttonAdded = buttonAdded + 1;
				end
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.UnlockedUnitsInnerFrame, Controls.UnlockedUnitsFrame );
		
		-- update the buildings unlocked
		g_UnlockedBuildingsManager:DestroyInstances();
		buttonAdded = 0;
		for thisBuildingInfo in GameInfo.Buildings( prereqCondition ) do
			local thisBuildingInstance = g_UnlockedBuildingsManager:GetInstance();
			if thisBuildingInstance then

				if not IconHookup( thisBuildingInfo.PortraitIndex, buttonSize, thisBuildingInfo.IconAtlas, thisBuildingInstance.UnlockedBuildingImage ) then
					thisBuildingInstance.UnlockedBuildingImage:SetTexture( defaultErrorTextureSheet );
					thisBuildingInstance.UnlockedBuildingImage:SetTextureOffset( nullOffset );
				end

				--move this button
				thisBuildingInstance.UnlockedBuildingButton:SetOffsetVal( (buttonAdded % numberOfButtonsPerRow) * buttonSize + buttonPadding, math.floor(buttonAdded / numberOfButtonsPerRow) * buttonSize + buttonPadding );
				
				thisBuildingInstance.UnlockedBuildingButton:SetToolTipString( Locale.ConvertTextKey( thisBuildingInfo.Description ) );
				thisBuildingInstance.UnlockedBuildingButton:SetVoids( thisBuildingInfo.ID, addToList );
				local thisBuildingClass = GameInfo.BuildingClasses[thisBuildingInfo.BuildingClass];
				if thisBuildingClass.MaxGlobalInstances > 0 or (thisBuildingClass.MaxPlayerInstances == 1 and thisBuildingInfo.SpecialistCount == 0) or thisBuildingClass.MaxTeamInstances > 0 then
					thisBuildingInstance.UnlockedBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectArticle );
				else
					thisBuildingInstance.UnlockedBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].SelectArticle );
				end
				buttonAdded = buttonAdded + 1;
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.UnlockedBuildingsInnerFrame, Controls.UnlockedBuildingsFrame );
		
		-- update the projects unlocked
		g_UnlockedProjectsManager:DestroyInstances();
		buttonAdded = 0;
		for thisProjectInfo in GameInfo.Projects( otherPrereqCondition ) do
		
			local bIgnore = projectsToIgnore[thisProjectInfo.Type];
			if(bIgnore ~= true) then
				local thisProjectInstance = g_UnlockedProjectsManager:GetInstance();
				if thisProjectInstance then
					local textureOffset, textureSheet = IconLookup( thisProjectInfo.PortraitIndex, buttonSize, thisProjectInfo.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisProjectInstance.UnlockedProjectImage, thisProjectInstance.UnlockedProjectButton, textureSheet, textureOffset, CategoryWonders, Locale.ConvertTextKey( thisProjectInfo.Description ), thisProjectInfo.ID + 1000);
					buttonAdded = buttonAdded + 1;
				end
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.UnlockedProjectsInnerFrame, Controls.UnlockedProjectsFrame );
		
		-- update the resources revealed
		g_RevealedResourcesManager:DestroyInstances();
		buttonAdded = 0;
		for revealedResource in GameInfo.Resources( revealCondition ) do
			local thisRevealedResourceInstance = g_RevealedResourcesManager:GetInstance();
			if thisRevealedResourceInstance then
				local textureOffset, textureSheet = IconLookup( revealedResource.PortraitIndex, buttonSize, revealedResource.IconAtlas );				
				if textureOffset == nil then
					textureSheet = defaultErrorTextureSheet;
					textureOffset = nullOffset;
				end				
				UpdateSmallButton( buttonAdded, thisRevealedResourceInstance.RevealedResourceImage, thisRevealedResourceInstance.RevealedResourceButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( revealedResource.Description ), revealedResource.ID );
				buttonAdded = buttonAdded + 1;
			end			
		end
		UpdateButtonFrame( buttonAdded, Controls.RevealedResourcesInnerFrame, Controls.RevealedResourcesFrame );

		-- update the build actions unlocked
		g_WorkerActionsManager:DestroyInstances();
		buttonAdded = 0;
		for thisBuildInfo in GameInfo.Builds( prereqCondition ) do
			local thisWorkerActionInstance = g_WorkerActionsManager:GetInstance();
			if thisWorkerActionInstance then
				local textureOffset, textureSheet = IconLookup( thisBuildInfo.IconIndex, buttonSize, thisBuildInfo.IconAtlas );				
				if textureOffset == nil then
					textureSheet = defaultErrorTextureSheet;
					textureOffset = nullOffset;
				end
				if thisBuildInfo.RouteType then
					UpdateSmallButton( buttonAdded, thisWorkerActionInstance.WorkerActionImage, thisWorkerActionInstance.WorkerActionButton, textureSheet, textureOffset, CategoryImprovements, Locale.ConvertTextKey( thisBuildInfo.Description ), GameInfo.Routes[thisBuildInfo.RouteType].ID + 1000 );
				elseif thisBuildInfo.ImprovementType then
					UpdateSmallButton( buttonAdded, thisWorkerActionInstance.WorkerActionImage, thisWorkerActionInstance.WorkerActionButton, textureSheet, textureOffset, CategoryImprovements, Locale.ConvertTextKey( thisBuildInfo.Description ), GameInfo.Improvements[thisBuildInfo.ImprovementType].ID );-- add fudge factor
				else -- we are a choppy thing
					UpdateSmallButton( buttonAdded, thisWorkerActionInstance.WorkerActionImage, thisWorkerActionInstance.WorkerActionButton, textureSheet, textureOffset, CategoryConcepts, Locale.ConvertTextKey( thisBuildInfo.Description ), GameInfo.Concepts["CONCEPT_WORKERS_CLEARINGLAND"].ID );-- add fudge factor
				end
				buttonAdded = buttonAdded + 1;
			end			
		end
		UpdateButtonFrame( buttonAdded, Controls.WorkerActionsInnerFrame, Controls.WorkerActionsFrame );

		-- Helper to get the Civiloepedia concept for an affinity.
		local GetConceptAffinity = function(affinityType)
			-- Check if there's a security project with this concept type
			for row in GameInfo.Affinity_Types{Type = affinityType} do
				return GameInfo.Concepts[ row.CivilopediaConcept ];
			end
			return nil;
		end

		-- Currently only supports one affinity, if the system ever grants multiple
		-- may want to use a stack of TextButtons.
		local affinityString   = "";
		local techAffinityPair = {};
		for techAffinityPair in GameInfo.Technology_Affinities() do
			local techType		= techAffinityPair.TechType;						
			if techType == thisTech.Type then
				local affinityType	= techAffinityPair.AffinityType;
				local affinity		= GameInfo.Affinity_Types[affinityType];				
				affinityString = affinityString .. affinity.IconString .. "[" .. affinity.ColorType .. "] " .. Locale.ConvertTextKey(affinity.Description) .. "[endcolor]";
				Controls.AffinitiesLabel:SetVoids( GetConceptAffinity(affinityType).ID , addToList );
				Controls.AffinitiesLabel:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryAffinities].SelectArticle );
				break;
			end
		end

		if ( affinityString ~= nil and affinityString ~= "" ) then
			Controls.AffinitiesFrame:SetHide( false );
			Controls.AffinitiesLabel:SetText( affinityString );
		else
			Controls.AffinitiesFrame:SetHide( true);
		end

		-- update the related articles
		Controls.RelatedArticlesFrame:SetHide( true ); -- todo: figure out how this should be implemented

		-- update the game info
		if (thisTech.Help) then
			UpdateTextBlock( Locale.ConvertTextKey( thisTech.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
		end

		-- update the quote
		if thisTech.Quote then
			UpdateTextBlock( Locale.ConvertTextKey( thisTech.Quote ), Controls.SilentQuoteLabel, Controls.SilentQuoteInnerFrame, Controls.SilentQuoteFrame );
		end

		--Controls.QuoteLabel:SetText( Locale.ConvertTextKey( thisTech.Quote ) );
		--contentSize = Controls.QuoteLabel:GetSize();
		--frameSize.x = wideInnerFrameWidth;
		--frameSize.y = contentSize.y + textPaddingFromInnerFrame + quoteButtonOffset;
		--Controls.QuoteInnerFrame:SetSize( frameSize );
		--frameSize.x = wideOuterFrameWidth;
		--frameSize.y = contentSize.y + textPaddingFromInnerFrame - offsetsBetweenFrames + quoteButtonOffset;
		--Controls.QuoteFrame:SetSize( frameSize );
		--Controls.QuoteFrame:SetHide( false );

		-- update the special abilites
		local abilitiesString = "";
		local numAbilities = 0;
		for row in GameInfo.Route_TechMovementChanges( condition ) do
			if numAbilities > 0 then
				 abilitiesString = abilitiesString .. "[NEWLINE]";
			end
			abilitiesString = abilitiesString .. Locale.ConvertTextKey("TXT_KEY_CIVILOPEDIA_SPECIALABILITIES_MOVEMENT", GameInfo.Routes[row.RouteType].Description);
			numAbilities = numAbilities + 1;
		end	
	
		for row in GameInfo.Improvement_TechYieldChanges( condition ) do
			if numAbilities > 0 then
				 abilitiesString = abilitiesString .. "[NEWLINE]";
			end
			abilitiesString = abilitiesString .. Locale.ConvertTextKey("TXT_KEY_CIVILOPEDIA_SPECIALABILITIES_YIELDCHANGES", GameInfo.Improvements[row.ImprovementType].Description, GameInfo.Yields[row.YieldType].IconString, GameInfo.Yields[row.YieldType].Description, row.Yield);
			numAbilities = numAbilities + 1;
		end	

		for row in GameInfo.Improvement_TechNoFreshWaterYieldChanges( condition ) do
			if numAbilities > 0 then
				 abilitiesString = abilitiesString .. "[NEWLINE]";
			end
			
			abilitiesString = abilitiesString .. Locale.ConvertTextKey("TXT_KEY_CIVILOPEDIA_SPECIALABILITIES_NOFRESHWATERYIELDCHANGES", GameInfo.Improvements[row.ImprovementType].Description, GameInfo.Yields[row.YieldType].Description, row.Yield );
			numAbilities = numAbilities + 1;
		end	

		for row in GameInfo.Improvement_TechFreshWaterYieldChanges( condition ) do
			if numAbilities > 0 then
				 abilitiesString = abilitiesString .. "[NEWLINE]";
			end
			abilitiesString = abilitiesString .. Locale.ConvertTextKey("TXT_KEY_CIVILOPEDIA_SPECIALABILITIES_FRESHWATERYIELDCHANGES", GameInfo.Improvements[row.ImprovementType].Description, GameInfo.Yields[row.YieldType].Description, row.Yield );
			numAbilities = numAbilities + 1;
		end	

		if thisTech.EmbarkedMoveChange > 0 then
			if numAbilities > 0 then
				 abilitiesString = abilitiesString .. "[NEWLINE]";
			end
			abilitiesString = abilitiesString .. Locale.ConvertTextKey( "TXT_KEY_ABLTY_FAST_EMBARK_STRING" );
			numAbilities = numAbilities + 1;
		end
	
		-- EMBARKATION now allowed by default, icon is no longer needed to indicate where it unlocks
		-- [DM 4-6-15]

		--if thisTech.AllowsEmbarking then
			--if numAbilities > 0 then
				 --abilitiesString = abilitiesString .. "[NEWLINE]";
			--end
			--abilitiesString = abilitiesString .. Locale.ConvertTextKey( "TXT_KEY_ALLOWS_EMBARKING" );
			--numAbilities = numAbilities + 1;
		--end
	
		--if thisTech.AllowsDefensiveEmbarking then
		--	if numAbilities > 0 then
		--		 abilitiesString = abilitiesString .. "[NEWLINE]";
		--	end
		--	abilitiesString = abilitiesString .. Locale.ConvertTextKey( "TXT_KEY_ABLTY_DEFENSIVE_EMBARK_STRING" );
		--	numAbilities = numAbilities + 1;
		--end
	
		--if thisTech.EmbarkedAllWaterPassage then
		--	if numAbilities > 0 then
		--		 abilitiesString = abilitiesString .. "[NEWLINE]";
		--	end
		--	abilitiesString = abilitiesString ..  Locale.ConvertTextKey( "TXT_KEY_ABLTY_OCEAN_EMBARK_STRING" );
		--	numAbilities = numAbilities + 1;
		--end
		
		if thisTech.BridgeBuilding then
			if numAbilities > 0 then
				 abilitiesString = abilitiesString .. "[NEWLINE]";
			end
			abilitiesString = abilitiesString .. Locale.ConvertTextKey( "TXT_KEY_ABLTY_BRIDGE_STRING" );
			numAbilities = numAbilities + 1;
		end

		if numAbilities > 0 then
			UpdateTextBlock( Locale.ConvertTextKey( abilitiesString ), Controls.AbilitiesLabel, Controls.AbilitiesInnerFrame, Controls.AbilitiesFrame );
		else
			Controls.AbilitiesFrame:SetHide( true );			
		end
		
		-- update the historical info
		if (thisTech.Civilopedia) then
			UpdateTextBlock( Locale.ConvertTextKey( thisTech.Civilopedia ), Controls.HistoryLabel, Controls.HistoryInnerFrame, Controls.HistoryFrame );
		end
		
		-- update the related images
		Controls.RelatedImagesFrame:SetHide( true );
		
	end
	
	ResizeEtc();

end

CivilopediaCategory[CategoryUnits].SelectArticle = function( unitID, shouldAddToList )
	print("CivilopediaCategory[CategoryUnits].SelectArticle");
	if m_selectedCategory ~= CategoryUnits then
		SetSelectedCategory(CategoryUnits, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryUnits, unitID );
	end
	
	if unitID ~= -1 then
		local thisUnit = GameInfo.Units[unitID];
					
		-- update the name
		local name = Locale.ConvertTextKey( thisUnit.Description ); 	
		Controls.ArticleID:SetText( name );

		local portraitIndex, portraitAtlas = UI.GetUnitPortraitIcon( thisUnit.ID );

		-- update the portrait
		if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
			Controls.PortraitFrame:SetHide( false );
		else
			Controls.PortraitFrame:SetHide( true );
		end

		-- update the cost
		Controls.CostFrame:SetHide( false );
		
		local costString = "";
		
		local cost = thisUnit.Cost;
--[[		
		local faithCost = thisUnit.FaithCost;
		
		if(Game and not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
			faithCost = Game.GetFaithCost(unitID);
		end
]]		
		if(Game ~= nil) then
			cost = Players[Game.GetActivePlayer()]:GetUnitProductionNeeded( unitID );
		end
	
--[[		
		if(cost == 1 and faithCost > 0) then
			costString = tostring(faithCost) .. " [ICON_PEACE]";
			
		elseif(cost > 0 and faithCost > 0) then
			costString = Locale.Lookup("TXT_KEY_PEDIA_A_OR_B", tostring(cost) .. " [ICON_PRODUCTION]", tostring(faithCost) .. " [ICON_PEACE");
		else
]]
			if(cost > 0) then
				costString = tostring(cost) .. " [ICON_PRODUCTION]";
--			elseif(faithCost > 0) then
--				costString = tostring(faithCost) .. " [ICON_PEACE]";
			else
				costString = Locale.Lookup("TXT_KEY_FREE");
				
				if(thisUnit.Type == "UNIT_SETTLER") then
					Controls.CostFrame:SetHide(true);
				end
			end
--		end
				
		Controls.CostLabel:SetText(costString);
		
		-- update the Combat value
		local combat = thisUnit.Combat;
		if combat > 0 then
			Controls.CombatLabel:SetText( tostring(combat).." [ICON_STRENGTH]" );
			Controls.CombatFrame:SetHide( false );
		end
		
		-- update the Ranged Combat value
		local rangedCombat = thisUnit.RangedCombat;
		if rangedCombat > 0 then
			Controls.RangedCombatLabel:SetText( tostring(rangedCombat).." [ICON_RANGE_STRENGTH]" );
			Controls.RangedCombatFrame:SetHide( false );
		end
		
		-- update the Ranged Combat value
		local rangedCombatRange = thisUnit.Range;
		if rangedCombatRange > 0 then
			Controls.RangedCombatRangeLabel:SetText( tostring(rangedCombatRange) .. " [ICON_ATTACK_RANGE]" );
			Controls.RangedCombatRangeFrame:SetHide( false );
		end
		
		

		local orbitalInfo = thisUnit.Orbital and GameInfo.OrbitalUnits[thisUnit.Orbital];
			
		-- update the Movement value
		local movementRange = thisUnit.Moves;
		if movementRange > 0 and not thisUnit.Immobile then
			Controls.MovementLabel:SetText( tostring(movementRange).." [ICON_MOVES]" );
			Controls.MovementFrame:SetHide( false );
		end

		if(orbitalInfo ~= nil) then
			Controls.OrbitalEffectRangeLabel:SetText(tostring(orbitalInfo.EffectRange) .. " [ICON_ORBITAL_RANGE]");
			Controls.OrbitalEffectRangeFrame:SetHide(false);

			-- If we're in game, query the modified value!
			local turnDuration = orbitalInfo.TurnDuration;
			if(Game) then
				local activePlayerID = Game.GetActivePlayer();
				local activePlayer = Players[activePlayerID];
				turnDuration = activePlayer:GetTurnsUnitAllowedInOrbit(thisUnit.ID, true);
			end

			local orbitalTurnDuration = tostring(turnDuration) .. " [ICON_ORBITAL_DURATION]";
			Controls.OrbitalTurnDurationLabel:SetText(orbitalTurnDuration);
			Controls.OrbitalTurnDurationFrame:SetHide(false);

		else
			Controls.OrbitalEffectRangeFrame:SetHide(true);
			Controls.OrbitalTurnDurationFrame:SetHide(true);
		end
		
 		local contentSize;
 		local frameSize = {};
		local buttonAdded = 0;
 		
 		-- update the free promotions
		--[[
		g_PromotionsManager:DestroyInstances();
		buttonAdded = 0;

		local condition = "UnitType = '" .. thisUnit.Type .. "'";
		for row in GameInfo.Unit_FreePromotions( condition ) do
			local promotion = GameInfo.UnitPromotions[row.PromotionType];
			if promotion then
				local thisPromotionInstance = g_PromotionsManager:GetInstance();
				if thisPromotionInstance then
					local textureOffset, textureSheet = IconLookup( promotion.PortraitIndex, buttonSize, promotion.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisPromotionInstance.PromotionImage, thisPromotionInstance.PromotionButton, textureSheet, textureOffset, CategoryUpgrades, Locale.ConvertTextKey( promotion.Description ), promotion.ID );
					buttonAdded = buttonAdded + 1;
				end
			end	
		end
		UpdateButtonFrame( buttonAdded, Controls.FreePromotionsInnerFrame, Controls.FreePromotionsFrame );
		--]]

		-- update the required resources
		Controls.RequiredResourcesLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_REQ_RESRC_LABEL" ) );
		g_RequiredResourcesManager:DestroyInstances();
		buttonAdded = 0;

		local condition = "UnitType = '" .. thisUnit.Type .. "'";

		for row in GameInfo.Unit_ResourceQuantityRequirements( condition ) do
			local requiredResource = GameInfo.Resources[row.ResourceType];
			if requiredResource then
				local thisRequiredResourceInstance = g_RequiredResourcesManager:GetInstance();
				if thisRequiredResourceInstance then
					local textureOffset, textureSheet = IconLookup( requiredResource.PortraitIndex, buttonSize, requiredResource.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisRequiredResourceInstance.RequiredResourceImage, thisRequiredResourceInstance.RequiredResourceButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( requiredResource.Description ), requiredResource.ID );
					buttonAdded = buttonAdded + 1;
				end
			end		
		end
		UpdateButtonFrame( buttonAdded, Controls.RequiredResourcesInnerFrame, Controls.RequiredResourcesFrame );

		-- update the prereq techs
		g_PrereqTechManager:DestroyInstances();
		buttonAdded = 0;

		if thisUnit.PrereqTech then
			local prereq = GameInfo.Technologies[thisUnit.PrereqTech];
			if prereq then
				local thisPrereqInstance = g_PrereqTechManager:GetInstance();
				if thisPrereqInstance then
					local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisPrereqInstance.PrereqTechImage, thisPrereqInstance.PrereqTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
					buttonAdded = buttonAdded + 1;
				end	
			end
		end	
		UpdateButtonFrame( buttonAdded, Controls.PrereqTechInnerFrame, Controls.PrereqTechFrame );

		-- update the obsolete techs
		g_ObsoleteTechManager:DestroyInstances();
		buttonAdded = 0;

		if thisUnit.ObsoleteTech then
			local obs = GameInfo.Technologies[thisUnit.ObsoleteTech];
			if obs then
				local thisTechInstance = g_ObsoleteTechManager:GetInstance();
				if thisTechInstance then
					local textureOffset, textureSheet = IconLookup( obs.PortraitIndex, buttonSize, obs.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisTechInstance.ObsoleteTechImage, thisTechInstance.ObsoleteTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( obs.Description ), obs.ID );
					buttonAdded = buttonAdded + 1;
				end	
			end
		end	
		UpdateButtonFrame( buttonAdded, Controls.ObsoleteTechInnerFrame, Controls.ObsoleteTechFrame );

		-- update the Upgrade units
		g_UpgradeManager:DestroyInstances();
		buttonAdded = 0;
		
		if(Game ~= nil) then
			local iUnitUpgrade = Game.GetUnitUpgradesTo(unitID);
			if iUnitUpgrade ~= nil and iUnitUpgrade ~= -1 then
				local obs = GameInfo.Units[iUnitUpgrade];
				if obs then
					local thisUpgradeInstance = g_UpgradeManager:GetInstance();
					if thisUpgradeInstance then
						local textureOffset, textureSheet = IconLookup( obs.PortraitIndex, buttonSize, obs.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisUpgradeInstance.UpgradeImage, thisUpgradeInstance.UpgradeButton, textureSheet, textureOffset, CategoryUnits, Locale.ConvertTextKey( obs.Description ), obs.ID );
						buttonAdded = buttonAdded + 1;
					end	
				end
			end	
		else
			for row in GameInfo.Unit_ClassUpgrades{UnitType = thisUnit.Type} do	
				local unitClass = GameInfo.UnitClasses[row.UnitClassType];
				local upgradeUnit = GameInfo.Units[unitClass.DefaultUnit];
				if (upgradeUnit) then
					local thisUpgradeInstance = g_UpgradeManager:GetInstance();
					if thisUpgradeInstance then
						local textureOffset, textureSheet = IconLookup( upgradeUnit.PortraitIndex, buttonSize, upgradeUnit.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisUpgradeInstance.UpgradeImage, thisUpgradeInstance.UpgradeButton, textureSheet, textureOffset, CategoryUnits, Locale.ConvertTextKey( upgradeUnit.Description ), upgradeUnit.ID );
						buttonAdded = buttonAdded + 1;
					end	
				end		
			end
		end
		
		UpdateButtonFrame( buttonAdded, Controls.UpgradeInnerFrame, Controls.UpgradeFrame );
		
		-- Are we a unique unit?  If so, who do I replace?
		local replacesUnitClass = {};
		local specificCivs = {};
		
		local classOverrideCondition = string.format("UnitType='%s' and CivilizationType <> 'CIVILIZATION_ALIEN' and CivilizationType <> 'CIVILIZATION_MINOR' and CivilizationType <> 'CIVILIZATION_NEUTRAL_PROXY'", thisUnit.Type);
		for row in GameInfo.Civilization_UnitClassOverrides(classOverrideCondition) do
			specificCivs[row.CivilizationType] = 1;
			replacesUnitClass[row.UnitClassType] = 1;
		end
		 	
		g_ReplacesManager:DestroyInstances();
		buttonAdded = 0;
		for unitClassType, _ in pairs(replacesUnitClass) do
			for replacedUnit in DB.Query("SELECT u.ID, u.Description, u.PortraitIndex, u.IconAtlas from Units as u inner join UnitClasses as uc on u.Type = uc.DefaultUnit where uc.Type = ?", unitClassType) do
				local thisUnitInstance = g_ReplacesManager:GetInstance();
				if thisUnitInstance then
					local textureOffset, textureSheet = IconLookup( replacedUnit.PortraitIndex, buttonSize, replacedUnit.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisUnitInstance.ReplaceImage, thisUnitInstance.ReplaceButton, textureSheet, textureOffset, CategoryUnits, Locale.ConvertTextKey( replacedUnit.Description ), replacedUnit.ID );
					buttonAdded = buttonAdded + 1;
				end
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.ReplacesInnerFrame, Controls.ReplacesFrame );

		g_CivilizationsManager:DestroyInstances();
		buttonAdded = 0;
		for civilizationType, _ in pairs(specificCivs) do
		
			local civ = GameInfo.Civilizations[civilizationType];
			if(civ ~= nil) then
				local thisCivInstance = g_CivilizationsManager:GetInstance();
				if thisCivInstance then
					local textureOffset, textureSheet = IconLookup( civ.PortraitIndex, buttonSize, civ.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisCivInstance.CivilizationImage, thisCivInstance.CivilizationButton, textureSheet, textureOffset, CategoryCivilizations, Locale.ConvertTextKey( civ.ShortDescription ), civ.ID );
					buttonAdded = buttonAdded + 1;
				end	
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.CivilizationsInnerFrame, Controls.CivilizationsFrame );

		-- update the game info
		if thisUnit.Help then
			UpdateTextBlock( Locale.ConvertTextKey( thisUnit.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
		end
				
		-- update the strategy info
		if thisUnit.Strategy then
			UpdateTextBlock( Locale.ConvertTextKey( thisUnit.Strategy ), Controls.StrategyLabel, Controls.StrategyInnerFrame, Controls.StrategyFrame );
		end
		
		-- update the historical info
		if thisUnit.Civilopedia then
			UpdateTextBlock( Locale.ConvertTextKey( thisUnit.Civilopedia ), Controls.HistoryLabel, Controls.HistoryInnerFrame, Controls.HistoryFrame );
		end

		-- Affinity Level Requirement
		local gameInfoText = "";
		Controls.ReqAffinitiesFrame:SetHide(true);
		local unitAffinityPrereq = CachedUnitAffinityPrereqs[thisUnit.Type];
		if (unitAffinityPrereq ~= nil) then
			if (unitAffinityPrereq.Level > 0) then
				local affinityInfo = GameInfo.Affinity_Types[unitAffinityPrereq.AffinityType];
				local gameInfoText = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_REQUIRED", affinityInfo.ColorType, unitAffinityPrereq.Level, affinityInfo.IconString, affinityInfo.Description);
				
				local affinityHeader = Locale.ConvertTextKey("TXT_KEY_PEDIA_CATEGORY_15_LABEL") .. ":";
				Controls.ReqAffinitiesHeader:SetText( affinityHeader );				
				Controls.ReqAffinitiesFrame:SetHide(false);
				Controls.ReqAffinitiesLabel:SetText( gameInfoText );
			end
		end
		
		-- update the related images
		Controls.RelatedImagesFrame:SetHide( true );
		
	end

	ResizeEtc();

end

local defaultPromotionPortraitOffset = Vector2( 256, 256 );

CivilopediaCategory[CategoryUpgrades].SelectArticle = function( upgradeID, shouldAddToList )
	print("CivilopediaCategory[CategoryUpgrades].SelectArticle");
	if m_selectedCategory ~= CategoryUpgrades then
		SetSelectedCategory(CategoryUpgrades, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryUpgrades, upgradeID );
	end
	
	if upgradeID ~= -1 then
		local upgradeInfo = GameInfo.UnitUpgrades[upgradeID];
		local unitInfo = GameInfo.Units[upgradeInfo.UnitType];
		local freePerkInfo = GameInfo.UnitPerks[upgradeInfo.FreePerk];
		if (upgradeInfo ~= nil and unitInfo ~= nil and freePerkInfo ~= nil) then
			-- update the name
			local name = Locale.ConvertTextKey( upgradeInfo.Description );
			Controls.ArticleID:SetText( name );

			-- Icon portrait
			local portraitIndex, portraitAtlas = UI.GetUnitPortraitIcon( unitInfo.ID );
			if IconHookup( portraitIndex, portraitSize, portraitAtlas, Controls.Portrait ) then
				Controls.PortraitFrame:SetHide( false );
			else
				Controls.PortraitFrame:SetHide( true );
			end
			
			-- Game Info text
			local gameInfoText = "";
			if (upgradeInfo.AnyAffinityLevel > 0) then
				gameInfoText = gameInfoText .. Locale.ConvertTextKey("TXT_KEY_UPANEL_AFFINITY_LEVEL_UNLOCK_TT", "TXT_KEY_AFFINITY_TYPE_ANY", upgradeInfo.AnyAffinityLevel) .. "[NEWLINE]"
			end
			if (upgradeInfo.HarmonyLevel > 0) then
				gameInfoText = gameInfoText .. "[ICON_HARMONY] [COLOR_HARMONY_AFFINITY]" .. Locale.ConvertTextKey("TXT_KEY_UPANEL_AFFINITY_LEVEL_UNLOCK_TT", "TXT_KEY_AFFINITY_TYPE_HARMONY", upgradeInfo.HarmonyLevel) .. "[ENDCOLOR][NEWLINE]";
			end
			if (upgradeInfo.PurityLevel > 0) then
				gameInfoText = gameInfoText .. "[ICON_PURITY] [COLOR_PURITY_AFFINITY]" .. Locale.ConvertTextKey("TXT_KEY_UPANEL_AFFINITY_LEVEL_UNLOCK_TT", "TXT_KEY_AFFINITY_TYPE_PURITY", upgradeInfo.PurityLevel) .. "[ENDCOLOR][NEWLINE]";
			end
			if (upgradeInfo.SupremacyLevel > 0) then
				gameInfoText = gameInfoText .. "[ICON_SUPREMACY] [COLOR_SUPREMACY_AFFINITY]" .. Locale.ConvertTextKey("TXT_KEY_UPANEL_AFFINITY_LEVEL_UNLOCK_TT", "TXT_KEY_AFFINITY_TYPE_SUPREMACY", upgradeInfo.SupremacyLevel) .. "[ENDCOLOR][NEWLINE]";
			end
			if (gameInfoText ~= "") then
				gameInfoText = gameInfoText .. "[NEWLINE]";
			end
			gameInfoText = gameInfoText .. GetHelpTextForUnitPerk(freePerkInfo.ID);
			gameInfoText = gameInfoText .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNIT_UPGRADE_CHOOSE_PERK");
			local AndText = " " .. Locale.ConvertTextKey("TXT_KEY_AND") .. " ";
			for choiceInfo in GameInfo.UnitUpgradePerkChoices("UpgradeType = '" .. upgradeInfo.Type.. "'") do
				local chosenPerkInfo = GameInfo.UnitPerks[choiceInfo.PerkType];
				local perkText		 = GetHelpTextForUnitPerk(chosenPerkInfo.ID);
				perkText = string.gsub( perkText, "%[NEWLINE%]", AndText );
				gameInfoText = gameInfoText .. "[NEWLINE][ICON_BULLET]" .. perkText;
			end
			UpdateTextBlock( gameInfoText, Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
		end
	end	

	ResizeEtc();

end

function SelectBuildingOrWonderArticle( buildingID )
	if buildingID ~= -1 then
		local thisBuilding = GameInfo.Buildings[buildingID];
					
		-- update the name
		local name = Locale.ConvertTextKey( thisBuilding.Description ); 	
		Controls.ArticleID:SetText( name );

		-- update the portrait
		if IconHookup( thisBuilding.PortraitIndex, portraitSize, thisBuilding.IconAtlas, Controls.Portrait ) then
			Controls.PortraitFrame:SetHide( false );
		else
			Controls.PortraitFrame:SetHide( true );
		end
		
		-- update the cost
		Controls.CostFrame:SetHide( false );
		local costString = "";
		
		local cost = thisBuilding.Cost;
		if(Game ~= nil) then
			cost = Players[Game.GetActivePlayer()]:GetBuildingProductionNeeded( buildingID );
		end
		
--[[
		local faithCost = thisBuilding.FaithCost;
		if(Game and Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
			faithCost = 0;
		end
]]
		
		local costPerPlayer = 0;
		for tLeagueProject in GameInfo.LeagueProjects() do
			if (tLeagueProject ~= nil) then
				for iTier = 1, 3, 1 do
					if (tLeagueProject["RewardTier" .. iTier] ~= nil) then
						local tReward = GameInfo.LeagueProjectRewards[tLeagueProject["RewardTier" .. iTier]];
						if (tReward ~= nil and tReward.Building ~= nil) then
							if (GameInfo.Buildings[tReward.Building] ~= nil and GameInfo.Buildings[tReward.Building].ID == buildingID) then
								costPerPlayer = tLeagueProject.CostPerPlayer;
								if (Game ~= nil and Game.GetNumActiveLeagues() > 0) then
									local pLeague = Game.GetActiveLeague();
									if (pLeague ~= nil) then
										costPerPlayer = pLeague:GetProjectCostPerPlayer(tLeagueProject.ID) / 100;
									end
								end
							end
						end
					end
				end
			end
		end
		
		if(costPerPlayer > 0) then
			costString = Locale.ConvertTextKey("TXT_KEY_LEAGUE_PROJECT_COST_PER_PLAYER", costPerPlayer);
		else
			if(cost > 0 and thisBuilding.Cost ~= 0) then
				costString = tostring(cost).. " [ICON_PRODUCTION]";
			else
				costString = Locale.Lookup("TXT_KEY_FREE");
			end
		end
		
		Controls.CostLabel:SetText(costString);
		
		-- update the maintenance
		local energyMaintenance = thisBuilding.EnergyMaintenance;
		if energyMaintenance > 0 then
			Controls.MaintenanceLabel:SetText( "-" .. tostring(energyMaintenance).." [ICON_ENERGY]" );
			Controls.MaintenanceFrame:SetHide( false );
		end

		-- update the Health
		local healthStrings = {};
		local iHealth = thisBuilding.Health;
		if (iHealth ~= nil and iHealth ~= 0) then
			table.insert(healthStrings, "+" .. tostring(iHealth).." [ICON_HEALTH_1]");		
		end

		local iHealthModifier = thisBuilding.HealthModifier;
		if(iHealthModifier ~= nil and iHealthModifier ~= 0) then
			table.insert(healthStrings, "+" .. tostring(iHealthModifier).."% [ICON_HEALTH_1]");
		end

		local iUnHealthModifier = thisBuilding.UnhealthModifier;
		if (iUnHealthModifier ~= nil and iUnHealthModifier ~= 0) then
			table.insert(healthStrings,  "+" .. tostring(iUnHealthModifier).."% [ICON_UNHEALTH]");
		end

		if(#healthStrings > 0) then
			Controls.HealthLabel:SetText(table.concat(healthStrings, " "));
			Controls.HealthFrame:SetHide( false );
		end

		local GetBuildingYieldChange = function(buildingID, yieldType)
			if(Game ~= nil) then
				return Game.GetBuildingYieldChange(buildingID, YieldTypes[yieldType]);
			else
				local yieldModifier = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				for row in GameInfo.Building_YieldChanges{BuildingType = buildingType, YieldType = yieldType} do
					yieldModifier = yieldModifier + row.Yield;
				end
				
				return yieldModifier;
			end
		
		end

		-- update the Defense
		local defenseEntries = {};
		local iDefense = thisBuilding.Defense;
		if iDefense > 0 then
			table.insert(defenseEntries, tostring(iDefense / 100).." [ICON_STRENGTH]");
		end
		
		local iExtraHitPoints = thisBuilding.ExtraCityHitPoints;
		if(iExtraHitPoints > 0) then
			table.insert(defenseEntries, Locale.Lookup("TXT_KEY_PEDIA_DEFENSE_HITPOINTS", iExtraHitPoints));
		end
		
		if(#defenseEntries > 0) then
			Controls.DefenseLabel:SetText(table.concat(defenseEntries, ", "));
			Controls.DefenseFrame:SetHide(false);
		else
			Controls.DefenseFrame:SetHide(true);
		end
		
		local GetBuildingYieldModifier = function(buildingID, yieldType)
			if(Game ~= nil) then
				return Game.GetBuildingYieldModifier(buildingID, YieldTypes[yieldType]);
			else
				local yieldModifier = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				for row in GameInfo.Building_YieldModifiers{BuildingType = buildingType, YieldType = yieldType} do
					yieldModifier = yieldModifier + row.Yield;
				end
				
				return yieldModifier;
			end
			
		end
		
		-- Use Game to calculate Yield Changes and modifiers.
		-- update the Food Change
		local iFood = GetBuildingYieldChange(buildingID, "YIELD_FOOD");
		if (iFood > 0) then
			Controls.FoodLabel:SetText( "+" .. tostring(iFood).." [ICON_FOOD]" );
			Controls.FoodFrame:SetHide( false );
		end


		local energyStrings = {};
		-- update the Energy Change
		local iGold = GetBuildingYieldChange(buildingID, "YIELD_ENERGY");
		if (iGold > 0) then
			table.insert(energyStrings, "+" .. tostring(iGold) .. "[ICON_ENERGY]");
		end

		-- update the Energy
		local iGold = GetBuildingYieldModifier(buildingID, "YIELD_ENERGY");
		if (iGold > 0) then
			table.insert(energyStrings, "+" .. tostring(iGold) .. "% [ICON_ENERGY]");
		end

		if(#energyStrings > 0) then
			Controls.GoldLabel:SetText(table.concat(energyStrings, ", "));
			Controls.GoldFrame:SetHide(false);
		else
			Controls.GoldFrame:SetHide(true);
		end


		-- update the Science
		local scienceItems = {};
		local iScience = GetBuildingYieldModifier(buildingID, "YIELD_SCIENCE");
		if(iScience > 0) then
			table.insert(scienceItems, "+" .. tostring(iScience).."% [ICON_RESEARCH]" );
		end
		
		-- update the Science Change
		local iScience = GetBuildingYieldChange(buildingID, "YIELD_SCIENCE");
		if(iScience > 0) then
			table.insert(scienceItems, "+" .. tostring(iScience).." [ICON_RESEARCH]" );
		end
		
		if(#scienceItems > 0) then
			Controls.ScienceLabel:SetText( table.concat(scienceItems, ", ") );
			Controls.ScienceFrame:SetHide( false );
		end

		-- update the Culture
		local cultureItems = {};
		local iCulture = GetBuildingYieldChange(buildingID, "YIELD_CULTURE");
		if iCulture > 0 then
			table.insert(cultureItems, "+" .. tostring(iCulture).." [ICON_CULTURE]" );			
		end

		-- update the Culture % mods		
		local iCulture = GetBuildingYieldModifier(buildingID, "YIELD_CULTURE");
		if(iCulture > 0) then
			table.insert(cultureItems, "+" .. tostring(iCulture).."% [ICON_CULTURE]");
		end

		if(#cultureItems > 0) then
			Controls.CultureLabel:SetText( table.concat(cultureItems, ", ") );
			Controls.CultureFrame:SetHide( false );
		end

		-- PRODUCTION
		local productionItems = {};

		-- FLAT Production
		local iProduction = GetBuildingYieldChange(buildingID, "YIELD_PRODUCTION");
		if(iProduction > 0) then
			table.insert(productionItems, "+" .. tostring(iProduction).." [ICON_PRODUCTION]");
		end

		-- MOD Production
		local iProduction = GetBuildingYieldModifier(buildingID, "YIELD_PRODUCTION");
		if(iProduction > 0) then
			table.insert(productionItems, "+" .. tostring(iProduction).."% [ICON_PRODUCTION]");
		end        

		-- Commit Production Items        
		if(#productionItems > 0) then
			Controls.ProductionLabel:SetText( table.concat(productionItems, ", ") );
			Controls.ProductionFrame:SetHide( false );
		end

 		local contentSize;
 		local frameSize = {};
		local buttonAdded = 0;

		-- update the prereq techs
		g_PrereqTechManager:DestroyInstances();

		if thisBuilding.PrereqTech then
			local prereq = GameInfo.Technologies[thisBuilding.PrereqTech];
			if prereq then
				local thisPrereqInstance = g_PrereqTechManager:GetInstance();
				if thisPrereqInstance then
					local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisPrereqInstance.PrereqTechImage, thisPrereqInstance.PrereqTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
					buttonAdded = buttonAdded + 1;
				end	
			end
		end	
		UpdateButtonFrame( buttonAdded, Controls.PrereqTechInnerFrame, Controls.PrereqTechFrame );

		local condition = "BuildingType = '" .. thisBuilding.Type .. "'";

		-- SpecialistType
		g_SpecialistsManager:DestroyInstances();
		buttonAdded = 0;

		if (thisBuilding.SpecialistCount > 0 and thisBuilding.SpecialistType) then
			local thisSpec = GameInfo.Specialists[thisBuilding.SpecialistType];
			if(thisSpec)  then
				for i = 1, thisBuilding.SpecialistCount, 1 do
					local thisSpecialistInstance = g_SpecialistsManager:GetInstance();
					if thisSpecialistInstance then
						local textureOffset, textureSheet = IconLookup( thisSpec.PortraitIndex, buttonSize, thisSpec.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				

						UpdateSmallButton( buttonAdded, thisSpecialistInstance.SpecialistImage, thisSpecialistInstance.SpecialistButton, textureSheet, textureOffset, CategoryConcepts, Locale.ConvertTextKey( thisSpec.Description ), ConceptBuildingSpecialistsId);
						buttonAdded = buttonAdded + 1;
					end	
				end
			end
		end	
		UpdateButtonFrame( buttonAdded, Controls.SpecialistsInnerFrame, Controls.SpecialistsFrame );
		
		-- required buildings
		g_RequiredBuildingsManager:DestroyInstances();
		buttonAdded = 0;
		for row in GameInfo.Building_ClassesNeededInCity( condition ) do
			local buildingClass = GameInfo.BuildingClasses[row.BuildingClassType];
			if(buildingClass) then
				local thisBuildingInfo = GameInfo.Buildings[buildingClass.DefaultBuilding];
				if (thisBuildingInfo) then
					local thisBuildingInstance = g_RequiredBuildingsManager:GetInstance();
					if thisBuildingInstance then

						if not IconHookup( thisBuildingInfo.PortraitIndex, buttonSize, thisBuildingInfo.IconAtlas, thisBuildingInstance.RequiredBuildingImage ) then
							thisBuildingInstance.RequiredBuildingImage:SetTexture( defaultErrorTextureSheet );
							thisBuildingInstance.RequiredBuildingImage:SetTextureOffset( nullOffset );
						end
						
						--move this button
						thisBuildingInstance.RequiredBuildingButton:SetOffsetVal( (buttonAdded % numberOfButtonsPerRow) * buttonSize + buttonPadding, math.floor(buttonAdded / numberOfButtonsPerRow) * buttonSize + buttonPadding );
						
						thisBuildingInstance.RequiredBuildingButton:SetToolTipString( Locale.ConvertTextKey( thisBuildingInfo.Description ) );
						thisBuildingInstance.RequiredBuildingButton:SetVoids( thisBuildingInfo.ID, addToList );
						local thisBuildingClass = GameInfo.BuildingClasses[thisBuildingInfo.BuildingClass];
						if thisBuildingClass.MaxGlobalInstances > 0 or (thisBuildingClass.MaxPlayerInstances == 1 and thisBuildingInfo.SpecialistCount == 0) or thisBuildingClass.MaxTeamInstances > 0 then
							thisBuildingInstance.RequiredBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectArticle );
						else
							thisBuildingInstance.RequiredBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].SelectArticle );
						end
						buttonAdded = buttonAdded + 1;
					end
				end
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.RequiredBuildingsInnerFrame, Controls.RequiredBuildingsFrame );

		-- needed local resources
		g_LocalResourcesManager:DestroyInstances();
		buttonAdded = 0;

		for row in GameInfo.Building_LocalResourceAnds( condition ) do
			local requiredResource = GameInfo.Resources[row.ResourceType];
			if requiredResource then
				local thisLocalResourceInstance = g_LocalResourcesManager:GetInstance();
				if thisLocalResourceInstance then
					local textureOffset, textureSheet = IconLookup( requiredResource.PortraitIndex, buttonSize, requiredResource.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisLocalResourceInstance.LocalResourceImage, thisLocalResourceInstance.LocalResourceButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( requiredResource.Description ), requiredResource.ID );
					buttonAdded = buttonAdded + 1;
				end
			end		
		end
		UpdateButtonFrame( buttonAdded, Controls.LocalResourcesInnerFrame, Controls.LocalResourcesFrame );
		
		-- update the required resources
		Controls.RequiredResourcesLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_REQ_RESRC_LABEL" ) );
		g_RequiredResourcesManager:DestroyInstances();
		buttonAdded = 0;

		for row in GameInfo.Building_ResourceQuantityRequirements( condition ) do
			local requiredResource = GameInfo.Resources[row.ResourceType];
			if requiredResource then
				local thisRequiredResourceInstance = g_RequiredResourcesManager:GetInstance();
				if thisRequiredResourceInstance then
					local textureOffset, textureSheet = IconLookup( requiredResource.PortraitIndex, buttonSize, requiredResource.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisRequiredResourceInstance.RequiredResourceImage, thisRequiredResourceInstance.RequiredResourceButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( requiredResource.Description ), requiredResource.ID );
					buttonAdded = buttonAdded + 1;
				end
			end		
		end
		UpdateButtonFrame( buttonAdded, Controls.RequiredResourcesInnerFrame, Controls.RequiredResourcesFrame );

		-- Are we a unique building?  If so, who do I replace?
		g_ReplacesManager:DestroyInstances();
		buttonAdded = 0;
		local defaultBuilding = nil;
		local thisCiv = nil;
		for row in GameInfo.Civilization_BuildingClassOverrides( condition ) do
			if row.Playable == true or row.AIPlayable == true then
			--if row.CivilizationType ~= "CIVILIZATION_ALIEN" and row.CivilizationType ~= "CIVILIZATION_MINOR" and row.CivilizationType ~= "CIVILIZATION_NEUTRAL_PROXY" then
				local otherCondition = "Type = '" .. row.BuildingClassType .. "'";
				for classrow in GameInfo.BuildingClasses( otherCondition ) do
					defaultBuilding = GameInfo.Buildings[classrow.DefaultBuilding];
				end
				if defaultBuilding then
					thisCiv = GameInfo.Civilizations[row.CivilizationType];
					break;
				end
			end
		end
		if defaultBuilding then
			local thisBuildingInstance = g_ReplacesManager:GetInstance();
			if thisBuildingInstance then
				local textureOffset, textureSheet = IconLookup( defaultBuilding.PortraitIndex, buttonSize, defaultBuilding.IconAtlas );				
				if textureOffset == nil then
					textureSheet = defaultErrorTextureSheet;
					textureOffset = nullOffset;
				end				
				UpdateSmallButton( buttonAdded, thisBuildingInstance.ReplaceImage, thisBuildingInstance.ReplaceButton, textureSheet, textureOffset, CategoryBuildings, Locale.ConvertTextKey( defaultBuilding.Description ), defaultBuilding.ID );
				buttonAdded = buttonAdded + 1;
			end
		end
		UpdateButtonFrame( buttonAdded, Controls.ReplacesInnerFrame, Controls.ReplacesFrame );

		buttonAdded = 0;
		if thisCiv then
			g_CivilizationsManager:DestroyInstances();
			local thisCivInstance = g_CivilizationsManager:GetInstance();
			if thisCivInstance then
				local textureOffset, textureSheet = IconLookup( thisCiv.PortraitIndex, buttonSize, thisCiv.IconAtlas );				
				if textureOffset == nil then
					textureSheet = defaultErrorTextureSheet;
					textureOffset = nullOffset;
				end				
				UpdateSmallButton( buttonAdded, thisCivInstance.CivilizationImage, thisCivInstance.CivilizationButton, textureSheet, textureOffset, CategoryCivilizations, Locale.ConvertTextKey( thisCiv.ShortDescription ), thisCiv.ID );
				buttonAdded = buttonAdded + 1;
			end	
		end
		UpdateButtonFrame( buttonAdded, Controls.CivilizationsInnerFrame, Controls.CivilizationsFrame );
		
		------------------------------------------------------------------
		-- update the GAME INFO
		-- NOTE! This will include parameterized effects that do not fit any of the standard stats above
		-- NOTE! You cannot use the Game class here because you can get to the Civilopedia from the main
		--       menu before Game is instantiated.
		
		local gameInfoItems = {};

		local GetTerrainYieldChange = function(buildingID, yieldID, terrainID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatYieldFromTerrain(buildingID, yieldID, terrainID);
			else
				local yieldModifier = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local yieldType = GameInfo.Yields[yieldID].Type;
				local terrainType = GameInfo.Terrains[terrainID].Type;
				for row in GameInfo.Building_TerrainYieldChanges{BuildingType = buildingType, YieldType = yieldType, TerrainType = terrainType } do
					yieldModifier = yieldModifier + row.Yield;
				end
				
				return yieldModifier;
			end
		end

		local GetFeatureYieldChange = function(buildingID, yieldID, featureID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatYieldFromFeature(buildingID, yieldID, featureID);
			else
				local yieldChange = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local yieldType = GameInfo.Yields[yieldID].Type;
				local featureType = GameInfo.Features[featureID].Type;
				for row in GameInfo.Building_FeatureYieldChanges{BuildingType = buildingType, YieldType = yieldType, FeatureType = featureType } do
					yieldChange = yieldChange + row.Yield;
				end
				
				return yieldChange;
			end
		end

		local GetResourceYieldChange = function(buildingID, yieldID, resourceID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatYieldFromResource(buildingID, yieldID, resourceID);
			else
				local yieldChange = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local yieldType = GameInfo.Yields[yieldID].Type;
				local resourceType = GameInfo.Resources[resourceID].Type;
				for row in GameInfo.Building_ResourceYieldChanges{BuildingType = buildingType, YieldType = yieldType, ResourceType = resourceType } do
					yieldChange = yieldChange + row.Yield;
				end
				
				return yieldChange;
			end
		end

		local GetResourceYieldChange = function(buildingID, yieldID, resourceID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatYieldFromResource(buildingID, yieldID, resourceID);
			else
				local yieldChange = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local yieldType = GameInfo.Yields[yieldID].Type;
				local resourceType = GameInfo.Resources[resourceID].Type;
				for row in GameInfo.Building_ResourceYieldChanges{BuildingType = buildingType, YieldType = yieldType, ResourceType = resourceType } do
					yieldChange = yieldChange + row.Yield;
				end
				
				return yieldChange;
			end
		end

		local GetTradeYieldChange = function(buildingID, yieldID)
			if(Game ~= nil) then
				return Game.GetBuildingTradeYieldChange(buildingID, yieldID);
			else
				local yieldChange = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local yieldType = GameInfo.Yields[yieldID].Type;
				for row in GameInfo.Building_TradeYieldChanges{BuildingType = buildingType, YieldType = yieldType } do
					yieldChange = yieldChange + row.Yield;
				end
				
				return yieldChange;
			end
		end

		local GetTradeYieldModifier = function(buildingID, yieldID)
			if(Game ~= nil) then
				return Game.GetBuildingTradeYieldModifier(buildingID, yieldID);
			else
				local yieldModifier = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local yieldType = GameInfo.Yields[yieldID].Type;
				for row in GameInfo.Building_TradeYieldModifiers{BuildingType = buildingType, YieldType = yieldType } do
					yieldModifier = yieldModifier + row.Yield;
				end
				
				return yieldModifier;
			end
		end

		-- SPECIAL YIELDS and EFFECTS
		for yieldInfo in GameInfo.Yields() do
			local eYield = yieldInfo.ID;
			
			-- Yield from TERRAIN
			for terrainInfo in GameInfo.Terrains() do
				local iTerrainYield = GetTerrainYieldChange(buildingID, eYield, terrainInfo.ID);
				if (iTerrainYield ~= nil and iTerrainYield ~= 0) then
					InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iTerrainYield, yieldInfo.IconString, yieldInfo.Description, terrainInfo.Description);
				end
			end

			-- Yield from FEATURES
			for featureInfo in GameInfo.Features() do
				local iFeatureYield = GetFeatureYieldChange(buildingID, eYield, featureInfo.ID);
				if (iFeatureYield ~= nil and iFeatureYield ~= 0) then
					InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iFeatureYield, yieldInfo.IconString, yieldInfo.Description, featureInfo.Description);
				end
			end

			-- Yield from RESOURCES
			for resourceInfo in GameInfo.Resources() do
				local iResourceYield = GetResourceYieldChange(buildingID, eYield, resourceInfo.ID);
				if (iResourceYield ~= nil and iResourceYield ~= 0) then
					InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_ICON_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_ICON_OBJECT", iResourceYield, yieldInfo.IconString, yieldInfo.Description, resourceInfo.IconString, resourceInfo.Description);
				end
			end

			--Yields from TRADE ROUTES
			-- FLAT
			local iFlatTradeYield = GetTradeYieldChange(buildingID, eYield);
			if (iFlatTradeYield ~= nil and iFlatTradeYield ~= 0) then
				InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iFlatTradeYield, yieldInfo.IconString, yieldInfo.Description, "TXT_KEY_EO_TRADE");
			end

			-- MOD
			local iModTradeYield = GetTradeYieldModifier(buildingID, eYield);
			if (iModTradeYield ~= nil and iModTradeYield ~= 0) then
				InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_MOD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_MOD_FROM_SPECIFIC_OBJECT", iModTradeYield, yieldInfo.IconString, yieldInfo.Description, "TXT_KEY_EO_TRADE");
			end
		end

		--
		local GetTerrainHealth = function(buildingID, terrainID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatHealthFromTerrain(buildingID, terrainID);
			else
				local health = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local terrainType = GameInfo.Terrains[terrainID].Type;
				for row in GameInfo.Building_TerrainHealthChange{BuildingType = buildingType, TerrainType = terrainType } do
					health = health + row.Quantity;
				end
				
				return health;
			end
		end

		-- Special from TERRAIN
		for terrainInfo in GameInfo.Terrains() do
			-- Health
			local iTerrainHealth = GetTerrainHealth(buildingID, terrainInfo.ID);
			if (iTerrainHealth ~= nil and iTerrainHealth ~= 0) then
				InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iTerrainHealth, HEALTH_ICON, "TXT_KEY_HEALTH", terrainInfo.Description );
			end
		end

		--
		local GetFeaturesHealth = function(buildingID, featureID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatHealthFromFeature(buildingID, featureID);
			else
				local health = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local featureType = GameInfo.Features[featureID].Type;
				for row in GameInfo.Building_FeatureHealthChange{BuildingType = buildingType, FeatureType = featureType } do
					health = health + row.Quantity;
				end
				
				return health;
			end
		end
		
		-- Special from FEATURES
		for featureInfo in GameInfo.Features() do
			-- Health
			local iFeatureHealth = GetFeaturesHealth(buildingID, featureInfo.ID);
			if (iFeatureHealth ~= nil and iFeatureHealth ~= 0) then
				InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iFeatureHealth, HEALTH_ICON, "TXT_KEY_HEALTH", featureInfo.Description);
			end
		end

		--
		local GetResourcesHealth = function(buildingID, resourceID)
			if(Game ~= nil) then
				return Game.GetBuildingFlatHealthFromResource(buildingID, resourceID);
			else
				local health = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local resourceType = GameInfo.Resources[resourceID].Type;
				for row in GameInfo.Building_ResourceHealthChange{BuildingType = buildingType, ResourceType = resourceType } do
					health = health + row.Quantity;
				end
				
				return health;
			end
		end

		-- Special from RESOURCES
		for resourceInfo in GameInfo.Resources() do
			-- Health
			local iResourceHealth = GetResourcesHealth(buildingID, resourceInfo.ID);
			if (iResourceHealth ~= nil and iResourceHealth ~= 0) then
				InsertYieldString( gameInfoItems, "TXT_KEY_YIELD_FROM_SPECIFIC_ICON_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_ICON_OBJECT", iResourceHealth, HEALTH_ICON, "TXT_KEY_HEALTH", resourceInfo.IconString, resourceInfo.Description);
			end
		end

		--
		local GetDomainModifier = function(buildingID, domainID)
			if(Game ~= nil) then
				return Game.GetBuildingDomainProductionModifier(buildingID, domainID);
			else
				local modifier = 0;
				local buildingType = GameInfo.Buildings[buildingID].Type;
				local domainType = GameInfo.Domains[domainID].Type;
				for row in GameInfo.Building_DomainProductionModifiers{BuildingType = buildingType, DomainType = domainType } do
					modifier = modifier + row.Modifier;
				end
				
				return modifier;
			end
		end

		-- DOMAIN Production Modifiers
		for domainInfo in GameInfo.Domains() do
			local iDomainProductionMod = GetDomainModifier(buildingID, domainInfo.ID);
			if (iDomainProductionMod ~= nil and iDomainProductionMod ~= 0) then
				table.insert(gameInfoItems, Locale.ConvertTextKey("TXT_KEY_DOMAIN_PRODUCTION_MOD", iDomainProductionMod, domainInfo.Description));
			end
		end

		-- Orbital Production
		local iOrbitalProductionMod = thisBuilding.OrbitalProductionModifier;
		if (iOrbitalProductionMod ~= nil and iOrbitalProductionMod ~= 0) then
			table.insert(gameInfoItems, Locale.ConvertTextKey("TXT_KEY_DOMAIN_PRODUCTION_MOD", iOrbitalProductionMod, "TXT_KEY_ORBITAL_UNITS"));
		end

		-- Orbital Coverage
		local iOrbitalCoverage = thisBuilding.OrbitalCoverageChange;
		if (iOrbitalCoverage ~= nil and iOrbitalCoverage ~= 0) then
			table.insert(gameInfoItems, Locale.ConvertTextKey("TXT_KEY_BUILDING_ORBITAL_COVERAGE", iOrbitalCoverage));
		end

			-- Anti-Orbital Strike
		local iOrbitalStrikeRangeChange = thisBuilding.OrbitalStrikeRangeChange;
		if (iOrbitalStrikeRangeChange ~= nil and iOrbitalStrikeRangeChange ~= 0) then
			table.insert(gameInfoItems, Locale.ConvertTextKey("TXT_KEY_UNITPERK_RANGE_AGAINST_ORBITAL_CHANGE", iOrbitalStrikeRangeChange));
		end

		-- Covert Ops Intrigue Cap
		local iIntrigueCapChange = thisBuilding.IntrigueCapChange;
		if (iIntrigueCapChange ~= nil and iIntrigueCapChange < 0) then
			local iIntrigueLevelsChange = (iIntrigueCapChange * -1) / (100 / GameDefines.MAX_CITY_INTRIGUE_LEVELS); -- Make it positive to show in UI
			table.insert(gameInfoItems, Locale.ConvertTextKey("TXT_KEY_BUILDING_CITY_INTRIGUE_CAP", iIntrigueLevelsChange));
		end

		-- Pre-written Help
		if thisBuilding.Help and (thisBuilding.Help ~= thisBuilding.Strategy) then
			table.insert(gameInfoItems, Locale.ConvertTextKey(thisBuilding.Help));
		end

		-- COMMIT GAME INFO
		if (#gameInfoItems > 0) then
			local completeGameInfoStr = table.concat(gameInfoItems, "[NEWLINE]");
			UpdateTextBlock(completeGameInfoStr, Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame);
		end
		------------------------------------------------------------------
				
		-- update the strategy info
		if thisBuilding.Strategy then
			UpdateTextBlock( Locale.ConvertTextKey( thisBuilding.Strategy ), Controls.StrategyLabel, Controls.StrategyInnerFrame, Controls.StrategyFrame );
		end
		
		-- update the historical info
		if thisBuilding.Civilopedia then
			UpdateTextBlock( Locale.ConvertTextKey( thisBuilding.Civilopedia ), Controls.HistoryLabel, Controls.HistoryInnerFrame, Controls.HistoryFrame );
		end
		
		if thisBuilding.Quote then
			UpdateTextBlock( Locale.ConvertTextKey( thisBuilding.Quote ), Controls.SilentQuoteLabel, Controls.SilentQuoteInnerFrame, Controls.SilentQuoteFrame );
		end

		-- Affinity Level Requirement
		local gameInfoText = "";
		Controls.ReqAffinitiesFrame:SetHide(true);
		local buildingAffinityPrereq = CachedBuildingAffinityPrereqs[thisBuilding.Type];
		if (buildingAffinityPrereq ~= nil) then
			if (buildingAffinityPrereq.Level > 0) then
				local affinityInfo = GameInfo.Affinity_Types[buildingAffinityPrereq.AffinityType];
				local gameInfoText = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_REQUIRED", affinityInfo.ColorType, buildingAffinityPrereq.Level, affinityInfo.IconString, affinityInfo.Description);
				
				Controls.ReqAffinitiesHeader:SetText( Locale.ConvertTextKey("TXT_KEY_PEDIA_CATEGORY_15_LABEL"));				
				Controls.ReqAffinitiesFrame:SetHide(false);
				Controls.ReqAffinitiesLabel:SetText( gameInfoText );
			end
		end
		
		-- update the related images
		Controls.RelatedImagesFrame:SetHide( true );

	end
end

CivilopediaCategory[CategoryBuildings].SelectArticle = function( buildingID, shouldAddToList )
	print("CivilopediaCategory[CategoryBuildings].SelectArticle");
	if m_selectedCategory ~= CategoryBuildings then
		SetSelectedCategory(CategoryBuildings, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryBuildings, buildingID );
	end
	
	SelectBuildingOrWonderArticle( buildingID );

	ResizeEtc();

end


CivilopediaCategory[CategoryWonders].SelectArticle = function( wonderID, shouldAddToList )
	print("CivilopediaCategory[CategoryWonders].SelectArticle");
	if m_selectedCategory ~= CategoryWonders then
		SetSelectedCategory(CategoryWonders, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryWonders, wonderID );
	end
	
	if wonderID < 1000 then
		SelectBuildingOrWonderArticle( wonderID );
	else
		local projectID = wonderID - 1000;
		if projectID ~= -1 then
		
			local thisProject = GameInfo.Projects[projectID];
						
			-- update the name
			local name = Locale.ConvertTextKey( thisProject.Description ); 	
			Controls.ArticleID:SetText( name );

			-- update the portrait
			if IconHookup( thisProject.PortraitIndex, portraitSize, thisProject.IconAtlas, Controls.Portrait ) then
				Controls.PortraitFrame:SetHide( false );
			else
				Controls.PortraitFrame:SetHide( true );
			end
			
			-- update the cost
			Controls.CostFrame:SetHide( false );
			local cost = thisProject.Cost;
			if(cost > 0 and Game ~= nil) then
				cost = Players[Game.GetActivePlayer()]:GetProjectProductionNeeded( projectID );
			end
			
			if(cost > 0) then
				Controls.CostLabel:SetText( tostring(cost).." [ICON_PRODUCTION]" );
			elseif(cost == 0) then
				Controls.CostLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_FREE" ) );
			else
				Controls.CostFrame:SetHide(true);
			end
	
 			local contentSize;
 			local frameSize = {};
			local buttonAdded = 0;

			-- update the prereq techs
			g_PrereqTechManager:DestroyInstances();
			buttonAdded = 0;

			if thisProject.TechPrereq then
				local prereq = GameInfo.Technologies[thisProject.TechPrereq];
				if prereq then
					local thisPrereqInstance = g_PrereqTechManager:GetInstance();
					if thisPrereqInstance then
						local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisPrereqInstance.PrereqTechImage, thisPrereqInstance.PrereqTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
						buttonAdded = buttonAdded + 1;
					end	
				end
			end	
			UpdateButtonFrame( buttonAdded, Controls.PrereqTechInnerFrame, Controls.PrereqTechFrame );

			local condition = "BuildingType = '" .. thisProject.Type .. "'";
			
			-- required buildings
			g_RequiredBuildingsManager:DestroyInstances();
			buttonAdded = 0;
			for row in GameInfo.Building_ClassesNeededInCity( condition ) do
				local buildingClass = GameInfo.BuildingClasses[row.BuildingClassType];
				if(buildingClass ~= nil) then
					local thisBuildingInfo = GameInfo.Buildings[buildingClass.DefaultBuilding];
					if(thisBuildingInfo ~= nil) then
						local thisBuildingInstance = g_RequiredBuildingsManager:GetInstance();
						if thisBuildingInstance then

							if not IconHookup( thisBuildingInfo.PortraitIndex, buttonSize, thisBuildingInfo.IconAtlas, thisBuildingInstance.RequiredBuildingImage ) then
								thisBuildingInstance.RequiredBuildingImage:SetTexture( defaultErrorTextureSheet );
								thisBuildingInstance.RequiredBuildingImage:SetTextureOffset( nullOffset );
							end
							
							--move this button
							thisBuildingInstance.RequiredBuildingButton:SetOffsetVal( (buttonAdded % numberOfButtonsPerRow) * buttonSize + buttonPadding, math.floor(buttonAdded / numberOfButtonsPerRow) * buttonSize + buttonPadding );
							
							thisBuildingInstance.RequiredBuildingButton:SetToolTipString( Locale.ConvertTextKey( thisBuildingInfo.Description ) );
							thisBuildingInstance.RequiredBuildingButton:SetVoids( thisBuildingInfo.ID, addToList );
							local thisBuildingClass = GameInfo.BuildingClasses[thisBuildingInfo.BuildingClass];
							if thisBuildingClass.MaxGlobalInstances > 0 or (thisBuildingClass.MaxPlayerInstances == 1 and thisBuildingInfo.SpecialistCount == 0) or thisBuildingClass.MaxTeamInstances > 0 then
								thisBuildingInstance.RequiredBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectArticle );
							else
								thisBuildingInstance.RequiredBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].SelectArticle );
							end
							buttonAdded = buttonAdded + 1;
						end
					end
				end
			end
			UpdateButtonFrame( buttonAdded, Controls.RequiredBuildingsInnerFrame, Controls.RequiredBuildingsFrame );
			
			-- update the game info
			if thisProject.Help then
				UpdateTextBlock( Locale.ConvertTextKey( thisProject.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
			end
					
			-- update the strategy info
			if (thisProject.Strategy) then
				UpdateTextBlock( Locale.ConvertTextKey( thisProject.Strategy ), Controls.StrategyLabel, Controls.StrategyInnerFrame, Controls.StrategyFrame );
			end
			
			-- update the historical info
			if (thisProject.Civilopedia) then
				UpdateTextBlock( Locale.ConvertTextKey( thisProject.Civilopedia ), Controls.HistoryLabel, Controls.HistoryInnerFrame, Controls.HistoryFrame );
			end
					
			-- update the related images
			Controls.RelatedImagesFrame:SetHide( true );
		end
	end

	ResizeEtc();

end

CivilopediaCategory[CategoryVirtues].SelectArticle = function( policyID, shouldAddToList )
	print("CivilopediaCategory[CategoryVirtues].SelectArticle");
	if m_selectedCategory ~= CategoryVirtues then
		SetSelectedCategory(CategoryVirtues, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryVirtues, policyID );
	end
	
	if policyID ~= -1 then
	
		local thisPolicy = GameInfo.Policies[policyID];
					
		-- update the name
		local name = Locale.ConvertTextKey( thisPolicy.Description ); 	
		Controls.ArticleID:SetText( name );

		-- update the portrait
		if IconHookup( thisPolicy.PortraitIndex, portraitSize, thisPolicy.IconAtlas, Controls.Portrait ) then
			Controls.PortraitFrame:SetHide( false );
		else
			Controls.PortraitFrame:SetHide( true );
		end
		
		-- update the policy branch
		if thisPolicy.PolicyBranchType then
			local branch = GameInfo.PolicyBranchTypes[thisPolicy.PolicyBranchType];
			if branch then
				local branchName = Locale.ConvertTextKey( branch.Description ); 	
				Controls.PolicyBranchLabel:SetText( branchName );
				Controls.PolicyBranchFrame:SetHide( false );
				-- update the prereq era
				if branch.EraPrereq then
					local era = GameInfo.Eras[branch.EraPrereq];
					if era then
						local eraName = Locale.ConvertTextKey( era.Description ); 	
						Controls.PrereqEraLabel:SetText( eraName );
						Controls.PrereqEraFrame:SetHide( false );
					end
				end
			end
		end
				
		local contentSize;
		local frameSize = {};
		local buttonAdded = 0;

		-- update the prereq policies
		g_RequiredPoliciesManager:DestroyInstances();
		buttonAdded = 0;

		local condition = "PolicyType = '" .. thisPolicy.Type .. "'";

		for row in GameInfo.Policy_PrereqPolicies( condition ) do
			local requiredPolicy = GameInfo.Policies[row.PrereqPolicy];
			if requiredPolicy then
				local thisRequiredPolicyInstance = g_RequiredPoliciesManager:GetInstance();
				if thisRequiredPolicyInstance then
					local textureOffset, textureSheet = IconLookup( requiredPolicy.PortraitIndex, buttonSize, requiredPolicy.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisRequiredPolicyInstance.RequiredPolicyImage, thisRequiredPolicyInstance.RequiredPolicyButton, textureSheet, textureOffset, CategoryVirtues, Locale.ConvertTextKey( requiredPolicy.Description ), requiredPolicy.ID );
					buttonAdded = buttonAdded + 1;
				end
			end		
		end
		UpdateButtonFrame( buttonAdded, Controls.RequiredPoliciesInnerFrame, Controls.RequiredPoliciesFrame );
		
		local tenetLevelLabels = {
			"TXT_KEY_POLICYSCREEN_L1_TENET",
			"TXT_KEY_POLICYSCREEN_L2_TENET",
			"TXT_KEY_POLICYSCREEN_L3_TENET",
		}
		
		local tenetLevel = tonumber(thisPolicy.Level);
		if(tenetLevel ~= nil and tenetLevel > 0) then
			Controls.TenetLevelLabel:LocalizeAndSetText(tenetLevelLabels[tenetLevel]);
			Controls.TenetLevelFrame:SetHide(false);	
		else
			Controls.TenetLevelFrame:SetHide(true);
		end
		

		-- update the game info
		if thisPolicy.Help then
			UpdateTextBlock( Locale.ConvertTextKey( thisPolicy.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
		else
			UpdateTextBlock( GetHelpTextForVirtue( policyID ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
		end
				
		-- update the strategy info
		--UpdateTextBlock( Locale.ConvertTextKey( thisPolicy.Strategy ), Controls.StrategyLabel, Controls.StrategyInnerFrame, Controls.StrategyFrame );
		
		-- update the historical info
		if (thisPolicy.Civilopedia) then
			UpdateTextBlock( Locale.ConvertTextKey( thisPolicy.Civilopedia ), Controls.HistoryLabel, Controls.HistoryInnerFrame, Controls.HistoryFrame );
		end
		
		-- update the related images
		Controls.RelatedImagesFrame:SetHide( true );
	end

	ResizeEtc();

end


CivilopediaCategory[CategoryEspionage].SelectArticle =  function( conceptID, shouldAddToList )
	print("CivilopediaCategory[CategoryEspionage].SelectArticle");
	if m_selectedCategory ~= CategoryEspionage then
		SetSelectedCategory(CategoryEspionage, dontAddToList);
	end
	
	ClearArticle();
	
	local article = m_categorizedListOfArticles[(CategoryEspionage * MAX_ENTRIES_PER_CATEGORY) + conceptID];

	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryEspionage, conceptID );
	end
	
	if conceptID ~= -1 then
		local thisConcept = GameInfo.Concepts[conceptID];
		
		if thisConcept then
		
			-- update the name
			local name = Locale.ConvertTextKey( thisConcept.Description ); 	
			Controls.ArticleID:SetText( name );
			
			-- portrait
			
			-- update the summary
			if thisConcept.Summary then
				UpdateSuperWideTextBlock( Locale.ConvertTextKey( thisConcept.Summary ), Controls.SummaryLabel, Controls.SummaryInnerFrame, Controls.SummaryFrame );
			end

			-- update perk
			if article.PlayerPerk and article.PlayerPerk.Description then
				UpdateSuperWideTextBlock( Locale.ConvertTextKey( article.PlayerPerk.Description ), Controls.ExtendedLabel, Controls.ExtendedInnerFrame, Controls.ExtendedFrame );
			end
			
			-- related images
			
			-- related concepts
		
		end

	end	

	ResizeEtc();
end


CivilopediaCategory[CategoryCivilizations].SelectArticle = function( rawCivID, shouldAddToList )
	print("CivilopediaCategory[CategoryCivilizations].SelectArticle");
	if m_selectedCategory ~= CategoryCivilizations then
		SetSelectedCategory(CategoryCivilizations, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryCivilizations, rawCivID );
	end

	if rawCivID < 1000 then
		if rawCivID ~= -1 then
		
			local thisCiv = GameInfo.Civilizations[rawCivID];
				if thisCiv and (thisCiv.Playable == true or thisCiv.AIPlayable == true) then
			--if thisCiv and thisCiv.Type ~= "CIVILIZATION_MINOR" and thisCiv.Type ~= "CIVILIZATION_ALIEN" and row.CivilizationType ~= "CIVILIZATION_NEUTRAL_PROXY" then
							
				-- update the name
				local name = Locale.ConvertTextKey( thisCiv.ShortDescription )
				Controls.ArticleID:SetText( name );

				-- update the portrait
				if IconHookup( thisCiv.PortraitIndex, portraitSize, thisCiv.IconAtlas, Controls.Portrait ) then
					Controls.PortraitFrame:SetHide( false );
				else
					Controls.PortraitFrame:SetHide( true );
				end

				local buttonAdded = 0;
		 		local condition = "CivilizationType = '" .. thisCiv.Type .. "'";
				
				-- add a list of leaders
				g_LeadersManager:DestroyInstances();
				buttonAdded = 0;
					
				local leader = nil;
				for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = thisCiv.Type} do
					leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
				end
				local thisLeaderInstance = g_LeadersManager:GetInstance();
				if thisLeaderInstance then
					local textureOffset, textureSheet = IconLookup( leader.PortraitIndex, buttonSize, leader.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisLeaderInstance.LeaderImage, thisLeaderInstance.LeaderButton, textureSheet, textureOffset, CategoryCivilizations, Locale.ConvertTextKey( leader.Description ), thisCiv.ID + 1000 );
					buttonAdded = buttonAdded + 1;
				end	
				UpdateButtonFrame( buttonAdded, Controls.LeadersInnerFrame, Controls.LeadersFrame );
				
				-- list of UUs
 				g_UniqueUnitsManager:DestroyInstances();
				buttonAdded = 0;
				for thisOverride in GameInfo.Civilization_UnitClassOverrides( condition ) do
					if thisOverride.UnitType ~= nil then
						local thisUnitInfo = GameInfo.Units[thisOverride.UnitType];
						if thisUnitInfo then
							local thisUnitInstance = g_UniqueUnitsManager:GetInstance();
							if thisUnitInstance then
								local textureOffset, textureSheet = IconLookup( thisUnitInfo.PortraitIndex, buttonSize, thisUnitInfo.IconAtlas );				
								if textureOffset == nil then
									textureSheet = defaultErrorTextureSheet;
									textureOffset = nullOffset;
								end			
								
								local unitCategory = CategoryUnits;
								local unitEntryID = thisUnitInfo.ID;
									
								UpdateSmallButton( buttonAdded, thisUnitInstance.UniqueUnitImage, thisUnitInstance.UniqueUnitButton, textureSheet, textureOffset, unitCategory, Locale.ConvertTextKey( thisUnitInfo.Description ), unitEntryID);
								buttonAdded = buttonAdded + 1;
							end
						end
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.UniqueUnitsInnerFrame, Controls.UniqueUnitsFrame );	 	  
				
				-- list of UBs
				g_UniqueBuildingsManager:DestroyInstances();
				buttonAdded = 0;
				for thisOverride in GameInfo.Civilization_BuildingClassOverrides( condition ) do
					if(thisOverride.BuildingType ~= nil) then
						local thisBuildingInfo = GameInfo.Buildings[thisOverride.BuildingType];
						if thisBuildingInfo then
							local thisBuildingInstance = g_UniqueBuildingsManager:GetInstance();
							if thisBuildingInstance then

								if not IconHookup( thisBuildingInfo.PortraitIndex, buttonSize, thisBuildingInfo.IconAtlas, thisBuildingInstance.UniqueBuildingImage ) then
									thisBuildingInstance.UniqueBuildingImage:SetTexture( defaultErrorTextureSheet );
									thisBuildingInstance.UniqueBuildingImage:SetTextureOffset( nullOffset );
								end
								
								--move this button
								thisBuildingInstance.UniqueBuildingButton:SetOffsetVal( (buttonAdded % numberOfButtonsPerRow) * buttonSize + buttonPadding, math.floor(buttonAdded / numberOfButtonsPerRow) * buttonSize + buttonPadding );
								
								thisBuildingInstance.UniqueBuildingButton:SetToolTipString( Locale.ConvertTextKey( thisBuildingInfo.Description ) );
								thisBuildingInstance.UniqueBuildingButton:SetVoids( thisBuildingInfo.ID, addToList );
								local thisBuildingClass = GameInfo.BuildingClasses[thisBuildingInfo.BuildingClass];
								if thisBuildingClass.MaxGlobalInstances > 0 or (thisBuildingClass.MaxPlayerInstances == 1 and thisBuildingInfo.SpecialistCount == 0) or thisBuildingClass.MaxTeamInstances > 0 then
									thisBuildingInstance.UniqueBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectArticle );
								else
									thisBuildingInstance.UniqueBuildingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].SelectArticle );
								end

								buttonAdded = buttonAdded + 1;
							end
						end
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.UniqueBuildingsInnerFrame, Controls.UniqueBuildingsFrame );
				
				-- list of unique improvements	 	  
				g_UniqueImprovementsManager:DestroyInstances();
				buttonAdded = 0;
				for thisImprovement in GameInfo.Improvements( condition ) do
					local thisImprovementInstance = g_UniqueImprovementsManager:GetInstance();
					if thisImprovementInstance then

						if not IconHookup( thisImprovement.PortraitIndex, buttonSize, thisImprovement.IconAtlas, thisImprovementInstance.UniqueImprovementImage ) then
							thisImprovementInstance.UniqueImprovementImage:SetTexture( defaultErrorTextureSheet );
							thisImprovementInstance.UniqueImprovementImage:SetTextureOffset( nullOffset );
						end
						
						--move this button
						thisImprovementInstance.UniqueImprovementButton:SetOffsetVal( (buttonAdded % numberOfButtonsPerRow) * buttonSize + buttonPadding, math.floor(buttonAdded / numberOfButtonsPerRow) * buttonSize + buttonPadding );
						
						thisImprovementInstance.UniqueImprovementButton:SetToolTipString( Locale.ConvertTextKey( thisImprovement.Description ) );
						thisImprovementInstance.UniqueImprovementButton:SetVoids( thisImprovement.ID, addToList );
						thisImprovementInstance.UniqueImprovementButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryImprovements].SelectArticle );

						buttonAdded = buttonAdded + 1;
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.UniqueImprovementsInnerFrame, Controls.UniqueImprovementsFrame );
				
				-- list of special abilities
				buttonAdded = 0;
				
				-- add the free form text
				g_FreeFormTextManager:DestroyInstances();
				
				local tagString = thisCiv.CivilopediaTag;
				if tagString then
					local headerString = tagString .. "_HEADING_";
					local bodyString = tagString .. "_TEXT_";
					local notFound = false;
					local i = 1;
					repeat
						local headerTag = headerString .. tostring( i );
						local bodyTag = bodyString .. tostring( i );
						if TagExists( headerTag ) and TagExists( bodyTag ) then
							local thisFreeFormTextInstance = g_FreeFormTextManager:GetInstance();
							if thisFreeFormTextInstance then
								thisFreeFormTextInstance.FFTextHeader:SetText( Locale.ConvertTextKey( headerTag ));
								UpdateTextBlock( Locale.ConvertTextKey( bodyTag ), thisFreeFormTextInstance.FFTextLabel, thisFreeFormTextInstance.FFTextInnerFrame, thisFreeFormTextInstance.FFTextFrame );
							end
						else
							notFound = true;		
						end
						i = i + 1;
					until notFound;

					local factoidHeaderString = tagString .. "_FACTOID_HEADING";
					local factoidBodyString = tagString .. "_FACTOID_TEXT";
					if TagExists( factoidHeaderString ) and TagExists( factoidBodyString ) then
						local thisFreeFormTextInstance = g_FreeFormTextManager:GetInstance();
						if thisFreeFormTextInstance then
							thisFreeFormTextInstance.FFTextHeader:SetText( Locale.ConvertTextKey( factoidHeaderString ));
							UpdateTextBlock( Locale.ConvertTextKey( factoidBodyString ), thisFreeFormTextInstance.FFTextLabel, thisFreeFormTextInstance.FFTextInnerFrame, thisFreeFormTextInstance.FFTextFrame );
						end
					end
					
					Controls.FFTextStack:SetHide( false );

				end

				-- update the related images
				Controls.RelatedImagesFrame:SetHide( true );
			end
		end
	else
		local civID = rawCivID - 1000;
		if civID ~= -1 then
		
			local thisCiv = GameInfo.Civilizations[civID];
			if thisCiv and (thisCiv.Playable == true or thisCiv.AIPlayable == true) then
			--if thisCiv and thisCiv.Type ~= "CIVILIZATION_MINOR" and thisCiv.Type ~= "CIVILIZATION_ALIEN" and row.CivilizationType ~= "CIVILIZATION_NEUTRAL_PROXY" then
							
				local leader = nil;
				for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = thisCiv.Type} do
					leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
				end

				-- update the name
				local tagString = leader.CivilopediaTag;
				if tagString then
					local name = Locale.ConvertTextKey( tagString.."_NAME" );
					Controls.ArticleID:SetText( name );
					Controls.SubtitleLabel:SetText( Locale.ConvertTextKey( tagString.."_SUBTITLE" ) );
					Controls.SubtitleID:SetHide( false );
				else
					local name = Locale.ConvertTextKey( leader.Description )
					Controls.ArticleID:SetText( name );
				end

				-- update the portrait
				if IconHookup( leader.PortraitIndex, portraitSize, leader.IconAtlas, Controls.Portrait ) then
					Controls.PortraitFrame:SetHide( false );
				else
					Controls.PortraitFrame:SetHide( true );
				end

				local buttonAdded = 0;
				
				-- add titles etc.
				if tagString then

					local livedKey = tagString .. "_LIVED";
					if(Locale.HasTextKey(livedKey)) then
						Controls.LivedLabel:SetText( Locale.ConvertTextKey( livedKey ) );
						Controls.LivedFrame:SetHide( false );
					else
						Controls.LivedFrame:SetHide(true);
					end
				
					local titlesString = tagString .. "_TITLES_";
					local notFound = false;
					local i = 1;
					local titles = "";
					local numTitles = 0;
					repeat
						local titlesTag = titlesString .. tostring( i );
						if TagExists( titlesTag ) then
							if numTitles > 0 then
								titles = titles .. "[NEWLINE][NEWLINE]";
							end
							numTitles = numTitles + 1;
							titles = titles .. Locale.ConvertTextKey( titlesTag );
						else
							notFound = true;		
						end
						i = i + 1;
					until notFound;
					if numTitles > 0 then
						UpdateNarrowTextBlock( Locale.ConvertTextKey( titles ), Controls.TitlesLabel, Controls.TitlesInnerFrame, Controls.TitlesFrame );
					end
				end

 				local condition = "LeaderType = '" .. leader.Type .. "'";
 	
				-- list of traits
 				--g_TraitsManager:DestroyInstances();
				--buttonAdded = 0;
				--for row in GameInfo.Leader_Traits( condition ) do
					--local thisTrait = GameInfo.Traits[row.TraitType];
					--if thisTrait then
						--local thisTraitInstance = g_TraitsManager:GetInstance();
						--if thisTraitInstance then
							--local textureSheet;
							--local textureOffset;
							--textureSheet = defaultErrorTextureSheet;
							--textureOffset = nullOffset;
							--UpdateSmallButton( buttonAdded, thisTraitInstance.TraitImage, thisTraitInstance.TraitButton, textureSheet, textureOffset, CategoryConcepts, Locale.ConvertTextKey( thisTrait.ShortDescription ), thisTrait.ID ); -- todo: add a fudge factor
							--buttonAdded = buttonAdded + 1;
						--end
					--end
				--end
				--UpdateButtonFrame( buttonAdded, Controls.TraitsInnerFrame, Controls.TraitsFrame );	 	  
								--
				-- add the civ icon
				g_CivilizationsManager:DestroyInstances();
				buttonAdded = 0;
				local thisCivInstance = g_CivilizationsManager:GetInstance();
				if thisCivInstance then
					local textureOffset, textureSheet = IconLookup( thisCiv.PortraitIndex, buttonSize, thisCiv.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisCivInstance.CivilizationImage, thisCivInstance.CivilizationButton, textureSheet, textureOffset, CategoryCivilizations, Locale.ConvertTextKey( thisCiv.ShortDescription ), thisCiv.ID );
					buttonAdded = buttonAdded + 1;
				end	
				UpdateButtonFrame( buttonAdded, Controls.CivilizationsInnerFrame, Controls.CivilizationsFrame );
						
				-- update the game info
				local leaderTrait = GameInfo.Leader_Traits(condition)();
				if leaderTrait then
					local trait = leaderTrait.TraitType;
					local traitString = Locale.ConvertTextKey( GameInfo.Traits[trait].ShortDescription ).."[NEWLINE][NEWLINE]"..Locale.ConvertTextKey( GameInfo.Traits[trait].Description );
					UpdateTextBlock( traitString, Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
				end
										
				-- add the free form text
				g_FreeFormTextManager:DestroyInstances();
				if tagString then
					local headerString = tagString .. "_HEADING_";
					local bodyString = tagString .. "_TEXT_";
					local notFound = false;
					local i = 1;
					repeat
						local headerTag = headerString .. tostring( i );
						local bodyTag = bodyString .. tostring( i );
						if TagExists( headerTag ) and TagExists( bodyTag ) then
							local thisFreeFormTextInstance = g_FreeFormTextManager:GetInstance();
							if thisFreeFormTextInstance then
								thisFreeFormTextInstance.FFTextHeader:SetText( Locale.ConvertTextKey( headerTag ));
								UpdateTextBlock( Locale.ConvertTextKey( bodyTag ), thisFreeFormTextInstance.FFTextLabel, thisFreeFormTextInstance.FFTextInnerFrame, thisFreeFormTextInstance.FFTextFrame );
							end
						else
							notFound = true;		
						end
						i = i + 1;
					until notFound;
					
					notFound = false;
					i = 1;
					repeat
						local bodyString = tagString .. "_FACT_";
						local bodyTag = bodyString .. tostring( i );
						if TagExists( bodyTag ) then
							local thisFreeFormTextInstance = g_FreeFormTextManager:GetInstance();
							if thisFreeFormTextInstance then
								thisFreeFormTextInstance.FFTextHeader:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_FACTOID" ));
								UpdateTextBlock( Locale.ConvertTextKey( bodyTag ), thisFreeFormTextInstance.FFTextLabel, thisFreeFormTextInstance.FFTextInnerFrame, thisFreeFormTextInstance.FFTextFrame );
							end
						else
							notFound = true;		
						end
						i = i + 1;
					until notFound;
											
					Controls.FFTextStack:SetHide( false );

				end
				
				-- update the related images
				Controls.RelatedImagesFrame:SetHide( true );

			end
		end
	end

	ResizeEtc();

end

CivilopediaCategory[CategoryQuests].SelectArticle = function( conceptID, shouldAddToList )
	print("CivilopediaCategory[CategoryQuests].SelectArticle");
	if m_selectedCategory ~= CategoryQuests then
		SetSelectedCategory(CategoryQuests, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryQuests, conceptID );
	end
	
	if conceptID ~= -1 then
		local thisConcept = GameInfo.Concepts[conceptID];
		
		if thisConcept then
		
			-- update the name
			local name = Locale.ConvertTextKey( thisConcept.Description ); 	
			Controls.ArticleID:SetText( name );
			
			-- portrait
			
			-- update the summary
			if thisConcept.Summary then
				UpdateSuperWideTextBlock( Locale.ConvertTextKey( thisConcept.Summary ), Controls.SummaryLabel, Controls.SummaryInnerFrame, Controls.SummaryFrame );
			end
			
			-- related images
			
			-- related concepts
		
		end

	end	

	ResizeEtc();
end


CivilopediaCategory[CategoryTerrain].SelectArticle = function( rawTerrainID, shouldAddToList )
	print("CivilopediaCategory[CategoryTerrain].SelectArticle");
	if m_selectedCategory ~= CategoryTerrain then
		SetSelectedCategory(CategoryTerrain, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryTerrain, rawTerrainID );
	end

	if rawTerrainID < 1000 then
		local terrainId = rawTerrainID;
		if terrainId ~= -1 then
		
			local thisTerrain = GameInfo.Terrains[terrainId];
			if thisTerrain then

				-- update the name
				local name = Locale.ConvertTextKey( thisTerrain.Description )
				Controls.ArticleID:SetText( name );

				-- update the portrait
				if IconHookup( thisTerrain.PortraitIndex, portraitSize, thisTerrain.IconAtlas, Controls.Portrait ) then
					Controls.PortraitFrame:SetHide( false );
				else
					Controls.PortraitFrame:SetHide( true );
				end

				local buttonAdded = 0;
		 		local condition = "TerrainType = '" .. thisTerrain.Type .. "'";
				
				-- City Yield
				Controls.YieldFrame:SetHide( false );
				local yieldLines = {};
				for row in GameInfo.Terrain_Yields( condition ) do
					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", row.Yield, GameInfo.Yields[row.YieldType].IconString, GameInfo.Yields[row.YieldType].Description));
				end
				-- special case hackery for hills
				if thisTerrain.Type == "TERRAIN_HILL" then
					local iconString = GameInfo.Yields["YIELD_PRODUCTION"].IconString;
					local description =  GameInfo.Yields["YIELD_PRODUCTION"].Description;

					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", tostring(1), iconString, description));
				end
				
				if #yieldLines > 0 then
					ShowAndSizeFrameToText( Locale.ConvertTextKey( table.concat(yieldLines, ", ") ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
				else
					ShowAndSizeFrameToText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_NO_YIELD" ) , Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
				end
				
				-- Movement
				Controls.MovementCostFrame:SetHide( false );
				local moveCost = thisTerrain.Movement;
				-- special case hackery for hills
				if thisTerrain.Type == "TERRAIN_HILL" then
					moveCost = moveCost + GameDefines.HILLS_EXTRA_MOVEMENT;
				end
				if thisTerrain.Type == "TERRAIN_MOUNTAIN" then
					Controls.MovementCostLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPASSABLE" ) );
				else
					Controls.MovementCostLabel:SetText( Locale.ConvertTextKey( moveCost ).."[ICON_MOVES]" );
				end

				-- Combat Modifier
				Controls.CombatModFrame:SetHide( false );
				local combatModifier = 0;
				local combatModString = "";
				if thisTerrain.Type == "TERRAIN_HILL" or thisTerrain.Type == "TERRAIN_MOUNTAIN" then
					combatModifier = GameDefines.HILLS_EXTRA_DEFENSE;
				elseif thisTerrain.Water then
					combatModifier = 0;
				else
					combatModifier = GameDefines.FLAT_LAND_EXTRA_DEFENSE;
				end
				if combatModifier > 0 then
					combatModString = "+";
				end
				combatModString = combatModString..tostring(combatModifier).."%";
				Controls.CombatModLabel:SetText( combatModString );

				-- Features that can exist on this terrain
 				g_FeaturesManager:DestroyInstances();
				buttonAdded = 0;
				for row in GameInfo.Feature_TerrainBooleans( condition ) do
					local thisFeature = GameInfo.Features[row.FeatureType];
					if thisFeature then
						local thisFeatureInstance = g_FeaturesManager:GetInstance();
						if thisFeatureInstance then
							local textureOffset, textureSheet = IconLookup( thisFeature.PortraitIndex, buttonSize, thisFeature.IconAtlas );				
							if textureOffset == nil then
								textureSheet = defaultErrorTextureSheet;
								textureOffset = nullOffset;
							end				
							UpdateSmallButton( buttonAdded, thisFeatureInstance.FeatureImage, thisFeatureInstance.FeatureButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisFeature.Description ), thisFeature.ID + 1000 ); -- todo: add a fudge factor
							buttonAdded = buttonAdded + 1;
						end
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.FeaturesInnerFrame, Controls.FeaturesFrame );	 	  

				-- Resources that can exist on this terrain
				local resourcesShown : table = {};

				Controls.ResourcesFoundLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCESFOUND_LABEL" ) );
 				g_ResourcesFoundManager:DestroyInstances();
				buttonAdded = 0;
				for row in GameInfo.Resource_TerrainBooleans( condition ) do
					local thisResource = GameInfo.Resources[row.ResourceType];
					if thisResource and thisResource.ShowInCivilopedia then
						local thisResourceInstance = g_ResourcesFoundManager:GetInstance();
						if thisResourceInstance then
							local textureOffset, textureSheet = IconLookup( thisResource.PortraitIndex, buttonSize, thisResource.IconAtlas );				
							if textureOffset == nil then
								textureSheet = defaultErrorTextureSheet;
								textureOffset = nullOffset;
							end		
							resourcesShown[row.ResourceType] = true;		
							UpdateSmallButton( buttonAdded, thisResourceInstance.ResourceFoundImage, thisResourceInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( thisResource.Description ), thisResource.ID );
							buttonAdded = buttonAdded + 1;
						end
					end
				end
				-- special case hackery for hills
				if thisTerrain.Type == "TERRAIN_HILL" then
					for thisResource in GameInfo.Resources() do
						if thisResource and thisResource.Hills and thisResource.ShowInCivilopedia then
							if( resourcesShown[thisResource.ID] == nil ) then
								local thisResourceInstance = g_ResourcesFoundManager:GetInstance();
								if thisResourceInstance then
									local textureOffset, textureSheet = IconLookup( thisResource.PortraitIndex, buttonSize, thisResource.IconAtlas );				
									if textureOffset == nil then
										textureSheet = defaultErrorTextureSheet;
										textureOffset = nullOffset;
									end				
									UpdateSmallButton( buttonAdded, thisResourceInstance.ResourceFoundImage, thisResourceInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( thisResource.Description ), thisResource.ID );
									buttonAdded = buttonAdded + 1;
								end
							end
						end
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.ResourcesFoundInnerFrame, Controls.ResourcesFoundFrame );	 	  

				-- generic text
				if (thisTerrain.Civilopedia) then
					UpdateTextBlock( Locale.ConvertTextKey( thisTerrain.Civilopedia ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
				end
				
				-- update the related images
				Controls.RelatedImagesFrame:SetHide( true );
			end
		end
	else
		local featureID = rawTerrainID - 1000;
		if featureID ~= -1 then
		
			local thisFeature;
			if featureID < 1000 then
				thisFeature = GameInfo.Features[featureID];
			else
				thisFeature = GameInfo.FakeFeatures[featureID-1000];
			end
			if thisFeature then

				-- update the name
				local name = Locale.ConvertTextKey( thisFeature.Description )
				Controls.ArticleID:SetText( name );

				-- update the portrait
				if IconHookup( thisFeature.PortraitIndex, portraitSize, thisFeature.IconAtlas, Controls.Portrait ) then
					Controls.PortraitFrame:SetHide( false );
				else
					Controls.PortraitFrame:SetHide( true );
				end

				local buttonAdded = 0;
		 		local condition = "FeatureType = '" .. thisFeature.Type .. "'";
				
				-- City Yield
				Controls.YieldFrame:SetHide( false );
				local yieldLines = {};
				for row in GameInfo.Feature_YieldChanges( condition ) do
					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", row.Yield, GameInfo.Yields[row.YieldType].IconString, GameInfo.Yields[row.YieldType].Description));
				end				
				-- add Health
				if thisFeature.InBorderHealth and thisFeature.InBorderHealth ~= 0 then
					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", thisFeature.InBorderHealth, "[ICON_HEALTH_1]", "TXT_KEY_TOPIC_HEALTH"));
				end

				if #yieldLines > 0 then
					ShowAndSizeFrameToText( Locale.ConvertTextKey( table.concat(yieldLines, ", ") ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
				else
					ShowAndSizeFrameToText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_NO_YIELD" ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
				end
				
				-- Movement
				Controls.MovementCostFrame:SetHide( false );
				local moveCost = thisFeature.Movement;
				if thisFeature.Impassable then
					Controls.MovementCostLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPASSABLE" ) );
				elseif (moveCost ~= nil and tonumber(moveCost) ~= 0) then
					Controls.MovementCostLabel:SetText( Locale.ConvertTextKey( moveCost ).."[ICON_MOVES]" );
				else
					Controls.MovementCostFrame:SetHide( true );
				end

				-- Combat Modifier
				Controls.CombatModFrame:SetHide( false );
				if (thisFeature.Defense ~= 0  or thisFeature.Type == "FEATURE_RIVER") then
					local defense = thisFeature.Defense;
					if(thisFeature.Type == "FEATURE_RIVER") then
						local additionalModifier = GameDefines.RIVER_ATTACK_MODIFIER;
						if(additionalModifier ~= nil) then
							defense = defense + additionalModifier;
						end
					end

					local combatModString = tostring(defense) .. "%";
					if(defense > 0) then
						combatModString = "+" .. combatModString;
					end 
					Controls.CombatModLabel:SetText( combatModString );
				else
					Controls.CombatModFrame:SetHide( true );
				end

				-- Features that can exist on this terrain
 				g_FeaturesManager:DestroyInstances();
				buttonAdded = 0;
				for row in GameInfo.Feature_TerrainBooleans( condition ) do
					local thisTerrain = GameInfo.Features[row.TerrainType];
					if thisTerrain then
						local thisTerrainInstance = g_FeaturesManager:GetInstance();
						if thisTerrainInstance then
							local textureOffset, textureSheet = IconLookup( thisTerrain.PortraitIndex, buttonSize, thisTerrain.IconAtlas );				
							if textureOffset == nil then
								textureSheet = defaultErrorTextureSheet;
								textureOffset = nullOffset;
							end				
							UpdateSmallButton( buttonAdded, thisTerrainInstance.FeatureImage, thisTerrainInstance.FeatureButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisTerrain.Description ), thisTerrain.ID );
							buttonAdded = buttonAdded + 1;
						end
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.TerrainsInnerFrame, Controls.TerrainsFrame );	 	  

				-- Resources that can exist on this feature
				Controls.ResourcesFoundLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCESFOUND_LABEL" ) );
  				g_ResourcesFoundManager:DestroyInstances();
				buttonAdded = 0;
				for row in GameInfo.Resource_FeatureBooleans( condition ) do
					local thisResource = GameInfo.Resources[row.ResourceType];
					if thisResource and thisResource.ShowInCivilopedia then
						local thisResourceInstance = g_ResourcesFoundManager:GetInstance();
						if thisResourceInstance then
							local textureOffset, textureSheet = IconLookup( thisResource.PortraitIndex, buttonSize, thisResource.IconAtlas );				
							if textureOffset == nil then
								textureSheet = defaultErrorTextureSheet;
								textureOffset = nullOffset;
							end				
							UpdateSmallButton( buttonAdded, thisResourceInstance.ResourceFoundImage, thisResourceInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( thisResource.Description ), thisResource.ID );
							buttonAdded = buttonAdded + 1;
						end
					end
				end
				UpdateButtonFrame( buttonAdded, Controls.ResourcesFoundInnerFrame, Controls.ResourcesFoundFrame );	 	  

				if(featureID < 1000) then
					-- generic text
					if (thisFeature.Help) then
						UpdateTextBlock( Locale.ConvertTextKey( thisFeature.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
					end
					
					if (thisFeature.Civilopedia) then
						UpdateTextBlock( Locale.ConvertTextKey( thisFeature.Civilopedia ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
					end			
				else
					if (thisFeature.Civilopedia) then
						UpdateTextBlock( Locale.ConvertTextKey( thisFeature.Civilopedia ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
					end				
				end
				
				-- update the related images
				Controls.RelatedImagesFrame:SetHide( true );
			end

		end
	end

	ResizeEtc();

end


CivilopediaCategory[CategoryResources].SelectArticle = function( resourceID, shouldAddToList )
	print("CivilopediaCategory[CategoryResources].SelectArticle");
	if m_selectedCategory ~= CategoryResources then
		SetSelectedCategory(CategoryResources, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryResources, resourceID );
	end

	if resourceID ~= -1 then
	
		local thisResource = GameInfo.Resources[resourceID];
		if thisResource and thisResource.ShowInCivilopedia then

			-- update the name
			local name = Locale.ConvertTextKey( thisResource.Description )
			Controls.ArticleID:SetText( name );

			-- update the portrait
			if IconHookup( thisResource.PortraitIndex, portraitSize, thisResource.IconAtlas, Controls.Portrait ) then
				Controls.PortraitFrame:SetHide( false );
			else
				Controls.PortraitFrame:SetHide( true );
			end

			local buttonAdded = 0;
	 		local condition = "ResourceType = '" .. thisResource.Type .. "'";
			
			-- tech visibility
			g_RevealTechsManager:DestroyInstances();
			buttonAdded = 0;
			if thisResource.TechReveal then
				local prereq = GameInfo.Technologies[thisResource.TechReveal];
				local thisPrereqInstance = g_RevealTechsManager:GetInstance();
				if thisPrereqInstance then
					local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisPrereqInstance.RevealTechImage, thisPrereqInstance.RevealTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
					buttonAdded = buttonAdded + 1;
				end			
				UpdateButtonFrame( buttonAdded, Controls.RevealTechsInnerFrame, Controls.RevealTechsFrame );
			end

			-- City Yield
			Controls.YieldFrame:SetHide( false );
			
			local yieldLines = {};
			for row in GameInfo.Resource_YieldChanges( condition ) do
				if row.Yield > 0 then
					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", row.Yield, GameInfo.Yields[row.YieldType].IconString, GameInfo.Yields[row.YieldType].Description));
				end
			end

			if #yieldLines > 0 then
				ShowAndSizeFrameToText( Locale.ConvertTextKey( table.concat(yieldLines, ", ") ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
			else
				ShowAndSizeFrameToText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_NO_YIELD" ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
			end

			-- found on
				Controls.ResourcesFoundLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAINS_LABEL" ) );
			g_ResourcesFoundManager:DestroyInstances(); -- okay, this is supposed to be a resource, but for now a round button is a round button
			buttonAdded = 0;
			for row in GameInfo.Resource_FeatureBooleans( condition ) do
				local thisFeature = GameInfo.Features[row.FeatureType];
				if thisFeature then
					local thisFeatureInstance = g_ResourcesFoundManager:GetInstance();
					if thisFeatureInstance then
						local textureOffset, textureSheet = IconLookup( thisFeature.PortraitIndex, buttonSize, thisFeature.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisFeatureInstance.ResourceFoundImage, thisFeatureInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisFeature.Description ), thisFeature.ID + 1000 ); -- todo: add a fudge factor
						buttonAdded = buttonAdded + 1;
					end
				end
			end
			
			local bAlreadyShowingHills = false;
			for row in GameInfo.Resource_TerrainBooleans( condition ) do
				local thisTerrain = GameInfo.Terrains[row.TerrainType];
				if thisTerrain then
					local thisTerrainInstance = g_ResourcesFoundManager:GetInstance();
					if thisTerrainInstance then
						if(row.TerrainType == "TERRAIN_HILL") then
							bAlreadyShowingHills = true;
						end
					
						local textureOffset, textureSheet = IconLookup( thisTerrain.PortraitIndex, buttonSize, thisTerrain.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisTerrainInstance.ResourceFoundImage, thisTerrainInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisTerrain.Description ), thisTerrain.ID );
						buttonAdded = buttonAdded + 1;
					end
				end
			end
			-- hackery for hills
			if thisResource and thisResource.Hills and not bAlreadyShowingHills then
				local thisTerrain = GameInfo.Terrains["TERRAIN_HILL"];
				local thisTerrainInstance = g_ResourcesFoundManager:GetInstance();
				if thisTerrainInstance then
					local textureOffset, textureSheet = IconLookup( thisTerrain.PortraitIndex, buttonSize, thisTerrain.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisTerrainInstance.ResourceFoundImage, thisTerrainInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisTerrain.Description ), thisTerrain.ID );
					buttonAdded = buttonAdded + 1;
				end
			end
			UpdateButtonFrame( buttonAdded, Controls.ResourcesFoundInnerFrame, Controls.ResourcesFoundFrame );	 	  
			
			-- improvement
			g_ImprovementsManager:DestroyInstances();
			buttonAdded = 0;
			for row in GameInfo.Improvement_ResourceTypes( condition ) do
				local thisImprovement = GameInfo.Improvements[row.ImprovementType];
				if thisImprovement then
					local thisImprovementInstance = g_ImprovementsManager:GetInstance();
					if thisImprovementInstance then
						local textureOffset, textureSheet = IconLookup( thisImprovement.PortraitIndex, buttonSize, thisImprovement.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisImprovementInstance.ImprovementImage, thisImprovementInstance.ImprovementButton, textureSheet, textureOffset, CategoryImprovements, Locale.ConvertTextKey( thisImprovement.Description ), thisImprovement.ID );
						buttonAdded = buttonAdded + 1;
					end
				end
			end
			UpdateButtonFrame( buttonAdded, Controls.ImprovementsInnerFrame, Controls.ImprovementsFrame );	 	  
			
			-- game info
			if (thisResource.Help) then
				UpdateTextBlock( Locale.ConvertTextKey( thisResource.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
			end

			-- generic text
			if (thisResource.Civilopedia) then
				UpdateTextBlock( Locale.ConvertTextKey( thisResource.Civilopedia ), Controls.HistoryLabel, Controls.HistoryInnerFrame, Controls.HistoryFrame );
			end

			
			
			-- update the related images
			Controls.RelatedImagesFrame:SetHide( true );
		end
	end

	ResizeEtc();

end


CivilopediaCategory[CategoryImprovements].SelectArticle = function( improvementID, shouldAddToList )
	print("CivilopediaCategory[CategoryImprovements].SelectArticle");
	if m_selectedCategory ~= CategoryImprovements then
		SetSelectedCategory(CategoryImprovements, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryImprovements, improvementID );
	end

	if improvementID ~= -1 and improvementID < 1000 then
	
		local thisImprovement = GameInfo.Improvements[improvementID];
		if thisImprovement then

			-- update the name
			local name = Locale.ConvertTextKey( thisImprovement.Description )
			Controls.ArticleID:SetText( name );

			-- update the portrait
			if IconHookup( thisImprovement.PortraitIndex, portraitSize, thisImprovement.IconAtlas, Controls.Portrait ) then
				Controls.PortraitFrame:SetHide( false );
			else
				Controls.PortraitFrame:SetHide( true );
			end

			local buttonAdded = 0;
	 		local condition = "ImprovementType = '" .. thisImprovement.Type .. "'";
			
			-- tech visibility
			g_PrereqTechManager:DestroyInstances();
			buttonAdded = 0;

			local prereq = nil;
			for row in GameInfo.Builds( condition ) do
				if row.PrereqTech then
					prereq = GameInfo.Technologies[row.PrereqTech];
				end
			end
			
			if prereq then
				local thisPrereqInstance = g_PrereqTechManager:GetInstance();
				if thisPrereqInstance then
					local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisPrereqInstance.PrereqTechImage, thisPrereqInstance.PrereqTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
					buttonAdded = buttonAdded + 1;
					UpdateButtonFrame( buttonAdded, Controls.PrereqTechInnerFrame, Controls.PrereqTechFrame );
				end
			end

			-- Yield
			local yieldLines = {};
			for row in GameInfo.Improvement_Yields( condition ) do
				if row.Yield > 0 then
					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", row.Yield, GameInfo.Yields[row.YieldType].IconString, GameInfo.Yields[row.YieldType].Description));
				end
			end

			-- Yield on particular resources
			for row in GameInfo.Improvement_ResourceType_Yields( condition ) do
				if row.Yield > 0 then
					local yieldInfo = GameInfo.Yields[row.YieldType];
					local resourceInfo = GameInfo.Resources[row.ResourceType];
					if (yieldInfo ~= nil and resourceInfo ~= nil) then
						InsertYieldString(yieldLines, "TXT_KEY_YIELD_FROM_SPECIFIC_ICON_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_ICON_OBJECT", row.Yield, yieldInfo.IconString, yieldInfo.Description, resourceInfo.Description, resourceInfo.IconString );
					end
				end
			end

			-- City Strength / HP
			local iCityHP = thisImprovement.CityHP;
			if(iCityHP > 0) then
				table.insert(yieldLines, Locale.Lookup("TXT_KEY_PRODUCTION_BUILDING_HITPOINTS_TT", iCityHP));
			end

			-- add in mountain adjacency yield
			for row in GameInfo.Improvement_AdjacentMountainYieldChanges( condition ) do
				if row.Yield > 0 then
					table.insert(yieldLines, Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", row.Yield, GameInfo.Yields[row.YieldType].IconString, GameInfo.Yields[row.YieldType].Description));
				end
			end

			if #yieldLines > 0 then
				ShowAndSizeFrameToText( Locale.ConvertTextKey( table.concat(yieldLines, "[NEWLINE]") ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame  );
			else
				ShowAndSizeFrameToText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_NO_YIELD" ), Controls.YieldLabel, Controls.YieldInnerFrame, Controls.YieldFrame );
			end
			
			buttonAdded = 0;
			if thisImprovement.CivilizationType then
				local thisCiv = GameInfo.Civilizations[thisImprovement.CivilizationType];
				if thisCiv then
					g_CivilizationsManager:DestroyInstances();
					local thisCivInstance = g_CivilizationsManager:GetInstance();
					if thisCivInstance then
						local textureOffset, textureSheet = IconLookup( thisCiv.PortraitIndex, buttonSize, thisCiv.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisCivInstance.CivilizationImage, thisCivInstance.CivilizationButton, textureSheet, textureOffset, CategoryCivilizations, Locale.ConvertTextKey( thisCiv.ShortDescription ), thisCiv.ID );
						buttonAdded = buttonAdded + 1;
					end	
				end
			end
			UpdateButtonFrame( buttonAdded, Controls.CivilizationsInnerFrame, Controls.CivilizationsFrame );
			
			-- found on
			local foundKey = (thisImprovement.Goody or thisImprovement.IgnoreOwnership) and "TXT_KEY_PEDIA_TERRAINS_LABEL" or "TXT_KEY_PEDIA_FOUNDON_LABEL";
			Controls.ResourcesFoundLabel:SetText( Locale.ConvertTextKey(foundKey) );
			g_ResourcesFoundManager:DestroyInstances(); -- okay, this is supposed to be a resource, but for now a round button is a round button
			buttonAdded = 0;
			for row in GameInfo.Improvement_ValidFeatures( condition ) do
				local thisFeature = GameInfo.Features[row.FeatureType];
				if thisFeature then
					local thisFeatureInstance = g_ResourcesFoundManager:GetInstance();
					if thisFeatureInstance then
						local textureOffset, textureSheet = IconLookup( thisFeature.PortraitIndex, buttonSize, thisFeature.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisFeatureInstance.ResourceFoundImage, thisFeatureInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisFeature.Description ), thisFeature.ID + 1000 ); -- todo: add a fudge factor
						buttonAdded = buttonAdded + 1;
					end
				end
			end
			for row in GameInfo.Improvement_ValidTerrains( condition ) do
				local thisTerrain = GameInfo.Terrains[row.TerrainType];
				if thisTerrain then
					local thisTerrainInstance = g_ResourcesFoundManager:GetInstance();
					if thisTerrainInstance then
						local textureOffset, textureSheet = IconLookup( thisTerrain.PortraitIndex, buttonSize, thisTerrain.IconAtlas );				
						if textureOffset == nil then
							textureSheet = defaultErrorTextureSheet;
							textureOffset = nullOffset;
						end				
						UpdateSmallButton( buttonAdded, thisTerrainInstance.ResourceFoundImage, thisTerrainInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisTerrain.Description ), thisTerrain.ID );
						buttonAdded = buttonAdded + 1;
					end
				end
			end
			-- hackery for hills
			--if thisImprovement and thisImprovement.HillsMakesValid then
				--local thisTerrain = GameInfo.Terrains["TERRAIN_HILL"];
				--local thisTerrainInstance = g_ResourcesFoundManager:GetInstance();
				--if thisTerrainInstance then
					--local textureSheet;
					--local textureOffset;
					--textureSheet = defaultErrorTextureSheet;
					--textureOffset = nullOffset;
					--UpdateSmallButton( buttonAdded, thisTerrainInstance.ResourceFoundImage, thisTerrainInstance.ResourceFoundButton, textureSheet, textureOffset, CategoryTerrain, Locale.ConvertTextKey( thisTerrain.Description ), thisTerrain.ID );
					--buttonAdded = buttonAdded + 1;
				--end
			--end
			UpdateButtonFrame( buttonAdded, Controls.ResourcesFoundInnerFrame, Controls.ResourcesFoundFrame );	 	  
			
			-- Required resource
			Controls.RequiredResourcesLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPROVES_RESRC_LABEL" ) );
			g_RequiredResourcesManager:DestroyInstances();
			buttonAdded = 0;
			if thisImprovement.Type ~= "IMPROVEMENT_EXPEDITION" then
				for row in GameInfo.Improvement_ResourceTypes( condition ) do
					local requiredResource = GameInfo.Resources[row.ResourceType];
					if requiredResource and requiredResource.ShowInCivilopedia then
						local thisRequiredResourceInstance = g_RequiredResourcesManager:GetInstance();
						if thisRequiredResourceInstance then
							local textureOffset, textureSheet = IconLookup( requiredResource.PortraitIndex, buttonSize, requiredResource.IconAtlas );				
							if textureOffset == nil then
								textureSheet = defaultErrorTextureSheet;
								textureOffset = nullOffset;
							end				
							UpdateSmallButton( buttonAdded, thisRequiredResourceInstance.RequiredResourceImage, thisRequiredResourceInstance.RequiredResourceButton, textureSheet, textureOffset, CategoryResources, Locale.ConvertTextKey( requiredResource.Description ), requiredResource.ID );
							buttonAdded = buttonAdded + 1;
						end
					end		
				end
			end
			UpdateButtonFrame( buttonAdded, Controls.RequiredResourcesInnerFrame, Controls.RequiredResourcesFrame );

			-- update the maintenance
			local energyMaintenance = thisImprovement.EnergyMaintenance;
			if energyMaintenance > 0 then
				Controls.MaintenanceLabel:SetText( tostring(energyMaintenance).." [ICON_ENERGY]" );
				Controls.MaintenanceFrame:SetHide( false );
			end

			-- update the Health
			local iHealth = thisImprovement.Health;
			local iUnhealth = thisImprovement.Unhealth;
			if iHealth > 0 then
				Controls.HealthLabel:SetText( tostring(iHealth).." [ICON_HEALTH_1]" );
				Controls.HealthFrame:SetHide( false );
			elseif iUnhealth > 0 then
				Controls.HealthLabel:SetText( tostring(iUnhealth).." [ICON_HEALTH_4]" );
				Controls.HealthFrame:SetHide( false );
			end

			-- update the game info
			if (thisImprovement.Help) then
				UpdateTextBlock( Locale.ConvertTextKey( thisImprovement.Help ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
			end

			-- generic text
			if (thisImprovement.Civilopedia) then
				UpdateTextBlock( Locale.ConvertTextKey( thisImprovement.Civilopedia ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
			end
			
			-- update the related images
			Controls.RelatedImagesFrame:SetHide( true );
		end
	--Roads and Magrail
	elseif improvementID ~= -1 then
	
		improvementID = improvementID - 1000;
		local thisImprovement = GameInfo.Routes[improvementID];
		if thisImprovement then

			-- update the name
			local name = Locale.ConvertTextKey( thisImprovement.Description )
			Controls.ArticleID:SetText( name );

			if IconHookup( thisImprovement.PortraitIndex, portraitSize, thisImprovement.IconAtlas, Controls.Portrait ) then
				Controls.PortraitFrame:SetHide( false );
			else
				Controls.PortraitFrame:SetHide( true );
			end

			local buttonAdded = 0;
	 		local condition = "RouteType = '" .. thisImprovement.Type .. "'";
			
			-- tech visibility
			g_PrereqTechManager:DestroyInstances();
			buttonAdded = 0;

			local prereq = nil;
			for row in GameInfo.Builds( condition ) do
				if row.PrereqTech then
					prereq = GameInfo.Technologies[row.PrereqTech];
				end
			end
			
			if prereq then
				local thisPrereqInstance = g_PrereqTechManager:GetInstance();
				if thisPrereqInstance then
					local textureOffset, textureSheet = IconLookup( prereq.PortraitIndex, buttonSize, prereq.IconAtlas );				
					if textureOffset == nil then
						textureSheet = defaultErrorTextureSheet;
						textureOffset = nullOffset;
					end				
					UpdateSmallButton( buttonAdded, thisPrereqInstance.PrereqTechImage, thisPrereqInstance.PrereqTechButton, textureSheet, textureOffset, CategoryTech, Locale.ConvertTextKey( prereq.Description ), prereq.ID );
					buttonAdded = buttonAdded + 1;
					UpdateButtonFrame( buttonAdded, Controls.PrereqTechInnerFrame, Controls.PrereqTechFrame );
				end
			end

			-- generic text
			if (thisImprovement.Civilopedia) then
				UpdateTextBlock( Locale.ConvertTextKey( thisImprovement.Civilopedia ), Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
			end
			
			-- update the related images
			Controls.RelatedImagesFrame:SetHide( true );
		end
	end

	ResizeEtc();
end

CivilopediaCategory[CategoryAffinities].SelectArticle = function(conceptID, shouldAddToList)
	print("CivilopediaCategory[CategoryAffinities].SelectArticle");
	if m_selectedCategory ~= CategoryAffinities then
		SetSelectedCategory(CategoryAffinities, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryAffinities, conceptID );
	end
	
	if conceptID ~= -1 then
		local thisConcept = GameInfo.Concepts[conceptID];
		
		if thisConcept then
		
			-- update the name
			local name = Locale.ConvertTextKey( thisConcept.Description ); 	
			Controls.ArticleID:SetText( name );
			
			-- portrait
			
			-- update the summary
			if thisConcept.Summary then
				UpdateSuperWideTextBlock( Locale.ConvertTextKey( thisConcept.Summary ), Controls.SummaryLabel, Controls.SummaryInnerFrame, Controls.SummaryFrame );
			end

			-- game info
			local gameInfoText = "";
			if (thisConcept.Type == "CONCEPT_AFFINITY_HARMONY") then
				gameInfoText =  GetHelpTextForAffinity(GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID, nil);
			elseif (thisConcept.Type == "CONCEPT_AFFINITY_PURITY") then
				gameInfoText =  GetHelpTextForAffinity(GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID, nil);
			elseif (thisConcept.Type == "CONCEPT_AFFINITY_SUPREMACY") then
				gameInfoText =  GetHelpTextForAffinity(GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID, nil);
			end
			if (gameInfoText ~= "") then
				UpdateSuperWideTextBlock( gameInfoText, Controls.GameInfoLabel, Controls.GameInfoInnerFrame, Controls.GameInfoFrame );
			end
			
			-- related images
			
			-- related concepts
		
		end

	end	

	ResizeEtc();
end

CivilopediaCategory[CategoryStations].SelectArticle = function(conceptID, shouldAddToList)
		print("CivilopediaCategory[CategoryStations].SelectArticle");
	if m_selectedCategory ~= CategoryStations then
		SetSelectedCategory(CategoryStations, dontAddToList);
	end
	
	ClearArticle();
	
	if shouldAddToList == addToList then
		AddToNavigationHistory( CategoryStations, conceptID );
	end
	
	if conceptID ~= -1 then
		local thisConcept = GameInfo.Concepts[conceptID];
		
		if thisConcept then
		
			-- update the name
			local name = Locale.ConvertTextKey( thisConcept.Description ); 	
			Controls.ArticleID:SetText( name );
			
			-- portrait
			
			-- update the summary
			if thisConcept.Summary then
				UpdateSuperWideTextBlock( Locale.ConvertTextKey( thisConcept.Summary ), Controls.SummaryLabel, Controls.SummaryInnerFrame, Controls.SummaryFrame );
			end
						
			-- related images
			
			-- related concepts
		
		end

	end	

	ResizeEtc();
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function SortFunction( a, b )

    local aVal = otherSortedList[ tostring( a ) ];
    local bVal = otherSortedList[ tostring( b ) ];
    
    if (aVal == nil) or (bVal == nil) then 
		--print("nil : "..tostring( a ).." = "..tostring(aVal).." : "..tostring( b ).." = "..tostring(bVal))
		if aVal and (bVal == nil) then
			return false;
		elseif (aVal == nil) and bVal then
			return true;
		else
			return tostring(a) < tostring(b); -- gotta do something deterministic
        end;
    else
        return aVal < bVal;
    end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

CivilopediaCategory[CategoryMain].SelectHeading = function( selectedEraID, dummy )
	print("CivilopediaCategory[CategoryMain].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first era
	--local thisListInstance = g_ListItemManager:GetInstance();
	--if thisListInstance then
	--	sortOrder = sortOrder + 1;
	--	thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_HOME_PAGE_LABEL" ));
	--	thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
	--	thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryMain].buttonClicked );
	--	thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
	--	otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	--end
	
	Controls.ListOfArticles:CalculateSize();
	Controls.ScrollPanel:CalculateInternalSize();
end

CivilopediaCategory[CategoryConcepts].SelectHeading = function( selectedEraID, dummy )
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryConcepts][selectedEraID].headingOpen = not sortedList[CategoryConcepts][selectedEraID].headingOpen; -- ain't lua great
--start working here on making the display not f up when closes

	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first era
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_GAME_CONCEPT_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryConcepts].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	local numConcepts = #sortedList[CategoryConcepts];
	for section = 1, numConcepts, 1 do	
		-- add a section header
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortOrder = sortOrder + 1;
			if sortedList[CategoryConcepts][section].headingOpen then
				local textString = "TXT_KEY_GAME_CONCEPT_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local textString = "TXT_KEY_GAME_CONCEPT_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			end
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryConcepts].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		if sortedList[CategoryConcepts][section].headingOpen then
			for i, v in ipairs(sortedList[CategoryConcepts][section]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryConcepts].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end
	end
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
end

CivilopediaCategory[CategoryTech].SelectHeading = function( selectedEraID, dummy )
	print("CivilopediaCategory[CategoryTech].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryTech].headingOpen = not sortedList[CategoryTech].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first era
	local thisTechInstance = g_ListItemManager:GetInstance();
	if thisTechInstance then
		sortOrder = sortOrder + 1;
		thisTechInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TECH_PAGE_LABEL" ));
		thisTechInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisTechInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTech].buttonClicked );
		thisTechInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisTechInstance.ListItemButton )] = sortOrder;
	end

	-- for each element of the sorted list		
	if sortedList[CategoryTech].headingOpen then
		for i, v in ipairs(sortedList[CategoryTech]) do
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTech].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end
	end
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryUnits].SelectHeading = function( selectedEraID, dummy )
	print("CivilopediaCategory[CategoryUnits].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryUnits][selectedEraID].headingOpen = not sortedList[CategoryUnits][selectedEraID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first era
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_UNITS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUnits].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	function PopulateHeaderAndItems(categoryID)
		-- for each element of the sorted list		
		if sortedList[CategoryUnits].headingOpen then
			for i, v in ipairs(sortedList[CategoryUnits]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUnits].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end
	end
	
	PopulateHeaderAndItems(0)
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();	
end

CivilopediaCategory[CategoryUpgrades].SelectHeading = function( selectedSection, dummy )
	print("CivilopediaCategory[CategoryUpgrades].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryUpgrades][selectedSection].headingOpen = not sortedList[CategoryUpgrades][selectedSection].headingOpen; -- ain't lua great

	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first era
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_UPGRADES_HEADING1_TITLE" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUpgrades].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for unitIndex = 1, #sortedList[CategoryUpgrades], 1 do
		if (sortedList[CategoryUpgrades][unitIndex][1] ~= nil) then
			-- add a section header
			local thisHeaderInstance = g_ListHeadingManager:GetInstance();
			if thisHeaderInstance then
				sortOrder = sortOrder + 1;
				local upgradeInfo = GameInfo.UnitUpgrades[sortedList[CategoryUpgrades][unitIndex][1].entryID];
				local unitInfo = GameInfo.Units[upgradeInfo.UnitType];
				local text = Locale.ConvertTextKey(unitInfo.Description);
				if sortedList[CategoryUpgrades][unitIndex].headingOpen then
					text = "[ICON_MINUS] " .. text;
				else
					text = "[ICON_PLUS] " .. text;
				end
				thisHeaderInstance.ListHeadingLabel:SetText(text);
				thisHeaderInstance.ListHeadingButton:SetVoids( unitIndex, 0 );
				thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUpgrades].SelectHeading );
				otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
			end

			-- for each element of the sorted list
			if sortedList[CategoryUpgrades][unitIndex].headingOpen then
				for i, v in ipairs(sortedList[CategoryUpgrades][unitIndex]) do
					local thisListInstance = g_ListItemManager:GetInstance();
					if thisListInstance then
						sortOrder = sortOrder + 1;
						thisListInstance.ListItemLabel:SetText( v.entryName );
						thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
						thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUpgrades].SelectArticle );
						thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
						otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
					end
				end
			end
		end
	end
	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();

end

CivilopediaCategory[CategoryBuildings].SelectHeading = function( selectedEraID, dummy )
	print("CivilopediaCategory[CategoryBuildings].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryBuildings][selectedEraID].headingOpen = not sortedList[CategoryBuildings][selectedEraID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first era
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_BUILDINGS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	function PopulateAndAdd(categoryID)

		-- for each element of the sorted list		
		if sortedList[CategoryBuildings].headingOpen then
			for i, v in ipairs(sortedList[CategoryBuildings]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end
	end

	PopulateAndAdd(0);
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();	
end


CivilopediaCategory[CategoryWonders].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryWonders].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryWonders][selectedSectionID].headingOpen = not sortedList[CategoryWonders][selectedSectionID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_WONDERS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 1, 3, 1 do	
		-- add a section header
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortOrder = sortOrder + 1;
			if sortedList[CategoryWonders][section].headingOpen then
				local textString = "TXT_KEY_WONDER_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local textString = "TXT_KEY_WONDER_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			end
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		if sortedList[CategoryWonders][section].headingOpen then
			for i, v in ipairs(sortedList[CategoryWonders][section]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end


CivilopediaCategory[CategoryVirtues].SelectHeading = function( selectedBranchID, dummy )
	print("CivilopediaCategory[CategoryVirtues].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryVirtues][selectedBranchID].headingOpen = not sortedList[CategoryVirtues][selectedBranchID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first branch
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_POLICIES_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryVirtues].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for branch in GameInfo.PolicyBranchTypes() do
	
		local branchID = branch.ID;
		-- add a branch header
		local thisHeadingInstance = g_ListHeadingManager:GetInstance();
		if thisHeadingInstance then
			sortOrder = sortOrder + 1;
			if sortedList[CategoryVirtues][branchID].headingOpen then
				local textString = branch.Description;
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeadingInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local textString = branch.Description;
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeadingInstance.ListHeadingLabel:SetText( localizedLabel );
			end
			thisHeadingInstance.ListHeadingButton:SetVoids( branchID, 0 );
			thisHeadingInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryVirtues].SelectHeading );
			otherSortedList[tostring( thisHeadingInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		if sortedList[CategoryVirtues][branchID].headingOpen then
			for i, v in ipairs(sortedList[CategoryVirtues][branchID]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryVirtues].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryEspionage].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryEspionage].SelectHeading");
	error("This method should never be hit as this category has no headings.");	
end


CivilopediaCategory[CategoryCivilizations].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryCivilizations].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryCivilizations][selectedSectionID].headingOpen = not sortedList[CategoryCivilizations][selectedSectionID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_CIVILIZATIONS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryCivilizations].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 1, 2, 1 do	
		-- add a section header
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortOrder = sortOrder + 1;
			if sortedList[CategoryCivilizations][section].headingOpen then
				local textString = "TXT_KEY_CIVILIZATION_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local textString = "TXT_KEY_CIVILIZATION_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			end
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryCivilizations].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		if sortedList[CategoryCivilizations][section].headingOpen then
			for i, v in ipairs(sortedList[CategoryCivilizations][section]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryCivilizations].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end


CivilopediaCategory[CategoryQuests].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryQuests].SelectHeading");
	error("This function should never be hit as this category has no headings.");
end

CivilopediaCategory[CategoryTerrain].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryTerrain].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryTerrain][selectedSectionID].headingOpen = not sortedList[CategoryTerrain][selectedSectionID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTerrain].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 1, 2, 1 do	
		-- add a section header
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortOrder = sortOrder + 1;
			if sortedList[CategoryTerrain][section].headingOpen then
				local textString = "TXT_KEY_TERRAIN_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local textString = "TXT_KEY_TERRAIN_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			end
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTerrain].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		if sortedList[CategoryTerrain][section].headingOpen then
			for i, v in ipairs(sortedList[CategoryTerrain][section]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTerrain].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryResources].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryResources].SelectHeading");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	sortedList[CategoryResources][selectedSectionID].headingOpen = not sortedList[CategoryResources][selectedSectionID].headingOpen; -- ain't lua great
	
	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCES_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryResources].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 0, 2, 1 do	
		-- add a section header
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortOrder = sortOrder + 1;
			if sortedList[CategoryResources][section].headingOpen then
				local textString = "TXT_KEY_RESOURCES_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local textString = "TXT_KEY_RESOURCES_SECTION_"..tostring( section );
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			end
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryResources].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		if sortedList[CategoryResources][section].headingOpen then
			for i, v in ipairs(sortedList[CategoryResources][section]) do
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryResources].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryImprovements].SelectHeading = function( selectedSection, dummy )
	print("CivilopediaCategory[CategoryImprovements].SelectHeading");
	-- todo: implement if there are ever sections in the Improvements page
	print("I should never get here");		
	ResizeEtc();
end

CivilopediaCategory[CategoryAffinities].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryAffinities].SelectHeading");
	error("This function should never be hit as this category has no headings.");
end

CivilopediaCategory[CategoryStations].SelectHeading = function( selectedSectionID, dummy )
	print("CivilopediaCategory[CategoryAffinities].SelectHeading");
	error("This function should never be hit as this category has no headings.");
end


----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------

CivilopediaCategory[CategoryMain].DisplayList = function( selectedSection, dummy )
	print("CivilopediaCategory[CategoryMain].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the rest of the stuff
	--local thisListInstance = g_ListItemManager:GetInstance();
	--if thisListInstance then
	--	sortOrder = sortOrder + 1;
	--	thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_HOME_PAGE_LABEL" ));
	--	thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
	--	thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryMain].buttonClicked );
	--	thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
	--	otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	--end
		-- for each element of the sorted list		
	for i, v in ipairs(sortedList[CategoryMain][1]) do
		-- add an entry
		local thisListInstance = g_ListItemManager:GetInstance();
		if thisListInstance then
			sortOrder = sortOrder + 1;
			thisListInstance.ListItemLabel:SetText( v.entryName );
			thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryMain].SelectArticle );
			thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
			otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
		end
	end
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
end

CivilopediaCategory[CategoryConcepts].DisplayList = function( selectedSection, dummy )
	print("CivilopediaCategory[CategoryConcepts].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};

	-- put in a home page before the rest of the stuff
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_GAME_CONCEPT_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryConcepts].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	-- for each element of the sorted list
	local numSections = #sortedList[CategoryConcepts];
	
	local GameConceptsList = sortedList[CategoryConcepts];
	for section = 1,numSections,1 do
		
		local headingOpen = GameConceptsList[section].headingOpen;
		if(headingOpen == nil) then
			headingOpen = true;
			GameConceptsList[section].headingOpen = true;
		end
	
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
		
			sortOrder = sortOrder + 1;
			local textString = "TXT_KEY_GAME_CONCEPT_SECTION_"..tostring( section );
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryConcepts].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
			
			if(headingOpen == true) then
				local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			else
				local localizedLabel = "[ICON_PLUS] "..Locale.ConvertTextKey( textString );
				thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			end			
		end	
		
		if(headingOpen == true) then
			for i, v in ipairs(sortedList[CategoryConcepts][section]) do
				-- add an entry
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryConcepts].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end
	end
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
	Controls.ScrollPanel:CalculateInternalSize();
end

CivilopediaCategory[CategoryTech].DisplayList = function()
	print("CivilopediaCategory[CategoryTech].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();
	
	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first era
	local thisTechInstance = g_ListItemManager:GetInstance();
	if thisTechInstance then
		sortOrder = sortOrder + 1;
		thisTechInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TECH_PAGE_LABEL" ));
		thisTechInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisTechInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTech].buttonClicked );
		thisTechInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisTechInstance.ListItemButton )] = sortOrder;
	end


	-- for each element of the sorted list		
	for i, v in ipairs(sortedList[CategoryTech]) do
		-- add a tech entry
		local thisTechInstance = g_ListItemManager:GetInstance();
		if thisTechInstance then
			sortOrder = sortOrder + 1;
			thisTechInstance.ListItemLabel:SetText( v.entryName );
			thisTechInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisTechInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTech].SelectArticle );
			thisTechInstance.ListItemButton:SetToolTipCallback( TipHandler );
			otherSortedList[tostring( thisTechInstance.ListItemButton )] = sortOrder;
		end
	end
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
end

CivilopediaCategory[CategoryUnits].DisplayList = function()
	print("CivilopediaCategory[CategoryUnits].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first era
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_UNITS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUnits].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	function PopulateAndAdd(categoryID)

		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryUnits]) do
			-- add a unit entry
			local thisUnitInstance = g_ListItemManager:GetInstance();
			if thisUnitInstance then
				sortOrder = sortOrder + 1;
				thisUnitInstance.ListItemLabel:SetText( v.entryName );
				thisUnitInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisUnitInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUnits].SelectArticle );
				thisUnitInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisUnitInstance.ListItemButton )] = sortOrder;
			end
		end
	end

	PopulateAndAdd(0);
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryUpgrades].DisplayList = function()
	print("start CivilopediaCategory[CategoryUpgrades].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();
	
	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the rest of the stuff
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_UPGRADES_HEADING1_TITLE" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUpgrades].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	-- for each element of the sorted list		
	for unitIndex = 1, #sortedList[CategoryUpgrades], 1 do
		if (sortedList[CategoryUpgrades][unitIndex][1] ~= nil) then
			local thisHeaderInstance = g_ListHeadingManager:GetInstance();
			if thisHeaderInstance then
				sortedList[CategoryUpgrades][unitIndex].headingOpen = true;
				sortOrder = sortOrder + 1;
				local upgradeInfo = GameInfo.UnitUpgrades[sortedList[CategoryUpgrades][unitIndex][1].entryID];
				local unitInfo = GameInfo.Units[upgradeInfo.UnitType];
				local text = "[ICON_MINUS] " .. Locale.ConvertTextKey(unitInfo.Description);
				thisHeaderInstance.ListHeadingLabel:SetText(text);
				thisHeaderInstance.ListHeadingButton:SetVoids( unitIndex, 0 );
				thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUpgrades].SelectHeading );
				otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
			end

			for i, v in ipairs(sortedList[CategoryUpgrades][unitIndex]) do
				-- add an entry
				local thisListInstance = g_ListItemManager:GetInstance();
				if thisListInstance then
					sortOrder = sortOrder + 1;
					thisListInstance.ListItemLabel:SetText( v.entryName );
					thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
					thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryUpgrades].SelectArticle );
					thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
					otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
				end
			end
		end
	end

	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
	Controls.ScrollPanel:CalculateInternalSize();
end

CivilopediaCategory[CategoryBuildings].DisplayList = function()
	print("CivilopediaCategory[CategoryBuildings].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first era
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_BUILDINGS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	function PopulateAndAdd(categoryID)
		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryBuildings]) do
			-- add an entry
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryBuildings].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end
	end

	PopulateAndAdd(0);
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
end

CivilopediaCategory[CategoryWonders].DisplayList = function()
	print("CivilopediaCategory[CategoryWonders].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_WONDERS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 1, 3, 1 do	
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortedList[CategoryWonders][section].headingOpen = true; -- ain't lua great
			sortOrder = sortOrder + 1;
			local textString = "TXT_KEY_WONDER_SECTION_"..tostring( section );
			local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
			thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryWonders][section]) do
			-- add a unit entry
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryWonders].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
	Controls.ScrollPanel:CalculateInternalSize();
		
end

CivilopediaCategory[CategoryVirtues].DisplayList = function()
	print("CivilopediaCategory[CategoryVirtues].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first branch
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_POLICIES_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryVirtues].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for branch in GameInfo.PolicyBranchTypes() do
	
		local branchID = branch.ID;
		-- add a branch header
		local thisHeadingInstance = g_ListHeadingManager:GetInstance();
		if thisHeadingInstance then
			sortedList[CategoryVirtues][branchID].headingOpen = true; -- ain't lua great
			sortOrder = sortOrder + 1;
			local textString = branch.Description;
			local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
			thisHeadingInstance.ListHeadingLabel:SetText( localizedLabel );
			thisHeadingInstance.ListHeadingButton:SetVoids( branchID, 0 );
			thisHeadingInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryVirtues].SelectHeading );
			otherSortedList[tostring( thisHeadingInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryVirtues][branchID]) do
			-- add an entry
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryVirtues].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryEspionage].DisplayList = function()
	print("CivilopediaCategory[CategoryEspionage].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	local espionageLabel = "TXT_KEY_PEDIA_ESPIONAGE_PAGE_LABEL";

	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( espionageLabel ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryEspionage].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	local espionageList = sortedList[CategoryEspionage];
	local onArticleSelect = CivilopediaCategory[CategoryEspionage].SelectArticle
	
	for _, v in ipairs(espionageList) do	

		-- add a unit entry
		local thisListInstance = g_ListItemManager:GetInstance();
		if thisListInstance then
			thisListInstance.ListItemLabel:SetText( v.entryName );
			thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, onArticleSelect );
			thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
			sortOrder = sortOrder + 1;
			otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
		end
	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryCivilizations].DisplayList = function()
	print("CivilopediaCategory[CategoryCivilizations].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_CIVILIZATIONS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryCivilizations].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 1, 2, 1 do	
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortedList[CategoryCivilizations][section].headingOpen = true; -- ain't lua great
			sortOrder = sortOrder + 1;
			local textString = "TXT_KEY_CIVILIZATIONS_SECTION_"..tostring( section );
			local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
			thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryCivilizations].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryCivilizations][section]) do
			-- add a unit entry
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryCivilizations].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryQuests].DisplayList = function()

	print("CivilopediaCategory[CategoryQuests].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	
	local headerlabel = "TXT_KEY_PEDIA_QUESTS_PAGE_LABEL";

	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( headerlabel ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryQuests].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	local espionageList = sortedList[CategoryQuests];
	local onArticleSelect = CivilopediaCategory[CategoryQuests].SelectArticle
	
	for _, v in ipairs(espionageList) do	

		-- add a unit entry
		local thisListInstance = g_ListItemManager:GetInstance();
		if thisListInstance then
			thisListInstance.ListItemLabel:SetText( v.entryName );
			thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, onArticleSelect );
			thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
			sortOrder = sortOrder + 1;
			otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
		end
	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
		
end

CivilopediaCategory[CategoryTerrain].DisplayList = function()
	print("CivilopediaCategory[CategoryTerrain].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_TERRAIN_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTerrain].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 1, 2, 1 do	
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortedList[CategoryTerrain][section].headingOpen = true; -- ain't lua great
			sortOrder = sortOrder + 1;
			local textString = "TXT_KEY_TERRAIN_SECTION_"..tostring( section );
			local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
			thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTerrain].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryTerrain][section]) do
			-- add a unit entry
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryTerrain].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryResources].DisplayList = function()
	print("CivilopediaCategory[CategoryResources].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_RESOURCES_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryResources].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	for section = 0, 2, 1 do	
		local thisHeaderInstance = g_ListHeadingManager:GetInstance();
		if thisHeaderInstance then
			sortedList[CategoryResources][section].headingOpen = true; -- ain't lua great
			sortOrder = sortOrder + 1;
			local textString = "TXT_KEY_RESOURCES_SECTION_"..tostring( section );
			local localizedLabel = "[ICON_MINUS] "..Locale.ConvertTextKey( textString );
			thisHeaderInstance.ListHeadingLabel:SetText( localizedLabel );
			thisHeaderInstance.ListHeadingButton:SetVoids( section, 0 );
			thisHeaderInstance.ListHeadingButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryResources].SelectHeading );
			otherSortedList[tostring( thisHeaderInstance.ListHeadingButton )] = sortOrder;
		end	
		
		-- for each element of the sorted list		
		for i, v in ipairs(sortedList[CategoryResources][section]) do
			-- add a unit entry
			local thisListInstance = g_ListItemManager:GetInstance();
			if thisListInstance then
				sortOrder = sortOrder + 1;
				thisListInstance.ListItemLabel:SetText( v.entryName );
				thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
				thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryResources].SelectArticle );
				thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
				otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
			end
		end

	end	
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();
		
end

CivilopediaCategory[CategoryImprovements].DisplayList = function()
	print("start CivilopediaCategory[CategoryImprovements].DisplayList");
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();
	
	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the rest of the stuff
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_IMPROVEMENTS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryImprovements].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end
	
	-- for each element of the sorted list		
	for i, v in ipairs(sortedList[CategoryImprovements][1]) do
		-- add an entry
		local thisListInstance = g_ListItemManager:GetInstance();
		if thisListInstance then
			sortOrder = sortOrder + 1;
			thisListInstance.ListItemLabel:SetText( v.entryName );
			thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryImprovements].SelectArticle );
			thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
			otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
		end
	end
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();

end

CivilopediaCategory[CategoryAffinities].DisplayList = function()
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_AFFINITIES_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryAffinities].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	-- for each element of the sorted list		
	for i, v in ipairs(sortedList[CategoryAffinities]) do
		-- add a unit entry
		local thisListInstance = g_ListItemManager:GetInstance();
		if thisListInstance then
			sortOrder = sortOrder + 1;
			thisListInstance.ListItemLabel:SetText( v.entryName );
			thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, function(dummy, shouldAddToList) CivilopediaCategory[CategoryAffinities].SelectArticle(v.entryID, shouldAddToList); end);
			thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
			otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
		end
	end
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();

end

CivilopediaCategory[CategoryStations].DisplayList = function()
	g_ListHeadingManager:DestroyInstances();
	g_ListItemManager:DestroyInstances();

	local sortOrder = 0;
	otherSortedList = {};
	
	-- put in a home page before the first section
	local thisListInstance = g_ListItemManager:GetInstance();
	if thisListInstance then
		sortOrder = sortOrder + 1;
		thisListInstance.ListItemLabel:SetText( Locale.ConvertTextKey( "TXT_KEY_PEDIA_STATIONS_PAGE_LABEL" ));
		thisListInstance.ListItemButton:SetVoids( homePageOfCategoryID, addToList );
		thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, CivilopediaCategory[CategoryStations].buttonClicked );
		thisListInstance.ListItemButton:SetToolTipCallback( TipHandler );
		otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
	end

	-- for each element of the sorted list		
	for i, v in ipairs(sortedList[CategoryStations]) do
		-- add a unit entry
		local thisListInstance = g_ListItemManager:GetInstance();
		if thisListInstance then
			sortOrder = sortOrder + 1;
			thisListInstance.ListItemLabel:SetText( v.entryName );
			thisListInstance.ListItemButton:SetVoids( v.entryID, addToList );
			thisListInstance.ListItemButton:RegisterCallback( Mouse.eLClick, function(dummy, shouldAddToList) CivilopediaCategory[CategoryStations].SelectArticle(v.entryID, shouldAddToList); end);
			thisListInstance.ListItemButton:SetToolTipCallback( TipHandler )
			otherSortedList[tostring( thisListInstance.ListItemButton )] = sortOrder;
		end
	end
	
	Controls.ListOfArticles:SortChildren( SortFunction );
	ResizeEtc();

end


-- ===========================================================================
-- ===========================================================================
function ClearArticle()
	Controls.ScrollPanel:SetScrollValue( 0 );
	Controls.PortraitFrame:SetHide( true );
	Controls.CostFrame:SetHide( true );
	Controls.MaintenanceFrame:SetHide( true );
	Controls.HealthFrame:SetHide( true );
	Controls.CultureFrame:SetHide( true );
	Controls.FaithFrame:SetHide( true );
	Controls.DefenseFrame:SetHide( true );
	Controls.FoodFrame:SetHide( true );
	Controls.GoldFrame:SetHide( true );
	Controls.ScienceFrame:SetHide( true );
	Controls.ProductionFrame:SetHide( true );
	Controls.CombatFrame:SetHide( true );
	Controls.RangedCombatFrame:SetHide( true );
	Controls.RangedCombatRangeFrame:SetHide( true );
	Controls.MovementFrame:SetHide( true );
	Controls.OrbitalEffectRangeFrame:SetHide(true);
	Controls.OrbitalTurnDurationFrame:SetHide(true);
	Controls.FreePromotionsFrame:SetHide( true );
	Controls.PrereqTechFrame:SetHide( true );
	Controls.LeadsToTechFrame:SetHide( true );
	Controls.ObsoleteTechFrame:SetHide( true );
	Controls.UpgradeFrame:SetHide( true );
	Controls.UnlockedUnitsFrame:SetHide( true );
	Controls.UnlockedBuildingsFrame:SetHide( true );
	Controls.RequiredBuildingsFrame:SetHide( true );
	Controls.RevealedResourcesFrame:SetHide( true );
	Controls.RequiredResourcesFrame:SetHide( true );
	Controls.RequiredPromotionsFrame:SetHide( true );
	Controls.LocalResourcesFrame:SetHide( true );
	Controls.WorkerActionsFrame:SetHide( true );
	Controls.UnlockedProjectsFrame:SetHide( true );
	Controls.SpecialistsFrame:SetHide( true );
	Controls.RelatedArticlesFrame:SetHide( true );
	Controls.GameInfoFrame:SetHide( true );
	Controls.QuoteFrame:SetHide( true );
	Controls.SilentQuoteFrame:SetHide( true );
	Controls.AbilitiesFrame:SetHide( true );			
	Controls.HistoryFrame:SetHide( true );
	Controls.StrategyFrame:SetHide( true );
	Controls.RelatedImagesFrame:SetHide( true );		
	Controls.SummaryFrame:SetHide( true );		
	Controls.ExtendedFrame:SetHide( true );		
	Controls.DNotesFrame:SetHide( true );		
	Controls.RequiredPoliciesFrame:SetHide( true );		
	Controls.PrereqEraFrame:SetHide( true );		
	Controls.PolicyBranchFrame:SetHide( true );	
	Controls.TenetLevelFrame:SetHide(true);	
	Controls.LeadersFrame:SetHide( true );
	Controls.UniqueUnitsFrame:SetHide( true );
	Controls.UniqueBuildingsFrame:SetHide( true );
	Controls.UniqueImprovementsFrame:SetHide( true );	
	Controls.CivilizationsFrame:SetHide ( true );
	Controls.TraitsFrame:SetHide( true );
	Controls.LivedFrame:SetHide( true );
	Controls.TitlesFrame:SetHide( true );
	Controls.SubtitleID:SetHide( true );
	Controls.YieldFrame:SetHide( true );
	Controls.MountainYieldFrame:SetHide( true );
	Controls.MovementCostFrame:SetHide( true );
	Controls.CombatModFrame:SetHide( true );
	Controls.FeaturesFrame:SetHide( true );
	Controls.ResourcesFoundFrame:SetHide( true );
	Controls.TerrainsFrame:SetHide( true );
	Controls.ReplacesFrame:SetHide( true );
	Controls.RevealTechsFrame:SetHide( true );
	Controls.ImprovementsFrame:SetHide( true );
	Controls.AffinitiesFrame:SetHide( true );
	Controls.ReqAffinitiesFrame:SetHide( true );
	Controls.HomePageBlurbFrame:SetHide( true );
	Controls.FFTextStack:SetHide( true );
	Controls.BBTextStack:SetHide ( true );
	Controls.PartialMatchPullDown:SetHide( true );
	Controls.SearchButton:SetHide( false );	
	
	Controls.Portrait:UnloadTexture();
	Controls.Portrait:SetTexture("256x256Frame.dds");
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function OnClose()
	Controls.Portrait:UnloadTexture();
    UIManager:DequeuePopup( ContextPtr );
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );


-- ===========================================================================
--	Navigate back to the previous entry.
-- ===========================================================================
function OnBackButtonClicked()
	-- Don't go past first entry, which should Civilopedia welcome screen.
	if m_historyCurrentIndex > 1 then
		m_historyCurrentIndex = m_historyCurrentIndex - 1;		
		
		local article = m_listOfTopicsViewed[m_historyCurrentIndex];
		if article then
			SetSelectedCategory( article.entryCategory, dontAddToList );
			
			-- Display (special) home page or regular article...
			if ( article.entryID == homePageOfCategoryID ) then
				CivilopediaCategory[article.entryCategory].DisplayHomePage();
			else
				CivilopediaCategory[article.entryCategory].SelectArticle( article.entryID, dontAddToList );
			end

		end
	end
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBackButtonClicked );

-- ===========================================================================
--	Navigate forward to the next entry in the history chain.
-- ===========================================================================
function OnForwardButtonClicked()
	if m_historyCurrentIndex < m_endTopic then
		m_historyCurrentIndex = m_historyCurrentIndex + 1;
		local article = m_listOfTopicsViewed[m_historyCurrentIndex];
		if article then
			SetSelectedCategory( article.entryCategory, dontAddToList );			

			-- Display (special) home page or regular article...
			if ( article.entryID == homePageOfCategoryID ) then
				CivilopediaCategory[article.entryCategory].DisplayHomePage();
			else
				CivilopediaCategory[article.entryCategory].SelectArticle( article.entryID, dontAddToList );
			end
		end
	end
end
Controls.ForwardButton:RegisterCallback( Mouse.eLClick, OnForwardButtonClicked );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function SearchForPediaEntry( searchString )

	UIManager:SetUICursor( 1 );
	
    if( searchString ~= nil and searchString ~= "" ) then
    	local article = searchableTextKeyList[searchString];
    	if article == nil then
    		article = searchableList[Locale.ToLower(searchString)];
    	end
    	
    	if article then
    		SetSelectedCategory( article.entryCategory, dontAddToList );
    		CivilopediaCategory[article.entryCategory].SelectArticle( article.entryID, addToList );
    	else
    		SetSelectedCategory( CategoryConcepts, addToList );
    	end
    end
	
	if( searchString == "OPEN_VIA_HOTKEY" ) then
    	if( ContextPtr:IsHidden() == false ) then
    	    OnClose();
	    else
        	UIManager:QueuePopup( ContextPtr, PopupPriority.eUtmost );
    	end
	else
    	UIManager:QueuePopup( ContextPtr, PopupPriority.eUtmost );
	end

	UIManager:SetUICursor( 0 );

end
Events.SearchForPediaEntry.Add( SearchForPediaEntry );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function GoToPediaHomePage ( iHomePage )
	UIManager:SetUICursor( 1 );
	UIManager:QueuePopup( ContextPtr, PopupPriority.Civilopedia );
	SetSelectedCategory( iHomePage, dontAddToList );
	UIManager:SetUICursor( 0 );
end
Events.GoToPediaHomePage.Add( GoToPediaHomePage );



----------------------------------------------------------------
----------------------------------------------------------------
function ValidateText(text)

	if #text < 3 then
		return false;
	end

	local isAllWhiteSpace = true;
	local numNonWhiteSpace = 0;
	for i = 1, #text, 1 do
		if string.byte(text, i) ~= 32 then
			isAllWhiteSpace = false;
			numNonWhiteSpace = numNonWhiteSpace + 1;
		end
	end
	
	if isAllWhiteSpace then
		return false;
	end
	
	if numNonWhiteSpace < 3 then
		return false;
	end
	
	-- don't allow % character
	for i = 1, #text, 1 do
		if string.byte(text, i) == 37 then
			return false;
		end
	end
	
	local invalidCharArray = { '\"', '<', '>', '|', '\b', '\0', '\t', '\n', '/', '\\', '*', '?', '%[', ']' };

	for i, ch in ipairs(invalidCharArray) do
		if string.find(text, ch) ~= nil then
			return false;
		end
	end
	
	-- don't allow control characters
	for i = 1, #text, 1 do
		if string.byte(text, i) < 32 then
			return false;
		end
	end
	
	return true;
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function OnSearchButtonClicked()
	UIManager:SetUICursor( 1 );
	local searchString = Controls.SearchEditBox:GetText();
	local lowerCaseSearchString = nil;
	if searchString ~= nil and searchString ~= "" and ValidateText(searchString) then

		local article = searchableTextKeyList[searchString];
		if article == nil then
			lowerCaseSearchString = Locale.ToLower(searchString);
			article = searchableList[lowerCaseSearchString];
		end
	    
		if article then
			SetSelectedCategory( article.entryCategory, dontAddToList );
			CivilopediaCategory[article.entryCategory].SelectArticle( article.entryID, addToList );
		else
		
			-- try to see if there is a partial match
			local partialMatch = {};
			local numberMatches = 0;
			for i, v in pairs(searchableList) do
				if string.find(Locale.ToLower(v.entryName), lowerCaseSearchString) ~= nil then
					numberMatches = numberMatches + 1;
					partialMatch[numberMatches] = v.entryName;
				end
			end
			if numberMatches == 1 then
				article = searchableList[Locale.ToLower(partialMatch[1])];
				if article then
					SetSelectedCategory( article.entryCategory, dontAddToList );
					CivilopediaCategory[article.entryCategory].SelectArticle( article.entryID, addToList );
				end
			elseif numberMatches > 1 then -- populate a dropdown with the matches
				Controls.PartialMatchPullDown:ClearEntries();
				--print "---------------------------------"
				for i, v in pairs( partialMatch ) do
					local controlTable = {};
					Controls.PartialMatchPullDown:BuildEntry( "InstanceOne", controlTable );
					controlTable.Button:SetText( v );
					
					controlTable.Button:RegisterCallback(Mouse.eLClick, 
					function()
						SearchForPediaEntry( v );
					end);

					controlTable.Button:SetVoid1( i );
					--print(v);
				end
				Controls.PartialMatchPullDown:CalculateInternals();
				--print "---------------------------------"
				--Controls.SearchButton:SetHide( true );
				Controls.PartialMatchPullDown:SetHide( false );
				Controls.PartialMatchPullDown:GetButton():SetText( searchString );
			else
				Controls.SearchNotFoundText:LocalizeAndSetText("TXT_KEY_SEARCH_NOT_FOUND", searchString);
				Controls.SearchFoundNothing:SetHide(false);
			end
		end
	end
	UIManager:SetUICursor( 0 );
end
Controls.SearchButton:RegisterCallback( Mouse.eLClick, OnSearchButtonClicked );


function OnSearchTextEnter( stringContent, control )	
	OnSearchButtonClicked();
end
Controls.SearchEditBox:RegisterCommitCallback( OnSearchTextEnter );

function OnSearchNotFoundOK()
	Controls.SearchFoundNothing:SetHide(true);
end
Controls.OK:RegisterCallback(Mouse.eLClick, OnSearchNotFoundOK );
 
 -- ==========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if(uiMsg == KeyEvents.KeyDown) then

		-- Eat up ENTER
		if ( wParam == Keys.VK_RETURN ) then
			return true;
		end

		if(not Controls.SearchFoundNothing:IsHidden()) then
			if(wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN) then
				Controls.SearchFoundNothing:SetHide(true);
				return true;
			end
		else
			if(wParam == Keys.VK_ESCAPE) then
				OnClose();
				return true;
			end
		end
    end
end
ContextPtr:SetInputHandler( InputHandler );

-- ==========================================================================
function ShowHideHandler( isHide )
    if( isHide ) then
		Controls.Portrait:UnloadTexture();
        Events.SystemUpdateUI.CallImmediate( SystemUpdateUIType.BulkShowUI );
		LuaEvents.CivilopediaHidden();
	else
        Events.SystemUpdateUI.CallImmediate( SystemUpdateUIType.BulkHideUI );
        
		-- Clears out any in-progress UI state (like range attack/bombard)
		if (InterfaceModeTypes ~= nil) then
			if (UI.GetInterfaceMode() ~= InterfaceModeTypes.INTERFACEMODE_PLANETFALL) then
				UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
				UI.ClearSelectedCities();
			end
		end

		if m_historyCurrentIndex > 1 then
			local article = m_listOfTopicsViewed[m_historyCurrentIndex];
			if article then
				SetSelectedCategory( article.entryCategory, dontAddToList );
				if(article.entryID == homePageOfCategoryID) then
					CivilopediaCategory[article.entryCategory].DisplayHomePage();
				else
					CivilopediaCategory[article.entryCategory].SelectArticle( article.entryID, dontAddToList );
				end
			else
				SetSelectedCategory(CategoryTerrain); -- this is a dummy so that the trigger for the next one fires
				SetSelectedCategory(CategoryMain);
				CivilopediaCategory[CategoryMain].DisplayHomePage();
			end
		else
			ResizeEtc();
		end

		LuaEvents.CivilopediaShown();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnClose);


----------------------------------------------------------------
-- If we hear a multiplayer game invite was sent, exit
-- so we don't interfere with the transition
----------------------------------------------------------------
function OnMultiplayerGameInvite()
   	if( ContextPtr:IsHidden() == false ) then
		OnClose();
	end
end
Events.MultiplayerGameLobbyInvite.Add( OnMultiplayerGameInvite );
Events.MultiplayerGameServerInvite.Add( OnMultiplayerGameInvite );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local tipControlTable = {};
TTManager:GetTypeControlTable( "TypeRoundImage", tipControlTable );
function TipHandler( control )
	local id = control:GetVoid1();	
	local article = m_categorizedListOfArticles[(m_selectedCategory * MAX_ENTRIES_PER_CATEGORY) + id];
	if article and article.tooltipTexture then
		tipControlTable.ToolTipImage:SetTexture( article.tooltipTexture );
		tipControlTable.ToolTipImage:SetTextureOffset( article.tooltipTextureOffset );
		tipControlTable.ToolTipFrame:SetHide( false );
	else
		tipControlTable.ToolTipFrame:SetHide( true );
	end		
end


-- ===========================================================================
--	Adds contents for a category's homepage article to the main catalog.
-- ===========================================================================
function AddCategoryHomePageArticle( categoryID )
	local article = {};
 	article.entryName		= "homePage";
 	article.entryID			= homePageOfCategoryID;
	article.entryCategory	= categoryID;
	m_categorizedListOfArticles[(categoryID * MAX_ENTRIES_PER_CATEGORY) + homePageOfCategoryID] = article;
end


-- ===========================================================================
-- ===========================================================================
function Initialize()

	-- Initialize all category related things...
	for i = 1, m_numCategories, 1 do
		if CivilopediaCategory[i].PopulateList then
			CivilopediaCategory[i].PopulateList();
			AddCategoryHomePageArticle( i );
		end
	end

	-- Set selected category to something invalid so the function will not
	-- think there is a cached value and properly select it.
	local initialCategory = m_selectedCategory;
	m_selectedCategory = -1;
	SetSelectedCategory( initialCategory, addToList );

	CivilopediaCategory[CategoryMain].DisplayHomePage();
end
Initialize();

