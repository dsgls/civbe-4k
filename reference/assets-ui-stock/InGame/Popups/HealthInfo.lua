-------------------------------------------------
-- Health Info
-------------------------------------------------
include( "InstanceManager" );

Controls.TradeRouteStack:SetHide( true );
Controls.CityHealthStack:SetHide( true );
Controls.CityUnhealthStack:SetHide( true );

-------------------------------------------------
-------------------------------------------------
function OnTradeRouteToggle()
    local bWasHidden = Controls.TradeRouteStack:IsHidden();
    Controls.TradeRouteStack:SetHide( not bWasHidden );
    if( bWasHidden ) then
        Controls.TradeRouteToggle:LocalizeAndSetText("TXT_KEY_EO_TRADE_ROUTES_COLLAPSE");
    else
        Controls.TradeRouteToggle:LocalizeAndSetText("TXT_KEY_EO_TRADE_ROUTES");
    end
    Controls.HealthStack:CalculateSize();
    Controls.HealthStack:ReprocessAnchoring();
    Controls.HealthScroll:CalculateInternalSize();
end
Controls.TradeRouteToggle:RegisterCallback( Mouse.eLClick, OnTradeRouteToggle );

---------------------------------------------------
---------------------------------------------------
function OnCityHealthToggle()
    local bWasHidden = Controls.CityHealthStack:IsHidden();
    Controls.CityHealthStack:SetHide( not bWasHidden );
    if( bWasHidden ) then
        Controls.CityHealthToggle:LocalizeAndSetText("TXT_KEY_EO_CITY_BREAKDOWN_COLLAPSE");
    else
        Controls.CityHealthToggle:LocalizeAndSetText("TXT_KEY_EO_CITY_BREAKDOWN");
    end
    Controls.HealthStack:CalculateSize();
    Controls.HealthStack:ReprocessAnchoring();
    Controls.HealthScroll:CalculateInternalSize();
end
Controls.CityHealthToggle:RegisterCallback( Mouse.eLClick, OnCityHealthToggle );

-------------------------------------------------
-------------------------------------------------
function OnCityUnhealthToggle()
    local bWasHidden = Controls.CityUnhealthStack:IsHidden();
    Controls.CityUnhealthStack:SetHide( not bWasHidden );
    if( bWasHidden ) then
        Controls.CityUnhealthToggle:LocalizeAndSetText("TXT_KEY_EO_CITY_BREAKDOWN_COLLAPSE");
    else
        Controls.CityUnhealthToggle:LocalizeAndSetText("TXT_KEY_EO_CITY_BREAKDOWN");
    end
    Controls.UnhealthStack:CalculateSize();
    Controls.UnhealthStack:ReprocessAnchoring();
    Controls.UnhealthScroll:CalculateInternalSize();
end
Controls.CityUnhealthToggle:RegisterCallback( Mouse.eLClick, OnCityUnhealthToggle );

-------------------------------------------------
-------------------------------------------------
--function OnResourcesAvailableToggle()
    --local bWasHidden = Controls.ResourcesAvailableStack:IsHidden();
    --Controls.ResourcesAvailableStack:SetHide( not bWasHidden );
    --local strString = Locale.ConvertTextKey("TXT_KEY_EO_RESOURCES_AVAILBLE");
    --if( bWasHidden ) then
        --Controls.ResourcesAvailableToggle:SetText("[ICON_MINUS]" .. strString);
    --else
        --Controls.ResourcesAvailableToggle:SetText("[ICON_PLUS]" .. strString);
    --end
    --Controls.ResourcesStack:CalculateSize();
    --Controls.ResourcesStack:ReprocessAnchoring();
    --Controls.ResourcesScroll:CalculateInternalSize();
