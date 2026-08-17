-- ===========================================================================
-- TopPanel.lua
-- ===========================================================================
include( "UIExtras" );
include( "InfoTooltipInclude" );

-- ===========================================================================
function UpdateData()

	local iPlayerID = Game.GetActivePlayer();

	local currentCargo = PreGame.GetLoadoutCargo(iPlayerID);
	local currentSpacecraft = PreGame.GetLoadoutSpacecraft(iPlayerID);
	local foo = GameInfo.Cargo[currentCargo];
	local bar = GameInfo.Spacecraft[currentSpacecraft];

	if( iPlayerID >= 0 ) then
		local pPlayer = Players[iPlayerID];
		local pTeam = Teams[pPlayer:GetTeam()];
		local pCity = UI.GetHeadSelectedCity();
		
		if (pPlayer:GetNumCities() > 0 or pPlayer:GetNumOutposts() > 0) then
			
			Controls.TopPanelInfoStack:SetHide(false);
			Controls.AffinityStack:SetHide(false);
			Controls.SciencePerTurn:SetHide(false);	
			Controls.EnergyPerTurn:SetHide(false);	
			Controls.HealthString:SetHide(false);	
			Controls.CultureString:SetHide(false);	
			Controls.ResourceString:SetHide(false);	
			
			if (pCity ~= nil and UI.IsCityScreenUp()) then		
				--Controls.MenuButton:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_RETURN")));
				Controls.MenuButton:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_SCREEN_EXIT_TOOLTIP"));
			else
				--Controls.MenuButton:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_MENU")));
				Controls.MenuButton:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_MENU_TOOLTIP"));
			end

			-----------------------------
			-- Update affinity status
			-----------------------------
			local purityText = Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS", GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].IconString, pPlayer:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID));
			local percentToNextPurityLevel = pPlayer:GetAffinityPercentTowardsNextLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID);
			if (pPlayer:GetAffinityPercentTowardsMaxLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID) >= 100) then
				percentToNextPurityLevel = 100;
			end
			Controls.PurityProgressBar:Resize(10,math.floor((percentToNextPurityLevel/100)*60));
			
			local harmonyText = Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS", GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].IconString, pPlayer:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID));
			local percentToNextHarmonyLevel = pPlayer:GetAffinityPercentTowardsNextLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID);
			if (pPlayer:GetAffinityPercentTowardsMaxLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID) >= 100) then
				percentToNextHarmonyLevel = 100;
			end
			Controls.HarmonyProgressBar:Resize(10,math.floor((percentToNextHarmonyLevel/100)*60));
			
			local supremacyText = Locale.ConvertTextKey("TXT_KEY_AFFINITY_STATUS", GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].IconString, pPlayer:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID));
			local percentToNextSupremacyLevel = pPlayer:GetAffinityPercentTowardsNextLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID);
			if (pPlayer:GetAffinityPercentTowardsMaxLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID) >= 100) then
				percentToNextSupremacyLevel = 100;
			end
			Controls.SupremacyProgressBar:Resize(10,math.floor((percentToNextSupremacyLevel/100)*60));

			Controls.Harmony	:SetText(harmonyText);
			Controls.Purity		:SetText(purityText);
			Controls.Supremacy	:SetText(supremacyText);

			-----------------------------
			-- Update science stats
			-----------------------------
			local strScienceText;
			
			if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
				strScienceText = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_SCIENCE_OFF");
			else
			
				local sciencePerTurn = pPlayer:GetScience();
			
				-- No Science
				if (sciencePerTurn <= 0) then
					strScienceText = string.format("[COLOR:255,60,60,255]" .. Locale.ConvertTextKey("TXT_KEY_NO_SCIENCE") .. "[ENDCOLOR]");
				-- We have science
				else
					strScienceText = string.format("+%i", sciencePerTurn);

					local iEnergyPerTurn = pPlayer:CalculateGoldRate();
					
					-- Energy being deducted from our Science
					if (pPlayer:GetEnergy() + iEnergyPerTurn < 0) then
						strScienceText = "[COLOR:255,0,60,255]" .. strScienceText .. "[ENDCOLOR]";
					-- Normal Science state
					else
						strScienceText = "[COLOR_MENU_BLUE]" .. strScienceText .. "[ENDCOLOR]";
					end
				end
			
				strScienceText = "[ICON_RESEARCH]" .. strScienceText;
			end
			
			local BUTTON_PADDING = 60;
			SetAutoWidthGridButton( Controls.SciencePerTurn, strScienceText, BUTTON_PADDING );

			-----------------------------
			-- Update energy stats
			-----------------------------
			local iTotalEnergy = pPlayer:GetEnergy();
			local iEnergyPerTurn = pPlayer:CalculateGoldRate();
			
			-- Accounting for positive or negative GPT - there's obviously a better way to do this.  If you see this comment and know how, it's up to you ;)
			-- Text is White when you can buy a Plot
			--if (iTotalEnergy >= pPlayer:GetBuyPlotCost(-1,-1)) then
				--if (iEnergyPerTurn >= 0) then
					--strGoldStr = string.format("[COLOR:255,255,255,255]%i (+%i)[ENDCOLOR]", iTotalEnergy, iEnergyPerTurn)
				--else
					--strGoldStr = string.format("[COLOR:255,255,255,255]%i (%i)[ENDCOLOR]", iTotalEnergy, iEnergyPerTurn)
				--end
			---- Text is Yellow or Red when you can't buy a Plot
			--else
			local strGoldStr = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_ENERGY", iTotalEnergy, iEnergyPerTurn);
			--end
			
			SetAutoWidthGridButton( Controls.EnergyPerTurn, strGoldStr, BUTTON_PADDING );

			-----------------------------
			-- Update international trade routes
			-----------------------------
			-- DEPRECATED: Revisit when trade routes are redesigned		-- DM 12-9-2013
			--local iUsedTradeRoutes = pPlayer:GetNumInternationalTradeRoutesUsed();
			--local iAvailableTradeRoutes = pPlayer:GetNumInternationalTradeRoutesAvailable();
			--local strInternationalTradeRoutes = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES", iUsedTradeRoutes, iAvailableTradeRoutes);
			--Controls.InternationalTradeRoutes:SetText(strInternationalTradeRoutes);
			Controls.InternationalTradeRoutes:SetHide(true);

			-----------------------------
			-- Update Health
			-----------------------------
			local strHealth;
			if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_HEALTH)) then
				strHealth = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_HEALTH_OFF");
			else
				local iHealth = pPlayer:GetExcessHealth();
				if (iHealth < 0) then
					strHealth = string.format("[ICON_HEALTH_3][COLOR_RED]%i[ENDCOLOR]", -iHealth);
				else
					strHealth = string.format("[ICON_HEALTH_1][COLOR_GREEN]%i[ENDCOLOR]", iHealth);
				end
			end

			SetAutoWidthGridButton( Controls.HealthString, strHealth, BUTTON_PADDING );
			
			-----------------------------
			-- Update Culture
			-----------------------------

			local strCultureStr;
			
			if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)) then
				strCultureStr = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_POLICIES_OFF");
			else
				local bIgnoreCost = true;
				if (pPlayer:GetNextPolicyCost() > 0 and pPlayer:CanAdoptAnyPolicy(bIgnoreCost)) then
					strCultureStr = string.format("%i/%i (+%i)", pPlayer:GetCulture(), pPlayer:GetNextPolicyCost(), pPlayer:GetTotalCulturePerTurn());
				else
					strCultureStr = string.format("+%i", pPlayer:GetTotalCulturePerTurn());
				end
			
				strCultureStr = "[ICON_CULTURE][COLOR_MAGENTA]" .. strCultureStr .. "[ENDCOLOR]";
			end
			
			SetAutoWidthGridButton( Controls.CultureString, strCultureStr, BUTTON_PADDING );
						
			-----------------------------
			-- Update Faith
			-----------------------------
			--local strFaithStr;
			--if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
				--strFaithStr = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_RELIGION_OFF");
			--else
				--strFaithStr = string.format("%i (+%i)", pPlayer:GetFaith(), pPlayer:GetTotalFaithPerTurn());
				--strFaithStr = "[ICON_PEACE]" .. strFaithStr;
			--end
			--Controls.FaithString:SetText(strFaithStr);
			Controls.FaithString:SetHide(true);

			-----------------------------
			-- Update Resources
			-----------------------------
			local pResource;
			local bShowResource;
			local iNumAvailable;
			local iNumUsed;
			local iNumTotal;
			local resourceCtr=0;
			
			local strResourceText = "";
			
			for pResource in GameInfo.Resources() do
				local iResourceLoop = pResource.ID;
				
				--if (Game.GetResourceUsageType(iResourceLoop) == ResourceUsageTypes.RESOURCEUSAGE_STRATEGIC) then
				if (Game.GetResourceClassType(iResourceLoop) == GameInfo.ResourceClasses["RESOURCECLASS_STRATEGIC"].ID) then
					
					bShowResource	= pTeam:IsResourceRevealed(iResourceLoop);
				
					iNumAvailable	= pPlayer:GetNumResourceAvailable(iResourceLoop, true);
					iNumUsed		= pPlayer:GetNumResourceUsed(iResourceLoop);
					iNumTotal		= pPlayer:GetNumResourceTotal(iResourceLoop, true);
					
					if (iNumUsed > 0) then
						bShowResource = true;
					end
							
					if (bShowResource) then
						local strThisResource = string.format("%s %i", pResource.IconString, iNumAvailable);
						if (iNumAvailable < 0) then
							strThisResource = "[COLOR_WARNING_TEXT]" .. strThisResource .. "[ENDCOLOR]";
						end
						
						-- Spacing
						if (resourceCtr > 0) then
							strResourceText = strResourceText .. "  ";
						end
						resourceCtr = resourceCtr + 1;

						strResourceText = strResourceText .. strThisResource;
					end
				end
			end
			Controls.ResourceString:SetSizeX(96*resourceCtr);
			Controls.ResourceString:SetText(strResourceText);	
		elseif(pPlayer:IsObserver()) then
			-- Observers only see game turn and menu buttons.
			Controls.TopPanelInfoStack:SetHide(false);
			Controls.AffinityStack:SetHide(true);	
			Controls.SciencePerTurn:SetHide(true);	
			Controls.EnergyPerTurn:SetHide(true);	
			Controls.HealthString:SetHide(true);	
			Controls.CultureString:SetHide(true);	
			Controls.ResourceString:SetHide(true);	
		else
		
			Controls.TopPanelInfoStack:SetHide(true);
			Controls.AffinityStack:SetHide(true);		
			
		end
		
		-- Update turn counter
		local turn = Locale.ConvertTextKey("TXT_KEY_TP_TURN_COUNTER", Game.GetGameTurn());
		Controls.CurrentTurn:SetText(Locale.ToUpper(turn));
		
		-- Update Unit Supply
		local iUnitSupplyMod = pPlayer:GetUnitProductionMaintenanceMod();
		if (not pPlayer:IsObserver() and iUnitSupplyMod ~= 0) then
			local iUnitsSupplied = pPlayer:GetNumUnitsSupplied();
			local iUnitsOver = pPlayer:GetNumUnitsOutOfSupply();
			local strUnitSupplyToolTip = Locale.ConvertTextKey("TXT_KEY_UNIT_SUPPLY_REACHED_TOOLTIP", iUnitsSupplied, iUnitsOver, -iUnitSupplyMod);
			
			Controls.UnitSupplyString:SetToolTipString(strUnitSupplyToolTip);
			Controls.UnitSupplyString:SetHide(false);
		else
			Controls.UnitSupplyString:SetHide(true);
		end
		
		-- Update date
		local date = Game.GetTurnString();
		
		--Controls.CurrentDate:SetText(date);
		Controls.TopPanelInfoStack:CalculateSize();
		Controls.TopPanelInfoStack:ReprocessAnchoring();
	end
