------------------------------------------------- 
-- CityBannerManager
-------------------------------------------------
include( "SupportFunctions" );
include( "IconSupport" );
include( "InstanceManager" );
include( "InfoTooltipInclude" );
include( "CityStateStatusHelper" );
include( "TabSupport" );
include( "IntrigueHelper" );
include( "SerializationUtilities" );


-- ===========================================================================
--		CONSTANTS
-- ===========================================================================
local ART_INTRIGUE_WIDTH					= 102;
local ART_INTRIGUE_HEIGHT					= 24;

local ALPHA_BANNER_IDLE						= 0.6;
local ALPHA_BANNER_OVER						= 0.95;


-- ===========================================================================
--		GLOBALS
-- ===========================================================================
local g_TeamIM		= InstanceManager:new( "TeamCityBanner",	"Anchor", Controls.CityBanners );
local g_OtherIM		= InstanceManager:new( "OtherCityBanner",	"Anchor", Controls.CityBanners );
local g_StationIM	= InstanceManager:new( "OtherCityBanner",	"Anchor", Controls.CityBanners  );

local g_HideCovertOps		= true;


local CityInstances			= {};
local OutpostInstances		= {};
local StationInstances		= {};
local WorldPositionOffset	= { x = 0, y = 0, z = 55 };

local BlackFog = 0; -- invisible
local GreyFog  = 1; -- once seen
local WhiteFog = 2; -- eyes on

local defaultErrorTextureSheet = "";
local nullOffset = Vector2( 0, 0 );

local g_CovertOpsBannerContainer = ContextPtr:LookUpControl( "../CovertOpsBannerContainer" );
local g_CovertOpsIntelReportContainer = ContextPtr:LookUpControl( "../CovertOpsIntelReportContainer" );

-------------------------------------------------
-- Determines whether or not to show the Range Strike Button
-------------------------------------------------
function ShouldShowRangeStrikeButton(city) 
	if city == nil then
		return false;
	end
	
	if (city:GetOwner() ~= Game.GetActivePlayer()) then
		return false;
	end
		
	return city:CanRangeStrikeNow();
end

-------------------------------------------------
-- Show/hide the range strike icon
-------------------------------------------------
function UpdateRangeIcons(cityBanner)

	local player = Players[cityBanner.playerID];		
	if (player ~= nil) then
		local primaryColorRaw, secondaryColorRaw = player:GetPlayerColors();
		if player:IsMinorCiv() then
			primaryColorRaw, secondaryColorRaw = secondaryColorRaw, primaryColorRaw;
		end
		local primaryColor 	 		= RGBAObjectToABGRHex( primaryColorRaw );
		local secondaryColor 		= RGBAObjectToABGRHex( secondaryColorRaw );	

		local city		= player:GetCityByID(cityBanner.cityID);
		local controls	= cityBanner.SubControls;

		if (controls.CityAttackFrame ~= nil) then
			if (ShouldShowRangeStrikeButton(city) or ShouldShowAntiOrbitalStrikeButton(city)) then
				if(controls.IconsStack:GetSizeX() ~= 3) then
					controls.CityAttackFrame:SetOffsetY(105);
					controls.CityAttackFrame:SetColor(0,0,0,0);
				else
					controls.CityAttackFrame:SetOffsetY(85);
					controls.CityAttackFrame:SetColor(primaryColor);
				end

				controls.CityAttackFrame:SetHide(false);
				
				local isHidingRangeStrike = not ShouldShowRangeStrikeButton(city);
				controls.CityRangeStrikeContainer:SetHide( isHidingRangeStrike );

				local isHidingAntiOrbitalStrike = not ShouldShowAntiOrbitalStrikeButton(city);
				controls.AntiOrbitalStrikeContainer:SetHide( isHidingAntiOrbitalStrike );
			else
				controls.CityAttackFrame:SetHide(true);
			end
		end
	end
end

-------------------------------------------------
-- Determines whether or not to show the Anti Orbital Strike Button
-------------------------------------------------
function ShouldShowAntiOrbitalStrikeButton(city)
	if city == nil then
		return false;
	end

	if (city:GetOwner() ~= Game.GetActivePlayer()) then
		return false;
	end

	return city:CanAttackOrbitalNow();
end


-------------------------------------------------
-- Updates banner to reflect latest city info.
-------------------------------------------------
function RefreshCityBanner(cityBanner, iActiveTeam, iActivePlayer)
	if ( CityInstances[ cityBanner.playerID ] == nil or CityInstances[ cityBanner.playerID ][ cityBanner.cityID ] == nil ) then
	    return;
    end
		
	local player = Players[cityBanner.playerID];
	
	local team = Players[cityBanner.playerID]:GetTeam();
	local isActivePlayerCity = (cityBanner.playerID == iActivePlayer);
	local isActiveTeamCity = false;
	if (iActiveTeam == team) then
		isActiveTeamCity = true;
	end	
		
	-- grab city using playerID and cityID
	local city = player:GetCityByID(cityBanner.cityID);
	-- for debugging purposes, we want to be able to create a city banner without a DLL-side city
	--assert(city);
	
	local bHasSpy = false;
	local bHasDiplomat = false;
	local strSpyName = nil;
	local strSpyRank = nil;
	
	--if(city ~= nil) then
		--local cityX = city:GetX();
		--local cityY = city:GetY();
		--
		--local activePlayer = Players[iActivePlayer]
		--local spies = activePlayer:GetCovertAgents();
		--for i,v in ipairs(spies) do
			--if(v.CityX == cityX and v.CityY == cityY) then
				--bHasSpy = true;
				--strSpyName = Locale.Lookup(v:GetName());
				--strSpyRank = Locale.Lookup(v:GetRank());
			--end
		--end
	--end
	
	local controls = cityBanner.SubControls;
	
	-- Update colors
	local primaryColorRaw, secondaryColorRaw = player:GetPlayerColors();
	if player:IsMinorCiv() then
		primaryColorRaw, secondaryColorRaw = secondaryColorRaw, primaryColorRaw;
	end

	local primaryColorAlphaedRaw	= { x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 0.5 };
	local primaryColor 	 		= RGBAObjectToABGRHex( primaryColorRaw );
	local secondaryColor 		= RGBAObjectToABGRHex( secondaryColorRaw );	
	local primaryColorAlphaed 	= RGBAObjectToABGRHex( primaryColorAlphaedRaw );

	controls.CityBannerBackground:SetColor(primaryColor);
--	if( isActiveTeamCity )then

		if ( controls.CityBannerButtonBase ~= nil )		then controls.CityBannerButtonBase		:SetColor( secondaryColor ); end
		if ( controls.CityBannerButtonBaseLeft ~= nil ) then controls.CityBannerButtonBaseLeft	:SetColor( secondaryColor ); end
		if ( controls.CityBannerButtonBaseRight ~= nil )then controls.CityBannerButtonBaseRight	:SetColor( secondaryColor ); end

		if ( controls.CityBannerBGLeftHL ~= nil )		then controls.CityBannerBGLeftHL		:SetColor( secondaryColor ); end
		if ( controls.CityBannerBGRightHL ~= nil )		then controls.CityBannerBGRightHL		:SetColor( secondaryColor ); end
		if ( controls.CityBannerRightBackground ~= nil )then controls.CityBannerRightBackground	:SetColor( primaryColor ); end
		if ( controls.CityBannerLeftBackground ~= nil ) then controls.CityBannerLeftBackground	:SetColor( primaryColor ); end
