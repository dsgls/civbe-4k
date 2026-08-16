-------------------------------------------------
-- Include file that has handy stuff for the tech tree and other screens that need to show a tech button
-------------------------------------------------
include( "IconSupport" );
include( "InfoTooltipInclude" );
include( "MathHelpers" );


-- ===== GLOBALS =========================================
freeString 						= Locale.ConvertTextKey("TXT_KEY_FREE");
--turnString 					= Locale.ConvertTextKey("TXT_KEY_TURN");
--turnsString					= Locale.ConvertTextKey("TXT_KEY_TURNS");


-- ===== CONSTANTS =========================================
local COLOR_UNDERLAY_UNITS		= 0xff2732B2;
local COLOR_UNDERLAY_BUILDINGS	= 0xffFFBD83;	
local COLOR_UNDERLAY_WONDERS	= 0xcc72dFdF;	

local g_hideUnits : table = {
	"UNIT_WORKER",
	"UNIT_EXPLORER",
	"UNIT_SEA_TRADER",
};

local defaultErrorTextureSheet	= "UnitActions360.dds";
local m_textureAffinity			= {};
m_textureAffinity["AFFINITY_TYPE_PURITY"] 		= { atlas="AFFINITY_ATLAS_TECHWEB", size=64, index=0};
m_textureAffinity["AFFINITY_TYPE_HARMONY"] 		= { atlas="AFFINITY_ATLAS_TECHWEB", size=64, index=2};
m_textureAffinity["AFFINITY_TYPE_SUPREMACY"] 	= { atlas="AFFINITY_ATLAS_TECHWEB", size=64, index=1};

local m_tooltipAffinity		= {};
m_tooltipAffinity["AFFINITY_TYPE_HARMONY"] 		= "TXT_KEY_TECHWEB_AFFINITY_ADDS_HARMONY";
m_tooltipAffinity["AFFINITY_TYPE_PURITY"] 		= "TXT_KEY_TECHWEB_AFFINITY_ADDS_PURITY";
m_tooltipAffinity["AFFINITY_TYPE_SUPREMACY"] 	= "TXT_KEY_TECHWEB_AFFINITY_ADDS_SUPREMACY";

local m_textureFrameUnit : table		= { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=0};
local m_textureFrameResource : table	= { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=1};
local m_textureFrameImprovement : table = { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=2};
local m_textureFrameBuilding : table	= { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=3};
local m_textureFrameAbility : table		= { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=4};
local m_textureFrameWonder : table		= { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=5};
local m_textureFrameVictory : table		= { atlas="TECHWEB_ATLAS_FRAMES", size=45, index=6};


-- ===== VARIBLES =========================================

techPediaSearchStrings			= {};		-- GLOBAL
g_searchTable					= {};		-- GLOBAL Holds mapping of searchable words to techs.
g_recentlyAddedUnlocks			= {};

local m_currentButtonNum		:number = 0;	-- current
local m_nextButton				:number = 1;

-- List the textures that we will need here
local validUnitBuilds			:table = nil;
local validBuildingBuilds		:table = nil;
local validImprovementBuilds	:table = nil;


-- ===========================================================================
function GetTechPedia( void1, void2, button )
	local searchString:string = techPediaSearchStrings[tostring(button)];
	if searchString == nil then
		error("TechButtonInclude is unable to get tech pedia entry for button '"..tostring(button:GetID()).."'");
		return;
	end
	Events.SearchForPediaEntry( searchString );		
end

