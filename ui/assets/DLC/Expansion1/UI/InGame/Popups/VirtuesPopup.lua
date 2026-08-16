-------------------------------------------------
-- VirtuesPopup
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("InfoTooltipInclude");

------------------------------------------------
-- Members
------------------------------------------------
local m_PopupInfo = nil;

local g_CategoryColors = 
{
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_MIGHT"].ID] = "[COLOR_VIRTUE_MIGHT]",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_PROSPERITY"].ID] = "[COLOR_VIRTUE_PROSPERITY]",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_KNOWLEDGE"].ID] = "[COLOR_VIRTUE_KNOWLEDGE]",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_INDUSTRY"].ID] = "[COLOR_VIRTUE_INDUSTRY]",
};
local g_DepthColors =
{
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_MODERATE"].ID] = {x=1, y=1, z=1, w=0.5},
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_DEVOTED"].ID] = {x=1, y=1, z=1, w=0.8},
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_EXTREME"].ID] = {x=1, y=1, z=1, w=1},
}

local g_UnavailableVirtueColor = {x=0.5, y=0.5, z=0.5, w=0.65};
local g_AvailableVirtueColor = {x=1, y=1, z=1, w=0.5};
local g_AcquiredVirtueColors = 
{
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_MIGHT"].ID] = {x=1, y=1, z=1, w=1},
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_PROSPERITY"].ID] = {x=1, y=1, z=1, w=1},
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_KNOWLEDGE"].ID] = {x=1, y=1, z=1, w=1},
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_INDUSTRY"].ID] = {x=1, y=1, z=1, w=1},
};

local g_UnacquiredVirtueTexture = "Virtue_Virtue_Off.dds";
local g_AcquiredVirtueTextures =
{
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_MIGHT"].ID] = "Virtue_Virtue_Might.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_PROSPERITY"].ID] = "Virtue_Virtue_Prosperity.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_KNOWLEDGE"].ID] = "Virtue_Virtue_Knowledge.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_INDUSTRY"].ID] = "Virtue_Virtue_Industry.dds",
};

local g_UnacquiredCategoryKickerTextures = 
{
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_MIGHT"].ID] = "Virtue_MightBonus_Off.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_PROSPERITY"].ID] = "Virtue_ProsperityBonus_Off.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_KNOWLEDGE"].ID] = "Virtue_KnowledgeBonus_Off.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_INDUSTRY"].ID] = "Virtue_IndustryBonus_Off.dds",
};
local g_AcquiredCategoryKickerTextures = 
{
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_MIGHT"].ID] = "Virtue_MightBonus_On.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_PROSPERITY"].ID] = "Virtue_ProsperityBonus_On.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_KNOWLEDGE"].ID] = "Virtue_KnowledgeBonus_On.dds",
	[GameInfo.PolicyBranchTypes["POLICY_BRANCH_INDUSTRY"].ID] = "Virtue_IndustryBonus_On.dds",
};

local g_UnacquiredDepthKickerTextures = 
{
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_MODERATE"].ID] = "Virtue_Level1Bonus_Off.dds",
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_DEVOTED"].ID] = "Virtue_Level2Bonus_Off.dds",
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_EXTREME"].ID] = "Virtue_Level3Bonus_Off.dds",
};
local g_AcquiredDepthKickerTextures = 
{
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_MODERATE"].ID] = "Virtue_Level1Bonus_On.dds",
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_DEVOTED"].ID] = "Virtue_Level2Bonus_On.dds",
	[GameInfo.PolicyDepthTypes["POLICY_DEPTH_EXTREME"].ID] = "Virtue_Level3Bonus_On.dds",
};

local g_BaseVirtueXOffset = -1;
local g_BaseVirtueYOffset = 5;
local g_PerVirtueXOffset = 30;
local g_PerVirtueYOffset = 62;
local g_PerDepthYOffset = 182;

local g_FromLineYOffset = 10;
local g_ToLineYOffset = -10;