end

function OnTopPanelDirty()
	UpdateData();
end

-------------------------------------------------
-------------------------------------------------
function OnCivilopedia()	
	-- In City View, return to main game
	--if (UI.GetHeadSelectedCity() ~= nil) then
		--Events.SerialEventExitCityScreen();
	--end
	--
	-- opens the Civilopedia without changing its current state
	Events.SearchForPediaEntry("");
end
Controls.CivilopediaButton:RegisterCallback( Mouse.eLClick, OnCivilopedia );


-------------------------------------------------
-------------------------------------------------
function OnMenu()
	
	-- In City View, return to main game
	if (UI.GetHeadSelectedCity() ~= nil and not UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK) then
		Events.SerialEventExitCityScreen();
		--UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	-- In Main View, open Menu Popup
	else
		Events.SerialEventShowInGameMenu();
	end
end
Controls.MenuButton:RegisterCallback( Mouse.eLClick, OnMenu );


-------------------------------------------------
-------------------------------------------------
function OnAffinitiesClicked()
	
	OnTechClicked();

end
--Controls.Affinities:RegisterCallback( Mouse.eLClick, OnAffinitiesClicked );

-------------------------------------------------
-------------------------------------------------
function OnCultureClicked()
	
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_CHOOSEPOLICY } );

