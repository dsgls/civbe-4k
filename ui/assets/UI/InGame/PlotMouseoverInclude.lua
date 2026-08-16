include( "SupportFunctions"  );

-------------------------------------------------
-------------------------------------------------
function GetCivStateQuestString(plot, bShortVersion)
	local resultStr = "";
	local iActivePlayer = Game.GetActivePlayer();
	local iActiveTeam = Game.GetActiveTeam();
	local pTeam = Teams[iActiveTeam];
	
	for iPlayerLoop = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS-1, 1 do	
		pOtherPlayer = Players[iPlayerLoop];
		iOtherTeam = pOtherPlayer:GetTeam();
			
		if( pOtherPlayer:IsMinorCiv() and iActiveTeam ~= iOtherTeam and pOtherPlayer:IsAlive() and pTeam:IsHasMet( iOtherTeam ) ) then
			
			-- Does the player have a quest to kill a barb camp here?
			if (pOtherPlayer:IsMinorCivDisplayedQuestForPlayer(iActivePlayer, MinorCivQuestTypes.MINOR_CIV_QUEST_KILL_CAMP)) then
				local iQuestData1 = pOtherPlayer:GetQuestData1(iActivePlayer, MinorCivQuestTypes.MINOR_CIV_QUEST_KILL_CAMP);
				local iQuestData2 = pOtherPlayer:GetQuestData2(iActivePlayer, MinorCivQuestTypes.MINOR_CIV_QUEST_KILL_CAMP);
				if (iQuestData1 == plot:GetX() and iQuestData2 == plot:GetY()) then
					if (bShortVersion) then
						resultStr =  "[COLOR_POSITIVE_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_CITY_STATE_BARB_QUEST_SHORT") .. "[ENDCOLOR]";
					else
						if (resultStr ~= "") then
							resultStr = resultStr .. "[NEWLINE]";
						end
						
						resultStr = resultStr .. "[COLOR_POSITIVE_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_CITY_STATE_BARB_QUEST_LONG",  pOtherPlayer:GetCivilizationShortDescriptionKey()) .. "[ENDCOLOR]";
					end
				end
			end
			
		end
	end		
	
	return resultStr;
end

-------------------------------------------------
-------------------------------------------------
function GetNatureString(plot)
	
	local natureStr = "";
	
	local bFirst = true;
	
	local iFeature = plot:GetFeatureType();
	
	-- Some Features are handled in a special manner, since they always have the same terrain type under it
	if (IsFeatureSpecial(iFeature)) then
		if (bFirst) then
			bFirst = false;
		else
			natureStr = natureStr .. ", ";
		end
		
		local convertedKey = Locale.ConvertTextKey( GameInfo.Features[plot:GetFeatureType()].Description);
		natureStr = natureStr .. convertedKey;
		
	-- Not a jungle
	else
		
		local bMountain = false;
		
		-- Feature
		if (iFeature > -1) then
			if (bFirst) then
				bFirst = false;
			else
				natureStr = natureStr .. ", ";
			end
			
			local convertedKey = Locale.ConvertTextKey( GameInfo.Features[plot:GetFeatureType()].Description);
			natureStr = natureStr .. convertedKey;
			
		-- No Feature
		else
			
			-- Mountain
			if (plot:IsMountain()) then
				if (bFirst) then
					bFirst = false;
				else
					natureStr = natureStr .. ", ";
				end
				
				bMountain = true;
				
				natureStr = natureStr .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_MOUNTAIN" );

			-- Canyon
			elseif (plot:IsCanyon()) then
				if (bFirst) then
					bFirst = false;
				else
					natureStr = natureStr .. ", ";
				end
				
				bMountain = true;
				
				natureStr = natureStr .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_CANYON" );
			end
			
		end
			
		-- Terrain
		if (not bMountain) then
			if (bFirst) then
				bFirst = false;
			else
				natureStr = natureStr .. ", ";
			end
			
			local convertedKey;
			
			-- Lake?
			if (plot:IsLake()) then
				convertedKey = Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_LAKE" );
			else
				convertedKey = Locale.ConvertTextKey(GameInfo.Terrains[plot:GetTerrainType()].Description);		
			end
			
			natureStr = natureStr .. convertedKey;
		end
	end	-- End Feature hack
	
	-- Hills
	if (plot:IsHills()) then
		if (bFirst) then
			bFirst = false;
		else
			natureStr = natureStr .. ", ";
		end
		
		natureStr = natureStr .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_HILL" );
	end

	-- River
	if (plot:IsRiver()) then
		if (bFirst) then
			bFirst = false;
		else
			natureStr = natureStr .. ", ";
		end
		
		natureStr = natureStr .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_RIVER" );
	end

	-- Miasma
	if (plot:HasMiasma()) then
		if (bFirst) then
			bFirst = false;
		else
			natureStr = natureStr .. ", ";
		end
		
		local convertedKey = Locale.ConvertTextKey( GameInfo.Features[FeatureTypes.FEATURE_MIASMA].Description);
		natureStr = natureStr .. convertedKey;
	end
	
	return natureStr;