local g_Shown = false;


-- ===========================================================================
--	Initialization
-- ===========================================================================
function OnPopup(popupInfo)

	if popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_CHOOSEPOLICY then
		-- Stop pop-ups from fighting for you eyes; if a new one is requested and this is up, shutdown this screen.
		if not ContextPtr:IsHidden() and popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TUTORIAL then
			OnClose();
		end
		return;
	end



	m_PopupInfo = popupInfo;

	local isShowRequest = true;

	-- Toggle?
	if ( popupInfo.Data1 == 1 ) and ( ContextPtr:IsHidden() == false ) then
		isShowRequest = false;		
	end

	if isShowRequest then
		-- SHOW
		if (ContextPtr:IsHidden()) then
			ShowWindow();
		end
	else
		-- HIDE
		if (not ContextPtr:IsHidden()) then
			HideWindow();
		end
	end
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

function ShowHideHandler(isHide, isInit)
	if (not isHide) then

		if( not g_Shown ) then
			LuaEvents.HideAllDiploPanels();
			LuaEvents.SubDiploPanelOpen( self );

			Events.BlurStateChange(0);
			print("VirtuesPopup, Blur On");
			Events.SerialEventGameMessagePopupShown(m_PopupInfo);

			-- Clears out any in-progress UI state (like range attack/bombard)
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			UI.ClearSelectedCities();

			UpdateWindow();
			g_Shown = true;			-- Using this flag to prevent circular calls, the ShowHide handler will be called even if the popup is in the correct state i.e. Hide will be called even if it is hidden.
		end

	elseif ( g_Shown ) then

		g_Shown = false;

		UIManager:DequeuePopup( ContextPtr );

		Events.BlurStateChange(1);
		print("VirtuesPopup, Blur Off");
		if (m_PopupInfo ~= nil) then
			Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
		end
		LuaEvents.SubDiploPanelClosed();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function ShowWindow()
	UIManager:QueuePopup( ContextPtr, PopupPriority.InGameUtmost );
end

function HideWindow()
	ContextPtr:SetHide(true);
end

function UpdateWindow()
	local player = Players[Game.GetActivePlayer()];

	Controls.VirtueDepthStack:DestroyAllChildren();
	Controls.VirtueCategoryStack:DestroyAllChildren();

	for depthData in GameInfo.PolicyDepthTypes() do
		AddVirtueDepth(player, Controls.VirtueDepthStack, depthData);
	end

	for categoryData in GameInfo.PolicyBranchTypes() do
		AddVirtueCategory(player, Controls.VirtueCategoryStack, categoryData);
	end

	Controls.VirtueDepthStack:CalculateSize();
	Controls.VirtueDepthStack:ReprocessAnchoring();
	Controls.VirtueCategoryStack:CalculateSize();
	Controls.VirtueCategoryStack:ReprocessAnchoring();

	HideConfirmInteraction();
end
Events.EventPoliciesDirty.Add(UpdateWindow);

function AddVirtueDepth(viewingPlayer, depthStack, depthData)
	local depthControl = {};
	ContextPtr:BuildInstanceForControl("VirtueDepthInstance", depthControl, depthStack);

	-- Kicker progress bar
	local depthVirtuesEarned : number = viewingPlayer:GetNumPoliciesInDepth(depthData.ID);
	local depthVirtuesTotal : number = GetTotalVirtuesInDepth(depthData);
	local depthVirtueDiscount : number = viewingPlayer:GetVirtueDepthKickerRequirementDiscount();
	local sizeYPerVirtue : number = depthControl.BaseBar:GetSizeY() / depthVirtuesTotal;

	local progressBarSize : number = depthVirtuesEarned * sizeYPerVirtue;
	depthControl.ProgressBar:SetSizeY(progressBarSize);
	depthControl.ProgressBar:SetColor(RGBAObjectToABGRHex(g_DepthColors[depthData.ID]));

	-- Kicker brackets
	local previousEndingIndex = 0;
	for tKickerInfo in GameInfo.PolicyDepth_KickerPolicies("PolicyDepthType = \"" .. depthData.Type .. "\" ORDER BY NumNeededInDepth") do
		local policyData : object = GameInfo.Policies[tKickerInfo.PolicyType];
		local numInDepth : number = tKickerInfo.NumNeededInDepth - depthVirtueDiscount;
		local kickerControl = {};
		ContextPtr:BuildInstanceForControl("VirtueDepthKickerInstance", kickerControl, depthControl.BaseBar);
		
		kickerControl.Bracket:SetOffsetY(previousEndingIndex * sizeYPerVirtue);
		kickerControl.Bracket:SetSizeY((numInDepth - previousEndingIndex) * sizeYPerVirtue);
		previousEndingIndex = numInDepth;

		local tooltip = "[COLOR_GREY]" .. Locale.ConvertTextKey(policyData.Description) .. "[ENDCOLOR]";
		tooltip = tooltip .. "[NEWLINE][NEWLINE]";
		tooltip = tooltip .. GetHelpTextForVirtue(policyData.ID);
		kickerControl.KickerIcon:SetToolTipString(tooltip);

		local iconTexture = g_UnacquiredDepthKickerTextures[depthData.ID];
		if (viewingPlayer:HasPolicy(policyData.ID)) then
			iconTexture = g_AcquiredDepthKickerTextures[depthData.ID];
		end
		kickerControl.KickerIcon:SetTexture(iconTexture);
	end
end

function AddVirtueCategory(viewingPlayer, categoryStack, categoryData)
	local categoryControl = {};
	ContextPtr:BuildInstanceForControl("VirtueCategoryInstance", categoryControl, categoryStack);
	local name = g_CategoryColors[categoryData.ID] .. Locale.ConvertTextKey("{" .. categoryData.Description .. ":upper}") .. "[ENDCOLOR]";
	categoryControl.Name:SetText(name);
	categoryControl.Name:SetToolTipString(Locale.ConvertTextKey(categoryData.Help));
	categoryControl.Background:SetTexture(categoryData.BackgroundImage);

	-- Kicker progress bar
	local categoryVirtuesEarned = viewingPlayer:GetNumPoliciesInBranch(categoryData.ID);
	local categoryVirtuesTotal = GetTotalVirtuesInCategory(categoryData);
	local sizeXPerVirtue = categoryControl.BaseBar:GetSizeX() / categoryVirtuesTotal;
	categoryControl.ProgressBar:SetSizeX(categoryVirtuesEarned * sizeXPerVirtue);
	categoryControl.ProgressBar:SetTexture(categoryData.ProgressBarImage);

	-- Kicker brackets
	local previousEndingIndex = 0;
	for tKickerInfo in GameInfo.PolicyBranch_KickerPolicies("PolicyBranchType = \"" .. categoryData.Type .. "\" ORDER BY NumNeededInBranch") do
		local policyData = GameInfo.Policies[tKickerInfo.PolicyType];
		local kickerControl = {};
		ContextPtr:BuildInstanceForControl("VirtueCategoryKickerInstance", kickerControl, categoryControl.BaseBar);

		kickerControl.Bracket:SetOffsetX(previousEndingIndex * sizeXPerVirtue);
		kickerControl.Bracket:SetSizeX((tKickerInfo.NumNeededInBranch - previousEndingIndex) * sizeXPerVirtue);
		previousEndingIndex = tKickerInfo.NumNeededInBranch;

		local tooltip = g_CategoryColors[categoryData.ID] .. Locale.ConvertTextKey(policyData.Description) .. "[ENDCOLOR]";
		tooltip = tooltip .. "[NEWLINE][NEWLINE]";
		tooltip = tooltip .. GetHelpTextForVirtue(policyData.ID);
		kickerControl.KickerIcon:SetToolTipString(tooltip);

		local iconTexture = g_UnacquiredCategoryKickerTextures[categoryData.ID];
		if (viewingPlayer:HasPolicy(policyData.ID)) then
			iconTexture = g_AcquiredCategoryKickerTextures[categoryData.ID];
		end
		kickerControl.KickerIcon:SetTexture(iconTexture);
	end

	-- Prereq lines
	for virtuePrereqData in GameInfo.Policy_PrereqORPolicies() do
		local fromVirtueData = GameInfo.Policies[virtuePrereqData.PrereqPolicy];
		local toVirtueData = GameInfo.Policies[virtuePrereqData.PolicyType];
		if (fromVirtueData ~= nil and toVirtueData ~= nil) then
			if (fromVirtueData.PolicyBranchType == categoryData.Type and toVirtueData.PolicyBranchType == categoryData.Type) then
				AddVirtueLine(viewingPlayer, categoryControl.Background, fromVirtueData, toVirtueData);
			end
		else
			print("SCRIPTING ERROR: Could not find corresponding database entries when drawing line from " .. virtuePrereqData.PrereqPolicy .. " to " .. virtuePrereqData.PolicyType);
		end
	end

	-- Virtue buttons
	for virtueData in GameInfo.Policies() do
		if (not Game.IsKickerPolicy(virtueData.ID)) then
			if (virtueData.PolicyBranchType == categoryData.Type) then
				if (virtueData.Type == categoryData.FreeFinishingPolicy) then
					-- Don't draw free finishers
				elseif (virtueData.Type == categoryData.FreePolicy) then
					-- Openers are a special case, as they unlock the whole category for us
					AddVirtueRootButton(viewingPlayer, categoryControl.Background, virtueData, categoryData);
				else
					-- Regular virtues
					AddVirtueButton(viewingPlayer, categoryControl.Background, virtueData, categoryData);
				end
			end
		end
	end
