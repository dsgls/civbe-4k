-------------------------------------------------
-- Artifacts Overview Popup
-------------------------------------------------
include( "IconSupport" );
include( "InstanceManager" );

local m_popupInfo : table = nil;
local m_player : object = nil;
local m_perksHeaderOpen : boolean = true;
local m_buildingsHeaderOpen : boolean = true;
local m_wondersHeaderOpen : boolean = true;

local g_earnedPerksInstanceManager = InstanceManager:new("PerkInstance", "Header", Controls.PerksStack);
local g_earnedBuildingsInstanceManager = InstanceManager:new("BuildingInstance", "Header", Controls.BuildingsStack);
local g_earnedWondersInstanceManager = InstanceManager:new("BuildingInstance", "Header", Controls.WondersStack);
local g_noPerksInstanceManager = InstanceManager:new("NoneInstance", "None", Controls.PerksStack);
local g_noBuildingsInstanceManager = InstanceManager:new("NoneInstance", "None", Controls.BuildingsStack);
local g_noWondersInstanceManager = InstanceManager:new("NoneInstance", "None", Controls.WondersStack);

-------------------------------------------------
--Initialize the window
-------------------------------------------------
function OnPopup(popupInfo : table)
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_ARTIFACTS_OVERVIEW) then
		return;
	end

	m_popupInfo = popupInfo;

	if (m_popupInfo.Data1 == 1) then
		if (not ContextPtr:IsHidden()) then
			OnClose();
		else
			UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
		end
	else
		UIManager:QueuePopup(ContextPtr, PopupPriority.ArtifactsOverview);
	end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );
-------------------------------------------------------------------------------
function OnShutdown()
	-- Unregister events
	Events.SerialEventGameMessagePopup.Remove(OnPopup);
end
ContextPtr:SetShutdown(OnShutdown);
-------------------------------------------------------------------------------
function OnClose()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose);
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );
-------------------------------------------------------------------------------
function ShowHideHandler(isHide: boolean)
	if (not isHide) then
		Controls.AlphaAnim:SetToBeginning();
		Controls.AlphaAnim:Play();

		m_player = Players[Game.GetActivePlayer()];
		UpdateScreen();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnClose);

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function OnPerksHeaderSelected()
	m_perksHeaderOpen = not m_perksHeaderOpen;
	UpdateScreen();
end

function OnBuildingsHeaderSelected()
	m_buildingsHeaderOpen = not m_buildingsHeaderOpen;
	UpdateScreen();
end

function OnWondersHeaderSelected()
	m_wondersHeaderOpen = not m_wondersHeaderOpen;
	UpdateScreen();
end

