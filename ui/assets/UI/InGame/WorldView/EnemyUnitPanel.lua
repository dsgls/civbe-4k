-------------------------------------------------
-- Enemy Unit Panel Screen 
-------------------------------------------------
include( "IconSupport" );
include( "InstanceManager" );

local g_MyCombatDataIM		= InstanceManager:new( "UsCombatInfo", "Text", Controls.MyCombatResultsStack );
local g_TheirCombatDataIM	= InstanceManager:new( "ThemCombatInfo", "Text", Controls.TheirCombatResultsStack );

local g_NumButtons = 12;
local g_lastUnitID = -1;		-- Used to determine if a different pUnit has been selected.
local g_DAMAGE_BAR_SIZE = 111;	-- Size of damage

local maxUnitHitPoints = GameDefines["MAX_HIT_POINTS"];

local defaultErrorTextureSheet = "TechAtlasSmall.dds";
local nullOffset = Vector2( 0, 0 );

--local g_iPortraitSize = Controls.UnitPortrait:GetSize().x;

local g_bWorldMouseOver = true;
local g_bShowPanel		= false;
local m_gridHeightXML	= Controls.DetailsGrid:GetSizeY();


function SetName(name)
	
	name = Locale.ToUpper(name);

    local iNameLength = Locale.Length(name);
    if (iNameLength < 18) then
	    Controls.UnitName:SetText(name);
	    
	    Controls.UnitName:SetHide(false);
	    Controls.LongUnitName:SetHide(true);
	    Controls.ReallyLongUnitName:SetHide(true);
	    
    elseif (iNameLength < 23) then
	    Controls.LongUnitName:SetText(name);
	    
	    Controls.UnitName:SetHide(true);
	    Controls.LongUnitName:SetHide(false);
	    Controls.ReallyLongUnitName:SetHide(true);
	    
    else
	    Controls.ReallyLongUnitName:SetText(name);
	    
	    Controls.UnitName:SetHide(true);
	    Controls.LongUnitName:SetHide(true);
	    Controls.ReallyLongUnitName:SetHide(false);
    end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function UpdateSitePortrait( pPlot )

	if (pPlot == nil) then
		error("Could not retrieve plot for site combat odds");
		return;
	end

	-- Retrieve site	
	local pStrategicSite = pPlot:GetPlotStrategicSite();
	if (pStrategicSite == nil) then
		error("Could not retrieve strategic site for combat odds!");
		return;
	end

	SetName(pPlot:GetSiteName());
	local playerID = pPlot:GetOwner();
	local pPlayer = Players[playerID];
    local thisCivType = PreGame.GetCivilization( playerID );
    local thisCiv = GameInfo.Civilizations[thisCivType];

	--print("thisCiv.AlphaIconAtlas:"..tostring(thisCiv.AlphaIconAtlas))

	local textureOffset, textureAtlas = IconLookup( thisCiv.PortraitIndex, 32, thisCiv.AlphaIconAtlas );
    local iconColor, flagColor = pPlayer:GetPlayerColors();
	if pPlayer:IsMinorCiv() then
		flagColor, iconColor = iconColor, flagColor;
	end

	Controls.RenderedEnemyPortrait:SetHide(true);
--	Controls.UnitBackColor:SetColor( flagColor );
--	Controls.UnitIcon:SetColor( iconColor );
end


--------------------------------------------------------------------------------
-- Refresh Unit portrait and name
--------------------------------------------------------------------------------
function UpdateUnitPortrait( pUnit )

	if pUnit == nil then
		Controls.RenderedEnemyPortrait:SetHide( true );
		return;
	end

	Controls.RenderedEnemyPortrait:SetHide( false );

	local unitPosition = 
	{
		x = unit and unit:GetX() or 0,
        y = unit and unit:GetY() or 0,
    };
    local hex = ToHexFromGrid(unitPosition);

	Events.CombatPreviewUnitChanged( pUnit:GetOwner(), pUnit:GetID(), hex.x, hex.y, 0 );

	local name = pUnit:GetName();
	SetName(name);
		
	local flagOffset, flagAtlas, flagHeightOffset = UI.GetUnitFlagIcon(pUnit);

	local textureOffset, textureSheet = IconLookup( flagOffset, 32, flagAtlas );				
	local pPlayer = Players[pUnit:GetOwner()];
    local iconColor, flagColor = pPlayer:GetPlayerColors();
	if pPlayer:IsMinorCiv() then
		flagColor, iconColor = iconColor, flagColor;
	end
end



--------------------------------------------------------------------------------
-- Refresh Site stats
--------------------------------------------------------------------------------
function UpdateSiteStats(pPlot)
	
	if (pPlot == nil) then
		error("Could not retrieve plot for site combat odds");
		return;
	end

	-- Retrieve site	
	local pStrategicSite = pPlot:GetPlotStrategicSite();
	if (pStrategicSite == nil) then
		error("Could not retrieve strategic site for combat odds!");
		return;
	end

	-- Strength
	local strength = math.floor(pStrategicSite:GetCombatStrength() / 100);
	
	strength = "[ICON_STRENGTH] " .. strength;
	Controls.UnitStrengthBox:SetHide(false);
	Controls.UnitStatStrength:SetText(strength);
	
	Controls.UnitMovementBox:SetHide(true);
	Controls.UnitRangedAttackBox:SetHide(true);		
end

--------------------------------------------------------------------------------
-- Refresh Unit stats
--------------------------------------------------------------------------------
function UpdateUnitStats(pUnit)
	
	-- Movement
	local move_denominator = GameDefines["MOVE_DENOMINATOR"];
	local max_moves = pUnit:MaxMoves() / move_denominator;
	local szMoveStr = "[ICON_MOVES] " .. max_moves;
	
	Controls.UnitStatMovement:SetText(szMoveStr);
	Controls.UnitMovementBox:SetHide(false);
	
	-- Strength
    local strength = 0;
    if(pUnit:GetDomainType() == DomainTypes.DOMAIN_AIR) then
        strength = pUnit:GetRangedCombatStrength();
    else
        strength = pUnit:GetCombatStrength();
    end
	if(strength > 0) then
		strength = " [ICON_STRENGTH] " .. strength;
		Controls.UnitStrengthBox:SetHide(false);
		Controls.UnitStatStrength:SetText(strength);
	else
		Controls.UnitStrengthBox:SetHide(true);
	end		
	
	-- Ranged Strength
	local iRangedStrength = 0;
	if(pUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR) then
		iRangedStrength = pUnit:GetRangedCombatStrength();
	else
		iRangedStrength = 0;
	end
	if(iRangedStrength > 0) then
		local szRangedStrength = "[ICON_RANGE_STRENGTH] " .. iRangedStrength;
		Controls.UnitRangedAttackBox:SetHide(false);
		Controls.UnitStatRangedAttack:SetText(szRangedStrength);
	else
		Controls.UnitRangedAttackBox:SetHide(true);
	end		
	
end


--------------------------------------------------------------------------------
-- Format our text please!
--------------------------------------------------------------------------------
function GetFormattedText(strLocalizedText, iValue, bForMe, bPercent, strOptionalColor)
	
	local strTextToReturn = "";
	local strNumberPart = Locale.ToNumber(iValue, "#.##");
	
	if (bPercent) then
		strNumberPart = strNumberPart .. "%";
		
		if (bForMe) then
			if (iValue > 0) then
				strNumberPart = "[COLOR_POSITIVE_TEXT]+" .. strNumberPart .. "[ENDCOLOR]";
			elseif (iValue < 0) then
				strNumberPart = "[COLOR_NEGATIVE_TEXT]" .. strNumberPart .. "[ENDCOLOR]";
			end
		else
			if (iValue < 0) then
				strNumberPart = "[COLOR_POSITIVE_TEXT]" .. strNumberPart .. "[ENDCOLOR]";
			elseif (iValue > 0) then
				strNumberPart = "[COLOR_NEGATIVE_TEXT]+" .. strNumberPart .. "[ENDCOLOR]";
			end
		end

	end
	
	if (strOptionalColor ~= nil) then
		strNumberPart = strOptionalColor .. strNumberPart .. "[ENDCOLOR]";
	end
	
	-- Formatting for my side
	if (bForMe) then
		strTextToReturn = " :  " .. strNumberPart;
	-- Formatting for their side
	else
		strTextToReturn = strNumberPart .. "  : ";
	end
	
	return strTextToReturn;
	
end


-- ===========================================================================
--	All contents are filled, make art fit...
-- ===========================================================================
function ResizeAllContents()
    Controls.MyCombatResultsStack:CalculateSize();
    Controls.TheirCombatResultsStack:CalculateSize();

	-- Increase size of grid if stack of upgrades goes past bottom.
	local ART_HEIGHT = 50;
	local myGridHeight		= Controls.MyCombatResultsStack:GetSizeY() + ART_HEIGHT;
	local theirGridHeight	= Controls.TheirCombatResultsStack:GetSizeY() + ART_HEIGHT;
	
	local gridHeight		= math.max( myGridHeight, theirGridHeight );	-- player vs enemy
	gridHeight				= math.max( gridHeight, m_gridHeightXML );		-- result vs initial XML value

	Controls.DetailsGrid:SetSizeY( gridHeight );
	Controls.ShadowsLeft:SetSizeY( gridHeight );
	Controls.ShadowsRight:SetSizeY( gridHeight );
	Controls.DetailsGrid:ReprocessAnchoring();
	local unitPanelX = ContextPtr:LookUpControl("/InGame/WorldView/UnitPanel/UnitPanelBackground"):GetSizeX();
	Controls.EnemyPanel:SetOffsetX(unitPanelX-62);
	Controls.DetailsGrid:SetOffsetX(unitPanelX-257);

end


-- ===========================================================================
-- Combat Odds vs Site
-- ===========================================================================
function UpdateCombatOddsUnitVsSite(pMyUnit, pPlot)
	
	--print("Updating site combat odds");

	if (pPlot == nil) then
		error("Could not retrieve plot for site combat odds");
		return;
	end
	
	local pStrategicSite = pPlot:GetPlotStrategicSite();
	if (pStrategicSite == nil) then
		error("Could not retrieve strategic site for combat odds!");
		return;
	end
	
	local bIsCity : boolean = pPlot:IsCity();
	local bIsOutpost : boolean = pPlot:IsOutpost();
	local bIsStation : boolean = pPlot:IsStation();
	
	g_MyCombatDataIM:ResetInstances();
	g_TheirCombatDataIM:ResetInstances();
	
	if (pMyUnit ~= nil) then
		
		local iMyPlayer = pMyUnit:GetOwner();
		local iTheirPlayer = pPlot:GetOwner();
		local pMyPlayer = Players[iMyPlayer];
		local pTheirPlayer = Players[iTheirPlayer];
		
		local iMyStrength = 0;
		local iTheirStrength = 0;
		local bRanged = false;
		local iNumVisibleAAUnits = 0;
		local bInterceptPossible = false;
		
		local pFromPlot = pMyUnit:GetPlot();
		
		-- Ranged Unit
		if (pMyUnit:IsRanged() and pMyUnit:IsRangedSupportFire() == false) then
			iMyStrength = pMyUnit:GetMaxRangedCombatStrengthVsSite(pPlot, true, true);
			bRanged = true;
			
		-- Melee Unit
		else
			iMyStrength = pMyUnit:GetMaxAttackStrength(pFromPlot, pPlot, nil);
		end
		
		iTheirStrength = pStrategicSite:GetCombatStrength(bRanged);
		
		if (iMyStrength > 0) then
			
			-- Start with logic of combat estimation
			local iMyDamageInflicted = 0;
			local iTheirDamageInflicted = 0;
			local iTheirFireSupportCombatDamage = 0;
			
			-- Ranged Strike
			if (bRanged) then
				iMyDamageInflicted = pMyUnit:GetRangeCombatDamageVsSite(pPlot, false);
				
				if (pPlot ~= nil and pMyUnit ~= nil and pMyUnit:GetDomainType() == DomainTypes.DOMAIN_AIR) then
					iTheirDamageInflicted = pStrategicSite:GetAirStrikeDefenseDamage(pMyUnit, false);
					iNumVisibleAAUnits = pMyUnit:GetInterceptorCount(pPlot, nil, true, true);		
					bInterceptPossible = true;	
				end
				
			-- Normal Melee Combat
			else								
				local pFireSupportUnit = pMyUnit:GetFireSupportUnit(pPlot:GetOwner(), pPlot:GetX(), pPlot:GetY());
				if (pFireSupportUnit ~= nil) then
					iTheirFireSupportCombatDamage = pFireSupportUnit:GetRangeCombatDamageVsUnit(pMyUnit, false);
				end
				
				iMyDamageInflicted = pMyUnit:GetCombatDamage(iMyStrength, iTheirStrength, pMyUnit:GetDamage() + iTheirFireSupportCombatDamage, false, false, true);
				iTheirDamageInflicted = pMyUnit:GetCombatDamage(iTheirStrength, iMyStrength, pStrategicSite:GetDamage(), false, true, false);
				iTheirDamageInflicted = iTheirDamageInflicted + iTheirFireSupportCombatDamage;
				
			end
			
			-- Site's max HP
			local maxSiteHitPoints = pStrategicSite:GetMaxHitPoints();
			if (iMyDamageInflicted > maxSiteHitPoints) then
				iMyDamageInflicted = maxSiteHitPoints;
			end
			-- Unit's max HP
			local maxUnitHitPoints = GameDefines["MAX_HIT_POINTS"];
			if (iTheirDamageInflicted > maxUnitHitPoints) then
				iTheirDamageInflicted = maxUnitHitPoints;
			end
			
			local bTheirCityLoss = false;
			local bMyUnitLoss = false;
			-- Will their Site be captured in combat?
			if (pStrategicSite:GetDamage() + iMyDamageInflicted >= maxSiteHitPoints) then
				bCityLoss = true;
			end
			-- Will my Unit die in combat?
			if (pMyUnit:GetDamage() + iTheirDamageInflicted >= maxUnitHitPoints) then
				bMyUnitLoss = true;
			end
			
			-- now do the health bars
			
			DoUpdateHealthBars(maxUnitHitPoints, maxSiteHitPoints, pMyUnit:GetDamage(), pStrategicSite:GetDamage(), iMyDamageInflicted, iTheirDamageInflicted)
			
			-- Now do text stuff
			
			local controlTable;
			local strText;
			
			Controls.GoodHeader:SetHide(true);
			Controls.BadHeader:SetHide(true);
			Controls.MehHeader:SetHide(true);

			local strMyDamageTextColor = "White_Black";
			local strTheirDamageTextColor = "White_Black";
			-- Ranged attack
			if (bRanged) then
				Controls.GoodHeader:SetHide(false);
				Controls.GoodLabel:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_INTERFACEMODE_RANGE_ATTACK")));
			-- Our unit is weak
			elseif (pMyUnit:GetDamage() > (maxUnitHitPoints / 2) and iTheirDamageInflicted > 0) then
				Controls.BadHeader:SetHide(false);
				Controls.BadLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_RISKY_ATTACK")));
			-- They are doing at least as much damage to us as we're doing to them
			elseif (iTheirDamageInflicted >= iMyDamageInflicted) then
				Controls.BadHeader:SetHide(false);
				Controls.BadLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_RISKY_ATTACK")));
			-- Safe (?) attack
			else
				Controls.GoodHeader:SetHide(false);
				Controls.GoodLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_SAFE_ATTACK")));
			end
				
			-- Ranged fire support
			if (iTheirFireSupportCombatDamage > 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_SUPPORT_DMG" );
				controlTable.Value:SetText( GetFormattedText( "", iTheirFireSupportCombatDamage, true, false ) );

				-- Also add an entry in their stack, so that the gaps match up
				controlTable = g_TheirCombatDataIM:GetInstance();
			end
			
			-- My Damage
			Controls.MyDamageValue:SetText("[COLOR_GREEN]" .. iMyDamageInflicted .. "[ENDCOLOR]");
			-- My Strength
			Controls.MyStrengthValue:SetText( Locale.ToNumber(iMyStrength / 100, "#.##"));
			
			-- Their Damage
			Controls.TheirDamageValue:SetText("[COLOR_RED]" .. iTheirDamageInflicted .. "[ENDCOLOR]");
			
			-- Their Strength
			Controls.TheirStrengthValue:SetText( Locale.ToNumber(iTheirStrength / 100, "#.##") );
			
			-- Attack Modifier
			local iModifier = pMyUnit:GetAttackModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_MOD_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- City Attack bonus
			if (bIsCity) then
				iModifier = pMyUnit:CityAttackModifier();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
				
					local textKey;
					if(iModifier >= 0) then
						textKey = "TXT_KEY_EUPANEL_ATTACK_CITIES";
					else
						textKey = "TXT_KEY_EUPANEL_ATTACK_CITIES_PENALTY";
					end
				
					controlTable.Text:LocalizeAndSetText( textKey );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			--TODO: Show bonus to their City from their National Security covert ops project

			-- Virtues Bonus
			iModifier = pMyPlayer:GetPolicyCombatModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VIRTUES" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Unused Moves
			iModifier = pMyUnit:GetPerUnusedMoveModifier();
			local iUnusedMoves = pMyUnit:GetUnusedMoves() / GameDefines["MOVE_DENOMINATOR"];
			if (iModifier ~= 0 and iUnusedMoves > 0) then
				iModifier = iModifier * iUnusedMoves;
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_UNUSED_MOVES_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
				
			if (not bRanged) then
			
				-- Crossing a River
				if (not pMyUnit:IsRiverCrossingNoPenalty()) then
					if (pMyUnit:GetPlot():IsRiverCrossingToPlot(pPlot)) then
						iModifier = GameDefines["RIVER_ATTACK_MODIFIER"];

						if (iModifier ~= 0) then
							controlTable = g_MyCombatDataIM:GetInstance();
							controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_OVER_RIVER" );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
						end
					end
				end
				

				-- Amphibious attack
				if (not pMyUnit:IsAmphibiousAttack()) then
					if (not pPlot:IsWater() and pMyUnit:GetPlot():IsWater() and pMyUnit:GetDomainType() == DomainTypes.DOMAIN_LAND) then
						iModifier = GameDefines["AMPHIB_ATTACK_MODIFIER"];

						if (iModifier ~= 0) then
							controlTable = g_MyCombatDataIM:GetInstance();
							controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_AMPHIBIOUS_ATTACK" );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
						end
					end
				end

				-- Miasma in our plot
				if (pMyUnit:GetPlot():HasMiasma()) then
					iModifier = pMyUnit:GetAttackWhileInMiasmaModifier();
					if (iModifier ~= 0) then
						controlTable = g_MyCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_WHILE_IN_MIASMA_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
					end
				end
				
			else
				iModifier = pMyUnit:GetRangedAttackModifier();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_RANGED_ATTACK_MODIFIER" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- Nearby orbital units modifier
			iModifier = pMyUnit:GetCombatModFromOrbitalUnits();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ORBITAL_UNITS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Inside City modifier
			iModifier = pMyUnit:CityModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_INSIDE_CITY" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- Nearby improvement modifier
			if (pMyUnit:GetNearbyImprovementModifier() ~= 0) then
				iModifier = pMyUnit:GetNearbyImprovementModifier();
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_IMPROVEMENT_NEAR" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Extra Combat Percent
			iModifier = pMyUnit:GetExtraCombatPercent();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EXTRA_PERCENT" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Extra Melee Combat Percent
			if (not bRanged) then
				iModifier = pMyUnit:GetExtraMeleeCombatPercent();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EXTRA_MELEE_PERCENT" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- Empire Health
			iModifier = pMyUnit:GetHealthCombatModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				if (iModifier < 0) then
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_UNHEALTHY" );
				else
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_HEALTHY" );
				end
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Hovering
			iModifier = pMyUnit:GetHoveringCombatModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_HOVERING" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Lack Strategic Resources
			iModifier = pMyUnit:GetStrategicResourceCombatPenalty();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_STRATEGIC_RESOURCE" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- Adjacent Modifier
			iModifier = pMyUnit:GetAdjacentModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ADJACENT_FRIEND_UNIT_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- No Adjacent Friendly Modifier
			iModifier = pMyUnit:GetNoAdjacentFriendlyModifier();
			if (iModifier ~= 0) then
				local bCombatUnit = true;
				if (not pMyUnit:IsFriendlyUnitAdjacent(bCombatUnit)) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_NO_ADJACENT_FRIEND_UNIT_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- Policy Attack bonus
			local iTurns = pMyPlayer:GetAttackBonusTurns();
			if (iTurns > 0) then
				iModifier = GameDefines["POLICY_ATTACK_BONUS_MOD"];
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_POLICY_ATTACK_BONUS", iTurns );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			---------------------------
			-- AIR INTERCEPT PREVIEW --
			---------------------------
			if (bInterceptPossible) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_AIR_INTERCEPT_WARNING1");
				controlTable.Value:SetText("");
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_AIR_INTERCEPT_WARNING2");
				controlTable.Value:SetText("");
			end
			if (iNumVisibleAAUnits > 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_VISIBLE_AA_UNITS", iNumVisibleAAUnits);
				controlTable.Value:SetText("");
			end
		end
	end

	ResizeAllContents();
end

-- ===========================================================================
--		Unit vs Unit
-- ===========================================================================
function UpdateCombatOddsUnitVsUnit(pMyUnit, pTheirUnit)

	g_MyCombatDataIM:ResetInstances();
	g_TheirCombatDataIM:ResetInstances();
	
	if (pMyUnit ~= nil) then
		
		local iMyPlayer = pMyUnit:GetOwner();
		local iTheirPlayer = pTheirUnit:GetOwner();
		local pMyPlayer = Players[iMyPlayer];
		local pTheirPlayer = Players[iTheirPlayer];
		
		local iMyStrength = 0;
		local iTheirStrength = 0;
		local bRanged = false;
		local iNumVisibleAAUnits = 0;
		local bInterceptPossible = false;
		
		local pFromPlot = pMyUnit:GetPlot();
		local pToPlot = pTheirUnit:GetPlot();
		
		-- Ranged Unit
		if (pMyUnit:IsRanged()) then
			iMyStrength = pMyUnit:GetMaxRangedCombatStrengthVsUnit(pTheirUnit, true, true);
			bRanged = true;
				
		-- Melee Unit
		else
			iMyStrength = pMyUnit:GetMaxAttackStrength(pFromPlot, pToPlot, pTheirUnit);
		end
		
		if (iMyStrength > 0) then
			
			-- Start with logic of combat estimation
			local iMyDamageInflicted = 0;
			local iTheirDamageInflicted = 0;
			local iTheirFireSupportCombatDamage = 0;
			
			-- Ranged Strike
			if (bRanged) then
				
				iMyDamageInflicted = pMyUnit:GetRangeCombatDamageVsUnit(pTheirUnit, false);
				
				iTheirStrength = pTheirUnit:GetRangeCombatDefenseVsUnit(pMyUnit);
				
				if (pMyUnit:GetDomainType() == DomainTypes.DOMAIN_AIR) then
					iMyDamageInflicted = pMyUnit:GetAirCombatDamage(pTheirUnit, false, nil);
					iTheirDamageInflicted = pTheirUnit:GetAirStrikeDefenseDamage(pMyUnit, false);
					iNumVisibleAAUnits = pMyUnit:GetInterceptorCount(pToPlot, pTheirUnit, true, true);		
					bInterceptPossible = true;
				end
				
			-- Normal Melee Combat
			else
				
				iTheirStrength = pTheirUnit:GetMaxDefenseStrength(pToPlot, pMyUnit);
				
				local pFireSupportUnit = pMyUnit:GetFireSupportUnit(pTheirUnit:GetOwner(), pToPlot:GetX(), pToPlot:GetY());
				if (pFireSupportUnit ~= nil) then
					iTheirFireSupportCombatDamage = pFireSupportUnit:GetRangeCombatDamageVsUnit(pMyUnit, false);
				end
				
				iMyDamageInflicted = pMyUnit:GetCombatDamage(iMyStrength, iTheirStrength, pMyUnit:GetDamage() + iTheirFireSupportCombatDamage, false, false, false);
				iTheirDamageInflicted = pTheirUnit:GetCombatDamage(iTheirStrength, iMyStrength, pTheirUnit:GetDamage(), false, false, false);
				iTheirDamageInflicted = iTheirDamageInflicted + iTheirFireSupportCombatDamage;
				
			end
			
			-- Don't give numbers greater than a Unit's max HP
			if (iMyDamageInflicted > maxUnitHitPoints) then
				iMyDamageInflicted = maxUnitHitPoints;
			end
			if (iTheirDamageInflicted > maxUnitHitPoints) then
				iTheirDamageInflicted = maxUnitHitPoints;
			end
			
			-- now do the health bars
			
			DoUpdateHealthBars(maxUnitHitPoints, maxUnitHitPoints, pMyUnit:GetDamage(), pTheirUnit:GetDamage(), iMyDamageInflicted, iTheirDamageInflicted)

			-- Now do text stuff
			
			local controlTable;
			local strText;
				
			Controls.GoodHeader:SetHide(true);
			Controls.BadHeader:SetHide(true);
			Controls.MehHeader:SetHide(true);

			local eCombatPrediction = Game.GetCombatPrediction(pMyUnit, pTheirUnit);
			
			if (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_RANGED) then
				Controls.GoodHeader:SetHide(false);
				Controls.GoodLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_INTERFACEMODE_RANGE_ATTACK")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_STALEMATE) then
				Controls.BadHeader:SetHide(false);
				Controls.BadLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_STALEMATE")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_TOTAL_DEFEAT) then
				Controls.BadHeader:SetHide(false);
				Controls.BadLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_TOTAL_DEFEAT")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_TOTAL_VICTORY) then
				Controls.GoodHeader:SetHide(false);
				Controls.GoodLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_TOTAL_VICTORY")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_MAJOR_VICTORY) then
				Controls.GoodHeader:SetHide(false);
				Controls.GoodLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_MAJOR_VICTORY")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_SMALL_VICTORY) then
				Controls.GoodHeader:SetHide(false);
				Controls.GoodLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_MINOR_VICTORY")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_MAJOR_DEFEAT) then
				Controls.BadHeader:SetHide(false);
				Controls.BadLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_MAJOR_DEFEAT")) );
			elseif (eCombatPrediction == CombatPredictionTypes.COMBAT_PREDICTION_SMALL_DEFEAT) then
				Controls.BadHeader:SetHide(false);
				Controls.BadLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_MINOR_DEFEAT")) );
			else
				Controls.MehHeader:SetHide(false);
				Controls.MehLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_STALEMATE")) );
			end

			local strMyDamageTextColor 		= "White_Black";
			local strTheirDamageTextColor 	= "White_Black";
			
			-- Ranged fire support
			if (iTheirFireSupportCombatDamage > 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_SUPPORT_DMG");
				controlTable.Value:SetText( GetFormattedText(strText, iTheirFireSupportCombatDamage, true, false) );

				-- Also add an entry in their stack, so that the gaps match up
				controlTable = g_TheirCombatDataIM:GetInstance();
			end
						
			-- My Damage
			Controls.MyDamageValue:SetText("[COLOR_GREEN]" .. iMyDamageInflicted .. "[ENDCOLOR]");
			
			-- My Strength
			Controls.MyStrengthValue:SetText( Locale.ToNumber(iMyStrength / 100, "#.##"));
			
			----------------------------------------------------------------------------
			-- BONUSES MY UNIT GETS
			----------------------------------------------------------------------------

			local iModifier;
			
			if (not bRanged) then
				
				-- Crossing a River
				if (not pMyUnit:IsRiverCrossingNoPenalty()) then
					if (pMyUnit:GetPlot():IsRiverCrossingToPlot(pToPlot)) then
						iModifier = GameDefines["RIVER_ATTACK_MODIFIER"];

						if (iModifier ~= 0) then
							controlTable = g_MyCombatDataIM:GetInstance();
							controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_OVER_RIVER" );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
						end
					end
				end
				
				-- Amphibious attack
				if (not pMyUnit:IsAmphibiousAttack()) then
					if (not pToPlot:IsWater() and pMyUnit:GetPlot():IsWater() and pMyUnit:GetDomainType() == DomainTypes.DOMAIN_LAND) then
						iModifier = GameDefines["AMPHIB_ATTACK_MODIFIER"];

						if (iModifier ~= 0) then
							controlTable = g_MyCombatDataIM:GetInstance();
							controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_AMPHIBIOUS_ATTACK" );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
						end
					end
				end

				-- Miasma in our plot
				if (pMyUnit:GetPlot():HasMiasma()) then
					iModifier = pMyUnit:GetAttackWhileInMiasmaModifier();
					if (iModifier ~= 0) then
						controlTable = g_MyCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_WHILE_IN_MIASMA_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
					end
				end
				
			end

			-- Nearby orbital units modifier
			iModifier = pMyUnit:GetCombatModFromOrbitalUnits();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ORBITAL_UNITS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Inside City modifier
			iModifier = pMyUnit:CityModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_INSIDE_CITY" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- Nearby improvement modifier
			if (pMyUnit:GetNearbyImprovementModifier() ~= 0) then
				iModifier = pMyUnit:GetNearbyImprovementModifier();
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_IMPROVEMENT_NEAR" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- Policy Attack bonus
			local iTurns = pMyPlayer:GetAttackBonusTurns();
			if (iTurns > 0) then
				iModifier = GameDefines["POLICY_ATTACK_BONUS_MOD"];
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_POLICY_ATTACK_BONUS", iTurns );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- Flanking bonus
			if (not bRanged) then
				iModifier = pMyUnit:FlankModifier(pTheirUnit);
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FLANKING_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- Extra Combat Percent
			iModifier = pMyUnit:GetExtraCombatPercent();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EXTRA_PERCENT" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Extra Melee Combat Percent
			if (not bRanged) then
				iModifier = pMyUnit:GetExtraMeleeCombatPercent();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EXTRA_MELEE_PERCENT" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- Bonus for fighting in one's lands
			if (pToPlot:IsFriendlyTerritory(c)) then
				
				-- General combat mod
				iModifier = pMyUnit:GetFriendlyLandsModifier();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FIGHT_AT_HOME_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
				
				-- Attack mod
				iModifier = pMyUnit:GetFriendlyLandsAttackModifier();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_IN_FRIEND_LANDS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
				
				iModifier = pMyPlayer:GetFoundedReligionFriendlyCityCombatMod(pToPlot);
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FRIENDLY_CITY_BELIEF_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- CombatBonusVsHigherTech
			if (pToPlot:GetOwner() == iMyPlayer) then
				iModifier = pMyPlayer:GetCombatBonusVsHigherTech();

				if (iModifier ~= 0 and pTheirUnit:IsHigherTechThan(pMyUnit:GetUnitType())) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TRAIT_LOW_TECH_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
					
			-- CombatBonusVsLargerCiv
			iModifier = pMyPlayer:GetCombatBonusVsLargerCiv();
			if (iModifier ~= 0 and pTheirUnit:IsLargerCivThan(pMyUnit)) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TRAIT_SMALL_SIZE_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
					
			-- CapitalDefenseModifier
			iModifier = pMyUnit:CapitalDefenseModifier();
			if (iModifier > 0) then
				
				-- Compute distance to capital
				local pCapital = pMyPlayer:GetCapitalCity();
					
				if (pCapital ~= nil) then

					local plotDistance = Map.PlotDistance(pCapital:GetX(), pCapital:GetY(), pMyUnit:GetX(), pMyUnit:GetY());
					iModifier = iModifier + (plotDistance * pMyUnit:CapitalDefenseFalloff());

					if (iModifier > 0) then
						controlTable = g_MyCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_CAPITAL_DEFENSE_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
					end
				end
			end
			
			-- Bonus for fighting outside one's lands
			if (not pToPlot:IsFriendlyTerritory(iMyPlayer)) then
				
				-- General combat mod
				iModifier = pMyUnit:GetOutsideFriendlyLandsModifier();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_OUTSIDE_HOME_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
				
				iModifier = pMyPlayer:GetFoundedReligionEnemyCityCombatMod(pToPlot);
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ENEMY_CITY_BELIEF_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- Empire Health
			iModifier = pMyUnit:GetHealthCombatModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				if (iModifier < 0) then
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_UNHEALTHY" );
				else
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_HEALTHY" );
				end
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Hovering
			iModifier = pMyUnit:GetHoveringCombatModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_HOVERING" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Lack Strategic Resources
			iModifier = pMyUnit:GetStrategicResourceCombatPenalty();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_STRATEGIC_RESOURCE" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- Adjacent Modifier
			iModifier = pMyUnit:GetAdjacentModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ADJACENT_FRIEND_UNIT_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- No Adjacent Friendly Modifier
			iModifier = pMyUnit:GetNoAdjacentFriendlyModifier();
			if (iModifier ~= 0) then
				local bCombatUnit = true;
				if (not pMyUnit:IsFriendlyUnitAdjacent(bCombatUnit)) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_NO_ADJACENT_FRIEND_UNIT_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- Attack Modifier
			iModifier = pMyUnit:GetAttackModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_MOD_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Attack Modifier from carrier
			if (pMyUnit:IsCargo()) then
				local pCarrier = pMyUnit:GetTransportUnit();
				if (pCarrier ~= nil) then
					iModifier = pCarrier:GetAttackForOnboardModifier();
					if (iModifier ~= 0) then
						controlTable = g_MyCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_CARRIER_ATTACK_MOD_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
					end
				end
			end

			-- UnitClassModifier
			iModifier = pMyUnit:GetUnitClassModifier(pTheirUnit:GetUnitClassType());
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				local unitClassType = GameInfo.UnitClasses[pTheirUnit:GetUnitClassType()].Description;
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_CLASS", unitClassType );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- UnitClassAttackModifier
			iModifier = pMyUnit:UnitClassAttackModifier(pTheirUnit:GetUnitClassType());
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				local unitClassType = GameInfo.UnitClasses[pTheirUnit:GetUnitClassType()].Description;
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_CLASS" , unitClassType );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- UnitCombatModifier
			if (pTheirUnit:GetUnitCombatType() ~= -1) then
				iModifier = pMyUnit:UnitCombatModifier(pTheirUnit:GetUnitCombatType());

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					local unitClassType = GameInfo.UnitCombatInfos[pTheirUnit:GetUnitCombatType()].Description;
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_CLASS", unitClassType );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- DomainModifier
			iModifier = pMyUnit:DomainModifier(pTheirUnit:GetDomainType());
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				local domainInfo = GameInfo.Domains[pTheirUnit:GetDomainType()];
				if (domainInfo ~= nil and domainInfo.Description ~= nil) then
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_DOMAIN_SPECIFIC", domainInfo.Description );
				else
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_DOMAIN" );
				end
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
			
			-- attackFortifiedMod
			if (pTheirUnit:GetFortifyTurns() > 0) then
				iModifier = pMyUnit:AttackFortifiedModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_FORT_UNITS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- AttackWoundedMod
			if (pTheirUnit:GetDamage() > 0) then
				iModifier = pMyUnit:AttackWoundedModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_VS_WOUND_UNITS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- HillsAttackModifier
			if (pToPlot:IsHills()) then
				iModifier = pMyUnit:HillsAttackModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_HILL_ATTACK_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			if (pToPlot:IsOpenGround()) then
			
				-- OpenAttackModifier
				iModifier = pMyUnit:OpenAttackModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_OPEN_TERRAIN_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
				
				-- OpenRangedAttackModifier
				iModifier = pMyUnit:OpenRangedAttackModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_OPEN_TERRAIN_RANGE_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			if(bRanged) then
				iModifier = pMyUnit:GetRangedAttackModifier();
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_RANGED_ATTACK_MODIFIER" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			if (pToPlot:IsRoughGround()) then
			
				-- RoughAttackModifier
				iModifier = pMyUnit:RoughAttackModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ROUGH_TERRAIN_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			
				-- RoughRangedAttackModifier
				iModifier = pMyUnit:RoughRangedAttackModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ROUGH_TERRAIN_RANGED_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			if (pToPlot:GetFeatureType() ~= -1) then
			
				-- FeatureAttackModifier
				iModifier = pMyUnit:FeatureAttackModifier(pToPlot:GetFeatureType());
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					local featureTypeBonus = Locale.ConvertTextKey(GameInfo.Features[pToPlot:GetFeatureType()].Description);
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_INTO_BONUS", featureTypeBonus );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- TerrainAttackModifier		
			iModifier = pMyUnit:TerrainAttackModifier(pToPlot:GetTerrainType());
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				local terrainTypeBonus = Locale.ConvertTextKey( GameInfo.Terrains[pToPlot:GetTerrainType()].Description );
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_INTO_BONUS", terrainTypeBonus  );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
				
			if (pToPlot:IsHills()) then
				iModifier = pMyUnit:TerrainAttackModifier(GameInfo.Terrains["TERRAIN_HILL"].ID);
				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					local terrainTypeBonus = Locale.ConvertTextKey( GameInfo.Terrains["TERRAIN_HILL"].Description );
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ATTACK_INTO_BONUS", terrainTypeBonus  );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
			
			-- Alien Bonus
			if (pTheirUnit:IsAlien()) then
				iModifier = GameInfo.HandicapInfos[Game:GetHandicapType()].AlienCombatBonus;
				
				iModifier = iModifier + Players[pMyUnit:GetOwner()]:GetBarbarianCombatBonus();
				iModifier = iModifier + pMyUnit:GetAlienCombatModifier();

				if (iModifier ~= 0) then
					controlTable = g_MyCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_VS_ALIENS_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end

			-- Civ Trait Bonus
			iModifier = pMyPlayer:GetTraitEraOfProsperityCombatModifier();
			if (iModifier ~= 0 and pMyPlayer:IsEraOfProsperity()) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_ERA_OF_PROSPERITY" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Virtues Bonus
			iModifier = pMyPlayer:GetPolicyCombatModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VIRTUES" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			-- Unused Moves
			iModifier = pMyUnit:GetPerUnusedMoveModifier();
			local iUnusedMoves = pMyUnit:GetUnusedMoves() / GameDefines["MOVE_DENOMINATOR"];
			if (iModifier ~= 0 and iUnusedMoves > 0) then
				iModifier = iModifier * iUnusedMoves;
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_UNUSED_MOVES_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			iModifier = pMyPlayer:GetTraitCityStateCombatModifier();
			if (iModifier ~= 0 and pTheirPlayer:IsMinorCiv()) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_CITY_STATE" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end

			----------------------------------------------------------------------------
			-- BONUSES THEIR UNIT GETS
			----------------------------------------------------------------------------
			
			-- Their Damage
			Controls.TheirDamageValue:SetText("[COLOR_RED]" .. iTheirDamageInflicted .. "[ENDCOLOR]");
			
			-- Their Strength
			Controls.TheirStrengthValue:SetText( Locale.ToNumber(iTheirStrength / 100, "#.##"));
			
			if (pTheirUnit:IsCombatUnit()) then

				-- Empire Health
				iModifier = pTheirUnit:GetHealthCombatModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					if (iModifier < 0) then
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_UNHEALTHY" );
					else
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_HEALTHY" );
					end
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- Hovering
				iModifier = pTheirUnit:GetHoveringCombatModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_HOVERING" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- Lack Strategic Resources
				iModifier = pTheirUnit:GetStrategicResourceCombatPenalty();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_STRATEGIC_RESOURCE" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
				
				-- Adjacent Modifier
				iModifier = pTheirUnit:GetAdjacentModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_ADJACENT_FRIEND_UNIT_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- No Adjacent Friendly Modifier
				iModifier = pTheirUnit:GetNoAdjacentFriendlyModifier();
				if (iModifier ~= 0) then
					local bCombatUnit = true;
					if (not pTheirUnit:IsFriendlyUnitAdjacent(bCombatUnit)) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_NO_ADJACENT_FRIEND_UNIT_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
					end
				end

				-- Plot Defense
				iModifier = pToPlot:DefenseModifier(pTheirUnit:GetTeam(), false, false);
				if (iModifier < 0 or not pTheirUnit:NoDefensiveBonus()) then

					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TERRAIN_MODIFIER" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
	--					strString.append(GetLocalizedText("TXT_KEY_COMBAT_PLOT_TILE_MOD", iModifier));
					end
				end

				-- FortifyModifier
				iModifier = pTheirUnit:FortifyModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_FORTIFICATION_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
	--				strString.append(GetLocalizedText("TXT_KEY_COMBAT_PLOT_FORTIFY_MOD", iModifier));
				end

				-- Miasma in their plot
				if (pTheirUnit:GetPlot():HasMiasma()) then
					iModifier = pTheirUnit:GetDefendWhileInMiasmaModifier();
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_WHILE_IN_MIASMA_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
					end
				end
				
				-- Great General bonus
				if (pTheirUnit:IsNearGreatGeneral()) then
					iModifier = pTheirPlayer:GetGreatGeneralCombatBonus();
					iModifier = iModifier + pTheirPlayer:GetTraitGreatGeneralExtraBonus();
					controlTable = g_TheirCombatDataIM:GetInstance();
					if (pTheirUnit:GetDomainType() == DomainTypes.DOMAIN_LAND) then
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_GG_NEAR" );
					else
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_GA_NEAR" );
					end
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					
					-- Ignores Great General penalty
					if (pTheirUnit:IsIgnoreGreatGeneralBenefit()) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_IGG");
						controlTable.Value:SetText(GetFormattedText(strText, -iModifier, false, true));
					end
				end
				
				-- Great General stack bonus
				if (pTheirUnit:GetGreatGeneralCombatModifier() ~= 0 and pTheirUnit:IsStackedGreatGeneral()) then
					iModifier = pTheirUnit:GetGreatGeneralCombatModifier();
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_GG_STACKED" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
				
				-- Reverse Great General bonus
				if (pTheirUnit:GetReverseGreatGeneralModifier() ~= 0) then
					iModifier = pTheirUnit:GetReverseGreatGeneralModifier();
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_REVERSE_GG_NEAR" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end 

				-- Nearby orbital units modifier
				iModifier = pTheirUnit:GetCombatModFromOrbitalUnits();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ORBITAL_UNITS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- Inside City modifier
				iModifier = pTheirUnit:CityModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_INSIDE_CITY" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
				
				-- Nearby improvement modifier
				if (pTheirUnit:GetNearbyImprovementModifier() ~= 0) then
					iModifier = pTheirUnit:GetNearbyImprovementModifier();
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_IMPROVEMENT_NEAR" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
				
				-- Flanking bonus
				if (not bRanged) then
					iModifier = pTheirUnit:FlankModifier(pMyUnit);
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_FLANKING_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
				
				-- ExtraCombatPercent
				iModifier = pTheirUnit:GetExtraCombatPercent();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_EXTRA_PERCENT" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
	--				strString.append(GetLocalizedText("TXT_KEY_COMBAT_PLOT_EXTRA_STRENGTH", iModifier));
				end

				-- Extra Melee Combat Percent
				if (not bRanged) then
					iModifier = pTheirUnit:GetExtraMeleeCombatPercent();
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_EXTRA_MELEE_PERCENT" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end

				-- Bonus for fighting in one's lands
				if (pToPlot:IsFriendlyTerritory(iTheirPlayer)) then
					iModifier = pTheirUnit:GetFriendlyLandsModifier();
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FIGHT_AT_HOME_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
					
					iModifier = pTheirPlayer:GetFoundedReligionFriendlyCityCombatMod(pToPlot);
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FRIENDLY_CITY_BELIEF_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
				
				-- Bonus for fighting outside one's lands
				if (not pToPlot:IsFriendlyTerritory(iTheirPlayer)) then
					
					-- General combat mod
					iModifier = pTheirUnit:GetOutsideFriendlyLandsModifier();
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_OUTSIDE_HOME_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
					
					iModifier = pTheirPlayer:GetFoundedReligionEnemyCityCombatMod(pToPlot);
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ENEMY_CITY_BELIEF_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
				
				-- Defense Modifier
				local iModifier = pTheirUnit:GetDefenseModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_DEFENSE_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- Defense Modifier from carrier
				if (pTheirUnit:IsCargo()) then
					local pCarrier = pTheirUnit:GetTransportUnit();
					if (pCarrier ~= nil) then
						iModifier = pCarrier:GetDefendForOnboardModifier();
						if (iModifier ~= 0) then
							controlTable = g_TheirCombatDataIM:GetInstance();
							controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_CARRIER_DEFENSE_BONUS" );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
						end
					end
				end

				-- Defense Modifier against ranged
				if (bRanged) then
					iModifier = pTheirUnit:GetRangedDefenseModifier();
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_RANGED_DEFENSE_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end

				-- UnitClassDefenseModifier
				iModifier = pTheirUnit:UnitClassDefenseModifier(pMyUnit:GetUnitClassType());
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					local unitClassBonus = Locale.ConvertTextKey(GameInfo.UnitClasses[pMyUnit:GetUnitClassType()].Description);
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VS_CLASS", unitClassBonus );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- UnitCombatModifier
				if (pMyUnit:GetUnitCombatType() ~= -1) then
					iModifier = pTheirUnit:UnitCombatModifier(pMyUnit:GetUnitCombatType());

					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						local unitClassType = Locale.ConvertTextKey(GameInfo.UnitCombatInfos[pMyUnit:GetUnitCombatType()].Description);
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VS_CLASS", unitClassType );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end

				-- DomainModifier
				iModifier = pTheirUnit:DomainModifier(pMyUnit:GetDomainType());
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					local domainInfo = GameInfo.Domains[pMyUnit:GetDomainType()];
					if (domainInfo ~= nil and domainInfo.Description ~= nil) then
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VS_DOMAIN_SPECIFIC", domainInfo.Description );
					else
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VS_DOMAIN" );
					end
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
				
				-- HillsDefenseModifier
				if (pToPlot:IsHills()) then
					iModifier = pTheirUnit:HillsDefenseModifier();

					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_HILL_DEFENSE_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
				
				-- OpenDefenseModifier
				if (pToPlot:IsOpenGround()) then
					iModifier = pTheirUnit:OpenDefenseModifier();

					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_OPEN_TERRAIN_DEF_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
				
				-- RoughDefenseModifier
				if (pToPlot:IsRoughGround()) then
					iModifier = pTheirUnit:RoughDefenseModifier();

					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_ROUGH_TERRAIN_DEF_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
	
				-- CombatBonusVsHigherTech
				if (pToPlot:GetOwner() == iTheirPlayer) then
					iModifier = pTheirPlayer:GetCombatBonusVsHigherTech();

					if (iModifier ~= 0 and pMyUnit:IsHigherTechThan(pTheirUnit:GetUnitType())) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TRAIT_LOW_TECH_BONUS" );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				end
				
				-- CombatBonusVsLargerCiv
				iModifier = pTheirPlayer:GetCombatBonusVsLargerCiv();
				if (iModifier ~= 0 and pMyUnit:IsLargerCivThan(pTheirUnit)) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TRAIT_SMALL_SIZE_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
								
				-- CapitalDefenseModifier
				iModifier = pTheirUnit:CapitalDefenseModifier();
				if (iModifier > 0) then
				
					-- Compute distance to capital
					local pCapital = pTheirPlayer:GetCapitalCity();
					
					if (pCapital ~= nil) then

						local plotDistance = Map.PlotDistance(pCapital:GetX(), pCapital:GetY(), pTheirUnit:GetX(), pTheirUnit:GetY());
						iModifier = iModifier + (plotDistance * pTheirUnit:CapitalDefenseFalloff());

						if (iModifier > 0) then
							controlTable = g_TheirCombatDataIM:GetInstance();
							controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_CAPITAL_DEFENSE_BONUS" );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
						end
					end
				end
		
				if (pToPlot:GetFeatureType() ~= -1) then
				
					-- FeatureDefenseModifier
					iModifier = pTheirUnit:FeatureDefenseModifier(pToPlot:GetFeatureType());
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						local typeBonus = Locale.ConvertTextKey(GameInfo.Features[pToPlot:GetFeatureType()].Description);
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_DEFENSE_TERRAIN", typeBonus );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
				else
				
					-- TerrainDefenseModifier		
					iModifier = pTheirUnit:TerrainDefenseModifier(pToPlot:GetTerrainType());
					if (iModifier ~= 0) then
						controlTable = g_TheirCombatDataIM:GetInstance();
						local typeBonus = Locale.ConvertTextKey(GameInfo.Terrains[pToPlot:GetTerrainType()].Description);
						controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_DEFENSE_TERRAIN", typeBonus );
						controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
					end
					
					if (pToPlot:IsHills()) then
						iModifier = pTheirUnit:TerrainDefenseModifier(GameInfo.Terrains["TERRAIN_HILL"].ID);
						if (iModifier ~= 0) then
							controlTable = g_TheirCombatDataIM:GetInstance();
							local terrainTypeBonus = Locale.ConvertTextKey( GameInfo.Terrains["TERRAIN_HILL"].Description );
							controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_DEFENSE_TERRAIN", terrainTypeBonus  );
							controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
						end
					end
				end
						
				-- Civ Trait Bonus
				iModifier = pTheirPlayer:GetTraitEraOfProsperityCombatModifier();
				if (iModifier ~= 0 and pTheirPlayer:IsEraOfProsperity()) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_ERA_OF_PROSPERITY" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- Virtues Bonus
				iModifier = pTheirPlayer:GetPolicyCombatModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VIRTUES" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end

				-- Unused Moves
				iModifier = pTheirUnit:GetPerUnusedMoveModifier();
				local iUnusedMoves = pTheirUnit:GetUnusedMoves() / GameDefines["MOVE_DENOMINATOR"];
				if (iModifier ~= 0 and iUnusedMoves > 0) then
					iModifier = iModifier * iUnusedMoves;
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_UNUSED_MOVES_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
			end
			
			--------------------------
			-- AIR INTERCEPT PREVIEW --
			--------------------------
			if (bInterceptPossible) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_AIR_INTERCEPT_WARNING1");
				controlTable.Value:SetText("");
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_AIR_INTERCEPT_WARNING2");
				controlTable.Value:SetText("");
			end
			if (iNumVisibleAAUnits > 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_VISIBLE_AA_UNITS", iNumVisibleAAUnits);
				controlTable.Value:SetText("");
			end
		end
	end

	ResizeAllContents();
end


-- ===========================================================================
--		City vs Unit
-- ===========================================================================
function UpdateCombatOddsCityVsUnit(myCity, theirUnit)
	
	-- Reset bonuses
	g_MyCombatDataIM:ResetInstances();
	g_TheirCombatDataIM:ResetInstances();
	
	--Set Initial Values
	local myCityMaxHP = myCity:GetMaxHitPoints();
	local myCityCurHP = myCity:GetDamage();
	local myCityDamageInflicted = myCity:RangeCombatDamage(theirUnit, nil);
	local myCityStrength = myCity:GetStrengthValueWhenAttackingUnit(theirUnit);

	local bRanged = true;
	
	local theirUnitMaxHP = GameDefines["MAX_HIT_POINTS"];
	local theirUnitCurHP = theirUnit:GetDamage();
	local theirUnitDamageInflicted = 0;
	local theirUnitStrength = myCity:RangeCombatUnitDefense(theirUnit);
	local iTheirPlayer = theirUnit:GetOwner();
	local pTheirPlayer = Players[iTheirPlayer];

	if (myCityDamageInflicted > theirUnitMaxHP) then
		myCityDamageInflicted = theirUnitMaxHP;
	end
				
	-- City vs Unit is ranged attack
	--Controls.RangedAttackIndicator:SetHide(false);
	--Controls.RangedAttackButtonLabel:SetText(Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_INTERFACEMODE_RANGE_ATTACK")));
	Controls.DetailsGrid:SetHide(false);
		
	-- Their Damage
	Controls.TheirDamageValue:SetText("[COLOR_RED]" .. theirUnitDamageInflicted .. "[ENDCOLOR]");
	
	-- Their Strength
	Controls.TheirStrengthValue:SetText( Locale.ToNumber(theirUnitStrength / 100, "#.##"));

	-- My Damage
	Controls.MyDamageValue:SetText("[COLOR_GREEN]" .. myCityDamageInflicted .. "[ENDCOLOR]");
	
	-- My Strength
	Controls.MyStrengthValue:SetText( Locale.ToNumber(myCityStrength / 100, "#.##"));
	
	DoUpdateHealthBars(myCityMaxHP, theirUnitMaxHP, myCityCurHP, theirUnitCurHP, myCityDamageInflicted, theirUnitDamageInflicted);

	Controls.BadHeader:SetHide(true);
	Controls.GoodHeader:SetHide(true);
	Controls.MehHeader:SetHide(true);

			
	-- Show some bonuses
	if (theirUnit:IsCombatUnit()) then

		local myPlayerID	= myCity:GetOwner();
		local myPlayer		= Players[myPlayerID];		
		local theirPlayerID = theirUnit:GetOwner();
		local theirPlayer	= Players[theirPlayerID];		
		local theirPlot		= theirUnit:GetPlot();
		
		local controlTable	= nil;

		-- Empire Health
		iModifier = theirUnit:GetHealthCombatModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			if (iModifier < 0) then
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_UNHEALTHY" );
			else
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_EMPIRE_HEALTHY" );
			end
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- Hovering
		iModifier = theirUnit:GetHoveringCombatModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_HOVERING" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- Lack Strategic Resources
		iModifier = theirUnit:GetStrategicResourceCombatPenalty();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_STRATEGIC_RESOURCE" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end
		
		-- Adjacent Modifier
		iModifier = theirUnit:GetAdjacentModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_ADJACENT_FRIEND_UNIT_BONUS" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- No Adjacent Friendly Modifier
		iModifier = theirUnit:GetNoAdjacentFriendlyModifier();
		if (iModifier ~= 0) then
			local bCombatUnit = true;
			if (not theirUnit:IsFriendlyUnitAdjacent(bCombatUnit)) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_NO_ADJACENT_FRIEND_UNIT_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
		end
		
		-- Plot Defense
		iModifier = theirPlot:DefenseModifier(theirUnit:GetTeam(), false, false);
		if (iModifier < 0 or not theirUnit:NoDefensiveBonus()) then
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TERRAIN_MODIFIER" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end

		-- FortifyModifier
		iModifier = theirUnit:FortifyModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_FORTIFICATION_BONUS" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
--				strString.append(GetLocalizedText("TXT_KEY_COMBAT_PLOT_FORTIFY_MOD", iModifier));
		end

		-- Miasma in their plot
		if (theirUnit:GetPlot():HasMiasma()) then
			iModifier = theirUnit:GetDefendWhileInMiasmaModifier();
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_WHILE_IN_MIASMA_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
		end
		
		---- Great General bonus
		--if (theirUnit:IsNearGreatGeneral()) then
			--iModifier = theirPlayer:GetGreatGeneralCombatBonus();
			--iModifier = iModifier + theirPlayer:GetTraitGreatGeneralExtraBonus();
			--controlTable = g_TheirCombatDataIM:GetInstance();
			--if (theirUnit:GetDomainType() == DomainTypes.DOMAIN_LAND) then
				--controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_GG_NEAR" );
			--else
				--controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_GA_NEAR" );
			--end
			--controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			--
			---- Ignores Great General penalty
			--if (theirUnit:IsIgnoreGreatGeneralBenefit()) then
				--controlTable = g_TheirCombatDataIM:GetInstance();
				--controlTable.Text:LocalizeAndSetText("TXT_KEY_EUPANEL_IGG");
				--controlTable.Value:SetText(GetFormattedText(strText, -iModifier, false, true));
			--end
		--end
		--
		---- Great General stacked bonus
		--if (theirUnit:GetGreatGeneralCombatModifier() ~= 0 and theirUnit:IsStackedGreatGeneral()) then
			--iModifier = theirUnit:GetGreatGeneralCombatModifier();
			--controlTable = g_TheirCombatDataIM:GetInstance();
			--controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_GG_STACKED" );
			--controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		--end

		-- Nearby orbital units modifier
		iModifier = theirUnit:GetCombatModFromOrbitalUnits();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ORBITAL_UNITS" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- Inside City modifier
		iModifier = theirUnit:CityModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_INSIDE_CITY" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end
		
		-- ExtraCombatPercent
		iModifier = theirUnit:GetExtraCombatPercent();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_EXTRA_PERCENT" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
--				strString.append(GetLocalizedText("TXT_KEY_COMBAT_PLOT_EXTRA_STRENGTH", iModifier));
		end

		-- Bonus for fighting in one's lands
		if (theirPlot:IsFriendlyTerritory(iTheirPlayer)) then
			iModifier = theirUnit:GetFriendlyLandsModifier();
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FIGHT_AT_HOME_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
	
			iModifier = pTheirPlayer:GetFoundedReligionFriendlyCityCombatMod(theirPlot);
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_FRIENDLY_CITY_BELIEF_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end
		
		-- Bonus for fighting outside one's lands
		if (not theirPlot:IsFriendlyTerritory(iTheirPlayer)) then
			
			-- General combat mod
			iModifier = theirUnit:GetOutsideFriendlyLandsModifier();
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_OUTSIDE_HOME_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
			
			iModifier = pTheirPlayer:GetFoundedReligionEnemyCityCombatMod(theirPlot);
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_ENEMY_CITY_BELIEF_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end
		
		-- Defense Modifier
		local iModifier = theirUnit:GetDefenseModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_DEFENSE_BONUS" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- Defense Modifier from carrier
		if (theirUnit:IsCargo()) then
			local pCarrier = theirUnit:GetTransportUnit();
			if (pCarrier ~= nil) then
				iModifier = pCarrier:GetDefendForOnboardModifier();
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_CARRIER_DEFENSE_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
			end
		end

		-- Defense Modifier against ranged
		if (bRanged) then
			iModifier = theirUnit:GetRangedDefenseModifier();
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_RANGED_DEFENSE_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end
		
		-- HillsDefenseModifier
		if (theirPlot:IsHills()) then
			iModifier = theirUnit:HillsDefenseModifier();

			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_HILL_DEFENSE_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end
		
		-- OpenDefenseModifier
		if (theirPlot:IsOpenGround()) then
			iModifier = theirUnit:OpenDefenseModifier();

			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_OPEN_TERRAIN_DEF_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end
		
		-- RoughDefenseModifier
		if (theirPlot:IsRoughGround()) then
			iModifier = theirUnit:RoughDefenseModifier();

			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_ROUGH_TERRAIN_DEF_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		end
		
		-- CombatBonusVsLargerCiv
		iModifier = theirPlayer:GetCombatBonusVsLargerCiv();
		if (iModifier ~= 0 and myPlayer:GetNumCities() > theirPlayer:GetNumCities()) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_TRAIT_SMALL_SIZE_BONUS" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- CapitalDefenseModifier
		iModifier = theirUnit:CapitalDefenseModifier();
		if (iModifier > 0) then

			-- Compute distance to capital
			local pCapital = theirPlayer:GetCapitalCity();
			
			if (pCapital ~= nil) then
				local plotDistance = Map.PlotDistance(pCapital:GetX(), pCapital:GetY(), theirUnit:GetX(), theirUnit:GetY());
				iModifier = iModifier + (plotDistance * theirUnit:CapitalDefenseFalloff());
						
				if (iModifier > 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_CAPITAL_DEFENSE_BONUS" );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
				end
			end
		end
		
		if (theirPlot:GetFeatureType() ~= -1) then
		
			-- FeatureDefenseModifier
			iModifier = theirUnit:FeatureDefenseModifier(theirPlot:GetFeatureType());
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				local typeBonus = Locale.ConvertTextKey(GameInfo.Features[theirPlot:GetFeatureType()].Description);
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_DEFENSE_TERRAIN", typeBonus );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
		else
		
			-- TerrainDefenseModifier		
			iModifier = theirUnit:TerrainDefenseModifier(theirPlot:GetTerrainType());
			if (iModifier ~= 0) then
				controlTable = g_TheirCombatDataIM:GetInstance();
				local typeBonus = Locale.ConvertTextKey(GameInfo.Terrains[theirPlot:GetTerrainType()].Description);
				controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_DEFENSE_TERRAIN", typeBonus );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
			end
			
			if (theirPlot:IsHills()) then
				iModifier = theirUnit:TerrainDefenseModifier(GameInfo.Terrains["TERRAIN_HILL"].ID);
				if (iModifier ~= 0) then
					controlTable = g_TheirCombatDataIM:GetInstance();
					local terrainTypeBonus = Locale.ConvertTextKey( GameInfo.Terrains["TERRAIN_HILL"].Description );
					controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_DEFENSE_TERRAIN", terrainTypeBonus  );
					controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
				end
			end
		end
		
		-- Alien Bonus
		if (theirUnit:IsAlien()) then
			iModifier = GameInfo.HandicapInfos[Game:GetHandicapType()].AlienCombatBonus;
			
			iModifier = iModifier + myPlayer:GetBarbarianCombatBonus();
			iModifier = iModifier + myCity:GetStrengthModVsAliens();

			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_VS_ALIENS_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
		end
		
		--TODO: Show bonus to our City from our National Security covert ops project

		-- Defending Unit
		if (myCity:GetDefendingUnit() ~= nil) then		
			iModifier = myPlayer:GetGarrisonedCityRangeStrikeModifier();
			if (iModifier ~= 0) then
				controlTable = g_MyCombatDataIM:GetInstance();
				controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_GARRISONED_CITY_RANGE_BONUS" );
				controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
			end
		end
		
		-- Religion Bonus
		iModifier = myCity:GetReligionCityRangeStrikeModifier();
		if (iModifier ~= 0) then
			controlTable = g_MyCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText( "TXT_KEY_EUPANEL_BONUS_RELIGIOUS_BELIEF" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
		end
		
		-- Civ Trait Bonus
		iModifier = theirPlayer:GetTraitEraOfProsperityCombatModifier();
		if (iModifier ~= 0 and theirPlayer:IsEraOfProsperity()) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_ERA_OF_PROSPERITY" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- Virtues Bonus
		iModifier = theirPlayer:GetPolicyCombatModifier();
		if (iModifier ~= 0) then
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_BONUS_VIRTUES" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, false, true) );
		end

		-- Unused Moves
		iModifier = theirUnit:GetPerUnusedMoveModifier();
		local iUnusedMoves = theirUnit:GetUnusedMoves() / GameDefines["MOVE_DENOMINATOR"];
		if (iModifier ~= 0 and iUnusedMoves > 0) then
			iModifier = iModifier * iUnusedMoves;
			controlTable = g_TheirCombatDataIM:GetInstance();
			controlTable.Text:LocalizeAndSetText(  "TXT_KEY_EUPANEL_UNUSED_MOVES_BONUS" );
			controlTable.Value:SetText( GetFormattedText(strText, iModifier, true, true) );
		end
	end

	-- Bombard Banner
	Controls.GoodHeader:SetHide(false);
	Controls.GoodLabel:SetText( Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_EUPANEL_RANGED_ATTACK")));
	
	ResizeAllContents();
end


--------------------------------------------------------------------------------
-- Update A Health Bar combat preview
--------------------------------------------------------------------------------
function UpdateSingleHealthBar( controlPrefix, iMaxMyHP, myCurrentDamage, inflicted )
   
    -- Grab controls
    local redBar            = Controls[ controlPrefix .. "RedBar"       ];
    local greenBar          = Controls[ controlPrefix .. "GreenBar"     ];
    local yellowBar         = Controls[ controlPrefix .. "YellowBar"    ];
    local deltaBar          = Controls[ controlPrefix .. "DeltaBar"     ];
    local deltaBarFlash     = Controls[ controlPrefix .. "DeltaBarFlash"];
    local deltaBarFlashImage= Controls[ controlPrefix .. "DeltaBarFlashImage"];

    -- Maths!
    local myDamageTaken = inflicted;
    if (myDamageTaken > iMaxMyHP - myCurrentDamage) then
        myDamageTaken = iMaxMyHP - myCurrentDamage;
    end
    myCurrentDamage = myCurrentDamage + myDamageTaken;

    local healthPercent     = (iMaxMyHP - myCurrentDamage) / iMaxMyHP;  
    local healthLeftPixels  = g_DAMAGE_BAR_SIZE * healthPercent;
    local healthTimes100    = math.floor(100 * healthPercent + 0.5);   
    local damagePercent     = inflicted / iMaxMyHP;
    local damagePixels      = g_DAMAGE_BAR_SIZE * damagePercent;


    local activeBar = {};
    if healthTimes100 <= 25 then                    -- red, danger danger about to die
        activeBar = redBar;
        greenBar:   SetHide(true);
        yellowBar:  SetHide(true);
    elseif healthTimes100 <= 60 then                -- yellow, oh noes!
        activeBar = yellowBar;
        greenBar:   SetHide(true);
        redBar:     SetHide(true);
    else                                            -- green, in the good
        activeBar = greenBar;
        yellowBar:  SetHide(true);
        redBar:     SetHide(true);
    end

    activeBar:      SetHide(false);
    activeBar:      SetMaskOffsetVal( 0, -g_DAMAGE_BAR_SIZE + (g_DAMAGE_BAR_SIZE - healthLeftPixels) );

    -- Damage will occur, show flash delta    
    if myDamageTaken > 0 then
        deltaBar:       SetHide( false );
        deltaBarFlash:  SetMaskOffsetVal( 0, -g_DAMAGE_BAR_SIZE );
        deltaBarFlash:  SetSizeVal( 13, damagePixels );
        deltaBarFlash:  SetOffsetVal( 0, g_DAMAGE_BAR_SIZE-healthLeftPixels-damagePixels);
    else
        deltaBar:		SetHide( true );
    end   
end


--------------------------------------------------------------------------------
-- Update all Health Bars for combat preview
--------------------------------------------------------------------------------
function DoUpdateHealthBars(iMaxMyHP, iTheirMaxHP, myCurrentDamage, theirCurrentDamage, iMyDamageInflicted, iTheirDamageInflicted)

	UpdateSingleHealthBar( "My", 	iMaxMyHP,	myCurrentDamage,	iTheirDamageInflicted);
	UpdateSingleHealthBar( "Their", iTheirMaxHP,theirCurrentDamage,	iMyDamageInflicted);

end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function OnWorldMouseOver( bWorldHasMouseOver )
    g_bWorldMouseOver = bWorldHasMouseOver;
    
	if( g_bShowPanel and g_bWorldMouseOver ) then
		ContextPtr:SetHide( false );
	else
		ContextPtr:SetHide( true );
    end
end
Events.WorldMouseOver.Add( OnWorldMouseOver );



--------------------------------------------------------------------------------
-- Hex has been moused over
--------------------------------------------------------------------------------
function OnMouseOverHex( hexX, hexY )

	g_bShowPanel = false;
	
	Controls.MyCombatResultsStack:SetHide(true);
	Controls.TheirCombatResultsStack:SetHide(true);
	
	local pPlot = Map.GetPlot( hexX, hexY );
	
	if (pPlot ~= nil) then
		local pHeadUnit = UI.GetHeadSelectedUnit();
		local pHeadCity = UI.GetHeadSelectedCity();
		local iInterfaceMode = UI.GetInterfaceMode();
		if (pHeadUnit ~= nil) then
			if (iInterfaceMode == InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP) then
				-- Don't show panel for air sweeps, air sweep combat works differently
			elseif (pHeadUnit:IsCombatUnit() and (pHeadUnit:IsRanged() and pHeadUnit:IsEmbarked()) == false) and ((pHeadUnit:IsRanged() and pHeadUnit:IsRangeAttackOnlyInDomain() and not pPlot:IsWater()) == false) then
				
				local iTeam = Game.GetActiveTeam()
				local pTeam = Teams[iTeam]
				
				-- Don't show info for stuff we can't see
				if (pPlot:IsRevealed(iTeam, false)) then
					
					-- Strategic Site
					if (pPlot:IsStrategicSite()) then

						if (pPlot:GetPlotStrategicSite():CanTeamAttackSite(iTeam) or (UIManager:GetAlt() and pPlot:GetOwner() ~= iTeam)) then

							UpdateSiteStats(pPlot);
							UpdateCombatOddsUnitVsSite(pHeadUnit, pPlot);
							UpdateSitePortrait(pPlot);
							
							Controls.MyCombatResultsStack:SetHide(false);
							Controls.TheirCombatResultsStack:SetHide(false);
							g_bShowPanel = true;
						end
					else
						
						-- Can see this plot right now
						if (pPlot:IsVisible(iTeam, false) and not pHeadUnit:IsCityAttackOnly()) then
							
							local iNumUnits = pPlot:GetNumUnits();
							local pUnit;
							
							-- Loop through all Units
							for i = 0, iNumUnits do
								pUnit = pPlot:GetUnit(i);
								if (pUnit ~= nil and not pUnit:IsInvisible(iTeam, false)) then
									
									-- No air units
									--if (pUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR) then
										
										-- Other guy must be same domain, OR we must be ranged OR we must be naval and he is embarked OR we can move in all terrains.
										if (pHeadUnit:GetDomainType() == pUnit:GetDomainType() or pHeadUnit:IsRanged() or (pHeadUnit:GetDomainType() == DomainTypes.DOMAIN_SEA and pUnit:IsEmbarked()) or pHeadUnit:CanMoveAllTerrain()) then
										
											 if (pUnit:GetCombatStrength() > 0 or pHeadUnit:IsRanged()) then

												if (pTeam:IsAtWar(pUnit:GetTeam()) or (UIManager:GetAlt() and pUnit:GetOwner() ~= iTeam)) then
													UpdateUnitPortrait(pUnit);
													UpdateUnitStats(pUnit);
												
													UpdateCombatOddsUnitVsUnit(pHeadUnit, pUnit);
													Controls.MyCombatResultsStack:SetHide(false);
													Controls.TheirCombatResultsStack:SetHide(false);
													
													g_bShowPanel = true;
													break;
												end
											end
										end
									--end
								end
							end
						end
					end
				end
			elseif(pHeadUnit:IsRanged() == true and pHeadUnit:IsEmbarked() == false) then
				
				local iTeam = Game.GetActiveTeam()
				local pTeam = Teams[iTeam]
				
				-- Don't show info for stuff we can't see
				if (pPlot:IsRevealed(iTeam, false)) then
					
					-- Site
					if (pPlot:IsStrategicSite()) then
						
						--local pCity = pPlot:GetPlotCity();
						
						if (pTeam:IsAtWar(pPlot:GetTeam()) or (UIManager:GetAlt() and pPlot:GetOwner() ~= iTeam)) then

							UpdateSiteStats(pPlot);
							UpdateCombatOddsUnitVsSite(pHeadUnit, pPlot);
							UpdateSitePortrait(pPlot);
							
							Controls.MyCombatResultsStack:SetHide(false);
							Controls.TheirCombatResultsStack:SetHide(false);
							g_bShowPanel = true;
						end
						
					-- No City Here
					else
						
						-- Can see this plot right now
						if (pPlot:IsVisible(iTeam, false)) then
							
							local iNumUnits = pPlot:GetNumUnits();
							local pUnit;
							
							-- Loop through all Units
							for i = 0, iNumUnits do
								pUnit = pPlot:GetUnit(i);
								if (pUnit ~= nil and not pUnit:IsInvisible(iTeam, false)) then
									 if (pUnit:GetCombatStrength() > 0 or pHeadUnit:IsRanged()) then
												
										if (pTeam:IsAtWar(pUnit:GetTeam()) or (UIManager:GetAlt() and pUnit:GetOwner() ~= iTeam)) then
											UpdateUnitPortrait(pUnit);
											UpdateUnitStats(pUnit);

											UpdateCombatOddsUnitVsUnit(pHeadUnit, pUnit);
											Controls.MyCombatResultsStack:SetHide(false);
											Controls.TheirCombatResultsStack:SetHide(false);
											
											g_bShowPanel = true;
											break;
										end
									end
								end
							end
						end
					end
				end
				
			end
		
		elseif(pHeadCity ~= nil and pHeadCity:CanRangeStrikeNow()) then	-- no unit selected, what about a city?
			
			local myTeamID = Game.GetActiveTeam();
			
			-- Don't show info for stuff we can't see
			if (pPlot:IsVisible(myTeamID, false)) then
							
				local numUnitsOnPlot = pPlot:GetNumUnits();
				
				local myTeam = Teams[myTeamID];
				
				-- Loop through all Units
				for i = 0, numUnitsOnPlot - 1 do
					local theirUnit = pPlot:GetUnit(i);
					
					
					if (theirUnit ~= nil and not theirUnit:IsInvisible(myTeamID, false)) then
														
						-- No air units
						if (theirUnit:GetDomainType() ~= DomainTypes.DOMAIN_AIR) then
							
							if (myTeam:IsAtWar(theirUnit:GetTeam()) or (UIManager:GetAlt() and theirUnit:GetOwner() ~= myTeamID)) then
								
								-- Enemy Unit info
								UpdateUnitPortrait(theirUnit);
								UpdateUnitStats(theirUnit);
							
								UpdateCombatOddsCityVsUnit(pHeadCity, theirUnit);
								
								Controls.MyCombatResultsStack:SetHide(false);
								Controls.TheirCombatResultsStack:SetHide(false);
								
								g_bShowPanel = true;
								
								break;
							end
						end
					end
				end
			end
		end
	end
	
	if( g_bShowPanel and g_bWorldMouseOver ) then
		ContextPtr:SetHide( false );
	else
		ContextPtr:SetHide( true );
	end
end
Events.SerialEventMouseOverHex.Add( OnMouseOverHex );


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsInit ) then
        LuaEvents.EnemyPanelHide( bIsHide );
		if( not bIsHide ) then
			if (Controls.AlphaIn:IsReversing()) then
				Controls.AlphaIn:Reverse();
			end
			Controls.AlphaIn:SetToBeginning();
			Controls.AlphaIn:Play();
		end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