end


-------------------------------------------------
-------------------------------------------------
function IsFeatureSpecial(iFeature)
	

	if (iFeature == GameInfoTypes["FEATURE_MARSH"]) then
		return true;
	elseif (iFeature == GameInfoTypes["FEATURE_ICE"]) then
		return true;
	end
	
	return false;
	
end


-------------------------------------------------
-------------------------------------------------
function GetResourceString(plot, bLongForm)

	local improvementStr = "";
	
	local iActiveTeam = Game.GetActiveTeam();
	local pTeam = Teams[iActiveTeam];
	
	if (plot:GetResourceType(iActiveTeam) >= 0) then
		local resourceType = plot:GetResourceType(iActiveTeam);
		local pResource = GameInfo.Resources[resourceType];
		
		-- Don't show quest artifacts if there's already a (quest) improvement here
		if (not (plot:HasImprovement() and pResource.ResourceClassType == "RESOURCECLASS_QUEST_ARTIFACT")) then
			if (plot:GetNumResource() > 1) then
				improvementStr = improvementStr .. plot:GetNumResource() .. " ";
			end
		
			local convertedKey = Locale.ConvertTextKey(pResource.Description);		
			improvementStr = improvementStr .. pResource.IconString .. " " .. convertedKey;
		
			-- Resource Hookup info
			--local iTechCityTrade = GameInfoTypes[pResource.TechCityTrade];
			--if (iTechCityTrade ~= nil) then
			--	if (iTechCityTrade ~= -1 and not pTeam:GetTeamTechs():HasTech(iTechCityTrade)) then
			--
			--		local techName = GameInfo.Technologies[iTechCityTrade].Description;
			--		if (bLongForm) then
			--			improvementStr = improvementStr .. " " .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_REQUIRES_TECH_TO_USE", techName );
			--		else
			--			improvementStr = improvementStr .. " " .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_REQUIRES_TECH", techName );
			--		end
			--	end
			--end
		end
	end
	
	return improvementStr;
	
end


-------------------------------------------------
-------------------------------------------------
function GetImprovementString(plot)

	local improvementStr = "";
	
	local iActiveTeam = Game.GetActiveTeam();
	local pTeam = Teams[iActiveTeam];

	local iImprovementType = plot:GetRevealedImprovementType(iActiveTeam, bIsDebug);
	if (iImprovementType >= 0) then
		if (improvementStr ~= "") then
			improvementStr = improvementStr .. ", ";
		end
		local convertedKey = Locale.ConvertTextKey(GameInfo.Improvements[iImprovementType].Description);		
		improvementStr = improvementStr .. convertedKey;
		if plot:IsImprovementPillaged() then
			improvementStr = improvementStr .." " .. Locale.ConvertTextKey("TXT_KEY_PLOTROLL_PILLAGED")
		end
	end

	local iRouteType = plot:GetRevealedRouteType(iActiveTeam, bIsDebug);
	if (iRouteType > -1) then
		if (improvementStr ~= "") then
			improvementStr = improvementStr .. ", ";
		end
		local convertedKey = Locale.ConvertTextKey(GameInfo.Routes[iRouteType].Description);		
		improvementStr = improvementStr .. convertedKey;
		--improvementStr = improvementStr .. "Road";
		
		if (plot:IsRoutePillaged()) then
			improvementStr = improvementStr .. " " .. Locale.ConvertTextKey("TXT_KEY_PLOTROLL_PILLAGED")
		end
	end
	
	return improvementStr;

end


