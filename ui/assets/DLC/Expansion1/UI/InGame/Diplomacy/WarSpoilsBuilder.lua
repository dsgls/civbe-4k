include("IconSupport");
include("InstanceManager");
include("TechButtonInclude");
include("AffinityInclude");

local PETROLEUM_RESOURCE_TYPE : number	= GameInfo.Resources["RESOURCE_PETROLEUM"].ID;
local GEOTHERMAL_RESOURCE_TYPE : number = GameInfo.Resources["RESOURCE_GEOTHERMAL_ENERGY"].ID;
local TITANIUM_RESOURCE_TYPE : number	= GameInfo.Resources["RESOURCE_TITANIUM"].ID;
local FIRAXITE_RESOURCE_TYPE : number	= GameInfo.Resources["RESOURCE_FIRAXITE"].ID;
local XENOMASS_RESOURCE_TYPE : number	= GameInfo.Resources["RESOURCE_XENOMASS"].ID;
local FLOAT_STONE_RESOURCE_TYPE : number = GameInfo.Resources["RESOURCE_FLOAT_STONE"].ID;
local PROGRESS_BAR_WIDTH : number = 155 * 2;

-- Taken from TechTree.lua
local AFFINITY_RING_SIZE	:number				= 46 * 2;		-- 46x46
local m_affinityRingUVIndex	:table				= {};			
m_affinityRingUVIndex[AFFINITY.harmony]			= {u=0,v=0};
m_affinityRingUVIndex[AFFINITY.purity]			= {u=1,v=0};
m_affinityRingUVIndex[AFFINITY.supremacy]		= {u=2,v=0};
m_affinityRingUVIndex[AFFINITY.purityharmony]	= {u=0,v=1};
m_affinityRingUVIndex[AFFINITY.supremacypurity]	= {u=1,v=1};
m_affinityRingUVIndex[AFFINITY.harmonysupremacy]= {u=2,v=1};
m_affinityRingUVIndex[AFFINITY.harmonypuritysupremacy]= {u=0,v=2};	-- Yes there is one that has all three.

local m_givingPlayer : object = nil;	-- The player whose stuff we're showing
local m_receivingPlayer : object = nil; -- The player receiving said stuff

local m_techItemInstanceManager : table = InstanceManager:new("TechItem", "Content", Controls.TechStack);
local m_cityItemInstanceManager : table = InstanceManager:new("CityItem", "Content", Controls.CityStack);

local m_spoils : table = nil;
local m_warStatus : object = nil;

local m_callback : ifunction = nil;

local m_instances : table = {};

function Update()
	if (m_givingPlayer == nil or m_receivingPlayer == nil) then
		return;
	end

	m_instances = {};

	local givingPlayerScore : number = m_warStatus:GetPlayerScore(m_givingPlayer:GetID());
	local receivingPlayerScore : number = m_warStatus:GetPlayerScore(m_receivingPlayer:GetID());

	if (m_givingPlayer:GetID() == Game.GetActivePlayer()) then
		Controls.TechLabel:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_YOUR_TECHS"));
		Controls.CitiesLabel:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_YOUR_CITIES"));
		Controls.YieldsLabel:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_YOUR_YIELDS"));
		Controls.Help:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_LOSER_HELP"));
	else
		Controls.TechLabel:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_THEIR_TECHS"));
		Controls.CitiesLabel:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_THEIR_CITIES"));
		Controls.YieldsLabel:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_THEIR_YIELDS"));
		if (m_givingPlayer:IsAlive()) then
			Controls.Help:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_WINNER_HELP"));
		else
			Controls.Help:SetText(Locale.Lookup("TXT_KEY_WAR_SPOILS_ELIMINATION_WIN_HELP"));
		end
	end

	Controls.HelpBox:SetSizeY(Controls.Help:GetSizeY() + 35);

	UpdateCities();
	UpdateTechs();
	UpdateYields();

	UpdateCosts();
	UpdateValid();
end