end

function AddVirtueLine(viewingPlayer, parent, fromVirtueData, toVirtueData)
	local lineControl = {};
	ContextPtr:BuildInstanceForControl("VirtueLineInstance", lineControl, parent);
	if (fromVirtueData.GridX ~= toVirtueData.GridX) then
		lineControl.MainLine:SetWidth(lineControl.MainLine:GetWidth() * 1.5);
	end

	local fromCoordinates = GetVirtueCoordinates(fromVirtueData);
	local toCoordinates = GetVirtueCoordinates(toVirtueData);

	fromCoordinates.y = fromCoordinates.y + g_FromLineYOffset;
	toCoordinates.y = toCoordinates.y + g_ToLineYOffset;
	local shiftX = lineControl.MainLine:GetWidth() / 2;

	lineControl.MainLine:SetStartVal(fromCoordinates.x, fromCoordinates.y);
	lineControl.MainLine:SetEndVal(toCoordinates.x, toCoordinates.y);
	lineControl.LeftLine:SetStartVal(fromCoordinates.x - shiftX, fromCoordinates.y);
	lineControl.LeftLine:SetEndVal(toCoordinates.x - shiftX, toCoordinates.y);
	lineControl.RightLine:SetStartVal(fromCoordinates.x + shiftX, fromCoordinates.y);
	lineControl.RightLine:SetEndVal(toCoordinates.x + shiftX, toCoordinates.y);

	return lineControl;
end