-- ===========================================================================
function GatherInfoAboutUniqueStuff( civType )

	validUnitBuilds = {};
	validBuildingBuilds = {};
	validImprovementBuilds = {};

	-- put in the default units for any civ
	for thisUnitClass in GameInfo.UnitClasses() do
		validUnitBuilds[thisUnitClass.Type]	= thisUnitClass.DefaultUnit;	
	end

	-- put in my overrides
	for thisOverride in GameInfo.Civilization_UnitClassOverrides() do
 		if thisOverride.CivilizationType == civType then
			validUnitBuilds[thisOverride.UnitClassType]	= thisOverride.UnitType;
 		end
	end

	-- put in the default buildings for any civ
	for thisBuildingClass in GameInfo.BuildingClasses() do
		validBuildingBuilds[thisBuildingClass.Type]	= thisBuildingClass.DefaultBuilding;	
	end

	-- put in my overrides
	for thisOverride in GameInfo.Civilization_BuildingClassOverrides() do
 		if thisOverride.CivilizationType == civType then
			validBuildingBuilds[thisOverride.BuildingClassType]	= thisOverride.BuildingType;	
 		end
	end
	
	-- add in support for unique improvements
	for thisImprovement in GameInfo.Improvements() do
		if thisImprovement.CivilizationType == civType or thisImprovement.CivilizationType == nil then
			validImprovementBuilds[thisImprovement.Type] = thisImprovement.Type;	
		else
			validImprovementBuilds[thisImprovement.Type] = nil;	
		end
	end
	
end

-- ===========================================================================
function ExcludeThisUnit(unitInfo : table)
	for _,unitType : string in ipairs(g_hideUnits) do
		if (unitType == unitInfo.Type) then
			return true;
		end
	end		
	return false;
end

-- ===========================================================================
--	Returns instance to next small button or NIL if none available.
-- ===========================================================================
function GetNextSmallButton( techButtonInstance:table )
	local thisButton :table	= techButtonInstance["B"..tostring(m_nextButton)];
	if thisButton ~= nil then

		-- Individual icons may be different sizes and have their offset changed,
		-- so the first time this small button is grabbed, store the XML enterd Y
		-- offset value and make sure to reset for subsequent handing out.
		if thisButton["XMLy"] ~= nil then
			thisButton:SetOffsetY( thisButton["XMLy"] );			-- restore original Y
		else
			thisButton["XMLy"] = thisButton:GetOffsetY();			-- store original Y offset
		end
	
		m_nextButton		= m_nextButton + 1;
		m_currentButtonNum	= m_nextButton - 1;
		return thisButton;
	else
		return nil;
	end
end