function UpdateCities()
	-- WRM: Candidate for the worst-named API of all time.  TechButtonInclude needs this
	--		for its functions to work.
	GatherInfoAboutUniqueStuff(m_givingPlayer:GetCivilizationType());

	-- Populate the cities list
	m_cityItemInstanceManager:ResetInstances();
	for city : object in m_givingPlayer:Cities() do
		if (not city:IsCapital()) then
			local instance : table = m_cityItemInstanceManager:GetInstance();
			InitCityItemInstance(instance, city);
			
			table.insert(m_instances, instance);
		end
	end
	Controls.CityStack:CalculateSize();
	Controls.CityStack:ReprocessAnchoring();
	Controls.CityScrollPanel:CalculateInternalSize();
end

function UpdateTechs()
	-- Build a list of techs we can give
	local availableTechs : table = {};
	for techInfo : table in GameInfo.Technologies() do
		if (m_givingPlayer:HasTech(techInfo.ID) and not m_receivingPlayer:HasTech(techInfo.ID)) then
			table.insert(availableTechs, techInfo.ID);
		end
	end

	-- Sort techs
	table.sort(availableTechs, function(a : number, b : number) 
		local techInfoA : table = GameInfo.Technologies[a];
		local techInfoB : table = GameInfo.Technologies[b];

		return Locale.Compare(techInfoA.Description, techInfoB.Description) == -1;
	end);

	-- Populate tech list
	m_techItemInstanceManager:ResetInstances();
	for i : number, techType : number in ipairs(availableTechs) do
		local instance : table = m_techItemInstanceManager:GetInstance();
		InitTechItemInstance(instance, techType);

		table.insert(m_instances, instance);
	end
	Controls.TechStack:CalculateSize();
	Controls.TechStack:ReprocessAnchoring();
	Controls.TechScrollPanel:CalculateInternalSize();
end

function UpdateYields()
	Controls.EnergyLabel:SetText(Locale.Lookup("TXT_KEY_PEACE_ENERGY_HEADER", m_givingPlayer:GetEnergy()));
	Controls.CapitalLabel:SetText(Locale.Lookup("TXT_KEY_PEACE_CAPITAL_HEADER", m_givingPlayer:GetDiplomaticCapital()));
	Controls.EnergyWarScore:SetText(string.format("%.1f", m_warStatus:GetWarScoreValueForEnergyUnit()));
	Controls.CapitalWarScore:SetText(m_warStatus:GetWarScoreValueForCapitalUnit());

	local energyCommitted : number = m_warStatus:GetPeaceTermsLumpEnergy();
	local capitalCommitted : number = m_warStatus:GetPeaceTermsLumpCapital();

	Controls.EnergyEditbox:SetText(energyCommitted);
	Controls.CapitalEditbox:SetText(capitalCommitted);
end

function UpdateCosts()
	for i : number, instance : table in ipairs(m_instances) do
		instance.UpdateCost();
	end

	local goal : number = m_warStatus:GetWarScoreDifference();
	local progress : number = goal - m_warStatus:GetWarScoreDifferenceIncludingSpoils();
	local clampedProgress : number = progress;
	if (clampedProgress > goal) then
		clampedProgress = goal;
	end

	local barCurrent : number = PROGRESS_BAR_WIDTH - (( clampedProgress / goal ) * PROGRESS_BAR_WIDTH);
	
	Controls.BarCurrent:SetTextureOffsetVal(barCurrent, 0);

	if (progress < goal) then
		Controls.ScoreCommitted:SetText(progress .. "/" .. goal);
	else
		Controls.ScoreCommitted:SetText("[COLOR_GREEN]" .. progress .. "/" .. goal);
	end
	
	
	UpdateValid();
end

function UpdateValid()
	local areTermsValid : boolean = AreTermsValid();
	Controls.ConfirmSpoilsButton:SetDisabled(not areTermsValid);
	if (areTermsValid) then
		Controls.ConfirmSpoilsButton:SetToolTipString(nil);
	else
		if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
			-- We're demanding spoils
			Controls.ConfirmSpoilsButton:SetToolTipString(Locale.Lookup("TXT_KEY_WAR_SPOILS_TOO_MUCH_VALUE_TT"));
		else
			-- We're surrendering spoils
			Controls.ConfirmSpoilsButton:SetToolTipString(Locale.Lookup("TXT_KEY_WAR_SPOILS_NOT_ENOUGH_VALUE_TT"));
		end
	end
end

function InitCityItemInstance(instance : table, city : object)
	local warScore : number = m_warStatus:GetWarScoreValueForCity(city);
	instance.IsActive = m_warStatus:HasPeaceTermCity(city);

	instance.Name:SetText(Locale.Lookup(city:GetName()));
	instance.Petroleum:SetText("[ICON_PETROLEUM]"..city:GetNumResourceLocal(PETROLEUM_RESOURCE_TYPE));
	instance.Geothermal:SetText("[ICON_GEOTHERMAL]"..city:GetNumResourceLocal(GEOTHERMAL_RESOURCE_TYPE));
	instance.Titanium:SetText("[ICON_TITANIUM]"..city:GetNumResourceLocal(TITANIUM_RESOURCE_TYPE));
	instance.Firaxite:SetText("[ICON_FIRAXITE]"..city:GetNumResourceLocal(FIRAXITE_RESOURCE_TYPE));
	instance.Xenomass:SetText("[ICON_XENOMASS]"..city:GetNumResourceLocal(XENOMASS_RESOURCE_TYPE));
	instance.Floatstone:SetText("[ICON_FLOAT_STONE]"..city:GetNumResourceLocal(FLOAT_STONE_RESOURCE_TYPE));
	instance.WarScore:SetText(warScore);
	instance.Check:SetHide(not instance.IsActive);

	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		if (m_warStatus:HasPeaceTermCity(city)) then
			m_warStatus:RemovePeaceTermCity(city);
			instance.IsActive = false;
		else
			m_warStatus:AddPeaceTermCity(city);
			instance.IsActive = true;
		end

		instance.Check:SetHide(not instance.IsActive);

		UpdateCosts();
	end);

	instance.UpdateCost = function()
		local currentWarScore : number = m_warStatus:GetWarScoreValueForCity(city);
		local canAfford : boolean = false;

		if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
			canAfford = currentWarScore <= m_warStatus:GetWarScoreDifferenceIncludingSpoils();
		else
			canAfford = m_warStatus:GetWarScoreDifferenceIncludingSpoils() > 0;
		end

		instance.CheckBoxDisabled:SetHide(canAfford or instance.IsActive);
		instance.Button:SetDisabled(not canAfford and not instance.IsActive);
	end
end

function InitTechItemInstance(instance : table, techType : number) 
	local techInfo : table = GameInfo.Technologies[techType];
	local warScore : number = m_warStatus:GetWarScoreValueForTech(techType);
	instance.IsActive = m_warStatus:HasPeaceTermTech(techType);

	for i : number = 1, 5, 1 do
		instance["IconUnderlay" .. i]:SetHide(true);
	end

	instance.Name:SetText(Locale.Lookup(techInfo.Description))
	instance.WarScore:SetText(warScore);
	IconHookup(techInfo.PortraitIndex, 64, techInfo.IconAtlas, instance.Portrait);

	-- Taken from TechTree.lua:
	-- Affinity ring
	local affinities:table = {};
	local hasPurity		:boolean= false;
	local hasSupremacy	:boolean= false;
	local hasHarmony	:boolean= false;
	local affinity		:number;
	for techAffinityPair in GameInfo.Technology_Affinities()  do
		if techAffinityPair.TechType == techInfo.Type then
			if		techAffinityPair.AffinityType == "AFFINITY_TYPE_SUPREMACY"	then hasSupremacy=true; 
			elseif	techAffinityPair.AffinityType == "AFFINITY_TYPE_PURITY"		then hasPurity	=true; 
			elseif	techAffinityPair.AffinityType == "AFFINITY_TYPE_HARMONY"	then hasHarmony	=true; 
			end
		end
	end

	if hasPurity and hasSupremacy and hasHarmony then	
		affinity = AFFINITY.harmonypuritysupremacy;
	elseif hasPurity and hasSupremacy then				affinity = AFFINITY.supremacypurity;
	elseif hasHarmony and hasPurity then				affinity = AFFINITY.purityharmony;
	elseif hasSupremacy and hasHarmony then				affinity = AFFINITY.harmonysupremacy;
	elseif hasPurity				then				affinity = AFFINITY.purity;
	elseif hasSupremacy				then				affinity = AFFINITY.supremacy;
	elseif hasHarmony				then				affinity = AFFINITY.harmony;
	end
	instance.AffinityRing:SetHide( affinity==nil );
	if affinity ~= nil then
		instance.AffinityRing:SetTextureOffsetVal( 
			m_affinityRingUVIndex[affinity].u * AFFINITY_RING_SIZE, 
			m_affinityRingUVIndex[affinity].v * AFFINITY_RING_SIZE 
		);
	end

	instance.Check:SetHide(not instance.IsActive);

	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		if (m_warStatus:HasPeaceTermTech(techType)) then
			m_warStatus:RemovePeaceTermTech(techType);
			instance.IsActive = false;
		else
			m_warStatus:AddPeaceTermTech(m_givingPlayer:GetID(), techType);
			instance.IsActive = true;
		end

		instance.Check:SetHide(not instance.IsActive);

		UpdateCosts();
	end);

	instance.UpdateCost = function()
		local currentWarScore : number = m_warStatus:GetWarScoreValueForTech(techType);
		local canAfford : boolean = false;

		if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
			canAfford = currentWarScore <= m_warStatus:GetWarScoreDifferenceIncludingSpoils();
		else
			canAfford = m_warStatus:GetWarScoreDifferenceIncludingSpoils() > 0;
		end

		instance.CheckBoxDisabled:SetHide(canAfford or instance.IsActive);
		instance.Button:SetDisabled(not canAfford and not instance.IsActive);
	end

	AddSmallButtonsToTechButton(instance, techInfo, 5, 45, 1);