function AddVirtueRootButton(viewingPlayer, parent, virtueData, categoryData)
	local virtueControl = {};
	ContextPtr:BuildInstanceForControl("VirtueButtonInstance", virtueControl, parent);
	IconHookup(virtueData.PortraitIndex, 64, virtueData.IconAtlas, virtueControl.VirtueIcon);

	local coordinates = GetVirtueCoordinates(virtueData);
	virtueControl.VirtueButton:SetOffsetVal(coordinates.x, coordinates.y);

	local tooltip = g_CategoryColors[categoryData.ID] .. Locale.ConvertTextKey(virtueData.Description) .. "[ENDCOLOR][NEWLINE][NEWLINE]" .. GetHelpTextForVirtue(virtueData.ID);
	local color = g_UnavailableVirtueColor;
	local texture = g_UnacquiredVirtueTexture;
	if (viewingPlayer:IsPolicyBranchUnlocked(categoryData.ID)) then
		color = g_AcquiredVirtueColors[categoryData.ID];
		texture = g_AcquiredVirtueTextures[categoryData.ID];
	elseif (viewingPlayer:CanUnlockPolicyBranch(categoryData.ID)) then
		color = g_AvailableVirtueColor;
	end
	virtueControl.VirtueIcon:SetColor(RGBAObjectToABGRHex(color));

	virtueControl.VirtueButton:SetTexture(texture);
	virtueControl.VirtueButton:SetToolTipString(tooltip);
	virtueControl.VirtueButton:SetVoid1(categoryData.ID);
	virtueControl.VirtueButton:RegisterCallback(Mouse.eLClick, OnVirtueRootClicked);
	virtueControl.VirtueButton:RegisterCallback(Mouse.eRClick, function()
		local searchString = Locale.ConvertTextKey(virtueData.Description);
		Events.SearchForPediaEntry(searchString);
	end);
			
	return virtueControl;
end

function AddVirtueButton(viewingPlayer, parent, virtueData, categoryData)
	local virtueControl = {};
	ContextPtr:BuildInstanceForControl("VirtueButtonInstance", virtueControl, parent);
	IconHookup(virtueData.PortraitIndex, 64, virtueData.IconAtlas, virtueControl.VirtueIcon);

	local coordinates = GetVirtueCoordinates(virtueData);
	virtueControl.VirtueButton:SetOffsetVal(coordinates.x, coordinates.y);

	local tooltip = g_CategoryColors[categoryData.ID] .. Locale.ConvertTextKey(virtueData.Description) .. "[ENDCOLOR][NEWLINE][NEWLINE]" .. GetHelpTextForVirtue(virtueData.ID);
	local color = g_UnavailableVirtueColor;
	local texture = g_UnacquiredVirtueTexture;
	if (viewingPlayer:HasPolicy(virtueData.ID)) then
		color = g_AcquiredVirtueColors[categoryData.ID];
		texture = g_AcquiredVirtueTextures[categoryData.ID];
	elseif (viewingPlayer:CanAdoptPolicy(virtueData.ID)) then
		color = g_AvailableVirtueColor;
	end
	virtueControl.VirtueIcon:SetColor(RGBAObjectToABGRHex(color));

	virtueControl.VirtueButton:SetTexture(texture);
	virtueControl.VirtueButton:SetToolTipString(tooltip);
	virtueControl.VirtueButton:SetVoid1(virtueData.ID);
	virtueControl.VirtueButton:RegisterCallback(Mouse.eLClick, OnVirtueClicked);
	virtueControl.VirtueButton:RegisterCallback(Mouse.eRClick, function()
		local searchString = Locale.ConvertTextKey(virtueData.Description);
		Events.SearchForPediaEntry(searchString);
	end);
			
	return virtueControl;
end

------------------------------------------------
-- Helpers
------------------------------------------------
function GetVirtueCoordinates(virtueData)
	local depthGridY = 0;
	local depthData = GameInfo.PolicyDepthTypes[virtueData.PolicyDepthType];
	if (depthData ~= nil) then
		depthGridY = depthData.ID * g_PerDepthYOffset;
	end

	local x = g_BaseVirtueXOffset + (virtueData.GridX * g_PerVirtueXOffset);
	local y = g_BaseVirtueYOffset + depthGridY + (virtueData.GridY * g_PerVirtueYOffset);

	local coord = {["x"] = x, ["y"] = y};
	return coord;
end

function GetTotalVirtuesInDepth(depthData)
	local count = 0;
	for policyData in GameInfo.Policies("PolicyDepthType = \"" .. depthData.Type .. "\"") do
		if (not Game.IsKickerPolicy(policyData.ID)) then
			count = count + 1;
		end
	end
	return count;