-------------------------------------------------
-------------------------------------------------
function GetUnitsString(plot)

	local strUnitText = "";

	local iActiveTeam = Game.GetActiveTeam();
	local pTeam = Teams[iActiveTeam];
	local bIsDebug = Game.IsDebugMode();
	local bFirstEntry = true;

	local tUnits = {};
	local numUnits = plot:GetNumUnits();
	for i = 0, numUnits - 1 do
		local unit = plot:GetUnit(i);
		table.insert(tUnits, unit);
	end
	local influencingOrbitalUnit = plot:GetOrbitalUnitInfluencingPlot();
	if (influencingOrbitalUnit ~= nil) then
		table.insert(tUnits, influencingOrbitalUnit);
	end
	
	-- Loop through all units
	for i, unit in ipairs(tUnits) do
		if (unit ~= nil and not unit:IsInvisible(iActiveTeam, bIsDebug)) then

			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strUnitText = strUnitText .. "[NEWLINE]";
			end

			local strength = 0;
			strength = unit:GetCombatStrength();
		
			local pPlayer = Players[unit:GetOwner()];
			
			-- Player using nickname
			if (pPlayer:GetNickName() ~= nil and pPlayer:GetNickName() ~= "") then
				local MAX_NAME_CHARS= 20;
				local strNickName	= TruncateStringByLength(pPlayer:GetNickName(), MAX_NAME_CHARS);
				strUnitText = strUnitText .. Locale.ConvertTextKey("TXT_KEY_MULTIPLAYER_UNIT_TT", strNickName, pPlayer:GetCivilizationAdjectiveKey(), unit:GetNameKey());
			-- Use civ short description
			else
				if(unit:HasName()) then
					local desc = Locale.ConvertTextKey("TXT_KEY_PLOTROLL_UNIT_DESCRIPTION_CIV", unit:GetOwnerAdjectiveKey(), unit:GetNameKey());
					strUnitText = strUnitText .. string.format("%s (%s)", Locale.Lookup(unit:GetNameNoDesc()), desc); 
				else
					strUnitText = strUnitText .. Locale.ConvertTextKey("TXT_KEY_PLOTROLL_UNIT_DESCRIPTION_CIV", unit:GetOwnerAdjectiveKey(), unit:GetNameKey());
				end
			end
			
			local unitTeam = unit:GetTeam();
			if iActiveTeam == unitTeam then
				strUnitText = "[COLOR_WHITE]" .. strUnitText .. "[ENDCOLOR]";
			elseif pTeam:IsAtWar(unitTeam) then
				strUnitText = "[COLOR_NEGATIVE_TEXT]" .. strUnitText .. "[ENDCOLOR]";
			else
				strUnitText = "[COLOR_POSITIVE_TEXT]" .. strUnitText .. "[ENDCOLOR]";
			end
			
			-- Debug stuff
			if (OptionsManager:IsDebugMode()) then
				strUnitText = strUnitText .. " ("..tostring(unit:GetOwner()).." - " .. tostring(unit:GetID()) .. ")";
			end
			
			-- Combat strength
			if (strength > 0) then
				strUnitText = strUnitText .. ", [ICON_STRENGTH]" .. unit:GetCombatStrength();
			end
			
			-- Hit Points
			if (unit:GetDamage() > 0) then
				strUnitText = strUnitText .. ", " .. Locale.ConvertTextKey("TXT_KEY_PLOTROLL_UNIT_HP", GameDefines["MAX_HIT_POINTS"] - unit:GetDamage());
			end
			
			-- Embarked?
			if (unit:IsEmbarked()) then
				strUnitText = strUnitText .. ", " .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_EMBARKED" );
			end

			-- In Orbit?
			if (unit:IsInOrbit()) then
				strUnitText = strUnitText .. ", " .. "[COLOR_CYAN]" .. Locale.ConvertTextKey( "TXT_KEY_PLOTROLL_ORBITING" ) .. "[ENDCOLOR]";
			end
			
			-- Building something?
			--if (unit:GetBuildType() ~= -1) then
				--strUnitText = strUnitText .. ", " .. Locale.ConvertTextKey(GameInfo.Builds[unit:GetBuildType()].Description);
			--end
		end			
	end
	
	return strUnitText;
	
end


