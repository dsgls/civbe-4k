-------------------------------------------------
-- Agreement Builder
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");

local m_player : object = nil;
local m_selectedPlayer : object = nil;
local m_selectedPolicyInfo : table = nil;
local m_selectedPolicyInstance : table = nil;

local m_policyInstanceManager : table = InstanceManager:new("PolicyItem", "Content", Controls.PoliciesStack);
local m_perkInstanceManager : table = InstanceManager:new("PerkItem", "Content", Controls.SelectedPolicy_Stack);

--[[
local m_relationshipLevelToolTips : table =
{
};]]

-------------------------------------------------
-- Init and boiler-plate
-------------------------------------------------
function OnShowAgreementBuilder(selectedPlayer : object)
	-- WRM: Work-around for hotloading bug
	if (Players == nil) then
		return;
	end

	m_player = Players[Game.GetActivePlayer()];
	m_selectedPlayer = selectedPlayer;
	m_selectedPolicyInfo = nil;
	m_selectedPolicyInstance = nil;

	ContextPtr:SetHide(false);
end
LuaEvents.ShowAgreementBuilder.Add(OnShowAgreementBuilder);

function ShowHideHandler(isHide : boolean)
	if (not isHide) then
		-- WRM: Work-around for hotloading bug
		if (Players == nil) then
			return;
		end

		UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function InputHandler(msg, wParam, lParam)
	if (msg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE) then
			OnAgreementBuilderCancel();
		end
	end

	return true;
end
ContextPtr:SetInputHandler(InputHandler);

-------------------------------------------------
-- Update
-------------------------------------------------
function UpdateWindow()
	if (m_player == nil or m_selectedPlayer == nil) then
		return;
	end

	Controls.SlideAnim:SetToBeginning();
	Controls.SlideAnim:Play();
	Controls.AlphaAnim:SetToBeginning();
	Controls.AlphaAnim:Play();

	m_selectedPolicyInfo = nil;
	m_selectedPolicyInstance = nil;

	m_policyInstanceManager:ResetInstances();
	m_perkInstanceManager:ResetInstances();

	local foreignPolicyTypes : table = m_selectedPlayer:GetForeignPolicies();
	for i : number, policyType : number in ipairs(foreignPolicyTypes) do
		local policyInfo : table = GameInfo.ForeignPolicies[policyType];

		local instance : table = m_policyInstanceManager:GetInstance();
		InitPolicyEntryInstance(instance, policyInfo);

		instance.Button:RegisterCallback(Mouse.eLClick, function() 
			if (m_selectedPolicyInstance ~= nil) then
				m_selectedPolicyInstance.SelectedHighlight:SetHide(true);
			end
			
			m_selectedPolicyInfo = policyInfo;
			m_selectedPolicyInstance = instance;
			m_selectedPolicyInstance.SelectedHighlight:SetHide(false);

			UpdateSelectedPolicyContent();
		end);
	end

	Controls.PoliciesStack:CalculateSize();
	Controls.PoliciesStack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();

	UpdateSelectedPolicyContent();
end

function UpdateSelectedPolicyContent()
	m_perkInstanceManager:ResetInstances();

	if (m_selectedPolicyInfo ~= nil) then
		Controls.SelectedPolicyContent:SetHide(false);

		IconHookup(m_selectedPolicyInfo.PortraitIndex, 64, m_selectedPolicyInfo.IconAtlas, Controls.SelectedPolicy_Icon);
		Controls.SelectedPolicy_Name:SetText(Locale.Lookup(m_selectedPolicyInfo.Description));
	
		for relationshipLevelInfo : table in GameInfo.RelationshipLevels() do
			local instance : table = m_perkInstanceManager:GetInstance();
			local perkInfo : table = nil;

			InitPerkInstance(instance, perkInfo, relationshipLevelInfo.ID);
		end

		Controls.SelectedPolicy_Stack:CalculateSize();
		Controls.SelectedPolicy_Stack:ReprocessAnchoring();
	else
		Controls.SelectedPolicyContent:SetHide(true);
	end
end

function InitPolicyEntryInstance(instance : table, policyInfo : table)
	if (policyInfo ~= nil) then
		instance.Icon:SetHide(false);
		IconHookup(policyInfo.PortraitIndex, 64, policyInfo.IconAtlas, instance.Icon);

		instance.Name:SetHide(false);
		instance.Name:SetText(Locale.Lookup(policyInfo.Description));

		instance.Description:SetHide(false);
		instance.Description:SetText(Locale.Lookup(policyInfo.Help));
		
		instance.NoPolicy:SetHide(true);
	else
		instance.Icon:SetHide(true);
		instance.Name:SetHide(true);
		instance.Description:SetHide(true);
		instance.NoPolicy:SetHide(false);
	end

	if (instance.SelectedHighlight ~= nil) then
		instance.SelectedHighlight:SetHide(true);
	end
end

function InitPerkInstance(instance : table, perkInfo : table, perkRelationshipLevel : number)
	if (perkInfo ~= nil) then
		instance.Description:SetText(locale.Lookup(perkInfo.Help));
	else
		instance.Description:SetText("$No Perk Set$");
	end

	local relationshipLevel : number = m_player:GetRelationship(m_selectedPlayer:GetID());
	instance.Highlight:SetHide(relationshipLevel ~= perkRelationshipLevel);
end

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function OnAgreementBuilderCancel()
	ContextPtr:SetHide(true);
end
Controls.CancelButton:RegisterCallback(Mouse.eLClick, OnAgreementBuilderCancel);

function OnAgreementBuilderPropose()
	if (m_player == nil or m_selectedPlayer == nil) then
		error("Invalid state");
	end

	if (m_selectedPolicyInfo == nil) then
		error("No policy selected");
	end

	Network.SendCreateAgreement(m_player:GetID(), m_selectedPlayer:GetID(), m_selectedPolicyInfo.ID);

	ContextPtr:SetHide(true);
end
Controls.ProposeButton:RegisterCallback(Mouse.eLClick, OnAgreementBuilderPropose);