end
Controls.CultureString:RegisterCallback( Mouse.eLClick, OnCultureClicked );


-------------------------------------------------
-------------------------------------------------
function OnTechClicked()
	
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, Data2 = -1} );

end
Controls.SciencePerTurn:RegisterCallback( Mouse.eLClick, OnTechClicked );

-------------------------------------------------
-------------------------------------------------
function OnFaithClicked()
	
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_RELIGION_OVERVIEW } );

end
Controls.FaithString:RegisterCallback( Mouse.eLClick, OnFaithClicked );

-------------------------------------------------
-------------------------------------------------
function OnGoldClicked()
	
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW } );

end
Controls.EnergyPerTurn:RegisterCallback( Mouse.eLClick, OnGoldClicked );

-------------------------------------------------
-------------------------------------------------
function OnTradeRouteClicked()
	
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_TRADE_ROUTE_OVERVIEW } );

end
Controls.InternationalTradeRoutes:RegisterCallback( Mouse.eLClick, OnTradeRouteClicked );


-------------------------------------------------
-- TOOLTIPS
-------------------------------------------------

local tipControlTable = {};
TTManager:GetTypeControlTable( "TooltipTypeTopPanel", tipControlTable );	--??TRON default TT's seem sufficient, are these custom ones needed?


-- ===========================================================================
-- Tooltip init
-- ===========================================================================
function DoInitTooltips()

	-- Affinities
	Controls.Harmony 			:RegisterMouseOverCallback( HarmonyTipHandler );
	Controls.HarmonyFullBar		:RegisterMouseOverCallback( HarmonyTipHandler );
	Controls.Purity 			:RegisterMouseOverCallback( PurityTipHandler );
	Controls.PurityFullBar		:RegisterMouseOverCallback( PurityTipHandler );
	Controls.Supremacy 			:RegisterMouseOverCallback( SupremacyTipHandler );
	Controls.SupremacyFullBar	:RegisterMouseOverCallback( SupremacyTipHandler );
	
	Controls.SciencePerTurn 	:RegisterMouseOverCallback( ScienceTipHandler );
	Controls.EnergyPerTurn 		:RegisterMouseOverCallback( GoldTipHandler );
	Controls.HealthString 		:RegisterMouseOverCallback( HealthTipHandler );
	Controls.CultureString 		:RegisterMouseOverCallback( CultureTipHandler );
	--Controls.FaithString 		:RegisterMouseOverCallback( FaithTipHandler );
	Controls.ResourceString 	:RegisterMouseOverCallback( ResourcesTipHandler );

	Controls.InternationalTradeRoutes:SetToolTipCallback( InternationalTradeRoutesTipHandler );
end


