
-- A lookup table that contains an xref from a building ID to its building class ID
BuildingIDToBuildingClassID = {};

m_hasCache = false;

function CachePerkHelperData()
	if m_hasCache then
		return;
	end

	m_hasCache = true;

	-- Make a table that xrefs a building ID with its building class ID	
	for row in GameInfo.Buildings() do
		local buildingClassInfo = GameInfo.BuildingClasses[row.BuildingClass];
		BuildingIDToBuildingClassID[row.ID] = buildingClassInfo.ID;
	end
end

function ClearCache( closed )
	m_hasCache = false;

	BuildingIDToBuildingClassID = {};
end
Events.DatabaseReset.Add(ClearCache);

-- Sum of all FLAT YIELD changes for active building class perk
function GetPlayerPerkBuildingFlatYieldChanges(activePerkTypes : table, playerID : number, buildingID : number, yieldID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		if (buildingClassID ~= nil) then
			for i : number, v : number in ipairs(activePerkTypes) do
				result = result + Game.GetPlayerPerkBuildingClassFlatYieldChange(v, buildingClassID, yieldID);
			end
		end
	else	
		local yieldInfo = GameInfo.Yields[yieldID];
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_BuildingYieldEffects{ PlayerPerkType = perkInfo.Type, YieldType = yieldInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.FlatYield;
			end
		end
	end

	return result;
end

-- Sum of all PERCENT YIELD changes for active building class perks
function GetPlayerPerkBuildingPercentYieldChanges(activePerkTypes : table, playerID : number, buildingID : number, yieldID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassPercentYieldChange(v, buildingClassID, yieldID);
		end
	else
		local yieldInfo = GameInfo.Yields[yieldID];
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_BuildingYieldEffects{ PlayerPerkType = perkInfo.Type, YieldType = yieldInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.PercentYield;
			end
		end
	end

	return result;
end

-- Sum of all FLAT HEALTH changes for active building class perks
function GetPlayerPerkBuildingFlatHealthChanges(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassFlatHealthChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.FlatHealth;
			end
		end
	end

	return result;
end

-- Sum of all PERCENT HEALTH changes for active building class perks
function GetPlayerPerkBuildingPercentHealthChanges(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types

	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassPercentHealthChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.PercentHealth;
			end
		end
	end

	return result;
end

-- Sum of all CITY STRENGTH changes for active building class perks
function GetPlayerPerkBuildingCityStrengthChanges(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassCityStrengthChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.CityStrength;
			end
		end
	end

	return result;
end

-- Sum of all CITY HIT POINTS changes for active building class perks
function GetPlayerPerkBuildingCityHPChanges(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassCityHPChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.CityHitPoints;
			end
		end
	end

	return result;
end

-- Sum of all CITY STRIKE DAMAGE changes for active building class perks
function GetPlayerPerkBuildingCityStrikeDamageMod(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassCityStrikeMod(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.CityStrikeDamageMod;
			end
		end
	end

	return result;
end

-- Sum of all ENERGY MAINTENANCE changes for active building class perks
function GetPlayerPerkBuildingEnergyMaintenanceChanges(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassEnergyMaintenanceChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.MaintenanceChange;
			end
		end
	end

	return result;
end

-- Sum of all ORBITAL COVERAGE changes for active building class perks
function GetPlayerPerkBuildingOrbitalCoverageChanges(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassOrbitalCoverageChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.OrbitalCoverageChange;
			end
		end
	end

	return result;
end

-- Sum of all MOVE CITY COST changes for active building class perks
function GetPlayerPerkBuildingCityMoveCostMod(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassAquaticCityMoveCostMod(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.AquaticCityMoveCostMod;
			end
		end
	end

	return result;
end

-- Sum of all MILITARY UNIT PRODUCTION changes for active building class perks
function GetPlayerPerkBuildingMilitaryProductionMod(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassMilitaryProductionMod(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.ProductionModMilitaryUnits;
			end
		end
	end

	return result;
end

-- Sum of all NAVAL UNIT PRODUCTION changes for active building class perks
function GetPlayerPerkBuildingNavalProductionMod(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassNavalProductionMod(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.ProductionModNavalUnits;
			end
		end
	end

	return result;
end

-- Sum of all GROWTH CARRYOVER changes for active building class perks
function GetPlayerPerkBuildingGrowthCarryoverChange(activePerkTypes : table, playerID : number, buildingID : number)

	CachePerkHelperData();
	
	local result = 0;

	-- Iterate over player's active perk types
	if (Game ~= nil) then
		local buildingClassID = BuildingIDToBuildingClassID[buildingID];
		for i : number, v : number in ipairs(activePerkTypes) do
			result = result + Game.GetPlayerPerkBuildingClassGrowthCarryoverChange(v, buildingClassID);
		end
	else
		local buildingInfo = GameInfo.Buildings[buildingID];
		for i,v in ipairs(activePerkTypes) do

			local perkInfo = GameInfo.PlayerPerks[v];

			for row in GameInfo.PlayerPerks_GeneralBuildingEffects{ PlayerPerkType = perkInfo.Type, BuildingClassType = buildingInfo.BuildingClass } do			
				result = result + row.GrowthCarryover;
			end
		end
	end

	return result;
end