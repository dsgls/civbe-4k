-- =========================================
-- ===== Affinity
-- =========================================

function AnalyzeAffinityTechs()
	local branchQuery = "SELECT Technology_Affinities.TechType, Technologies.Cost, Technology_Affinities.AffinityType, Technology_Affinities.AffinityValue FROM Technology_Affinities INNER JOIN Technologies ON Technologies.Type = Technology_Affinities.TechType AND Technologies.LeafTech = 0 ORDER BY Technologies.Cost";
	local leafQuery = "SELECT Technology_Affinities.TechType, Technologies.Cost, Technology_Affinities.AffinityType, Technology_Affinities.AffinityValue FROM Technology_Affinities INNER JOIN Technologies ON Technologies.Type = Technology_Affinities.TechType AND Technologies.LeafTech = 1 ORDER BY Technologies.Cost";
	local queries = {
		Branch = branchQuery,
		Leaf = leafQuery,
	};
	local tierData = {};
	for techCategory, query in pairs(queries) do
		local currentTier = 0;
		local currentCost = -1;
		for row in DB.Query(query) do
			if (row.Cost > currentCost) then
				currentTier = currentTier + 1;
				currentCost = row.Cost;
			end
			if (tierData[currentTier] == nil) then
				table.insert(tierData, {});
			end
			if (tierData[currentTier][techCategory] == nil) then
				tierData[currentTier][techCategory] = {};
			end
			if (tierData[currentTier][techCategory][row.AffinityType] == nil) then
				tierData[currentTier][techCategory][row.AffinityType] = {
					NumTechs = 0,
					NumXP = 0,
					CumulativeTechs = 0,
					CumulativeXP = 0,
				};
				if (tierData[currentTier - 1] ~= nil) then
					tierData[currentTier][techCategory][row.AffinityType].CumulativeTechs = tierData[currentTier - 1][techCategory][row.AffinityType].CumulativeTechs;
					tierData[currentTier][techCategory][row.AffinityType].CumulativeXP = tierData[currentTier - 1][techCategory][row.AffinityType].CumulativeXP;
				end
			end
			tierData[currentTier][techCategory][row.AffinityType].NumTechs = 1 + tierData[currentTier][techCategory][row.AffinityType].NumTechs;
			tierData[currentTier][techCategory][row.AffinityType].CumulativeTechs = 1 + tierData[currentTier][techCategory][row.AffinityType].CumulativeTechs;
			tierData[currentTier][techCategory][row.AffinityType].NumXP = row.AffinityValue + tierData[currentTier][techCategory][row.AffinityType].NumXP;
			tierData[currentTier][techCategory][row.AffinityType].CumulativeXP = row.AffinityValue + tierData[currentTier][techCategory][row.AffinityType].CumulativeXP;
		end
	end
	
	for tierNumber, tierTable in ipairs(tierData) do
		PrintHeader("Tier " .. tierNumber .. " Techs");
		for techCategory, categoryTable in pairs(tierTable) do
			PrintSection(techCategory);
			for affinityInfo in GameInfo.Affinity_Types() do
				local affinity = affinityInfo.Type;
				PrintData(Locale.Lookup(affinityInfo.Description) .. ": " .. categoryTable[affinity].NumXP .. " XP (" .. categoryTable[affinity].NumTechs .. " techs)");
			end
		end
		PrintSection("Cumulative Totals");
		for affinityInfo in GameInfo.Affinity_Types() do
			local affinity = affinityInfo.Type;
			local xp = 0;
			local techs = 0;
			for techCategory, categoryTable in pairs(tierTable) do
				xp = xp + categoryTable[affinity].CumulativeXP;
				techs = techs + categoryTable[affinity].CumulativeTechs;
			end
			PrintData(Locale.Lookup(affinityInfo.Description) .. ": " .. xp .. " XP (" .. techs .. " techs)");
		end
	end
end

function AnalyzeAffinityLevels()
	PrintHeader("Affinity Levels");

	PrintSection("Level | Delta | Total");
	local totalXP = 0;
	local query = "SELECT * FROM Affinity_Levels ORDER BY ID";
	for t in DB.Query(query) do
		totalXP = totalXP + t.AffinityValueNeededAsDominant;
		PrintData("  " .. t.ID .. "     " .. t.AffinityValueNeededAsDominant .. "     " .. totalXP);
	end
end

-- =========================================
-- ===== Units and Upgrades
-- =========================================

function AnalyzeUnitPrereqs(unitStringTable)
	for i, unitString in ipairs(unitStringTable) do
		AnalyzeUnitPrereq(unitString);
	end
end

function AnalyzeUnitPrereq(unitString)
	local techPrereqString = GameInfo.Units[unitString].PrereqTech;
	if (techPrereqString ~= nil) then
		PrintHeader("Cheapest Tech Prereq Path to " .. unitString .. " (" .. techPrereqString .. ")");
		AnalyzePathToTech(techPrereqString);
	end
end

function AnalyzeUnitMatchups()
	PrintHeader("Simulating Unit Matchups for unusual outcomes");
	local simulatedSet = {};
	local dbFilter = "Combat > 0 AND RangedCombat == 0 AND NOT AlienLifeform";
	for attackerUnitInfo in GameInfo.Units(dbFilter) do
		for defenderUnitInfo in GameInfo.Units(dbFilter) do
			local simulationKey = "";
			if (attackerUnitInfo.Type < defenderUnitInfo.Type) then
				simulationKey = attackerUnitInfo.Type .. "_vs_" .. defenderUnitInfo.Type;
			else
				simulationKey = defenderUnitInfo.Type .. "_vs_" .. attackerUnitInfo.Type;
			end
			if (simulatedSet[simulationKey] == nil) then
				AnalyzeCombat(attackerUnitInfo.Type, defenderUnitInfo.Type);
				simulatedSet[simulationKey] = true;
			end
		end
	end
end