-- ===========================================================================
--	Has a few assumptions: 
--		1.) the small buttons are named "B1", "B2", "B3"
--		2.) GatherInfoAboutUniqueStuff() has been called before this
--
--	ARGS:
--	thisTechButtonInstance,	UI element
--	tech,					data structure with technology info
--	maxSmallButtonSize		no more than this many buttons will be populated
--	textureSize
--	startingButtoNum,		(optional) 1, but will use this instead if set
--
--	RETURNS: the # of small buttons added
-- ===========================================================================
function AddSmallButtonsToTechButton( thisTechButtonInstance, tech, maxSmallButtons, textureSize, startingButtonNum )
	
	if tech == nil then
		return;
	end

	-- Used for search related operations (e.g., populating search dictionary)
	g_recentlyAddedUnlocks = {};

	local techType = tech.Type;
	m_currentButtonNum = 0;

	-- (optional)
	if startingButtonNum ~= nil then
		m_nextButton = startingButtonNum;
	else
		m_nextButton = 1;
	end

	-- hide the ones we aren't using
	for i = m_nextButton, maxSmallButtons, 1 do
		local buttonName = "B"..tostring(i);
		thisTechButtonInstance[buttonName]:SetHide(true);
	end

	--[[ Now using affinity icon rings; save room for unlocks
	local affinities = {};
	for techAffinityPair in GameInfo.Technology_Affinities()  do
		local techType		= techAffinityPair.TechType;
		local affinityType	= techAffinityPair.AffinityType;
		if ( techType == tech.Type ) then							
			--print("Setting affinity Type: " .. tech.ID .. " > " .. thisTechButtonInstance.affinityType );				
			if thisTechButtonInstance.affinityTypes == nil then
				thisTechButtonInstance.affinityTypes = {};
			end
			table.insert( affinities, affinityType );						
		end
	end

	-- If an affinity exists, wire it up as the first small button
	for _,affinityType in ipairs(affinities) do				
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		local textureInfo   = m_textureAffinity[ tostring(affinityType) ];
		if ( textureInfo ~= nil and thisButton ~= nil) then 
			thisButton:SetSizeVal( textureInfo.size, textureInfo.size);
			thisButton:SetOffsetY( thisButton:GetOffsetY() - 6 );	

			IconHookup( textureInfo.index, textureInfo.size, textureInfo.atlas, thisButton );
			local toolTipString = Locale.ConvertTextKey(m_tooltipAffinity[ affinityType ]);
			if ( toolTipString ~= nil ) then
				thisButton:SetToolTipString( toolTipString );
			else
				print("WARNING: Missing tooltip string for affinity '"..tostring(affinityType).."', on tech "..thisTechButtonInstance.tech.Description);
			end
				
			local conceptType = GameInfo.Affinity_Types[affinityType].CivilopediaConcept;
			local concept = GameInfo.Concepts[conceptType];
			techPediaSearchStrings[tostring(thisButton)] = concept.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

			thisButton:SetHide( false );
		else
			print("ERROR: Missing infinity texture for affinity '"..tostring(affinityType).."', on tech "..thisTechButtonInstance.tech.Description);
		end
	end		
	]]

	-- add the stuff granted by this tech here --

  	for thisUnitInfo in GameInfo.Units(string.format("PreReqTech = '%s'", techType)) do
		if (not ExcludeThisUnit(thisUnitInfo)) then
 			-- if this tech grants this player the ability to make this unit
			if validUnitBuilds[thisUnitInfo.Class] == thisUnitInfo.Type then
				local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
				if thisButton then
					thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
					AdjustArtOnGrantedUnitButton( thisButton, thisUnitInfo, textureSize );
					table.insert( g_recentlyAddedUnlocks, thisUnitInfo.Description );
				end
			end
		end
 	end

 	for thisBuildingInfo in GameInfo.Buildings(string.format("PreReqTech = '%s'", techType)) do
 		-- if this tech grants this player the ability to construct this building
		if validBuildingBuilds[thisBuildingInfo.BuildingClass] == thisBuildingInfo.Type then
			local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
			if thisButton then
				thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
				AdjustArtOnGrantedBuildingButton( thisButton, thisBuildingInfo, textureSize );
				table.insert( g_recentlyAddedUnlocks, thisBuildingInfo.Description );
			end
		end
 	end

 	for thisResourceInfo in GameInfo.Resources(string.format("TechReveal = '%s'", techType)) do
 		-- if this tech grants this player the ability to reveal this resource
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			AdjustArtOnGrantedResourceButton( thisButton, thisResourceInfo, textureSize );
			table.insert( g_recentlyAddedUnlocks, thisResourceInfo.Description );
		end
 	end
 
 	for thisProjectInfo in GameInfo.Projects(string.format("TechPrereq = '%s'", techType)) do
 		-- if this tech grants this player the ability to build this project
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
 		if thisButton then
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			AdjustArtOnGrantedProjectButton( thisButton, thisProjectInfo, textureSize );
			table.insert( g_recentlyAddedUnlocks, thisProjectInfo.Description );
 		end
	end

	-- if this tech grants this player the ability to perform this action (usually only workers can do these)
	for thisBuildInfo in GameInfo.Builds(string.format("PrereqTech = '%s'", techType)) do
		-- Improvement Build
		if thisBuildInfo.ImprovementType then
			if validImprovementBuilds[thisBuildInfo.ImprovementType] == thisBuildInfo.ImprovementType then
				local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
				if thisButton then
					thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
					AdjustArtOnGrantedImprovementButton( thisButton, GameInfo.Improvements[thisBuildInfo.ImprovementType], textureSize );
					table.insert( g_recentlyAddedUnlocks, thisBuildInfo.Description );
				end
 			end
		else -- Other Action
			local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
			if thisButton then
				thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
				AdjustArtOnGrantedActionButton( thisButton, thisBuildInfo, textureSize );
				local ttString : string = Locale.Lookup(thisBuildInfo.Description);
				ttString = ttString.."[NEWLINE][NEWLINE]"..Locale.Lookup("TXT_KEY_TERM_WORKER_BUILD")..".";
				if (thisBuildInfo.Help ~= nil) then
					ttString = ttString .." "..Locale.Lookup(thisBuildInfo.Help);
				end
				thisButton:SetToolTipString(ttString);
				AddFirstLineUndecoratedToSearch( thisBuildInfo.Description );
 			end
		end
	end
	
	-- show processes
	local processCondition = "TechPrereq = '" .. techType .. "'";
	for row in GameInfo.Processes(processCondition) do
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( row.PortraitIndex, textureSize, row.IconAtlas, thisButton );
			thisButton:SetHide( false );
			local strPText = Locale.ConvertTextKey( row.Description );
			thisButton:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_ENABLE_PRODUCITON_CONVERSION", strPText) );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);

			AddFirstLineUndecoratedToSearch( row.Description );
		end		
	end	
		
 	-- todo: need to add abilities, etc.
	local condition = "TechType = '" .. techType .. "'";

	-- Player Perk unlocks
	for row in GameInfo.Technology_FreePlayerPerks(condition) do
		local playerPerkType = row.PlayerPerkType;
		local thisPerkInfo = GameInfo.PlayerPerks[playerPerkType];
		if (thisPerkInfo ~= nil) then
			local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
			if thisButton then
				thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
				AdjustArtOnGrantedPlayerPerkButton( thisButton, thisPerkInfo, textureSize );				
				local perkInfo = GameInfo.PlayerPerks[thisPerkInfo.ID];
				local description =  GetHelpTextForPlayerPerk(thisPerkInfo.ID, true);
				thisButton:SetToolTipString( description );

				-- Only add first line into search table (Some misc bonuses get added, but need this here so "Leash" can be searched.)
				AddFirstLineUndecoratedToSearch( description );
			else
				break;
			end
		end
	end
		
	for row in GameInfo.Route_TechMovementChanges(condition) do
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			thisButton:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_FASTER_MOVEMENT", GameInfo.Routes[row.RouteType].Description ) );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);		
			AddFirstLineUndecoratedToSearch( row.Description );

		else
			break
		end
	end	
	
	-- Some improvements can have multiple yield changes, group them and THEN add buttons.
	local yieldChanges = {};
	for row in GameInfo.Improvement_TechYieldChanges(condition) do
		local improvementType = row.ImprovementType;
		
		if(yieldChanges[improvementType] == nil) then
			yieldChanges[improvementType] = {};
		end
		
		local improvement = GameInfo.Improvements[row.ImprovementType];
		local yield = GameInfo.Yields[row.YieldType];
		
		local changeText:string = Locale.Lookup( "TXT_KEY_TECH_IMPROVEMENT_YIELD_CHANGE", row.Yield, yield.IconString, yield.Description, improvement.Description);
		table.insert(yieldChanges[improvementType], changeText );
		AddFirstLineUndecoratedToSearch( changeText );
	end
	
	-- Let's sort the yield change butons!
	local sortedYieldChanges = {};
	for k,v in pairs(yieldChanges) do
		table.insert(sortedYieldChanges, {k,v});
	end
	table.sort(sortedYieldChanges, function(a,b) return Locale.Compare(a[1], b[1]) == -1 end); 
	
	for i,v in pairs(sortedYieldChanges) do
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton ~= nil then
			table.sort(v[2], function(a,b) return Locale.Compare(a,b) == -1 end);
		
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			thisButton:SetToolTipString(table.concat(v[2], "[NEWLINE]"));
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);			
		else
			break;
		end
	end	
	
	for row in GameInfo.Improvement_TechNoFreshWaterYieldChanges(condition) do
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			thisButton:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_NO_FRESH_WATER", GameInfo.Improvements[row.ImprovementType].Description , GameInfo.Yields[row.YieldType].Description, row.Yield));
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);
		else
			break;
		end
	end	

	for row in GameInfo.Improvement_TechFreshWaterYieldChanges(condition) do
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			thisButton:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_FRESH_WATER", GameInfo.Improvements[row.ImprovementType].Description , GameInfo.Yields[row.YieldType].Description, row.Yield));
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);
		else
			break;
		end
	end	

	if tech.EmbarkedMoveChange > 0 then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local changeText:string = Locale.ConvertTextKey( "TXT_KEY_FASTER_EMBARKED_MOVEMENT" );
			thisButton:SetToolTipString( changeText );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);
			AddFirstLineUndecoratedToSearch( changeText );
		end
	end

	if tech.AllowsDeepWaterCityMovement then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local changeText:string = Locale.ConvertTextKey( "TXT_KEY_ALLOWS_DEEP_WATER_CITY_MOVE" );
			thisButton:SetToolTipString( changeText );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );	
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);	
			AddFirstLineUndecoratedToSearch( changeText );
		end
	end

	if tech.UnitFortificationModifier > 0 then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local description = Locale.ConvertTextKey( "TXT_KEY_UNIT_FORTIFICATION_MOD", tech.UnitFortificationModifier );
			thisButton:SetToolTipString( description );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);			
			AddFirstLineUndecoratedToSearch( description );
		end
	end
	
	if tech.UnitBaseHealModifier > 0 then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local description = Locale.ConvertTextKey( "TXT_KEY_UNIT_BASE_HEAL_MOD", tech.UnitBaseHealModifier );
			thisButton:SetToolTipString( description );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);
			AddFirstLineUndecoratedToSearch( description );
		end
	end

	if tech.UnitBaseMiasmaHeal > 0 then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local description = Locale.ConvertTextKey( "TXT_KEY_BASE_MIASMA_HEAL", tech.UnitBaseMiasmaHeal );
			thisButton:SetToolTipString( description );	
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);			
			AddFirstLineUndecoratedToSearch( description );
		end
	end

	if tech.MapVisible then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local description :string = Locale.ConvertTextKey( "TXT_KEY_REVEALS_ENTIRE_MAP" );
			thisButton:SetToolTipString( description );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);			
			AddFirstLineUndecoratedToSearch( description );
		end
	end
	
	if tech.InternationalTradeRoutesChange > 0 then
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton then
			IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
			thisButton:SetHide( false );
			local description :string = Locale.ConvertTextKey( "TXT_KEY_ADDITIONAL_INTERNATIONAL_TRADE_ROUTE" );
			thisButton:SetToolTipString( description );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);
			AddFirstLineUndecoratedToSearch( description );
		end	
	end

	for row in GameInfo.Technology_TradeRouteDomainExtraRange(condition) do
		if (row.TechType == techType and row.Range > 0) then
			local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
			if thisButton then
				IconHookup( 0, textureSize, "GENERIC_FUNC_ATLAS", thisButton );
				thisButton:SetHide( false );
				local description:string;
				if (GameInfo.Domains[row.DomainType].ID == DomainTypes.DOMAIN_LAND) then
					description = Locale.ConvertTextKey( "TXT_KEY_EXTENDS_LAND_TRADE_ROUTE_RANGE" );
				elseif (GameInfo.Domains[row.DomainType].ID == DomainTypes.DOMAIN_SEA) then
					description = Locale.ConvertTextKey( "TXT_KEY_EXTENDS_SEA_TRADE_ROUTE_RANGE" );
				end
				thisButton:SetToolTipString( description );
				techPediaSearchStrings[tostring(thisButton)] = tech.Description;
				thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
				thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
				BackingFrameHookup(thisButton, m_textureFrameAbility);				
				AddFirstLineUndecoratedToSearch( description );
			end	
		end
	end
	
	for row in GameInfo.Technology_FreePromotions(condition) do
		local promotion = GameInfo.UnitPromotions[row.PromotionType];
		local thisButton:table = GetNextSmallButton( thisTechButtonInstance );
		if thisButton and promotion ~= nil then
			AdjustArtOnButton( thisButton, promotion.PortraitIndex, promotion.IconAtlas, textureSize );		
			local description = Locale.ConvertTextKey("TXT_KEY_FREE_PROMOTION_FROM_TECH", promotion.Description, promotion.Help);
			thisButton:SetToolTipString( description );
			techPediaSearchStrings[tostring(thisButton)] = tech.Description;
			thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
			thisButton["IconUnderlay"] = thisTechButtonInstance["IconUnderlay"..tostring(m_currentButtonNum)];	-- Attach underlay control and give it common name.
			BackingFrameHookup(thisButton, m_textureFrameAbility);
			AddFirstLineUndecoratedToSearch( description );
		else
			break;
		end
	end

	return m_currentButtonNum;
