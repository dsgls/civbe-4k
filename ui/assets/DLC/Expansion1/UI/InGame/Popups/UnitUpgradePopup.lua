-- ===========================================================================
--
--		Unit Upgrade Popup v3.4
--
--	Handles showing the existing unit upgrades in a grid as well as allow for
--	selecting a unit to inspect.
--	Also handles inspecting a unit, allowing a player to select upgrade perks.
--
-- ===========================================================================

include("AffinityInclude");			
include("IconSupport");
include("InstanceManager");
include("InfoTooltipInclude");		-- Perk text
include("MathHelpers");				-- Polar coordinates
include("SupportFunctions");
include("TabSupport");
include("UIExtras");



-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local DEBUG_CACHE_SCREEN_NAME	:string = "UnitUpgradePopup";
local DEBUG_SHOW_IDS			:boolean= false;
local DEBUG_ONE_UNIT_ONLY_ID	:number = -1;	-- When not -1, will be only unit populated in system

local MAX_PARTICLES				:number = 30;	-- UI FX for upgrading
local HEIGHT_TOP_PANEL			:number = 36;
local HEIGHT_TOP_BANNER			:number = 2;
local HEIGHT_TABS_BANNER		:number = 80;
local MAX_UPGRADE_LEVELS		:number = 3;	
local TEXTURE_SLOT				:string = "UnitUpgradePerkSlotPrevious.dds";
local TEXTURE_SLOT_CURRENT		:string = "UnitUpgradePerkSlotCurrent.dds";
local TEXTURE_SLOT_FUTURE		:string = "UnitUpgradePerkSlotFuture.dds";
local TEXTURE_UPGRADE_CHOSEN	:string = "UnitUpgradeChosenButton.dds";	-- already purchased
local TEXTURE_UPGRADE_DISABLED	:string = "UnitUpgradeCostButton.dds";		-- future/unavailable upgrade 
local TEXTURE_UPGRADE_PURCHASE	:string = "UnitUpgradeUpgradeButton.dds";	-- one that can be bought
local TEXTURE_BG_RING_NORMAL	:string = "UnitUpgradeChooserFrame.dds";
local TEXTURE_STAND_OFF			:string = "UnitUpgradeUnitStandOff.dds";
local TEXTURE_STAND_ON			:string = "UnitUpgradeUnitStandOn.dds";
local HARMONY_AFFINITY_TYPE		:number = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID;
local PURITY_AFFINITY_TYPE		:number = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID;
local SUPREMACY_AFFINITY_TYPE	:number = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID;
local ROMAN_NUMBERS				:table	= {"I","II","III","IV","V","VI","VII","VIII","IX","X"};


-- ===========================================================================
--	ENUMS
-- ===========================================================================

local State						:table  = { SELECT_UNIT = 1, UPGRADE_UNIT = 2, VIEW_UNIT = 3 };
local Filter					:table  = { ALL = "All", AVAIL="Avail", MELEE = "Melee", RANGED = "Ranged", NAVAL = "Naval", HOVER = "Hover", AIR = "Air" };
local IconModifier				:table  = { NONE = 1, SMALL = 2, COLOR = 3 };

local UpgradePositioning		:table	= {};
UpgradePositioning.Distance					= {};		-- Radius distance from center of the circle
UpgradePositioning.Distance[1]				= 0;
UpgradePositioning.Distance[2]				= 97;		 
UpgradePositioning.Distance[3]				= 147;		
UpgradePositioning.Distance["Additional"]	= 51;		-- Need more spacing when there are multiple level 1 upgrades
UpgradePositioning.Angle					= {};
UpgradePositioning.Angle["Harmony"]			= 0;		-- Could stop doing 90- in the angle calculation and store these in Affinity (diplo wheel would use values too!)
UpgradePositioning.Angle["PurityHarmony"]	= 60;
UpgradePositioning.Angle["Purity"]			= 120;
UpgradePositioning.Angle["PuritySupremacy"]	= 180;
UpgradePositioning.Angle["Supremacy"]		= 240;
UpgradePositioning.Angle["HarmonySupremacy"]= 300;

-- Map the index of icons in the atlas 
local AffinityAtlasIndex	:table	= {
	HALF_PURITY_HARMONY		= 0,
	HALF_PURITY_SUPREMACY	= 1,
	HALF_SUPREMACY_HARMONY	= 2,
	BASE_UPGRADE			= 3,
	SMALL_SUPREMACY_HARMONY	= 4,
	SMALL_PURITY_HARMONY	= 5,
	SMALL_PURITY_SUPREMACY	= 6,
	HARMONY					= 7,
	PURITY					= 8,
	SUPREMACY				= 9,
	BLANK					= 10,
	SMALL_SUPREMACY			= 11,
	SMALL_HARMONY			= 12,
	SMALL_PURITY			= 13,
	COLOR_HARMONY			= 14,
	COLOR_PURITY			= 15,
	COLOR_SUPREMACY			= 16,
	COLOR_PURITY_HARMONY	= 17,
	COLOR_PURITY_SUPREMACY	= 18,
	COLOR_SUPREMACY_HARMONY = 19
};

-- Potentially move to ColorAtlas:
local UpgradeColors			:table	= {};
UpgradeColors["GRAY"]				= 0xee88716a;
UpgradeColors["NORMAL"]				= 0xffe4cbb6;
UpgradeColors["LOCKED"]				= 0xff948b76;

local m_bShown : boolean = false;

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_cardIM			:table	= InstanceManager:new("UnitCard",		"Content",	Controls.CardStack);
local m_upgradeIM		:table	= InstanceManager:new("UpgradeButton",	"Button",	Controls.UpgradeCircleCenter);
local m_perkIM			:table	= InstanceManager:new("PerkContent",	"Content",	Controls.PerkStack);
local m_AbilityBuffIM	:table	= InstanceManager:new("AbilityBuff",	"Text",		Controls.AbilitiesStack);
local m_ParticleFrontIM	:table	= InstanceManager:new("PixieDust",		"Content",	Controls.ParticleAreaFront);
local m_ParticleBackIM	:table	= InstanceManager:new("PixieDust",		"Content",	Controls.ParticleAreaBack);
local m_popupInfo		:table	= nil;
local m_player			:object = nil;
local m_allUnits		:table  = nil;
local m_unit			:table	= nil;
local m_currentUpgrade	:table	= nil;	-- The upgrade the engine wants the player to take
local m_selectedUpgrade	:table	= nil;	-- The upgrade the player may have selected to view
local m_selectedPerk	:table  = nil;
local m_allUnitPerkStats:table	= {};					-- key is unit ID, value is augmented stat values from perk being applied
local m_state			:number = State.SELECT_UNIT;
local m_filter			:string = Filter.ALL;
local m_width			:number = 1024;
local m_height			:number = 768;
local m_tabs			:table;
local m_hiddenAtShutdown	:boolean = true;
local m_upgradeNotifications:table = {};



-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--	ENGINE EVENT
-- ===========================================================================
function OnPopup(popupInfo : table)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_UNIT_UPGRADE) then
		-- Hide this popup if it's showing and the message is not from the tutorial system.
		if (not ContextPtr:IsHidden() and popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TUTORIAL) then
			HideWindow();
		end
		return;
	end

	m_popupInfo = popupInfo;
	
	local isShowRequest : boolean = true;
	
	-- Toggle?
	if (popupInfo.Data1 == 1) and (ContextPtr:IsHidden() == false) then
		isShowRequest = false;		
	end

	-- Final process:
	if (isShowRequest) then
		ShowWindow();
	else
		HideWindow();
	end
end


-- ===========================================================================
--	For the tiny Roman numbers on the grid page...
--	Assumes a custom atlased texture exists in the following format:
--     ______________..
--   |
--   |   I   II  III      <-- Inactive row  
--   |
--   |   I   II  III      <-- Active row
--	 |
--   |   I   II  III      <-- (Active) Highlight row.
--   |_______________..
--
--	image		Image control (w/ UnitUpgradeLevelIndicator32.dds) to change
--	n			Number to show
--	isActive	Number currently for an active (can be or has been) upgraded?
--	isHighlight	Number for an upgrade that can be selected now?
--
-- ===========================================================================
function SetRomanNumeralTexture( imageControl:table, n:number, isActive:boolean, isHighlight:boolean )	
	imageControl:SetTextureOffsetVal( ((n-1)*32), (isActive and (isHighlight and 64 or 32) or 0) );
end


-- ===========================================================================
--	Set # used on a tab to show amount of new upgrades
--
function SetBadge( name:string, amt:number )
	if amt<1 then
		Controls["Filter"..name.."Badge"]:SetHide( true );
	else
		Controls["Filter"..name.."Badge"]:SetHide( false );
		Controls["Filter"..name.."Label"]:SetText( tostring(amt) );
	end
end