--[[
	else
		--NOTE: If the active player were to ever change (such as during an auto play) these controls will not exist because
		--		the city banner is of the "active player" type and not the "other player" type.
		--		This fix is merely a fix to the Lua nil value error and not a proper solution to the problem.
		if(controls.RightBackground ~= nil and controls.LeftBackground ~= nil) then
			controls.RightBackground		:SetColor( secondaryColor );
			controls.LeftBackground			:SetColor( secondaryColor );
	    end
	end
]]	
	local textColorRaw 		= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 1  };
	local textColor200Raw	= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 0.7};
	local textColorShadowRaw= {x = 0, y = 0, z = 0, w = 0.5};
	local textColorSoftRaw 	= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 0.5};

	local textColor 		= RGBAObjectToABGRHex( textColorRaw );
	local textColor200		= RGBAObjectToABGRHex( textColor200Raw );
	local textColorShadow 	= RGBAObjectToABGRHex( textColorShadowRaw );
	local textColorSoft 	= RGBAObjectToABGRHex( textColorSoftRaw );
	
	if(controls.CityProductionName) then
		controls.CityProductionName:SetColor( textColor200, 0);
	end

	controls.CityName:SetColor( textColor, 0);
	--controls.CityName:SetColor( textColorShadow, 1);
	--controls.CityName:SetColor( textColorSoft, 2);
    
    	
	if city ~= nil then
		-- Update name
		local cityName			= city:GetNameKey();
		local localizedCityName = Locale.ConvertTextKey(cityName);
		local convertedKey		= Locale.ToUpper(localizedCityName);
		
		-- Update capital icon
		local isCapital = city:IsCapital() or Players[city:GetOriginalOwner()]:IsMinorCiv();
		
		if (city:IsCapital() and not player:IsMinorCiv()) then	
			controls.CityTypeIcon:SetColor( primaryColor );
		end		

		controls.CityTypeIcon:SetHide( not isCapital );
		controls.CityName:SetText(convertedKey);

		local strToolTip = "";
		if (UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_SELECTION) then
			if (isActivePlayerCity) then
				if (city:IsPuppet() and not player:MayNotAnnex()) then
					strToolTip = Locale.ConvertTextKey("TXT_KEY_CITY_ANNEX_TT");
				else
					strToolTip = Locale.ConvertTextKey("TXT_KEY_CITY_ENTER_CITY_SCREEN");
				end
			elseif (isActiveTeamCity) then
				strToolTip = Locale.ConvertTextKey("TXT_KEY_CITY_TEAMMATE");
			elseif (Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_WAR )) then
				strToolTip = Locale.ConvertTextKey("TXT_KEY_ALWAYS_AT_WAR_WITH_CITY");
			elseif (player:IsMinorCiv()) then
				local strStatusTT = GetCityStateStatusToolTip(iActivePlayer, cityBanner.playerID, false);
				strToolTip = strToolTip .. strStatusTT;	
				controls.StatusIconBG:SetToolTipString(strStatusTT);
				controls.StatusIcon:SetToolTipString(strStatusTT);
			elseif (not Teams[Game.GetActiveTeam()]:IsHasMet(player:GetTeam())) then
				strToolTip = Locale.ConvertTextKey("TXT_KEY_HAVENT_MET");
			else
				strToolTip = Locale.ConvertTextKey("TXT_KEY_TALK_TO_PLAYER");
			end
		end
				
		controls.BannerButton:SetToolTipString(strToolTip);

		DoResizeBanner(controls);

		-- Update City Status icons
		controls.StatusBacking:SetHide(true);

		-- Connected to capital?
		if (isActiveTeamCity) then
			if (not city:IsCapital() and player:IsCapitalConnectedToCity(city) and not city:IsBlockaded()) then
				controls.StatusBacking:SetHide( false );
                controls.ConnectedIcon:SetHide(false);
				controls.ConnectedIcon:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_CONNECTED"));
			else
				controls.ConnectedIcon:SetHide(true);
			end
		end
			
		-- Blockaded
		if (city:IsBlockaded()) then
            controls.StatusBacking:SetHide( false );
			controls.BlockadedIcon:SetHide(false);
			controls.BlockadedIcon:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_BLOCKADED"));
		else
			controls.BlockadedIcon:SetHide(true);
		end
		
		-- Being Razed
		if (city:IsRazing()) then
			controls.StatusBacking:SetHide( false );
			controls.RazingIcon:SetHide(false);
			controls.RazingIcon:SetToolTipString(Locale.ConvertTextKey( "TXT_KEY_CITY_BURNING", tostring(city:GetRazingTurns()) ));
		else
			controls.RazingIcon:SetHide(true);
		end

		-- Puppet Status
		if (city:IsPuppet()) then
			controls.StatusBacking:SetHide( false );
			controls.PuppetIcon:SetHide(false);			

			if(isActivePlayerCity) then
				controls.PuppetIcon:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_PUPPET"));
			else
				controls.PuppetIcon:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_PUPPET_OTHER"));
			end
		else
			controls.PuppetIcon:SetHide(true);
		end
		
		-- Resistance Status
		if (city:IsResistance()) then
			controls.StatusBacking:SetHide( false );
			controls.ResistanceIcon:SetHide(false);			
			controls.ResistanceIcon:SetToolTipString(Locale.ConvertTextKey( "TXT_KEY_CITY_RESISTANCE", city:GetResistanceTurns() ));			
		else
			controls.ResistanceIcon:SetHide(true);
		end

		-- Martial Law Status
		if (city:IsMartialLaw()) then
			controls.StatusBacking:SetHide( false );
			controls.OccupiedIcon:SetHide(false);
			controls.OccupiedIcon:SetToolTipString(Locale.ConvertTextKey( "TXT_KEY_CITY_MARTIAL_LAW", city:GetMartialLawTurns() ));			
		else
			controls.OccupiedIcon:SetHide(true);
		end
		
		if(bHasSpy) then
			controls.StatusBacking:SetHide( false );
			controls.SpyIcon:SetHide(false);
			if (isActivePlayerCity) then
				controls.SpyIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_SPY_YOUR_CITY_TT", strSpyRank, strSpyName, city:GetName(), strSpyRank, strSpyName);
			elseif (player:IsMinorCiv()) then
				controls.SpyIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_SPY_CITY_STATE_TT", strSpyRank, strSpyName, city:GetName(), strSpyRank, strSpyName);			
			else
				controls.SpyIcon:LocalizeAndSetToolTip("TXT_KEY_CITY_SPY_OTHER_CIV_TT", strSpyRank, strSpyName, city:GetName(), strSpyRank, strSpyName, strSpyRank, strSpyName);
			end
		else
			controls.SpyIcon:SetHide(true);
		end

		controls.IconsStack:ReprocessAnchoring();

		-- Update strength
		local cityStrengthStr = math.floor(city:GetStrengthValue() / 100);
		controls.CityBannerStrengthFrame:SetColor( secondaryColor );
		controls.ShieldIcon				:SetColor( primaryColor );
		controls.CityStrength			:SetColor( primaryColor, 0 );
		controls.CityStrength			:SetText( cityStrengthStr );				

		--[[
		local garrisonedUnit = city:GetDefendingUnit();
		if garrisonedUnit == nil then
			if isActiveTeamCity then
				if controls.GarrisonFrame~= nil then
					--controls.GarrisonFrame:SetHide(true);
				end
			end	
		end		]]--
		
    	if isActiveTeamCity then
			if controls.EjectGarrison then
				controls.EjectGarrison:SetHide(true);
			end
		end

		-- Update the strike icons
		if cityBanner.SubControls.CityAttackStack ~= nil then
			UpdateRangeIcons(cityBanner);
			cityBanner.SubControls.CityAttackStack:CalculateSize();
			cityBanner.SubControls.CityAttackStack:ReprocessAnchoring();
		end
		
		-- Update population
		local cityPopulation = math.floor(city:GetPopulation());
		controls.CityPopulation:SetText(cityPopulation);
		controls.CityPopulation:SetColor( primaryColor, 0 );

		-- Update Growth Time
		if(controls.CityGrowth) then
			local cityGrowth = city:GetFoodTurnsLeft();
			
			if (city:IsFoodProduction() or city:FoodDifferenceTimes100() == 0) then
				cityGrowth = "-";
				controls.CityBannerRightBackground:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_STOPPED_GROWING_TT", localizedCityName, cityPopulation));
			elseif city:FoodDifferenceTimes100() < 0 then
				cityGrowth = "[COLOR_WARNING_TEXT]-[ENDCOLOR]";
				controls.CityBannerRightBackground:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_STARVING_TT",localizedCityName ));
			else
				controls.CityBannerRightBackground:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_WILL_GROW_TT", localizedCityName, cityPopulation, cityPopulation+1, cityGrowth));
			end
			
			controls.CityGrowth:SetText(cityGrowth);
			controls.CityGrowth:SetColor(primaryColor);
		end
		
		-- Update Production Time
		if(controls.BuildGrowth) then
			local buildGrowth = "-";
			
			if (city:IsProduction() and not city:IsProductionProcess()) then
				if (city:GetCurrentProductionDifferenceTimes100(false, false) > 0) then
					buildGrowth = city:GetProductionTurnsLeft();
				end
			end
			
			controls.BuildGrowth:SetText(buildGrowth);
			controls.BuildGrowth:SetColor(primaryColor);

		end
		
		-- Update Growth Meter
		if (controls.GrowthBar) then
			
			local iCurrentFood = city:GetFood();
			local iFoodNeeded = city:GrowthThreshold();
			local iFoodPerTurn = city:FoodDifference();
			local iCurrentFoodPlusThisTurn = iCurrentFood + iFoodPerTurn;
			
			local fGrowthProgressPercent = iCurrentFood / iFoodNeeded;
			local fGrowthProgressPlusThisTurnPercent = iCurrentFoodPlusThisTurn / iFoodNeeded;
			if (fGrowthProgressPlusThisTurnPercent > 1) then
				fGrowthProgressPlusThisTurnPercent = 1
			end
			
			controls.GrowthBar:SetPercent( fGrowthProgressPercent );
			controls.GrowthBarShadow:SetPercent( fGrowthProgressPlusThisTurnPercent );
			
			controls.GrowthBar:SetColor( primaryColor );
			controls.GrowthBarShadow:SetColor( primaryColorAlphaed );
		end
		
		-- Update Production Meter
    	controls.CityBannerLeftBackground:SetHide(false);
		if (controls.ProductionBar) then
			controls.ProductionBar:SetHide(false);
			controls.ProductionBarShadow:SetHide(false);
			controls.BuildGrowth:SetHide(false);
		end
		controls.CityBannerButtonBaseRight:SetHide(false);

		if (controls.ProductionBar) then
			local iCurrentProduction = city:GetProduction();
			local iProductionNeeded = city:GetProductionNeeded();
			local iProductionPerTurn = city:GetYieldRate(YieldTypes.YIELD_PRODUCTION);
			if (city:IsFoodProduction()) then
				iProductionPerTurn = iProductionPerTurn + city:GetFoodProduction();
			end
			local iCurrentProductionPlusThisTurn = iCurrentProduction + iProductionPerTurn;
			
			local fProductionProgressPercent = iCurrentProduction / iProductionNeeded;
			local fProductionProgressPlusThisTurnPercent = iCurrentProductionPlusThisTurn / iProductionNeeded;
			if (fProductionProgressPlusThisTurnPercent > 1) then
				fProductionProgressPlusThisTurnPercent = 1
			end
			
			controls.ProductionBar:SetPercent( fProductionProgressPercent );
			controls.ProductionBarShadow:SetPercent( fProductionProgressPlusThisTurnPercent );

			controls.ProductionBar:SetColor( primaryColor );
			controls.ProductionBarShadow:SetColor( primaryColorAlphaed );
		end
		-- Turn on all City-specific icons

		if (controls.StatusIcon) then
			controls.StatusIcon:SetHide(false);
		end
		if (controls.CityBannerProductionImage) then
			controls.CityBannerProductionImage:SetHide(false);
		end

		-- Update Production Name
		local cityProductionName = city:GetProductionNameKey();
		if cityProductionName == nil or string.len(cityProductionName) == 0 then
			cityProductionName = "TXT_KEY_PRODUCTION_NO_PRODUCTION";
		end

		if (controls.CityProductionName) then

			if ( isActivePlayerCity ) then
				convertedKey = Locale.ConvertTextKey(cityProductionName);
				controls.CityProductionName:SetText(convertedKey);
				if (controls.CityBannerLeftBackground) then
					if (city:IsProductionProcess()) then
						local cityProductionProcess = city:GetProductionProcess();
						local tooltipString = GetHelpTextForProcess(cityProductionProcess, false);
						controls.CityBannerLeftBackground:SetToolTipString(tooltipString);
					else
						if cityProductionName == "TXT_KEY_PRODUCTION_NO_PRODUCTION" then
							controls.CityBannerLeftBackground:SetToolTipString(Locale.ConvertTextKey( "TXT_KEY_CITY_NOT_PRODUCING", localizedCityName ));
						else
							local productionTurnsLeft = city:GetProductionTurnsLeft();
							local tooltipString;
							if productionTurnsLeft > 99 then
								tooltipString = Locale.ConvertTextKey("TXT_KEY_CITY_CURRENTLY_PRODUCING_99PLUS_TT", localizedCityName, cityProductionName);
							else
								tooltipString = Locale.ConvertTextKey("TXT_KEY_CITY_CURRENTLY_PRODUCING_TT", localizedCityName, cityProductionName, productionTurnsLeft);
							end
							controls.CityBannerLeftBackground:SetToolTipString(tooltipString);
						end
					end	
				end
			else
				-- Other player's city.  Don't show production.
			end
		end
	
		-- Update Production icon
		if controls.CityBannerProductionImage then

			local unitProduction = city:GetProductionUnit();
			local buildingProduction = city:GetProductionBuilding();
			local projectProduction = city:GetProductionProject();
			local processProduction = city:GetProductionProcess();
			local noProduction = false;

			controls.CityBannerProductionImage:SetColor( primaryColor );

			if unitProduction ~= -1 then
				local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(unitProduction, city:GetOwner());			
				if IconHookup( portraitOffset, 45, portraitAtlas, controls.CityBannerProductionImage ) then
					controls.CityBannerProductionImage:SetHide( false );					
				else
					controls.CityBannerProductionImage:SetHide( true );
				end
			elseif buildingProduction ~= -1 then
				local thisBuildingInfo = GameInfo.Buildings[buildingProduction];
				if IconHookup( thisBuildingInfo.PortraitIndex, 45, thisBuildingInfo.IconAtlas, controls.CityBannerProductionImage ) then
					controls.CityBannerProductionImage:SetHide( false );
				else
					controls.CityBannerProductionImage:SetHide( true );
				end
			elseif projectProduction ~= -1 then
				local thisProjectInfo = GameInfo.Projects[projectProduction];
				if IconHookup( thisProjectInfo.PortraitIndex, 45, thisProjectInfo.IconAtlas, controls.CityBannerProductionImage ) then
					controls.CityBannerProductionImage:SetHide( false );
				else
					controls.CityBannerProductionImage:SetHide( true );
				end
			elseif processProduction ~= -1 then
				controls.CityBannerProductionImage:SetColor( 0xffffffff );		-- These have coloured icons, don't tint!
				local thisProcessInfo = GameInfo.Processes[processProduction];
				if IconHookup( thisProcessInfo.PortraitIndex, 45, thisProcessInfo.IconAtlas, controls.CityBannerProductionImage ) then
					controls.CityBannerProductionImage:SetHide( false );
				else
					controls.CityBannerProductionImage:SetHide( true );
				end
			else -- really should have an error texture
				controls.CityBannerProductionImage:SetHide(true);
			end
			
			if isActivePlayerCity then
    			controls.CityBannerProductionButton:RegisterCallback( Mouse.eLClick, OnProdClick );
    			controls.CityBannerProductionButton:SetVoids( city:GetID(), nil );
    			controls.BannerButton:SetDisabled( false );
			end
			
		end
	
		-- This is another player's banner instance
		if( controls.MinorIndicator and controls.StatusIcon ) then
		
			controls.MinorIndicator:SetHide(false);
			controls.StatusIconBG:SetHide(false);
			--controls.StatusMeterFrame:SetHide(false);

			controls.StatusIcon:SetColor( textColor );
			local civType = player:GetCivilizationType();
			local civInfo = GameInfo.Civilizations[civType];

			if( player:IsMinorCiv() ) then
				-- minor trait icon
				controls.StatusIcon:SetTexture( GameInfo.MinorCivTraits[ GameInfo.MinorCivilizations[ player:GetMinorCivType() ].MinorCivTrait ].TraitIcon );
				controls.StatusIcon:SetTextureOffsetVal( 0, 0 );

			else
				IconHookup( civInfo.PortraitIndex, 32, civInfo.AlphaIconAtlas, controls.StatusIcon );
				controls.StatusIcon:SetOffsetX(2);
				controls.StatusIconBG:SetHide( true );
            	--controls.StatusMeterFrame:SetHide( true );
			end
			
			local pOriginalOwner = Players[ city:GetOriginalOwner() ];
			if( pOriginalOwner:IsMinorCiv() ) then
			-- Stations don't return as a minor civ so this is never run, remove? -TRON

			else
			    controls.MinorIndicator:SetHide( true );
			 --   controls.MinorOccupiedSpacer:SetHide( true );
			 --   controls.NameStack:SetOffsetX( -3 );
			end

			controls.NameStack:CalculateSize();
			controls.NameStack:ReprocessAnchoring();
			
		end	
		
		-- Refresh the damage bar too
		RefreshCityDamage( city, cityBanner, city:GetDamage() );		
	end

	if(controls.NameStack)then
		controls.NameStack:CalculateSize();
		controls.NameStack:ReprocessAnchoring();
	end
	
	controls.IconsStack:CalculateSize();
	local size = controls.IconsStack:GetSizeX();
	if(size == 3) then
		controls.StatusBacking:SetHide( true );
	else
		controls.StatusBacking:SetSizeX(size+35);
	end
	controls.IconsStack:ReprocessAnchoring();


	-- =====  Covert Ops =====
	controls.IntelReport:SetHide(true);
	if (not UI.IsInCovertOpsView()) then
		controls.CovertOps:SetHide( true );
		controls.IntelReport:SetHide( true );
		controls.Anchor:SetAlpha( ALPHA_BANNER_IDLE );
	else
		-- Change the parent so that the intel report draws on top of the selected 
		-- unit flag
		controls.CovertOpsAnchor:ChangeParent(g_CovertOpsBannerContainer);
		controls.CovertOpsIntelReportAnchor:ChangeParent(g_CovertOpsIntelReportContainer);

		controls.CovertOps:SetHide( false );
		controls.Anchor:SetAlpha( ALPHA_BANNER_OVER );		

		if ( controls.CityAttackFrame ~= nil ) then
			controls.CityAttackFrame:SetHide( true );		-- If strike target is up, hide it for cover ops
		end

