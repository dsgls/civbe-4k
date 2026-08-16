-------------------------------------------------
-- Traits Overview
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");

local m_shown : boolean = false;
local m_player : object = nil;
local m_playerTraits : table = nil;
local m_selectedCategoryInfo : table = {};

local m_traitInstanceManager : table = InstanceManager:new("TraitLevelInstance", "Content", Controls.TraitLevelsStack);

local m_traitCategoryData : table = 
{
	{
		Info = GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_CHARACTER"],
		ControlPrefix = "CharacterTrait",
	},
	{
		Info = GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_POLITICAL"],
		ControlPrefix = "PoliticalTrait",
	},
	{
		Info = GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_DOMESTIC"],
		ControlPrefix = "DomesticTrait",
	},
	{
		Info = GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_MILITARY"],
		ControlPrefix = "MilitaryTrait",
	},
};

-------------------------------------------------
-- Init and boiler-plate
-------------------------------------------------
function OnShowTraitsOverview(player : object)
	-- WRM: Work-around for hotloading bug
	if (Players == nil) then
		return;
	end

	m_player = player;
	m_selectedCategoryInfo = nil;

	ContextPtr:SetHide(false);
end
LuaEvents.ShowTraitsOverview.Add(OnShowTraitsOverview);

function ShowHideHandler(isHide : boolean)
	m_shown = not isHide;

	if (not isHide) then
		-- WRM: Work-around for hotloading bug
		if (Players == nil) then
			return;
		end

		Controls.SlideAnim:SetToBeginning();
		Controls.SlideAnim:Play();
		Controls.AlphaAnim:SetToBeginning();
		Controls.AlphaAnim:Play();

		UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function InputHandler(msg, wParam, lParam)
	if (msg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE) then
			OnClose();
		end
	end

	return true;
end
ContextPtr:SetInputHandler(InputHandler);

-------------------------------------------------
-- Update
-------------------------------------------------
function UpdateWindow()
	if (not m_shown) then
		return;
	end
	
	-- For hotload debugging
	if (m_player == nil) then
		return;
	end

	-- Cache player's traits
	m_playerTraits = m_player:GetPersonalityTraits();

	-- Update trait buttons
	for i : number, data : table in ipairs(m_traitCategoryData) do
		local button : table = Controls[data.ControlPrefix .. "Button"];
		local icon : table = Controls[data.ControlPrefix .. "Icon"];
		local categoryInfo : table = data.Info;
		
		button:RegisterCallback(Mouse.eLClick, function() 
			m_selectedCategoryInfo = categoryInfo;
			UpdateWindow();
		end)
	end

	if (m_selectedCategoryInfo == nil) then
		m_selectedCategoryInfo = m_traitCategoryData[1].Info;
	end

	-- Update trait
	

	-- Update trait levels
	m_traitInstanceManager:ResetInstances();
	local trait : table = FindTraitInfoForCategoryType(m_playerTraits, m_selectedCategoryInfo.ID);
	if (trait ~= nil) then
		Controls.CurrentTraitNameLabel:SetText(Locale.Lookup(GameInfo.PersonalityTraits[trait:GetType()].Description));
		
		for i : number = 1, GameDefines.DIPLO_TRAIT_MAX_LEVELS, 1 do
			local instance : table = m_traitInstanceManager:GetInstance();
			InitTraitLevelInstance(instance, trait, i);
		end
	else
	end

	Controls.TraitLevelsStack:CalculateSize();
	Controls.TraitLevelsStack:ReprocessAnchoring();
end
Events.PersonalityTraitAdded.Add(UpdateWindow);
Events.PersonalityTraitRemoved.Add(UpdateWindow);
Events.PersonalityTraitLeveledUp.Add(UpdateWindow);

function FindTraitInfoForCategoryType(traits : table, categoryType : number)
	local categoryTypeName : string = GameInfo.PersonalityTraitCategories[categoryType].Type;
	
	for i : number, trait : table in ipairs(traits) do
		local traitInfo : table = GameInfo.PersonalityTraits[trait:GetType()];
		if (traitInfo.TraitCategoryType == categoryTypeName) then
			return trait;
		end
	end

	return nil;
end

function InitTraitLevelInstance(instance : table, trait : table, level : number)
	local traitInfo : table = GameInfo.PersonalityTraits[trait:GetType()];
	
	instance.LevelLabel:SetText("$Level " .. level);

	-- Set up instance manager for policies
	if (instance.PoliciesInstanceManager == nil) then
		instance.PoliciesInstanceManager = InstanceManager:new("PolicyInstance", "Content", instance.PoliciesStack);
	end
	instance.PoliciesInstanceManager:ResetInstances();

	-- Get policies for this trait level
	local policyInfos : table = {};
	for policyData : table in GameInfo.PersonalityTraits_ForeignPolicies{PersonalityTraitType = traitInfo.Type} do
		table.insert(policyInfos, GameInfo.ForeignPolicies[policyData.ForeignPolicyType]);
	end

	-- Get perks for this trait level
	local perkInfos : table = {};
	for perkData : table in GameInfo.PersonalityTraits_Perks{PersonalityTraitType = traitInfo.Type, Level = level} do
		table.insert(perkInfos, GameInfo.PlayerPerks[perkData.PlayerPerkType]);
	end

	-- Create instances for policies
	for i : number, policyInfo : table in ipairs(policyInfos) do
		local policyInstance : table = instance.PoliciesInstanceManager:GetInstance();
		InitPolicyInstance(policyInstance, policyInfo);
	end
	instance.PoliciesStack:CalculateSize();
	instance.PoliciesStack:ReprocessAnchoring();

	-- Build perks string
	local perkStr = "";
	for i : number, perkInfo : table in ipairs(perkInfos) do
		perkStr = perkStr .. "[BULLET]" .. perkInfo.Help .. "[NEWLINE]";
	end
	instance.PerksLabel:SetText(perkStr);

	-- WRM: The adding and subtracting to level are there because
	--		level in native is base-0.

	-- Highlight
	instance.Highlight:SetHide(trait:GetLevel() < level-1);

	-- Level up button
	if (m_player:GetID() == Game.GetActivePlayer()) then
		instance.LevelUpButton:SetHide(trait:GetLevel()+2 ~= level);
		instance.LevelUpButton:SetDisabled(not trait:CanLevelUp());
		instance.LevelUpButton:SetText(Locale.Lookup("TXT_KEY_LEVEL_UP_BUTTON", trait:GetTraitModificationCost()));
		instance.LevelUpButton:RegisterCallback(Mouse.eLClick, function() 
			Network.SendLevelUpPersonalityTrait(m_player:GetID(), trait:GetType());
		end);
	else
		instance.LevelUpButton:SetHide(true);
	end
end

function InitPolicyInstance(instance : table, policyInfo : table)
	IconHookup(policyInfo.PortraitIndex, 64, policyInfo.IconAtlas, instance.Icon);
	instance.Icon:SetToolTipString(Locale.Lookup(policyInfo.Description) .. "[NEWLINE]" .. Locale.Lookup(policyInfo.Help));
end

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function OnClose()
	ContextPtr:SetHide(true);
end
Controls.CancelButton:RegisterCallback(Mouse.eLClick, OnClose);