-- ===========================================================================
-- Helper class return index number of the affinity icon based on stats passed in.
--
function GetAffinityIconIndex( purity:number, harmony:number, supremacy:number, iconModifier:number )
	
	local index		:number	= AffinityAtlasIndex.BASE_UPGRADE;
	local isSmall	:boolean= (iconModifier == IconModifier.SMALL);
	local isColor	:boolean= (iconModifier == IconModifier.COLOR);

	if isSmall then
		if purity > 0 and harmony > 0 and supremacy > 0 then
			print("ERROR: No support for small affinity icons that use all 3 affinities!");
			AssertDueToAbove();
		elseif purity > 0 and harmony > 0 then		index = AffinityAtlasIndex.SMALL_PURITY_HARMONY;
		elseif purity > 0 and supremacy > 0 then	index = AffinityAtlasIndex.SMALL_PURITY_SUPREMACY;
		elseif supremacy > 0 and harmony > 0 then	index = AffinityAtlasIndex.SMALL_SUPREMACY_HARMONY;
		elseif harmony > 0 then						index = AffinityAtlasIndex.SMALL_HARMONY;
		elseif purity > 0 then						index = AffinityAtlasIndex.SMALL_PURITY;
		elseif supremacy > 0 then					index = AffinityAtlasIndex.SMALL_SUPREMACY;
		end
	elseif isColor then
		if purity > 0 and harmony > 0 and supremacy > 0 then
			print("ERROR: No support for color affinity icons that use all 3 affinities!");
			AssertDueToAbove();
		elseif purity > 0 and harmony > 0 then		index = AffinityAtlasIndex.COLOR_PURITY_HARMONY;
		elseif purity > 0 and supremacy > 0 then	index = AffinityAtlasIndex.COLOR_PURITY_SUPREMACY;
		elseif supremacy > 0 and harmony > 0 then	index = AffinityAtlasIndex.COLOR_SUPREMACY_HARMONY;
		elseif harmony > 0 then						index = AffinityAtlasIndex.COLOR_HARMONY;
		elseif purity > 0 then						index = AffinityAtlasIndex.COLOR_PURITY;
		elseif supremacy > 0 then					index = AffinityAtlasIndex.COLOR_SUPREMACY;
		end
	else
		if purity > 0 and harmony > 0 and supremacy > 0 then
			print("ERROR: No support for affinity icons that use all 3 affinities!");
			AssertDueToAbove();
		elseif purity > 0 and harmony > 0 then		index = AffinityAtlasIndex.HALF_PURITY_HARMONY;
		elseif purity > 0 and supremacy > 0 then	index = AffinityAtlasIndex.HALF_PURITY_SUPREMACY;
		elseif supremacy > 0 and harmony > 0 then	index = AffinityAtlasIndex.HALF_SUPREMACY_HARMONY;
		elseif harmony > 0 then						index = AffinityAtlasIndex.HARMONY;
		elseif purity > 0 then						index = AffinityAtlasIndex.PURITY;
		elseif supremacy > 0 then					index = AffinityAtlasIndex.SUPREMACY;
		end
	end
	return index;
end


-- ===========================================================================
--	Coverts values into strings decorated by Text Icons to show positive
--	or negative deltas in the result.
--
function GetStatsIconStrings( movement:number, strength:number, range:number, rangedStrength:number, deltaMovement:number, deltaStrength:number, deltaRange:number, deltaRangedStrength:number, isShowingStats:boolean )
	
	if isShowingStats == nil then isShowingStats = false; end

	local movementString		:string = "";
	local strengthString		:string = "";
	local rangeString			:string = "";
	local rangedStrengthString	:string = "";

	if deltaMovement > 0 then	
		movementString = movementString.."[ICON_STAT_INCREASE]";
		if isShowingStats then movementString = movementString.."[COLOR:Green](+"..tostring(deltaMovement)..")[ENDCOLOR]"; end
	elseif deltaMovement < 0 then	
		movementString = movementString.."[ICON_STAT_DECREASE]";
		if isShowingStats then movementString = movementString.."[COLOR:Red](-"..tostring(deltaMovement)..")[ENDCOLOR]"; end
	end
	movementString = movementString .. m_unit.Movement .. "[ICON_MOVES]";
		
	if deltaStrength > 0 then
		strengthString = strengthString.."[ICON_STAT_INCREASE]";
		if isShowingStats then strengthString = strengthString.."[COLOR:Green](+"..tostring(deltaStrength)..")[ENDCOLOR]"; end
	elseif deltaStrength < 0 then	
		strengthString = strengthString.."[ICON_STAT_DECREASE]";
		if isShowingStats then strengthString = strengthString.."[COLOR:Red](-"..tostring(deltaStrength)..")[ENDCOLOR]"; end
	end
	strengthString = strengthString .. m_unit.Strength .. "[ICON_STRENGTH]";
	
	if deltaRangedStrength > 0 then
		rangedStrengthString = rangedStrengthString.."[ICON_STAT_INCREASE]";
		if isShowingStats then rangedStrengthString = rangedStrengthString.."[COLOR:Green](+"..tostring(deltaRangedStrength)..")[ENDCOLOR]"; end
	elseif deltaRangedStrength < 0 then	
		rangedStrengthString = rangedStrengthString.."[ICON_STAT_DECREASE]";
		if isShowingStats then rangedStrengthString = rangedStrengthString.."[COLOR:Red](-"..tostring(deltaRangedStrength)..")[ENDCOLOR]"; end
	end
	rangedStrengthString = rangedStrengthString .. m_unit.RangedStrength .. "[ICON_RANGE_STRENGTH]";

	--
	if deltaRange > 0 then
		rangeString = rangeString.."[ICON_STAT_INCREASE]";
		if isShowingStats then rangeString = rangeString.."[COLOR:Green](+"..tostring(deltaRange)..")[ENDCOLOR]"; end
	elseif deltaRange < 0 then	
		rangeString = rangeString.."[ICON_STAT_DECREASE]";
		if isShowingStats then rangeString = rangeString.."[COLOR:Red](-"..tostring(deltaRange)..")[ENDCOLOR]"; end
	end
	rangeString = rangeString .. m_unit.Range .. "[ICON_ATTACK_RANGE]";

	return movementString, strengthString, rangeString, rangedStrengthString;
end


-- ===========================================================================
function Reset()
	m_state						= State.SELECT_UNIT;
	m_player					= Players[Game.GetActivePlayer()];
	m_unit						= nil;
	m_selectedUpgrade			= nil;
	m_selectedPerk				= nil;

	-- Obtain all data for perk changes related to this player.
	for unitInfo : object in GameInfo.Units() do
		m_allUnitPerkStats[unitInfo.ID] = m_player:GetUpgradeStatsForUnit(unitInfo.ID);
	end
end


-- ===========================================================================
function IsMatchingFilter( filter:string, unit:table )
	local isMatching:boolean = true;
	if		filter == Filter.AIR	then isMatching = (unit.Domain == GameInfo.Domains[DomainTypes.DOMAIN_AIR].Type); 
	elseif	filter == Filter.AVAIL	then isMatching = (unit.HasPendingUpgrade);
	elseif	filter == Filter.NAVAL	then isMatching = (unit.Domain == GameInfo.Domains[DomainTypes.DOMAIN_SEA].Type); 
	elseif	filter == Filter.HOVER	then isMatching = (unit.Domain == GameInfo.Domains[DomainTypes.DOMAIN_HOVER].Type); 
	elseif	filter == Filter.RANGED	then isMatching = (unit.RangedStrength > 0) and (unit.Domain ~= GameInfo.Domains[DomainTypes.DOMAIN_SEA].Type); 
	elseif	filter == Filter.MELEE	then isMatching = (unit.RangedStrength <= 0) and (unit.Domain ~= GameInfo.Domains[DomainTypes.DOMAIN_SEA].Type); 
	end

	return isMatching;
end


-- ===========================================================================
function AddToSpecialAbilitiesBuffDescription( upgradeData:table )
		
	for _,perk in pairs(upgradeData.Perks) do
		if perk.HasPerk then
			local instance:table= m_AbilityBuffIM:GetInstance();
			instance.Text:SetText( GetHelpTextForUnitPerk(perk.ID) );

			-- Little bit of a trip to get the free perk.
			for _,perkStatEntry in ipairs( m_allUnitPerkStats[m_unit.ID] ) do
				if perkStatEntry.UpgradeType == upgradeData.ID and perkStatEntry.PerkType == perk.ID then
					local freeInstance:table= m_AbilityBuffIM:GetInstance();
					local freePerk :table = GameInfo.UnitPerks[perkStatEntry.FreePerkType];
					freeInstance.Text:SetText( GetHelpTextForUnitPerk(freePerk.ID) );					
				end
			end

		end
	end	
end


-- ===========================================================================			
--	Handles returning the UI results for the special case of a hybrid affinity
--	that has multiple upgrades on the same level; just using different amounts
--	of each affinity.
--	Forced a button's UI position to "round" towards which affinity is used
--	the most.
--
--	RETURNS:	table with results values or...
--				NIL if upgradeData has nothing to do the affinities 
-- ===========================================================================			
function GetForcedUpgradeButtonUI( upgradeData, AffinityString1, AffinityString2 )
	
	if upgradeData["FORCED_AFFINITY_FOR_ANGLES"] then

		if upgradeData[AffinityString1] < 1 or upgradeData[AffinityString2] < 1 then
			return nil;
		end

		local affinityAngle :string = AffinityString1;
		if upgradeData[AffinityString2] > upgradeData[AffinityString1] then
			affinityAngle = AffinityString2;
		elseif upgradeData[AffinityString1] == upgradeData[AffinityString2] then
			affinityAngle = AffinityString1 .. AffinityString2;
		end
		local angle		:number  = UpgradePositioning.Angle[affinityAngle];
		local text		:string  = tostring(upgradeData[AffinityString1]).. "[NEWLINE]" .. tostring(upgradeData[AffinityString2]);	
		local amt		:number  = m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_"..string.upper(AffinityString1)].ID);
		local isSmall	:boolean = amt < upgradeData[AffinityString1];
		if not isSmall then
			amt = m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_"..string.upper(AffinityString2)].ID);
			isSmall = amt < upgradeData[AffinityString2];
		end
		if not isSmall then
			text = "";
		end
		return {
			Angle	= angle,
			Text	= text,
			IsSmall	= isSmall,
		};
	end
	return nil;
end

-- ===========================================================================			
--	Obtain (potential) results for a UI button against two affinity
--	strings that are passed in.
--
--	RETURNS:	table with results values or...
--				NIL if upgradeData has nothing to do the affinities 
-- ===========================================================================			
function GetUpgradeButtonUI( upgradeData, AffinityString1, AffinityString2 )

	if upgradeData[AffinityString1] > 0 and (AffinityString2 == "" or upgradeData[AffinityString2] > 0 ) then					

		local angle		:number  = UpgradePositioning.Angle[AffinityString1..AffinityString2];
		local text		:string  = tostring(upgradeData[AffinityString1]);
		local amt		:number  = m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_"..string.upper(AffinityString1)].ID);
		local isSmall	:boolean = amt < upgradeData[AffinityString1];


		if AffinityString2 ~= "" then
			text = text .. "[NEWLINE]" .. tostring(upgradeData[AffinityString2]);
			if not isSmall then
				amt = m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_"..string.upper(AffinityString2)].ID);
				isSmall	= amt < upgradeData[AffinityString2];
			end
		end
		if not isSmall then
			text = "";
		end

		return {
			Angle	= angle,
			Text	= text,
			IsSmall	= isSmall,
		};
	end
	return nil;
end

-- ===========================================================================
-- Separate particles into two groups, foreground and background particles.
-- Put 2/3 of the particles in to the back and 1/3 into the front.
-- ===========================================================================
function PlayParticleEffect()
	
	m_ParticleFrontIM:ResetInstances();
	m_ParticleBackIM:ResetInstances();

	Controls.ParticleAreaFront:SetToBeginning();
	Controls.ParticleAreaFront:Play();
	Controls.ParticleAreaBack:SetToBeginning();	
	Controls.ParticleAreaBack:Play();
	
	Controls.ParticleAreaFront:SetHide( false );
	Controls.ParticleAreaBack:SetHide( false );	
	
	for i = 1, math.floor(MAX_PARTICLES * 0.34), 1 do
		local instance	:table	= m_ParticleFrontIM:GetInstance();
		
		local offsetX	:number = math.random() - 0.5;
		offsetX = math.sin(offsetX) * 550;
		offsetY = 250 * (math.abs(offsetX)/550);		-- push upward the further out from center
		instance.Content:SetBeginVal(offsetX,offsetY);
		instance.Content:SetEndVal(offsetX,400+offsetY);		
		
		local progress	:number = math.random();
		instance.Content:SetProgress( progress );
		instance.Alpha:SetProgress( progress );

		local size		:number = math.random(3,4);
		instance.Sparkle:SetSizeVal( size, size );
	end
	
	for i = 1, math.floor(MAX_PARTICLES * 0.67), 1 do
		local instance	:table	= m_ParticleBackIM:GetInstance();
		instance.Content:SetSpeed(0.7);
		instance.Alpha:SetSpeed(0.7);


		local offsetX	:number = math.random() - 0.5;
		offsetX = math.sin(offsetX) * 550;
		offsetY = 250 * (math.abs(offsetX)/550);		-- push upward the further out from center
		instance.Content:SetBeginVal(offsetX,offsetY);
		instance.Content:SetEndVal(offsetX,400+offsetY);		
		
		local progress	:number = math.random();
		instance.Content:SetProgress( progress );
		instance.Alpha:SetProgress( progress );

		local size		:number = math.random(2,3);
		instance.Sparkle:SetSizeVal( size, size );
	end
end

-- ===========================================================================
--	Have instance managers allocate particles; pooled internally for later reuse.
function PreAllocateParticles()
	for i = 1, math.floor(MAX_PARTICLES * 0.34), 1 do m_ParticleFrontIM:GetInstance(); end
	for i = 1, math.floor(MAX_PARTICLES * 0.67), 1 do m_ParticleBackIM:GetInstance(); end
end

-- ===========================================================================
function OnAcceptPerk()
	m_player:AssignUnitUpgrade( m_selectedPerk.UnitID, m_selectedPerk.UpgradeID, m_selectedPerk.ID);

	m_state			= State.VIEW_UNIT;
	Events.SerialEventUnitUpgradeScreenDirty();

	Controls.AcceptUpgradeButton:SetDisabled( true );
	Controls.IgnoreUpgradeButton:SetDisabled( true );

	Controls.PadImage:SetTexture(TEXTURE_STAND_ON);
	PlayParticleEffect();	
	Events.AudioPlay2DSound("AS2D_INTERFACE_UNIT_UPGRADE_CONFIRM");

	Close();	-- Upgrade applied
end
Controls.AcceptUpgradeButton:RegisterCallback(Mouse.ecLClick, OnAcceptPerk);

-- ===========================================================================
--	Mark that an upgrade has been seen and is explicitly being ignored.
-- ===========================================================================
function OnIgnorePerk()
	if m_currentUpgrade ~= nil then						
		-- Mark all upgrades on the same level as being ignored.
		for _,upgradeData in ipairs(m_unit.Upgrades[m_currentUpgrade.Level] ) do
			if upgradeData.IsPurchasable then
				m_player:IgnoreUnitUpgrade( upgradeData.ID );
			end
		end				
		Events.SerialEventUnitUpgradeScreenDirty();
	end
	Close();
end
Controls.IgnoreUpgradeButton:RegisterCallback(Mouse.ecLClick, OnIgnorePerk);

-- ===========================================================================
--	Tells game engine to take the selected perk.
--	Plays effects.
function SelectPerk( perk:table )
	m_selectedPerk	= perk;
	Controls.AcceptUpgradeButton:SetDisabled( false );
end