-------------------------------------------------
-------------------------------------------------
function GetOwnerString(plot)

	local strOwner = "";
	
	local iActiveTeam = Game.GetActiveTeam();
	local pTeam = Teams[iActiveTeam];
	local bIsDebug = Game.IsDebugMode();
	
	-- City here?
	if (plot:IsCity()) then
		
		local pCity = plot:GetPlotCity();
		if (pCity ~= nil) then
			local iCityOwner = pCity:GetOwner();
			local pCityOwner = Players[iCityOwner];
			if (pCityOwner ~= nil) then
				if (pCityOwner:IsMinorCiv()) then
					local strCivName = pCityOwner:GetCivilizationShortDescriptionKey();
					strOwner = Locale.ConvertTextKey("TXT_KEY_CITY_STATE_OF", strCivName);
				else
					local strAdjectiveKey = pCityOwner:GetCivilizationAdjectiveKey();
					local strCityName = pCity:GetName()
					strOwner = Locale.ConvertTextKey("TXT_KEY_CITY_OF", strAdjectiveKey, strCityName);
				end	
			end
		end
		
	-- No city, see if this plot is just owned
	else
		
		-- Plot owner
		local iOwner = plot:GetRevealedOwner(iActiveTeam, bIsDebug);
		
		if (iOwner >= 0) then
			local pPlayer = Players[iOwner];
			
			-- Player using nickname
			if (pPlayer:GetNickName() ~= nil and pPlayer:GetNickName() ~= "") then
				local MAX_NAME_CHARS= 20;
				local nickName = TruncateStringByLength(pPlayer:GetNickName(), MAX_NAME_CHARS);
				strOwner = Locale.ConvertTextKey("TXT_KEY_PLOTROLL_OWNED_PLAYER", nickName);
			-- Use civ short description
			else
				strOwner = Locale.ConvertTextKey("TXT_KEY_PLOTROLL_OWNED_CIV", pPlayer:GetCivilizationShortDescriptionKey());
			end
				local iActiveTeam = Game.GetActiveTeam();
				local plotTeam = pPlayer:GetTeam();
				if iActiveTeam == plotTeam then
					strOwner = "[COLOR_WHITE]" .. strOwner .. "[ENDCOLOR]";
				elseif pTeam:IsAtWar(plotTeam) then
					strOwner = "[COLOR_NEGATIVE_TEXT]" .. strOwner .. "[ENDCOLOR]";
				else
					strOwner = "[COLOR_POSITIVE_TEXT]" .. strOwner .. "[ENDCOLOR]";
				end
		end
	end


	
	return strOwner;

end


-------------------------------------------------
-------------------------------------------------
function GetYieldString(plot)

	local strYield = "";
	
	-- food
	local iNumFood = plot:CalculateYield(0, true);
	if (iNumFood > 0) then
		strYield = strYield .. "[ICON_FOOD] " .. iNumFood .. " ";
	end
	
	-- production
	local iNumProduction = plot:CalculateYield(1, true);
	if (iNumProduction > 0) then
		strYield = strYield .. "[ICON_PRODUCTION] " .. iNumProduction .. " ";
	end
	
	-- energy
	local iNumGold = plot:CalculateYield(2, true);
	if (iNumGold > 0) then
		strYield = strYield .. "[ICON_ENERGY] " .. iNumGold .. " ";
	end
	
	-- science
	local iNumScience = plot:CalculateYield(3, true);
	if (iNumScience > 0) then
		strYield = strYield .. "[ICON_RESEARCH] " .. iNumScience .. " ";
	end
	
    	-- culture	
	local iNumCulture = plot:CalculateYield(4, true);
	if (iNumCulture > 0) then
		strYield = strYield .. "[ICON_CULTURE] " .. iNumCulture .. " ";
	end
	
	-- Health (local to plot)
	local iHealth = plot:GetHealth();
	if (iHealth > 0) then
		strYield = strYield .. "[ICON_HEALTH_1] " .. iHealth .. " ";
	end
	
	return strYield;
end


-------------------------------------------------
-------------------------------------------------
function GetMaintenanceString(plot)

	local items = {};
	
	local iEnergyMaintenance = plot:GetPlotMaintenance(Game.GetActivePlayer());
	if iEnergyMaintenance > 0 then
		table.insert(items, "[ICON_ENERGY] " .. iEnergyMaintenance);		
	end

	local iUnhealth = plot:GetUnhealth();
	if (iUnhealth > 0) then
		table.insert(items, "[ICON_HEALTH_4] " .. iUnhealth);
	end

	local strText = "";
	if (#items > 0) then
		strText = "[COLOR_NEGATIVE_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_MAINTENANCE") .. "[ENDCOLOR]" .. " : ";
		strText = strText .. table.concat(items, " ");
	end

	return strText;
end


-------------------------------------------------
-------------------------------------------------
function GetInternationalTradeRouteString(plot)
	local strTradeRouteStr = "";
	local iActivePlayer = Game.GetActivePlayer();
	local astrTradeRouteStrings = Players[iActivePlayer]:GetInternationalTradeRoutePlotToolTip(plot);
		
	for i,v in ipairs(astrTradeRouteStrings) do	
		if (strTradeRouteStr == "") then
			strTradeRouteStr = strTradeRouteStr .. Locale.ConvertTextKey("TXT_KEY_TRADE_ROUTE_TT_PLOT_HEADING");
		else
			strTradeRouteStr = strTradeRouteStr .. "[NEWLINE]";
		end
	
		strTradeRouteStr = strTradeRouteStr .. v.String;
	end
	
	return strTradeRouteStr;
end