------------------------------------------------------
-- StationHelper.lua

-- Consolidation of code associated with displaying
-- statuses and such for Stations
------------------------------------------------------

include( "IconSupport" );
include( "StringHelperInclude" );

-- Conquest only yields either Energy or Science
-- If the station produces a different yield, it's converted to one of those via this table
local REWARD_YIELD_CONVERSION = {
	[YieldTypes.YIELD_FOOD] = {
		[YieldTypes.YIELD_SCIENCE]	= 0,
		[YieldTypes.YIELD_ENERGY]	= 100,
	},
	[YieldTypes.YIELD_CULTURE] = {
		[YieldTypes.YIELD_SCIENCE]	= 50,
		[YieldTypes.YIELD_ENERGY]	= 50,
	},
	[YieldTypes.YIELD_PRODUCTION] = {
		[YieldTypes.YIELD_SCIENCE]	= 100,
		[YieldTypes.YIELD_ENERGY]	= 0,
	},
}

function GenericYieldDelta(station, yieldType, allYieldsTable)

	local yieldTable = SubTableByIndexClamped(station:GetLevel(), allYieldsTable);
	if yieldTable[yieldType] ~= nil then
		return yieldTable[yieldType];
	else
		return 0;
	end
end

function GenericConquestYield(station, yieldType, allYieldsTable)

	if (yieldType ~= YieldTypes.YIELD_SCIENCE and yieldType ~= YieldTypes.YIELD_ENERGY) then
		error("Station Conquest yields can only be either Energy or Science");
		return 0;
	end

	local reward = 0;
	local yieldTable = SubTableByIndexClamped(station:GetLevel(), allYieldsTable);

	if yieldTable[yieldType] ~= nil then
		reward = yieldTable[yieldType];
	else
		for k,v in pairs(yieldTable) do
			if REWARD_YIELD_CONVERSION[k] ~= nil then
				local yieldConversion = REWARD_YIELD_CONVERSION[k][yieldType];
				reward = reward + ((v * yieldConversion) / 100);
			end
		end	
	end

	return (reward * GameDefines.STATION_CONQUEST_YIELD_REWARD_SCALAR) / 100;
end

-----------------------------------------------------------------------------------
function GenericYieldStationMessageString(stationData, playerType, allYieldsTable)

	-- Allow for Station Sentinel yield mod
	local yieldMod : number = 0;
	local station : object = Game.GetStationByType(stationData.Info.ID);
	if (station ~= nil) then
		local stationPlot : object = station:GetPlot();
		local orbitalUnitForPlot : object = stationPlot:GetOrbitalUnitInfluencingPlot();
		if (orbitalUnitForPlot ~= nil and orbitalUnitForPlot:GetOwner() == playerType) then
			local orbitalUnitType = orbitalUnitForPlot:GetOrbitalUnitType();
			if (orbitalUnitType >= 0) then
				yieldMod = GameInfo.OrbitalUnits[orbitalUnitType].StationTradeYieldMod;
			end
		end
	end

	local yieldStrings = {};
	local yieldTable = SubTableByIndexClamped(stationData.Level, allYieldsTable);

	for type, yield in pairs(yieldTable) do		
		yield = yield + ((yield * yieldMod) / 100);
		local yieldString = GetYieldValueString(type, yield, false);
		table.insert(yieldStrings, yieldString);
	end

	if (#yieldStrings == 1) then
		return Locale.ConvertTextKey("TXT_KEY_STATION_PROPOSAL_ONE_YIELD", stationData.Info.Description, yieldStrings[1]);
	elseif (#yieldStrings == 2) then
		return Locale.ConvertTextKey("TXT_KEY_STATION_PROPOSAL_TWO_YIELDS", stationData.Info.Description, yieldStrings[1], yieldStrings[2]);
	elseif (#yieldStrings == 3) then
		return Locale.ConvertTextKey("TXT_KEY_STATION_PROPOSAL_THREE_YIELDS", stationData.Info.Description, yieldStrings[1], yieldStrings[2], yieldStrings[3]);
	else
		return "NUM YIELDS UNHANDLED"
	end
end

-----------------------------------------------------------------------------------
function GenericYieldStationNextLevelString(station, playerType, allYieldsTable)

	-- Allow for Station Sentinel yield mod
	local yieldMod : number = 0;
	local stationPlot : object = station:GetPlot();
	local orbitalUnitForPlot : object = stationPlot:GetOrbitalUnitInfluencingPlot();
	if (orbitalUnitForPlot ~= nil and orbitalUnitForPlot:GetOwner() == playerType) then
		local orbitalUnitType = orbitalUnitForPlot:GetOrbitalUnitType();
		if (orbitalUnitType >= 0) then
			yieldMod = GameInfo.OrbitalUnits[orbitalUnitType].StationTradeYieldMod;
		end
	end

	local yieldStrings = {};
	local nextLevel = station:GetLevel() + 1;
	local yieldTable = SubTableByIndexClamped(nextLevel, allYieldsTable);

	for type, yield in pairs(yieldTable) do		
		yield = yield + ((yield * yieldMod) / 100);
		local yieldString = GetYieldValueString(type, yield, false);
		table.insert(yieldStrings, yieldString);
	end

	if (#yieldStrings == 1) then
		return Locale.ConvertTextKey("TXT_KEY_STATION_NEXT_LEVEL_MESSAGE_ONE_YIELD", nextLevel, station:GetNameKey(), yieldStrings[1]);
	elseif (#yieldStrings == 2) then
		return Locale.ConvertTextKey("TXT_KEY_STATION_NEXT_LEVEL_MESSAGE_TWO_YIELDS", nextLevel, station:GetNameKey(), yieldStrings[1], yieldStrings[2]);
	elseif (#yieldStrings == 3) then
		return Locale.ConvertTextKey("TXT_KEY_STATION_NEXT_LEVEL_MESSAGE_THREE_YIELDS", nextLevel, station:GetNameKey(), yieldStrings[1], yieldStrings[2], yieldStrings[3]);
	else
		return "NUM YIELDS UNHANDLED"
	end
end

function GenericMilitaryUnitRewardString(unitInfo, numUnits)
	if (numUnits == 1) then
		return Locale.ConvertTextKey("TXT_KEY_REWARD_MILITARY_UNIT", numUnits, unitInfo.Description);
	elseif (numUnits > 1) then
		return Locale.ConvertTextKey("TXT_KEY_REWARD_MILITARY_UNIT_PLURAL", numUnits, unitInfo.Description);
	else
		return "NUM UNITS UNHANDLED"
	end
end

----------------------------------------------------------------        
-- String Management
---------------------------------------------------------------- 
function GenericYieldStationTradeSummary(station, allYieldsTable)

	local summary = "";
	local yieldTable = SubTableByIndexClamped(station:GetLevel(), allYieldsTable);

	for type, yield in pairs(yieldTable) do
		local yieldString = GetYieldValueString(type, yield, true);
		summary = summary .. "[ICON_ARROW_LEFT] " .. yieldString .. "[NEWLINE]";
	end

	return summary;
end

-- Assumes that masterTable is a table of tables indexed by integer, so that the function can select
-- the one that corresponds to the station's current level. If the index provided is greater
-- than the table size, returns the last element
function SubTableByIndexClamped(index, masterTable)

	if (index < 1) then
		index = 1;
	elseif (index > #masterTable) then
		index = #masterTable;
	end

	return masterTable[index];
end