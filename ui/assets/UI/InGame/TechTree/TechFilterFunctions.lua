hstructure TechFilters
	TECHFILTER_RECOMMENDED : ifunction
	TECHFILTER_FOOD : ifunction
	TECHFILTER_SCIENCE : ifunction
	TECHFILTER_PRODUCTION : ifunction
	TECHFILTER_CULTURE : ifunction
	TECHFILTER_ENERGY : ifunction
	TECHFILTER_CAPITAL : ifunction
	TECHFILTER_HEALTH : ifunction
	TECHFILTER_PURITY : ifunction
	TECHFILTER_HARMONY : ifunction
	TECHFILTER_SUPREMACY : ifunction
	TECHFILTER_UNITS : ifunction
	TECHFILTER_IMPROVEMENTS : ifunction
	TECHFILTER_WONDERS : ifunction
	TECHFILTER_ORBITAL : ifunction
	TECHFILTER_AQUATIC : ifunction
	TECHFILTER_VICTORIES : ifunction
end

g_TechFilters = hmake TechFilters{};

-- Food Filter
g_TechFilters.TECHFILTER_FOOD = function(techInfo)
	local yieldType : string = "YIELD_FOOD";

	if CheckUnlocksForYield(techInfo, yieldType) then
		return true;
	end

	return false;
end

-- Science Filter
g_TechFilters.TECHFILTER_SCIENCE = function(techInfo)
	local yieldType : string = "YIELD_SCIENCE";

	if CheckUnlocksForYield(techInfo, yieldType) then
		return true;
	end

	return false;
end

-- Production Filter
g_TechFilters.TECHFILTER_PRODUCTION = function(techInfo)
	local yieldType : string = "YIELD_PRODUCTION";

	if CheckUnlocksForYield(techInfo, yieldType) then
		return true;
	end

	return false;
end

-- Culture Filter
g_TechFilters.TECHFILTER_CULTURE = function(techInfo)
	local yieldType : string = "YIELD_CULTURE";

	if CheckUnlocksForYield(techInfo, yieldType) then
		return true;
	end

	return false;
end

-- Energy Filter
g_TechFilters.TECHFILTER_ENERGY = function(techInfo)
	local yieldType : string = "YIELD_ENERGY";

	if CheckUnlocksForYield(techInfo, yieldType) then
		return true;
	end

	return false;
end

-- Health Filter
g_TechFilters.TECHFILTER_HEALTH = function(techInfo)
	if CheckUnlocksForHealth(techInfo) then
		return true;
	end

	return false;
end

-- Purity Filter
g_TechFilters.TECHFILTER_PURITY = function(techInfo)
	local affinityType : string = "AFFINITY_TYPE_PURITY";

	if CheckAffinity(techInfo, affinityType) then
		return true;
	end

	return false;
end

-- Harmony Filter
g_TechFilters.TECHFILTER_HARMONY = function(techInfo)
	local affinityType : string = "AFFINITY_TYPE_HARMONY";

	if CheckAffinity(techInfo, affinityType) then
		return true;
	end

	return false;
end

-- Supremacy Filter
g_TechFilters.TECHFILTER_SUPREMACY = function(techInfo)
	local affinityType : string = "AFFINITY_TYPE_SUPREMACY";

	if CheckAffinity(techInfo, affinityType) then
		return true;
	end

	return false;
end

-- Improvements Filter
g_TechFilters.TECHFILTER_IMPROVEMENTS = function(techInfo)
	-- Improvements
	local condition : string = "PrereqTech = '" .. techInfo.Type .. "' and ImprovementType IS NOT NULL";
	for row in GameInfo.Builds(condition) do
		if row ~= nil then
			return true;
		end
	end

	return false;
end

-- Wonders Filter
g_TechFilters.TECHFILTER_WONDERS = function(techInfo)
	local query : string = "SELECT BuildingClasses.Type from BuildingClasses INNER JOIN Buildings ON Buildings.BuildingClass = BuildingClasses.Type WHERE BuildingClasses.MaxGlobalInstances = 1 AND Buildings.PrereqTech = '" .. techInfo.Type .. "' LIMIT 1";

	for row : table in DB.Query(query) do
		return true;
	end

	return false;
end

-- Units Filter
g_TechFilters.TECHFILTER_UNITS = function(techInfo)
	local condition : string = "PrereqTech = '" .. techInfo.Type .. "'";
	for row in GameInfo.Units(condition) do
		if row ~= nil then
			return true;
		end
	end

	return false;
end

-- Orbital Filter
g_TechFilters.TECHFILTER_ORBITAL = function(techInfo)
	local condition : string = "PrereqTech = '" .. techInfo.Type .. "' and Orbital IS NOT NULL";
	for row in GameInfo.Units(condition) do
		if row ~= nil then
			return true;
		end
	end

	return false;
end

-- Aquatic Filter
g_TechFilters.TECHFILTER_AQUATIC = function(techInfo)
	return false;
end

-- Victory Conditions Filter
g_TechFilters.TECHFILTER_VICTORIES = function(techInfo)
	-- At present there's no better way than to do this manually, because
	-- each Victory quest can require techs for one of several reasons:
	--		*	The victory requires building a unit or building that is unlocked by the tech	
	--		*	The victory requires the tech itself to advance the quest

	-- Contact Victory
	if (Game.IsVictoryValid(GameInfo.Victories.VICTORY_CONTACT)) then
		-- Transcendental Equation
		if (techInfo.Type == "TECH_TRANSCENDENTAL_MATH") then
			return true;
		end
		-- Deep Space Telescope prereq
		if (techInfo.Type == GameInfo.Units.UNIT_DEEP_SPACE_TELESCOPE.PrereqTech) then
			return true;
		end
	end

	-- Promised Land Victory
	if (Game.IsVictoryValid(GameInfo.Victories.VICTORY_PROMISED_LAND)) then
		-- Lasercom Satellite prereq
		if (techInfo.Type == GameInfo.Units.UNIT_LASERCOM_SATELLITE.PrereqTech) then
			return true;
		end
		-- Purity Gate prereq
		if (techInfo.Type == GameInfo.Projects.PROJECT_PURITY_GATE.TechPrereq) then
			return true;
		end
	end

	-- Emancipation Victory
	if (Game.IsVictoryValid(GameInfo.Victories.VICTORY_EMANCIPATION)) then
		-- Lasercom Satellite prereq
		if (techInfo.Type == GameInfo.Units.UNIT_LASERCOM_SATELLITE.PrereqTech) then
			return true;
		end
		-- Supremacy Gate prereq
		if (techInfo.Type == GameInfo.Projects.PROJECT_SUPREMACY_GATE.TechPrereq) then
			return true;
		end
	end

	-- Transcendence Victory
	if (Game.IsVictoryValid(GameInfo.Victories.VICTORY_TRANSCENDENCE)) then
		-- Quest Techs
		if (techInfo.Type == "TECH_TRANSGENICS" or 
			techInfo.Type == "TECH_SWARM_INTELLIGENCE" or 
			techInfo.Type == "TECH_NANOROBOTICS") 
		then
			return true;
		end
		-- Mind Flower speed-up building prereqs
		if (techInfo.Type == GameInfo.Buildings.BUILDING_MIND_STEM.PrereqTech or 
			techInfo.Type == GameInfo.Buildings.BUILDING_XENO_SANCTUARY.PrereqTech) 
		then
			return true;
		end
	end

	return false;
end

-- ===========================================================================
-- 	Utility Functions
-- ===========================================================================
function CheckUnlocksForYield(techInfo, yieldType)
	-- Buildings
	for row in GameInfo.Buildings{ PrereqTech = techInfo.Type } do
		local buildingType = row.Type;

		-- Direct yield from building
		for row in GameInfo.Building_YieldChanges{ BuildingType = buildingType, YieldType = yieldType } do
			if row.Yield > 0 then
				return true;
			end
		end

		-- Building specialists
		if row.SpecialistType ~= nil and row.SpecialistCount > 0 then
			for row in GameInfo.SpecialistYields{SpecialistType = row.SpecialistType} do
				if row.YieldType == yieldType then
					return true;
				end
			end
		end
	end

	-- Improvements
	-- To find Improvements we must go through Builds
	local condition : string = "PrereqTech = '" .. techInfo.Type .. "' and ImprovementType IS NOT NULL";
	for row in GameInfo.Builds(condition) do

		local improvementType = row.ImprovementType;		
		for row in GameInfo.Improvement_Yields{ ImprovementType = improvementType, YieldType = yieldType } do
			if row.Yield > 0 then
				return true;
			end
		end
	end

	-- Yield from other sources..?
	-- TODO

	return false;
end

function CheckUnlocksForHealth(techInfo)
	-- Health from Buildings
	for row in GameInfo.Buildings{ PrereqTech = techInfo.Type } do
		if row.Health > 0 then
			return true;
		end
	end

	-- Health from other sources..?
	-- TODO

	return false;
end

function CheckAffinity(techInfo, affinityType)
	for row in GameInfo.Technology_Affinities{ TechType = techInfo.Type, AffinityType = affinityType } do
		if row.AffinityValue > 0 then
			return true;
		end
	end

	return false;
end