--end
--Controls.ResourcesAvailableToggle:RegisterCallback( Mouse.eLClick, OnResourcesAvailableToggle );
--
---------------------------------------------------
---------------------------------------------------
--function OnResourcesImportedToggle()
    --local bWasHidden = Controls.ResourcesImportedStack:IsHidden();
    --Controls.ResourcesImportedStack:SetHide( not bWasHidden );
    --local strString = Locale.ConvertTextKey("TXT_KEY_RESOURCES_IMPORTED");
    --if( bWasHidden ) then
        --Controls.ResourcesImportedToggle:SetText("[ICON_MINUS]" .. strString);
    --else
        --Controls.ResourcesImportedToggle:SetText("[ICON_PLUS]" .. strString);
    --end
    --Controls.ResourcesStack:CalculateSize();
    --Controls.ResourcesStack:ReprocessAnchoring();
    --Controls.ResourcesScroll:CalculateInternalSize();
--end
--Controls.ResourcesImportedToggle:RegisterCallback( Mouse.eLClick, OnResourcesImportedToggle );
--
---------------------------------------------------
---------------------------------------------------
--function OnResourcesExportedToggle()
    --local bWasHidden = Controls.ResourcesExportedStack:IsHidden();
    --Controls.ResourcesExportedStack:SetHide( not bWasHidden );
    --local strString = Locale.ConvertTextKey("TXT_KEY_RESOURCES_EXPORTED");
    --if( bWasHidden ) then
        --Controls.ResourcesExportedToggle:SetText("[ICON_MINUS]" .. strString);
    --else
        --Controls.ResourcesExportedToggle:SetText("[ICON_PLUS]" .. strString);
    --end
    --Controls.ResourcesStack:CalculateSize();
    --Controls.ResourcesStack:ReprocessAnchoring();
    --Controls.ResourcesScroll:CalculateInternalSize();
--end
--Controls.ResourcesExportedToggle:RegisterCallback( Mouse.eLClick, OnResourcesExportedToggle );
--
---------------------------------------------------
---------------------------------------------------
----function OnResourcesLocalToggle()
    ----local bWasHidden = Controls.ResourcesLocalStack:IsHidden();
    ----Controls.ResourcesLocalStack:SetHide( not bWasHidden );
    ----local strString = Locale.ConvertTextKey("TXT_KEY_EO_LOCAL_RESOURCES");
    ----if( bWasHidden ) then
        ----Controls.ResourcesLocalToggle:SetText("[ICON_MINUS]" .. strString);
    ----else
        ----Controls.ResourcesLocalToggle:SetText("[ICON_PLUS]" .. strString);
    ----end
    ----Controls.ResourcesStack:CalculateSize();
    ----Controls.ResourcesStack:ReprocessAnchoring();
    ----Controls.ResourcesScroll:CalculateInternalSize();
----end
----Controls.ResourcesLocalToggle:RegisterCallback( Mouse.eLClick, OnResourcesLocalToggle );

---------------------------------------------------
---------------------------------------------------
--function OnResourceToggle(instance)
--
    --local bWasHidden = instance.ResourceEntryLocalStack:IsHidden();
    --instance.ResourceEntryLocalStack:SetHide( not bWasHidden );
--
	--instance.ResourceEntryLocalStack:DestroyAllChildren();
    --if( bWasHidden ) then
		--
		--local iPlayerID = Game.GetActivePlayer();
		--local pPlayer = Players[iPlayerID];
--
		--local totalInstance = {};
		--ContextPtr:BuildInstanceForControl( "TradeEntry", totalInstance, instance.ResourceEntryLocalStack );	    
		--local iNumTotal = pPlayer:GetNumResourceTotal(instance.ResourceID, false);
		--totalInstance.CityName:SetText( "Total" );
		--totalInstance.TradeIncomeValue:SetText( iNumTotal );
--
		--local importInstance = {};
		--ContextPtr:BuildInstanceForControl( "TradeEntry", importInstance, instance.ResourceEntryLocalStack );
		--local iNumImported = pPlayer:GetResourceImport(instance.ResourceID);
		--importInstance.CityName:SetText( "Imported" );		
		--importInstance.TradeIncomeValue:SetText( iNumImported );