--		if (controls.StatusBacking ~= nil) then
--			controls.StatusBacking:SetHide( true );			-- If status bar is up, hide it for cover ops
--		end

		local isCurrentPlayersCity = city:GetOwner() == Game.GetActivePlayer();

		local intrigueLevel = city:GetIntrigueLevel();		-- 1 to 5
		local intrigue		= city:GetIntrigue();			-- 0 to 100	
	
		controls.Intrigue			:SetHide( false );
		controls.IntrigueHighlight	:SetHide( false );	

		local intriguePercent = intrigue / 100 ;
		controls.Intrigue			:SetSizeVal( ART_INTRIGUE_WIDTH * intriguePercent , ART_INTRIGUE_HEIGHT);
		controls.IntrigueHighlight	:SetColor( IntrigueToABGRColor( intrigue ) );

		

		local covertOpsSelectedCity = UI.GetCovertOpsSelectedCity();
		if (isCurrentPlayersCity or 
			covertOpsSelectedCity == nil or 
			covertOpsSelectedCity:GetID() ~= city:GetID() or
			covertOpsSelectedCity:GetOwner() ~= city:GetOwner() )
		then
			controls.CounterIntelArea:SetHide(true);
			controls.TabRow:SetHide(true);
			controls.IntelReport:SetHide(true);
		else
			controls.CounterIntelArea:SetHide(true);
			controls.TabRow:SetHide(false);

			local tabs = CreateTabs(controls.TabRow, 64, 32);
			tabs.AddTab(controls.IntelReportTab,
				function()
					controls.IntelReportArea:SetHide(false);
					controls.OPsHistoryArea:SetHide(true);
				end
			);
			tabs.AddTab(controls.OPsHistoryTab,
				function()
					controls.IntelReportArea:SetHide(true);
					controls.OPsHistoryArea:SetHide(false);
				end
			);
			tabs.EvenlySpreadTabs();
			tabs.SelectTab(controls.IntelReportTab);

			-- Build history
			controls.HistoryStack:DestroyAllChildren();
			local recordIM = InstanceManager:new("OpsHistoryInstance", "OpsHistoryTop", controls.HistoryStack);
			local records = city:GetCovertOperationRecords(Game.GetActivePlayer());
			for i,record in ipairs(records) do
				local instance = recordIM:GetInstance();
				instance.RecordString:SetText(record);
			end

			local agent = covertOpsSelectedCity:GetCovertAgent(Game.GetActivePlayer());
			if (agent ~= nil) then
				controls.IntelTitle:SetString(Locale.ConvertTextKey(agent:GetName()));
			end

			-- Build intel report
			if (agent ~= nil and agent:GetHasEstablishedNetwork()) then
				controls.IntelReport:SetHide(false);
				controls.IntelStack:DestroyAllChildren();

				-- WRM: In a perfect world, this would live in the covert ops system,
				--		but the plumbing to get it here would be nasty.
				local rank = agent:GetRank();

				local itemIM  = InstanceManager:new("IntelInstance", "IntelReportTop", controls.IntelStack);
				local instance = nil;

				-- Add current research
				local currentTechInfo = GameInfo.Technologies[Players[city:GetOwner()]:GetCurrentResearch()];
				if (currentTechInfo ~= nil) then
					instance = itemIM:GetInstance();
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_RESEARCH_TECH", currentTechInfo.Description));
				end

				-- Add current production
				instance = itemIM:GetInstance();
				instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_PRODUCTION", city:GetProductionNameKey()));

				-- Add Health
				instance = itemIM:GetInstance();
				local localHealth = city:GetLocalHealth();
				if (localHealth < 0) then
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_BAD_HEALTH", localHealth));
				else
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_GOOD_HEALTH", localHealth));
				end
				

				if (rank >= 1) then
					-- Add yields
					instance = itemIM:GetInstance();
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_ENERGY_YIELD", city:GetYieldRateTimes100(YieldTypes.YIELD_ENERGY) / 100));
				
					instance = itemIM:GetInstance();
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_PRODUCTION_YIELD", city:GetYieldRateTimes100(YieldTypes.YIELD_PRODUCTION) / 100));

					instance = itemIM:GetInstance();
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_FOOD_YIELD", city:GetYieldRateTimes100(YieldTypes.YIELD_FOOD) / 100));

					instance = itemIM:GetInstance();
					instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_CULTURE_YIELD", city:GetYieldRateTimes100(YieldTypes.YIELD_CULTURE) / 100));
					
					if (not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
						instance = itemIM:GetInstance();
						instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_SCIENCE_YIELD", city:GetYieldRateTimes100(YieldTypes.YIELD_RESEARCH) / 100));
					end
				end

				if (rank >= 2) then
					-- Counter intel agent
					local counterAgent = city:GetCovertAgent(city:GetOwner());
					if (counterAgent ~= nil) then
						local counterAgentRank = counterAgent:GetRank();
						local rankTextKey = nil;
						if (counterAgentRank == 0) then
							rankTextKey = "TXT_KEY_COVERT_SPY_RANK_RECRUIT";
						elseif (counterAgentRank == 1) then
							rankTextKey = "TXT_KEY_COVERT_SPY_RANK_AGENT";
						elseif (counterAgentRank == 2) then
							rankTextKey = "TXT_KEY_COVERT_SPY_RANK_SPECIAL_AGENT";	
						else
							rankTextKey = "UNKNOWN AGENT RANK";
						end

						instance = itemIM:GetInstance();
						instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_COUNTER_AGENT", rankTextKey));
					else
						instance = itemIM:GetInstance();
						instance.IntelString:SetText(Locale.ConvertTextKey("TXT_KEY_INTEL_REPORT_NO_COUNTER_AGENT"));
					end
				end

				controls.IntelScroll:CalculateInternalSize();
				controls.HistoryScroll:CalculateInternalSize();
				controls.CounterIntelScroll:CalculateInternalSize();
			else
				controls.IntelReport:SetHide(true);
			end
		end
	end
end

-------------------------------------------------
-- Update the output damage, this will also update the tooltip
-------------------------------------------------
function RefreshOutpostDamage(outpost, outpostBanner, damage)
	local controls = outpostBanner.SubControls;
	local strength = math.floor(outpost:GetCombatStrength() / 100);

	local maxHP			= outpost:GetMaxHitPoints();
	local curHP			= maxHP - damage;
	local defenseStr	= Locale.ConvertTextKey("TXT_KEY_NUM_COMBAT_STRENGTH", strength);
	defenseStr			= defenseStr .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUM_CUR_HIT_POINTS", curHP, maxHP);

	controls.CityBannerStrengthFrame:SetToolTipString(defenseStr);
	
	RefreshBannerDamageBar(outpostBanner, damage, maxHP);
end

-------------------------------------------------
-- Updates banner to reflect latest outpost info.
-------------------------------------------------
function RefreshOutpostBanner (outpostBanner, iActiveTeam, iActivePlayer)
	if (OutpostInstances[outpostBanner.playerID] == nil or OutpostInstances[outpostBanner.playerID][outpostBanner.outpostID] == nil) then
	    return;
    end

	-- Determine active player and team
	local player = Players[outpostBanner.playerID];	
	local team = Players[outpostBanner.playerID]:GetTeam();
	local isActivePlayerOutpost = (outpostBanner.playerID == iActivePlayer);
	local isActiveTeamOutpost = false;
	if (iActiveTeam == team) then
		isActiveTeamOutpost = true;
	end	
		
	-- Retrieve the outpost instance
	local outpost = player:GetOutpostByID(outpostBanner.outpostID);
	local controls = outpostBanner.SubControls;

	-- Update colors
	local primaryColorRaw, secondaryColorRaw = player:GetPlayerColors();
	local backgroundColorRaw= {x = secondaryColorRaw.x, y = secondaryColorRaw.y, z = secondaryColorRaw.z, w = 0.7};
	local primaryColor 	 	= RGBAObjectToABGRHex( primaryColorRaw );
	local secondaryColor 	= RGBAObjectToABGRHex( secondaryColorRaw );
	local backgroundColor 	= RGBAObjectToABGRHex( backgroundColorRaw );

	controls.CityBannerBackground:SetColor(backgroundColor);

	if (controls.CityBannerBGLeftHL ~= nil) then
		controls.CityBannerBGLeftHL:SetColor( backgroundColor );
	end
	if (controls.CityBannerBGRightHL ~= nil) then
		controls.CityBannerBGRightHL:SetColor( backgroundColor );
	end
	if (controls.CityBannerRightBackground ~= nil) then
		controls.CityBannerRightBackground:SetColor( backgroundColor );
	end
	if (controls.CityBannerLeftBackground ~= nil) then
		controls.CityBannerLeftBackground:SetColor( backgroundColor );
	end

	
	local textColorRaw 		= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 1};
	local textColor200Raw 	= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 0.7};	
	local textColorShadowRaw= {x = 0, y = 0, z = 0, w = 0.5};
	local textColorSoftRaw 	= {x = 1, y = 1, z = 1, w = 0.5};

	local textColor 		= RGBAObjectToABGRHex( textColorRaw );
	local textColor200 		= RGBAObjectToABGRHex( textColor200Raw );
	local textColorShadow 	= RGBAObjectToABGRHex( textColorShadowRaw );
	local textColorSoft 	= RGBAObjectToABGRHex( textColorSoftRaw );

	controls.CityName:SetColor(textColor, 0);