end



function AddCallbackToSmallButtons( thisTechButtonInstance, maxSmallButtons, void1, void2, thisEvent, thisCallback )
	for buttonNum = 1, maxSmallButtons, 1 do
		local buttonName = "B"..tostring(buttonNum);
		thisTechButtonInstance[buttonName]:SetVoids(void1, void2);
		thisTechButtonInstance[buttonName]:RegisterCallback(thisEvent, thisCallback);
	end
end


-- ===========================================================================
--	Is a building a wonder
--	RETURNS: true if so
-- ===========================================================================
function IsWonder( building )
	local thisBuildingClass = GameInfo.BuildingClasses[building.BuildingClass];
	if (thisBuildingClass.MaxGlobalInstances > 0 or thisBuildingClass.MaxTeamInstances > 0 or thisBuildingClass.MaxPlayerInstances > 0)	then
		return true;
	end
	return false;	
end

function IsVictoryProject(projectInfo)
	if (projectInfo ~= nil) then
		return projectInfo.VictoryPrereq ~= nil;
	end
	return false;
end

function AdjustArtOnGrantedUnitButton( thisButton, thisUnitInfo, textureSize )
	-- if we have one, update the unit picture
	if thisButton then
		
		-- Tooltip
		local bIncludeRequirementsInfo = true;
		thisButton:SetToolTipString( GetHelpTextForUnit(thisUnitInfo.ID, bIncludeRequirementsInfo) );
		local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(thisUnitInfo.ID);
		local textureOffset, textureSheet = IconLookup( portraitOffset, textureSize, portraitAtlas );
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end

		thisButton:SetTexture( textureSheet );
		thisButton:SetTextureOffset( textureOffset );
		thisButton:SetHide( false );
		techPediaSearchStrings[tostring(thisButton)] = Locale.ConvertTextKey(thisUnitInfo.Description);		
		thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

		-- Backing frame icon
		BackingFrameHookup(thisButton, m_textureFrameUnit);
	end