-- ===========================================================================
--	Determine all deltas combined from upgrades leading up to the selected
--	upgrade level.
--	Note: These stats already have come from the engine and include the 'free'
--	perks that occur for just upgrading a unit.
--
--	RETURNS:	A table containing the complete range of what the highest and 
--				lowest possible delta values that could have been selected.
function BuildPerkStatsFromBaseUnit( selectedUpgrade:table )

	local result		:table  = {};
	result.lowMovement	= 0;
	result.highMovement	= 0;
	result.lowStrength	= 0;
	result.highStrength	= 0;
	result.lowRanged	= 0;
	result.highRanged	= 0;
	result.isOwned		= true;	-- own all upgrades up to (and including) this upgrade?
	result.isCanBeOwned = true; -- own all upgrades up to, but NOT including, this one?

	local affinity:number = GetAffinityEnum( selectedUpgrade.Purity, selectedUpgrade.Harmony, selectedUpgrade.Supremacy );
	
	for _,levelUpgrades in pairs(m_unit.Upgrades) do 
		for _,upgrade in pairs(levelUpgrades) do 
		
			-- Some (level 1) upgrades don't require a specific affinity.
			local upgradeAffinity:number = GetAffinityEnum( upgrade.Purity, upgrade.Harmony, upgrade.Supremacy );
			if (upgradeAffinity == affinity or upgradeAffinity == 0) and upgrade.Level <= selectedUpgrade.Level then						
			
				local movementLowest	:number = 0;
				local strengthLowest	:number = 0;
				local rangedLowest		:number = 0;
				local movementHighest	:number = 0;
				local strengthHighest	:number = 0;
				local rangedHighest		:number = 0;
			
				for _,perk in pairs(upgrade.Perks) do								
					if perk.HasPerk then
						-- Overwrite any previous values, this IS the perk selected.
						movementLowest = perk.Movement;
						movementHighest= perk.Movement;
						strengthLowest = perk.Strength;
						strengthHighest= perk.Strength;
						rangedLowest   = perk.RangedStrength;
						rangedHighest  = perk.RangedStrength;
						break;	-- you can go now...we're done here
					else
						-- Adjust lowest values
						movementLowest	= (movementLowest~=0)	and math.min(movementLowest, perk.Movement) or movementLowest;
						strengthLowest	= (strengthLowest~=0)	and math.min(strengthLowest, perk.Strength) or strengthLowest;
						rangedLowest	= (rangedLowest~=0)		and math.min(rangedLowest, perk.RangedStrength) or rangedLowest;

						-- Adjust highest values
						movementHighest	= math.max(movementHighest, perk.Movement);
						strengthHighest	= math.max(strengthHighest, perk.Strength);
						rangedHighest	= math.max(rangedHighest, perk.RangedStrength);
					end
				end

				-- Trickery: Will always be set to one level below the currently inspected level,
				-- so everything so far is considered owned (until it is checked that it isn't).
				result.isCanBeOwned = result.isOwned;

				if not upgrade.HasUpgrade then
					result.isOwned = false;
				end

				-- Add to the previous upgrade deltas that have been found.
				result.lowMovement	= result.lowMovement + movementLowest;
				result.lowStrength	= result.lowStrength + strengthLowest;
				result.lowRanged	= result.lowRanged   + rangedLowest;

				result.highMovement	= result.highMovement + movementHighest;
				result.highStrength	= result.highStrength + strengthHighest;
				result.highRanged	= result.highRanged   + rangedHighest;
			end
		end
	end

	return result;

end


-- ===========================================================================
--	When viewing a unit, displays upgrade/perks information
--
function UpdateCurrentUpgrade()

	local choosenPerkID				:number = -1;
	local upgradeID					:number = -1;
	local deltaMovement				:number = 0;
	local deltaStrength				:number = 0;
	local viewingRange				:number = 0;
	local deltaRangedStrength		:number = 0;
	local isHasSpecificStatDetails	:boolean = false;	-- "Arrows" or full blown stat deltas?
	local rangeString				:string = "";
	local movementString			:string = "";
	local strengthString			:string = "";
	local rangeString				:string = "";
	local rangedStrengthString		:string = "";


	m_perkIM:ResetInstances();

	if m_selectedUpgrade ~= nil then

		upgradeID = m_selectedUpgrade.ID;			

		-- Obtain stats, if all highs match lows, then specific stat deltas can be displayed
		local perkDeltaStats:table = BuildPerkStatsFromBaseUnit( m_selectedUpgrade );		
		if		(perkDeltaStats.lowMovement	== perkDeltaStats.highMovement) 
			and (perkDeltaStats.lowStrength	== perkDeltaStats.highStrength)
			and (perkDeltaStats.lowRanged	== perkDeltaStats.highRanged) then
			isHasSpecificStatDetails = true;
		end

		Controls.AffinityIcon:SetHide( false );		

		local affinityIconIndex :number  = GetAffinityIconIndex( m_selectedUpgrade.Purity, m_selectedUpgrade.Harmony, m_selectedUpgrade.Supremacy, IconModifier.COLOR );		
		IconHookup( affinityIconIndex, 40, "AFFINITY_ATLAS_UNIT_UPGRADE", Controls.AffinityIcon );
		Controls.AffinityName:SetText( Locale.Lookup(m_selectedUpgrade.Description) );
	
		-- Any of the perks already selected?		
		if m_selectedUpgrade.HasUpgrade then
			for _,perk in ipairs(m_selectedUpgrade.Perks) do
				if perk.HasPerk then
					choosenPerkID = perk.ID;
					break;
				end
			end
		end

		Controls.UpgradeAndPerkHeader:SetHide( false );

		if choosenPerkID ~= -1 then
			Controls.UpgradeAndPerkHeader:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_PERK_CHOOSEN") .. ":");
			Controls.PurchaseCostArea:SetHide( true );
			--Controls.AcceptUpgradeButton:SetDisabled( false );
		else
			Controls.AcceptUpgradeButton:SetDisabled( true );
			if m_selectedUpgrade.IsPurchasable then
				Controls.UpgradeAndPerkHeader:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_CHOOSE_A_PERK") .. ":");
				Controls.PurchaseCostArea:SetHide( true );
			else
				Controls.UpgradeAndPerkHeader:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_ENABLES") .. ":");
			
				local numTypes		:number = 0;
				local requiredText	:string = "";
				local purityAmt		:number = m_player:GetAffinityLevel(PURITY_AFFINITY_TYPE);
				local harmonyAmt	:number = m_player:GetAffinityLevel(HARMONY_AFFINITY_TYPE);
				local supremacyAmt	:number = m_player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE);
				local anyAmt		:number = (purityAmt + harmonyAmt + supremacyAmt);
			
				if m_selectedUpgrade.Purity > purityAmt			then numTypes = numTypes + 1; requiredText = "[ICON_PURITY][Color:Purity]" .. tostring(m_selectedUpgrade.Purity) .. "[ENDCOLOR]  "; end
				if m_selectedUpgrade.Harmony > harmonyAmt		then numTypes = numTypes + 1; requiredText = requiredText .. "[ICON_HARMONY][Color:Harmony]" .. tostring(m_selectedUpgrade.Harmony) .. "[ENDCOLOR]  "; end
				if m_selectedUpgrade.Supremacy > supremacyAmt	then numTypes = numTypes + 1; requiredText = requiredText .. "[ICON_SUPREMACY][Color:Supremacy]" .. tostring(m_selectedUpgrade.Supremacy) .. "[ENDCOLOR]  "; end
				if m_selectedUpgrade.Any > anyAmt				then numTypes = numTypes + 2; requiredText = requiredText .. Locale.Lookup("TXT_KEY_UNIT_UPGRADE_AFFINITY_ANY", m_selectedUpgrade.Any); end	-- 2 on purpose, can be more than 1 type of affinity

				Controls.PurchaseCostArea:SetHide( numTypes == 0 );				
				if numTypes == 1 then
					Controls.PurchaseCostLabel:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_AFFINITY_LEVEL_REQUIRED" ));				
				else
					Controls.PurchaseCostLabel:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_AFFINITY_LEVELS_REQUIRED" ));
				end
				Controls.PurchaseCostText:SetText( requiredText );
			end
		end			
		Controls.AcceptUpgradeButton:SetHide( not m_selectedUpgrade.IsPurchasable );
		Controls.AcceptUpgradeButton:SetDisabled( m_selectedPerk == nil );
		Controls.IgnoreUpgradeButton:SetHide( not m_selectedUpgrade.IsPurchasable );
		Controls.IgnoreUpgradeButton:SetDisabled( m_state == State.VIEW_UNIT );

		-- Perks for the given upgrade!
		local lastInstance	:table = nil;
		for _,perk in ipairs(m_selectedUpgrade.Perks) do

			-- If a perk is selected, only show that perk.
			if choosenPerkID == -1 or (choosenPerkID ~= -1 and choosenPerkID == perk.ID ) then
				local instance	:table = m_perkIM:GetInstance();
				local text		:string = GetHelpTextForUnitPerk(perk.ID);
				
				-- Little bit of a trip to get the free perk; including tracking potential dupes:
				local perksUsed:table = {};
				for _,perkStatEntry in ipairs( m_allUnitPerkStats[m_unit.ID] ) do					
					if perkStatEntry.UpgradeType == m_selectedUpgrade.ID and perkStatEntry.PerkType == perk.ID then
						local isUsedPerk:boolean = false;
						for _,usedPerkID in pairs(perksUsed) do
							if perk.ID == usedPerkID then
								isUsedPerk = true;
								break;
							end
						end
						if not isUsedPerk then
							local freePerk :table = GameInfo.UnitPerks[perkStatEntry.FreePerkType];
							table.insert(perksUsed, perk.ID);
							text = text .. "[NEWLINE]" .. GetHelpTextForUnitPerk(freePerk.ID);
						end						
					end
				end

				local perkBoxHeight = m_height - 636;					-- Magic # of height; perfect fit for scrolling perk boxes.
				instance.DescriptionBox:SetSizeY( perkBoxHeight );
				instance.DescriptionScroll:SetSizeY( perkBoxHeight );
				instance.Description:SetText( text );									
				instance.DescriptionScroll:CalculateInternalSize();
				instance.DescriptionScroll:ReprocessAnchoring();
				IconHookup(perk.PortraitIndex, perk.IconSize, perk.IconAtlas, instance.Icon);
				instance.ClickBlocker:SetHide( m_selectedUpgrade.IsPurchasable );
				instance.Stack:CalculateSize();
				instance.Content:SetSize( instance.Stack:GetSize() );
				instance.Selected:SetSize( instance.Stack:GetSize() );
				instance.Selected:SetHide( m_selectedPerk == nil or m_selectedPerk.ID ~= perk.ID )
				if m_selectedUpgrade.IsPurchasable then
					instance.Content:RegisterCallback(Mouse.ecLClick, 
						function() 
							SelectPerk( perk );
							UpdateCurrentUpgrade();	-- Refresh stats							
						end 
					);
				else			
					instance.Content:ClearCallback(Mouse.eLClick);
				end

				local isLocked :boolean  = (choosenPerkID ~= nil) and (choosenPerkID ~= perk.ID);
				instance.Icon:SetColor( isLocked and UpgradeColors.LOCKED or 0xffffffff  );		
				instance.Description:SetColor( isLocked and UpgradeColors.LOCKED or UpgradeColors.NORMAL );

				lastInstance = instance;
			end
		end
		
		-- Determine stat deltas to show in preview window
		local movementDelta : number = 0;
		local strengthDelta : number = 0;
		local rangeDelta : number = 0;
		local rangedStrengthDelta : number = 0;
		viewingRange = m_unit.Range;
		if m_selectedPerk ~= nil then
			movementDelta = m_selectedPerk.Movement;
			strengthDelta = m_selectedPerk.Strength;
			rangeDelta = m_selectedPerk.Range;
			rangedStrengthDelta = m_selectedPerk.RangedStrength;
			isHasSpecificStatDetails = true;
		--else
			--movementDelta = (m_unit.BaseMovement + perkDeltaStats.highMovement) -  m_unit.Movement;
			--strengthDelta = (m_unit.BaseStrength + perkDeltaStats.highStrength) -  m_unit.Strength;
			--rangedStrengthDelta = (m_unit.BaseRangedStrength +  perkDeltaStats.highRanged) -  m_unit.RangedStrength;
			viewingRange = viewingRange + rangeDelta;
		end

		movementString, strengthString, rangeString, rangedStrengthString =  GetStatsIconStrings( 
			m_unit.BaseMovement + perkDeltaStats.highMovement, 
			m_unit.BaseStrength + perkDeltaStats.highStrength, 
			m_unit.BaseRangedStrength +  perkDeltaStats.highRanged,
			m_unit.Range,
			movementDelta,
			strengthDelta,
			rangeDelta,
			rangedStrengthDelta,
			isHasSpecificStatDetails );

	else
		-- No upgrades/perks selected.
		Controls.PurchaseCostArea:SetHide( true );
		Controls.AffinityIcon:SetHide( true );		
		Controls.AcceptUpgradeButton:SetHide( true );
		Controls.IgnoreUpgradeButton:SetHide( true );
		Controls.AffinityName:SetText( Locale.Lookup(m_unit.Description) );
		Controls.UpgradeAndPerkHeader:SetHide( true );
		
		-- Grab strings
		viewingRange = m_unit.Range;
		movementString, strengthString, rangeString, rangedStrengthString =  GetStatsIconStrings( m_unit.Movement, m_unit.Strength, m_unit.Range, m_unit.RangedStrength, 0, 0, 0, 0, false );		
	end

	UI:UpdateUnitUpgradePreview(m_unit.ID, upgradeID, choosenPerkID);	

	Controls.PerkStack:CalculateSize();

	Controls.Movement:SetText( movementString );
	Controls.Movement:SetToolTipString( m_unit.MovementTip );

	Controls.Strength:SetText( strengthString );
	Controls.Strength:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_UPANEL_STRENGTH_TT") );

	Controls.Range:SetHide( viewingRange == 0 );
	Controls.Range:SetText( rangeString );
	Controls.Range:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_UPANEL_ATTACK_RANGE_TT", viewingRange));
	
	
	Controls.RangedStrength:SetHide( m_unit.RangedStrength == 0 );
	Controls.RangedStrength:SetText( rangedStrengthString );
	Controls.RangedStrength:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_UPANEL_RANGED_ATTACK_TT") );

	Controls.StatStack:CalculateSize();
	Controls.StatStack:ReprocessAnchoring();
end


-- ===========================================================================
function View_UnitUpgrade( unit:table )	

	-- HACK: Gamecore returning a unit having upgrades at tier 3 after applying perk; force it into view mode.
	if unit.NextLevel == 0 then
		m_state = State.VIEW_UNIT;
	end

	if m_state == State.UPGRADE_UNIT then
		Controls.HeaderText:SetText( Locale.Lookup("{TXT_KEY_UNIT_UPGRADE_UPGRADING:upper}") .. " " .. Locale.ToUpper(Locale.Lookup(unit.Name)) );				
		local bigRomanTexture:string = "UnitUpgradeLevel" .. tostring( unit.NextLevel ) .. ".dds";
		Controls.BigRomanNumber:SetTexture( bigRomanTexture );
		if unit.NextLevel == 1 then Controls.BigRomanNumber:SetSizeX(25); end	-- Each texture diffent width, fix it up
		if unit.NextLevel == 2 then Controls.BigRomanNumber:SetSizeX(44); end
		if unit.NextLevel == 3 then Controls.BigRomanNumber:SetSizeX(66); end
		Controls.ChooseRing1:SetHide(	not (unit.NextLevel == 1));
		Controls.ChooseRing2:SetHide(	not (unit.NextLevel == 2));

		-- Set the "current" so if it's not taken, it can be set to be ignored.
		for _,upgrade in pairs(m_unit.Upgrades[unit.NextLevel]) do
			if upgrade.IsPurchasable then				
				if not m_player:IsUnitUpgradeIgnored(upgrade.ID) then
					m_currentUpgrade = upgrade;
					break;
				end
			end
		end

	else
		Controls.HeaderText:SetText( Locale.Lookup("{TXT_KEY_UNIT_UPGRADE_VIEWING:upper}") .. " " .. Locale.ToUpper(Locale.Lookup(unit.Name)) );
		Controls.ChooseRing1:SetHide(true);
		Controls.ChooseRing2:SetHide(true);
	end
	
	Controls.LevelUpHeaderGrid:SetHide(	not (m_state == State.UPGRADE_UNIT));
	Controls.BigRomanNumber:SetHide(	not (m_state == State.UPGRADE_UNIT));
	Controls.NewUpgradeArrow:SetHide(	not (m_state == State.UPGRADE_UNIT));
	--Controls.UpgradeInfoHeader:SetHide(	not (m_state == State.UPGRADE_UNIT));

	-- Upper right message
	if unit.NextLevel > 0 and m_state == State.UPGRADE_UNIT then
		Controls.UpgradeInfoHeader:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_NEW_UPGRADE_SUMMARY", unit.Name, ROMAN_NUMBERS[unit.NextLevel] ));
		Controls.UpgradeInfoHeader:SetColorByName("UpgradeGoldenSet");
	else
		Controls.UpgradeInfoHeader:SetText( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_BASE_UNIT") );
		Controls.UpgradeInfoHeader:SetColorByName("UpgradeNormalSet");
	end

	m_upgradeIM:ResetInstances();
	m_AbilityBuffIM:ResetInstances();

	Controls.AbilitiesBG:SetHide( m_unit.CurrentUpgrade == nil );

	local additionalRadiusDistance :number = 0;	-- Used when there are multiple items at a level 1 upgrade

	for iLevel,upgradeInstances in ipairs(unit.Upgrades) do
	
		local iActiveLevelUpgrade	:number = m_player:GetAssignedUpgradeAtLevel(unit.ID, iLevel);
		local numUpgrades			:number = table.count( upgradeInstances );

		-- Base sizing on if there is x3 upgrades for a level 1 upgrade.
		if iLevel == 1 then

			-- Candidate to be moved to early data processing:
			if numUpgrades > 1 then
				additionalRadiusDistance = UpgradePositioning.Distance["Additional"];

				-- Hybrid affinities may have multiple combinations of 2 affinities for upgrades (at level 1)
				-- First scan if this is such a case...
				local isMultipleHybridAffinityUpgrades:boolean = false;
				local HP:number = 0;
				local PS:number = 0;
				local SH:number = 0;
				for _,upgradeData in ipairs(upgradeInstances) do
					if upgradeData.Harmony > 0 and upgradeData.Purity > 0 then HP = HP + 1;
					elseif upgradeData.Purity > 0 and upgradeData.Supremacy > 0 then PS = PS + 1;
					elseif upgradeData.Supremacy > 0 and upgradeData.Harmony > 0 then SH = SH + 1; 
					end
					if HP > 1 or PS > 1 or SH > 1 then
						isMultipleHybridAffinityUpgrades = true;
						break;
					end
				end
				-- If more than one pair of the same hyrbid affinities was found, set forced values
				if isMultipleHybridAffinityUpgrades then
					for _,upgradeData in ipairs(upgradeInstances) do
						upgradeData["FORCED_AFFINITY_FOR_ANGLES"] = true;
					end
				end
			end
		end

		for i,upgradeData in pairs(upgradeInstances) do

			local isSmallIcons	:boolean= true;
			local distance		:number = UpgradePositioning.Distance[iLevel] + additionalRadiusDistance;
			local angle			:number	= 0;
			local text			:string = "";
			local results		:table	= nil;

			if results == nil then	results = GetForcedUpgradeButtonUI(upgradeData, "Purity",	"Harmony"); end
			if results == nil then	results = GetForcedUpgradeButtonUI(upgradeData, "Purity",	"Supremacy"); end
			if results == nil then	results = GetForcedUpgradeButtonUI(upgradeData, "Harmony",	"Supremacy"); end
			if results == nil then	results = GetUpgradeButtonUI(upgradeData, "Purity",	 "Harmony"); end
			if results == nil then	results = GetUpgradeButtonUI(upgradeData, "Purity",	 "Supremacy"); end
			if results == nil then	results = GetUpgradeButtonUI(upgradeData, "Harmony", "Supremacy"); end
			if results == nil then	results = GetUpgradeButtonUI(upgradeData, "Harmony",	""); end
			if results == nil then	results = GetUpgradeButtonUI(upgradeData, "Purity",		""); end
			if results == nil then	results = GetUpgradeButtonUI(upgradeData, "Supremacy",	""); end
			if results ~= nil then
				angle		= results.Angle;
				text		= results.Text;
				isSmallIcons= results.IsSmall;
			else				
				isSmallIcons= upgradeData.Any > (
					m_player:GetAffinityLevel(PURITY_AFFINITY_TYPE) +
					m_player:GetAffinityLevel(HARMONY_AFFINITY_TYPE) +
					m_player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE));
				if isSmallIcons then
					text = tostring(upgradeData.Any);
				end
			end			

			local x,y = PolarToCartesian( distance, angle-90 );
			
			local instance :table = m_upgradeIM:GetInstance();
			instance.Button:SetOffsetVal( x, y );	
			instance.Info:SetText( text );

			local iconModifier	:number = isSmallIcons and IconModifier.SMALL or IconModifier.NONE;			
			local iconIndex		:number	= GetAffinityIconIndex( upgradeData.Purity, upgradeData.Harmony, upgradeData.Supremacy, iconModifier );
			--print("iconIndex: ", iconIndex, upgradeData.Purity, upgradeData.Harmony, upgradeData.Supremacy);

			IconHookup( iconIndex, 40, "AFFINITY_ATLAS_UNIT_UPGRADE", instance.Icon );
			IconHookup( iconIndex, 40, "AFFINITY_ATLAS_UNIT_UPGRADE", instance.HighlightIcon );
		

			local isAnotherUpgradeOnThisLevelSelected	:boolean = (iActiveLevelUpgrade ~= -1 and iActiveLevelUpgrade ~= upgradeData.ID);

			if upgradeData.IsPurchasable and m_state == State.UPGRADE_UNIT then
				instance.Button:SetTexture(TEXTURE_UPGRADE_PURCHASE);				
				instance.Icon:SetColor( 0xffffffff );
				instance.Info:SetColor( 0xffffffff );
				instance.HighlightIcon:SetColor( UpgradeColors.NORMAL );
			elseif upgradeData.HasUpgrade then
				instance.Button:SetTexture(TEXTURE_UPGRADE_CHOSEN);				
				instance.Icon:SetColor( 0xffffffff );
				instance.Info:SetColor( 0xffffffff );
				instance.HighlightIcon:SetColor( UpgradeColors.GRAY );
				AddToSpecialAbilitiesBuffDescription( upgradeData );
			else
				instance.Button:SetTexture(TEXTURE_UPGRADE_DISABLED);
				instance.Icon:SetColor( UpgradeColors.GRAY );
				instance.Info:SetColor( UpgradeColors.GRAY );
				instance.HighlightIcon:SetColor( UpgradeColors.GRAY );
			end

			instance.Button:RegisterCallback(Mouse.eLClick, 
				function() 
					Controls.PadImage:SetTexture(TEXTURE_STAND_OFF);
					m_selectedPerk = nil;
					m_selectedUpgrade = upgradeData;
					UpdateCurrentUpgrade(); 
				end );
		end	-- upgrades on a current level
	end -- levels of upgrades

	Controls.AbilitiesStack:CalculateSize();
	Controls.AbilitiesScroll:CalculateInternalSize();

	-- No upgrade selected; find the highest one the unit currently has.
	if m_selectedUpgrade == nil then
		local highestLevel:number = 0;
		for _,levelUpgrades in pairs(m_unit.Upgrades) do 
			for _,upgrade in pairs(levelUpgrades) do 
				if upgrade.HasUpgrade then
					if upgrade.Level > highestLevel then
						highestLevel = upgrade.Level;
						m_selectedUpgrade = upgrade;
					end
				end
			end
		end
	end

	UpdateCurrentUpgrade();
end


-- ===========================================================================
--	Pick a unit from a grid view.
--	units	A table of units (data only)
--
function View_GridOfUnits( units:table )
	
	m_cardIM:ResetInstances();
	Reset();

	Controls.HeaderText:SetText( Locale.Lookup("{TXT_KEY_UNIT_UPGRADE_SELECT_UNIT_TITLE:upper}"));

	for _,unit in pairs(units) do

		local isShowing :boolean = IsMatchingFilter( m_filter, unit );

		if isShowing then
			local instance = m_cardIM:GetInstance();
		
			instance.UnitName:SetText( DEBUG_SHOW_IDS and (tostring(unit.ID).." "..Locale.ToUpper(Locale.Lookup(unit.Name)) ) or Locale.ToUpper(Locale.Lookup(unit.Name)));
			instance.Movement:SetText( unit.Movement .. "[ICON_MOVES]" );
			instance.Movement:SetToolTipString( unit.MovementTip );
			instance.Strength:SetText( unit.Strength .. "[ICON_STRENGTH]" );
			instance.Strength:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_UPANEL_STRENGTH_TT") );
			instance.RangedStrength:SetText( unit.RangedStrength .. "[ICON_RANGE_STRENGTH]" );
			instance.RangedStrength:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_UPANEL_RANGED_ATTACK_TT") );
			instance.RangedStrength:SetHide( unit.RangedStrength <= 0 );
			instance.Range:SetText( unit.Range .. "[ICON_ATTACK_RANGE]" );
			instance.Range:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_UPANEL_ATTACK_RANGE_TT", unit.Range));
			instance.Range:SetHide( unit.Range <= 0 );
			instance.Slot1:SetHide( unit.NumLevels < 1 );
			instance.Slot2:SetHide( unit.NumLevels < 2 );
			instance.Slot3:SetHide( unit.NumLevels < 3 );

			if unit.IsViewable then
				instance.ReqTech:SetHide( true );
				instance.UnitName:SetColor( 0xffccb3a2, 0 );
				instance.UnitName:SetColor( 0x80ccb3a2, 1 );
				instance.Content:SetTexture("UnitUpgradeUnitButton.dds");
				instance.Content:RegisterCallback(Mouse.eLClick, 
					function() 
						m_state				= unit.HasPendingUpgrade and State.UPGRADE_UNIT or State.VIEW_UNIT;
						m_unit				= unit;
						m_selectedUpgrade	= nil;
						m_selectedPerk		= nil;
						Refresh();
					end);
			else
				instance.UnitName:SetColor( 0xff665050, 0 );
				instance.UnitName:SetColor( 0x30665050, 1 );
				instance.Content:SetTexture("UnitUpgradeUnitLockedButton.dds");
				instance.ReqTech:SetHide( unit.RequiredTech == nil );				
				if unit.RequiredTech ~= nil then

					local tech:table = GameInfo.Technologies[unit.RequiredTech];
					IconHookup(tech.PortraitIndex, 64, tech.IconAtlas, instance.TechIcon);
					IconHookup(tech.PortraitIndex, 64, tech.IconAtlas, instance.TechIconHighlight);
					instance.TechIcon:SetToolTipString( Locale.Lookup("TXT_KEY_UNIT_UPGRADE_RESEARCH_UNIT_TT", tech.Description) );
					instance.Content:RegisterCallback(Mouse.eLClick,
						function()
							Close();
							local techID = tech.ID;
							Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, Data2 = techID } );	-- Call tech web to go to tech
						end);
				end
			end

			-- Connect to Civilopedia
			instance.Content:RegisterCallback(Mouse.eRClick,
				function()					
					local searchString = unit.Name;
					Events.SearchForPediaEntry( searchString );
				end);

			--if unit.ID == 9 then
				--print("DEBUGGING target unit");	-- 5=solider, 6=ranger, 9=gun boat, 47=patrol boat
			--end
	
			local perkTypes			: table = m_player:GetPerksForUnit(unit.ID);
			local nextUpgradeLevel	: number = unit.HasPendingUpgrade and unit.NextLevel or (unit.NextLevel - 1);

			local portraitIndex :number = -1;
			local portraitAtlas	:string;

			-- Portrait system is based off of upgrades, base units arent' included; add them here (kluge):
			if unit.CurrentUpgrade == nil then
				if     ( unit.Type == "UNIT_MARINE" )			then portraitIndex = 3;  portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_AIR_FIGHTER" )		then portraitIndex = 51; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_CAVALRY" )			then portraitIndex = 43; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_NAVAL_CARRIER" )	then portraitIndex = 28; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_NAVAL_FIGHTER" )	then portraitIndex = 19; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_RANGED_MARINE" )	then portraitIndex = 11; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_SIEGE" )			then portraitIndex = 35; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_CNDR" )				then portraitIndex = 63; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_CARVR" )			then portraitIndex = 64; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_SABR" )				then portraitIndex = 65; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_ANGEL" )			then portraitIndex = 66; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_BATTLESUIT" )		then portraitIndex = 67; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_AEGIS" )			then portraitIndex = 68; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_LEV_TANK" )			then portraitIndex = 69; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_LEV_DESTROYER" )	then portraitIndex = 70; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_XENO_SWARM" )		then portraitIndex = 71; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_XENO_CAVALRY" )		then portraitIndex = 72; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_XENO_TITAN" )		then portraitIndex = 96; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_ROCKTOPUS" )		then portraitIndex = 95; portraitAtlas = "UNIT_UPGRADE_ATLAS_1";
				elseif ( unit.Type == "UNIT_NAVAL_MELEE" )		then portraitIndex = 32; portraitAtlas = "UNIT_UPGRADE_ATLAS_XP1";
				elseif ( unit.Type == "UNIT_SUBMARINE" )		then portraitIndex = 24; portraitAtlas = "UNIT_UPGRADE_ATLAS_XP1";
				else
					portraitIndex = unit.DefaultPortraitIndex;
					portraitAtlas = unit.DefaultPortraitAtlas;
				end
			else
				portraitIndex = unit.CurrentUpgrade.PortraitIndex;
				portraitAtlas = unit.CurrentUpgrade.PortraitAtlas;
			end

			IconHookup(portraitIndex, 128, portraitAtlas, instance.Portrait);
			instance.Portrait:SetColor( unit.IsViewable and 0xffffffff or 0xcc222222 );

			local arrowAdded: boolean = false;

			-- Loop from 3 to 1 so upgrade arrow can be put on latest
			for perkIndex : number = MAX_UPGRADE_LEVELS, 1, -1 do
			
				-- Set roman numerals and background image
				local perkType : number = (perkTypes ~= nil) and perkTypes[perkIndex] or -1;
				local perkSlot : table  = instance["Slot"..tostring(perkIndex)];
				local perkButton : table = instance["PerkButton"..tostring(perkIndex)];
				local perkIcon : table	= instance["PerkIcon"..tostring(perkIndex)];
				local perkAnim : table  = instance["Alpha"..tostring(perkIndex)];
				local perkNum  : table  = instance["Num"..tostring(perkIndex)];

				local isNextUpgradeTier :boolean = (perkIndex == nextUpgradeLevel);
				if ( perkIndex < nextUpgradeLevel ) then
					perkSlot:SetTexture( TEXTURE_SLOT );
				elseif perkIndex == nextUpgradeLevel then
					perkSlot:SetTexture( TEXTURE_SLOT_CURRENT );
				else
					perkSlot:SetTexture( TEXTURE_SLOT_FUTURE );
				end
				SetRomanNumeralTexture( perkNum, perkIndex, isNextUpgradeTier, unit.HasPendingUpgrade );
				perkNum:SetHide( perkIndex > nextUpgradeLevel and nextUpgradeLevel ~= -1 );	

				if (perkIndex <= table.count(perkTypes) ) then				
					perkSlot:SetColor( 0xffffffff );
					perkNum:SetColor( 0xffffffff );
					perkIcon:SetHide( false );									
					perkIcon:SetOffsetY(0);
					perkIcon:SetSizeVal(56,56);
					local perkInfo : table = GameInfo.UnitPerks[perkType];
					IconHookup(perkInfo.PortraitIndex, 56, perkInfo.IconAtlas, perkIcon );
					if (perkButton ~= nil) then
						perkButton:SetToolTipString(GetHelpTextForUnitPerk(perkType));
					end
					perkAnim:Stop();
					perkAnim:SetToEnd();
				else
					if isNextUpgradeTier and unit.HasPendingUpgrade and not unit.IsIgnored and not arrowAdded then
						perkSlot:SetColor( 0xff66ccff );
						perkIcon:SetHide( false );
						perkIcon:SetSizeVal(40,40);
						perkIcon:SetOffsetY(-2);
						perkIcon:SetTexture("NewUpgrade40.dds");				
						perkAnim:SetToBeginning();
						perkAnim:Play();
						arrowAdded = true;
					else
						perkSlot:SetColor( 0xffffffff );
						perkNum:SetColor( 0xffffffff );
						perkIcon:SetHide( true );			
					end
				end
			end -- perks
		end -- is showing
	end	-- looping all units

	-- Update badges (if any)
	for _,filter in pairs(Filter) do
		local amt:number = m_tabs["Filter"..filter.."BadgeCount"];
		SetBadge( filter, amt);
	end	

	Controls.CardScroll:SetSizeY( m_height - (HEIGHT_TOP_BANNER + HEIGHT_TABS_BANNER ) );
	Controls.CardStack:CalculateSize();
	Controls.CardScroll:CalculateInternalSize();
	Controls.BackBlackOutter:SetSizeY( m_height - 75 );
end


-- ===========================================================================
function Refresh()

	Controls.UnitUpgradeBG:SetHide(		m_state == State.SELECT_UNIT );
	Controls.UnitSelectBG:SetHide(		m_state == State.UPGRADE_UNIT or m_state == State.VIEW_UNIT );
	Controls.CloseButton:SetHide(		m_state == State.UPGRADE_UNIT or m_state == State.VIEW_UNIT);
	Controls.UpgradeCloseButton:SetHide(m_state == State.SELECT_UNIT );		

	if m_state == State.UPGRADE_UNIT or m_state == State.VIEW_UNIT then		
		View_UnitUpgrade( m_unit );
	elseif m_state == State.SELECT_UNIT then
		m_allUnits = UpdateUnitList();
		View_GridOfUnits( m_allUnits );
	end
end


-- ===========================================================================
--	Callback from engine when data is refreshed (e.g., perk/upgrade applied.)
--	TODO: Engine is calling this twice on perk upgrades! Stop this.
-- ===========================================================================
function OnRefreshData()

	-- Currently editing/viewing a unit?
	if m_unit ~= nil then
		-- Unit may have just been updated in engine; get latest info...
		local id:number = m_unit.ID;
		for unitInfo : object in GameInfo.Units() do
			if unitInfo.ID == id then
				m_unit = UpdateSingleUnit( unitInfo );
				
				-- Upgrade status (e.g., is purchasable) likely changed.
				if m_selectedUpgrade ~= nil then
					local earlyBreak :boolean = false;
					for _,upgradeLevels in pairs(m_unit.Upgrades) do
						for _,upgrade in pairs(upgradeLevels) do
							if upgrade.ID == m_selectedUpgrade.ID then
								m_selectedUpgrade = upgrade;
								earlyBreak = true;
								break;
							end
						end
						if earlyBreak then
							break;
						end
					end
				end

				if m_unit.HasPendingUpgrade then
					m_state	= State.UPGRADE_UNIT;
				end
				break;
			end
		end
	end

	Refresh();
end


-- ===========================================================================
--	Returns the movement, ranged movement, and strength based on the 
--	unit's current applied perks.
-- ===========================================================================
function GetPerkStats( unitInfo:table )
	
	local movement		: number = 0;
	local strength		: number = 0;
	local range			: number = 0;
	local rangedStrength: number = 0;
	local movementTip	: string;

	if DomainTypes[unitInfo.Domain] == DomainTypes.DOMAIN_AIR then
		range				= m_player:GetBaseRangeWithPerks(unitInfo.ID);
		local rebaseRange	= range * GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER;
		rebaseRange			= rebaseRange / 100;
		movementTip			= Locale.ConvertTextKey("TXT_KEY_UPANEL_UNIT_MAY_STRIKE_REBASE", range, rebaseRange);
		strength			= m_player:GetBaseRangedCombatStrengthWithPerks(unitInfo.ID);
		movement			= rebaseRange; -- Treat Rebase Range as the movement space for air units
	else
		movement			= m_player:GetBaseMovesWithPerks(unitInfo.ID);
		if DomainTypes[unitInfo.Domain] == DomainTypes.DOMAIN_SEA then
			movement = movement + m_player:GetNavalMovementChangeFromPlayerPerks();
		end
		movementTip			= Locale.ConvertTextKey("TXT_KEY_UPANEL_UNIT_MAY_MOVE", movement);				
		strength			= m_player:GetBaseCombatStrengthWithPerks(unitInfo.ID);
	end	

	if(unitInfo.RangedCombat > 0 and unitInfo.Domain ~= DomainTypes.DOMAIN_AIR) then
		rangedStrength = m_player:GetBaseRangedCombatStrengthWithPerks(unitInfo.ID);
		range = m_player:GetBaseRangeWithPerks(unitInfo.ID);
	end

	return movement, strength, range, rangedStrength, movementTip;
end


-- ===========================================================================
--	Updates all of the upgrade/perk information for a single unit.
-- ===========================================================================
function UpdateSingleUnit( unitInfo:table )

	local movement		: number = 0;
	local movementTip	: string;
	local strength		: number = 0;
	local range			: number = 0;
	local rangedStrength: number = 0;
	local purityAmt		: number = m_player:GetAffinityLevel(PURITY_AFFINITY_TYPE);
	local harmonyAmt	: number = m_player:GetAffinityLevel(HARMONY_AFFINITY_TYPE);
	local supremacyAmt	: number = m_player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE);
	local anyAmt		: number = (purityAmt + harmonyAmt + supremacyAmt);

	movement, strength, range, rangedStrength, movementTip = GetPerkStats( unitInfo );

	local hasPendingUpgrade		:boolean = m_player:DoesUnitHavePendingUpgrades(unitInfo.ID, -1, true);	-- For all levels, including prior ignored upgrades
	local isIgnored				:boolean = hasPendingUpgrade and not m_player:DoesUnitHavePendingUpgrades(unitInfo.ID); -- Is the pending upgrade an ignored one?
	local isViewable			:boolean= true;
	local currentUpgrade		:table	= nil;
	local upgrades				:table	= {};
	local numLevels				:number = 0;
	local nextLevel				:number = 0;
	local portraitIndex			:number = -1;
	local portraitSize			:number = 128;
	local portraitAtlas			:string = "";
	local defaultPortraitAtlas	:string = "";
	local defaultPortraitIndex	:number = -1;
	local mostUpgradedName		:string = unitInfo.Description;

	if unitInfo.PrereqTech ~= nil then
		local activeTeamID	:number = Game.GetActiveTeam();
		local activeTeam	:table	= Teams[activeTeamID];	
		local tech			:table	= GameInfo.Technologies[unitInfo.PrereqTech];
		isViewable = activeTeam:GetTeamTechs():HasTech(tech.ID);
	end

	-- Start at the lowest level and work upwards
	for iLevel : number = 1, MAX_UPGRADE_LEVELS do
		local upgradeTypes : table = m_player:GetUpgradesForUnitClassLevel(unitInfo.ID, iLevel);
		if table.count(upgradeTypes) > 0 then
			numLevels = numLevels + 1;
		end
		if m_player:IsUnitUpgradeTierReady(unitInfo.ID, iLevel) then
			nextLevel = iLevel;
		end

		local upgradeData	:table = {};
		for _,iType in ipairs(upgradeTypes) do
			local upgrade	:table = GameInfo.UnitUpgrades[iType];
			local perkTypes	:table = m_player:GetPerksForUpgrade(upgrade.ID);
			local perks		:table = {};
			for _,perkType in ipairs(perkTypes) do
				local hasPerk		:boolean= m_player:DoesUnitHavePerk(unitInfo.ID, perkType)
				local perk			:table	= GameInfo.UnitPerks[perkType];
				local freePerk		:table;

				local perkMovement		:number = 0;
				local perkStrength		:number = 0;
				local perkRange			:number = 0;
				local perkRangedStrength:number = 0;
				for _,perkStatEntry in ipairs( m_allUnitPerkStats[unitInfo.ID] ) do
					if perkStatEntry.UpgradeType == upgrade.ID and perkStatEntry.PerkType == perkType then
						perkMovement		= perkStatEntry.Movement;
						perkStrength		= perkStatEntry.Strength;
						perkRange			= perkStatEntry.Range;
						perkRangedStrength	= perkStatEntry.RangedStrength;						
						freePerk			= GameInfo.UnitPerks[perkStatEntry.FreePerkType];
						perkMovement		= perkMovement + freePerk.MovesChange;
						perkStrength		= perkStrength + freePerk.ExtraCombatStrength;
						perkRange			= perkRange + freePerk.RangeChange;
						perkRangedStrength	= perkRangedStrength + freePerk.ExtraRangedCombatStrength;
					end
				end

				table.insert(perks,
				{
					ID				= perk.ID,
					HasPerk			= hasPerk,
					PortraitIndex	= perk.PortraitIndex,
					IconAtlas		= perk.IconAtlas,
					IconSize		= 56,
					UnitID			= unitInfo.ID,
					UpgradeID		= upgrade.ID,
					Movement		= perkMovement,
					Strength		= perkStrength,
					Range			= perkRange,
					RangedStrength	= perkRangedStrength,
				});
			end

			-- levels increase, if unit has this upgrade set it for the portrait
			local hasUpgrade		:boolean= m_player:DoesUnitHaveUpgrade(unitInfo.ID, iType);
			portraitIndex					= upgrade.PortraitIndex;
			portraitSize					= 128;
			portraitAtlas					= upgrade.IconAtlas;
			local isUpgradeIgnored	:boolean= m_player:IsUnitUpgradeIgnored(upgrade.ID);

			-- Update name if player has upgrade (will be progressively over-written by higher levels upgrades)
			if hasUpgrade then
				mostUpgradedName = upgrade.Description;
			end

			local isPurchasable:boolean = 
				(hasPendingUpgrade or isUpgradeIgnored) and
				(nextLevel >= iLevel) and
				upgrade.AnyAffinityLevel <= anyAmt and
				upgrade.PurityLevel		<= purityAmt and
				upgrade.HarmonyLevel	<= harmonyAmt and
				upgrade.SupremacyLevel	<= supremacyAmt;

			local singleUpgrade:table =
			{
				ID				= upgrade.ID,
				Level			= iLevel,
				Pending			= (nextLevel >= iLevel),
				HasUpgrade		= hasUpgrade,
				Any				= upgrade.AnyAffinityLevel,
				Purity			= upgrade.PurityLevel,
				Harmony			= upgrade.HarmonyLevel,
				Supremacy		= upgrade.SupremacyLevel,					
				Description		= upgrade.Description,
				Perks			= perks,
				IsPurchasable	= isPurchasable,
				PortraitAtlas	= portraitAtlas,
				PortraitIndex	= portraitIndex,
				PortraitSize	= portraitSize,
			};
			table.insert(upgradeData, singleUpgrade );

			-- Levels are built in increasing order, so the last upgrade will be most current.
			if hasUpgrade then 
				currentUpgrade = singleUpgrade;
			end
		end
		upgrades[iLevel] = upgradeData;

		-- Bit ugly write a default portrait for units that look the same in both level 0 and level 1
		if iLevel == 1 then
			defaultPortraitAtlas = portraitAtlas;
			defaultPortraitIndex = portraitIndex;
		end

	end -- level

	if not isViewable then
		isViewable = (hasPendingUpgrade or nextLevel > 1);
	end

	local unit:table= 
	{					
		ID					= unitInfo.ID,
		Type				= unitInfo.Type,
		BaseStrength		= unitInfo.Combat,
		BaseRangedStrength	= unitInfo.RangedCombat,
		BaseMovement		= unitInfo.Moves,
		CurrentUpgrade		= currentUpgrade,
		Description			= unitInfo.Description,
		Domain				= unitInfo.Domain,
		HasPendingUpgrade	= hasPendingUpgrade,		
		IsIgnored			= isIgnored,
		IsViewable			= isViewable,
		Movement			= math.floor(movement),
		MovementTip			= movementTip,
		Name				= mostUpgradedName,
		NextLevel			= nextLevel,
		NumLevels			= numLevels,
		DefaultPortraitAtlas= defaultPortraitAtlas,
		DefaultPortraitIndex= defaultPortraitIndex,
		Range				= range,
		RangedStrength		= rangedStrength,
		RequiredTech		= unitInfo.PrereqTech,
		Strength			= strength,
		UnitInfo			= unitInfo,
		Upgrades			= upgrades,
	};

	return unit;
end



-- ===========================================================================
--	Obtain a list of units based on the current filter.
--	RETURN: List o' units
-- ===========================================================================
function UpdateUnitList()

	local entries : table = {};		-- return value

	-- Reset badges
	for _,cfilter in pairs(Filter) do
		m_tabs["Filter"..cfilter.."BadgeCount"] = 0;
	end

	-- Loop through all units in the game.
	for unitInfo : object in GameInfo.Units() do
			
		-- Ignore satellites and some enemy units... 
		local upgradesForLevel1:table = m_player:GetUpgradesForUnitClassLevel(unitInfo.ID, 1);
		-- m_player:CanTrain(unitInfo.ID, true, true, true, false) and  -- This culls everything from the grid that isn't unlocked!
		if	(table.count(upgradesForLevel1) > 0) and 
			(DEBUG_ONE_UNIT_ONLY_ID == -1 or DEBUG_ONE_UNIT_ONLY_ID == unitInfo.ID ) then

			--if unitInfo.ID == 9 then
			--	print("DEBUGGING target unit");	-- debug: 5=solider, 6=ranger, 9=gun boat, 47=patrol boat
			--end

			local unit: table = UpdateSingleUnit( unitInfo );					
			table.insert( entries, unit );

			-- Update badge info if necesary
			if unit.HasPendingUpgrade then
				for _,filter in pairs(Filter) do
					if IsMatchingFilter( filter, unit ) then
						-- Don't show ignored units, except in the AVAIL
						if not unit.IsIgnored or filter == Filter.AVAIL then
							local amt:number = m_tabs["Filter"..filter.."BadgeCount"];
							amt = amt + 1;
							m_tabs["Filter"..filter.."BadgeCount"] = amt;
						end
					end
				end
			end
		end
	end -- each unit

	table.sort(entries, function(a : table, b : table) 
		if a.HasPendingUpgrade and not a.IsIgnored and not b.HasPendingUpgrade then
			return true;
		elseif not a.HasPendingUpgrade and b.HasPendingUpgrade then
			return false;
		else
			return Locale.Compare(a.Name, b.Name) < 0;		-- both have or don't have upgrade, alpha sort
		end
	end);

	return entries;		
end


-- ===========================================================================
function ShowWindow()
	if (not m_bShown) then
		m_bShown = true;
		Events.BlurStateChange(0);
		print("UnitUpgradePopup, Blur On");
		ContextPtr:SetHide(false);
	end
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	Reset();
	
	-- Set the tab based on if there are any (pending) upgrades available.
	if m_tabs["FilterAvailBadgeCount"] ~= nil and m_tabs["FilterAvailBadgeCount"] > 0 then
		m_tabs.SelectTab( Controls.FilterAvail );	
	else
		m_tabs.SelectTab( Controls.FilterAll );	
	end

	Controls.MySupremacyLabel:SetText("[ICON_SUPREMACY]"  .. m_player:GetAffinityLevel(SUPREMACY_AFFINITY_TYPE));
	Controls.MySupremacyContainer:SetSizeX(Controls.MySupremacyLabel:GetSizeX()+5);
	Controls.MyPurityLabel:SetText("[ICON_PURITY]"  .. m_player:GetAffinityLevel(PURITY_AFFINITY_TYPE));
	Controls.MyPurityContainer:SetSizeX(Controls.MyPurityLabel:GetSizeX()+5);
	Controls.MyHarmonyLabel:SetText("[ICON_HARMONY]"  .. m_player:GetAffinityLevel(HARMONY_AFFINITY_TYPE));
	Controls.MyHarmonyContainer:SetSizeX(Controls.MyHarmonyLabel:GetSizeX()+5);
	Controls.HeaderYieldStack:CalculateSize();
	Controls.HeaderYieldStack:ReprocessAnchoring();

	Events.SerialEventGameMessagePopupShown( m_popupInfo );
end

-- ===========================================================================
--	Single exit point to hide the window.
--	Makes sure signal is sent to system this is now closed.
-- ===========================================================================
function HideWindow()
	ContextPtr:SetHide(true);
	LuaEvents.UnitUpgradePopup_SubDiploPanelClosed();
end

-- ===========================================================================
function Close()
	if m_state == State.SELECT_UNIT then
		HideWindow();
	else
		m_state = State.SELECT_UNIT;
		Controls.PadImage:SetTexture(TEXTURE_STAND_OFF);
		Refresh();
	end
end

-- ===========================================================================
--	Callback from clicking
function OnClose()
	Close();	
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);


-- ===========================================================================
--	May be directly called by ESC or from a click
function CloseUpgradeWithoutAnActiviation()
	if m_state == State.UPGRADE_UNIT then
		-- If not already marked "ignored" auto-ignore that now.
		--[[
		if m_currentUpgrade ~= nil then						
			m_player:IgnoreUnitUpgrade( m_currentUpgrade.ID );		
			Events.SerialEventUnitUpgradeScreenDirty();
		end
		]]
		m_currentUpgrade = nil;
	end
	Close();
end

-- ===========================================================================
--	Closed by clicking the button
function OnUpgradeClose()
	CloseUpgradeWithoutAnActiviation();
end
Controls.UpgradeCloseButton:RegisterCallback(Mouse.eLClick, OnUpgradeClose);

-- ===========================================================================
--	LUA Event
--	Debug only, reload cached values across reload for this context.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == DEBUG_CACHE_SCREEN_NAME then
		m_hiddenAtShutdown		= contextTable["m_hiddenAtShutdown"];
		m_popupInfo				= contextTable["m_popupInfo"];		
		m_state					= contextTable["m_state"];
		m_unit					= contextTable["m_unit"];
		m_upgradeNotifications	= contextTable["m_upgradeNotifications"];
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnHide()
	Events.SerialEventGameMessagePopupProcessed.CallImmediate( ButtonPopupTypes.BUTTONPOPUP_UNIT_UPGRADE, 0 );
	if (m_bShown) then
		m_bShown = false;
		Events.BlurStateChange(1);
		print("UnitUpgradePopup, Blur Off");
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit( isHotload:boolean )	
	if not isHotload then		
		return;
	end
		
	LuaEvents.GameDebug_GetValues(DEBUG_CACHE_SCREEN_NAME);
	if not m_hiddenAtShutdown then
		ContextPtr:SetHide(false);
		if (not m_bShown) then
			m_bShown = true;
			Events.BlurStateChange(0);	
			print("UnitUpgradePopup, Blur On Init");	
		end
		m_allUnits = UpdateUnitList();
		if m_state == State.SELECT_UNIT then
			--OnPopup( m_popupInfo ); -- Fake gamecore calling this.. okay this may be overkill
			Reset();			
			m_tabs.SelectTab( Controls.FilterAll );
		else
			Refresh();
		end
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInput( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			Close();
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()

	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_hiddenAtShutdown",	ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_popupInfo",			m_popupInfo );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_state",				m_state );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_unit",				m_unit );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_upgradeNotifications",m_upgradeNotifications );
	LuaEvents.GameDebug_Return.Remove( OnGameDebugReturn );

	HideWindow();

	if not ContextPtr:IsHidden() then
		Events.SerialEventGameMessagePopupProcessed.CallImmediate( ButtonPopupTypes.BUTTONPOPUP_UNIT_UPGRADE, 0 );
	end
end

-- ===========================================================================
--	ENGINE EVENT
-- ===========================================================================
function OnNotificationAdded( Id:number, type, toolTip, strSummary, iGameValue, iExtraGameData, ePlayer )
	if (type == NotificationTypes.NOTIFICATION_UNIT_UPGRADES_AVAILABLE) then
		table.insert( m_upgradeNotifications, Id );
	end
end

-- ===========================================================================
--	ENGINE EVENT
--	Necessary to track notification events due to IGNOREing upgrades not
--	sending back a message when they are realized... the refresh here will
--	ensure ignored upgrades are reflected in the UI since this notification
--	event is sent after ignore has been applied.
-- ===========================================================================
function OnNotificationRemoved( Id:number )
	local position :number = 0;
	-- Find the corresponding upgrade notification (if it exist)
	for i,v in pairs(m_upgradeNotifications) do
		if ( v == Id ) then
			position = i;
			break;
		end
	end
	-- If the removed notification was related to upgrades, it would have a position other than 0. 
	if (position > 0 ) then
		table.remove( m_upgradeNotifications, i );
		Refresh();
	end
end



----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		Close();
	end
end

-- ===========================================================================
--	
-- ===========================================================================
function Initialize()

	-- One time sizing:
	m_width, m_height = UIManager:GetScreenSizeVal();
	Controls.UnitSelectBG:SetSizeY( m_height + 26 );
	Controls.UnitUpgradeBG:SetSizeY( m_height + -4 );
	Controls.UnitPerkGrid:SetSizeY( m_height - 12 );

	Controls.PerkSelectArea:SetSizeY(m_height - 477 );
	Controls.AbilitiesScroll:SetSizeY( math.floor( 150 + ((m_height - 776) * 0.5 )));

	Reset();				-- Must be done before tab setup.
	PreAllocateParticles();

	-- Tab setup
	m_tabs = CreateTabs( Controls.TabRow, 64, 32 );
	m_tabs.AddTab( Controls.FilterAvail,	function() m_filter = Filter.AVAIL; Refresh(); end );
	m_tabs.AddTab( Controls.FilterAll,		function() m_filter = Filter.ALL;	Refresh(); end );
	m_tabs.AddTab( Controls.FilterMelee,	function() m_filter = Filter.MELEE; Refresh(); end );
	m_tabs.AddTab( Controls.FilterRanged,	function() m_filter = Filter.RANGED;Refresh(); end );
	m_tabs.AddTab( Controls.FilterNaval,	function() m_filter = Filter.NAVAL; Refresh(); end );
	m_tabs.AddTab( Controls.FilterHover,	function() m_filter = Filter.HOVER; Refresh(); end );
	m_tabs.AddTab( Controls.FilterAir,		function() m_filter = Filter.AIR;	Refresh(); end );
	m_tabs.EvenlySpreadTabs();		
	for _,filterName in pairs(Filter) do
		SetBadge( filterName, 0 );
	end

	-- Native UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInput );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetShutdown( OnShutdown );
	
	-- Game Events
	Events.NotificationAdded.Add( OnNotificationAdded );
	Events.NotificationRemoved.Add( OnNotificationRemoved );
	Events.SerialEventGameMessagePopup.Add( OnPopup );	
	Events.SerialEventUnitUpgradeScreenDirty.Add( OnRefreshData );
	Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);
	
	-- LUA Events
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );		-- hotloading help	
end
Initialize();
