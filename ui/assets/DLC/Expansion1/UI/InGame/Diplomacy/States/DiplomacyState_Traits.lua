-------------------------------------------------
-- Traits Diplomacy State
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");

local m_player						: object = nil;
local m_selectedPlayer				: object = nil;
local m_shown						: boolean = false;
local m_selectedCategoryInfo		: table = nil;
local m_traitsInstanceManager		: table = InstanceManager:new("PersonalityTrait", "Content", Controls.TraitsStack);
local m_selectTraitsInstanceManager : table = InstanceManager:new("PersonalityTrait", "Content", Controls.SelectTraitsStack);

local m_traitCategoryInfos : table = 
{
	GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_CHARACTER"],
	GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_POLITICAL"],
	GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_DOMESTIC"],
	GameInfo.PersonalityTraitCategories["PERSONALITY_TRAIT_CATEGORY_MILITARY"],
};

-- Swap controls
local m_oldTraitInstance : table = {};
local m_newTraitInstance : table = {};

function ShowHideHandler(isHide : boolean)
	if (not isHide) then
		if (m_selectedCategoryInfo == nil) then
			ShowDiploTutorial("DIPLOMACY_TRAITS", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_TRAITS"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_TRAITS");
			DoListTraits();
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function UpdateTraits()
	if (not m_shown) then
		return;
	end

	m_traitsInstanceManager:ResetInstances();

	local traits : table = m_player:GetPersonalityTraits();
	if (traits == nil) then
		error("No traits found");
	end

	table.sort(traits, function(a, b) 
		local traitAInfo : table = GameInfo.PersonalityTraits[a:GetType()];
		local traitBInfo : table = GameInfo.PersonalityTraits[b:GetType()];
		local categoryAInfo : table = GameInfo.PersonalityTraitCategories[traitAInfo.TraitCategoryType];
		local categoryBInfo : table = GameInfo.PersonalityTraitCategories[traitBInfo.TraitCategoryType];

		return categoryAInfo.UIPriority < categoryBInfo.UIPriority;
	end);

	for i : number, categoryInfo : table in ipairs(m_traitCategoryInfos) do
		local trait : object = nil;
		for j : number, tempTrait in ipairs(traits) do
			if (GameInfo.PersonalityTraits[tempTrait:GetType()].TraitCategoryType == categoryInfo.Type) then
				trait = tempTrait;
				break;
			end
		end

		local instance	: table	= m_traitsInstanceManager:GetInstance();

		if (trait ~= nil) then
			local traitInfo : table = GameInfo.PersonalityTraits[trait:GetType()];
			
			local changeTraitTT : string = Locale.Lookup("{TXT_KEY_DIPLOMACYUI_SPENDTOSWITCH}", m_player:GetTraitModificationCost());
			InitPersonalityTraitInstance(instance, m_player:GetID(), traitInfo);

			local categoryInfo : table = GameInfo.PersonalityTraitCategories[traitInfo.TraitCategoryType];

			instance.Icon:SetHide(false);
			instance.ChangeButton:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_SWITCHTRAIT:upper}"));
			instance.ChangeButtonCost:SetText(m_player:GetTraitModificationCost());
			local costContainerSizeX = 58;
			instance.ChangeButtonCostStack:CalculateSize();
			instance.ChangeButtonCostStack:ReprocessAnchoring();
			if (instance.ChangeButtonCostStack:GetSizeX()+25) > costContainerSizeX then
				costContainerSizeX = (instance.ChangeButtonCostStack:GetSizeX()+25);
			end
			instance.ChangeButtonCostContainer:SetSizeX(costContainerSizeX);

			if (m_selectedPlayer == m_player) then
				if (traitInfo.TraitCategoryType ~= "PERSONALITY_TRAIT_CATEGORY_CHARACTER") then
					instance.CantChange:SetHide(true);
					instance.ChangeButton:SetHide(false);
					if (m_player:GetDiplomaticCapital() < m_player:GetTraitModificationCost()) then
						instance.ChangeButton:SetDisabled(true);
						instance.ChangeButton:SetToolTipString(changeTraitTT.."[NEWLINE]".. Locale.Lookup("TXT_KEY_DIPLOMACYUI_NOTENOUGH"));
					else
						instance.ChangeButton:SetDisabled(false);
						instance.ChangeButton:SetToolTipString(changeTraitTT);
						instance.ChangeButton:RegisterCallback(Mouse.eLClick, function() 
							DoSwapTrait(categoryInfo);
						end);
					end
					instance.ChangeButton:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_SWITCHTRAIT:upper}"));
				else
					instance.CantChange:SetHide(false);
					instance.ChangeButton:SetHide(true);
				end	
			else
				instance.CantChange:SetHide(true);
				instance.ChangeButton:SetHide(true);
			end
		else			
			InitPersonalityTraitInstance(instance, m_player:GetID(), nil);
			instance.CategoryName:SetText(Locale.Lookup(categoryInfo.Description));
			if(categoryInfo.BannerImage ~= nil) then
				instance.BannerImage:SetTexture(categoryInfo.BannerImage);
			end
			instance.Name:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_EMPY_TRAIT:upper}"))
			instance.ChangeButton:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_ADD_TRAIT:upper}"));
			instance.Icon:SetHide(true);
			instance.ChangeButtonCost:SetText(m_player:GetTraitModificationCost());

			if (m_player:GetDiplomaticCapital() < m_player:GetTraitModificationCost()) then
				instance.ChangeButton:SetDisabled(true);
				instance.ChangeButton:SetToolTipString(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NOTENOUGH"));
			else
				instance.ChangeButton:SetDisabled(false);
				instance.ChangeButton:SetToolTipString(changeTraitTT);
				instance.ChangeButton:RegisterCallback(Mouse.eLClick, function() 
					DoSwapTrait(categoryInfo);
				end);
			end
		end

		if (not m_player:IsTurnActive()) then
			instance.ChangeButton:SetDisabled(true);
		end
	end

	Controls.TraitsStack:CalculateSize();
	Controls.TraitsStack:ReprocessAnchoring();
end

function DoListTraits()
	DoCancelSwap();

	Controls.ConfirmSwap:SetHide(true);
	Controls.TraitsStack:SetHide(false);
	Controls.SelectTraitsPanel:SetHide(true);
	UpdateTraits();
end

function DoCancelSwap()
	Controls.TraitsStack:SetHide(false);
	Controls.SelectTraitsPanel:SetHide(true);
	Controls.ManageTraitsAlpha:SetToBeginning();
	Controls.ManageTraitsAlpha:Play();
	Controls.ManageTraitsSlide:SetToBeginning();
	Controls.ManageTraitsSlide:Play();
	Controls.CancelButton:SetHide(true);
	Controls.SelectTraitIndicator:SetHide(true);
	Controls.SelectTraitLabel:SetHide(true);
	Controls.WindowHeader:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_MANAGETRAITS:upper}"));
	Controls.SelectTraitsPanel:SetScrollValue(0);
	Controls.SelectTraitsAlpha:SetToBeginning();
	Controls.SelectTraitsSlide:SetToBeginning();
end

function DoSwapTrait(categoryInfo : table)
	Controls.ConfirmSwap:SetHide(true);
	Controls.TraitsStack:SetHide(true);
	Controls.SelectTraitsPanel:SetHide(false);
	Controls.SelectTraitsAlpha:SetToBeginning();
	Controls.SelectTraitsAlpha:Play();
	Controls.SelectTraitsSlide:SetToBeginning();
	Controls.SelectTraitsSlide:Play();
	Controls.CancelButton:SetHide(false);
	Controls.CancelButton:RegisterCallback(Mouse.eLClick, DoCancelSwap); 
	local cancelText = Controls.CancelButton:GetTextControl();
	Controls.CancelButton:SetSizeX(cancelText:GetSizeX() + 40);
	Controls.CancelAlpha:SetToBeginning();
	Controls.CancelAlpha:Play();
	Controls.CancelSlide:SetToBeginning();
	Controls.CancelSlide:Play();

	local selectTraitOffsetX = 0;
	if(categoryInfo.ID == 2) then
		selectTraitOffsetX = 64 * 2;
	end
	if(categoryInfo.ID == 3) then
		selectTraitOffsetX = 32 * 2;
	end
	Controls.SelectTraitIndicator:SetTextureOffsetVal(selectTraitOffsetX,0);
	Controls.SelectTraitIndicator:SetHide(false);
	Controls.SelectTraitLabel:SetHide(false);
	Controls.WindowHeader:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_SWITCHTRAIT:upper}"));
	Controls.SelectTraitHeaderStack:CalculateSize();
	Controls.SelectTraitHeaderStack:ReprocessAnchoring();
	Controls.HeaderStack:CalculateSize();
	Controls.HeaderStack:ReprocessAnchoring();
	Controls.IndicatorAlpha:SetToBeginning();
	Controls.IndicatorAlpha:Play();
	Controls.IndicatorSlide:SetToBeginning();
	Controls.IndicatorSlide:Play();

	if (categoryInfo == nil) then
		error("Invalid trait category");
	end

	local categoryHeaders = {
		["PERSONALITY_TRAIT_CATEGORY_POLITICAL"] = "TXT_KEY_DIPLOMACYUI_SELECTTRAIT_LABEL_POLITICAL",
		["PERSONALITY_TRAIT_CATEGORY_DOMESTIC"] = "TXT_KEY_DIPLOMACYUI_SELECTTRAIT_LABEL_DOMESTIC",
		["PERSONALITY_TRAIT_CATEGORY_MILITARY"] = "TXT_KEY_DIPLOMACYUI_SELECTTRAIT_LABEL_MILITARY",
	}

	local label = categoryHeaders[categoryInfo.Type];
	if(label == nil) then
		label = Locale.Lookup("TXT_KEY_DIPLOMACYUI_SELECTTRAIT_LABEL", categoryInfo.Description);
	else
		label = Locale.Lookup(label);
	end

	Controls.SelectTraitLabel:SetText(label);
	m_selectTraitsInstanceManager:ResetInstances();

	for traitInfo in GameInfo.PersonalityTraits{TraitCategoryType = categoryInfo.Type} do
		if (not m_player:HasPersonalityTrait(traitInfo.ID)) then
			local instance : table = m_selectTraitsInstanceManager:GetInstance();
			InitPersonalityTraitInstance(instance, m_player:GetID(), traitInfo);
			instance.ChangeButtonCost:SetText(m_player:GetTraitModificationCost());
			instance.ChangeButton:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_SELECT:upper}"));
			local temp : table = traitInfo; -- for lambda capture
			instance.ChangeButton:RegisterCallback(Mouse.eLClick, function() 
				--local traits : table = m_player:GetPersonalityTraits();

				--Network.SendAddPersonalityTrait(m_player:GetID(), temp.ID);

				--DoListTraits();
				local currentTrait : object = m_player:GetPersonalityTraitInCategory(categoryInfo.ID);
				local currentTraitInfo : table = nil;
				if (currentTrait ~= nil) then
					currentTraitInfo = GameInfo.PersonalityTraits[currentTrait:GetType()];
				end

				DoConfirmTraitSwap(currentTraitInfo, temp);
			end);
		end
	end

	Controls.SelectTraitsStack:CalculateSize();
	Controls.SelectTraitsPanel:CalculateInternalSize();
	Controls.SelectTraitsStack:ReprocessAnchoring();
	Controls.SelectTraitsPanel:ReprocessAnchoring();
end

function DoConfirmTraitSwap(oldTraitInfo : table, newTraitInfo : table)
	Controls.ConfirmSwap:SetHide(false);
	Controls.ConfirmSwapAlpha:SetToBeginning();
	Controls.ConfirmSwapAlpha:Play();
	Controls.ConfirmSwapSlide:SetToBeginning();
	Controls.ConfirmSwapSlide:Play();
	local windowSizeY = Controls.WindowContentStack:GetSizeY()+60;
	Controls.ConfirmSwapWindow:SetSizeY(windowSizeY);
	-- HACK: This Window isn't re-anchoring appropriately for its new size, so I'm adding an offset
	local originalWindowSize = 500;
	Controls.ConfirmSwapWindow:SetOffsetY(windowSizeY-500);
	-- *******************************************************************************************

	if (oldTraitInfo ~= nil) then
		m_oldTraitInstance.Content:SetHide(false);
		InitPersonalityTraitInstance(m_oldTraitInstance, m_player:GetID(), oldTraitInfo, true);
		m_oldTraitInstance.ChangeButton:SetHide(true);
		m_oldTraitInstance.CantChange:SetHide(true);
	else
		Controls.Arrow:SetHide(true);
		Controls.LoseUpgradesText:SetHide(true);
		Controls.OldTraitPlaceholder:SetHide(true);
		Controls.ConfirmSwapHeader:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_CONFIRMTRAITSELECT:upper}"));
		Controls.TraitsInstanceStack:CalculateSize();
		Controls.TraitsInstanceStack:ReprocessAnchoring();
		Controls.WindowContentStack:CalculateSize();
		Controls.WindowContentStack:ReprocessAnchoring();
	end
	
	InitPersonalityTraitInstance(m_newTraitInstance, m_player:GetID(), newTraitInfo, true);
	m_newTraitInstance.ChangeButton:SetHide(true);
	m_newTraitInstance.CantChange:SetHide(true);

	Controls.ConfirmSwapCost:SetText(m_player:GetTraitModificationCost());
	local costContainerSizeX = 58;
	Controls.ConfirmSwapCostStack:CalculateSize();
	Controls.ConfirmSwapCostStack:ReprocessAnchoring();
	if((Controls.ConfirmSwapCostStack:GetSizeX()+25)>costContainerSizeX) then
		costContainerSizeX = (Controls.ConfirmSwapCostStack:GetSizeX()+25);
	end
	Controls.ConfirmSwapCostContainer:SetSizeX(costContainerSizeX);

	Controls.ConfirmSwapButton:RegisterCallback(Mouse.eLClick, function() 
				Events.AudioPlay2DSound("AS2D_INTERFACE_SERVICE_GET");
		Controls.DiploDelta:SetText("-"..m_player:GetTraitModificationCost());
		Controls.DiploDeltaSlide:SetToBeginning();
		Controls.DiploDeltaSlide:Play();
		Controls.DiploDeltaContainer:SetSizeX(Controls.DiploDelta:GetSizeX()+10);
		
		Controls.ConfirmSwap:SetHide(true);
		DoCancelSwap();
	
		Network.SendAddPersonalityTrait(m_player:GetID(), newTraitInfo.ID);	
	end);

	Controls.CancelSwapButton:RegisterCallback(Mouse.eLClick, function() 
		Controls.ConfirmSwap:SetHide(true);
	end);
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function OnInitialize(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];

	ContextPtr:BuildInstanceForControl("PersonalityTrait", m_oldTraitInstance, Controls.OldTraitPlaceholder);
	ContextPtr:BuildInstanceForControl("PersonalityTrait", m_newTraitInstance, Controls.NewTraitPlaceholder);

	LuaEvents.DiplomacyUI_StateChanged.Add(OnStateChanged);
	LuaEvents.DiplomacyUI_ResetAnimations.Add(ResetAnimations);
	Events.PersonalityTraitAdded.Add(OnTraitAdded);
	Events.PersonalityTraitRemoved.Add(OnTraitRemoved);
	Events.PersonalityTraitLeveledUp.Add(OnTraitLeveledUp);

	ContextPtr:SetHide(true);
	local screenSizeX, screenSizeY = UIManager:GetScreenSizeVal();
	local paddingFromEdge = 0;
	local headerSize = 78;
	local footerSize = 116;
	local minimumReqHeight = 690;
	-- This is an approximation of the offset that the text should have from the side of the screen
	local offsetMultiplier = .00006*(screenSizeX)-.07;
	if(screenSizeX/screenSizeY > 1.5 and ((screenSizeY-headerSize-footerSize) > minimumReqHeight) and offsetMultiplier > .02) then
		paddingFromEdge = screenSizeX * offsetMultiplier;
		Controls.WindowAlpha:SetAnchor("R,T");
		Controls.WindowAlpha:SetOffsetX((screenSizeX/2)*(-1)+(Controls.MainWindow:GetSizeX()/2)+paddingFromEdge);
		Controls.MainWindow:SetSizeY(screenSizeY-194);
		Controls.SwitchTraitWindow:SetSizeY(screenSizeY-194);
		Controls.SelectTraitsAlpha:SetSizeY(screenSizeY-115);
		Controls.SelectTraitsPanel:SetSizeVal(890,screenSizeY-230);
		Controls.SelectTraitsPanel:CalculateInternalSize();
		Controls.SelectTraitsPanel:ReprocessAnchoring();
	else
		local windowWidth = (screenSizeX - 1024)/2+900;
		Controls.MainWindow:SetSizeX(windowWidth);
		Controls.MainWindowDropShadow:SetSizeX(windowWidth+90);
		Controls.SwitchTraitWindow:SetSizeX(windowWidth);
		Controls.SwitchTraitDropShadow:SetSizeX(windowWidth+90);
		Controls.SelectTraitsPanel:SetSizeVal((windowWidth-10),(screenSizeY-115));
		Controls.ScrollPanelGradient:SetSizeX(windowWidth);
		Controls.CancelAlpha:SetSizeX(windowWidth-10);
		Controls.CancelSlide:SetSizeX(windowWidth-10);
		Controls.ConfirmSwap:SetSizeX(windowWidth);
	end
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
	Events.PersonalityTraitAdded.Remove(OnTraitAdded);
	Events.PersonalityTraitRemoved.Remove(OnTraitRemoved);
	Events.PersonalityTraitLeveledUp.Remove(OnTraitLeveledUp);
	LuaEvents.DiplomacyUI_ResetAnimations.Remove(ResetAnimations);
end
ContextPtr:SetShutdown(OnShutdown)

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function ResetAnimations()
	Controls.WindowAlpha:SetToBeginning();
	Controls.WindowAlpha:Play();
	Controls.WindowSlide:SetToBeginning();
	Controls.WindowSlide:Play();
	DoCancelSwap();
end

function OnStateChanged(state : number, selectedPlayer : number)
	if (state == g_diplomacyUIStates.TRAITS) then
		m_player = Players[Game.GetActivePlayer()];
		m_selectedPlayer = Players[selectedPlayer];
		m_shown = true;
		ContextPtr:SetHide(false);
	else
		if (m_shown) then
			m_shown = false;
			ContextPtr:SetHide(true);
		end
	end
end

function OnTraitAdded(playerType : number, traitType : number)
	UpdateTraits();
end

function OnTraitRemoved(playerType : number, traitType : number)
	UpdateTraits();
end

function OnTraitLeveledUp(playerType : number, traitType : number, level : number)
	UpdateTraits();
end

function ShowServicesForRelationshipLevel(traitInstance : table, traitInfo : table, relationshipLevelType : number) 
	traitInstance.ServiceEntryInstanceManager:ResetInstances();
	
	local hasServices : boolean = false;
	local relationshipLevelTypeStr : string = GameInfo.RelationshipLevels[relationshipLevelType].Type;
	for info : table in GameInfo.PersonalityTraits_ForeignPolicies{PersonalityTraitType = traitInfo.Type} do
		local perkInfo : table = GetPerkInfoForPolicy(info.ForeignPolicyType, relationshipLevelTypeStr);
		local policyInfo : table = GameInfo.ForeignPolicies[info.ForeignPolicyType];
		if (perkInfo ~= nil and policyInfo ~= nil) then
			local serviceInstance : table = traitInstance.ServiceEntryInstanceManager:GetInstance();
			InitServiceEntryInstance(serviceInstance, policyInfo, perkInfo);
			hasServices = true;
		end
	end

	local relationshipInfo : table = GameInfo.RelationshipLevels[relationshipLevelType];
	local relationshipDescription = Locale.Lookup("TXT_KEY_DIPLOMACYUI_OFFER", traitInfo.Description);
	if (hasServices) then
		traitInstance.RelationshipDescription:SetText(relationshipDescription);
		traitInstance.ServicesScrollPanel:SetHide(false);
	else
		traitInstance.RelationshipDescription:SetText(Locale.Lookup("TXT_KEY_DIPLOMACYUI_NOSERVICESAVAIL", relationshipInfo.Description));
		traitInstance.ServicesScrollPanel:SetHide(true);
	end

	traitInstance.ServicesScrollPanel:CalculateInternalSize();
	traitInstance.ServicesScrollPanel:ReprocessAnchoring();
end

function GetPerkInfoForPolicy(policyTypeStr : string, relationshipLevelTypeStr : string) 
	for info : table in GameInfo.ForeignPolicies_Perks{ForeignPolicyType = policyTypeStr, RelationshipLevelType = relationshipLevelTypeStr} do
		return GameInfo.PlayerPerks[info.PlayerPerkType];
	end

	return nil;
end

-------------------------------------------------
-- Initialization
-------------------------------------------------
function InitPersonalityTraitInstance(instance : table, playerType : number, traitInfo : table, isSwap : boolean)
	local owningPlayer : object = Players[playerType];

	if (traitInfo ~= nil) then
		local categoryInfo : table = GameInfo.PersonalityTraitCategories[traitInfo.TraitCategoryType];
		local trait : object = FindTrait(owningPlayer:GetPersonalityTraits(), traitInfo.ID);

		IconHookup( traitInfo.PortraitIndex, 64, traitInfo.IconAtlas, instance.Icon);
		instance.TabRow:SetHide(false);

		-- Init basic info
		instance.Name:SetText(Locale.Lookup(traitInfo.Description));
		instance.CategoryName:SetText(Locale.Lookup("{"..categoryInfo.Description..":upper}"));
		instance.PerksContent:SetHide(false);
		instance.ServicesContent:SetHide(true);

		instance.Tabs = CreateTabs(instance.TabRow, 64, 32);
		instance.Tabs.AddTab(instance.PerksTab, function() 
			instance.PerksContent:SetHide(false);
			instance.ServicesContent:SetHide(true);
		end);
		instance.Tabs.AddTab(instance.ServicesTab, function() 
			instance.PerksContent:SetHide(true);
			instance.ServicesContent:SetHide(false);
		end);
		instance.Tabs.CenterAlignTabs();

		instance.Tabs.SelectTab(instance.PerksTab);

		-- Perks content
		if (instance.m_perkEntryInstanceManager == nil) then
			instance.m_perkEntryInstanceManager = InstanceManager:new("PersonalityTraitLevelEntry", "Content", instance.PerksStack);
		end

		instance.m_perkEntryInstanceManager:ResetInstances();

		for level : number = 1, GameDefines.DIPLO_TRAIT_MAX_LEVELS, 1 do
			local perkInfo : table = FindPerkForTrait(traitInfo, level);
			if (perkInfo ~= nil) then
				local levelInstance : table = instance.m_perkEntryInstanceManager:GetInstance();
				local levelYOffset = 0;
				if (trait ~= nil and not isSwap) then
					levelInstance.Unavailable:SetHide(level <= trait:GetLevel()+1);
					if (level == trait:GetLevel() + 1) then
						levelInstance.Button:SetHide(false);
						local levelCost : number = owningPlayer:GetTraitModificationCost();
						if (trait:CanLevelUp()) then
							levelInstance.Button:SetDisabled(false);
							levelInstance.Button:SetToolTipString(Locale.Lookup("TXT_KEY_LEVEL_UP_FOR_TT", owningPlayer:GetTraitModificationCost()));
							levelYOffset = 45 * 2;
							levelInstance.Description:SetColor(0xff97e5e8,0);
							levelInstance.UpgradeText:SetText(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_UPGRADEFOR:upper}"));
						else
							levelInstance.Button:SetDisabled(true);
							levelInstance.Button:SetToolTipString(Locale.Lookup("{TXT_KEY_DIPLOMACYUI_NOTENOUGH_TT}"));
							levelInstance.Description:SetColor(0xffe4cbb6,0);
							levelInstance.UpgradeText:SetText("");						
						end
						InitTraitLevelEntryInstance(levelInstance, perkInfo, levelCost);
					else
						InitTraitLevelEntryInstance(levelInstance, perkInfo, nil);
						levelInstance.Button:SetHide(true);
						levelInstance.Description:SetColor(0xffe4cbb6,0);
					end

					levelInstance.Button:RegisterCallback(Mouse.eLClick, function() 
						Controls.DiploDelta:SetText("-"..owningPlayer:GetTraitModificationCost());
						Controls.DiploDeltaSlide:SetToBeginning();
						Controls.DiploDeltaSlide:Play();
						Controls.DiploDeltaContainer:SetSizeX(Controls.DiploDelta:GetSizeX()+10);
						Events.AudioPlay2DSound("AS2D_INTERFACE_DIPLOMACY_TRAIT_UP");
						Network.SendLevelUpPersonalityTrait(trait:GetOwner(), trait:GetType());
					end);
				
					if (level < trait:GetLevel()) then
						levelInstance.Unavailable:SetHide(false);
						levelInstance.Unavailable:SetColor(0x77000000);
						levelInstance.Description:SetColor(0x77e4cbb6,0);
						levelInstance.Icon:SetColor(0x77ffffff,0);
					end
				else
					if (trait ~= nil) then
						levelInstance.Unavailable:SetHide(level <= trait:GetLevel());
					else
						levelInstance.Unavailable:SetHide(false);
					end
				
					levelInstance.Button:SetHide(true);
					InitTraitLevelEntryInstance(levelInstance, perkInfo, nil);
				end

				if (not m_player:IsTurnActive()) then
					levelInstance.Button:SetDisabled(true);
				end

				local levelXOffset = (level-1)*66 * 2;
				levelInstance.Icon:SetTextureOffsetVal(levelXOffset, levelYOffset);
			end
		end

		instance.PerksStack:CalculateSize();
		instance.PerksStack:ReprocessAnchoring();

		-- Services content

		-- Set up service instance manager
		if (instance.ServiceEntryInstanceManager == nil) then
			instance.ServiceEntryInstanceManager = InstanceManager:new("ServiceEntry", "Content", instance.ServicesStack);
		end
		instance.ServiceEntryInstanceManager:ResetInstances();
		local hasServices : boolean = false;

		for traitInfo : table in GameInfo.PersonalityTraits_ForeignPolicies{PersonalityTraitType = traitInfo.Type} do
			local policyInfo: table = GameInfo.ForeignPolicies[traitInfo.ForeignPolicyType];
			for serviceInfo : table in GameInfo.ForeignPolicies_Perks{ForeignPolicyType = traitInfo.ForeignPolicyType, RelationshipLevelType = policyInfo.MinRelationshipLevelType} do
				local perkInfo = GameInfo.PlayerPerks[serviceInfo.PlayerPerkType];
				if (perkInfo ~= nil and policyInfo ~= nil) then
					local serviceInstance : table = instance.ServiceEntryInstanceManager:GetInstance();
					InitServiceEntryInstance(serviceInstance, policyInfo, perkInfo);
					hasServices = true;
				end
			end
		end
		local relationshipDescription = Locale.Lookup("{TXT_KEY_DIPLOMACYUI_OFFER, traitInfo.Description}");
		if (hasServices) then
			instance.RelationshipDescription:SetText(relationshipDescription);
			instance.ServicesScrollPanel:SetHide(false);
		else
			instance.ServicesScrollPanel:SetHide(true);
		end
		instance.ServicesScrollPanel:CalculateInternalSize();
		instance.ServicesScrollPanel:ReprocessAnchoring();
		instance.EmptyContent:SetHide(true);
	else
		instance.PerksContent:SetHide(true);
		instance.ServicesContent:SetHide(true);
		instance.TabRow:SetHide(true);
		instance.EmptyContent:SetHide(false);
	end