--
		--local exportInstance = {};
		--ContextPtr:BuildInstanceForControl( "TradeEntry", exportInstance, instance.ResourceEntryLocalStack );
		--local iNumExported = pPlayer:GetResourceExport(instance.ResourceID);    
		--exportInstance.CityName:SetText( "Exported" );		
		--exportInstance.TradeIncomeValue:SetText( iNumExported );
--
		--instance.ResourceEntryToggle:SetText("[ICON_MINUS]");
    --else
		--instance.ResourceEntryToggle:SetText("[ICON_PLUS]");
    --end
--
	--instance.ResourceEntryLocalStack:CalculateSize();
	--instance.ResourceEntryLocalStack:ReprocessAnchoring();
--
    --Controls.ResourcesStack:CalculateSize();
    --Controls.ResourcesStack:ReprocessAnchoring();
    --Controls.ResourcesScroll:CalculateInternalSize();
--end

-------------------------------------------------
-------------------------------------------------
function UpdateScreen()

	local iPlayerID = Game.GetActivePlayer();
    local pPlayer = Players[iPlayerID];
	local pTeam = Teams[pPlayer:GetTeam()];
	local pCity = UI.GetHeadSelectedCity();
    
    local iHandicap = Players[Game.GetActivePlayer()]:GetHandicapType();
	local pHandicapInfo = GameInfo.HandicapInfos[iHandicap];

	-----------------------------------------------
	-- Health
	-----------------------------------------------
	
	Controls.TotalHealthValue:SetText("[COLOR_POSITIVE_TEXT]" .. pPlayer:GetHealth() .. "[ENDCOLOR]");
	
	local iVirtuesHealth		= pPlayer:GetHealthFromPolicies();
	local iCityHealth			= pPlayer:GetHealthFromCities();
	local iTradeRouteHealth		= pPlayer:GetHealthFromTradeRoutes();
	local iExtraHealthPerCity	= pPlayer:GetExtraHealthPerCity() * pPlayer:GetNumCities();	
	local iHandicapHealth		= pHandicapInfo.BaseHealthRate;
	
	-- Trade Routes
	
	if (iTradeRouteHealth ~= 0) then
		Controls.TradeRouteStack:DestroyAllChildren();
		for pCity in pPlayer:Cities() do
		    
		    -- Capitals cannot be connected to themselves
		    if (not pCity:IsCapital()) then
			    
			    local strTradeConnection = "-";
			    
				if (pPlayer:IsCapitalConnectedToCity(pCity)) then
					strTradeConnection = pPlayer:GetHealthPerTradeRoute() / 100;
				end
				
				local instance = {};
				ContextPtr:BuildInstanceForControl( "TradeEntry", instance, Controls.TradeRouteStack );
		        
				instance.CityName:SetText( pCity:GetName() );
				instance.TradeIncomeValue:SetText( strTradeConnection );
			end
		end
		
		Controls.TradeRouteValue:SetText(iTradeRouteHealth);
	end
    
    if( iTradeRouteHealth > 0 ) then
        Controls.TradeRouteToggle:SetHide( false );
    else
        Controls.TradeRouteToggle:SetHide( true );
    end
    Controls.TradeRouteStack:CalculateSize();
    Controls.TradeRouteStack:ReprocessAnchoring();
	
	-- LocalCityHealth
	Controls.LocalCityHealthTitle:SetText(Locale.Lookup("TXT_KEY_EO_LOCAL_CITY"));
	Controls.LocalCityHealthValue:SetText(iCityHealth);

	if (iCityHealth > 0) then
		Controls.CityHealthStack:DestroyAllChildren();
		for pCity in pPlayer:Cities() do
		    
		    local strLocalCity = "-";
		    
			if (pCity:GetLocalHealth() > 0) then
				strLocalCity = pCity:GetLocalHealth();
			end
			
			local instance = {};
			ContextPtr:BuildInstanceForControl( "TradeEntry", instance, Controls.CityHealthStack );
	        
			instance.CityName:SetText( pCity:GetName() );
			instance.TradeIncomeValue:SetText( strLocalCity );
		end
	end

	if( pPlayer:GetNumCities() > 0 ) then
        Controls.CityHealthToggle:SetDisabled( false );
        Controls.CityHealthToggle:SetAlpha( 1.0 );
    else
        Controls.CityHealthToggle:SetDisabled( true );
        Controls.CityHealthToggle:SetAlpha( 0.5 );
    end
    Controls.CityHealthStack:CalculateSize();
    Controls.CityHealthStack:ReprocessAnchoring();

	-- Virtues
	Controls.VirtuesHealthValue:SetText(iVirtuesHealth);
	
	-- Free Health per City
	if (iExtraHealthPerCity > 0) then
		Controls.FreeCityHealthValue:SetText(iExtraHealthPerCity);
		Controls.FreeCityHealth:SetHide(false);
	else
		Controls.FreeCityHealth:SetHide(true);
	end
	
	-- iHandicapHealth
	Controls.HandicapHealthValue:SetText(iHandicapHealth);

	Controls.HealthStack:CalculateSize();
	Controls.HealthStack:ReprocessAnchoring();
	Controls.HealthScroll:CalculateInternalSize();

	-----------------------------------------------
	-- Unhealth
	-----------------------------------------------
	
	local pHandicap = GameInfo.HandicapInfos[iHandicap];
	
	local iTotalUnhealth = Locale.ToNumber( pPlayer:GetUnhealthTimes100() / 100, "#.##" );
	local iUnhealthFromUnits = Locale.ToNumber( pPlayer:GetUnhealthFromUnits() / 100, "#.##" );
	local iUnhealthFromCityCount = Locale.ToNumber( pPlayer:GetUnhealthFromCityCount() / 100, "#.##" );
	local iUnhealthFromConqueredCityCount = Locale.ToNumber( pPlayer:GetUnhealthFromConqueredCityCount() / 100, "#.##" );
	local iUnhealthFromPop = Locale.ToNumber( pPlayer:GetUnhealthFromCityPopulation() / 100, "#.##" );
	local iUnhealthFromConqueredCities = Locale.ToNumber( pPlayer:GetUnhealthFromConqueredCities() / 100, "#.##" );
	
	local iOccupiedPop = 0;
	local iNumResistanceCities = 0;
	for pCity in pPlayer:Cities() do
		if (pCity:IsResistance()) then
			iNumResistanceCities = iNumResistanceCities + 1;
			iOccupiedPop = iOccupiedPop + pCity:GetPopulation();
		end
	end
	
	local iNumNormalCities = pPlayer:GetNumCities() - iNumResistanceCities;
	local iNormalPop = pPlayer:GetTotalPopulation() - iOccupiedPop;
	
	-- Total Unhealth
	Controls.TotalUnhealthValue:SetText("[COLOR_NEGATIVE_TEXT]" .. iTotalUnhealth .. "[ENDCOLOR]");
	local iUnhealthMod = pPlayer:GetUnhealthMod();		-- Player Mod
	if (iUnhealthMod ~= 0) then
		Controls.TotalUnhealthValue:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_PLAYER", iUnhealthMod));
	end
	
	-- Normal City Count
	Controls.CityCountUnhealthTitle:SetText(Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_CITIES", iNumNormalCities));
	Controls.CityCountUnhealthValue:SetText(iUnhealthFromCityCount);
	
	local strTTExtraInfo = "";
	
	local iCityCountMod = pHandicap.NumCitiesUnhealthMod;	-- Handicap
	if (iCityCountMod ~= 100) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_CITIES_HANDICAP_TT", 100 - iCityCountMod);
	end
	
	iCityCountMod = pPlayer:GetCityCountUnhealthMod();		-- Player Mod
	if (iCityCountMod ~= 0) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_PLAYER", iCityCountMod);
	end
	
	iCityCountMod = pPlayer:GetTraitCityUnhealthMod();		-- Trait Mod
	if (iCityCountMod ~= 0) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_TRAIT", iCityCountMod);
	end
	
	local iCityCountMod = Game:GetWorldNumCitiesUnhealthPercent();	-- World Size
	if (iCityCountMod ~= 100) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_MAP", 100 - iCityCountMod);
	end
	
	local strTooltip;
	if (strTTExtraInfo~= "") then
		strTooltip = Locale.Lookup("TXT_KEY_NUMBER_OF_CITIES_TT_NORMALLY", GameDefines.UNHEALTH_PER_CITY) .. strTTExtraInfo;
	else
		strTooltip = Locale.Lookup("TXT_KEY_NUMBER_OF_CITIES_TT", GameDefines.UNHEALTH_PER_CITY);
	end
	
	Controls.CityCountUnhealth:SetToolTipString(strTooltip);
	
	-- Occupied City Count
	if (iUnhealthFromConqueredCityCount ~= "0") then
		Controls.OCityCountUnhealthTitle:SetText(Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_OCCUPIED_CITIES", iNumResistanceCities));
		Controls.OCityCountUnhealthValue:SetText(iUnhealthFromConqueredCityCount);
		
		strTooltip = Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_OCCUPIED_CITIES_TT", GameDefines.UNHEALTH_PER_CAPTURED_CITY);
		strTTExtraInfo = "";
		
		local iCityCountMod = pHandicap.NumCitiesUnhealthMod;	-- Handicap
		if (iCityCountMod ~= 100) then
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_CITIES_HANDICAP_TT", 100 - iCityCountMod);
		end
		
		iCityCountMod = pPlayer:GetCityCountUnhealthMod();		-- Player Mod
		if (iCityCountMod ~= 0) then
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_PLAYER", iCityCountMod);
		end
		
		iCityCountMod = pPlayer:GetTraitCityUnhealthMod();		-- Trait Mod
		if (iCityCountMod ~= 0) then
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_TRAIT", iCityCountMod);
		end
		
		local iCityCountMod = Game:GetWorldNumCitiesUnhealthPercent();	-- World Size
		if (iCityCountMod ~= 100) then
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_MAP", 100 - iCityCountMod);
		end
		
		if (strTTExtraInfo~= "") then
			strTooltip = strTooltip .. " " .. Locale.ConvertTextKey("TXT_KEY_NORMALLY") .. "." .. strTTExtraInfo;
		else
			strTooltip = strTooltip .. ".";
		end
			
		Controls.OCityCountUnhealth:SetToolTipString(strTooltip);
		Controls.OCityCountUnhealth:SetHide(false);
	else
		Controls.OCityCountUnhealth:SetHide(true);
	end
	
	-- Normal Population
	Controls.PopulationUnhealthTitle:SetText(Locale.ConvertTextKey("TXT_KEY_POP_UNHEALTH", iNormalPop));
	Controls.PopulationUnhealthValue:SetText(iUnhealthFromPop);
	
	strTooltip = Locale.ConvertTextKey("TXT_KEY_POP_UNHEALTH_TT", GameDefines.UNHEALTH_PER_POPULATION);
	strTTExtraInfo = "";
	
	local iPopulationMod = pHandicap.PopulationUnhealthMod;	-- Handicap
	if (iPopulationMod ~= 100) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_CITIES_HANDICAP_TT", 100 - iPopulationMod);
	end
	
	iCityCountMod = pPlayer:GetTraitPopUnhealthMod();		-- Trait Mod
	if (iCityCountMod ~= 0) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_TRAIT", iCityCountMod);
	end
	
	iCityCountMod = pPlayer:GetCapitalUnhealthMod();		-- Capital Mod
	if (iCityCountMod ~= 0) then
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_CAPITAL", iCityCountMod);
	end
	
	if (pPlayer:IsHalfSpecialistUnhealth()) then		-- Specialist Health
		strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_SPECIALIST");
	end
	
	if (strTTExtraInfo ~= "") then
		strTooltip = strTooltip .. " " .. Locale.ConvertTextKey("TXT_KEY_NORMALLY") .. "." .. strTTExtraInfo;
	else
		strTooltip = strTooltip .. ".";
	end
	
	Controls.PopulationUnhealth:SetToolTipString(strTooltip);
	
	-- Occupied City Count
	if (iOccupiedPop ~= 0) then
		Controls.OPopulationUnhealthTitle:SetText(Locale.ConvertTextKey("TXT_KEY_OCCUPIED_POP_UNHEALTH", iOccupiedPop));
		Controls.OPopulationUnhealthValue:SetText(iUnhealthFromConqueredCities);
		
		strTooltip = Locale.ConvertTextKey("TXT_KEY_OCCUPIED_POP_UNHEALTH_TT");
		strTTExtraInfo = "";
		
		if (iPopulationMod ~= 100) then		-- Handicap
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUMBER_OF_CITIES_HANDICAP_TT", 100 - iPopulationMod);
		end
		
		iCityCountMod = pPlayer:GetOccupiedPopulationUnhealthMod();		-- Player Mod
		if (iCityCountMod ~= 0) then
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_PLAYER", iCityCountMod);
		end
		
		if (pPlayer:IsHalfSpecialistUnhealth()) then		-- Specialist Health
			strTTExtraInfo = strTTExtraInfo .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_UNHEALTH_MOD_SPECIALIST");
		end
		
		if (strTTExtraInfo ~= "") then
			strTooltip = strTooltip .. " " .. Locale.ConvertTextKey("TXT_KEY_NORMALLY") .. "." .. strTTExtraInfo;
		else
			strTooltip = strTooltip .. ".";
		end
		
		Controls.OPopulationUnhealth:SetToolTipString(strTooltip);
		Controls.OPopulationUnhealth:SetHide(false);
	else
		Controls.OPopulationUnhealth:SetHide(true);
	end
	
	-- City Breakdown
    Controls.CityUnhealthStack:DestroyAllChildren();
    for pCity in pPlayer:Cities() do
	    
		-- OLD METHOD don't use
	    --local fUnhealthTimes100 = pPlayer:GetUnhealthFromCityForUI(pCity);

		local cityUnhealth = pCity:GetLocalUnhealth();
		
		local instance = {};
		ContextPtr:BuildInstanceForControl( "TradeEntry", instance, Controls.CityUnhealthStack );
        
        -- Make it a dash instead of a zero, so it stands out more
        if (cityUnhealth == 0) then
			cityUnhealth = "-";
		else
			cityUnhealth = Locale.ToNumber(cityUnhealth / 100, "#.##" )
        end
        
        instance.CityName:SetText(pCity:GetName());
		instance.TradeIncomeValue:SetText(cityUnhealth);
		
		-- Occupation tooltip
		strOccupationTT = "";
		if (pCity:IsResistance()) then
			strOccupationTT = Locale.ConvertTextKey("TXT_KEY_EO_CITY_IS_OCCUPIED");
		end
		
		instance.TradeIncome:SetToolTipString(strOccupationTT);
	end
    
    if( pPlayer:GetNumCities() > 0 ) then
        Controls.CityUnhealthToggle:SetDisabled( false );
        Controls.CityUnhealthToggle:SetAlpha( 1.0 );
    else
        Controls.CityUnhealthToggle:SetDisabled( true );
        Controls.CityUnhealthToggle:SetAlpha( 0.5 );
    end
    Controls.CityUnhealthStack:CalculateSize();
    Controls.CityUnhealthStack:ReprocessAnchoring();



	-----------------------------------------------
	-- Resources
	-----------------------------------------------
	
	Controls.ResourcesStack:DestroyAllChildren();

	for pResource in GameInfo.Resources() do
		local iResourceID = pResource.ID;
		local iNum = pPlayer:GetNumResourceTotal(iResourceID, true);
		
		-- Only Strategic Resources
		if (Game.GetResourceClassType(iResourceID) == GameInfo.ResourceClasses["RESOURCECLASS_STRATEGIC"].ID) then
				
			local instance = {};
			ContextPtr:BuildInstanceForControl( "ResourceEntry", instance, Controls.ResourcesStack );
		        
			instance.ResourceName:SetText( Locale.Lookup(pResource.IconString) .. Locale.ConvertTextKey(pResource.Description) );
			instance.ResourceValue:SetText( iNum );
			instance.ResourceID = iResourceID;
			
			if iNum == 0 then
				-- Make it a dash instead of a zero, so it stands out more
				instance.ResourceValue:SetText("-");
			end
		end
	end

	---- Resources Available
	--
    --Controls.ResourcesAvailableToggle:SetText("[ICON_PLUS]" .. Locale.ConvertTextKey("TXT_KEY_EO_RESOURCES_AVAILBLE"));
	--
	--local iTotalNumResources = 0;
--
	--print("iTotalNumResources: " .. iTotalNumResources);
	--
    --Controls.ResourcesAvailableStack:DestroyAllChildren();
	--for pResource in GameInfo.Resources() do
		--local iResourceID = pResource.ID;
		--local iNum = pPlayer:GetNumResourceTotal(iResourceID, true);
		--
		---- Only Luxuries or Strategic Resources
		--if (Game.GetResourceClassType(iResourceID) == GameInfo.ResourceClasses["RESOURCECLASS_STRATEGIC"].ID) then
		----if (Game.GetResourceUsageType(iResourceID) ~= ResourceUsageTypes.RESOURCEUSAGE_BONUS) then
				--
			--iTotalNumResources = iTotalNumResources + 1;
				--
			--local instance = {};
			--ContextPtr:BuildInstanceForControl( "ResourceEntry", instance, Controls.ResourcesAvailableStack );
		        --
			---- Make it a dash instead of a zero, so it stands out more
			--if (iNum == 0) then
				--iNum = "-";
			--end
		        --
			--instance.ResourceName:SetText( Locale.ConvertTextKey(pResource.Description) );
			--instance.ResourceValue:SetText( iNum );
		--end
	--end
--
	--print("iTotalNumResources: " .. iTotalNumResources);
--
    --if ( iTotalNumResources > 0 ) then
        --Controls.ResourcesAvailableToggle:SetDisabled( false );
        --Controls.ResourcesAvailableToggle:SetAlpha( 1.0 );
    --else
        --Controls.ResourcesAvailableToggle:SetDisabled( true );
        --Controls.ResourcesAvailableToggle:SetAlpha( 0.5 );
    --end
    --Controls.ResourcesAvailableStack:CalculateSize();
    --Controls.ResourcesAvailableStack:ReprocessAnchoring();
	--
	---- Resources Imported
	--
    --Controls.ResourcesImportedToggle:SetText("[ICON_PLUS]" .. Locale.ConvertTextKey("TXT_KEY_RESOURCES_IMPORTED"));
	--
	--iTotalNumResources = 0;
	--
    --Controls.ResourcesImportedStack:DestroyAllChildren();
	--for pResource in GameInfo.Resources() do
		--local iResourceID = pResource.ID;
		--local iNum = pPlayer:GetResourceImport(iResourceID);
		--
		--if (iNum > 0) then
			---- Only Luxuries or Strategic Resources
			--if (Game.GetResourceUsageType(iResourceID) ~= ResourceUsageTypes.RESOURCEUSAGE_BONUS) then
				--
				--iTotalNumResources = iTotalNumResources + 1;
				--
				--local instance = {};
				--ContextPtr:BuildInstanceForControl( "ResourceEntry", instance, Controls.ResourcesImportedStack );
		        --
				---- Make it a dash instead of a zero, so it stands out more
				--if (iNum == 0) then
					--iNum = "-";
				--end
		        --
				--instance.ResourceName:SetText( Locale.ConvertTextKey(pResource.Description) );
				--instance.ResourceValue:SetText( iNum );
			--end
		--end
	--end
--
    --if ( iTotalNumResources > 0 ) then
        --Controls.ResourcesImportedToggle:SetDisabled( false );
        --Controls.ResourcesImportedToggle:SetAlpha( 1.0 );
    --else
        --Controls.ResourcesImportedToggle:SetDisabled( true );
        --Controls.ResourcesImportedToggle:SetAlpha( 0.5 );
    --end
    --Controls.ResourcesImportedStack:CalculateSize();
    --Controls.ResourcesImportedStack:ReprocessAnchoring();
	--
	--
	---- Resources Exported
	--
    --Controls.ResourcesExportedToggle:SetText("[ICON_PLUS]" .. Locale.ConvertTextKey("TXT_KEY_RESOURCES_EXPORTED"));
	--
	--iTotalNumResources = 0;
	--
    --Controls.ResourcesExportedStack:DestroyAllChildren();
	--for pResource in GameInfo.Resources() do
		--local iResourceID = pResource.ID;
		--local iNum = pPlayer:GetResourceExport(iResourceID);
		--
		--if (iNum > 0) then
			---- Only Luxuries or Strategic Resources
			--if (Game.GetResourceUsageType(iResourceID) ~= ResourceUsageTypes.RESOURCEUSAGE_BONUS) then
				--
				--iTotalNumResources = iTotalNumResources + 1;
				--
				--local instance = {};
				--ContextPtr:BuildInstanceForControl( "ResourceEntry", instance, Controls.ResourcesExportedStack );
		        --
				---- Make it a dash instead of a zero, so it stands out more
				--if (iNum == 0) then
					--iNum = "-";
				--end
		        --
				--instance.ResourceName:SetText( Locale.ConvertTextKey(pResource.Description) );
				--instance.ResourceValue:SetText( iNum );
			--end
		--end
	--end
--
    --if ( iTotalNumResources > 0 ) then
        --Controls.ResourcesExportedToggle:SetDisabled( false );
        --Controls.ResourcesExportedToggle:SetAlpha( 1.0 );
    --else
        --Controls.ResourcesExportedToggle:SetDisabled( true );
        --Controls.ResourcesExportedToggle:SetAlpha( 0.5 );
    --end
    --Controls.ResourcesExportedStack:CalculateSize();
    --Controls.ResourcesExportedStack:ReprocessAnchoring();
    --
	---- Resources Local
	--
    --Controls.ResourcesLocalToggle:SetText("[ICON_PLUS]" .. Locale.ConvertTextKey("TXT_KEY_EO_LOCAL_RESOURCES"));
	--
	--iTotalNumResources = 0;
	--
    --Controls.ResourcesLocalStack:DestroyAllChildren();
	--for pResource in GameInfo.Resources() do
		--local iResourceID = pResource.ID;
		--local iNum = pPlayer:GetNumResourceTotal(iResourceID, false) + pPlayer:GetResourceExport(iResourceID);
		--
		--if (iNum > 0) then
			---- Only Luxuries or Strategic Resources
			--if (Game.GetResourceUsageType(iResourceID) ~= ResourceUsageTypes.RESOURCEUSAGE_BONUS) then
				--
				--iTotalNumResources = iTotalNumResources + 1;
				--
				--local instance = {};
				--ContextPtr:BuildInstanceForControl( "ResourceEntry", instance, Controls.ResourcesLocalStack );
		        --
				---- Make it a dash instead of a zero, so it stands out more
				--if (iNum == 0) then
					--iNum = "-";
				--end
		        --
				--instance.ResourceName:SetText( Locale.ConvertTextKey(pResource.Description) );
				--instance.ResourceValue:SetText( iNum );
			--end
		--end
	--end
--
    --if ( iTotalNumResources > 0 ) then
        --Controls.ResourcesLocalToggle:SetDisabled( false );
        --Controls.ResourcesLocalToggle:SetAlpha( 1.0 );
    --else
        --Controls.ResourcesLocalToggle:SetDisabled( true );
        --Controls.ResourcesLocalToggle:SetAlpha( 0.5 );
    --end
    --Controls.ResourcesLocalStack:CalculateSize();
    --Controls.ResourcesLocalStack:ReprocessAnchoring();
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )
    if( not bIsHide ) then
    	UpdateScreen();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );