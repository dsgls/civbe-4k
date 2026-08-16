-------------------------------------------------
-- Agreements Overview
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");

local m_shown : boolean = false;
local m_player : object = nil;
local m_selectedPlayer : object = nil;

local m_agreementInstanceManager : table = InstanceManager:new("AgreementInstance", "Content", Controls.AgreementsStack);

-------------------------------------------------
-- Init and boiler-plate
-------------------------------------------------
function OnShowAgreementsOverview(player : object, selectedPlayer : object)
	-- WRM: Work-around for hotloading bug
	if (Players == nil) then
		return;
	end

	m_player = player;
	m_selectedPlayer = selectedPlayer;

	ContextPtr:SetHide(false);
end
LuaEvents.ShowAgreementsOverview.Add(OnShowAgreementsOverview);

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

	-- Build agreements list
	m_agreementInstanceManager:ResetInstances();
	local agreements : table = Game.GetAgreementsWithPlayers(m_player:GetID(), m_selectedPlayer:GetID());
	for i : number, agreement : object in ipairs(agreements) do
		if (not agreement:IsCanceled()) then
			local instance : table = m_agreementInstanceManager:GetInstance();

			InitAgreementInstance(instance, agreement);

			instance.CancelAgreementButton:RegisterCallback(Mouse.eLClick, function() 
				Network.SendCancelAgreement(agreement:GetID(), m_player:GetID());
			end);
		end
	end

	Controls.AgreementsStack:CalculateSize();
	Controls.AgreementsStack:ReprocessAnchoring();
end
Events.DiplomacyAgreementCanceled.Add(UpdateWindow);

function InitAgreementInstance(instance : table, agreement : object)
	local policyType : number = agreement:GetForeignPolicy();
	local policyInfo : table = GameInfo.ForeignPolicies[policyType];

	if (policyInfo ~= nil) then
		instance.MyPolicyIcon:SetHide(false);
		IconHookup(policyInfo.PortraitIndex, 64, policyInfo.IconAtlas, instance.MyPolicyIcon);
	
		if (instance.MyPolicyName ~= nil) then
			instance.MyPolicyName:SetHide(false);
			instance.MyPolicyName:SetText(Locale.Lookup(policyInfo.Description));
		end

		if (instance.MyPolicyDescription ~= nil) then
			instance.MyPolicyDescription:SetHide(false);
			instance.MyPolicyDescription:SetText(Locale.Lookup(policyInfo.Help));
		end
	else
		instance.MyPolicyIcon:SetHide(true);
	
		if (instance.MyPolicyName ~= nil) then
			instance.MyPolicyName:SetHide(true);
		end

		if (instance.MyPolicyDescription ~= nil) then
			instance.MyPolicyDescription:SetHide(true);
		end
	end

	instance.TheirPolicyIcon:SetHide(true);
	
	if (instance.TheirPolicyName ~= nil) then
		instance.TheirPolicyName:SetHide(true);
	end

	if (instance.TheirPolicyDescription ~= nil) then
		instance.TheirPolicyDescription:SetHide(true);
	end

	
end

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function OnClose()
	ContextPtr:SetHide(true);
end
Controls.CancelButton:RegisterCallback(Mouse.eLClick, OnClose);