end

function InitTraitLevelEntryInstance(instance : table, perkInfo : table, levelCost : number)
	instance.Description:SetText(Locale.Lookup(perkInfo.Help));

	if (levelCost ~= nil) then
		instance.CostContainer:SetHide(false);
		instance.Cost:SetHide(false);
		instance.Cost:SetText(levelCost);
	else
		instance.CostContainer:SetHide(true);
		instance.Cost:SetHide(true);	
	end
	instance.CostTextStack:CalculateSize();
	instance.CostTextStack:ReprocessAnchoring();
	instance.CostContainer:SetSizeX(instance.CostTextStack:GetSizeX() + 22);
end

function InitServiceEntryInstance(instance : table, policyInfo : table, perkInfo : table)
	local perkInfoTable : table = {};
	local tooltipString : string = "";
	local indexCtr = 1;
	for foreignPolicies_Perk : table in GameInfo.ForeignPolicies_Perks{ForeignPolicyType = policyInfo.Type} do
		perkInfoTable[indexCtr] = GameInfo.PlayerPerks[foreignPolicies_Perk.PlayerPerkType];		
		if (indexCtr > 1) then
			tooltipString = tooltipString .. "[NEWLINE]";
		end
		tooltipString = tooltipString .. "[ICON_".. foreignPolicies_Perk.RelationshipLevelType.."]" .."[COLOR_".. foreignPolicies_Perk.RelationshipLevelType.."]"
						.. Locale.Lookup("TXT_KEY_AGREEMENT_TT_WHEN", GameInfo.RelationshipLevels[foreignPolicies_Perk.RelationshipLevelType].Description).."[ENDCOLOR]: ".. Locale.Lookup(perkInfoTable[indexCtr].Help);
		indexCtr = indexCtr + 1;
	end

	instance.Content:SetToolTipString(tooltipString);
	instance.Name:SetText(Locale.Lookup(policyInfo.Description));
	instance.Description:SetText(Locale.Lookup(policyInfo.Help));
	instance.CapitalPerTurn:SetText("+".. policyInfo.PerTurnCost .."[ICON_DIPLO_CAPITAL]");
	IconHookup( policyInfo.PortraitIndex, 32, policyInfo.IconAtlas, instance.PolicyIcon);
end
