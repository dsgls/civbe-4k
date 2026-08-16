-------------------------------------------------
-- Help text for Info Objects (Units, Buildings, etc.)
-------------------------------------------------
include("StringHelperInclude");
include("PlayerPerkHelper");

hstructure BuildingResourceQuantityRequirement
	ResourceType : string;
end

-- Keyed by BuildingType
CachedBuildingResourceQuantityRequirements = nil;

hstructure AffinityPrereq
	AffinityType	: string;
	Level			: number;
end

-- Keyed by UnitType
CachedUnitAffinityPrereqs = nil;

-- Keyed by BuildingType
CachedBuildingAffinityPrereqs = nil;

-- Keyed by affinity level
CachedHarmonyAffinityPerks = nil;
CachedPurityAffinityPerks = nil;
CachedSupremacyAffinityPerks = nil;

-- Keyed by ProjectType
CachedProjectAffinityPrereqs = nil;

-- Keyed by CovertOperationType
CachedCovertOperationAffinityPrereqs = nil;

-- Keyed by BuildingType
CachedBuildingLocalResourceOrs = nil;

hstructure BuildingYieldEffect
	BuildingClassType	: string;
	YieldType			: string;
	FlatYield			: number;
end

-- Array of Player Perk Infos.  No key.
CachedPlayerPerksArray = nil;

hstructure PlayerPerkInfo
	ID							: number;
	MiasmaBaseHeal				: number;
	UnitFlatVisibilityChange	: number;
	UnitPercentHealChange		: number;
end

-- Keyed by PlayerPerkType
CachedPlayerPerksBuildingYieldEffects = nil;

hstructure YieldInfo
	ID			: number;
	Type		: string;
	Description	: string;
	IconString	: string;
end

-- Array of Yield Infos.  No key.
CachedYieldInfoArray = nil;

-- Terrain Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure TerrainInfo
		ID				: number;
		Type			: string;
		Description		: string;
end	

-- Array of Terrain Infos.  No key.
CachedTerrainInfoArray = nil;

-- Feature Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure FeatureInfo
	ID			: number;
	Type		: string;
	Description	: string;
end

-- Array of Feature Infos.  No key.
CachedFeatureInfoArray = nil;

-- Resource Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure ResourceInfo
	ID			: number;
	Type		: string;
	Description	: string;
	IconString	: string;
end

-- Array of Resource Infos.  No key.
CachedResourceInfoArray = nil;

-- Domain Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure DomainInfo
	ID			: number;
	Type		: string;
	Description	: string;
end

-- Array of Domain Infos.  No key.
CachedDomainInfoArray = nil;

-- Building Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure BuildingInfo
	ID			: number;
	Type		: string;
	Description	: string;
	BuildingClass : string;
	SpecialistCount : number;
end

-- Array of Unit Promotion Infos.  No key.
CachedUnitPromotionInfoArray = nil;

-- Unit Promotion Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure UnitPromotionInfo
	ID			: number;
	Help		: string;
end

-- Array of Unit Free Promotion Infos.  No key.
CachedUnitFreePromotionsInfoArray = nil;

-- Unit Free Promotions Info structure.
-- Note: Only fields that are used by lua are present to save space.  Add additional fields as needed.
hstructure UnitFreePromotionsInfo
	UnitType		: string;
	PromotionType	: string;
end

-- Array of Building Infos.  No key.
CachedBuildingInfoArray = nil;

function ClearCache( closed )
	m_hasCached = false;

	CachedBuildingResourceQuantityRequirements = nil;
	CachedUnitAffinityPrereqs = nil;
	CachedBuildingAffinityPrereqs = nil;
	CachedHarmonyAffinityPerks = nil;
	CachedPurityAffinityPerks = nil;
	CachedSupremacyAffinityPerks = nil;
	CachedProjectAffinityPrereqs = nil;
	CachedCovertOperationAffinityPrereqs = nil;
	CachedBuildingLocalResourceOrs = nil;
	CachedPlayerPerksArray = nil;
	CachedPlayerPerksBuildingYieldEffects = nil;
	CachedYieldInfoArray = nil;
	CachedTerrainInfoArray = nil;
	CachedFeatureInfoArray = nil;
	CachedResourceInfoArray = nil;
	CachedDomainInfoArray = nil;
	CachedBuildingInfoArray = nil;
	CachedUnitPromotionInfoArray = nil;
	CachedUnitFreePromotionsInfoArray = nil;
end
Events.DatabaseReset.Add(ClearCache);

-- Cache some frequently used database information if the table is not indexed by type.  Using a condition to search
-- for an entry is expensive.
m_hasCached = false;

function CacheDatabaseQueries()

	if(m_hasCached) then
		return;
	end

	m_hasCached = true;

	-- Cache the information we need from GameInfo.Building_ResourceQuantityRequirements, indexing it by the BuildingType
	if (CachedBuildingResourceQuantityRequirements == nil) then
		CachedBuildingResourceQuantityRequirements = {};
		for row in GameInfo.Building_ResourceQuantityRequirements() do
			CachedBuildingResourceQuantityRequirements[row.BuildingType] = hmake BuildingResourceQuantityRequirement { ResourceType = row.ResourceType };
		end
	end

	-- Unit Affinity Level Requirement
	if (CachedUnitAffinityPrereqs == nil) then
		CachedUnitAffinityPrereqs = {};
		for row in GameInfo.Unit_AffinityPrereqs() do
			if CachedUnitAffinityPrereqs[row.UnitType] == nil then
				CachedUnitAffinityPrereqs[row.UnitType] = {};
			end
			CachedUnitAffinityPrereqs[row.UnitType][row.AffinityType] = row.Level;
		end
	end

	-- Building Affinity Level Requirement
	if (CachedBuildingAffinityPrereqs == nil) then
		CachedBuildingAffinityPrereqs = {};
		for row in GameInfo.Building_AffinityPrereqs() do
			CachedBuildingAffinityPrereqs[row.BuildingType] = hmake AffinityPrereq { AffinityType = row.AffinityType, Level = row.Level };
		end
	end

	-- Affinity Perks
	local harmonyType = "AFFINITY_TYPE_HARMONY";
	local purityType = "AFFINITY_TYPE_PURITY";
	local supremacyType = "AFFINITY_TYPE_SUPREMACY";
	if (CachedHarmonyAffinityPerks == nil) then
		CachedHarmonyAffinityPerks = {};
		for row in GameInfo.Affinity_Perks("HarmonyLevelNeeded > 0") do
			if (CachedHarmonyAffinityPerks[row.HarmonyLevelNeeded] == nil) then
				CachedHarmonyAffinityPerks[row.HarmonyLevelNeeded] = {};
			end
			local otherAffinityPrereqs = {};
			if (row.PurityLevelNeeded > 0) then
				table.insert(otherAffinityPrereqs, hmake AffinityPrereq { AffinityType = purityType, Level = row.PurityLevelNeeded });
			end
			if (row.SupremacyLevelNeeded > 0) then
				table.insert(otherAffinityPrereqs, hmake AffinityPrereq { AffinityType = supremacyType, Level = row.SupremacyLevelNeeded });
			end
			local affinityPerk : table = {
				PlayerPerk = row.PlayerPerk,
				OtherAffinityPrereqs = otherAffinityPrereqs,
			};
			table.insert(CachedHarmonyAffinityPerks[row.HarmonyLevelNeeded], affinityPerk);
		end
	end
	if (CachedPurityAffinityPerks == nil) then
		CachedPurityAffinityPerks = {};
		for row in GameInfo.Affinity_Perks("PurityLevelNeeded > 0") do
			if (CachedPurityAffinityPerks[row.PurityLevelNeeded] == nil) then
				CachedPurityAffinityPerks[row.PurityLevelNeeded] = {};
			end
			local otherAffinityPrereqs = {};
			if (row.HarmonyLevelNeeded > 0) then
				table.insert(otherAffinityPrereqs, hmake AffinityPrereq { AffinityType = harmonyType, Level = row.HarmonyLevelNeeded });
			end
			if (row.SupremacyLevelNeeded > 0) then
				table.insert(otherAffinityPrereqs, hmake AffinityPrereq { AffinityType = supremacyType, Level = row.SupremacyLevelNeeded });
			end
			local affinityPerk : table = {
				PlayerPerk = row.PlayerPerk,
				OtherAffinityPrereqs = otherAffinityPrereqs,
			};
			table.insert(CachedPurityAffinityPerks[row.PurityLevelNeeded], affinityPerk);
		end
	end
	if (CachedSupremacyAffinityPerks == nil) then
		CachedSupremacyAffinityPerks = {};
		for row in GameInfo.Affinity_Perks("SupremacyLevelNeeded > 0") do
			if (CachedSupremacyAffinityPerks[row.SupremacyLevelNeeded] == nil) then
				CachedSupremacyAffinityPerks[row.SupremacyLevelNeeded] = {};
			end
			local otherAffinityPrereqs = {};
			if (row.HarmonyLevelNeeded > 0) then
				table.insert(otherAffinityPrereqs, hmake AffinityPrereq { AffinityType = harmonyType, Level = row.HarmonyLevelNeeded });
			end
			if (row.PurityLevelNeeded > 0) then
				table.insert(otherAffinityPrereqs, hmake AffinityPrereq { AffinityType = purityType, Level = row.PurityLevelNeeded });
			end
			local affinityPerk : table = {
				PlayerPerk = row.PlayerPerk,
				OtherAffinityPrereqs = otherAffinityPrereqs,
			};
			table.insert(CachedSupremacyAffinityPerks[row.SupremacyLevelNeeded], affinityPerk);
		end
	end

	-- Project Affinity Level Requirement
	if (CachedProjectAffinityPrereqs == nil) then
		CachedProjectAffinityPrereqs = {};
		for row in GameInfo.Project_AffinityPrereqs() do
			CachedProjectAffinityPrereqs[row.ProjectType] = hmake AffinityPrereq { AffinityType = row.AffinityType, Level = row.Level };
		end
	end

	-- CovertOp Affinity Level Requirement
	if (CachedCovertOperationAffinityPrereqs == nil) then
		CachedCovertOperationAffinityPrereqs = {};
		for row in GameInfo.CovertOperation_AffinityPrereqs() do
			CachedCovertOperationAffinityPrereqs[row.CovertOperationType] = hmake AffinityPrereq { AffinityType = row.AffinityType, Level = row.Level };
		end
	end

	-- Build Local resource OR table.
	-- The table is by building type, but each entry is also a table because the building can have multiple resources.
	if (CachedBuildingLocalResourceOrs == nil) then
		CachedBuildingLocalResourceOrs = {};
		for row in GameInfo.Building_LocalResourceOrs() do
			if (CachedBuildingLocalResourceOrs[row.BuildingType] == nil) then
				CachedBuildingLocalResourceOrs[row.BuildingType] = {};
			end
			table.insert(CachedBuildingLocalResourceOrs[row.BuildingType], row.ResourceType);
		end		
	end

	-- Player Perk Infos
	if (CachedPlayerPerksArray == nil) then
		CachedPlayerPerksArray = {};
		for row in GameInfo.PlayerPerks() do
			local perkEntry = hmake PlayerPerkInfo {
												ID = row.ID,
												MiasmaBaseHeal = row.MiasmaBaseHeal,
												UnitFlatVisibilityChange = row.UnitFlatVisibilityChange,
												UnitPercentHealChange = row.UnitPercentHealChange
												};
			table.insert(CachedPlayerPerksArray, perkEntry);
		end
	end

	-- Player Perk Building Yield Effects
	if (CachedPlayerPerksBuildingYieldEffects == nil) then
		CachedPlayerPerksBuildingYieldEffects = {};
		for row in GameInfo.PlayerPerks_BuildingYieldEffects() do
			CachedPlayerPerksBuildingYieldEffects[row.PlayerPerkType] = hmake BuildingYieldEffect { BuildingClassType = row.BuildingClassType, YieldType = row.YieldType, FlatYield = row.FlatYield };
		end
	end

	-- Cached Yield Infos
	if (CachedYieldInfoArray == nil) then
		CachedYieldInfoArray = {};
		for row in GameInfo.Yields() do
			local yieldEntry = hmake YieldInfo { 
												ID = row.ID,
												Type = row.Type,
												Description = row.Description,
												IconString = row.IconString
												};
			table.insert(CachedYieldInfoArray, yieldEntry);
		end
	end


	if (CachedTerrainInfoArray == nil) then
		CachedTerrainInfoArray = {};
		for row in GameInfo.Terrains() do
			local terrainEntry = hmake TerrainInfo { 
												ID = row.ID,
												Type = row.Type,
												Description = row.Description,
												};

			table.insert(CachedTerrainInfoArray, terrainEntry);
		end
	end

	-- Cached Feature Infos
	if (CachedFeatureInfoArray == nil) then
		CachedFeatureInfoArray = {};
		for row in GameInfo.Features() do
			local featureEntry = hmake FeatureInfo { 
												ID = row.ID,
												Type = row.Type,
												Description = row.Description
												};
			table.insert(CachedFeatureInfoArray, featureEntry);
		end
	end

	-- Cached Resource Infos
	if (CachedResourceInfoArray == nil) then
		CachedResourceInfoArray = {};
		for row in GameInfo.Resources() do
			local resourceEntry = hmake ResourceInfo { 
												ID = row.ID,
												Type = row.Type,
												Description = row.Description,
												IconString = row.IconString
												};
			table.insert(CachedResourceInfoArray, resourceEntry);
		end
	end

	-- Cached Domain Infos
	if (CachedDomainInfoArray == nil) then
		CachedDomainInfoArray = {};
		for row in GameInfo.Domains() do
			local domainEntry = hmake DomainInfo { 
												ID = row.ID,
												Type = row.Type,
												Description = row.Description
												};
			table.insert(CachedDomainInfoArray, domainEntry);
		end
	end

	-- Cached Building Infos
	if (CachedBuildingInfoArray == nil) then
		CachedBuildingInfoArray = {};
		for row in GameInfo.Buildings() do
			local buildingEntry = hmake BuildingInfo { 
												ID = row.ID,
												Type = row.Type,
												Description = row.Description,
												BuildingClass = row.BuildingClass,
												SpecialistCount = row.SpecialistCount
												};
			table.insert(CachedBuildingInfoArray, buildingEntry);
		end
	end

	-- Cached Unit Promotion Infos
	if (CachedUnitPromotionInfoArray == nil) then
		CachedUnitPromotionInfoArray = {};
		for row in GameInfo.UnitPromotions() do
			local promotionEntry = hmake UnitPromotionInfo {
												ID = row.ID,
												Help = row.Help
												};
			table.insert(CachedUnitPromotionInfoArray, promotionEntry);
		end
	end

	-- Cached Unit Free Promotions Infos
	if (CachedUnitFreePromotionsInfoArray == nil) then
		CachedUnitFreePromotionsInfoArray = {};
		for row in GameInfo.Unit_FreePromotions() do
			local pairEntry = hmake UnitFreePromotionsInfo {
												UnitType = row.UnitType,
												PromotionType = row.PromotionType
												};
			table.insert(CachedUnitFreePromotionsInfoArray, pairEntry);
		end
	end

end

function InsertYieldString( insertTable : table, positiveString : string, negativeString : string, iYield : number, ... )

	if (arg.n == 3) then
		if(iYield > 0) then
			table.insert(insertTable, Locale.ConvertTextKey(positiveString, iYield, arg[1], arg[2], arg[3]));
		elseif(iYield < 0) then
			table.insert(insertTable, Locale.ConvertTextKey(negativeString, math.abs(iYield), arg[1], arg[2], arg[3]));
		end
	end

	if (arg.n == 4) then
		if(iYield > 0) then
			table.insert(insertTable, Locale.ConvertTextKey(positiveString, iYield, arg[1], arg[2], arg[3], arg[4]));
		elseif(iYield < 0) then
			table.insert(insertTable, Locale.ConvertTextKey(negativeString, math.abs(iYield), arg[1], arg[2], arg[3], arg[4]));
		end
	end
end

-- ===========================================================================
----------------------------------------------------------------
-- UNIT
----------------------------------------------------------------
-- ===========================================================================
function GetHelpTextForUnit(iUnitID, bIncludeRequirementsInfo, city : object)

	CacheDatabaseQueries();

	local pUnitInfo = GameInfo.Units[iUnitID];
	local pOrbitalInfo = nil;
	if (pUnitInfo.Orbital ~= nil) then
		pOrbitalInfo = GameInfo.OrbitalUnits[pUnitInfo.Orbital];
	end
	
	local pActivePlayer = Players[Game.GetActivePlayer()];
	local pActiveTeam = Teams[Game.GetActiveTeam()];

	local strHelpText = "";
	
	-- Name
	local descriptionKey = pUnitInfo.Description;
	local bestUpgrade = pActivePlayer:GetBestUnitUpgrade(iUnitID);
	if (bestUpgrade ~= -1) then
		local bestUpgradeInfo = GameInfo.UnitUpgrades[bestUpgrade];
		if (bestUpgradeInfo ~= nil) then
			descriptionKey = bestUpgradeInfo.Description;
		end
	end
	strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey( descriptionKey ));
	
	-- Cost
	strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
	
	-- Skip cost if it's 0
	if (pActivePlayer:IsUnitClassFreeToBuild(GameInfo.UnitClasses[pUnitInfo.Class].ID)) then
		strHelpText = strHelpText .. "[ICON_PRODUCTION] " .. Locale.Lookup("TXT_KEY_FREE");
	elseif(pUnitInfo.Cost > 0) then
		local productionNeeded : number = 0;

		if(city ~= nil) then
			productionNeeded = city:GetUnitProductionNeeded(iUnitID);
		else
			productionNeeded = pActivePlayer:GetUnitProductionNeeded(iUnitID);
		end

		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_COST", productionNeeded);
	end
	
	-- Moves
	if pOrbitalInfo == nil and pUnitInfo.Domain ~= "DOMAIN_AIR" then
		local iMoves = pActivePlayer:GetBaseMovesWithPerks(iUnitID);
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_MOVEMENT", iMoves);
	end

	-- Orbital Duration
	if (pOrbitalInfo ~= nil) then
		local includeGameplayModifiers = true;
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_ORBITAL_DURATION", pActivePlayer:GetTurnsUnitAllowedInOrbit(iUnitID, includeGameplayModifiers));
	end

	-- Orbital Effect Range
	if (pOrbitalInfo ~= nil) then
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_ORBITAL_EFFECT_RANGE", pOrbitalInfo.EffectRange);
	end
	
	-- Range
	local iRange = pActivePlayer:GetBaseRangeWithPerks(iUnitID);
	if (pOrbitalInfo == nil and iRange ~= 0) then
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_RANGE", iRange);
	end
	
	-- Ranged Strength
	local iRangedStrength = pActivePlayer:GetBaseRangedCombatStrengthWithPerks(iUnitID);
	if (iRangedStrength ~= 0) then
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_RANGED_STRENGTH", iRangedStrength);
	end
	
	-- Strength
	local iStrength = pActivePlayer:GetBaseCombatStrengthWithPerks(iUnitID);
	if (iStrength ~= 0) then
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_STRENGTH", iStrength);
	end

	-- Invisibility
	if (pUnitInfo.Invisibility) then
		strHelpText = strHelpText .. "[NEWLINE]";
		strHelpText = strHelpText .. "[COLOR_YELLOW]" .. Locale.Lookup("TXT_KEY_TERM_INVISIBILITY") .. "[ENDCOLOR]";
	end
	
	-- Strategic Resource Requirements
	local iNumResourcesNeededSoFar = 0;
	local iNumResourceNeeded;
	local iResourceID;
	for pResource in GameInfo.Resources() do
		iResourceID = pResource.ID;
		iNumResourceNeeded = Game.GetNumResourceRequiredForUnit(iUnitID, iResourceID);
		if (iNumResourceNeeded > 0) then
			-- First resource required
			if (iNumResourcesNeededSoFar == 0) then
				strHelpText = strHelpText .. "[NEWLINE]";
				strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_RESOURCES_REQUIRED");
				strHelpText = strHelpText .. " " .. iNumResourceNeeded .. " " .. pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description);
			else
				strHelpText = strHelpText .. ", " .. iNumResourceNeeded .. " " .. pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description);
			end
		end
	end

	-- Affinity Level Requirement
	local levelDiscount : number = pActivePlayer:GetUnitAffinityRequirementDiscount();
	for k,v in pairs(CachedUnitAffinityPrereqs) do
		if k == pUnitInfo.Type then
			for affinityType,level in pairs(v) do
				local requiredLevel : number = math.max(level - levelDiscount, 0);
				if (requiredLevel > 0) then
					local affinityInfo = GameInfo.Affinity_Types[affinityType];
					local affinityPrereqString = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_REQUIRED", affinityInfo.ColorType, requiredLevel, affinityInfo.IconString, affinityInfo.Description);
					strHelpText = strHelpText .. "[NEWLINE]";
					strHelpText = strHelpText .. affinityPrereqString;
				end
			end
		end
	end
	
	-- Pre-written Help text
	if (not pUnitInfo.Help) then
		print("Invalid unit help");
		print(strHelpText);
	else
		local strWrittenHelpText = Locale.ConvertTextKey( pUnitInfo.Help );
		if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
			-- Separator
			strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
			strHelpText = strHelpText .. strWrittenHelpText;
		end	
	end
	
	
	-- Requirements?
	if (bIncludeRequirementsInfo) then
		if (pUnitInfo.Requirements) then
			strHelpText = strHelpText .. Locale.ConvertTextKey( pUnitInfo.Requirements );
		end
	end
	
	return strHelpText;
	
end