function AnalyzeCombat(attackerUnitString, defenderUnitString)
	local attackerUnitInfo = GameInfo.Units[attackerUnitString];
	local defenderUnitInfo = GameInfo.Units[defenderUnitString];
	if (attackerUnitInfo ~= nil and defenderUnitInfo ~= nil) then
		local attackerStrengthFactor = CalculateCombatStrengthFactor(attackerUnitInfo.Combat, defenderUnitInfo.Combat);
		local attackerDamageMin = 24 * attackerStrengthFactor;
		local attackerDamageAvg = 30 * attackerStrengthFactor;
		local attackerDamageMax = 36 * attackerStrengthFactor;
		local defenderStrengthFactor = CalculateCombatStrengthFactor(defenderUnitInfo.Combat, attackerUnitInfo.Combat);
		local defenderDamageMin = 24 * defenderStrengthFactor;
		local defenderDamageAvg = 30 * defenderStrengthFactor;
		local defenderDamageMax = 36 * defenderStrengthFactor;

		local unusualCombatResults = GetUnusualCombatResults(attackerUnitInfo, attackerDamageAvg, defenderUnitInfo, defenderDamageAvg);
		if (#unusualCombatResults > 0) then
			PrintSection(Locale.Lookup(attackerUnitInfo.Description) .. " vs " .. Locale.Lookup(defenderUnitInfo.Description));
			for i, unusualResult in ipairs(unusualCombatResults) do
				PrintData("Unusual: " .. unusualResult);
			end
			PrintData(Locale.Lookup(attackerUnitInfo.Description) .. "(" .. attackerUnitInfo.Combat .. " STR) deals " .. ToRoundedString(attackerDamageMin) .. "-" .. ToRoundedString(attackerDamageMax) .. " damage");
			PrintData(Locale.Lookup(defenderUnitInfo.Description) .. "(" .. defenderUnitInfo.Combat .. " STR) deals " .. ToRoundedString(defenderDamageMin) .. "-" .. ToRoundedString(defenderDamageMax) .. " damage");
		end
	end
end

function CalculateCombatStrengthFactor(myStrength, opponentStrength)
	local factor = 0;
	local ratio = myStrength / opponentStrength;
	if (ratio >= 1) then
		factor = (((ratio + 3)/4)^4 + 1)/2;
	elseif (ratio < 1 and ratio > 0) then
		factor = 1 / ((((1/ratio + 3)/4)^4 + 1)/2);
	end
	return factor;
end

function GetUnusualCombatResults(attackerUnitInfo, attackerDamageAvg, defenderUnitInfo, defenderDamageAvg)
	local unusualResults = {};
	local costRatio = attackerUnitInfo.Cost / defenderUnitInfo.Cost;
	if (costRatio < 2 and costRatio > 0.5) then
		if (attackerDamageAvg > 60 or defenderDamageAvg > 60) then
			table.insert(unusualResults, "Comparable costs, average damage over 60");
		end
	end
	--[[
	if (attackerDamageAvg < 10 or defenderDamageAvg < 10) then
		table.insert(unusualResults, "Average damage under 10");
	end
	--]]
	return unusualResults;
end

-- =========================================
-- ===== Tech Web
-- =========================================

function AnalyzePathToTech(techString)
	PrintHeader("Cheapest Tech Prereq Path to " .. techString);
	local bestPath = FindCheapestPathToTech(techString);
	if (bestPath ~= nil) then
		local totalCost = 0;
		for i, pathTech in ipairs(bestPath) do
			totalCost = totalCost + GameInfo.Technologies[pathTech].Cost;
			PrintSection(i .. ": " .. pathTech .. " (" .. GameInfo.Technologies[pathTech].Cost .. ")");
		end
		PrintData("Total Cost = " .. totalCost);
	else
		PrintSection("No path found!");
	end
end

-- Find the cheapest research path to a particular tech, using Dijkstra's algorithm
function FindCheapestPathToTech(endTechString)
	local techWeb = {}; -- Consider pulling out into member variable to avoid recalculation across different analyses
	local unvisited = {};
	for row in GameInfo.Technologies() do
		techWeb[row.Type] = {
			CostToHere = math.huge,
			PreviousTech = nil
		};
		table.insert(unvisited, row.Type);
	end
	local startTechString = "TECH_HABITATION";
	techWeb[startTechString].CostToHere = 0;

	-- Early out
	if (startTechString == endTechString) then
		return { startTechString };
	end

	while #unvisited > 0 do
		-- Sort our unvisited list
		table.sort(unvisited, function(lhs, rhs)
			return techWeb[lhs].CostToHere < techWeb[rhs].CostToHere;
		end);

		-- Dequeue
		local curTechString = unvisited[1];
		table.remove(unvisited, 1);

		-- Find connected techs
		local queries = {};
		table.insert(queries, "SELECT Technology_Connections.FirstTech AS Start, Technology_Connections.SecondTech AS Connected, Technologies.Cost AS ConnectedCost FROM Technology_Connections INNER JOIN Technologies WHERE Start = '" .. curTechString .. "' AND Connected = Technologies.Type");
		table.insert(queries, "SELECT Technology_Connections.SecondTech AS Start, Technology_Connections.FirstTech AS Connected, Technologies.Cost AS ConnectedCost FROM Technology_Connections INNER JOIN Technologies WHERE Start = '" .. curTechString .. "' AND Connected = Technologies.Type");
		for i, query in ipairs(queries) do
			for row in DB.Query(query) do
				local nextTechString = row.Connected;
				local costToCur = techWeb[curTechString].CostToHere;
				local costToNext = costToCur + GameInfo.Technologies[nextTechString].Cost;
				if (costToNext < techWeb[nextTechString].CostToHere) then
					techWeb[nextTechString].CostToHere = costToNext;
					techWeb[nextTechString].PreviousTech = curTechString;
				end

				-- Found destination? - Reconstruct our path and we're done
				if (nextTechString == endTechString) then
					local bestPathToStart = {};
					table.insert(bestPathToStart, nextTechString);
					local prevTechString = techWeb[nextTechString].PreviousTech;
					while (prevTechString ~= nil) do
						table.insert(bestPathToStart, prevTechString);
						prevTechString = techWeb[prevTechString].PreviousTech;
					end

					-- Reverse it so it reads in expected order
					local bestPathToEnd = {};
					for j = #bestPathToStart, 1, -1 do
						table.insert(bestPathToEnd, bestPathToStart[j]);						
					end
					return bestPathToEnd;
				end
			end
		end
	end

	return nil;
end

-- =========================================
-- ===== Setup and Formatting
-- =========================================

function ToRoundedString(num)
	return string.format("%d", num);
end

function PrintHeader(text)
	print("");
	print("! > " .. text);
end

function PrintSection(text)
	print("     > " .. text);
end

function PrintData(text)
	print("       " .. text);
end

function Initialize()
	print("BalanceAnalytics ready");
end

Initialize();