end

function GetRemainingWarScore()
	local givingPlayerScore : number = m_warStatus:GetPlayerScore(m_givingPlayer:GetID());
	local receivingPlayerScore : number = m_warStatus:GetPlayerScore(m_receivingPlayer:GetID());

	if (givingPlayerScore > receivingPlayerScore) then
		return givingPlayerScore - receivingPlayerScore;
	else
		return receivingPlayerScore - givingPlayerScore;
	end
end

function AreTermsValid()
	local currentWarScore : number = m_warStatus:GetWarScoreDifferenceIncludingSpoils();

	if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
		-- We're demanding spoils
		return currentWarScore >= 0 or m_warStatus:IsTotalSurrender();
	else
		-- We're surrendering spoils
		return currentWarScore <= 0 or m_warStatus:IsTotalSurrender();
	end
end

-------------------------------------------------
-- Event Listeners
-------------------------------------------------
function OnShowWarSpoilsBuilder(playerAType : number, playerBType : number, callback : ifunction)
	m_warStatus = Game.GetWarStatus(playerAType, playerBType);
	if (m_warStatus ~= nil) then
		local playerAScore : number = m_warStatus:GetPlayerScore(playerAType);
		local playerBScore : number = m_warStatus:GetPlayerScore(playerBType);

		if (playerAScore > playerBScore) then
			m_givingPlayer = Players[playerBType];
			m_receivingPlayer = Players[playerAType];
		elseif (playerBScore > playerAScore) then
			m_givingPlayer = Players[playerAType];
			m_receivingPlayer = Players[playerBType];
		else
			-- This window shouldn't show if the scores are the same.
			if (callback ~= nil) then
				callback(true);
			end
			return;
		end

		m_callback = callback;

		m_spoils = {};
		m_spoils.Cities = {};
		m_spoils.Techs = {};
		m_spoils.Energy = 0;
		m_spoils.DiploCapital = 0;

		ContextPtr:SetHide(false);
	else
		if (callback ~= nil) then
			callback(true);
		end
		return;
	end
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function OnInitialize(isHotload : boolean)
	LuaEvents.DiplomacyUI_ShowWarSpoilsBuilder.Add(OnShowWarSpoilsBuilder);
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	LuaEvents.DiplomacyUI_ShowWarSpoilsBuilder.Remove(OnShowWarSpoilsBuilder);
end
ContextPtr:SetShutdown(OnShutdown);

function ShowHideHandler(isHide : boolean)
	if (not isHide) then
		-- Reset animations
		Controls.SelectSpoilsAlphaAnim:SetToBeginning();
		Controls.SelectSpoilsAlphaAnim:Play();
		Controls.SelectSpoilsSlideAnim:SetToBeginning();
		Controls.SelectSpoilsSlideAnim:Play();

		-- Update window data
		Update();
	else
		m_givingPlayer = nil;
		m_receivingPlayer = nil;
		m_callback = nil;
		m_spoils = nil;
		m_warStatus = nil;
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function OnConfirm()
	if (m_callback ~= nil) then
		m_callback(true);
	end

	ContextPtr:SetHide(true);