end

function GetTotalVirtuesInCategory(categoryData)
	local count = 0;
	for policyData in GameInfo.Policies("PolicyBranchType = \"" .. categoryData.Type .. "\"") do
		if (not Game.IsKickerPolicy(policyData.ID)) then
			count = count + 1;
		end
	end
	return count;
end

---------------------------------------------------------------------------------------
function ComposeKickerProgressText(player : object, policyToAdoptID : number)
	local s = "";
	local policyToAdoptData = GameInfo.Policies[policyToAdoptID];
	local breadthKickerDiscount : number = player:GetVirtueBreadthKickerRequirementDiscount();
	local depthKickerDiscount : number = player:GetVirtueDepthKickerRequirementDiscount();

	-- Category kicker
	local categoryKickerData = nil;
	local neededInCategory = nil;
	local categoryData = GameInfo.PolicyBranchTypes[policyToAdoptData.PolicyBranchType];
	local ownedInCategory = player:GetNumPoliciesInBranch(categoryData.ID);
	for tKickerInfo in GameInfo.PolicyBranch_KickerPolicies("PolicyBranchType = \"" .. policyToAdoptData.PolicyBranchType .. "\" ORDER BY NumNeededInBranch") do
		local totalNumNeeded : number = tKickerInfo.NumNeededInBranch - breadthKickerDiscount;
		if (ownedInCategory < totalNumNeeded) then
			categoryKickerData = GameInfo.Policies[tKickerInfo.PolicyType];
			neededInCategory = totalNumNeeded;
			break;
		end
	end

	-- Depth kicker
	local depthKickerData = nil;
	local neededInDepth = nil;
	local depthData = GameInfo.PolicyDepthTypes[policyToAdoptData.PolicyDepthType];
	local ownedInDepth = player:GetNumPoliciesInDepth(depthData.ID);
	for tKickerInfo in GameInfo.PolicyDepth_KickerPolicies("PolicyDepthType = \"" .. policyToAdoptData.PolicyDepthType .. "\" ORDER BY NumNeededInDepth") do
		local totalNumNeeded : number = tKickerInfo.NumNeededInDepth - depthKickerDiscount;
		if (ownedInDepth < totalNumNeeded) then
			depthKickerData = GameInfo.Policies[tKickerInfo.PolicyType];
			neededInDepth = totalNumNeeded;
			break;
		end
	end

	if (categoryKickerData ~= nil and neededInCategory ~= nil) then
		local remainingInCategory = neededInCategory - (ownedInCategory + 1);
		if (remainingInCategory <= 0) then
			s = s .. Locale.ConvertTextKey("TXT_KEY_VIRTUES_POPUP_CONFIRM_PROMPT_CATEGORY_KICKER_EARNED"
										, g_CategoryColors[categoryData.ID], categoryData.Description, GetHelpTextForVirtue(categoryKickerData.ID));
		else
			s = s .. Locale.ConvertTextKey("TXT_KEY_VIRTUES_POPUP_CONFIRM_PROMPT_CATEGORY_KICKER_PROGRESS"
										, g_CategoryColors[categoryData.ID], categoryData.Description, GetHelpTextForVirtue(categoryKickerData.ID), remainingInCategory);
		end
	end

	if (depthKickerData ~= nil and neededInDepth ~= nil) then
		if (s ~= "") then
			s = s .. "[NEWLINE][NEWLINE]";
		end
		local remainingInDepth = neededInDepth - (ownedInDepth + 1);
		if (remainingInDepth <= 0) then
			s = s .. Locale.ConvertTextKey("TXT_KEY_VIRTUES_POPUP_CONFIRM_PROMPT_DEPTH_KICKER_EARNED"
										, "[COLOR_GREY]", depthData.Description, GetHelpTextForVirtue(depthKickerData.ID));
		else
			s = s .. Locale.ConvertTextKey("TXT_KEY_VIRTUES_POPUP_CONFIRM_PROMPT_DEPTH_KICKER_PROGRESS"
										, "[COLOR_GREY]", depthData.Description, GetHelpTextForVirtue(depthKickerData.ID), remainingInDepth);
		end
	end

	return s;