-- ===========================================================================
----------------------------------------------------------------
-- BUILDING
----------------------------------------------------------------
-- ===========================================================================
function GetHelpTextForBuilding(iBuildingID, bExcludeName, bExcludeHeader, bNoMaintenance, pCity)

	CacheDatabaseQueries();

	local pBuildingInfo = GameInfo.Buildings[iBuildingID];
	 
	local activePlayerID = Game.GetActivePlayer();
	local pActivePlayer = Players[activePlayerID];
	local activeTeamID = Game.GetActiveTeam();
	local pActiveTeam = Teams[activeTeamID];
	
	local buildingClass = GameInfo.Buildings[iBuildingID].BuildingClass;
	local buildingClassID = GameInfo.BuildingClasses[buildingClass].ID;
	
	local strHelpText = "";
	
	-- Get the active perk types.  It is better to get this once and pass it around, rather than having each function re-get it every time.
	local activePerkTypes = pActivePlayer:GetAllActivePlayerPerkTypes();

	local lines = {};
	if (not bExcludeHeader) then
		
		if (not bExcludeName) then
			-- Name
			strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey( pBuildingInfo.Description ));
			strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
		end
		
		-- Cost
		--Only show cost info if the cost is greater than 0.
		if(pBuildingInfo.Cost > 0) then
			local iCost = pActivePlayer:GetBuildingProductionNeeded(iBuildingID);
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_COST", iCost));
		end

		-- Strategic Resource Cost
		local buildingResourceRequirement = CachedBuildingResourceQuantityRequirements[pBuildingInfo.Type];
		if (buildingResourceRequirement ~= nil) then
			local resourceInfo = GameInfo.Resources[buildingResourceRequirement.ResourceType];
			local iNumResourceNeeded = Game.GetNumResourceRequiredForBuilding(pBuildingInfo.ID, resourceInfo.ID);
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_RESOURCE_QUANTITY_COST", resourceInfo.IconString, resourceInfo.Description, iNumResourceNeeded));
		end

		-- Maintenance
		if (not bNoMaintenance) then
			local iMaintenance = pBuildingInfo.EnergyMaintenance;
			-- changes from PLAYER PERKS
			local iEnergyMaintenanceChange = GetPlayerPerkBuildingEnergyMaintenanceChanges(activePerkTypes, activePlayerID, iBuildingID);
			if (iEnergyMaintenanceChange ~= nil and iEnergyMaintenanceChange ~= 0) then
				iMaintenance = math.max(iMaintenance + iEnergyMaintenanceChange, 0);
			end
			if (iMaintenance ~= nil and iMaintenance ~= 0) then		
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PEDIA_MAINT_LABEL") .. " " .. "[ICON_ENERGY] " .. tostring(iMaintenance));
			end
		end

		-- Commit HEADER strings		
		strHelpText = strHelpText .. table.concat(lines, "[NEWLINE]");
		-- Clear table for next category
		lines = {};		
	end
	
	----------------------------------------
	-- STANDARD YIELDS
	local hasStandardYields : boolean = false;

	for yieldIndex, yieldInfo in ipairs(CachedYieldInfoArray) do
		local eYield = yieldInfo.ID;

		-- FLAT Yield from the building
		local iFlatYield = Game.GetBuildingYieldChange(iBuildingID, eYield);
		if (pCity ~= nil) then
			iFlatYield = iFlatYield + pCity:GetReligionBuildingClassYieldChange(buildingClassID, eYield) + pActivePlayer:GetPlayerBuildingClassYieldChange(buildingClassID, eYield);
			iFlatYield = iFlatYield + pCity:GetLeagueBuildingClassYieldChange(buildingClassID, eYield);
		end
		-- FLAT Yield changes from PLAYER PERKS
		local iFlatYieldFromPerks = GetPlayerPerkBuildingFlatYieldChanges(activePerkTypes, activePlayerID, iBuildingID, eYield);
		if (iFlatYieldFromPerks ~= nil and iFlatYieldFromPerks ~= 0) then
			iFlatYield = iFlatYield + iFlatYieldFromPerks;
		end

		if (iFlatYield ~= nil and iFlatYield ~= 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_TOOLTIP_POSITIVE_YIELD", yieldInfo.IconString, yieldInfo.Description, iFlatYield));
		end

		-- MOD Yield from the building
		local iModYield = Game.GetBuildingYieldModifier(iBuildingID, eYield);
		-- MOD from Virtues
		iModYield = iModYield + pActivePlayer:GetPolicyBuildingClassYieldModifier(buildingClassID, eYield);
		-- MOD from Player Perks
		local iModYieldFromPerks = GetPlayerPerkBuildingPercentYieldChanges(activePerkTypes, activePlayerID, iBuildingID, eYield);
		iModYield = iModYield + iModYieldFromPerks;

		if (iModYield ~= nil and iModYield > 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_TOOLTIP_POSITIVE_YIELD_MOD_LOCAL", yieldInfo.IconString, yieldInfo.Description, iModYield));
		end
	end

	-- HEALTH

	-- FLAT Health
	local iHealthTotal = 0;
	local iHealth = pBuildingInfo.Health;
	if (iHealth ~= nil) then
		iHealthTotal = iHealthTotal + iHealth;
	end
	-- Health from Virtues
	iHealthTotal = iHealthTotal + pActivePlayer:GetExtraBuildingHealthFromPolicies(iBuildingID);
	--if (pCity ~= nil) then
		--iHealthTotal = iHealthTotal + pCity:GetReligionBuildingClassHealth(buildingClassID) + pActivePlayer:GetPlayerBuildingClassHealth(buildingClassID);
	--end
	-- Health from Player Perks
	local iHealthFromPerks = GetPlayerPerkBuildingFlatHealthChanges(activePerkTypes, activePlayerID, iBuildingID);
	iHealthTotal = iHealthTotal + iHealthFromPerks;
	-- TOTAL Health FLAT
	if (iHealthTotal ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_HEALTH_TT", iHealthTotal));
	end

	-- MOD Health
	local iHealthMod = pBuildingInfo.HealthModifier;
	local iHealthModFromPerks = GetPlayerPerkBuildingPercentHealthChanges(activePerkTypes, activePlayerID, iBuildingID);
	iHealthMod = iHealthMod + iHealthModFromPerks;	
	-- TOTAL MOD Health
	if (iHealthMod ~= nil and iHealthMod ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_TOOLTIP_POSITIVE_YIELD_MOD", HEALTH_ICON, "TXT_KEY_HEALTH", iHealthMod));
	end
	
	-- City Strength (Defense)
	local iDefense = pBuildingInfo.Defense;
	-- City Strength from PLAYER PERKS
	local iCityStrengthFromPerks = GetPlayerPerkBuildingCityStrengthChanges(activePerkTypes, activePlayerID, iBuildingID);
	if (iCityStrengthFromPerks ~= nil and iCityStrengthFromPerks ~= 0) then
		iDefense = iDefense + iCityStrengthFromPerks;
	end

	if (iDefense ~= nil and iDefense ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_DEFENSE_TT", iDefense / 100));
	end	
	
	-- City Hit Points
	local iHitPoints = pBuildingInfo.ExtraCityHitPoints;
	-- City Hit Points from PLAYER PERKS
	local iCityHPFromPerks = GetPlayerPerkBuildingCityHPChanges(activePerkTypes, activePlayerID, iBuildingID);
	if (iCityHPFromPerks ~= nil and iCityHPFromPerks ~= 0) then
		iHitPoints = iHitPoints + iCityHPFromPerks;
	end

	if (iHitPoints ~= nil and iHitPoints ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_PRODUCTION_BUILDING_HITPOINTS_TT", iHitPoints));
	end

	-- City Strike Damage	
	local iCityStrikeDamage = pBuildingInfo.CityStrikeModifier;
	-- City Strike Damage from PLAYER PERKS
	local iCityStrikeDamageFromPerks = GetPlayerPerkBuildingCityStrikeDamageMod(activePerkTypes, activePlayerID, iBuildingID);
	if (iCityStrikeDamageFromPerks ~= nil and iCityStrikeDamageFromPerks ~= 0) then
		iCityStrikeDamage = iCityStrikeDamage + iCityStrikeDamageFromPerks;
	end

	if (iCityStrikeDamage ~= nil and iCityStrikeDamage ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_BUILDING_CITY_STRIKE_MODIFIER", iCityStrikeDamage));
	end

	-- If there are standard yields to add
	if #lines > 0 then

		hasStandardYields = true;
		-- SEPARATOR at the top of this category (if this isn't the first category)
		if (strHelpText ~= nil and strHelpText ~= "") then
			table.insert(lines, 1, "[NEWLINE]----------------");
		end
		-- Commit STANDARD strings
		strHelpText = strHelpText .. table.concat(lines, "[NEWLINE]");
		-- Clear table for next category
		lines = {};
	end

	----------------------------------------
	-- SPECIAL YIELDS and EFFECTS
	for yieldIndex, yieldInfo in ipairs(CachedYieldInfoArray) do
		local eYield = yieldInfo.ID;
		
		-- Yield from TERRAIN
		for terrainIndex, terrainInfo in ipairs(CachedTerrainInfoArray) do
			local iTerrainYield = Game.GetBuildingFlatYieldFromTerrain(iBuildingID, eYield, terrainInfo.ID);
			if (iTerrainYield ~= nil and iTerrainYield > 0) then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_LOCAL_TERRAIN", iTerrainYield, yieldInfo.IconString, yieldInfo.Description, terrainInfo.Description));
			end
		end

		-- Yield from FEATURES
		for featureIndex, featureInfo in ipairs(CachedFeatureInfoArray) do
			local iFeatureYield = Game.GetBuildingFlatYieldFromFeature(iBuildingID, eYield, featureInfo.ID);
			if (iFeatureYield ~= nil and iFeatureYield > 0) then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_LOCAL_FEATURES", iFeatureYield, yieldInfo.IconString, yieldInfo.Description, featureInfo.Description));
			end
		end

		-- Yield from RESOURCES
		for resourceIndex, resourceInfo in ipairs(CachedResourceInfoArray) do
			local iResourceYield = Game.GetBuildingFlatYieldFromResource(iBuildingID, eYield, resourceInfo.ID);
			if (iResourceYield ~= nil and iResourceYield > 0) then
				table.insert(lines, Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_LOCAL_RESOURCES", iResourceYield, yieldInfo.IconString, yieldInfo.Description, resourceInfo.IconString, resourceInfo.Description));
			end
		end

		--Yields from TRADE ROUTES
		local tradeTypeStr = "TXT_KEY_EO_TRADE";
		if (Game.GetDefaultTradeTypeForYield(eYield) == TradeConnectionTypes.TRADE_CONNECTION_INTERNATIONAL) then
			tradeTypeStr = "TXT_KEY_EO_INTERNATIONAL_OR_STATION_TRADE";
		elseif (Game.GetDefaultTradeTypeForYield(eYield) == TradeConnectionTypes.TRADE_CONNECTION_INTERNAL_CITY) then
			tradeTypeStr = "TXT_KEY_EO_INTERNAL_OR_STATION_TRADE";
		end
		-- FLAT
		local iFlatTradeYield = Game.GetBuildingTradeYieldChange(iBuildingID, eYield);
		if (iFlatTradeYield ~= nil and iFlatTradeYield ~= 0) then
			InsertYieldString(lines, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iFlatTradeYield, yieldInfo.IconString, yieldInfo.Description, tradeTypeStr);
		end

		-- MOD
		local iModTradeYield = Game.GetBuildingTradeYieldModifier(iBuildingID, eYield);
		if (iModTradeYield ~= nil and iModTradeYield ~= 0) then
			InsertYieldString(lines, "TXT_KEY_YIELD_MOD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_MOD_FROM_SPECIFIC_OBJECT", iModTradeYield, yieldInfo.IconString, yieldInfo.Description, tradeTypeStr);
		end
	end

	-- Map Effects (buffs from terrain, features, resources)

	-- Special from TERRAIN
	for terrainIndex, terrainInfo in ipairs(CachedTerrainInfoArray) do
		-- Health
		local iTerrainHealth = Game.GetBuildingFlatHealthFromTerrain(iBuildingID, terrainInfo.ID);
		if (iTerrainHealth ~= nil and iTerrainHealth ~= 0) then
			InsertYieldString(lines, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iTerrainHealth, HEALTH_ICON, "TXT_KEY_HEALTH", terrainInfo.Description);
		end
	end
	
	-- Special from FEATURES
	for featureIndex, featureInfo in ipairs(CachedFeatureInfoArray) do
		-- Health
		local iFeatureHealth = Game.GetBuildingFlatHealthFromFeature(iBuildingID, featureInfo.ID);
		if (iFeatureHealth ~= nil and iFeatureHealth ~= 0) then
			InsertYieldString(lines, "TXT_KEY_YIELD_FROM_SPECIFIC_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_OBJECT", iFeatureHealth, HEALTH_ICON, "TXT_KEY_HEALTH", featureInfo.Description);
		end
	end

	-- Special from RESOURCES
	for resourceIndex, resourceInfo in ipairs(CachedResourceInfoArray) do
		-- Health
		local iResourceHealth = Game.GetBuildingFlatHealthFromResource(iBuildingID, resourceInfo.ID);
		if (iResourceHealth ~= nil and iResourceHealth ~= 0) then
			InsertYieldString(lines, "TXT_KEY_YIELD_FROM_SPECIFIC_ICON_OBJECT", "TXT_KEY_NEGATIVE_YIELD_FROM_SPECIFIC_ICON_OBJECT", iResourceHealth, HEALTH_ICON, "TXT_KEY_HEALTH", resourceInfo.IconString, resourceInfo.Description);
		end
	end

	-- GROWTH Carryover
	local iGrowthCarryover = pBuildingInfo.FoodKept;
	-- Military Units Production from PLAYER PERKS
	local iGrowthCarryoverFromPerks = GetPlayerPerkBuildingGrowthCarryoverChange(activePerkTypes, activePlayerID, iBuildingID);
	if (iGrowthCarryoverFromPerks ~= nil and iGrowthCarryoverFromPerks ~= 0) then
		iGrowthCarryover = iGrowthCarryover + iGrowthCarryoverFromPerks;
	end
	if (iGrowthCarryover ~= nil and iGrowthCarryover ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_GROWTH_CARRYOVER_MOD", iGrowthCarryover));
	end

	-- DOMAIN Production Modifiers
	for domainIndex, domainInfo in ipairs(CachedDomainInfoArray) do
		local iDomainProductionMod = Game.GetBuildingDomainProductionModifier(iBuildingID, domainInfo.ID);
		-- Modifiers from PLAYER PERKS -- Naval
		if (domainInfo.Type == "DOMAIN_SEA") then
			local iNavalProductionModFromPerks = GetPlayerPerkBuildingNavalProductionMod(activePerkTypes, activePlayerID, iBuildingID);
			if (iNavalProductionModFromPerks ~= nil and iNavalProductionModFromPerks ~= 0) then
				iDomainProductionMod = iDomainProductionMod + iNavalProductionModFromPerks;
			end
		end
		if (iDomainProductionMod ~= nil and iDomainProductionMod ~= 0) then
			table.insert(lines, Locale.ConvertTextKey("TXT_KEY_DOMAIN_PRODUCTION_MOD", iDomainProductionMod, domainInfo.Description));
		end
	end

	-- Military Units Production
	local iMilitaryProductionMod = pBuildingInfo.MilitaryProductionModifier;
	-- Military Units Production from PLAYER PERKS
	local iMilitaryProductionModFromPerks = GetPlayerPerkBuildingMilitaryProductionMod(activePerkTypes, activePlayerID, iBuildingID);
	if (iMilitaryProductionModFromPerks ~= nil and iMilitaryProductionModFromPerks ~= 0) then
		iMilitaryProductionMod = iMilitaryProductionMod + iMilitaryProductionModFromPerks;
	end
	if (iMilitaryProductionMod ~= nil and iMilitaryProductionMod ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_MILITARY_PRODUCTION_MOD", iMilitaryProductionMod));
	end

	-- Orbital Production
	local iOrbitalProductionMod = pBuildingInfo.OrbitalProductionModifier;
	if (iOrbitalProductionMod ~= nil and iOrbitalProductionMod ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_DOMAIN_PRODUCTION_MOD", iOrbitalProductionMod, "TXT_KEY_ORBITAL_UNITS"));
	end

	-- Orbital Coverage
	local iOrbitalCoverage = pBuildingInfo.OrbitalCoverageChange;
	-- Orbital Coverage from PLAYER PERKS
	local iOrbitalCoverageFromPerks = GetPlayerPerkBuildingOrbitalCoverageChanges(activePerkTypes, activePlayerID, iBuildingID);
	if (iOrbitalCoverageFromPerks ~= nil and iOrbitalCoverageFromPerks ~= 0) then
		iOrbitalCoverage = iOrbitalCoverage + iOrbitalCoverageFromPerks;
	end
	if (iOrbitalCoverage ~= nil and iOrbitalCoverage ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_BUILDING_ORBITAL_COVERAGE", iOrbitalCoverage));
	end

	-- Anti-Orbital Strike
	local iOrbitalStrikeRangeChange = pBuildingInfo.OrbitalStrikeRangeChange;
	if (iOrbitalStrikeRangeChange ~= nil and iOrbitalStrikeRangeChange ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_UNITPERK_RANGE_AGAINST_ORBITAL_CHANGE", iOrbitalStrikeRangeChange));
	end

	-- Covert Ops Intrigue Cap
	local iIntrigueCapChange = pBuildingInfo.IntrigueCapChange;
	if (iIntrigueCapChange ~= nil and iIntrigueCapChange < 0) then
		local iIntrigueLevelsChange = (iIntrigueCapChange * -1) / (100 / GameDefines.MAX_CITY_INTRIGUE_LEVELS); -- Make it positive to show in UI
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_BUILDING_CITY_INTRIGUE_CAP", iIntrigueLevelsChange));
	end

	-- Move City Cost Mod
	local iCityMoveCostMod = pBuildingInfo.CityMoveCostModifier;
	-- City Move Cost from PLAYER PERKS
	local iMoveCostModFromPerks = GetPlayerPerkBuildingCityMoveCostMod(activePerkTypes, activePlayerID, iBuildingID);
	if (iMoveCostModFromPerks ~= nil and iMoveCostModFromPerks ~= 0) then
		iCityMoveCostMod = iCityMoveCostMod + iMoveCostModFromPerks;
	end
	if (iCityMoveCostMod ~= nil and iCityMoveCostMod ~= 0) then
		table.insert(lines, Locale.ConvertTextKey("TXT_KEY_BUILDING_MOVE_COST_MOD", iCityMoveCostMod));
	end

	-- Specialist slots
	local strSpecialistType = pBuildingInfo.SpecialistType;
	if strSpecialistType ~= nil then
		table.insert(lines, GetSpecialistSlotsTooltip(pBuildingInfo.SpecialistType, pBuildingInfo.SpecialistCount));
	end

	-- Pre-written HELP TEXT
	if (pBuildingInfo.Help ~= nil) then
		local strWrittenHelpText = Locale.ConvertTextKey( pBuildingInfo.Help );
		if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
			table.insert(lines, strWrittenHelpText);
		end
	end

	-- Only add if this building has any special effects
	if #lines > 0 then

		-- SEPARATOR at the top of this category (if not the first category)
		if (strHelpText ~= nil and strHelpText ~= "") then
			if hasStandardYields then	
				table.insert(lines, 1, "[NEWLINE]");
			else
				table.insert(lines, 1, "[NEWLINE]----------------");
			end
		end
		
		-- Commit SPECIAL strings
		strHelpText = strHelpText .. table.concat(lines, "[NEWLINE]");
		-- Clear table for next category
		lines = {};
	end

	----------------------------------------
	-- REQUIREMENTS

	-- Local OR Resource Requirements
	local resourceLocalOrTable = {};
	local resourcePresentAtCity : boolean = (pCity ~= nil);

	local buildingLocalResourceOrs = CachedBuildingLocalResourceOrs[pBuildingInfo.Type];
	if (buildingLocalResourceOrs ~= nil) then
		for i, resourceType in ipairs(buildingLocalResourceOrs) do
			local resourceInfo = GameInfo.Resources[resourceType];
			table.insert(resourceLocalOrTable, resourceInfo);

			if (pCity ~= nil) then
				if (not pCity:IsHasResourceLocal(resourceInfo.ID)) then
					resourcePresentAtCity = false;
				end
			end
		end
	end

	if #resourceLocalOrTable > 0 then
		local resourceOrString = "";
		if #resourceLocalOrTable > 1 then
			resourceOrString = Locale.ConvertTextKey("TXT_KEY_BUILDING_LOCAL_RESOURCES_OR_REQUIRED");
			for i,pair in ipairs(resourceLocalOrTable) do
				resourceOrString = resourceOrString .. Locale.ConvertTextKey(pair.IconString) .. " " .. Locale.ConvertTextKey(pair.Description);
				if i < #resourceLocalOrTable then
					resourceOrString = resourceOrString .. ",";
				end
			end
		else
			resourceOrString = Locale.ConvertTextKey("TXT_KEY_BUILDING_LOCAL_RESOURCES_OR_REQUIRED_ONE", resourceLocalOrTable[1].IconString, resourceLocalOrTable[1].Description);
		end

		if (resourcePresentAtCity) then
			table.insert(lines, resourceOrString);
		else
			table.insert(lines, "[COLOR_WARNING_TEXT]" .. resourceOrString .. "[ENDCOLOR]");
		end
	end

	-- Local Terrain Requirements
	if pBuildingInfo.Land == true then
		local landCityString = Locale.Lookup("TXT_KEY_BUILDING_LAND_CITY_REQUIRED");
		table.insert(lines, "[COLOR_WARNING_TEXT]" .. landCityString .. "[ENDCOLOR]");
	elseif pBuildingInfo.WaterOnly == true then
		local waterCityString = Locale.Lookup("TXT_KEY_BUILDING_WATER_CITY_REQUIRED");
		table.insert(lines, "[COLOR_WARNING_TEXT]" .. waterCityString .. "[ENDCOLOR]");
	elseif pBuildingInfo.WaterAccess == true then
		local coastalCityString = Locale.Lookup("TXT_KEY_BUILDING_WATER_ACCESS_REQUIRED");
		table.insert(lines, "[COLOR_WARNING_TEXT]" .. coastalCityString .. "[ENDCOLOR]");
	end

	if pBuildingInfo.NearbyTerrainRequired ~= nil then
		local pTerrainInfo = GameInfo.Terrains[pBuildingInfo.NearbyTerrainRequired];
		local nearbyTerrainStr = Locale.Lookup("TXT_KEY_BUILDING_NEARBY_TERRAIN_REQUIRED", pTerrainInfo.Description);
		table.insert(lines, "[COLOR_WARNING_TEXT]" .. nearbyTerrainStr .. "[ENDCOLOR]");
	end

	-- Affinity Level Requirement
	local levelDiscount : number = pActivePlayer:GetBuildingAffinityRequirementDiscount();
	local buildingAffinityPrereq = CachedBuildingAffinityPrereqs[pBuildingInfo.Type];
	if (buildingAffinityPrereq ~= nil) then
		local requiredLevel : number = math.max(buildingAffinityPrereq.Level - levelDiscount, 0);
		if (requiredLevel > 0) then
			local affinityInfo = GameInfo.Affinity_Types[buildingAffinityPrereq.AffinityType];
			local affinityPrereqString = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_REQUIRED", affinityInfo.ColorType, requiredLevel, affinityInfo.IconString, affinityInfo.Description);
			table.insert(lines, affinityPrereqString .. "[ENDCOLOR]");
		end
	end

	-- Only add if this building has any special requirements
	if #lines > 0 then
		-- SEPARATOR at the top of this category
		if (strHelpText ~= nil and strHelpText ~= "") then
			table.insert(lines, 1, "[NEWLINE]----------------");
		end
		-- Commit REQUIREMENT strings
		strHelpText = strHelpText .. table.concat(lines, "[NEWLINE]");
		-- Clear table for next category
		lines = {};
	end

	----------------------------------------
	-- Pre-written STRATEGY TEXT
	if (pBuildingInfo.Strategy ~= nil) then
		local strStrategyText = Locale.ConvertTextKey( pBuildingInfo.Strategy );
		if (strStrategyText ~= nil and strStrategyText ~= "") then
			-- Separator
			if (strHelpText ~= nil and strHelpText ~= "") then
				strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
			end
			strHelpText = strHelpText .. strStrategyText;
		end
	end
	
	----------------------------------------
	-- DONE!

	return strHelpText;	
end

-- ===========================================================================
----------------------------------------------------------------
-- IMPROVEMENT
----------------------------------------------------------------
-- ===========================================================================
function GetHelpTextForImprovement(iImprovementID, bExcludeName, bExcludeHeader, bNoMaintenance)

	CacheDatabaseQueries();

	local pImprovementInfo = GameInfo.Improvements[iImprovementID];
	
	local pActivePlayer = Players[Game.GetActivePlayer()];
	local pActiveTeam = Teams[Game.GetActiveTeam()];
	
	local strHelpText = "";
	
	if (not bExcludeHeader) then
		
		if (not bExcludeName) then
			-- Name
			strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey( pImprovementInfo.Description ));
		end
				
	end	
	
	-- Pre-written Help text
	if (pImprovementInfo.Help ~= nil) then
		local strWrittenHelpText = Locale.ConvertTextKey( pImprovementInfo.Help );
		if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
			-- Separator
			strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
			strHelpText = strHelpText .. strWrittenHelpText;
		end
	end
	
	-- BENEFIT strings
	local yieldLines = {};
	for row in GameInfo.Improvement_Yields{ ImprovementType = pImprovementInfo.Type} do
		local yieldInfo = GameInfo.Yields[row.YieldType];
		table.insert(yieldLines, Locale.ConvertTextKey(yieldInfo.IconString .. " " .. tostring(row.Yield)));
	end

	if (#yieldLines > 0) then
		-- Separator
		strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_TT_TERM_YIELDS") .. table.concat(yieldLines, " ");
	end

	-- COST strings
	local maintenanceLines = {};

	-- Maintenance
	if (not bNoMaintenance) then

		-- Energy
		local iMaintenance = pImprovementInfo.EnergyMaintenance;
		if (iMaintenance ~= nil and iMaintenance ~= 0) then
			local energyMaint = "[ICON_ENERGY] " .. tostring(iMaintenance);
			table.insert(maintenanceLines, energyMaint);
		end

		-- Unhealth
		local iUnhealth = pImprovementInfo.Unhealth;
		if (iUnhealth ~= nil and iUnhealth ~= 0) then		
			local unhealthMaint = "[ICON_HEALTH_4] " .. tostring(iUnhealth);
			table.insert(maintenanceLines, unhealthMaint);
		end
	end

	if #maintenanceLines > 0 then
		-- Separator
		strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
		-- Commit COST strings
		local allMaintenance = Locale.ConvertTextKey("TXT_KEY_PEDIA_MAINT_LABEL") .. " " .. table.concat(maintenanceLines, " ");
		strHelpText = strHelpText .. allMaintenance;
	end

	-- REQUIREMENTS

	-- No Miasma
	if (pImprovementInfo.NoMiasma == true) then
		local noMiasmaStr = Locale.Lookup("TXT_KEY_IMPROVEMENT_NO_MIASMA");
		strHelpText = strHelpText .. "[NEWLINE][COLOR_WARNING_TEXT]" .. noMiasmaStr .. "[ENDCOLOR]";
	end

	return strHelpText;
end


-- ===========================================================================

-- PROJECT

-- ===========================================================================

function GetHelpTextForProject(iProjectID, bIncludeRequirementsInfo)

	CacheDatabaseQueries();

	local pProjectInfo = GameInfo.Projects[iProjectID];
	
	local pActivePlayer = Players[Game.GetActivePlayer()];
	local pActiveTeam = Teams[Game.GetActiveTeam()];
	
	local strHelpText = "";
	
	-- Name
	strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey( pProjectInfo.Description ));
	
	-- Cost
	local iCost = pActivePlayer:GetProjectProductionNeeded(iProjectID);
	strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
	strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_COST", iCost);
	
	-- Affinity Level Requirement
	local levelDiscount : number = pActivePlayer:GetBuildingAffinityRequirementDiscount();
	local projectAffinityPrereq = CachedProjectAffinityPrereqs[pProjectInfo.Type];
	if (projectAffinityPrereq ~= nil) then
		local requiredLevel : number = math.max(projectAffinityPrereq.Level - levelDiscount, 0);
		if (projectAffinityPrereq.Level > 0) then
			local affinityInfo = GameInfo.Affinity_Types[projectAffinityPrereq.AffinityType];
			local affinityPrereqString = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_REQUIRED", affinityInfo.ColorType, requiredLevel, affinityInfo.IconString, affinityInfo.Description);
			strHelpText = strHelpText .. "[NEWLINE]" .. affinityPrereqString;
		end
	end

	-- Other Requirements?
	if (bIncludeRequirementsInfo) then
		if (pProjectInfo.Requirements) then
			strHelpText = strHelpText .. Locale.ConvertTextKey( pProjectInfo.Requirements );
		end
	end

	-- Pre-written Help text
	local strWrittenHelpText = Locale.ConvertTextKey( pProjectInfo.Help );
	if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
		-- Separator
		strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
		strHelpText = strHelpText .. strWrittenHelpText;
	end
	
	return strHelpText;
	
end

-- ===========================================================================

-- PROCESS

-- ===========================================================================

function GetHelpTextForProcess(iProcessID, bIncludeRequirementsInfo)

	CacheDatabaseQueries();

	local pProcessInfo = GameInfo.Processes[iProcessID];
	local pActivePlayer = Players[Game.GetActivePlayer()];
	local pActiveTeam = Teams[Game.GetActiveTeam()];
	
	local strHelpText = "";
	
	-- Name
	strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey(pProcessInfo.Description));
	
	-- Pre-written Help text

	-- Intercept HEALTH process since it's not a true yield
	if (GameInfo.Processes[iProcessID].ProductionToHealthModifier ~= 0) then

		local yield : number = GameInfo.Processes[iProcessID].ProductionToHealthModifier;
		
		local extraYield : number = pActivePlayer:GetExtraProcessYieldRate(-1);
		if (extraYield ~= 0) then
			yield = yield + extraYield;
		end

		-- Buffs?
		local yieldMod = pActivePlayer:GetProcessYieldModifier(-1);
		if (yieldMod ~= 0) then
			yield = yield + ((yield * yieldMod) / 100);
		end

		local strWrittenHelpText = Locale.ConvertTextKey("TXT_KEY_PROCESS_GENERIC_HELP", yield, "[ICON_HEALTH_1]", "TXT_KEY_HEALTH");
		if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
			strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
			strHelpText = strHelpText .. strWrittenHelpText;
		end
	else
		-- Normal YIELD process

		local yieldType : string = nil;
		local yield : number = 0;
		local baseYield : number = 0;
		for row in GameInfo.Process_ProductionYields("ProcessType = \"" .. pProcessInfo.Type .. "\"") do
			yieldType = row.YieldType;
			baseYield = row.Yield;
			break;
		end

		if (yieldType == nil) then
			return "INVALID YIELD TYPE";
		end

		local yieldInfo = GameInfo.Yields[yieldType];
		if (yieldInfo ~= nil) then

			yield = baseYield;
			local yieldMod : number = pActivePlayer:GetProcessYieldModifier(yieldInfo.ID);
			if (yieldMod ~= 0) then
				yield = ((baseYield * yieldMod) / 100);
			end

			-- Buffs?
			local extraYield : number = pActivePlayer:GetExtraProcessYieldRate(yieldInfo.ID);			
			if (extraYield ~= 0) then
				yield = yield + extraYield;
			end

			local strWrittenHelpText = Locale.ConvertTextKey("TXT_KEY_PROCESS_GENERIC_HELP", yield, yieldInfo.IconString, yieldInfo.Description);
			if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
				strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
				strHelpText = strHelpText .. strWrittenHelpText;
			end
		end
	end

	return strHelpText;
end

-- ===========================================================================

-- PLAYER PERK

-- ===========================================================================

function GetHelpTextForPlayerPerk(perkID, bExcludeName)

	CacheDatabaseQueries();

	local perkInfo = GameInfo.PlayerPerks[perkID];

	local strHelpText = "";
	local separate : boolean = false;

	-- Description
	if (not bExcludeName) then
		strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey( perkInfo.Description ));
		strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
	end

	local condition = "PlayerPerkType = '" .. perkInfo.Type .. "'";

	-- Yield from Buildings
	local playerPerkBuildingYieldEffect = CachedPlayerPerksBuildingYieldEffects[perkInfo.Type];
	if (playerPerkBuildingYieldEffect ~= nil) then
		local buildingInfo = GameInfo.BuildingClasses[playerPerkBuildingYieldEffect.BuildingClassType];
		local yield = GameInfo.Yields[playerPerkBuildingYieldEffect.YieldType];
		strHelpText = strHelpText .. Locale.Lookup( "TXT_KEY_PLAYERPERK_ALL_BUILDING_YIELD_EFFECT", playerPerkBuildingYieldEffect.FlatYield, yield.IconString, yield.Description, buildingInfo.Description);
		strHelpText = strHelpText .. "[NEWLINE";
		separate = true;
	end

	if (separate) then
		strHelpText = strHelpText .. "[NEWLINE]----------------[NEWLINE]";
		separate = false;
	end

	-- Pre-written Help text
	if perkInfo.Help ~= nil and perkInfo.Help ~= "" then
		local strWrittenHelpText = Locale.ConvertTextKey(perkInfo.Help);
		if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
			strHelpText = strHelpText .. strWrittenHelpText;
			separate = true;
		end
	end

	return strHelpText;
end

-- ===========================================================================
-- Tooltips for Yield & Similar (e.g. Culture)
-- ===========================================================================

-- FOOD
function GetFoodTooltip(pCity)
	
	local strFoodToolTip = "";
	
	strFoodToolTip = strFoodToolTip .. Locale.ConvertTextKey("TXT_KEY_FOOD_HELP_INFO");
	strFoodToolTip = strFoodToolTip .. "[NEWLINE][NEWLINE]";
	
	local fFoodProgress = pCity:GetFoodTimes100() / 100;
	local iFoodNeeded = pCity:GrowthThreshold();
	
	strFoodToolTip = strFoodToolTip .. Locale.ConvertTextKey("TXT_KEY_FOOD_PROGRESS", fFoodProgress, iFoodNeeded);
	
	strFoodToolTip = strFoodToolTip .. "[NEWLINE][NEWLINE]";
	strFoodToolTip = strFoodToolTip .. GetYieldTooltipHelper(pCity, YieldTypes.YIELD_FOOD);
	
	return strFoodToolTip;
end

-- ENERGY
function GetEnergyTooltip(pCity)
	
	local strEnergyToolTip = "";
	strEnergyToolTip = strEnergyToolTip .. Locale.ConvertTextKey("TXT_KEY_ENERGY_HELP_INFO");
	strEnergyToolTip = strEnergyToolTip .. "[NEWLINE][NEWLINE]";
	
	strEnergyToolTip = strEnergyToolTip .. GetYieldTooltipHelper(pCity, YieldTypes.YIELD_ENERGY);
	
	return strEnergyToolTip;
end

-- SCIENCE
function GetScienceTooltip(pCity)
	
	local strScienceToolTip = "";

	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
		strScienceToolTip = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_SCIENCE_OFF_TOOLTIP");
	else	
		strScienceToolTip = strScienceToolTip .. Locale.ConvertTextKey("TXT_KEY_SCIENCE_HELP_INFO");
		strScienceToolTip = strScienceToolTip .. "[NEWLINE][NEWLINE]";	
		strScienceToolTip = strScienceToolTip .. GetYieldTooltipHelper(pCity, YieldTypes.YIELD_SCIENCE);
	end
	
	return strScienceToolTip;
end

-- PRODUCTION
function GetProductionTooltip(pCity)

	local strProductionToolTip = "";

	strProductionToolTip = strProductionToolTip .. Locale.ConvertTextKey("TXT_KEY_PRODUCTION_HELP_INFO");
	strProductionToolTip = strProductionToolTip .. "[NEWLINE][NEWLINE]";
	
	strProductionToolTip = strProductionToolTip .. GetYieldTooltipHelper(pCity, YieldTypes.YIELD_PRODUCTION);
	
	return strProductionToolTip;
end

-- HEALTH
function GetHealthTooltip(pCity)

	local strHealthToolTip = "";
	local capitalConnection : boolean = pCity:IsConnectedToCapital();

	strHealthToolTip = strHealthToolTip .. Locale.ConvertTextKey("TXT_KEY_HEALTH_HELP_INFO");
	strHealthToolTip = strHealthToolTip .. "[NEWLINE][NEWLINE]";
	strHealthToolTip = strHealthToolTip .. Locale.Lookup("TXT_KEY_HEALTH_HELP_INFO_POP_CAP_WARNING") .. "[NEWLINE][NEWLINE]";
	
	-- base Health
	local iTotalLocalHealth = pCity:GetLocalHealth();

	local iHealthFromTerrain = pCity:GetHealthFromTerrain();
	local iHealthFromBuildings = pCity:GetHealthFromBuildings();
	local iHealthFromProcess = pCity:GetHealthFromProcess();
	local iHealthFromPerks = pCity:GetHealthFromPerks();
	local iBaseLocalHealth = iHealthFromTerrain + iHealthFromBuildings + iHealthFromProcess + iHealthFromPerks;
		
	local strHealthFromBuildings = Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_BUILDINGS", iHealthFromBuildings, "[ICON_HEALTH_1]");
	local strHealthFromTerrain = Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_TERRAIN", iHealthFromTerrain, "[ICON_HEALTH_1]");
	local strHealthFromProcess = "";
	if (iHealthFromProcess ~= 0) then
		local iProcessType = pCity:GetProductionProcess();
		if (iProcessType >= 0) then
			local pProcessInfo = GameInfo.Processes[iProcessType];
			strHealthFromProcess = strHealthFromProcess .. Locale.ConvertTextKey("TXT_KEY_SHORT_YIELD_FROM_SPECIFIC_OBJECT", iHealthFromProcess, "[ICON_HEALTH_1]", pProcessInfo.Description);
		end
	end
	local strHealthFromPerks = "";
	if (iHealthFromPerks ~= 0) then
		strHealthFromPerks = strHealthFromPerks .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_MISC", iHealthFromPerks, "[ICON_HEALTH_1]");
	end
	local strBaseHealth = Locale.ConvertTextKey("TXT_KEY_YIELD_BASE", iBaseLocalHealth, "[ICON_HEALTH_1]");

	strHealthToolTip = strHealthToolTip .. "[ICON_BULLET]" .. strHealthFromBuildings .. "[NEWLINE]";
	strHealthToolTip = strHealthToolTip .. "[ICON_BULLET]" .. strHealthFromTerrain .. "[NEWLINE]";
	if (strHealthFromProcess ~= "") then
		strHealthToolTip = strHealthToolTip .. "[ICON_BULLET]" .. strHealthFromProcess .. "[NEWLINE]";
	end
	if (strHealthFromPerks ~= "") then
		strHealthToolTip = strHealthToolTip .. "[ICON_BULLET]" .. strHealthFromPerks .. "[NEWLINE]";
	end
	strHealthToolTip = strHealthToolTip .. strBaseHealth .. "[NEWLINE]";

	strHealthToolTip = strHealthToolTip .. "----------------[NEWLINE]";

	-- health Modifier
	local iHealthModifier = pCity:GetTotalHealthModifier() - 100;
	if (iHealthModifier > 0) then
		local strHealthBuildingMod = Locale.ConvertTextKey("TXT_KEY_HEALTH_BUILDING_MOD_INFO", iHealthModifier);
		strHealthToolTip = strHealthToolTip .. "[ICON_BULLET]" .. strHealthBuildingMod .. "[NEWLINE]";
		strHealthToolTip = strHealthToolTip .. "----------------[NEWLINE]";
	end

	-- total Health
	local posNegIcon = "[ICON_HEALTH_1]";
	if (iTotalLocalHealth < 0) then
		posNegIcon = "[ICON_HEALTH_3]";
	end
		
	local strTotalLocalHealth = Locale.ConvertTextKey("TXT_KEY_YIELD_TOTAL", iTotalLocalHealth, posNegIcon);
	strHealthToolTip = strHealthToolTip .. strTotalLocalHealth;

	local iPopulation = pCity:GetPopulation();
	-- if local health is positive and our output is higher than the city's population, include the cap reminder
	if (iBaseLocalHealth > iPopulation) then		
		local strPopCap : string = Locale.ConvertTextKey("TXT_KEY_HEALTH_POP_CAPPED", iPopulation);
		strHealthToolTip = strHealthToolTip .. " " .. strPopCap;
	end

	return strHealthToolTip;
end

-- CULTURE
function GetCultureTooltip(pCity)
	local s = "";

	-- Basic info
	local showBreakdown = true;
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)) then
		s = s .. Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_POLICIES_OFF_TOOLTIP");
		showBreakdown = false;
	else
		s = s .. Locale.Lookup("TXT_KEY_CULTURE_HELP_INFO");
		if (pCity:IsWater() == false) then
			s = s .. Locale.Lookup("TXT_KEY_CULTURE_HELP_INFO_LAND_CITY");
		end
	end

	local iCulturePerTurn : number = pCity:GetCulturePerTurn();

	-- Tile growth
	if (pCity:AllowsCultureBorderGrowth()) then
		
		local iCultureStored = pCity:GetCultureStored();
		local iCultureNeeded = pCity:GetCultureThreshold();
		s = s .. "[NEWLINE][NEWLINE]";
		s = s .. Locale.ConvertTextKey("TXT_KEY_CULTURE_INFO", iCultureStored, iCultureNeeded);
		if iCulturePerTurn > 0 then
			local iCultureDiff = iCultureNeeded - iCultureStored;
			local iCultureTurns = math.ceil(iCultureDiff / iCulturePerTurn);
			s = s .. " " .. Locale.ConvertTextKey("TXT_KEY_CULTURE_TURNS", iCultureTurns);
		end
	end

	-- Sources
	if (showBreakdown) then
		-- Base yield amount --
		local sBaseYieldBreakdown = "";
		local bFirst = true;
		local iCultureAccountedFor = 0;
		
		-- from Buildings
		local iCultureFromBuildings = pCity:GetCulturePerTurnFromBuildings();
		if (iCultureFromBuildings ~= 0) then
			iCultureAccountedFor = iCultureAccountedFor + iCultureFromBuildings;
			if (bFirst) then
				bFirst = false;
			else
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
			end
			
			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_FROM_BUILDINGS", iCultureFromBuildings);
		end
		
		-- from Policies
		local iCultureFromPolicies = pCity:GetCulturePerTurnFromPolicies();
		if (iCultureFromPolicies ~= 0) then
			iCultureAccountedFor = iCultureAccountedFor + iCultureFromPolicies;
			if (bFirst) then
				bFirst = false;
			else
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
			end
			
			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_FROM_POLICIES", iCultureFromPolicies);
		end
		
		-- from Specialists
		local iCultureFromSpecialists = pCity:GetCulturePerTurnFromSpecialists();
		if (iCultureFromSpecialists ~= 0) then
			iCultureAccountedFor = iCultureAccountedFor + iCultureFromSpecialists;
			if (bFirst) then
				bFirst = false;
			else
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
			end
			
			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_FROM_SPECIALISTS", iCultureFromSpecialists);
		end
		
		-- from Terrain
		local iCultureFromTerrain = pCity:GetBaseYieldRateFromTerrain(YieldTypes.YIELD_CULTURE);
		if (iCultureFromTerrain ~= 0) then
			iCultureAccountedFor = iCultureAccountedFor + iCultureFromTerrain;
			if (bFirst) then
				bFirst = false;
			else
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
			end
			
			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_FROM_TERRAIN", iCultureFromTerrain);
		end

		-- from Traits
		local iCultureFromTraits = pCity:GetCulturePerTurnFromTraits();
		if (iCultureFromTraits ~= 0) then
			iCultureAccountedFor = iCultureAccountedFor + iCultureFromTraits;
			if (bFirst) then
				bFirst = false;
			else
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
			end
			
			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_FROM_TRAITS", iCultureFromTraits);
		end

		-- from Production Processes
		local iCultureFromProcesses = pCity:GetYieldRateFromProductionProcesses(YieldTypes.YIELD_CULTURE);
		if (iCultureFromProcesses ~= 0) then
			iCultureAccountedFor = iCultureAccountedFor + iCultureFromProcesses;
			local iProcessType = pCity:GetProductionProcess();
			if (iProcessType >= 0) then
				local pProcessInfo = GameInfo.Processes[iProcessType];
				if (bFirst) then
					bFirst = false;
				else
					sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
				end			
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_SHORT_YIELD_FROM_SPECIFIC_OBJECT", iCultureFromProcesses, "[ICON_CULTURE]", pProcessInfo.Description);
			end
		end

		-- from Misc
		local iYieldBase = pCity:GetBaseCulturePerTurn(iYieldType);
		local iYieldFromMisc = iYieldBase - iCultureAccountedFor;
		if (iYieldFromMisc ~= 0) then
			if (bFirst) then
				bFirst = false;
			else
				sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE]";
			end

			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_MISC", iYieldFromMisc, "[ICON_CULTURE]");
		end

		-- Yield modifiers --
		local sYieldModifierBreakdown = "";
		
		-- from miscellaneous City stuff
		-- This actually includes a lot of component parts that our system does not handle well like other yields.
		-- So here we will subtract out component parts we want to call out with custom text.
		-- Once we have more QA time to verify accuracy, this should be changed to work the same as other yields.

		local totalMiscMod = pCity:GetBaseYieldRateModifier(YieldTypes.YIELD_CULTURE) - 100;
		local healthMod = pCity:GetHealthYieldRateModifier(YieldTypes.YIELD_CULTURE);
		local warMod : number = pCity:GetYieldRateWarModifier(YieldTypes.YIELD_CULTURE);
		
		totalMiscMod = totalMiscMod - healthMod - warMod;
		
		if (healthMod ~= 0) then
			if (healthMod > 0) then
				sYieldModifierBreakdown = sYieldModifierBreakdown .. Locale.ConvertTextKey("TXT_KEY_PRODMOD_YIELD_HEALTH", healthMod);
			else
				sYieldModifierBreakdown = sYieldModifierBreakdown .. Locale.ConvertTextKey("TXT_KEY_PRODMOD_YIELD_UNHEALTH", healthMod);
			end
		end

		if (warMod ~= 0) then
			sYieldModifierBreakdown = sYieldModifierBreakdown .. Locale.ConvertTextKey("TXT_KEY_PRODMOD_YIELD_WAR", warMod);
		end
		
		if (totalMiscMod ~= 0) then
			sYieldModifierBreakdown = sYieldModifierBreakdown .. Locale.ConvertTextKey("TXT_KEY_PRODMOD_YIELD_PLAYER", totalMiscMod);
		end
		
		-- From being at War

		-- from Wonder multplier
		if (pCity:GetNumWorldWonders() > 0) then
			local iAmount = Players[pCity:GetOwner()]:GetCultureWonderMultiplier();
			if (iAmount ~= 0) then
				sYieldModifierBreakdown = sYieldModifierBreakdown .. "[NEWLINE][ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_WONDER_BONUS", iAmount);
			end
		end
		
		-- from Puppet status
		if (pCity:IsPuppet()) then
			local iAmount = GameDefines.PUPPET_CULTURE_MODIFIER;
			if (iAmount ~= 0) then
				sYieldModifierBreakdown = sYieldModifierBreakdown .. Locale.ConvertTextKey("TXT_KEY_PRODMOD_PUPPET", iAmount);
			end
		end

		-- Aquatic City bonus
		if (pCity:IsWater()) then
			sYieldModifierBreakdown = sYieldModifierBreakdown .. "[NEWLINE][ICON_BULLET]" .. Locale.Lookup("TXT_KEY_WATER_CITY_CULTURE_BONUS");
		end

		-- from Trade
		local iCultureFromTrade = pCity:GetYieldPerTurnFromTrade(YieldTypes.YIELD_CULTURE);
		if (iCultureFromTrade ~= 0) then
			sBaseYieldBreakdown = sBaseYieldBreakdown .. "[NEWLINE][ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_FROM_TRADE", iCultureFromTrade);
		end

		-- Construct the text --
		s = s .. "[NEWLINE][NEWLINE]";
		s = s .. sBaseYieldBreakdown .. "[NEWLINE]----------------";
		if (iYieldBase ~= iCulturePerTurn or sYieldModifierBreakdown ~= "") then
			s = s .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_BASE", iYieldBase, "[ICON_CULTURE]");
		end
		if (sYieldModifierBreakdown ~= "") then
			s = s .. "[NEWLINE]----------------" .. sYieldModifierBreakdown .. "[NEWLINE]----------------";
		end
		if (iCulturePerTurn >= 0) then
			s = s .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_TOTAL", iCulturePerTurn, "[ICON_CULTURE]");
		else
			s = s .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_TOTAL_NEGATIVE", iCulturePerTurn, "[ICON_CULTURE]");
		end
	end
	
	return s;
end


------------------------------
-- Yield Tooltip Helper
------------------------------
function GetYieldTooltipHelper(pCity, iYieldType)
	
	local strModifiers = "";
	
	-- Base Yield
	local iBaseYield = pCity:GetBaseYieldRate(iYieldType);

	local iYieldPerPop = pCity:GetYieldPerPopTimes100(iYieldType);
	if (iYieldPerPop ~= 0) then
		iYieldPerPop = iYieldPerPop * pCity:GetPopulation();
		iYieldPerPop = iYieldPerPop / 100;
		
		iBaseYield = iBaseYield + iYieldPerPop;
	end

	-- Total Yield
	local iTotalYield;
	
	-- Special cases
	if (iYieldType == YieldTypes.YIELD_FOOD) then
		iTotalYield = pCity:FoodDifferenceTimes100() / 100;
	elseif (iYieldType == YieldTypes.YIELD_PRODUCTION) then
		local ignoreFoodProduction = false;
		local includeOverflow = false;
		iTotalYield = pCity:GetCurrentProductionDifferenceTimes100(ignoreFoodProduction, includeOverflow) / 100;
	else
		iTotalYield = pCity:GetYieldRateTimes100(iYieldType) / 100;
	end
	
	-- Yield modifiers string
	strModifiers = strModifiers .. pCity:GetYieldModifierTooltip(iYieldType);
	
	-- Build tooltip
	local strYieldToolTip = GetYieldTooltip(pCity, iYieldType, iBaseYield, iTotalYield, strModifiers);
	
	return strYieldToolTip;

end


------------------------------
-- Helper function to build yield tooltip string
function GetYieldTooltip(pCity, iYieldType, iBase, iTotal, strModifiersString)
	
	local pYield = GameInfo.Yields[iYieldType];
	local strYieldBreakdown = "";
	
	-- Yield from terrain
	local iYieldFromTerrain = pCity:GetBaseYieldRateFromTerrain(iYieldType);
	if (iYieldFromTerrain ~= 0) then
		strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_TERRAIN", iYieldFromTerrain, pYield.IconString);
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end
	
	-- Total Yield from Buildings (including quest reward and player perk effects)
	local iYieldFromBuildings = pCity:GetTotalYieldRateFromBuildings(iYieldType);
	if (iYieldFromBuildings ~= 0) then
		strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_BUILDINGS", iYieldFromBuildings, pYield.IconString);
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end
	
	-- Yield from Specialists
	local iYieldFromSpecialists = pCity:GetBaseYieldRateFromSpecialists(iYieldType);
	if (iYieldFromSpecialists ~= 0) then
		strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_SPECIALISTS", iYieldFromSpecialists, pYield.IconString);
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end
	
	-- Yield from Production Processes
	local iYieldFromProcesses = pCity:GetYieldRateFromProductionProcesses(iYieldType);
	if (iYieldFromProcesses ~= 0) then
		local iProcessType = pCity:GetProductionProcess();
		if (iProcessType >= 0) then
			local pProcessInfo = GameInfo.Processes[iProcessType];
			strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_SHORT_YIELD_FROM_SPECIFIC_OBJECT", iYieldFromProcesses, pYield.IconString, pProcessInfo.Description);
			strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
		end
	end

	-- Yield from Primordial Marvel Effect
	if(iYieldType == YieldTypes.YIELD_PRODUCTION) then
		local primordialEffectTurnsRemaining : number = Players[pCity:GetOwner()]:GetPrimordialEffectTurnsRemaining();
		if(primordialEffectTurnsRemaining == nil) then
			error("primordialEffectTurnsRemaining was nil.");
		end

		if(primordialEffectTurnsRemaining > 0) then
			local primordialEffectProductionMod : number = Players[pCity:GetOwner()]:GetPrimordialEffectProductionMod();
			local primordialEffectProductionYield : number = iBase * (primordialEffectProductionMod / 100);

			strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_PLAYERPERK_MARVEL_PRIMORDIAL_TOOLTIP", primordialEffectProductionYield, primordialEffectTurnsRemaining);
			strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
		end
	end

	-- Base Yield from Misc
	local iYieldFromMisc = pCity:GetBaseYieldRateFromMisc(iYieldType);
	if (iYieldFromMisc ~= 0) then
		if (iYieldType == YieldTypes.YIELD_SCIENCE) then
			strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_POP", iYieldFromMisc, pYield.IconString);
		else
			strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_MISC", iYieldFromMisc, pYield.IconString);
		end
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end
	
	-- Base Yield from Pop
	local iYieldPerPop = pCity:GetYieldPerPopTimes100(iYieldType);
	if (iYieldPerPop ~= 0) then
		local iYieldFromPop = iYieldPerPop * pCity:GetPopulation();
		iYieldFromPop = iYieldFromPop / 100;
		
		strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_POP_EXTRA", iYieldFromPop, pYield.IconString);
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end
	
	-- Base Yield from Loadout (colonists)
	local iYieldFromLoadout = pCity:GetYieldPerTurnFromLoadout(iYieldType);
	if (iYieldFromLoadout ~= 0) then
		strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_LOADOUT", iYieldFromLoadout, pYield.IconString);
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end
	
	-- Base Yield from Religion
	local iYieldFromReligion = pCity:GetBaseYieldRateFromReligion(iYieldType);
	if (iYieldFromReligion ~= 0) then
		strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_RELIGION", iYieldFromReligion, pYield.IconString);
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
	end

	-- Extra Yield from Trade
	-- Food: counted as Base Yield (since our citizens will eat it and we may need it to not starve)
	-- Everything else: counted after the fact, so that modifiers don't apply to it (too powerful)
	local iYieldFromTrade = pCity:GetYieldPerTurnFromTrade(iYieldType);
	if (iYieldFromTrade ~= 0) then
		if (iYieldType == YieldTypes.YIELD_FOOD) then
			strYieldBreakdown = strYieldBreakdown .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_TRADE", iYieldFromTrade, pYield.IconString);
			strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]";
		else
			strModifiersString = strModifiersString .. "[NEWLINE][ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_FROM_TRADE", iYieldFromTrade, pYield.IconString);
		end
	end
		
	local strExtraBaseString = "";
	
	-- Food eaten by pop
	local iYieldEaten = 0;
	if (iYieldType == YieldTypes.YIELD_FOOD) then
		iYieldEaten = pCity:FoodConsumption(true, 0);
		if (iYieldEaten ~= 0) then
			--strModifiers = strModifiers .. "[NEWLINE]";
			--strModifiers = strModifiers .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_YIELD_EATEN_BY_POP", iYieldEaten, "[ICON_FOOD]");
			--strModifiers = strModifiers .. "[NEWLINE]----------------[NEWLINE]";			
			strExtraBaseString = strExtraBaseString .. "   " .. Locale.ConvertTextKey("TXT_KEY_FOOD_USAGE", pCity:GetYieldRate(YieldTypes.YIELD_FOOD, false), iYieldEaten);
			
			local iFoodSurplus = pCity:GetYieldRate(YieldTypes.YIELD_FOOD, false) - iYieldEaten;
			iBase = iFoodSurplus;
			
			--if (iFoodSurplus >= 0) then
				--strModifiers = strModifiers .. Locale.ConvertTextKey("TXT_KEY_YIELD_AFTER_EATEN", iFoodSurplus, "[ICON_FOOD]");
			--else
				--strModifiers = strModifiers .. Locale.ConvertTextKey("TXT_KEY_YIELD_AFTER_EATEN_NEGATIVE", iFoodSurplus, "[ICON_FOOD]");
			--end
		end
	end

	-- Extra Production from Food (ie. producing Colonists)
	if (iYieldType == YieldTypes.YIELD_PRODUCTION) then
		if (pCity:IsFoodProduction()) then
			local productionFromFood = pCity:GetFoodProduction();
			if (productionFromFood > 0) then
				strModifiersString = strModifiersString .. Locale.ConvertTextKey("TXT_KEY_PRODMOD_FOOD_CONVERSION", productionFromFood);
			end
		end
	end
	
	local strTotal;
	if (iTotal >= 0) then
		strTotal = Locale.ConvertTextKey("TXT_KEY_YIELD_TOTAL", iTotal, pYield.IconString);
	else
		strTotal = Locale.ConvertTextKey("TXT_KEY_YIELD_TOTAL_NEGATIVE", iTotal, pYield.IconString);
	end
	
	strYieldBreakdown = strYieldBreakdown .. "----------------";
	
	-- Build combined string
	if (iBase ~= iTotal or strExtraBaseString ~= "") then
		local strBase = Locale.ConvertTextKey("TXT_KEY_YIELD_BASE", iBase, pYield.IconString) .. strExtraBaseString;
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]" .. strBase;
	end
	
	-- Modifiers
	if (strModifiersString ~= "") then
		strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]----------------" .. strModifiersString .. "[NEWLINE]----------------";
	end
	strYieldBreakdown = strYieldBreakdown .. "[NEWLINE]" .. strTotal;
	
	return strYieldBreakdown;

end


----------------------------------------------------------------        
-- MOOD INFO
----------------------------------------------------------------        
function GetMoodInfo(iOtherPlayer)
	
	local strInfo = "";
	
	-- Always war!
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_ALWAYS_WAR)) then
		return "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_ALWAYS_WAR_TT");
	end
	
	local iActivePlayer = Game.GetActivePlayer();
	local pActivePlayer = Players[iActivePlayer];
	local pActiveTeam = Teams[pActivePlayer:GetTeam()];
	local pOtherPlayer = Players[iOtherPlayer];
	local iOtherTeam = pOtherPlayer:GetTeam();
	local pOtherTeam = Teams[iOtherTeam];
	
	local aOpinion = pOtherPlayer:GetOpinionTable(iActivePlayer);
	--local aOpinionList = {};
	for i,v in ipairs(aOpinion) do
		--aOpinionList[i] = "[ICON_BULLET]" .. v .. "[NEWLINE]";
		strInfo = strInfo .. "[ICON_BULLET]" .. v .. "[NEWLINE]";
	end
	--strInfo = table.cat(aOpinionList, "[NEWLINE]");

	--  No specific events - let's see what string we should use
	if (strInfo == "") then
		
		-- Appears Friendly
		if (iVisibleApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_FRIENDLY) then
			strInfo = strInfo .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_DIPLO_FRIENDLY");
		-- Appears Guarded
		elseif (iVisibleApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_GUARDED) then
			strInfo = strInfo .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_DIPLO_GUARDED");
		-- Appears Hostile
		elseif (iVisibleApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_HOSTILE) then
			strInfo = strInfo .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_DIPLO_HOSTILE");
		-- Neutral - default string
		else
			strInfo = "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_DIPLO_DEFAULT_STATUS");
		end
	end
	
	-- Remove extra newline off the end if we have one
	if (Locale.EndsWith(strInfo, "[NEWLINE]")) then
		local iNewLength = Locale.Length(strInfo)-9;
		strInfo = Locale.Substring(strInfo, 1, iNewLength);
	end
	
	return strInfo;
	
end

------------------------------
-- Helper function to build religion tooltip string
function GetSpecialistSlotsTooltip ( specialistType, numSlots )
	local specialistStr = "UNDEF";
	local specialistInfo = GameInfo.Specialists[specialistType];
	for row in GameInfo.SpecialistYields{SpecialistType = specialistType} do
		local yieldInfo = GameInfo.Yields[row.YieldType];
		specialistStr = Locale.ConvertTextKey("TXT_KEY_BUILDING_SPECIALIST_SLOTS", numSlots, yieldInfo.IconString, specialistInfo.Description);
	end

	return specialistStr;
end

------------------------------
-- Helper function to build religion tooltip string
function GetReligionTooltip(city)

	local religionToolTip = "";
	
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
		return religionToolTip;
	end

	local bFoundAFollower = false;
	local eReligion = city:GetReligiousMajority();
	local bFirst = true;
	
	if (eReligion >= 0) then
		bFoundAFollower = true;
		local religion = GameInfo.Religions[eReligion];
		local strReligion = Locale.ConvertTextKey(Game.GetReligionName(eReligion));
		local strIcon = religion.IconString;
		local strPressure = "";
			
		if (city:IsHolyCityForReligion(eReligion)) then
			if (not bFirst) then
				religionToolTip = religionToolTip .. "[NEWLINE]";
			else
				bFirst = false;
			end
			religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_HOLY_CITY_TOOLTIP_LINE", strIcon, strReligion);			
		end

		local iPressure;
		local iNumTradeRoutesAddingPressure;
		iPressure, iNumTradeRoutesAddingPressure = city:GetPressurePerTurn(eReligion);
		if (iPressure > 0) then
			strPressure = Locale.ConvertTextKey("TXT_KEY_RELIGIOUS_PRESSURE_STRING", iPressure);
		end
		
		local iFollowers = city:GetNumFollowers(eReligion)			
		if (not bFirst) then
			religionToolTip = religionToolTip .. "[NEWLINE]";
		else
			bFirst = false;
		end
		
		--local iNumTradeRoutesAddingPressure = city:GetNumTradeRoutesAddingPressure(eReligion);
		if (iNumTradeRoutesAddingPressure > 0) then
			religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_RELIGION_TOOLTIP_LINE_WITH_TRADE", strIcon, iFollowers, strPressure, iNumTradeRoutesAddingPressure);
		else
			religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_RELIGION_TOOLTIP_LINE", strIcon, iFollowers, strPressure);
		end
	end	
		
	local iReligionID;
	for pReligion in GameInfo.Religions() do
		iReligionID = pReligion.ID;
		
		if (iReligionID >= 0 and iReligionID ~= eReligion and city:GetNumFollowers(iReligionID) > 0) then
			bFoundAFollower = true;
			local religion = GameInfo.Religions[iReligionID];
			local strReligion = Locale.ConvertTextKey(Game.GetReligionName(iReligionID));
			local strIcon = religion.IconString;
			local strPressure = "";

			if (city:IsHolyCityForReligion(iReligionID)) then
				if (not bFirst) then
					religionToolTip = religionToolTip .. "[NEWLINE]";
				else
					bFirst = false;
				end
				religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_HOLY_CITY_TOOLTIP_LINE", strIcon, strReligion);			
			end
				
			local iPressure = city:GetPressurePerTurn(iReligionID);
			if (iPressure > 0) then
				strPressure = Locale.ConvertTextKey("TXT_KEY_RELIGIOUS_PRESSURE_STRING", iPressure);
			end
			
			local iFollowers = city:GetNumFollowers(iReligionID)			
			if (not bFirst) then
				religionToolTip = religionToolTip .. "[NEWLINE]";
			else
				bFirst = false;
			end
			
			local iNumTradeRoutesAddingPressure = city:GetNumTradeRoutesAddingPressure(iReligionID);
			if (iNumTradeRoutesAddingPressure > 0) then
				religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_RELIGION_TOOLTIP_LINE_WITH_TRADE", strIcon, iFollowers, strPressure, iNumTradeRoutesAddingPressure);
			else
				religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_RELIGION_TOOLTIP_LINE", strIcon, iFollowers, strPressure);
			end
		end
	end
	
	if (not bFoundAFollower) then
		religionToolTip = religionToolTip .. Locale.ConvertTextKey("TXT_KEY_RELIGION_NO_FOLLOWERS");
	end
		
	return religionToolTip;