end

function AdjustArtOnGrantedBuildingButton( thisButton, thisBuildingInfo, textureSize )
	-- if we have one, update the building (or wonder) picture
	if thisButton then
		
		-- Tooltip
		local bExcludeName = false;
		local bExcludeHeader = false;
		thisButton:SetToolTipString( GetHelpTextForBuilding(thisBuildingInfo.ID, bExcludeName, bExcludeHeader, false, nil) );
		
		local textureOffset, textureSheet = IconLookup( thisBuildingInfo.PortraitIndex, textureSize, thisBuildingInfo.IconAtlas );				
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end				
		thisButton:SetTexture( textureSheet );
		thisButton:SetTextureOffset( textureOffset );
		thisButton:SetHide( false );
		techPediaSearchStrings[tostring(thisButton)] = Locale.ConvertTextKey(thisBuildingInfo.Description);
		thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

		-- Backing frame icon
		if (IsWonder(thisBuildingInfo)) then
			BackingFrameHookup(thisButton, m_textureFrameWonder);
		else
			BackingFrameHookup(thisButton, m_textureFrameBuilding);
		end
	end
end


function AdjustArtOnGrantedProjectButton( thisButton, thisProjectInfo, textureSize )
	-- if we have one, update the project picture
	if thisButton then
		
		-- Tooltip
		local bIncludeRequirementsInfo = true;
		thisButton:SetToolTipString( GetHelpTextForProject(thisProjectInfo.ID, bIncludeRequirementsInfo) );

		local textureOffset, textureSheet = IconLookup( thisProjectInfo.PortraitIndex, textureSize, thisProjectInfo.IconAtlas );				
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end				
		thisButton:SetTexture( textureSheet );
		thisButton:SetTextureOffset( textureOffset );
		thisButton:SetHide( false );
		techPediaSearchStrings[tostring(thisButton)] = Locale.ConvertTextKey(thisProjectInfo.Description);
		thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

		-- Backing frame icon
		if (IsVictoryProject(thisProjectInfo)) then
			BackingFrameHookup(thisButton, m_textureFrameVictory);
		else
			BackingFrameHookup(thisButton, m_textureFrameWonder);
		end
	end