end

------------------------------------------------
-- Interaction
------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
			if (not Controls.ConfirmPopup:IsHidden()) then
				Controls.ConfirmPopup:SetHide(true);
			else
				OnClose();
			end
            return true;
        end
    end
end
ContextPtr:SetInputHandler(InputHandler);

function OnVirtueRootClicked(categoryID)
	local player = Players[Game.GetActivePlayer()];
	if (player:CanUnlockPolicyBranch(categoryID) and not player:IsPolicyBranchUnlocked(categoryID)) then
		local policy = GameInfo.Policies[GameInfo.PolicyBranchTypes[categoryID].FreePolicy];
		local confirmText = Locale.ConvertTextKey("TXT_KEY_VIRTUES_POPUP_CONFIRM_PROMPT", g_CategoryColors[categoryID], policy.Description);
		confirmText = confirmText .. "[NEWLINE]" .. GetHelpTextForVirtue(policy.ID);
		local kickerText = ComposeKickerProgressText(player, policy.ID);
		ShowConfirmInteraction(confirmText, kickerText, function()
			local regularVirtue = false;
			Network.SendUpdatePolicies(categoryID, regularVirtue, true);
			Events.AudioPlay2DSound("AS2D_INTERFACE_POLICY_CONFIRM");
		end);
	end
end

function OnVirtueClicked(virtueID)
	local player = Players[Game.GetActivePlayer()];
	if (player:CanAdoptPolicy(virtueID) and not player:HasPolicy(virtueID)) then
		local policy = GameInfo.Policies[virtueID];
		local categoryID = GameInfo.PolicyBranchTypes[policy.PolicyBranchType].ID;
		local confirmText = Locale.ConvertTextKey("TXT_KEY_VIRTUES_POPUP_CONFIRM_PROMPT", g_CategoryColors[categoryID], policy.Description);
		confirmText = confirmText .. "[NEWLINE]" .. GetHelpTextForVirtue(policy.ID);
		local kickerText = ComposeKickerProgressText(player, policy.ID);
		ShowConfirmInteraction(confirmText, kickerText, function()
			local regularVirtue = true;
			Network.SendUpdatePolicies(virtueID, regularVirtue, true);
			Events.AudioPlay2DSound("AS2D_INTERFACE_POLICY_CONFIRM");
		end);
	end
end

function ShowConfirmInteraction(confirmText, kickerText, confirmHandler)
	Controls.ConfirmPopup:SetHide(false);
	Controls.ConfirmLabel:SetText(confirmText);
	Controls.KickerLabel:SetText(kickerText);
	
	Controls.MainBodyText:CalculateSize();
	Controls.MainBodyText:ReprocessAnchoring();

	local bodyTextHeight = Controls.MainBodyText:GetSizeY();
	if (bodyTextHeight > Controls.PopupWindow:GetSizeY() - 200 ) then
		Controls.PopupWindow:SetSizeY( bodyTextHeight +  Controls.ButtonStack:GetOffsetY() + 120 );
	else
		Controls.PopupWindow:SetSizeY(800);
	end

	Controls.YesButton:RegisterCallback(Mouse.eLClick, function()
		confirmHandler();
		HideConfirmInteraction();
	end);
	Controls.NoButton:RegisterCallback(Mouse.eLClick, function()
		HideConfirmInteraction();
	end);
end

function HideConfirmInteraction()
	Controls.ConfirmPopup:SetHide(true);
end

function OnClose()
	HideWindow();
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnVirturesActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		HideWindow();
	end
end
Events.GameplaySetActivePlayer.Add(OnVirturesActivePlayerChanged);