--	controls.CityName:SetColor(textColorShadow, 1);
--	controls.CityName:SetColor(textColorSoft, 2);

	if outpost ~= nil then

		-- Update name
		local outpostName			= outpost:GetNameKey();
		local localizedOutpostName	= Locale.ConvertTextKey(outpostName);
		local convertedKey			= Locale.ToUpper(localizedOutpostName);
		
		controls.CityTypeIcon:SetHide( true );
		controls.CityName:SetText(convertedKey);		

		local strToolTip = "";
		if (UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_SELECTION) then
			if (isActivePlayerOutpost) then
				strToolTip = Locale.ConvertTextKey("TXT_KEY_TT_VIEW_OUTPOST");
			elseif (isActiveTeamOutpost) then
				strToolTip = Locale.ConvertTextKey("TXT_KEY_OUTPOST_TEAMMATE");
			elseif (not Teams[Game.GetActiveTeam()]:IsHasMet(player:GetTeam())) then
				strToolTip = Locale.ConvertTextKey("TXT_KEY_HAVENT_MET");
			else
				strToolTip = Locale.ConvertTextKey("TXT_KEY_TALK_TO_PLAYER_OUTPOST");
			end
		end
		controls.BannerButton:SetToolTipString(strToolTip);

		-- Update strength
		local outpostStrengthStr = math.floor(outpost:GetCombatStrength() / 100);
		controls.CityBannerStrengthFrame:SetColor( secondaryColor );
		controls.ShieldIcon				:SetColor( primaryColor );
		controls.CityStrength			:SetColor( primaryColor, 0 );
		controls.CityStrength			:SetText(outpostStrengthStr);

		-- Update damage
		RefreshOutpostDamage(outpost, outpostBanner, outpost:GetDamage());

		-- Update Garrisoned Unit
		--[[ TODO
		if (controls.GarrisonFrame) then
			controls.GarrisonFrame:SetHide(true);
		end]]--

		-- Update Growth Meter
		if (controls.GrowthBar) then
			
			local currentGrowthPercent = outpost:GetCurrentGrowthPercent() / 100;
			local growthRate = outpost:GetGrowthRate() / 100;
			local growthProgressPlusThisTurnPercent = (currentGrowthPercent + growthRate);
			if (growthProgressPlusThisTurnPercent > 1) then
				growthProgressPlusThisTurnPercent = 1
			end

			-- Repurpose for city population...
			--controls.CityPopulation:SetText(tostring(math.floor(growthRate*100))); -- show percentage?
			controls.CityPopulation:SetText(tostring(0));
			controls.CityPopulation:SetColor( primaryColor, 0 );
			
			controls.GrowthBar:SetPercent( currentGrowthPercent );
			controls.GrowthBarShadow:SetPercent( growthProgressPlusThisTurnPercent );
			controls.GrowthBar:SetColor( primaryColor );
			controls.GrowthBarShadow:SetColor( primaryColor );

			if (controls.CityGrowth) then
				local turnsUntilGrowth = outpost:GetTurnsUntilNextGrowth();
				controls.CityBannerRightBackground:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_OUTPOST_WILL_GROW_TT", localizedOutpostName, turnsUntilGrowth));
			end
		else
			-- If no growth bar, we are an 'other player' outpost
			if (controls.CityPopulation ~= nil) then
				controls.CityPopulation:SetText(tostring(0));
				controls.CityPopulation:SetColor( primaryColor, 0 );
			end
		end	
		
    	controls.CityBannerLeftBackground:SetHide(true);
		if (controls.ProductionBar) then
			controls.ProductionBar:SetHide(true);
			controls.ProductionBarShadow:SetHide(true);
			controls.BuildGrowth:SetHide(true);
		end
		controls.CityBannerButtonBaseRight:SetHide(true);

		-- Hide minor power indicator icons
		if (controls.MinorIndicator) then
			controls.MinorIndicator:SetHide(true);
		end
--		if (controls.StatusIcon) then
--			controls.StatusIcon:SetOffsetX( 0 );
--			controls.StatusIconBG:SetHide( true );
--			controls.StatusMeterFrame:SetHide( true );
--		end

		-- Turn off all City-specific icons
		controls.BlockadedIcon:SetHide(true);
		controls.ConnectedIcon:SetHide(true);
		controls.RazingIcon:SetHide(true);
		controls.ResistanceIcon:SetHide(true);
		controls.PuppetIcon:SetHide(true);
		controls.OccupiedIcon:SetHide(true);
		controls.SpyIcon:SetHide(true);

		-- Range Strike.  Outposts can't do this, so hide it
		if controls.CityAttackFrame ~= nil then
			controls.CityAttackFrame:SetHide( true );
		end

		if (controls.StatusIcon) then
			controls.StatusIcon:SetHide(true);
		end
		if (controls.CityBannerProductionImage) then
			controls.CityBannerProductionImage:SetHide(true);
		end

		controls.IconsStack:ReprocessAnchoring();
		DoResizeBanner(controls);
	end

	if(controls.NameStack)then
		controls.NameStack:CalculateSize();
		controls.NameStack:ReprocessAnchoring();
	end

	controls.StatusBacking				:SetHide(true);
	controls.BlockadedIcon				:SetHide(true);
	controls.ConnectedIcon				:SetHide(true);
	controls.RazingIcon					:SetHide(true);
	controls.ResistanceIcon				:SetHide(true);
	controls.PuppetIcon					:SetHide(true);
	controls.OccupiedIcon				:SetHide(true);
	controls.SpyIcon					:SetHide(true);	
	controls.IconsStack:CalculateSize();
	controls.IconsStack:ReprocessAnchoring();
end

-------------------------------------------------
-- Update the station damage, this will also update the tooltip
-------------------------------------------------
function RefreshStationDamage(station, stationBanner, damage)
	local controls = stationBanner.SubControls;
	local strength = math.floor(station:GetStrengthValue() / 100);

	local maxHP			= station:GetMaxHitPoints();
	local curHP			= maxHP - damage;
	local defenseStr	= Locale.ConvertTextKey("TXT_KEY_NUM_COMBAT_STRENGTH", strength);
	defenseStr			= defenseStr .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUM_CUR_HIT_POINTS", curHP, maxHP);
	controls.CityBannerStrengthFrame:SetToolTipString(defenseStr);
	
	RefreshBannerDamageBar(stationBanner, damage, maxHP);
end

-------------------------------------------------
-- Updates banner to reflect latest station info.
-------------------------------------------------
function RefreshStationBanner (stationBanner)
	if (StationInstances[stationBanner.stationID] == nil) then
		return;
	end

	-- Retrieve the station instance
	local station = Game.GetStationByID(stationBanner.stationID);
	if (station == nil ) then
		print("ERROR: Station doesn't exist or isn't active in the game!");
		return;
	end

	local stationInfo = GameInfo.Stations[station:GetType()];
	local controls = stationBanner.SubControls;

	-- Update Colors
	local primaryColorRaw, secondaryColorRaw = station:GetDefaultColors();
	local backgroundColorRaw = {x = secondaryColorRaw.x, y = secondaryColorRaw.y, z = secondaryColorRaw.z, w = 0.8};
	local primaryColor 		= RGBAObjectToABGRHex( primaryColorRaw );
	local secondaryColor 	= RGBAObjectToABGRHex( secondaryColorRaw );
	local backgroundColor 	= RGBAObjectToABGRHex( backgroundColorRaw );

	controls.CityBannerBackground:SetColor(backgroundColor);

	if(controls.RightBackground ~= nil and controls.LeftBackground ~= nil) then
		controls.RightBackground:SetColor( backgroundColor );
		controls.LeftBackground:SetColor( backgroundColor );
	end

	local textColorRaw 		= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 1};
	local textColorShadowRaw= {x = 0, y = 0, z = 0, w = 0.5};
	local textColorSoftRaw 	= {x = 1, y = 1, z = 1, w = 0.5};
	local textColor 		= RGBAObjectToABGRHex( textColorRaw );
	local textColorShadow 	= RGBAObjectToABGRHex( textColorShadowRaw );
	local textColorSoft 	= RGBAObjectToABGRHex( textColorSoftRaw );
	controls.CityName:SetColor(textColor, 0);