function UpdateScreen()
	----
	local debug : boolean = false;
	----

	-- Reset All
	g_earnedPerksInstanceManager:ResetInstances();
	g_earnedBuildingsInstanceManager:ResetInstances();
	g_earnedWondersInstanceManager:ResetInstances();
	g_noPerksInstanceManager:ResetInstances();
	g_noBuildingsInstanceManager:ResetInstances();
	g_noWondersInstanceManager:ResetInstances();

	local noPerks : boolean = true;
	local noBuildings : boolean = true;
	local noWonders : boolean = true;

	-- Populate Artifact Rewards
	for row in GameInfo.ArtifactRewards() do
		if (m_player:HasRecievedArtifactReward(row.ID) or debug) then
			-- Perk
			if (row.PlayerPerkReward ~= nil or row.PromotionReward ~= nil) then
				local instance = g_earnedPerksInstanceManager:GetInstance();
				instance.Title:SetText(Locale.Lookup(row.Description));
				instance.Effects:SetText(Locale.Lookup(row.EffectsSummary));
				noPerks = false;
		
			-- Building / Wonder
			elseif (row.BuildingReward ~= nil) then			
				local buildingInfo = GameInfo.Buildings[row.BuildingReward];
				local buildingClassInfo = GameInfo.BuildingClasses[buildingInfo.BuildingClass];
				local instance = nil;
				if buildingClassInfo.MaxGlobalInstances > 0 or buildingClassInfo.MaxPlayerInstances == 1 or buildingClassInfo.MaxTeamInstances > 0 then
					-- Wonder
					instance = g_earnedWondersInstanceManager:GetInstance();
					noWonders = false;
				else				
					-- Building
					instance = g_earnedBuildingsInstanceManager:GetInstance();
					noBuildings = false;
				end

				if (instance ~= nil) then
					if (buildingInfo ~= nil) then
						instance.Title:SetText(Locale.Lookup(buildingInfo.Description));
						instance.Effects:SetText(Locale.Lookup(row.EffectsSummary));
					end
					-- Portrait
					local textureOffset, textureSheet = IconLookup( buildingInfo.PortraitIndex, 64, buildingInfo.IconAtlas );
					if textureSheet ~= nil and textureOffset ~= nil then
						instance.BuildingImage:SetTexture(textureSheet);
						instance.BuildingImage:SetTextureOffset(textureOffset);
					end
				end
			end

		end
	end

	-- Handle empty categories
	if (noPerks) then
		local instance = g_noPerksInstanceManager:GetInstance();
	end
	if (noBuildings) then
		local instance = g_noBuildingsInstanceManager:GetInstance();
	end
	if (noWonders) then
		local instance = g_noWondersInstanceManager:GetInstance();
	end

	-- Handle section hiding and showing
	if (m_perksHeaderOpen) then
		Controls.PerksPlus:SetText("[ICON_MINUS]");
		Controls.PerksStack:SetHide(false);
	else
		Controls.PerksPlus:SetText("[ICON_PLUS]");
		Controls.PerksStack:SetHide(true);
	end
	Controls.PerksButton:RegisterCallback( Mouse.eLClick, OnPerksHeaderSelected );

	-- Handle section hiding and showing
	if (m_buildingsHeaderOpen) then
		Controls.BuildingsPlus:SetText("[ICON_MINUS]");
		Controls.BuildingsStack:SetHide(false);
	else
		Controls.BuildingsPlus:SetText("[ICON_PLUS]");
		Controls.BuildingsStack:SetHide(true);
	end
	Controls.BuildingsButton:RegisterCallback( Mouse.eLClick, OnBuildingsHeaderSelected );

	-- Handle section hiding and showing
	if (m_wondersHeaderOpen) then
		Controls.WondersPlus:SetText("[ICON_MINUS]");
		Controls.WondersStack:SetHide(false);
	else
		Controls.WondersPlus:SetText("[ICON_PLUS]");
		Controls.WondersStack:SetHide(true);
	end
	Controls.WondersButton:RegisterCallback( Mouse.eLClick, OnWondersHeaderSelected );

	-- Clean Up Earned Items
	Controls.PerksStack:CalculateSize();
	Controls.PerksStack:ReprocessAnchoring();

	Controls.BuildingsStack:CalculateSize();
	Controls.BuildingsStack:ReprocessAnchoring();

	Controls.WondersStack:CalculateSize();
	Controls.WondersStack:ReprocessAnchoring();

	Controls.EarnedItemsStack:CalculateSize();
	Controls.EarnedItemsStack:ReprocessAnchoring();

	Controls.EarnedItemsScrollPanel:CalculateInternalSize();
	Controls.EarnedItemsScrollPanel:ReprocessAnchoring();

	-- Populate Earned Yields
	local earnedEnergy = m_player:GetTotalArtifactYield(YieldTypes.YIELD_ENERGY);
	local energyStr : string = Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", earnedEnergy, "[ICON_ENERGY]", "TXT_KEY_YIELD_ENERGY");
	Controls.EarnedEnergy:SetText(energyStr);

	local earnedFood = m_player:GetTotalArtifactYield(YieldTypes.YIELD_FOOD);
	local foodStr : string = Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", earnedFood, "[ICON_FOOD]", "TXT_KEY_YIELD_FOOD");
	Controls.EarnedFood:SetText(foodStr);

	local earnedProduction = m_player:GetTotalArtifactYield(YieldTypes.YIELD_PRODUCTION);
	local productionStr : string = Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", earnedProduction, "[ICON_PRODUCTION]", "TXT_KEY_YIELD_PRODUCTION");
	Controls.EarnedProduction:SetText(productionStr);

	local earnedScience = m_player:GetTotalArtifactYield(YieldTypes.YIELD_SCIENCE);
	local scienceStr : string = Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", earnedScience, "[ICON_RESEARCH]", "TXT_KEY_YIELD_SCIENCE");
	Controls.EarnedScience:SetText(scienceStr);

	local earnedCulture = m_player:GetTotalArtifactYield(YieldTypes.YIELD_CULTURE);
	local cultureStr : string = Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", earnedCulture, "[ICON_CULTURE]", "TXT_KEY_YIELD_CULTURE");
	Controls.EarnedCulture:SetText(cultureStr);
end