end

----------------------------------------------------------------
----------------------------------------------------------------
-- UNIT COMBO THINGS
----------------------------------------------------------------
----------------------------------------------------------------
function GetHelpTextForSpecificUnit(unit)
	local s = "";
	
	-- Attributes
	s = s .. GetHelpTextForUnitAttributes(unit:GetUnitType(), "[ICON_BULLET]");

	-- Player Perks
	local temp = GetHelpTextForUnitPlayerPerkBuffs(unit:GetUnitType(), unit:GetOwner(), "[ICON_BULLET]");
	if (temp ~= "") then
		if (s ~= "") then
			s = s .. "[NEWLINE]";
		end
		s = s .. temp;
	end

	-- Promotions
	temp = GetHelpTextForUnitPromotions(unit, "[ICON_BULLET]");
	if (temp ~= "") then
		if (s ~= "") then
			s = s .. "[NEWLINE]";
		end
		s = s .. temp;
	end
	
	-- Upgrades and Perks
	local player = Players[unit:GetOwner()];
	if (player ~= nil) then
		local allPerks = player:GetPerksForUnit(unit:GetUnitType());
		local tempPerks = player:GetFreePerksForUnit(unit:GetUnitType());
		for i,v in ipairs(tempPerks) do
			table.insert(allPerks, v);
		end
		local ignoreCoreStats = true;
		temp = GetHelpTextForUnitPerks(allPerks, ignoreCoreStats, "[ICON_BULLET]");
		if (temp ~= "") then
			if (s ~= "") then
				s = s .. "[NEWLINE]";
			end
			s = s .. temp;
		end
	end

	return s;