--	controls.CityName:SetColor(textColorShadow, 1);
--	controls.CityName:SetColor(textColorSoft, 2);	

	if station ~= nil then
		-- Update name
		controls.CityName:SetText(Locale.ToUpper(Locale.Lookup(stationInfo.Description)));
		controls.CityTypeIcon:SetHide( true );

		local textureOffset, textureSheet = IconLookup( 10, 32, "CIV_ALPHA_ATLAS" );			
		controls.MinorIndicator:SetColor( primaryColor );
		controls.MinorIndicator:SetTextureOffset(textureOffset);	

		-- Defense/Shield icon
		local strengthStr = math.floor(station:GetStrengthValue() / 100);
		controls.CityBannerStrengthFrame:SetColor( secondaryColor );
		controls.ShieldIcon				:SetColor( primaryColor );
		controls.CityStrength			:SetColor( primaryColor, 0 );
		controls.CityStrength			:SetText( strengthStr );				

		RefreshStationDamage(station, stationBanner, station:GetDamage());

		-- Turn off all City-specific art pieces
		controls.IsThisStation				:SetHide( true );	-- hack
		controls.CityBannerButtonBaseLeft	:SetHide( true );
		controls.CityBannerButtonBaseRight	:SetHide( true );
		controls.CityBannerLeftBackground	:SetHide( true );
		controls.CityBannerRightBackground	:SetHide( true );
		controls.StatusBacking				:SetHide( true );
		controls.BlockadedIcon				:SetHide(true);
		controls.ConnectedIcon				:SetHide(true);
		controls.RazingIcon					:SetHide(true);
		controls.ResistanceIcon				:SetHide(true);
		controls.PuppetIcon					:SetHide(true);
		controls.OccupiedIcon				:SetHide(true);
		controls.SpyIcon					:SetHide(true);		
		
		-- Range Strike.  Stations can't do this, so hide it
		if controls.CityAttackFrame ~= nil then
			controls.CityAttackFrame:SetHide( true );
		end

		controls.IconsStack:ReprocessAnchoring();
		DoResizeBanner(controls);

		-- Refresh the damage bar too	
	end

	if(controls.NameStack)then
		controls.NameStack:CalculateSize();
		controls.NameStack:ReprocessAnchoring();
	end

	controls.IconsStack:CalculateSize();
	controls.IconsStack:ReprocessAnchoring();
end

----------------------------------------------------------------
----------------------------------------------------------------
function SetUpMinorMeter( iMajor, iMinor, controls, minorColor )  

	controls.StatusMeterFrame:SetHide( false );
	controls.StatusIconBG:SetHide( false );
	controls.StatusIcon:SetOffsetX( 0 );
	controls.StatusIcon:SetColor( RGBAObjectToABGRHex( {x=1, y=1, z=1, w=1 }) );
	
	-- If we're neutral, show the minor's own colors
	if (GetCityStateStatusType(iMajor, iMinor) == "MINOR_FRIENDSHIP_STATUS_NEUTRAL") then
		controls.StatusIcon:SetColor( minorColor );
		controls.StatusIconBG:SetHide( true );
    	controls.StatusIcon:SetOffsetX( -5 );
    end
	
	-- If INF is 0, don't bother showing the meter
	if (Players[iMinor]:GetMinorCivFriendshipWithMajor(iMajor) == 0) then
		controls.StatusMeterFrame:SetHide(true);
	end
	
	--UpdateCityStateStatusUI(iMajor, iMinor, controls.PositiveStatusMeter, controls.NegativeStatusMeter, controls.StatusMeterMarker, controls.StatusIconBG);
end


-- ===========================================================================
--	control,	receiving mouse enter
--	id,			ID of city/station
-- ===========================================================================
function OnMouseEnter( control, id )

	if IsCityCanReceiveMouseOverEvents( id ) then
		control:SetAlpha( ALPHA_BANNER_OVER );
	end

end

-- ===========================================================================
--	control,	receiving mouse exit
--	id,			ID of city/station
-- ===========================================================================
function OnMouseExit( control, id )

	if IsCityCanReceiveMouseOverEvents( id ) then
		control:SetAlpha( ALPHA_BANNER_IDLE );
	end
end

-- ===========================================================================
--	Should the city respond to mouse over/out/enter/exit events?
--
function IsCityCanReceiveMouseOverEvents( id )
	local covertOpsSelectedCity = UI.GetCovertOpsSelectedCity();
	local isAllowedByCovertOps	= true;
	if ( covertOpsSelectedCity ~= nil ) then
		isAllowedByCovertOps = ( covertOpsSelectedCity:GetID() ~= id );
	end
	return isAllowedByCovertOps;
end

-------------------------------------------------
-- On City Created
-------------------------------------------------
function OnCityCreated( hexPos, playerID, cityID, cultureType, eraType, continent, size, fowState )
	local controlTable = {};
	
	--If the player is on your team, display TeamCityBanner, otherwise display OtherCityBanner.
	local iActivePlayer = Game.GetActivePlayer();
	local iActiveTeam	= Players[iActivePlayer]:GetTeam();
	local team			= Players[playerID]:GetTeam();
	
	if( CityInstances[ playerID ] ~= nil and
	    CityInstances[ playerID ][ cityID ] ~= nil ) then
	    return;
    end
    
    local gridPosX, gridPosY = ToGridFromHex( hexPos.x, hexPos.y );
		
	local isActiveType = false;
	if(iActiveTeam ~= team) then
	    controlTable = g_OtherIM:GetInstance();
	    controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnBannerClick );
	    controlTable.BannerButton:SetVoid1( gridPosX );
	    controlTable.BannerButton:SetVoid2( gridPosY );
	else
	    controlTable = g_TeamIM:GetInstance();
	    controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnBannerClick );
	    
	    controlTable.BannerButton:SetVoid1( gridPosX );
	    controlTable.BannerButton:SetVoid2( gridPosY );
	    
		controlTable.EjectGarrison:RegisterCallback( Mouse.eLClick, OnEjectGarrisonClick );		
		controlTable.EjectGarrison:SetVoid1(playerID);
		controlTable.EjectGarrison:SetVoid2(cityID);
		controlTable.CityRangeStrikeButton:RegisterCallback( Mouse.eLClick, OnCityRangeStrikeButtonClick );		
		controlTable.CityRangeStrikeButton:SetVoid1(playerID);
		controlTable.CityRangeStrikeButton:SetVoid2(cityID);
		controlTable.AntiOrbitalStrikeButton:RegisterCallback( Mouse.eLClick, OnAntiOrbitalStrikeButtonClick );
		controlTable.AntiOrbitalStrikeButton:SetVoid1(playerID);
		controlTable.AntiOrbitalStrikeButton:SetVoid2(cityID);
		
		isActiveType = true;
	end

	controlTable.BannerButton:RegisterMouseEnterCallback( function() OnMouseEnter(controlTable.Anchor, cityID); end );
	controlTable.BannerButton:RegisterMouseExitCallback( function()	OnMouseExit(controlTable.Anchor, cityID); end  );
	
	local cityBanner = {
		playerID	= playerID,
		cityID		= cityID,
		IsActiveType= isActiveType,
		SubControls = controlTable,
		Hex			= hexPos,
	};
	
	if (CityInstances[playerID] == nil) then
		CityInstances[playerID] = {}
	end
	
	CityInstances[playerID][cityID] = cityBanner;
	
	local LocalHexPos = HexToWorld( hexPos );
	LocalHexPos = VecAdd( LocalHexPos, WorldPositionOffset );
	controlTable.Anchor:SetWorldPosition( LocalHexPos );
	if (controlTable.CovertOpsAnchor ~= nil) then
		controlTable.CovertOpsAnchor:SetWorldPosition( LocalHexPos );
	end

	if (controlTable.CovertOpsIntelReportAnchor ~= nil) then
		controlTable.CovertOpsIntelReportAnchor:SetWorldPosition( LocalHexPos );
	end

	RefreshCityBanner(cityBanner, iActiveTeam, iActivePlayer);
	
	-- Now that it's constructed, set display state for the banner
	if fowState == BlackFog then
	    controlTable.Anchor:SetHide( true );
		controlTable.CovertOpsAnchor:SetHide( true );
		controlTable.CovertOpsIntelReportAnchor:SetHide( true );
    else
	    controlTable.Anchor:SetHide( false );
		controlTable.CovertOpsAnchor:SetHide( false );
		controlTable.CovertOpsIntelReportAnchor:SetHide( false );
	end
	
end
Events.SerialEventCityCreated.Add( OnCityCreated );

-------------------------------------------------
-- On Outpost Created
-------------------------------------------------
function OnOutpostCreated(hexPos, playerID, outpostID, fowState)
	local controlTable = {};

	if(OutpostInstances[playerID] ~= nil and OutpostInstances[playerID][outpostID] ~= nil) then
	    return;
    end

	--If the player is on your team, display TeamCityBanner, otherwise display OtherCityBanner.
	local iActivePlayer = Game.GetActivePlayer();
	local iActiveTeam = Players[iActivePlayer]:GetTeam();
	local team = Players[playerID]:GetTeam();

	local gridPosX, gridPosY = ToGridFromHex(hexPos.x, hexPos.y);		

	local isActiveType = false;
	if(iActiveTeam ~= team) then
	    controlTable = g_OtherIM:GetInstance();
	    controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnOutpostBannerClick );
	    controlTable.BannerButton:SetVoid1( gridPosX );
	    controlTable.BannerButton:SetVoid2( gridPosY );
	else
	    controlTable = g_TeamIM:GetInstance();
	    controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnOutpostBannerClick );	    
	    controlTable.BannerButton:SetVoid1( gridPosX );
	    controlTable.BannerButton:SetVoid2( gridPosY );

		isActiveType = true;
	end

	local outpostBanner = {
		playerID = playerID,
		outpostID = outpostID,
		IsActiveType = isActiveType,
		SubControls = controlTable,
		Hex = hexPos,
	};
	
	if (OutpostInstances[playerID] == nil) then
		OutpostInstances[playerID] = {}
	end
	
	OutpostInstances[playerID][outpostID] = outpostBanner;

	local HexPos = HexToWorld( hexPos );
	controlTable.Anchor:SetWorldPosition( VecAdd( HexPos, WorldPositionOffset ) );

	RefreshOutpostBanner(outpostBanner, iActiveTeam, iActivePlayer);

	if fowState == BlackFog then
	    controlTable.Anchor:SetHide( true );
		controlTable.CovertOpsAnchor:SetHide( true );
		controlTable.CovertOpsIntelReportAnchor:SetHide( true );
    else
	    controlTable.Anchor:SetHide( false );
		controlTable.CovertOpsAnchor:SetHide( false );
		controlTable.CovertOpsIntelReportAnchor:SetHide( false );
	end

end
Events.SerialEventOutpostCreated.Add(OnOutpostCreated);

-------------------------------------------------
-- On Station Created
-------------------------------------------------
function OnStationCreated(hexPos, stationID, fowState)
	local controlTable = {};

	if( StationInstances[ stationID ] ~= nil ) then
	    return;
    end


	local gridPosX, gridPosY = ToGridFromHex( hexPos.x, hexPos.y );		
	local isActiveType = true;
	
	if ( Game.GetStationByID(stationID) == nil ) then
		print("WARNING: Ignoring OnStationCreated( ["..tostring(gridPosX)..","..tostring(gridPosY).."], id="..tostring( stationID )..", fowState:"..tostring(fowState).." ) called but Game.GetStationByID("..tostring( stationID )..") returned NIL!" );
		return;
	end

	controlTable = g_StationIM:GetInstance();
	controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnStationBannerClick );
	controlTable.BannerButton:SetVoid1( gridPosX );
	controlTable.BannerButton:SetVoid2( gridPosY );

	controlTable.BannerButton:RegisterMouseEnterCallback( function() OnMouseEnter(controlTable.Anchor, stationID); end );
	controlTable.BannerButton:RegisterMouseExitCallback( function() OnMouseExit(controlTable.Anchor, stationID); end  );

	local stationBanner = {
		stationID = stationID,
		IsActiveType = isActiveType,
		SubControls = controlTable,
		Hex = hexPos,
	};
	
	StationInstances[stationID] = stationBanner;

	local HexPos = HexToWorld( hexPos );
	controlTable.Anchor:SetWorldPosition( VecAdd( HexPos, WorldPositionOffset ) );
	
	RefreshStationBanner(stationBanner);
	
	if fowState == BlackFog then
		controlTable.Anchor:SetHide( true );
		controlTable.CovertOpsAnchor:SetHide( true );
		controlTable.CovertOpsIntelReportAnchor:SetHide( true );
    else
	    controlTable.Anchor:SetHide( false );
		controlTable.CovertOpsAnchor:SetHide( false );
		controlTable.CovertOpsIntelReportAnchor:SetHide( false );
	end
end
Events.SerialEventStationCreated.Add( OnStationCreated );

-------------------------------------------------------------------------------
-- Check the banner to see if it needs to be rebuilt (active player change)
-------------------------------------------------------------------------------
function CheckCityBannerRebuild( instance, iActiveTeam, iActivePlayer )
		
	local cityTeam = Players[instance.playerID]:GetTeam();
	
    -- If the city banner was instanced for the active team and now its not or vice versa, rebuild the banner
	local bWantActive = cityTeam == iActiveTeam;
	if (instance.IsActiveType ~= bWantActive) then
		-- rebuild the banner
		RebuildBanner(instance, bWantActive, iActiveTeam, iActivePlayer);		
	end
end

-------------------------------------------------
-- Rebuild a City Banner Instance
-------------------------------------------------
function RebuildBanner(instance : table, bannerIsActive : boolean, activeTeam : number, activePlayer : number)
	
	local controlTable = {};

	local gridPosX, gridPosY = ToGridFromHex( instance.Hex.x, instance.Hex.y );
	local worldPos = HexToWorld( instance.Hex );
	
	local bWasHidden = instance.SubControls.Anchor:IsHidden();
	-- --print("Rebuilding banner for player: " .. tostring(instance.playerID) .. " city: " .. tostring(instance.cityID) .. " from active = " .. tostring(instance.IsActiveType) .. " to active = " .. tostring(bWantActive));	

	-- Release the old one
	if (instance.IsActiveType == true) then	
		if (instance.SubControls ~= nil) then
			g_TeamIM:ReleaseInstance(instance.SubControls);
		end
	else
		if (instance.SubControls ~= nil) then
			g_OtherIM:ReleaseInstance(instance.SubControls);
		end
	end

	-- Create the new banner (active or inactive)
	if (not bannerIsActive) then

		-- inactive banner
		controlTable = g_OtherIM:GetInstance();
		controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnBannerClick );
		controlTable.BannerButton:SetVoid1( gridPosX );
		controlTable.BannerButton:SetVoid2( gridPosY );			
	else			
		-- active banner
		controlTable = g_TeamIM:GetInstance();
		controlTable.BannerButton:RegisterCallback( Mouse.eLClick, OnBannerClick );
	    
		controlTable.BannerButton:SetVoid1( gridPosX );
		controlTable.BannerButton:SetVoid2( gridPosY );
	    
		controlTable.EjectGarrison:RegisterCallback( Mouse.eLClick, OnEjectGarrisonClick );		
		controlTable.EjectGarrison:SetVoid1(instance.playerID);
		controlTable.EjectGarrison:SetVoid2(instance.cityID);
		controlTable.CityRangeStrikeButton:RegisterCallback( Mouse.eLClick, OnCityRangeStrikeButtonClick );		
		controlTable.CityRangeStrikeButton:SetVoid1(instance.playerID);
		controlTable.CityRangeStrikeButton:SetVoid2(instance.cityID);
		controlTable.AntiOrbitalStrikeButton:RegisterCallback( Mouse.eLClick, OnAntiOrbitalStrikeButtonClick );
		controlTable.AntiOrbitalStrikeButton:SetVoid1(instance.playerID);
		controlTable.AntiOrbitalStrikeButton:SetVoid2(instance.cityID);
	end
		
	controlTable.Anchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
	controlTable.CovertOpsAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );
	controlTable.CovertOpsIntelReportAnchor:SetWorldPosition( VecAdd( worldPos, WorldPositionOffset ) );

	-- Attach
	instance.SubControls = controlTable;
	-- Set the new active type flag
	instance.IsActiveType = bannerIsActive;
		
	RefreshCityBanner(instance, activeTeam, activePlayer);

	-- Keep the hidden state	
	controlTable.Anchor:SetHide( bWasHidden );
	controlTable.CovertOpsAnchor:SetHide( bWasHidden );
	controlTable.CovertOpsIntelReportAnchor:SetHide( bWasHidden );
end

-------------------------------------------------
-- Change the width of the banner so it looks good with the length of the city name
-------------------------------------------------
function DoResizeBanner(BannerInstance)

	-- Just in case
	BannerInstance.NameStack:CalculateSize();
	BannerInstance.NameStack:ReprocessAnchoring();

	local isStation = false;
	local iWidth = BannerInstance.NameStack:GetSizeX();	

	-- If this control doesn't exist, then we're using the active player banner as opposed to the other player.
	-- NOTE:	There are rare instances when the active player will change (hotseat, autoplay) so just checking
	--			the active player is not good enough.
	if (BannerInstance.CityBannerButtonGlow ~= nil) then
		iWidth = iWidth + 10;	-- Offset for human player's banners
		if(iWidth < 130) then
			iWidth = 130		-- Set minimum witdth for banner so it looks correct with the life bar
		end
		BannerInstance.CityBannerBackgroundIcon:SetSizeX(iWidth);
		BannerInstance.CityBannerButtonGlow:SetSizeX(iWidth);
		BannerInstance.CityBannerButtonBase:SetSizeX(iWidth);
		
	else

		-- Station? (hack: determine station based on art turned on/off)
		if ( BannerInstance.IsThisStation:IsHidden() ) then
			iWidth = iWidth + 20;	
			isStation = true;
		else
			iWidth = iWidth + 10
		end		
		
		if(iWidth < 130) then
			iWidth = 130		-- Set minimum witdth for banner so it looks correct with the life bar
		end
		
		--BannerInstance.CityBannerBaseFrame:SetSizeX(iWidth);
		BannerInstance.CityBannerButtonBase:SetSizeX(iWidth);
	end

	if ( BannerInstance.CityBannerShadow ~= nil ) then
		if (isStation) then
			BannerInstance.CityBannerShadow:SetSizeX( iWidth + 40 );
		else
			BannerInstance.CityBannerShadow:SetSizeX( iWidth + 130 );
		end
	end


	BannerInstance.BannerButton:SetSizeX(iWidth);
	BannerInstance.CityBannerBackground:SetSizeX(iWidth);
	BannerInstance.CityBannerBackgroundHL:SetSizeX(iWidth);
	
	BannerInstance.BannerButton:ReprocessAnchoring();
	BannerInstance.NameStack:ReprocessAnchoring();
end


-------------------------------------------------
-- On Interfacemode Changed
-------------------------------------------------
function OnInterfaceModeChanged(oldInterfaceMode, newInterfaceMode)
	if (oldInterfaceMode ~= newInterfaceMode) then
		if (oldInterfaceMode == InterfaceModeTypes.INTERFACEMODE_SELECTION or newInterfaceMode == InterfaceModeTypes.INTERFACEMODE_SELECTION) then
			OnCityUpdate();
			OnOutpostUpdate();
		end
	end
end
Events.InterfaceModeChanged.Add(OnInterfaceModeChanged);


-------------------------------------------------
-- On City Update
-------------------------------------------------
function OnCityUpdate()
	-- Update all cities
	local iActivePlayer = Game.GetActivePlayer();
	local iActiveTeam = Players[iActivePlayer]:GetTeam();
	
	for i, v in pairs(CityInstances) do
		for iCities, vCities in pairs(v) do
			RefreshCityBanner(vCities, iActiveTeam, iActivePlayer);
		end
	end

	local foo = 2;
end
Events.SerialEventCityInfoDirty.Add(OnCityUpdate);

-------------------------------------------------
-- On Outpost Update
-------------------------------------------------
function OnOutpostUpdate()
	-- Update all outposts
	local iActivePlayer = Game.GetActivePlayer();
	local iActiveTeam = Players[iActivePlayer]:GetTeam();

	for i, v in pairs(OutpostInstances) do
		for iOutposts, vOutposts in pairs(v) do
			RefreshOutpostBanner(vOutposts, iActiveTeam, iActivePlayer);
		end
	end
end
-- Piggyback outpost updating on city updating, since they operate in the same channels
Events.SerialEventCityInfoDirty.Add(OnOutpostUpdate);
Events.SerialEventOutpostInfoDirty.Add(OnOutpostUpdate);

-------------------------------------------------
-- On Station Update
-------------------------------------------------
function OnStationUpdate()
	-- Update all stations

	for i, v in pairs(StationInstances) do
		RefreshStationBanner(v);
	end
end
-- Piggyback station updating on city updating, since they operate in the same channels
Events.SerialEventCityInfoDirty.Add(OnStationUpdate);

-------------------------------------------------
-- On City Moved
-------------------------------------------------
function OnCityMoved(fromHexPos, toHexPos, playerID, cityID)

	local playerTable : table = CityInstances[playerID];
	local bannerInstance : table = playerTable[cityID];

	bannerInstance.Hex = toHexPos;

	local activePlayer : number = Game.GetActivePlayer();
	local activeTeam : number = Players[activePlayer]:GetTeam();

	local cityTeam = Players[bannerInstance.playerID]:GetTeam();
	local bannerIsActive : boolean = (cityTeam == activeTeam);

	RebuildBanner(bannerInstance, bannerIsActive, activeTeam, activePlayer);
end
Events.CityMoved.Add(OnCityMoved);

-------------------------------------------------
-- On City Destroyed
-------------------------------------------------
function OnCityDestroyed(hexPos, playerID, cityID, newPlayerID)
	
	local playerTable = CityInstances[ playerID ];
	local banner = playerTable[ cityID ];
	
	local active_team = Players[Game.GetActivePlayer()]:GetTeam();
	local team = Players[playerID]:GetTeam();
	
	if(active_team ~= team) 
	then
	    g_OtherIM:ReleaseInstance( banner.SubControls );
    else
	    g_TeamIM:ReleaseInstance( banner.SubControls );	    	    
    end
	
	playerTable[cityID] = nil;
	
end
Events.SerialEventCityDestroyed.Add(OnCityDestroyed);
Events.SerialEventCityCaptured.Add(OnCityDestroyed);

-------------------------------------------------
-- On Outpost Removed (Converted, Disbanded, or Destroyed)
-------------------------------------------------
function OnOutpostRemoved (hexPos, playerID, outpostID, fowState)

	local playerTable = OutpostInstances[playerID];
	local banner = playerTable[outpostID];
	local active_team = Players[Game.GetActivePlayer()]:GetTeam();
	local team = Players[playerID]:GetTeam();

	if(active_team ~= team) 
	then
	    g_OtherIM:ReleaseInstance( banner.SubControls );
    else
	    g_TeamIM:ReleaseInstance( banner.SubControls );
    end
	
	playerTable[outpostID] = nil;

end
Events.SerialEventOutpostRemoved.Add(OnOutpostRemoved);

-------------------------------------------------
-- On Station Removed
-------------------------------------------------
function OnStationRemoved (hexPos, stationID, fowState)

	local banner = StationInstances[stationID];

	g_StationIM:ReleaseInstance( banner.SubControls );

	StationInstances[stationID] = nil;
end
Events.SerialEventStationRemoved.Add(OnStationRemoved);

-------------------------------------------------
-- Refresh the City / Station / Outpost Damage bar
-------------------------------------------------
function RefreshBannerDamageBar(instance, iDamage, iMaxDamage)
	
	if instance == nil then
		print("ERROR: Request to refresh City/Station/Outpost banner but NIL instance!");
	    return;
    end
	
	local iHealthPercent = 1 - (iDamage / iMaxDamage);

    instance.SubControls.CityBannerHealthBar:SetPercent(iHealthPercent);
    
	---- Health bar color based on amount of damage
	local COLOR_ABGR_GREEN	= 0xff00ff00;
	local COLOR_ABGR_YELLOW = 0xff00f0f0;
	local COLOR_ABGR_RED	= 0xff0000ff;

	local tBarColor;	
    if iHealthPercent > 0.66 then
		tBarColor = COLOR_ABGR_GREEN;        
    elseif iHealthPercent > 0.33 then
		tBarColor = COLOR_ABGR_YELLOW;
    else
		tBarColor = COLOR_ABGR_RED;
    end
	instance.SubControls.CityBannerHealthBar:SetColor( tBarColor );
    
    -- Show or hide the Health Bar as necessary
    if (iDamage == 0) then
		instance.SubControls.CityBannerHealthBarBase:SetHide( true );
	else
		instance.SubControls.CityBannerHealthBarBase:SetHide( false );
    end

end

-------------------------------------------------
-- Update the output damage, this will also update the tooltip
-------------------------------------------------
function RefreshCityDamage(city, cityBanner, damage)
	local controls = cityBanner.SubControls;
	local strength = math.floor(city:GetStrengthValue() / 100);

	local maxHP				= city:GetMaxHitPoints();
	local curHP				= maxHP - damage;
	local defenseStr		= Locale.ConvertTextKey("TXT_KEY_NUM_COMBAT_STRENGTH", strength);
	defenseStr			= defenseStr .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_NUM_CUR_HIT_POINTS", curHP, maxHP);
	controls.CityBannerStrengthFrame:SetToolTipString(defenseStr);
	
	RefreshBannerDamageBar(cityBanner, damage, maxHP);
end


-------------------------------------------------
-- On City Set Damage
-------------------------------------------------
function OnCitySetDamage(iPlayerID, iCityID, iDamage, iPreviousDamage)
	
	local playerTable = CityInstances[ iPlayerID ];
	local instance = playerTable[ iCityID ];
	local city = Players[iPlayerID]:GetCityByID(iCityID);
	
	if (city ~= nil and instance ~= nil) then
		RefreshCityDamage(city, instance, iDamage);
	end

end
Events.SerialEventCitySetDamage.Add(OnCitySetDamage);


-------------------------------------------------
-- On Outpost Set Damage
-------------------------------------------------
function OnOutpostSetDamage(iPlayerID, iOutpostID, iDamage, iPreviousDamage)
	
	local playerTable = OutpostInstances[ iPlayerID ];	
	local outpost = Players[iPlayerID]:GetOutpostByID(iOutpostID);
	
	if (outpost ~= nil) then
		local instance = playerTable[iOutpostID];
		if (instance ~= nil) then
			RefreshOutpostDamage(outpost, instance, iDamage);
		end
	end
end
Events.SerialEventOutpostSetDamage.Add(OnOutpostSetDamage);

-------------------------------------------------
-- On Station Set Damage
-------------------------------------------------
function OnStationSetDamage(iPlayerID, iPlotIndex, iDamage, iPreviousDamage)
	
	-- check if there's a station at this plot index
	for k,v in pairs(StationInstances) do
		
		local gridPosX, gridPosY = ToGridFromHex( v.Hex.x, v.Hex.y );
		local plot = Map.GetPlot( gridPosX, gridPosY );
		local plotIndex = plot:GetPlotIndex();

		if (plotIndex == iPlotIndex) then
		
			local station = Game.GetStationByID(k);

			if (station ~= nil) then
				RefreshStationDamage(station, v, iDamage);
			end
		end
	end
end
Events.SerialEventSiteSetDamage.Add(OnStationSetDamage);

-------------------------------------------------
-- On Specific City changed
-------------------------------------------------
function OnSpecificCityInfoDirty(iPlayerID, iCityID, eUpdateType)
	
	if (eUpdateType == CityUpdateTypes.CITY_UPDATE_TYPE_BANNER or
	    eUpdateType == CityUpdateTypes.CITY_UPDATE_TYPE_ENEMY_IN_RANGE or
	    eUpdateType == CityUpdateTypes.CITY_UPDATE_TYPE_GARRISON) then
		
		local playerTable = CityInstances[ iPlayerID ];
		if playerTable == nil then
			return;
		end
		
		local instance = playerTable[ iCityID ];
		if instance == nil then
			return;
		end
						
		if (eUpdateType == CityUpdateTypes.CITY_UPDATE_TYPE_ENEMY_IN_RANGE) then
			UpdateRangeIcons(instance);
		else		
			local iActivePlayer = Game.GetActivePlayer();
			local iActiveTeam = Players[iActivePlayer]:GetTeam();
			RefreshCityBanner(instance, iActiveTeam, iActivePlayer);
		end		
	end
	
end
Events.SpecificCityInfoDirty.Add(OnSpecificCityInfoDirty);


------------------------------------------------------------
------------------------------------------------------------
function OnHexFogEvent( hexPos, fowType, bWholeMap )
    if( bWholeMap ) then
        for playerID,playerTable in pairs( CityInstances ) do
            for cityID,instance in pairs( playerTable ) do
                if( fowType == BlackFog ) then
                    instance.SubControls.Anchor:SetHide( true );
					if (instance.CovertOpsAnchor ~= nil) then
						instance.CovertOpsAnchor:SetHide( true );
					end
                elseif( fowType == GreyFog ) then
                    instance.SubControls.Anchor:SetHide( false );
					if (instance.CovertOpsAnchor ~= nil) then
						instance.CovertOpsAnchor:SetHide( false );
					end
                else
                    instance.SubControls.Anchor:SetHide( false );
					if (instance.CovertOpsAnchor ~= nil) then
						instance.CovertOpsAnchor:SetHide( false );
					end
                end
            end
        end
		for stationID, stationInstance in pairs(StationInstances) do
			if (fowType == BlackFog) then
				stationInstance.SubControls.Anchor:SetHide(true);
			else
				stationInstance.SubControls.Anchor:SetHide(false);
			end
		end
    else
        local gridPosX, gridPosY = ToGridFromHex( hexPos.x, hexPos.y );
		local plot = Map.GetPlot( gridPosX, gridPosY );
		if plot ~= nil then
			local city = plot:GetPlotCity();
			if city ~= nil then
				local cityID = city:GetID();
				local player = city:GetOwner();
				if player ~= -1 then
					local playerTable = CityInstances[ player ];
					if playerTable then
						local instance = playerTable[ cityID ];
						if instance then
							if fowType == BlackFog  then
								instance.SubControls.Anchor:SetHide( true );
								instance.SubControls.CovertOpsAnchor:SetHide( true );
							else
								local garrisonedUnit = city:GetDefendingUnit();
								-- WRM: UnitMoving is not a function defined anywhere as far back as core CivBE.  I don't know
									--		if this was a bug that shipped with Civ or what, but I removed the check and fixed
									--		the assert.
								--if garrisonedUnit and not UnitMoving(garrisonedUnit:GetOwner(), garrisonedUnit:GetID()) then
								if garrisonedUnit ~= nil then
									GarrisonComplete( instance, city );
								end
								instance.SubControls.Anchor:SetHide( false );
								instance.SubControls.CovertOpsAnchor:SetHide( false );
							end
						end
					end
				end
			else
				local station = Game.GetStationByPlot(plot:GetPlotIndex());
				if (station ~= nil) then
					local instance = StationInstances[station:GetID()];
					if instance then
						if fowType == BlackFog  then
							instance.SubControls.Anchor:SetHide( true );
						else
							instance.SubControls.Anchor:SetHide( false );
						end
					end
				end
			end
		end
	end
end
Events.HexFOWStateChanged.Add( OnHexFogEvent );

-------------------------------------------------
-- On City Range Strike Button Selected
-------------------------------------------------
function OnCityRangeStrikeButtonClick( PlayerID, CityID )
	local player = Players[PlayerID];
	if (player == nil) then
		--print("Invalid player");
		return;
	end
	
	local city = player:GetCityByID(CityID);

	if (player:GetID() ~= Game.GetActivePlayer()) then
		--print("Not my player!");
		return;
	end

	if (city == nil) then
		--print("No city!");
		return;
	end;
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK);
	UI.ClearSelectionList();
	UI.SelectCity( city );

	Events.InitCityRangeStrike( PlayerID, CityID );
end


function OnInitCityRangeStrike( PlayerID, CityID )

	local player = Players[PlayerID];
	if (player == nil) then
		--print("Invalid player");
		return;
	end
	
	local city = player:GetCityByID(CityID);

	if (player:GetID() ~= Game.GetActivePlayer()) then
		--print("Not my player!");
		return;
	end

	if (city == nil) then
		--print("No city!");
		return;
	end;

	UI.SelectCity( city );
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK);
end
Events.InitCityRangeStrike.Add( OnInitCityRangeStrike );

-------------------------------------------------
-- On Anti Orbital Strike Button Selected
-------------------------------------------------
function OnAntiOrbitalStrikeButtonClick( PlayerID, CityID )
	local player = Players[PlayerID];
	if (player == nil) then
		--print("Invalid player");
		return;
	end
	
	local city = player:GetCityByID(CityID);

	if (player:GetID() ~= Game.GetActivePlayer()) then
		--print("Not my player!");
		return;
	end

	if (city == nil) then
		--print("No city!");
		return;
	end;
	
	UI.ClearSelectionList();
	UI.SelectCity( city );
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK);
end

------------------------------------------------------------
-- OnEjectGarrisonClick - kick out the city's garrison!
------------------------------------------------------------
function OnEjectGarrisonClick ( PlayerID, CityID )
	
	local player = Players[PlayerID];
	if (player == nil) then
		--print("Invalid player");
		return;
	end
	
	local city = player:GetCityByID(CityID);

	if (player:GetID() ~= Game.GetActivePlayer()) then
		--print("Not my player!");
		return;
	end

	if (city == nil) then
		--print("No city!");
		return;
	end;

	local unit = city:GetDefendingUnit();
	if (unit == nil) then
		--print("No unit!");
		return;
	end;
	
	UI.SetPlaceUnit(unit);
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT);
	OnCityUpdate();
	UI.HighlightCanPlacePlots(unit, city:Plot());
end