end


function AdjustArtOnGrantedImprovementButton( thisButton, thisImprovementInfo, textureSize )
	-- if we have one, update the picture
	if thisButton then
		
		-- Tooltip
		local bExcludeName = false;
		local bExcludeHeader = false;
		thisButton:SetToolTipString( GetHelpTextForImprovement(thisImprovementInfo.ID, bExcludeName, bExcludeHeader, false) );
		
		local textureOffset, textureSheet = IconLookup( thisImprovementInfo.PortraitIndex, textureSize, thisImprovementInfo.IconAtlas );				
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end
		thisButton:SetTexture( textureSheet );
		thisButton:SetTextureOffset( textureOffset );
		thisButton:SetHide( false );
		techPediaSearchStrings[tostring(thisButton)] = Locale.ConvertTextKey(thisImprovementInfo.Description);
		thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

		-- Backing frame icon
		BackingFrameHookup(thisButton, m_textureFrameImprovement);
	end
end


function AdjustArtOnGrantedResourceButton( thisButton, thisResourceInfo, textureSize )
	if thisButton then
		thisButton:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_REVEALS_RESOURCE_ON_MAP", thisResourceInfo.Description)); 

		local textureOffset, textureSheet = IconLookup( thisResourceInfo.PortraitIndex, textureSize, thisResourceInfo.IconAtlas );				
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end				
		thisButton:SetTexture( textureSheet );
		thisButton:SetTextureOffset( textureOffset );
		thisButton:SetHide( false );
		techPediaSearchStrings[tostring(thisButton)] =  Locale.Lookup(thisResourceInfo.Description);
		thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

		-- Backing frame icon
		BackingFrameHookup(thisButton, m_textureFrameResource);
	end