-- ===========================================================================
-- 	Remove?
-- ===========================================================================
function ShowToolTip( text )

	if (text ~= nil and #text > 0) then
		tipControlTable.TooltipLabel:SetText(text);
		tipControlTable.TooltipLabel:ReprocessAnchoring();
	
		-- Autosize tooltip
		local w,h = tipControlTable.TooltipLabel:GetSizeVal();
	
--		print("---------------------------------------------");
--		print("Tool Tip Size: " .. tostring(w) .. " by " .. tostring(h));
	
		local gw, gh = tipControlTable.TopPanelMouseover:GetSizeVal();
--		print("Grid Old Size: " .. tostring(gw) .. " by " .. tostring(gh));

		tipControlTable.TopPanelMouseover:SetSizeVal(w + 32, h + 32);

		local gw, gh = tipControlTable.TopPanelMouseover:GetSizeVal();
--		print("Grid New Size: " .. tostring(gw) .. " by " .. tostring(gh));

		tipControlTable.TopPanelMouseover:SetHide(false);
	else
		tipControlTable.TopPanelMouseover:SetHide(true);
	end
end


-- ===========================================================================
-- Affinities Tooltips
-- ===========================================================================
function HarmonyTipHandler( control )
	AffinityTipHandler(control, GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID);
end

function PurityTipHandler( control )
	AffinityTipHandler(control, GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID);
end

function SupremacyTipHandler( control )
	AffinityTipHandler(control, GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID);
end

function AffinityTipHandler( control, affinity )
	local activePlayerID= Game.GetActivePlayer();
	local activePlayer 	= Players[activePlayerID];
	local str 			= GetHelpTextForAffinity(affinity, activePlayer);
	control:SetToolTipString( str );
end


-- ===========================================================================
-- Science Tooltip
-- ===========================================================================
function ScienceTipHandler( control )

	local strText = "";
	
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
		strText = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_SCIENCE_OFF_TOOLTIP");
	else
	
		local iPlayerID = Game.GetActivePlayer();
		local pPlayer = Players[iPlayerID];
		local pTeam = Teams[pPlayer:GetTeam()];
		local pCity = UI.GetHeadSelectedCity();
	
		local iSciencePerTurn = pPlayer:GetScience();
	
		if (pPlayer:IsAnarchy()) then
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_ANARCHY", pPlayer:GetAnarchyNumTurns());
			strText = strText .. "[NEWLINE][NEWLINE]";
		end
	
		-- Science
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE", iSciencePerTurn);
		
			if (pPlayer:GetNumCities() > 0) then
				strText = strText .. "[NEWLINE][NEWLINE]";
		end
	
		local bFirstEntry = true;
	
		-- Science LOSS from Budget Deficits
		local iScienceFromBudgetDeficit = pPlayer:GetScienceFromBudgetDeficitTimes100();
		if (iScienceFromBudgetDeficit ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end

			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_BUDGET_DEFICIT", iScienceFromBudgetDeficit / 100);
			strText = strText .. "[NEWLINE]";
		end
	
		-- Science from Cities
		local iScienceFromCities = pPlayer:GetScienceFromCitiesTimes100(true);
		if (iScienceFromCities ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end

			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_CITIES", iScienceFromCities / 100);
		end
	
		-- Science from Trade Routes
		local iScienceFromTrade = pPlayer:GetScienceFromCitiesTimes100(false) - iScienceFromCities;
		if (iScienceFromTrade ~= 0) then
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end
			
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_ITR", iScienceFromTrade / 100);
		end
	
		-- Science from Other Players
		local iScienceFromOtherPlayers = pPlayer:GetScienceFromOtherPlayersTimes100();
		if (iScienceFromOtherPlayers ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end

			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_MINORS", iScienceFromOtherPlayers / 100);
		end
	
		-- Science from Health
		local iScienceFromHealth = pPlayer:GetScienceFromHealthTimes100();
		if (iScienceFromHealth ~= 0) then
			
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end
	
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_HEALTH", iScienceFromHealth / 100);
		end

		-- Science from Culture Rate
		local iScienceFromCulture = pPlayer:GetScienceFromCultureTimes100() / 100;
		if (iScienceFromCulture ~= 0) then
			
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end
	
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_CULTURE", iScienceFromCulture);
		end
	
		-- Science from Diplomacy Rate
		local iScienceFromDiplomacy = pPlayer:GetScienceFromDiplomacyTimes100() / 100;
		if (iScienceFromDiplomacy > 0) then			
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end
	
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_SCIENCE_FROM_DIPLOMACY", iScienceFromDiplomacy);
		elseif (iScienceFromDiplomacy < 0) then
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				bFirstEntry = false;
			else
				strText = strText .. "[NEWLINE]";
			end
	
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_NEGATIVE_SCIENCE_FROM_DIPLOMACY", -iScienceFromDiplomacy);
		end

		-- Uncategorized Science
		-- Bucket for any income that isn't explicitly called out on its own
		local iExplicitScience = 
			iScienceFromCities +
			iScienceFromTrade +
			iScienceFromOtherPlayers +
			iScienceFromHealth +
			iScienceFromCulture +
			iScienceFromDiplomacy;

		local iUncategorizedScience = iSciencePerTurn - iExplicitScience;
		if (iUncategorizedScience > 0) then
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", iUncategorizedScience);
		end
			
		-- Let people know that building more cities makes techs harder to get
			local iCostMod = Game.GetNumCitiesTechCostMod();
			local iDiscountPercent = pPlayer:GetNumCitiesResearchCostDiscount();
			if (iDiscountPercent ~= 0) then
				iCostMod = iCostMod * (100 + iDiscountPercent);
				iCostMod = iCostMod / 100;
			end
			strText = strText .. "[NEWLINE][NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_TECH_CITY_COST", iCostMod);
	end
	
	control:SetToolTipString( strText );
end


-- ===========================================================================
-- Energy Tooltip
-- ===========================================================================
function GoldTipHandler( control )

	local strText = "";
	local iPlayerID = Game.GetActivePlayer();
	local pPlayer = Players[iPlayerID];
	local pTeam = Teams[pPlayer:GetTeam()];
	local pCity = UI.GetHeadSelectedCity();
	
	-- INCOME --

	local iTotalEnergy = pPlayer:GetEnergy();	

	local iGoldPerTurnFromOtherPlayers = pPlayer:GetGoldPerTurnFromDiplomacy();
	local iGoldPerTurnToOtherPlayers = 0;
	if (iGoldPerTurnFromOtherPlayers < 0) then
		iGoldPerTurnToOtherPlayers = -iGoldPerTurnFromOtherPlayers;
		iGoldPerTurnFromOtherPlayers = 0;
	end
	
	local iGoldPerTurnFromPolicies = pPlayer:GetGoldPerTurnFromPolicies();
	local fTradeRouteGold = (pPlayer:GetGoldFromCitiesTimes100() - pPlayer:GetGoldFromCitiesMinusTradeRoutesTimes100()) / 100;
	local fGoldPerTurnFromCities = pPlayer:GetGoldFromCitiesMinusTradeRoutesTimes100() / 100;
	local fCityConnectionGold = pPlayer:GetCityConnectionGoldTimes100() / 100;
	local fTraitGold = pPlayer:GetGoldPerTurnFromTraits();

	-- Don't sum income here, let the game core do that
	local fTotalIncome = pPlayer:CalculateGrossGoldTimes100() / 100;
	local fExplicitIncome = 
		fGoldPerTurnFromCities + 
		iGoldPerTurnFromOtherPlayers + 
		fCityConnectionGold + 
		iGoldPerTurnFromPolicies +
		fTradeRouteGold + 
		fTraitGold;	

	local iUncategorizedIncome = math.floor(fTotalIncome - fExplicitIncome);	-- Bucket for any energy income that isn't explicitly called out on its own

	if (pPlayer:IsAnarchy()) then
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_ANARCHY", pPlayer:GetAnarchyNumTurns());
		strText = strText .. "[NEWLINE][NEWLINE]";
	end
	
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_AVAILABLE_GOLD", iTotalEnergy);
		strText = strText .. "[NEWLINE][NEWLINE]";
	
	strText = strText .. "[COLOR_WHITE]";
	strText = strText .. "+" .. Locale.ConvertTextKey("TXT_KEY_TP_TOTAL_INCOME", math.floor(fTotalIncome));
	strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_CITY_OUTPUT", fGoldPerTurnFromCities);
	if (math.floor(fCityConnectionGold) > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_FROM_CITY_CONNECTIONS", math.floor(fCityConnectionGold));
	end
	if (math.floor(fTradeRouteGold) > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_FROM_TRADE_ROUTES", math.floor(fTradeRouteGold));
	end
	if (math.floor(fTraitGold) > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_FROM_TRAITS", math.floor(fTraitGold));
	end
	if (iGoldPerTurnFromOtherPlayers > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_FROM_OTHERS", iGoldPerTurnFromOtherPlayers);
	end
	if (iGoldPerTurnFromPolicies > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_FROM_POLICIES", iGoldPerTurnFromPolicies);
	end
	if (iUncategorizedIncome > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", iUncategorizedIncome);
	end
	
	-- EXPENSES --

	local iUnitCost = pPlayer:CalculateUnitCost();
	local iUnitSupply = pPlayer:CalculateUnitSupply();
	local iBuildingMaintenance = pPlayer:GetBuildingGoldMaintenance();
	local iImprovementMaintenance = pPlayer:GetImprovementGoldMaintenance();
	local iRouteMaintenance = pPlayer:GetRouteEnergyMaintenance();

	-- Special costs
	local beaconEnergyDelta = pPlayer:GetBeaconEnergyCostPerTurn();

	local iTotalExpenses = 
		iUnitCost + 
		iUnitSupply + 
		iBuildingMaintenance + 
		iImprovementMaintenance + 
		iRouteMaintenance +
		iGoldPerTurnToOtherPlayers +
		beaconEnergyDelta;

	strText = strText .. "[NEWLINE]";
	strText = strText .. "[COLOR_RED]";
	strText = strText .. "[NEWLINE]-" .. Locale.ConvertTextKey("TXT_KEY_TP_TOTAL_EXPENSES", iTotalExpenses);
	if (iUnitCost ~= 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNIT_MAINT", iUnitCost);
	end
	if (iUnitSupply ~= 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_UNIT_SUPPLY", iUnitSupply);
	end
	if (iBuildingMaintenance ~= 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_BUILDING_MAINT", iBuildingMaintenance);
	end
	if (iImprovementMaintenance ~= 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_TILE_MAINT", iImprovementMaintenance);
	end
	if (iRouteMaintenance ~= 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_ROUTE_MAINT", iRouteMaintenance);
	end
	if (iGoldPerTurnToOtherPlayers > 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_TO_OTHERS", iGoldPerTurnToOtherPlayers);
	end
	if (beaconEnergyDelta ~= 0) then
		strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_TO_BEACON", beaconEnergyDelta);
	end
	strText = strText .. "[ENDCOLOR]";
	
	if (fTotalIncome + iTotalEnergy < 0) then
		strText = strText .. "[NEWLINE][COLOR_RED]" .. Locale.ConvertTextKey("TXT_KEY_TP_LOSING_SCIENCE_FROM_DEFICIT") .. "[ENDCOLOR]";
	end
	
	-- Basic explanation of Health
		strText = strText .. "[NEWLINE][NEWLINE]";
		strText = strText ..  Locale.ConvertTextKey("TXT_KEY_TP_ENERGY_EXPLANATION");
	
	control:SetToolTipString( strText );
end


-- ===========================================================================
-- Health Tooltip
-- ===========================================================================
function HealthTipHandler( control )
	local strText = "";
	
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_HEALTH)) then
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_HEALTH_OFF_TOOLTIP");
	else
		local iPlayerID = Game.GetActivePlayer();
		local pPlayer = Players[iPlayerID];
		local pTeam = Teams[pPlayer:GetTeam()];
		local pCity = UI.GetHeadSelectedCity();

		local iHealth = pPlayer:GetExcessHealth();
		local healthLevel = pPlayer:GetCurrentHealthLevel();
		local healthLevelInfo = GameInfo.HealthLevels[healthLevel];

		local colorPrefixText = "[COLOR_GREEN]";
		local iconStringText = "[ICON_HEALTH]";
		local rangeFactor = 1;
		if (iHealth <= 0) then
			colorPrefixText = "[COLOR_RED]";
			iconStringText = "[ICON_UNHEALTH]";
			if (iHealth < 0) then
				rangeFactor = -1;
			end
		end
		
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_SUMMARY", iconStringText, colorPrefixText, iHealth * rangeFactor);
		if (healthLevelInfo.Help ~= nil) then
			strText = strText .. " " .. Locale.ConvertTextKey(healthLevelInfo.Help);
		end
		local effectsText = ComposeHealthLevelEffectsText(pPlayer);
		if (effectsText ~= "") then
			strText = strText .. "[NEWLINE][NEWLINE]" .. effectsText;
		end

		--*** TOTAL HEALTH ***--
		local iTotalHealth = pPlayer:GetHealth();

		--*** HEALTH Source Breakdown ***--
		local pHandicapInfo = GameInfo.HandicapInfos[pPlayer:GetHandicapType()];
		local iHandicapHealth		= pHandicapInfo.BaseHealthRate;		
		local iCityHealth			= pPlayer:GetHealthFromCities();
		local iExtraCityHealth		= pPlayer:GetExtraHealthPerCity() * pPlayer:GetNumCities();
		local iPoliciesHealth		= pPlayer:GetHealthFromPolicies();
		local iTradeRouteHealth		= pPlayer:GetHealthFromTradeRoutes();
		--local iNationalSecProject	= pPlayer:GetHealthFromNationalSecurityProject(); WRM: Add this in when we have a text string for it
		local iUnaccountedFor		= iTotalHealth - (iHandicapHealth + iPoliciesHealth + iCityHealth + iTradeRouteHealth + iExtraCityHealth);
	
		strText = strText .. "[NEWLINE][NEWLINE]";
		strText = strText .. "[COLOR_WHITE]";
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_SOURCES", iTotalHealth);
	
		-- Individual Resource Info
		strText = strText .. "[NEWLINE]";
		strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_CITIES", iCityHealth);
		if (iPoliciesHealth >= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_POLICIES", iPoliciesHealth);
		end
		if (iTradeRouteHealth ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_CONNECTED_CITIES", iTradeRouteHealth);
		end
		if (iExtraCityHealth ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_CITY_COUNT", iExtraCityHealth);
		end
		if (iHandicapHealth ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_DIFFICULTY_LEVEL", iHandicapHealth);
		end
		if (iUnaccountedFor > 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_OTHER_SOURCES", iUnaccountedFor);
		end

		strText = strText .. "[ENDCOLOR]";
	
		--*** TOTAL UNHEALTH ***--
		local iTotalUnhealth = pPlayer:GetUnhealth();

		--*** UNHEALTH Source Breakdown ***--
		local iUnhealthFromCities			= pPlayer:GetUnhealthFromCities() / 100;
		local iUnhealthFromUnits			= pPlayer:GetUnhealthFromUnits() / 100;
		local iUnhealthFromCityCount		= pPlayer:GetUnhealthFromCityCount() / 100;
		local iUnhealthFromConqueredCityCount= pPlayer:GetUnhealthFromConqueredCityCount() / 100;
		
		local iUnhealthFromPupetCities		= pPlayer:GetUnhealthFromPuppetCityPopulation();
		local unHealthFromSpecialists		= pPlayer:GetUnhealthFromCitySpecialists();
		local unHealthFromPop				= pPlayer:GetUnhealthFromCityPopulation() - unHealthFromSpecialists - iUnhealthFromPupetCities;
			
		local iUnhealthFromPop				= unHealthFromPop / 100;
		local iUnhealthFromConqueredCities	= pPlayer:GetUnhealthFromConqueredCities() / 100;

		local iUnhealthMod = pPlayer:GetUnhealthMod();
		
		strText = strText .. "[NEWLINE][NEWLINE]";
		strText = strText .. "[COLOR:255,150,150,255]";
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_TOTAL", iTotalUnhealth);

		-- Local City Unhealth
		strText = strText .. "[NEWLINE]";
		strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_CITIES", Locale.ToNumber( iUnhealthFromCities, "#.##" ));

		-- City Count
		strText = strText .. "[NEWLINE]";
		strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_CITY_COUNT", Locale.ToNumber( iUnhealthFromCityCount, "#.##" ));
		if (iUnhealthFromConqueredCityCount ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_CAPTURED_CITY_COUNT", Locale.ToNumber( iUnhealthFromConqueredCityCount, "#.##" ));
		end

		strText = strText .. "[NEWLINE]";
		strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_POPULATION", Locale.ToNumber( iUnhealthFromPop, "#.##" ));		
		if(iUnhealthFromPupetCities > 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_PUPPET_CITIES", iUnhealthFromPupetCities / 100);
		end
		
		-- City Specialists
		if(unHealthFromSpecialists > 0) then
			strText = strText .. "[NEWLINE]  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_SPECIALISTS", unHealthFromSpecialists / 100);
		end
		
		if (iUnhealthFromConqueredCities ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_OCCUPIED_POPULATION", Locale.ToNumber( iUnhealthFromConqueredCities, "#.##" ));
		end
		if (iUnhealthFromUnits ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_UNITS",  Locale.ToNumber( iUnhealthFromUnits, "#.##" ));
		end		

		-- Uncategorized Unhealth
		-- Bucket for any energy income that isn't explicitly called out on its own
		local iExplicitUnhealth = 
			iUnhealthFromCities +
			iUnhealthFromCityCount +
			iUnhealthFromConqueredCityCount +
			iUnhealthFromPop +
			iUnhealthFromPupetCities +
			unHealthFromSpecialists +
			iUnhealthFromConqueredCities +
			iUnhealthFromUnits;

		local iUncategorizedUnhealth = iTotalUnhealth - iExplicitUnhealth;
		if (iUncategorizedUnhealth > 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", iUncategorizedUnhealth);
		end

		strText = strText .. "[ENDCOLOR]";

		-- Overall Unhealth Mod
		if (iUnhealthMod ~= 0) then
			if (iUnhealthMod > 0) then -- Positive mod means more Unhealth - this is a bad thing!
				strText = strText .. "[NEWLINE]";
				strText = strText .. "  [ICON_BULLET][COLOR:255,150,150,255]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_MOD", iUnhealthMod) .. "[ENDCOLOR]";
			else -- Negative mod means less Unhealth - this is a good thing!
				strText = strText .. "[NEWLINE]";
				strText = strText .. "  [ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_TP_UNHEALTH_MOD", iUnhealthMod);
			end
		end
	
		--[[
		-- Basic explanation of Health
			strText = strText .. "[NEWLINE][NEWLINE]";
			strText = strText ..  Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_EXPLANATION");
		--]]
	end
	
	control:SetToolTipString( strText );
end

function ComposeHealthLevelEffectsText(player)
	local s = "";
	local netHealth = player:GetExcessHealth();
	local first = true;

	for info in GameInfo.HealthLevels() do
		if (player:IsAffectedByHealthLevel(info.ID)) then
			local combatMod = info.CombatModifier;
			local cityGrowthMod = Game.GetHealthLevelCityGrowthModifier(info.ID, netHealth);
			local outpostGrowthMod = Game.GetHealthLevelOutpostGrowthModifier(info.ID, netHealth);
			local cityIntrigueMod = Game.GetHealthLevelCityIntrigueModifier(info.ID, netHealth);
			if (combatMod ~= nil and combatMod ~= 0) then
				if (first) then first = false; else s = s .. "[NEWLINE]"; end
				s = s .. "[ICON_BULLET]";
				s = s .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_LEVEL_EFFECT_COMBAT_MODIFIER", combatMod);
			end
			if (cityGrowthMod ~= 0) then
				if (first) then first = false; else s = s .. "[NEWLINE]"; end
				s = s .. "[ICON_BULLET]";
				s = s .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_LEVEL_EFFECT_CITY_GROWTH_MODIFIER", cityGrowthMod);
			end
			if (outpostGrowthMod ~= 0) then
				if (first) then first = false; else s = s .. "[NEWLINE]"; end
				s = s .. "[ICON_BULLET]";
				s = s .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_LEVEL_EFFECT_OUTPOST_GROWTH_MODIFIER", outpostGrowthMod);
			end
			if (cityIntrigueMod ~= 0) then
				if (first) then first = false; else s = s .. "[NEWLINE]"; end
				s = s .. "[ICON_BULLET]";
				s = s .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_LEVEL_EFFECT_CITY_INTRIGUE_MODIFIER", cityIntrigueMod);
			end
			for yieldInfo in GameInfo.Yields() do
				local yieldMod = Game.GetHealthLevelCityYieldModifier(info.ID, netHealth, yieldInfo.ID);
				if (yieldMod ~= 0) then
					if (first) then first = false; else s = s .. "[NEWLINE]"; end
					s = s .. "[ICON_BULLET]";
					s = s .. Locale.ConvertTextKey("TXT_KEY_TP_HEALTH_LEVEL_EFFECT_CITY_YIELD_MODIFIER", yieldMod, yieldInfo.IconString, yieldInfo.Description);
				end
			end
		end
	end

	if (s ~= "") then
		if (player:IsEmpireUnhealthy()) then
			s = "[COLOR_WARNING_TEXT]" .. s .. "[ENDCOLOR]";
		else
			s = "[COLOR_POSITIVE_TEXT]" .. s .. "[ENDCOLOR]";
		end
	end

	return s;
end


-- ===========================================================================
-- Culture Tooltip
-- ===========================================================================
function CultureTipHandler( control )

	local strText = "";
	
	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)) then
		strText = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_POLICIES_OFF_TOOLTIP");
	else
	
		local iPlayerID = Game.GetActivePlayer();
		local pPlayer = Players[iPlayerID];
    
	    local iTurns;
		local iCulturePerTurn = pPlayer:GetTotalCulturePerTurn();
		local iCultureNeeded = pPlayer:GetNextPolicyCost() - pPlayer:GetCulture();

	    if (iCultureNeeded <= 0) then
			iTurns = 0;
		else
			if (iCulturePerTurn == 0) then
				iTurns = "?";
			else
				iTurns = iCultureNeeded / iCulturePerTurn;
				iTurns = math.ceil(iTurns);
			end
	    end
	    
	    if (pPlayer:IsAnarchy()) then
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_ANARCHY", pPlayer:GetAnarchyNumTurns());
		end
	    
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_NEXT_POLICY_TURN_LABEL", iTurns);
	
			strText = strText .. "[NEWLINE][NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_ACCUMULATED", pPlayer:GetCulture());
			strText = strText .. "[NEWLINE]";
		
			if (pPlayer:GetNextPolicyCost() > 0) then
				strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_NEXT_POLICY", pPlayer:GetNextPolicyCost());
		end

		if (pPlayer:IsAnarchy()) then
			ShowToolTip(strText);
			return;
		end

		local bFirstEntry = true;
		
		-- Culture for Free
		local iCultureForFree = pPlayer:GetCulturePerTurnForFree();
		if (iCultureForFree ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				strText = strText .. "[NEWLINE]";
				bFirstEntry = false;
			end

			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_FOR_FREE", iCultureForFree);
		end
	
		-- Culture from Cities
		local iCultureFromCities = pPlayer:GetCulturePerTurnFromCities();
		if (iCultureFromCities ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				strText = strText .. "[NEWLINE]";
				bFirstEntry = false;
			end

			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_FROM_CITIES", iCultureFromCities);
		end
	
		-- Culture from Excess Health
		local iCultureFromHealth = pPlayer:GetCulturePerTurnFromExcessHealth();
		if (iCultureFromHealth ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				strText = strText .. "[NEWLINE]";
				bFirstEntry = false;
			end

			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_FROM_HEALTH", iCultureFromHealth);
		end
	
		-- Culture from Traits
		local iCultureFromTraits = pPlayer:GetCulturePerTurnFromTraits();
		if (iCultureFromTraits ~= 0) then
		
			-- Add separator for non-initial entries
			if (bFirstEntry) then
				strText = strText .. "[NEWLINE]";
				bFirstEntry = false;
			end

			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_FROM_TRAITS", iCultureFromTraits);
		end

		-- Uncategorized Culture
		-- Bucket for any income that isn't explicitly called out on its own
		local iExplicitCulture = 
			iCultureForFree +
			iCultureFromCities +
			iCultureFromHealth +
			iCultureFromTraits;

		local iUncategorizedCulture = iCulturePerTurn - iExplicitCulture;
		if (iUncategorizedCulture > 0) then
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_YIELD_FROM_UNCATEGORIZED", iUncategorizedCulture);
		end

		-- Let people know that building more cities makes policies harder to get
			local iCostMod = Game.GetNumCitiesPolicyCostMod();
			local iDiscountPercent = pPlayer:GetNumCitiesPolicyCostDiscount();
			if (iDiscountPercent ~= 0) then
				iCostMod = iCostMod * (100 + iDiscountPercent);
				iCostMod = iCostMod / 100;
			end
			strText = strText .. "[NEWLINE][NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_CULTURE_CITY_COST", iCostMod);
	end
	
	control:SetToolTipString( strText );

end


-- ===========================================================================
-- FaithTooltip
-- ===========================================================================
function FaithTipHandler( control )

	local strText = "";

	if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
		strText = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_RELIGION_OFF_TOOLTIP");
	else
	
		local iPlayerID = Game.GetActivePlayer();
		local pPlayer = Players[iPlayerID];

	    if (pPlayer:IsAnarchy()) then
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_ANARCHY", pPlayer:GetAnarchyNumTurns());
			strText = strText .. "[NEWLINE]";
			strText = strText .. "[NEWLINE]";
		end
	    
		strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_ACCUMULATED", pPlayer:GetFaith());
		strText = strText .. "[NEWLINE]";
	
		-- Faith from Cities
		local iFaithFromCities = pPlayer:GetFaithPerTurnFromCities();
		if (iFaithFromCities ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_FROM_CITIES", iFaithFromCities);
		end

		-- Faith from Outposts
		local iFaithFromOutposts = pPlayer:GetFaithPerTurnFromOutposts();
		if (iFaithFromOutposts ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_FROM_OUTPOSTS", iFaithFromOutposts);
		end
	
		-- Faith from Minor Civs
		local iFaithFromMinorCivs = pPlayer:GetFaithPerTurnFromMinorCivs();
		if (iFaithFromMinorCivs ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_FROM_MINORS", iFaithFromMinorCivs);
		end

		-- Faith from Religion
		local iFaithFromReligion = pPlayer:GetFaithPerTurnFromReligion();
		if (iFaithFromReligion ~= 0) then
			strText = strText .. "[NEWLINE]";
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_FROM_RELIGION", iFaithFromReligion);
		end

		---- Faith from Stations (can be positive or negative)
		--local iFaithDeltaFromStations = pPlayer:GetFaithDeltaPerTurnFromStations();
		--if (iFaithDeltaFromStations ~= 0) then
--
			--local strStationText;
			---- Gate for pos/neg
			--if iFaithDeltaFromStations > 0 then
				--strStationText = "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_FROM_STATIONS", iFaithDeltaFromStations);
			--elseif iFaithDeltaFromStations < 0 then
				--strStationText = "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_TO_STATIONS", iFaithDeltaFromStations);
			--end
--
			--strText = strText .. strStationText .. "[NEWLINE]";
		--end

		if (iFaithFromCities ~= 0 or iFaithFromOutposts ~= 0 or iFaithFromMinorCivs ~= 0 or iFaithFromReligion ~= 0 or iFaithDeltaFromStations ~= 0) then
			strText = strText .. "[NEWLINE]";
		end
	
		strText = strText .. "[NEWLINE]";

		strText = strText .. "$Creed and Dogma info$[NEWLINE]";
		--[[
		if (pPlayer:HasCreatedPantheon()) then
			if (Game.GetNumReligionsStillToFound() > 0 or pPlayer:HasCreatedReligion()) then
				if (pPlayer:GetCurrentEra() < GameInfo.Eras["ERA_INDUSTRIAL"].ID) then
					strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_NEXT_PROPHET", pPlayer:GetMinimumFaithNextGreatProphet());
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[NEWLINE]";
				end
			end
		else
			if (pPlayer:CanCreatePantheon(false)) then
				strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_NEXT_PANTHEON", Game.GetMinimumFaithNextPantheon());
				strText = strText .. "[NEWLINE]";
			else
				strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_PANTHEONS_LOCKED");
				strText = strText .. "[NEWLINE]";
			end
			strText = strText .. "[NEWLINE]";
		end

		if (Game.GetNumReligionsStillToFound() < 0) then
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_RELIGIONS_LEFT", 0);
		else
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_RELIGIONS_LEFT", Game.GetNumReligionsStillToFound());
		end
		
		if (pPlayer:GetCurrentEra() >= GameInfo.Eras["ERA_INDUSTRIAL"].ID) then
		    local bAnyFound = false;
			strText = strText .. "[NEWLINE]";		
			strText = strText .. "[NEWLINE]";		
			strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_FAITH_NEXT_GREAT_PERSON", pPlayer:GetMinimumFaithNextGreatProphet());	
			for info in GameInfo.Units{Special = "SPECIALUNIT_PEOPLE"} do
				if (info.ID == GameInfo.Units["UNIT_MERCHANT"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_COMMERCE"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_COMMERCE"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_SCIENTIST"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_RATIONALISM"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_RATIONALISM"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_WRITER"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_AESTHETICS"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_AESTHETICS"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_ARTIST"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_AESTHETICS"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_AESTHETICS"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_MUSICIAN"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_AESTHETICS"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_AESTHETICS"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_GREAT_GENERAL"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_HONOR"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_HONOR"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_GREAT_ADMIRAL"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_EXPLORATION"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_EXPLORATION"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
				if (info.ID == GameInfo.Units["UNIT_ENGINEER"].ID and pPlayer:IsPolicyBranchFinished(GameInfo.PolicyBranchTypes["POLICY_BRANCH_TRADITION"].ID) and not pPlayer:IsPolicyBranchBlocked(GameInfo.PolicyBranchTypes["POLICY_BRANCH_TRADITION"].ID)) then	
					strText = strText .. "[NEWLINE]";
					strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey(info.Description);
					bAnyFound = true;
				end
			end
			if (not bAnyFound) then
				strText = strText .. "[NEWLINE]";
				strText = strText .. "[ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_RO_YR_NO_GREAT_PEOPLE");
			end
		end
		--]]
	end

	control:SetToolTipString( strText );

end


-- ===========================================================================
-- Resources Tooltip
-- ===========================================================================
function ResourcesTipHandler( control )

	local strText;
	local iPlayerID = Game.GetActivePlayer();
	local pPlayer = Players[iPlayerID];
	local pTeam = Teams[pPlayer:GetTeam()];
	local pCity = UI.GetHeadSelectedCity();
	
	strText = "";
	
	local pResource;
	local bShowResource;
	local bThisIsFirstResourceShown = true;
	local iNumAvailable;
	local iNumUsed;
	local iNumTotal;
	local idStrategicResourceClass = GameInfo.ResourceClasses["RESOURCECLASS_STRATEGIC"].ID;

	for pResource in GameInfo.Resources() do
		local iResourceLoop = pResource.ID;
		
		if (Game.GetResourceClassType(iResourceLoop) == idStrategicResourceClass) then

			bShowResource	= pTeam:IsResourceRevealed(iResourceLoop);	
			
			if (bShowResource) then
				iNumAvailable = pPlayer:GetNumResourceAvailable(iResourceLoop, true);
				iNumUsed = pPlayer:GetNumResourceUsed(iResourceLoop);
				iNumTotal = pPlayer:GetNumResourceTotal(iResourceLoop, true);
				
				-- Add newline to the front of all entries that AREN'T the first
				if (bThisIsFirstResourceShown) then
					strText = "";
					bThisIsFirstResourceShown = false;
				else
					strText = strText .. "[NEWLINE][NEWLINE]";
				end
				
				strText = strText .. iNumAvailable .. " " .. pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description);
				
				-- Details
				if (iNumUsed ~= 0 or iNumTotal ~= 0) then
					strText = strText .. " : ";	-- Space before colon ok in some languages but required in French
					strText = strText .. Locale.ConvertTextKey("TXT_KEY_TP_RESOURCE_INFO", iNumTotal, iNumUsed);
				end
			end
		end
	end
	
	control:SetToolTipString( strText );
end


-- ===========================================================================
-- International Trade Route Tooltip
-- ===========================================================================
function InternationalTradeRoutesTipHandler( control )

	local iPlayerID = Game.GetActivePlayer();
	local pPlayer = Players[iPlayerID];
	
	local strTT = "";
	
	local iNumLandTradeUnitsAvail = pPlayer:GetNumAvailableTradeUnits(DomainTypes.DOMAIN_LAND);
	if (iNumLandTradeUnitsAvail > 0) then
		local iTradeUnitType = pPlayer:GetTradeUnitType(DomainTypes.DOMAIN_LAND);
		local strUnusedTradeUnitWarning = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES_TT_UNASSIGNED", iNumLandTradeUnitsAvail, GameInfo.Units[iTradeUnitType].Description);
		strTT = strTT .. strUnusedTradeUnitWarning;
	end
	
	local iNumSeaTradeUnitsAvail = pPlayer:GetNumAvailableTradeUnits(DomainTypes.DOMAIN_SEA);
	if (iNumSeaTradeUnitsAvail > 0) then
		local iTradeUnitType = pPlayer:GetTradeUnitType(DomainTypes.DOMAIN_SEA);
		local strUnusedTradeUnitWarning = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES_TT_UNASSIGNED", iNumLandTradeUnitsAvail, GameInfo.Units[iTradeUnitType].Description);	
		strTT = strTT .. strUnusedTradeUnitWarning;
	end
	
	if (strTT ~= "") then
		strTT = strTT .. "[NEWLINE]";
	end
	
	local iUsedTradeRoutes = pPlayer:GetNumInternationalTradeRoutesUsed();
	local iAvailableTradeRoutes = pPlayer:GetNumInternationalTradeRoutesAvailable();
	
	local strText = Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_INTERNATIONAL_TRADE_ROUTES_TT", iUsedTradeRoutes, iAvailableTradeRoutes);
	strTT = strTT .. strText;
	
	local strYourTradeRoutes = pPlayer:GetTradeYourRoutesTTString();
	if (strYourTradeRoutes ~= "") then
		strTT = strTT .. "[NEWLINE][NEWLINE]"
		strTT = strTT .. Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_ITR_ESTABLISHED_BY_PLAYER_TT");
		strTT = strTT .. "[NEWLINE]";
		strTT = strTT .. strYourTradeRoutes;
	end

	local strToYouTradeRoutes = pPlayer:GetTradeToYouRoutesTTString();
	if (strToYouTradeRoutes ~= "") then
		strTT = strTT .. "[NEWLINE][NEWLINE]"
		strTT = strTT .. Locale.ConvertTextKey("TXT_KEY_TOP_PANEL_ITR_ESTABLISHED_BY_OTHER_TT");
		strTT = strTT .. "[NEWLINE]";
		strTT = strTT .. strToYouTradeRoutes;
	end

	ShowToolTip(strTT);
end

-------------------------------------------------
-- On Top Panel mouseover exited
-------------------------------------------------
--function HelpClose()
	---- Hide the help text box
	--Controls.HelpTextBox:SetHide( true );
--end


-- Register Events
Events.SerialEventGameDataDirty.Add(OnTopPanelDirty);
Events.SerialEventTurnTimerDirty.Add(OnTopPanelDirty);
Events.SerialEventCityInfoDirty.Add(OnTopPanelDirty);

-- Update data at initialization
UpdateData();
DoInitTooltips();
