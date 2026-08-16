-------------------------------------------------
-- ReligionOverview
-------------------------------------------------
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");

------------------------------------------------
-- Members
------------------------------------------------

------------------------------------------------
-- Initialization
------------------------------------------------
function OnPopup(popupInfo)
	-- Removed for CivBE
	return;
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

function ShowHideHandler(isHide)
	if (not isHide) then
		UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function UpdateWindow()
	local player = Players[Game.GetActivePlayer()];

	BuildPlayerBeliefs(player);
	BuildAvailableBeliefs(player);
	HideConfirmInteraction();
end
Events.SerialEventGameDataDirty.Add(UpdateWindow);

function BuildPlayerBeliefs(player)
	Controls.PlayerBeliefsStack:DestroyAllChildren();

	-- Name
	Controls.PlayerBeliefsLabel:SetText("My Beliefs");

	-- Acquired Beliefs
	local playerBeliefs = Game.GetBeliefsAcquiredByPlayer(player:GetID());
	for i, beliefID in ipairs(playerBeliefs) do
		local beliefInfo = GameInfo.Beliefs[beliefID];
		local control = {};
		ContextPtr:BuildInstanceForControl("AcquiredBeliefSlotInstance", control, Controls.PlayerBeliefsStack);
		control.Name:LocalizeAndSetText(beliefInfo.ShortDescription);
		control.Description:LocalizeAndSetText(beliefInfo.Description);
	end

	-- Another Belief Available?
	if (Game.CanAcquireAnyBelief(player:GetID())) then
		local control = {};
		ContextPtr:BuildInstanceForControl("NewBeliefSlotInstance", control, Controls.PlayerBeliefsStack);
		control.Name:SetText("Choose New Belief");
	end

	Controls.PlayerBeliefsStack:CalculateSize();
	Controls.PlayerBeliefsStack:ReprocessAnchoring();
	Controls.PlayerBeliefsScrollPanel:CalculateInternalSize();
end

function BuildAvailableBeliefs(player)
	Controls.AvailableBeliefsStack:DestroyAllChildren();

	-- Name
	Controls.AvailableBeliefsLabel:SetText("Available Beliefs");

	-- Available Beliefs
	local availableBeliefs = {};
	for i,v in ipairs(Game.GetAvailableBeliefs()) do
		local belief = GameInfo.Beliefs[v];
		if (belief ~= nil) then
			table.insert(availableBeliefs, {
				ID = belief.ID,
				Name = Locale.Lookup(belief.ShortDescription),
				Description = Locale.Lookup(belief.Description),
				Cost = Game.GetFaithNeededForBelief(iPlayer, belief.ID),
			});
		end
	end
	table.sort(availableBeliefs, function(a,b) return CompareBeliefs(a,b); end);
	for i, beliefTable in ipairs(availableBeliefs) do
		local control = {};
		ContextPtr:BuildInstanceForControl("AvailableBeliefInstance", control, Controls.AvailableBeliefsStack);
		control.Name:SetText(beliefTable.Name);
		control.Description:SetText(beliefTable.Description);

		if (Game.CanAcquireBelief(player:GetID(), beliefTable.ID)) then
			control.Cost:SetText(beliefTable.Cost .. " [ICON_PEACE]");
			control.Button:RegisterCallback(Mouse.eLClick, function() SelectBelief(player:GetID(), beliefTable); end);
		else
			control.Cost:SetText("[COLOR_GREY]" .. beliefTable.Cost .. "[ENDCOLOR] [ICON_PEACE]");
		end
	end

	Controls.AvailableBeliefsStack:CalculateSize();
	Controls.AvailableBeliefsStack:ReprocessAnchoring();
	Controls.BeliefCategoriesScrollPanel:CalculateInternalSize();
end

------------------------------------------------
-- Helpers
------------------------------------------------
function CompareBeliefs(a, b)
	if (a.Cost ~= b.Cost) then
		return a.Cost < b.Cost;
	end
	return Locale.Compare(a.Name, b.Name) < 0;
end

------------------------------------------------
-- Interaction
------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose();
            return true;
        end
    end
end
ContextPtr:SetInputHandler(InputHandler);

function SelectBelief(playerID, beliefTable)
	local prompt = "Purchase [COLOR_POSITIVE_TEXT]" .. beliefTable.Name .. "[ENDCOLOR] for [ICON_PEACE]" .. beliefTable.Cost.. "?[NEWLINE][NEWLINE]" .. beliefTable.Description;
	ShowConfirmInteraction(prompt, function()
		Network.SendAcquireBelief(playerID, beliefTable.ID);
		Events.AudioPlay2DSound("AS2D_INTERFACE_RELIGION_CONFIRM");
	end);
end

function ShowConfirmInteraction(promptText, confirmHandler)
	Controls.ConfirmPopup:SetHide(false);
	Controls.ConfirmLabel:SetText(promptText);
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
	ContextPtr:SetHide(true);
	--[[
	ContextPtr:LookUpControl("/InGame/WorldView/DiploCorner/VirtuesTail"):SetHide(true);
	ContextPtr:LookUpControl("/InGame/WorldView/DiploCorner/ButtonDimmer"):SetHide(true);	
	LuaEvents.SubDiploPanelClosed();
	--]]
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);