end

function AdjustArtOnGrantedActionButton( thisButton, thisBuildInfo, textureSize )
	if thisButton then
		thisButton:SetToolTipString( Locale.ConvertTextKey( thisBuildInfo.Description ) );
		local textureOffset, textureSheet = IconLookup( thisBuildInfo.IconIndex, textureSize, thisBuildInfo.IconAtlas );				
		if textureOffset == nil then
			textureSheet = defaultErrorTextureSheet;
			textureOffset = nullOffset;
		end				
		thisButton:SetTexture( textureSheet );
		thisButton:SetTextureOffset( textureOffset );
		thisButton:SetHide(false);

		local searchString = thisBuildInfo.Description;
		if thisBuildInfo.RouteType then
			searchString = Locale.ConvertTextKey( GameInfo.Routes[thisBuildInfo.RouteType].Description );
		elseif thisBuildInfo.ImprovementType then
			searchString = Locale.ConvertTextKey( GameInfo.Improvements[thisBuildInfo.ImprovementType].Description );
		elseif thisBuildInfo.Type == "TERRAFORM_ADD_MIASMA" then
			searchString = GameInfo.Concepts["CONCEPT_WORKERS_PLACE"].Description;
		elseif thisBuildInfo.Type == "TERRAFORM_CLEAR_MIASMA" then
			searchString = GameInfo.Concepts["CONCEPT_WORKERS_REMOVE"].Description;
		else -- we are a choppy thing
			searchString = Locale.ConvertTextKey( GameInfo.Concepts["CONCEPT_WORKERS_CLEARINGLAND"].Description );
		end
		techPediaSearchStrings[tostring(thisButton)] = searchString;
		thisButton:RegisterCallback( Mouse.eRClick, GetTechPedia );
		
		-- Backing frame icon
		BackingFrameHookup(thisButton, m_textureFrameAbility);
	end
end