end

function GetHelpTextForUnitType(unitType, playerID, includeFreePromotions)
	local s = "";

	-- Attributes
	s = s .. GetHelpTextForUnitAttributes(unitType, nil);

	-- Player Perks
	if (includeFreePromotions ~= nil and includeFreePromotions == true) then
		local temp = GetHelpTextForUnitPlayerPerkBuffs(unitType, playerID, nil);
		if (temp ~= "") then
			if (s ~= "") then
				s = s .. "[NEWLINE]";
			end
			s = s .. temp;
		end
	end

	-- Promotions
	if (includeFreePromotions ~= nil and includeFreePromotions == true) then
		local temp = GetHelpTextForUnitInherentPromotions(unitType, nil);
		if (temp ~= "") then
			if (s ~= "") then
				s = s .. "[NEWLINE]";
			end
			s = s .. temp;
		end
	end

	-- Upgrades and Perks
	local player = Players[playerID];
	if (player ~= nil) then
		local allPerks = player:GetPerksForUnit(unitType);
		local tempPerks = player:GetFreePerksForUnit(unitType);
		for i,v in ipairs(tempPerks) do
			table.insert(allPerks, v);
		end
		local ignoreCoreStats = true;
		local temp = GetHelpTextForUnitPerks(allPerks, ignoreCoreStats, nil);
		if (temp ~= "") then
			if (s ~= "") then
				s = s .. "[NEWLINE]";
			end
			s = s .. temp;
		end
	end

	return s;
end

----------------------------------------------------------------
----------------------------------------------------------------
-- UNIT MISCELLANY
-- Stuff not covered by promotions or perks
----------------------------------------------------------------
----------------------------------------------------------------
function GetUpgradedUnitDescriptionKey(player, unitType)
	local descriptionKey = "";
	local unitInfo = GameInfo.Units[unitType];
	if (unitInfo ~= nil) then
		descriptionKey = unitInfo.Description;
		if (player ~= nil) then
			local bestUpgrade = player:GetBestUnitUpgrade(unitType);
			if (bestUpgrade ~= -1) then
				local bestUpgradeInfo = GameInfo.UnitUpgrades[bestUpgrade];
				if (bestUpgradeInfo ~= nil) then
					descriptionKey = bestUpgradeInfo.Description;
				end
			end
		end
	end
	return descriptionKey;
end

--TODO: antonjs: Once we have a text budget and refactor time,
--roll these miscellaneous things (player perks, attributes in
--the base unit XML) in with existing unit buff systems 
--instead of being special case like this.
function GetHelpTextForUnitAttributes(unitType, prefix)
	local s = "";
	local unitInfo = GameInfo.Units[unitType];
	if (unitInfo ~= nil) then
		if (unitInfo.OrbitalAttackRange >= 0) then
			if (s ~= "") then
				s = s .. "[NEWLINE]";
			end
			if (prefix ~= nil) then
				s = s .. prefix;
			end
			s = s .. Locale.ConvertTextKey("TXT_KEY_INTERFACEMODE_ORBITAL_ATTACK");
		end
	end
	return s;
end

function GetHelpTextForUnitPlayerPerkBuffs(unitType, playerID, prefix)
	CacheDatabaseQueries();

	local s = "";
	local player = Players[playerID];
	local unitInfo = GameInfo.Units[unitType];
	if (player ~= nil and unitInfo ~= nil) then
		for i,info in ipairs(CachedPlayerPerksArray) do
			if (player:HasPerk(info.ID)) then
				if (info.MiasmaBaseHeal > 0 or info.UnitPercentHealChange > 0) then
					if (s ~= "") then
						s = s .. "[NEWLINE]";
					end
					if (prefix ~= nil) then
						s = s .. prefix;
					end
					s = s .. Locale.ConvertTextKey(GameInfo.PlayerPerks[info.ID].Help);
				end

				-- Help text for this player perk is inaccurate. Commencing hax0rs.
				if (info.UnitFlatVisibilityChange > 0) then
					if (s ~= "") then
						s = s .. "[NEWLINE]";
					end
					if (prefix ~= nil) then
						s = s .. prefix;
					end
					s = s .. Locale.ConvertTextKey("TXT_KEY_UNITPERK_VISIBILITY_CHANGE", info.UnitFlatVisibilityChange);
				end
			end
		end
	end
	return s;
end

----------------------------------------------------------------
----------------------------------------------------------------
-- UNIT PROMOTIONS
----------------------------------------------------------------
----------------------------------------------------------------
function GetHelpTextForUnitInherentPromotions(unitType, prefix)
	CacheDatabaseQueries();

	local s = "";
	local unitInfo = GameInfo.Units[unitType];
	if (unitInfo ~= nil) then
		for pairIndex, pairInfo in ipairs(CachedUnitFreePromotionsInfoArray) do
			if (pairInfo.UnitType == unitInfo.Type) then
				local promotionInfo = GameInfo.UnitPromotions[pairInfo.PromotionType];
				if (promotionInfo ~= nil and promotionInfo.Help ~= nil) then
					if (s ~= "") then
						s = s .. "[NEWLINE]";
					end
					if (prefix ~= nil) then
						s = s .. prefix;
					end
					s = s .. Locale.ConvertTextKey(promotionInfo.Help);
				end
			end
		end
	end
	return s;
end

function GetHelpTextForUnitPromotions(unit, prefix)
	CacheDatabaseQueries();

	local s = "";
	for promotionIndex, promotionInfo in ipairs(CachedUnitPromotionInfoArray) do
		if (unit:IsHasPromotion(promotionInfo.ID)) then
			if (promotionInfo ~= nil and promotionInfo.Help ~= nil) then
				if (s ~= "") then
					s = s .. "[NEWLINE]";
				end
				if (prefix ~= nil) then
					s = s .. prefix;
				end
				s = s .. Locale.ConvertTextKey(promotionInfo.Help);
			end
		end
	end
	return s;
end

----------------------------------------------------------------
----------------------------------------------------------------
-- UNIT PERKS
----------------------------------------------------------------
----------------------------------------------------------------
function GetHelpTextForUnitPerk(perkID)
	local ignoreCoreStats = false;
	return GetHelpTextForUnitPerks( GetHelpListForUnitPerk(perkID), ignoreCoreStats, nil );
end

function GetHelpListForUnitPerk(perkID)
	local list = {};
	table.insert(list, perkID);
	return list;
end