------------------------------------------------------------
------------------------------------------------------------
function LeaderSelected( ePlayer )

	if not Players[Game.GetActivePlayer()]:IsTurnActive() or Game.IsProcessingMessages() then
		return;
	end

	local player = Players[ePlayer];
    if player:IsHuman() then
        Events.OpenPlayerDealScreenEvent( ePlayer );
    else
        UI.SetRepeatActionPlayer(ePlayer);
        UI.ChangeStartDiploRepeatCount(1);
    	player:DoBeginDiploWithHuman();
	end
end

------------------------------------------------------------
------------------------------------------------------------
function OnBannerClick( x, y )
	local plot = Map.GetPlot( x, y );
	if plot then
		local playerID = plot:GetOwner();
		local player = Players[playerID];
		
		-- Active player city
		if playerID == Game.GetActivePlayer() then
			-- Puppets are special
			if (plot:GetPlotCity():IsPuppet() and not player:MayNotAnnex()) then
				local popupInfo = {
						Type = ButtonPopupTypes.BUTTONPOPUP_ANNEX_CITY,
						Data1 = plot:GetPlotCity():GetID(),
						Data2 = -1,
						Data3 = -1,
						Option1 = false,
						Option2 = false;
					}
				Events.SerialEventGameMessagePopup(popupInfo);
			else
				UI.DoSelectCityAtPlot( plot );
			end
			
		-- Other player, which has been met
		elseif (Teams[Game.GetActiveTeam()]:IsHasMet(player:GetTeam())) then
			
			if player:IsMinorCiv() then
				UI.DoSelectCityAtPlot( plot );
			else
				LeaderSelected( playerID );
			end
		end
	end
end

------------------------------------------------------------
------------------------------------------------------------
function OnOutpostBannerClick (x, y)
	local plot		= Map.GetPlot( x, y );
	local plotIndex	= plot:GetPlotIndex();
	local playerID	= plot:GetOwner();
	local player	= Players[playerID];

	-- Our outpost or another players?
	if playerID == Game.GetActivePlayer() then		
		--local popupInfo = {
			--Type = ButtonPopupTypes.BUTTONPOPUP_OUTPOST,
			--Data1 = plotIndex,
			--Data2 = -1,
			--Data3 = -1,
			--Option1 = false,
			--Option2 = false;
		--}
		--Events.SerialEventGameMessagePopup(popupInfo);
	elseif (player ~= nil) then
		local activeTeam = Game.GetActiveTeam();
		local playerTeam = player:GetTeam();
		if ( Teams[activeTeam]:IsHasMet( playerTeam )) then
			if player:IsMinorCiv() then
				UI.DoSelectCityAtPlot( plot );
			else
				LeaderSelected( playerID );
			end
		else
			print("Clicked an Outpost Banner but hasn't met other player?");
		end
	end
end

------------------------------------------------------------
------------------------------------------------------------
function OnStationBannerClick (x, y)
	local plot		= Map.GetPlot( x, y );
	local plotIndex = plot:GetPlotIndex();

	local popupInfo = {
			Type = ButtonPopupTypes.BUTTONPOPUP_STATION,
			Data1 = plotIndex,
			Data2 = -1,
			Data3 = -1,
			Option1 = false,
			Option2 = false;
		}
	Events.SerialEventGameMessagePopup(popupInfo);
end

------------------------------------------------------------
------------------------------------------------------------
function GarrisonComplete( cityBanner, pCity )
	local active_team = Players[Game.GetActivePlayer()]:GetTeam();
	local team = Players[cityBanner.playerID]:GetTeam();
	
	local controls = cityBanner.SubControls;
end

-------------------------------------------------
-- On Unit Garrison
-------------------------------------------------
function OnUnitGarrison( playerID, unitID, bGarrisoned )
-- WRM: UnitMoving is not a function defined anywhere as far back as core CivBE.  I don't know
	--		if this was a bug that shipped with Civ or what, but I removed the check and fixed
	--		the assert.
--	if bGarrisoned and not UnitMoving(playerID, unitID) then
	if bGarrisoned then
		local player = Players[ playerID ];
		local unit = player:GetUnitByID( unitID );
		local cityBanners = CityInstances[ playerID ];
		if unit ~= nil and cityBanners ~= nil then
			local city = unit:GetGarrisonedCity();
			if city ~= nil then
				local banner = cityBanners[city:GetID()];
				if banner ~= nil then
					GarrisonComplete( banner, city );
				end
			end
		end
	end
end
Events.UnitGarrison.Add( OnUnitGarrison );

-------------------------------------------------
-- On Unit Move Queue Changed
-------------------------------------------------
function OnUnitMoveQueueChanged( playerID, unitID, bRemainingMoves )
	if not bRemainingMoves then
		local player = Players[ playerID ];
		local unit = player:GetUnitByID( unitID );
		local cityBanners = CityInstances[ playerID ];
		if unit ~= nil and cityBanners ~= nil and unit:IsGarrisoned() then
			local city = unit:GetGarrisonedCity();
			if city ~= nil then
				local banner = cityBanners[city:GetID()];
				if banner ~= nil then
					GarrisonComplete( banner, city );
				end
			end
		end
	end
end
Events.UnitMoveQueueChanged.Add( OnUnitMoveQueueChanged );

-------------------------------------------------
-------------------------------------------------
function OnProdClick( cityID, prodName )
	local playerID = Game.GetActivePlayer();
	local activePlayer = Players[playerID]
	local city = activePlayer:GetCityByID(cityID);
	if city and not city:IsPuppet() and activePlayer:IsTurnActive() then
		local popupInfo = {
				Type = ButtonPopupTypes.BUTTONPOPUP_CHOOSEPRODUCTION,
				Data1 = cityID,
				Data2 = -1,
				Data3 = -1,
				Option1 = false,
				Option2 = false;
			}
		Events.SerialEventGameMessagePopup(popupInfo);
		-- send production popup message
	end
end

------------------------------------------------------------
------------------------------------------------------------
function OnInterfaceModeChanged(oldInterfaceMode, newInterfaceMode)
	local disableBanners = newInterfaceMode ~= InterfaceModeTypes.INTERFACEMODE_SELECTION;
	for iPlayer, playerCityBanners in pairs(CityInstances) do
		for iCity, cityBanner in pairs(playerCityBanners) do
			cityBanner.SubControls.BannerButton:SetDisabled(disableBanners);
			cityBanner.SubControls.BannerButton:EnableToolTip(not disableBanners);
		end
	end
end
Events.InterfaceModeChanged.Add(OnInterfaceModeChanged);

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnCityBannerActivePlayerChanged( iActivePlayer, iPrevActivePlayer )

	local iActiveTeam = Players[iActivePlayer]:GetTeam();
	-- Update all cities
	for i, v in pairs(CityInstances) do
		for iCities, vCities in pairs(v) do
			CheckCityBannerRebuild(vCities, iActiveTeam, iActivePlayer);
		end
	end
end
Events.GameplaySetActivePlayer.Add(OnCityBannerActivePlayerChanged);

------------------------------------------------------------
------------------------------------------------------------
function HideGarrisonRing(iX, iY, bHide)
	local pPlot = Map.GetPlot( iX, iY );
	if pPlot ~= nil then
		local pCity = pPlot:GetPlotCity();
		if pCity ~= nil then
			local cityID = pCity:GetID();
			local playerID = pCity:GetOwner();
			if playerID ~= -1 then
				-- Only the active team has a Garrison ring			
				local eActiveTeam = Players[Game.GetActivePlayer()]:GetTeam();
				local eCityTeam = Players[playerID]:GetTeam();
	
				--[[if eActiveTeam == eCityTeam then			
					local playerTable = CityInstances[ playerID ];
					if playerTable then
						local pBannerInstance = playerTable[ cityID ];
						if pBannerInstance ~= nil then					
							if (bHide) then
								pBannerInstance.SubControls.GarrisonFrame:SetHide(true);
							else
								-- Only show it if we really need to
								local garrisonedUnit = pCity:GetDefendingUnit();
								if garrisonedUnit ~= nil then
									pBannerInstance.SubControls.GarrisonFrame:SetHide(false);
								end							
							end
						end
					end
				end]]--
			end
		end
	end
end
------------------------------------------------------------
------------------------------------------------------------
function OnCombatBegin( attackerPlayerID,
                        attackerUnitID,
                        attackerUnitDamage,
                        attackerFinalUnitDamage,
                        attackerMaxHitPoints,
                        defenderPlayerID,
                        defenderUnitID,
                        defenderUnitDamage,
                        defenderFinalUnitDamage,
                        defenderMaxHitPoints, 
                        bContinuation,
                        attackerX,
                        attackerY,
                        defenderX,
                        defenderY )
    --print( "CityBanner CombatBegin" );                        
				
	HideGarrisonRing(attackerX, attackerY, true);
	HideGarrisonRing(defenderX, defenderY, true);
end
Events.RunCombatSim.Add( OnCombatBegin );


------------------------------------------------------------
------------------------------------------------------------
function OnCombatEnd( attackerPlayerID,
                      attackerUnitID,
                      attackerUnitDamage,
                      attackerFinalUnitDamage,
                      attackerMaxHitPoints,
                      defenderPlayerOD,
                      defenderUnitID,
                      defenderUnitDamage,
                      defenderFinalUnitDamage,
                      defenderMaxHitPoints,
                      attackerX,
                      attackerY,
					  defenderX,
                      defenderY )
                         
    --print( "CityBanner CombatEnd" );                        
    
	HideGarrisonRing(attackerX, attackerY, false);
	HideGarrisonRing(defenderX, defenderY, false);
end
Events.EndCombatSim.Add( OnCombatEnd );


-- ===========================================================================
-- scan for all cities when we are loaded
-- this keeps the banners from disappearing on hotload
-- ===========================================================================
if( ContextPtr:IsHotLoad() ) then
    local i = 0;
    local player = Players[i];
    while player ~= nil 
    do
        if( player:IsAlive() ) then
			for city in player:Cities() do
    			if( city ~= nil ) then
    				OnCityCreated( ToHexFromGrid( Vector2( city:GetX(), city:GetY() ) ), player:GetID(), city:GetID() );
				end
            end

			for outpostIndex = 0, player:GetNumOutposts() - 1, 1
   			do
				local outpost = player:GetOutpostByID( outpostIndex );
				if( outpost ~= nil ) then
					OnOutpostCreated( ToHexFromGrid( Vector2( outpost:GetX(), outpost:GetY() ) ), player:GetID(), outpost:GetID() );
				end
			end
        end

        i = i + 1;
        player = Players[i];
    end

	for stationIndex = 0, Game.GetNumActiveStations() - 1, 1 
	do
		local station = Game.GetStationByIndex( stationIndex );
		local fow	  = WhiteFog;
		if( station ~= nil ) then
			OnStationCreated( ToHexFromGrid( Vector2( station:GetX(), station:GetY() ) ), stationIndex, fow );
		end
	end
end


-- ===========================================================================
-- ===========================================================================
function OnSetCovertOpsView()
	OnCityUpdate();
end
Events.SetCovertOpsView.Add(OnSetCovertOpsView)

function OnCovertOpsCitySelectionChanged()
	OnCityUpdate();
end
Events.CovertOpsCitySelectionChanged.Add(OnCovertOpsCitySelectionChanged)