function AdjustArtOnGrantedUnitUpgradeButton (thisButton, thisUnitUpgradeInfo, textureSize)
	if (thisButton ~= nil and thisUnitUpgradeInfo ~= nil) then
		IconHookup(0, textureSize, "GENERIC_FUNC_ATLAS", thisButton);
		thisButton:SetHide(false);
		thisButton:SetToolTipString(Locale.ConvertTextKey(thisUnitUpgradeInfo.Description));

		-- Backing frame icon
		BackingFrameHookup(thisButton, m_textureFrameAbility);
	end
end

function AdjustArtOnGrantedPlayerPerkButton (thisButton, thisPerkInfo, textureSize)
	if (thisButton ~= nil and thisPerkInfo ~= nil) then
		local textureOffset, textureSheet = IconLookup( thisPerkInfo.IconIndex, textureSize, thisPerkInfo.IconAtlas );				
		if textureSheet ~= nil then
			if textureOffset == nil then
				textureSheet = defaultErrorTextureSheet;
				textureOffset = nullOffset;
			end

			thisButton:SetTexture( textureSheet );
			thisButton:SetTextureOffset( textureOffset );
			thisButton:SetHide(false);
		else
			IconHookup(0, textureSize, "GENERIC_FUNC_ATLAS", thisButton);
		end

		thisButton:SetHide(false);
		thisButton:SetToolTipString( GetHelpTextForPlayerPerk(thisPerkInfo.ID, true) );

		-- Backing frame icon
		BackingFrameHookup(thisButton, m_textureFrameAbility);
	end
end

function AdjustArtOnButton (thisButton, iconIndex, iconAtlas, textureSize)
	if (thisButton ~= nil and iconIndex ~= nil and iconAtlas ~= nil and textureSize ~= nil) then
		local textureOffset, textureSheet = IconLookup(iconIndex, textureSize, iconAtlas );				
		if textureSheet ~= nil then
			if textureOffset == nil then
				textureSheet = defaultErrorTextureSheet;
				textureOffset = nullOffset;
			end

			thisButton:SetTexture( textureSheet );
			thisButton:SetTextureOffset( textureOffset );
			thisButton:SetHide(false);
		else
			IconHookup(0, textureSize, "GENERIC_FUNC_ATLAS", thisButton);
		end

		thisButton:SetHide(false);
	end
end

-- ===========================================================================

function BackingFrameHookup(buttonInstance : table, frameTextureTable : table)
	if frameTextureTable == nil then
		return;
	end
	local iconUnderlay = buttonInstance["IconUnderlay"];
	if (iconUnderlay ~= nil) then
		local frameOffset : table, frameSheet : string = IconLookup( frameTextureTable.index, frameTextureTable.size, frameTextureTable.atlas );
		iconUnderlay:SetTexture( frameSheet );
		iconUnderlay:SetTextureOffset( frameOffset );
		iconUnderlay:SetHide( false );
		iconUnderlay["hasTexture"] = true;
	end
end

-- ==============================================================================
--	originalText	Tooltip text
--	RETURNS:	Only the first line (before [NEWLINE]) without any decorations 
--				(e.g., no color, icons, etc...)
--
function AddFirstLineUndecoratedToSearch( originalText:string )
	-- Because lua treats brackets specially, convert them to arrow brackets
	-- then look for "NEWLINE" in the brackets.
	-- Finally stip off any other control characters (e.g., "[COLOR_HAPPY]")
	local subtext:string = string.gsub(originalText, "%[", "<" );
	subtext = string.gsub(subtext, "]", ">" );
	local startIndex:number, endIndex:number = string.find(subtext, "<NEWLINE>");
	if startIndex ~= nil then
		subtext = string.sub( subtext, 1, startIndex - 1);
		subtext = string.gsub( subtext, "<(%w+)(%s*)%_*(%w+)%_*(%w+)>", "" );
		table.insert( g_recentlyAddedUnlocks, subtext );
	else
		table.insert( g_recentlyAddedUnlocks, originalText );
	end
end

-- ===========================================================================
-- Debug helper only (don't put into code, this can be commented out)
-- ===========================================================================
function str( val )
	if val == nil then
		return "nil";
	else
		return tostring( math.floor(val));
	end
end