function GetHelpTextForUnitPerks(perkIDTable, ignoreCoreStats, prefix)
	local s = "";

	-- Text key overrides
	local filteredPerkIDTable = {};
	for index, perkID in ipairs(perkIDTable) do
		local perkInfo = GameInfo.UnitPerks[perkID];
		if (perkInfo ~= nil) then
			if (perkInfo.Help ~= nil) then
				if (s ~= "") then
					s = s .. "[NEWLINE]";
				end
				if (prefix ~= nil) then
					s = s .. prefix;
				end
				s = s .. Locale.ConvertTextKey(perkInfo.Help);
			else
				table.insert(filteredPerkIDTable, perkID);
			end
		end
	end

	-- Basic Attributes
	if (not ignoreCoreStats) then
		s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_EXTRA_COMBAT_STRENGTH", "ExtraCombatStrength", s == "", prefix);
		s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_EXTRA_RANGED_COMBAT_STRENGTH", "ExtraRangedCombatStrength", s == "", prefix);
	end
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGE_CHANGE", "RangeChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGE_AT_FULL_HEALTH_CHANGE", "RangeAtFullHealthChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGE_AT_FULL_MOVES_CHANGE", "RangeAtFullMovesChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGE_FOR_ONBOARD_CHANGE", "RangeForOnboardChange", s == "", prefix);
	if (not ignoreCoreStats) then
		s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_MOVES_CHANGE", "MovesChange", s == "", prefix);
	end
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_VISIBILITY_CHANGE", "VisibilityChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_CARGO_CHANGE", "CargoChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGE_AGAINST_ORBITAL_CHANGE", "RangeAgainstOrbitalChange", s == "", prefix);
	-- General combat
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_MOD", "AttackMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_FORTIFIED_MOD", "AttackFortifiedMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_UNFORTIFIED_MOD", "AttackUnfortifiedMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_WOUNDED_MOD", "AttackWoundedMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_WHILE_IN_MIASMA_MOD", "AttackWhileInMiasmaMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_IN_ORBITAL_COVERAGE_MOD", "AttackWhileInOrbitalCoverageMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_CITY_MOD", "AttackCityMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_FROM_INVISIBLE_MOD", "AttackFromInvisibleMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_FOR_ONBOARD_MOD", "AttackForOnboardMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DEFEND_MOD", "DefendMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DEFEND_RANGED_MOD", "DefendRangedMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DEFEND_WHILE_IN_MIASMA_MOD", "DefendWhileInMiasmaMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DEFEND_IN_ORBITAL_COVERAGE_MOD", "DefendWhileInOrbitalCoverageMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DEFEND_FOR_ONBOARD_MOD", "DefendForOnboardMod", s == "", prefix);
	-- Air combat
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_WITH_AIR_SWEEP_MOD", "AttackWithAirSweepMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ATTACK_WITH_INTERCEPTION_MOD", "AttackWithInterceptionMod", s == "", prefix);
	-- Territory
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_FRIENDLY_LANDS_MOD", "FriendlyLandsMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_OUTSIDE_FRIENDLY_LANDS_MOD", "OutsideFriendlyLandsMod", s == "", prefix);
	-- Battlefield position
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ADJACENT_FRIENDLY_MOD", "AdjacentFriendlyMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_PER_ADJACENT_FRIENDLY_MOD", "PerAdjacentFriendlyMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_NO_ADJACENT_FRIENDLY_MOD", "NoAdjacentFriendlyMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_FLANKING_MOD", "FlankingMod", s == "", prefix);
	-- Other conditional bonuses
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ALIEN_COMBAT_MOD", "AlienCombatMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_FORTIFIED_MOD", "FortifiedMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_CITY_MOD", "CityMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_PER_UNUSED_MOVE_MOD", "PerUnusedMoveMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DAMAGE_TO_ADJACENT_UNITS_ON_DEATH", "DamageToAdjacentUnitsOnDeath", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DAMAGE_TO_ADJACENT_UNITS_ON_ATTACK", "DamageToAdjacentUnitsOnAttack", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_SEE_INVISIBLE_RANGE_CHANGE", "SeeInvisibleRangeChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_PASSIVE_ABILITY_AOE_DAMAGE_CHANGE", "PassiveAbilityAOEDamageChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_SUPPORT_MISSION_STRENGTH_MOD", "SupportMissionStrengthMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_SUPPORT_MISSION_DAMAGE_CHANGE", "SupportMissionDamageChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_SUPPORT_MISSION_HEAL_CHANGE", "SupportMissionHealChange", s == "", prefix);
	-- Attack logistics
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_IGNORE_RANGED_ATTACK_LINE_OF_SIGHT", "IgnoreRangedAttackLineOfSight", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_MELEE_ATTACK_HEAVY_CHARGE", "MeleeAttackHeavyCharge", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_EXTRA_ATTACKS", "ExtraAttacks", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_EXTRA_INTERCEPTIONS", "ExtraInterceptions", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGED_ATTACK_SETUPS_NEEDED_MOD", "RangedAttackSetupsNeededMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_RANGED_ATTACK_SCATTER_CHANCE_MOD", "RangedAttackScatterChanceMod", s == "", prefix);
	-- Movement logistics
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_MOVE_AFTER_ATTACKING", "MoveAfterAttacking", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_MOVE_AFTER_SUPPORT_MISSION", "MoveAfterSupportMission", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_IGNORE_TERRAIN_COST", "IgnoreTerrainCost", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_IGNORE_PILLAGE_COST", "IgnorePillageCost", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_IGNORE_ZONE_OF_CONTROL", "IgnoreZoneOfControl", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_FLAT_MOVEMENT_COST", "FlatMovementCost", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_MOVE_ANYWHERE", "MoveAnywhere", s == "", prefix);
	-- Don't show "Hover", since it is redundant with the descriptions for "FlatMovementCost" and "MoveAnywhere"
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_WITHDRAW_FROM_MELEE_CHANCE_MOD", "WithdrawFromMeleeChanceMod", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_FREE_REBASES", "FreeRebases", s == "", prefix);
	-- Healing
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ALWAYS_HEAL", "AlwaysHeal", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_HEAL_OUTSIDE_FRIENDLY_TERRITORY", "HealOutsideFriendlyTerritory", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ENEMY_HEAL_CHANGE", "EnemyHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_NEUTRAL_HEAL_CHANGE", "NeutralHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_FRIENDLY_HEAL_CHANGE", "FriendlyHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_MIASMA_HEAL_CHANGE", "MiasmaHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ADJACENT_UNIT_HEAL_CHANGE", "AdjacentUnitHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_SAME_TILE_HEAL_CHANGE", "SameTileHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_KILL_UNIT_HEAL_CHANGE", "KillUnitHealChange", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_PILLAGE_HEAL_CHANGE", "PillageHealChange", s == "", prefix);
	-- Orbital layer
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_GENERATE_MIASMA_IN_ORBIT", "GenerateMiasmaInOrbit", s == "", prefix);
	s = s .. ComposeUnitPerkFlagHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ALLOW_MANUAL_DEORBIT", "AllowManualDeorbit", s == "", prefix);
	s = s .. ComposeUnitPerkNumberHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_ORBITAL_COVERAGE_RADIUS_CHANGE", "OrbitalCoverageRadiusChange", s == "", prefix);
	-- Attrition
	-- Actions
	-- Domain combat mods
	s = s .. ComposeUnitPerkDomainCombatModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DOMAIN_COMBAT_MOD_LAND", "DOMAIN_LAND", s == "", prefix);
	s = s .. ComposeUnitPerkDomainCombatModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DOMAIN_COMBAT_MOD_SEA", "DOMAIN_SEA", s == "", prefix);
	s = s .. ComposeUnitPerkDomainCombatModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_DOMAIN_COMBAT_MOD_AIR", "DOMAIN_AIR", s == "", prefix);
	-- Domain combat mods
	s = s .. ComposeUnitPerkTerrainModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_TERRAIN_TYPE_MOD_GENERIC", "TERRAIN_COAST", s == "", prefix);
	s = s .. ComposeUnitPerkTerrainModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_TERRAIN_TYPE_MOD_GENERIC", "TERRAIN_OCEAN", s == "", prefix);
	-- Combat class mods
	s = s .. ComposeUnitPerkCombatClassModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_COMBAT_CLASS_MOD_GENERIC", "UNITCOMBAT_MELEE", s == "", prefix);
	s = s .. ComposeUnitPerkCombatClassModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_COMBAT_CLASS_MOD_GENERIC", "UNITCOMBAT_RANGED", s == "", prefix);
	s = s .. ComposeUnitPerkCombatClassModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_COMBAT_CLASS_MOD_GENERIC", "UNITCOMBAT_NAVALMELEE", s == "", prefix);
	s = s .. ComposeUnitPerkCombatClassModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_COMBAT_CLASS_MOD_GENERIC", "UNITCOMBAT_NAVALRANGED", s == "", prefix);
	s = s .. ComposeUnitPerkCombatClassModHelpText(filteredPerkIDTable, "TXT_KEY_UNITPERK_COMBAT_CLASS_MOD_GENERIC", "UNITCOMBAT_SUBMARINE", s == "", prefix);

	return s;
end

function ComposeUnitPerkNumberHelpText(perkIDTable, textKey, numberKey, firstEntry, prefix)
	local s = "";
	local number = 0;
	for index, perkID in ipairs(perkIDTable) do
		local perkInfo = GameInfo.UnitPerks[perkID];
		if (perkInfo ~= nil and perkInfo[numberKey] ~= nil and perkInfo[numberKey] ~= 0) then
			number = number + perkInfo[numberKey];
		end
	end

	if (number ~= 0) then
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		end
		if (prefix ~= nil) then
			s = s .. prefix;
		end
		s = s .. Locale.ConvertTextKey(textKey, number);
	end

	return s;
end

function ComposeUnitPerkFlagHelpText(perkIDTable, textKey, flagKey, firstEntry, prefix)
	local s = "";
	local flag = false;
	for index, perkID in ipairs(perkIDTable) do
		local perkInfo = GameInfo.UnitPerks[perkID];
		if (perkInfo ~= nil and perkInfo[flagKey] ~= nil and perkInfo[flagKey]) then
			flag = true;
			break;
		end
	end

	if (flag) then
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		end
		if (prefix ~= nil) then
			s = s .. prefix;
		end
		s = s .. Locale.ConvertTextKey(textKey);
	end

	return s;
end

function ComposeUnitPerkDomainCombatModHelpText(perkIDTable, textKey, domainKey, firstEntry, prefix)
	local s = "";
	local number = 0;
	for index, perkID in ipairs(perkIDTable) do
		local perkInfo = GameInfo.UnitPerks[perkID];
		if (perkInfo ~= nil) then
			for domainCombatInfo in GameInfo.UnitPerks_DomainCombatMods("UnitPerkType = \"" .. perkInfo.Type .. "\" AND DomainType = \"" .. domainKey .. "\"") do
				if (domainCombatInfo.CombatMod ~= 0) then
					number = number + domainCombatInfo.CombatMod;
				end
			end
		end
	end

	if (number ~= 0) then
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		end
		if (prefix ~= nil) then
			s = s .. prefix;
		end
		s = s .. Locale.ConvertTextKey(textKey, number);
	end

	return s;
end

function ComposeUnitPerkCombatClassModHelpText(perkIDTable, textKey, combatClassKey, firstEntry, prefix)
	local s = "";
	local number = 0;
	for index, perkID in ipairs(perkIDTable) do
		local perkInfo = GameInfo.UnitPerks[perkID];
		if (perkInfo ~= nil) then
			for combatClassInfo in GameInfo.UnitPerks_CombatClassMods("UnitPerkType = \"" .. perkInfo.Type .. "\" AND CombatClassType = \"" .. combatClassKey .. "\"") do
				if (combatClassInfo.CombatMod ~= 0) then
					number = number + combatClassInfo.CombatMod;
				end
			end
		end
	end

	if (number ~= 0) then
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		end
		if (prefix ~= nil) then
			s = s .. prefix;
		end

		local combatClassData : table = GameInfo.UnitCombatInfos[combatClassKey];
		if combatClassData ~= nil then
			s = s .. Locale.ConvertTextKey(textKey, number, combatClassData.Description);
		end
	end

	return s;
end

function ComposeUnitPerkTerrainModHelpText(perkIDTable, textKey, terrainKey, firstEntry, prefix)
	local s = "";
	local number = 0;
	for index, perkID in ipairs(perkIDTable) do
		local perkInfo = GameInfo.UnitPerks[perkID];
		if (perkInfo ~= nil) then
			for terrainInfo in GameInfo.UnitPerks_TerrainCombatMods("UnitPerkType = \"" .. perkInfo.Type .. "\" AND TerrainType = \"" .. terrainKey .. "\"") do
				if (terrainInfo.CombatMod ~= 0) then
					number = number + terrainInfo.CombatMod;
				end
			end
		end
	end

	if (number ~= 0) then
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		end
		if (prefix ~= nil) then
			s = s .. prefix;
		end

		local terrainData : table = GameInfo.Terrains[terrainKey];
		if terrainData ~= nil then
			s = s .. Locale.ConvertTextKey(textKey, number, terrainData.Description);
		end
	end

	return s;
end

----------------------------------------------------------------
----------------------------------------------------------------
-- VIRTUES
----------------------------------------------------------------
----------------------------------------------------------------
function GetHelpTextForVirtue(virtueID)
	local list = {};
	table.insert(list, virtueID);
	return GetHelpTextForVirtues(list);
end

function GetHelpTextForVirtues(virtueIDTable)
	local s = "";

	-- Post-processing functions to display values more clearly to player
	local divByHundred = function(number)
		-- Some database values are in multiplied by 100 to match game core usage
		number = number * 0.01;
		return number;
	end;
	local flipSign = function(number)
		number = number * -1;
		return number;
	end;
	local modByGameResearchSpeed = function(number)
		local gameSpeedResearchMod = 1;
		if (Game ~= nil) then
			gameSpeedResearchMod = Game.GetResearchPercent() / 100;
		end
		number = number * gameSpeedResearchMod;
		number = math.floor(number); -- for display, truncate trailing decimals
		return number;
	end;

	s = s .. ComposeVirtueFlagHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CAPTURE_OUTPOSTS_FOR_SELF", "CaptureOutpostsForSelf", s == "");

	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_BARBARIAN_COMBAT_BONUS", "BarbarianCombatBonus", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_RESEARCH_FROM_BARBARIAN_KILLS", "ResearchFromBarbarianKills", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_RESEARCH_FROM_BARBARIAN_CAMPS", "ResearchFromBarbarianCamps", s == "", modByGameResearchSpeed); --value modified by game speed
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_EXP_MODIFIER", "ExpModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_MILITARY_PRODUCTION_MODIFIER", "MilitaryProductionModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_HEALTH_PER_MILITARY_UNIT_TIMES_100", "HealthPerMilitaryUnitTimes100", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_TECH_AFFINITY_XP_MODIFIER", "TechAffinityXPModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_COVERT_OPS_INTRIGUE_MODIFIER", "CovertOpsIntrigueModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_COVERT_OPS_COUNTER_INTEL_MODIFIER", "CovertOpsCounterIntelModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NUM_FREE_AFFINITY_LEVELS", "NumFreeAffinityLevels", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_UNIT_PRODUCTION_MODIFIER_PER_UPGRADE", "UnitProductionModifierPerUpgrade", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_STRATEGIC_RESOURCE_MOD", "StrategicResourceMod", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_ORBITAL_COVERAGE_RADIUS_FROM_STATION_TRADE", "OrbitalCoverageRadiusFromStationTrade", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_UNIT_GOLD_MAINTENANCE_MOD", "UnitGoldMaintenanceMod", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_COMBAT_MODIFIER", "CombatModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_OUTPOST_GROWTH_MODIFIER", "OutpostGrowthModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_FOOD_KEPT_AFTER_GROWTH_PERCENT", "FoodKeptAfterGrowthPercent", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_WORKER_SPEED_MODIFIER", "WorkerSpeedModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_PLOT_CULTURE_COST_MODIFIER", "PlotCultureCostModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_EXPLORER_EXPEDITION_CHARGES", "ExplorerExpeditionCharges", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_LAND_TRADE_ROUTE_GOLD_CHANGE", "LandTradeRouteGoldChange", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_SEA_TRADE_ROUTE_GOLD_CHANGE", "SeaTradeRouteGoldChange", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NEW_CITY_EXTRA_POPULATION", "NewCityExtraPopulation", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_EXTRA_HEALTH", "ExtraHealth", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_EXTRA_HEALTH_PER_LUXURY", "HealthPerBasicResourceTypeTimes100", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_UNHEALTH_MOD", "UnhealthMod", s == "", flipSign); --less confusing to show as a positive number in text
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_RESEARCH_MOD_PER_EXTRA_CONNECTED_TECH", "ResearchModPerExtraConnectedTech", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_HEALTH_TO_SCIENCE", "HealthToScience", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_HEALTH_TO_CULTURE", "HealthToCulture", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_POLICY_COST_MODIFIER", "PolicyCostModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_PERCENT_CULTURE_RATE_TO_ENERGY", "PercentCultureRateToEnergy", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_HEALTH_PER_X_POPULATION", "HealthPerXPopulation", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NUM_CITIES_RESEARCH_COST_DISCOUNT", "NumCitiesResearchCostDiscount", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NUM_CITIES_POLICY_COST_DISCOUNT", "NumCitiesPolicyCostDiscount", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_LEAF_TECH_RESEARCH_MODIFIER", "LeafTechResearchModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_PERCENT_CULTURE_RATE_TO_RESEARCH", "PercentCultureRateToResearch", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CULTURE_PER_WONDER", "CulturePerWonder", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_BUILDING_PRODUCTION_MODIFIER", "BuildingProductionModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_WONDER_PRODUCTION_MODIFIER", "WonderProductionModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_BUILDING_ALREADY_IN_CAPITAL_MODIFIER", "BuildingAlreadyInCapitalModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_INTERNAL_TRADE_ROUTE_YIELD_MODIFIER", "InternalTradeRouteYieldModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_HEALTH_PER_TRADE_ROUTE_TIMES_100", "HealthPerTradeRouteTimes100", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_ORBITAL_PRODUCTION_MODIFIER", "OrbitalProductionModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_ORBITAL_DURATION_MODIFIER", "OrbitalDurationModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_UNIT_PURCHASE_COST_MODIFIER", "UnitPurchaseCostModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_HEALTH_PER_BUILDING_TIMES_100", "HealthPerBuildingTimes100", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_EXTRA_HEALTH_PER_CITY", "ExtraHealthPerCity", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NUM_FREE_TECHS", "NumFreeTechs", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NUM_FREE_POLICIES", "NumFreePolicies", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_NUM_FREE_COVERT_AGENTS", "NumFreeCovertAgents", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_ORBITAL_COVERAGE_MODIFIER", "OrbitalCoverageModifier", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_RESEARCH_FROM_EXPEDITIONS", "ResearchFromExpeditions", s == "", modByGameResearchSpeed); --value modified by game speed
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CITY_GROWTH_MOD", "CityGrowthMod", s == "");
	s = s .. ComposeVirtueNumberHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CAPITAL_GROWTH_MOD", "CapitalGrowthMod", s == "");

	s = s .. ComposeVirtueInterestHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_ENERGY_INTEREST_PERCENT_PER_TURN", "EnergyInterestPercentPerTurn", s == "");

	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_YIELD_MODIFIER", "Policy_YieldModifiers", s == "");
	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CAPITAL_YIELD_MODIFIER", "Policy_CapitalYieldModifiers", s == "");
	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CITY_YIELD_CHANGE", "Policy_CityYieldChanges", s == "");
	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CITY_YIELD_PER_POP_CHANGE", "Policy_CityYieldPerPopChanges", s == "", divByHundred); --value in hundredths
	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_CAPITAL_YIELD_CHANGE", "Policy_CapitalYieldChanges", s == "");
	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_SPECIALIST_EXTRA_YIELD", "Policy_SpecialistExtraYields", s == "");
	s = s .. ComposeVirtueYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_TRADE_ROUTE_WITH_STATION_PER_TIER_YIELD_CHANGE", "Policy_TradeRouteWithStationPerTierYieldChanges", s == "");
	
	s = s .. ComposeVirtueResourceClassYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_RESOURCE_CLASS_YIELD_CHANGE", s == "");

	s = s .. ComposeVirtueImprovementYieldHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_IMPROVEMENT_YIELD_CHANGE", s == "");

	s = s .. ComposeVirtueFreeUnitHelpText(virtueIDTable, "TXT_KEY_POLICY_EFFECT_FREE_UNIT_CLASS", s == "");

	return s;