end
Controls.ConfirmSpoilsButton:RegisterCallback(Mouse.eLClick, OnConfirm);

function OnCancel()
	if (m_callback ~= nil) then
		m_callback(false);
	end

	ContextPtr:SetHide(true);
end
Controls.CancelSpoilsButton:RegisterCallback(Mouse.eLClick, OnCancel);

function OnEnergyEditboxChanged()
	m_warStatus:SetPeaceTermLumpEnergy(0);

	local available : number = m_givingPlayer:GetEnergy();
	local canCommit : number = m_warStatus:GetWarScoreDifferenceIncludingSpoils() / m_warStatus:GetWarScoreValueForEnergyUnit();
	if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
		canCommit = math.floor(canCommit);
	else	
		canCommit = math.ceil(canCommit);
	end

	local allowed : number = math.min(available, canCommit);

	local input : number = tonumber(Controls.EnergyEditbox:GetText());

	if (input == nil) then
		input = 0;
	else
		if (input > allowed) then
			input = allowed;
		end
	end
	
	if (input < 0) then
		input = 0
	end

	Controls.EnergyEditbox:SetText(input);

	m_warStatus:SetPeaceTermLumpEnergy(input);

	UpdateCosts();
end
Controls.EnergyEditbox:RegisterCallback(OnEnergyEditboxChanged);

function OnCapitalEditboxChanged()
	m_warStatus:SetPeaceTermLumpCapital(0);

	local available : number = m_givingPlayer:GetDiplomaticCapital();
	local canCommit : number = m_warStatus:GetWarScoreDifferenceIncludingSpoils() / m_warStatus:GetWarScoreValueForCapitalUnit();
	if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
		canCommit = math.floor(canCommit);
	else	
		canCommit = math.ceil(canCommit);
	end

	local allowed : number = math.min(available, canCommit);

	local input : number = tonumber(Controls.CapitalEditbox:GetText());

	if (input == nil) then
		input = 0;
	else
		if (input > allowed) then
			input = allowed;
		end
	end

	if (input < 0) then
		input = 0
	end

	Controls.CapitalEditbox:SetText(input);

	m_warStatus:SetPeaceTermLumpCapital(input);

	UpdateCosts();
end
Controls.CapitalEditbox:RegisterCallback(OnCapitalEditboxChanged);

function OnMaxEnergyButton()
	m_warStatus:SetPeaceTermLumpEnergy(0);

	local available : number = m_givingPlayer:GetEnergy();
	local canCommit : number = m_warStatus:GetWarScoreDifferenceIncludingSpoils() / m_warStatus:GetWarScoreValueForEnergyUnit();
	if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
		canCommit = math.floor(canCommit);
	else	
		canCommit = math.ceil(canCommit);
	end

	local max : number = math.min(available, canCommit);
	if (max < 0) then
		max = 0;
	end

	Controls.EnergyEditbox:SetText(max);
	m_warStatus:SetPeaceTermLumpEnergy(max);
	
	UpdateCosts();
end
Controls.MaxEnergyButton:RegisterCallback(Mouse.eLClick, OnMaxEnergyButton);

function OnMaxCapitalButton()
	m_warStatus:SetPeaceTermLumpCapital(0);

	local available : number = m_givingPlayer:GetDiplomaticCapital();
	local canCommit : number = m_warStatus:GetWarScoreDifferenceIncludingSpoils() / m_warStatus:GetWarScoreValueForCapitalUnit();
	if (m_receivingPlayer:GetID() == Game.GetActivePlayer()) then
		canCommit = math.floor(canCommit);
	else	
		canCommit = math.ceil(canCommit);
	end

	local max : number = math.min(available, canCommit);
	if (max < 0) then
		max = 0;
	end

	Controls.CapitalEditbox:SetText(max);
	m_warStatus:SetPeaceTermLumpCapital(max);
	
	UpdateCosts();
end
Controls.MaxCapitalButton:RegisterCallback(Mouse.eLClick, OnMaxCapitalButton);