end

function ComposeVirtueNumberHelpText(virtueIDTable, textKey, numberKey, firstEntry, postProcessFunction)
	local s = "";
	local number = 0;
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil and virtueInfo[numberKey] ~= nil and virtueInfo[numberKey] ~= 0) then
			number = number + virtueInfo[numberKey];
		end
	end

	if (number ~= 0) then
		if (postProcessFunction ~= nil) then
			number = postProcessFunction(number);
		end
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		else
			firstEntry = false;
		end
		s = s .. "[ICON_BULLET]";
		s = s .. Locale.ConvertTextKey(textKey, number);
	end

	return s;
end

function ComposeVirtueFlagHelpText(virtueIDTable, textKey, flagKey, firstEntry)
	local s = "";
	local flag = false;
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil and virtueInfo[flagKey] ~= nil and virtueInfo[flagKey]) then
			flag = true;
			break;
		end
	end

	if (flag) then
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		else
			firstEntry = false;
		end
		s = s .. "[ICON_BULLET]";
		s = s .. Locale.ConvertTextKey(textKey);
	end

	return s;
end

function ComposeVirtueInterestHelpText(virtueIDTable, textKey, numberKey, firstEntry)
	local s = "";
	local interestPercent = 0;
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil and virtueInfo[numberKey] ~= nil and virtueInfo[numberKey] ~= 0) then
			interestPercent = interestPercent + virtueInfo[numberKey];
		end
	end

	if (interestPercent ~= 0) then
		local maximum = (interestPercent * GameDefines["ENERGY_INTEREST_PRINCIPAL_MAXIMUM"]) / 100;
		if (not firstEntry) then
			s = s .. "[NEWLINE]";
		else
			firstEntry = false;
		end
		s = s .. "[ICON_BULLET]";
		s = s .. Locale.ConvertTextKey(textKey, interestPercent, maximum);
	end

	return s;
end

function ComposeVirtueYieldHelpText(virtueIDTable, textKey, tableKey, firstEntry, postProcessFunction)
	local s = "";
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil and GameInfo[tableKey] ~= nil) then
			for tableInfo in GameInfo[tableKey]("PolicyType = \"" .. virtueInfo.Type .. "\"") do
				if (tableInfo.YieldType ~= nil and tableInfo.Yield ~= nil) then
					local yieldInfo = GameInfo.Yields[tableInfo.YieldType];
					local yieldNumber = tableInfo.Yield;
					if (yieldNumber ~= 0) then
						if (postProcessFunction ~= nil) then
							yieldNumber = postProcessFunction(yieldNumber);
						end
						if (not firstEntry) then
							s = s .. "[NEWLINE]";
						else
							firstEntry = false;
						end
						s = s .. "[ICON_BULLET]";
						s = s .. Locale.ConvertTextKey(textKey, yieldNumber, yieldInfo.IconString, yieldInfo.Description);
					end
				end
			end
		end
	end
	return s;
end

function ComposeVirtueResourceClassYieldHelpText(virtueIDTable, textKey, firstEntry)
	local s = "";
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil) then
			for tableInfo in GameInfo.Policy_ResourceClassYieldChanges("PolicyType = \"" .. virtueInfo.Type .. "\"") do
				local resourceClassInfo = GameInfo.ResourceClasses[tableInfo.ResourceClassType];
				local yieldInfo = GameInfo.Yields[tableInfo.YieldType];
				local yieldNumber = tableInfo.YieldChange;
				if (yieldNumber ~= 0) then
					if (not firstEntry) then
						s = s .. "[NEWLINE]";
					else
						firstEntry = false;
					end
					s = s .. "[ICON_BULLET]";
					s = s .. Locale.ConvertTextKey(textKey, yieldNumber, yieldInfo.IconString, yieldInfo.Description, resourceClassInfo.Description);
				end
			end
		end
	end
	return s;
end

function ComposeVirtueImprovementYieldHelpText(virtueIDTable, textKey, firstEntry)
	local s = "";
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil) then
			for tableInfo in GameInfo.Policy_ImprovementYieldChanges("PolicyType = \"" .. virtueInfo.Type .. "\"") do
				local improvementInfo = GameInfo.Improvements[tableInfo.ImprovementType];
				local yieldInfo = GameInfo.Yields[tableInfo.YieldType];
				local yieldNumber = tableInfo.Yield;
				if (yieldNumber ~= 0) then
					if (not firstEntry) then
						s = s .. "[NEWLINE]";
					else
						firstEntry = false;
					end
					s = s .. "[ICON_BULLET]";
					s = s .. Locale.ConvertTextKey(textKey, yieldNumber, yieldInfo.IconString, yieldInfo.Description, improvementInfo.Description);
				end
			end
		end
	end
	return s;
end

function ComposeVirtueFreeUnitHelpText(virtueIDTable, textKey, firstEntry)
	local s = "";
	for index, virtueID in ipairs(virtueIDTable) do
		local virtueInfo = GameInfo.Policies[virtueID];
		if (virtueInfo ~= nil) then
			for tableInfo in GameInfo.Policy_FreeUnitClasses("PolicyType = \"" .. virtueInfo.Type .. "\"") do
				local unitClassInfo = GameInfo.UnitClasses[tableInfo.UnitClassType];
				local unitInfo = GameInfo.Units[unitClassInfo.DefaultUnit];
				if (unitInfo ~= nil) then
					if (not firstEntry) then
						s = s .. "[NEWLINE]";
					else
						firstEntry = false;
					end
					s = s .. "[ICON_BULLET]";
					s = s .. Locale.ConvertTextKey(textKey, unitInfo.Description);
				end
			end
		end
	end
	return s;
end

----------------------------------------------------------------
----------------------------------------------------------------
-- AFFINITIES
----------------------------------------------------------------
----------------------------------------------------------------
function GetHelpTextForAffinity(affinity, player)
	local s = "";
	local affinityInfo = nil;
	if (affinity == GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID) then
		affinityInfo = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"];
	elseif (affinity == GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID) then
		affinityInfo = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"];
	elseif (affinity == GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID) then
		affinityInfo = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"];
	end
	if (affinityInfo == nil) then
		return s;
	end

	if (player ~= nil) then
		-- Current level
		local currentLevel = player:GetAffinityLevel(affinity);
		s = s .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS_DETAIL", affinityInfo.IconString, affinityInfo.ColorType, affinityInfo.Description, player:GetAffinityLevel(affinityInfo.ID));

		-- Progress towards next level
		local nextLevel = player:GetAffinityLevel(affinity) + 1;
		local nextLevelInfo = GameInfo.Affinity_Levels[nextLevel];
		if (nextLevelInfo ~= nil) then
			s = s .. "[NEWLINE][NEWLINE]";
			s = s .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS_PROGRESS", player:GetAffinityScoreTowardsNextLevel(affinityInfo.ID), player:CalculateAffinityScoreNeededForNextLevel(affinityInfo.ID));
		else
			s = s .. "[NEWLINE][NEWLINE]";
			s = s .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS_MAX_LEVEL");
		end

		-- Dominance
		local isDominant = affinityInfo.ID == player:GetDominantAffinityType();
		if (isDominant) then
			if (currentLevel >= 0) then
				s = s .. "[NEWLINE][NEWLINE]";
				s = s .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS_DOMINANT");
			end
		else
			if (nextLevelInfo ~= nil) then
				local penalty = nextLevelInfo.AffinityValueNeededAsNonDominant - nextLevelInfo.AffinityValueNeededAsDominant;
				if (penalty > 0) then
					s = s .. "[NEWLINE][NEWLINE]";
					s = s .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS_NON_DOMINANT_PENALTY", penalty);
				end
			end
		end
	end

	return s;
end

-- Does not include unit upgrade unlocks
function GetHelpTextsForAffinityLevel(affinity, affinityLevel)

	CacheDatabaseQueries();

	local textTable = {};
	local affinityInfo = GameInfo.Affinity_Types[affinity];
	local affinityLevelInfo = GameInfo.Affinity_Levels[affinityLevel];
	if (affinityInfo == nil or affinityLevelInfo == nil) then
		return textTable;
	end
	
	-- Gained a Player Perk?
	local CachedAffinityPerks = nil;
	if (affinityInfo.Type == "AFFINITY_TYPE_HARMONY") then
		CachedAffinityPerks = CachedHarmonyAffinityPerks;
	elseif (affinityInfo.Type == "AFFINITY_TYPE_PURITY") then
		CachedAffinityPerks = CachedPurityAffinityPerks;
	elseif (affinityInfo.Type == "AFFINITY_TYPE_SUPREMACY") then
		CachedAffinityPerks = CachedSupremacyAffinityPerks;
	end
	if (CachedAffinityPerks ~= nil and CachedAffinityPerks[affinityLevel] ~= nil) then
		for i, affinityPerk in ipairs(CachedAffinityPerks[affinityLevel]) do
			local s = "";
			local perkInfo = GameInfo.PlayerPerks[affinityPerk.PlayerPerk];
			if (perkInfo ~= nil) then
				s = s .. Locale.ConvertTextKey(perkInfo.Help);
			end
			if (#affinityPerk.OtherAffinityPrereqs > 0) then
				local prereqAffinityData : table = {};
				for i : number, otherAffinityPrereq in ipairs(affinityPerk.OtherAffinityPrereqs) do
					local otherAffinityInfo : table = GameInfo.Affinity_Types[otherAffinityPrereq.AffinityType];
					if (otherAffinityInfo ~= nil) then
						table.insert(prereqAffinityData, {AffinityInfo = otherAffinityInfo, PrereqInfo = otherAffinityPrereq});
					end
				end

				if (#prereqAffinityData == 1) then
					s = Locale.Lookup("TXT_KEY_AFFINITY_ONE_REQUIREMENT", 
						prereqAffinityData[1].AffinityInfo.IconString, prereqAffinityData[1].PrereqInfo.Level) .. s;
				elseif (#prereqAffinityData == 2) then
					s = Locale.Lookup("TXT_KEY_AFFINITY_TWO_REQUIREMENTS", 
						prereqAffinityData[1].AffinityInfo.IconString, prereqAffinityData[1].PrereqInfo.Level,
						prereqAffinityData[2].AffinityInfo.IconString, prereqAffinityData[2].PrereqInfo.Level) .. s;
				elseif (#prereqAffinityData == 3) then
					s = Locale.Lookup("TXT_KEY_AFFINITY_THREE_REQUIREMENTS", 
						prereqAffinityData[1].AffinityInfo.IconString, prereqAffinityData[1].PrereqInfo.Level,
						prereqAffinityData[2].AffinityInfo.IconString, prereqAffinityData[2].PrereqInfo.Level,
						prereqAffinityData[3].AffinityInfo.IconString, prereqAffinityData[3].PrereqInfo.Level) .. s;
				else
					print("Exceeded max affinity prereqs");
				end

				--[[
				local prereqString = "(with ";
				for i, otherAffinityPrereq in ipairs(affinityPerk.OtherAffinityPrereqs) do
					local otherAffinityInfo = GameInfo.Affinity_Types[otherAffinityPrereq.AffinityType];
					if (otherAffinityInfo ~= nil) then
						prereqString = prereqString .. otherAffinityInfo.IconString .. otherAffinityPrereq.Level;
					end
				end
				prereqString = prereqString .. ")";
				s = prereqString .. " " .. s;]]
			end
			table.insert(textTable, s);
		end
	end

	-- Unlocked Covert Ops?
	for covertOperationType, value in pairs(CachedCovertOperationAffinityPrereqs) do
		if (value.AffinityType == affinityInfo.Type and value.Level == affinityLevel) then
			local covertOpInfo = GameInfo.CovertOperations[covertOperationType];
			local s = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_UP_DETAILS_COVERT_OP_UNLOCKED", covertOpInfo.Description);
			table.insert(textTable, s);
		end
	end

	-- Unlocked Projects (for Victory)?
	for projectType, value in pairs(CachedProjectAffinityPrereqs) do
		if (value.AffinityType == affinityInfo.Type and value.Level == affinityLevel) then
			local projectInfo = GameInfo.Projects[projectType];
			local victoryInfo = GameInfo.Victories[projectInfo.VictoryPrereq];
			local s = Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_UP_DETAILS_PROJECT_UNLOCKED", projectInfo.Description, victoryInfo.Description);
			table.insert(textTable, s);
		end
	end

	return textTable;
end