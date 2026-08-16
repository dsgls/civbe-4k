-------------------------------------------------
-- Affinity Level Up Popup
-------------------------------------------------
include( "InfoTooltipInclude" );

local m_PopupInfo = nil;

function UpdatePopup(popupInfo)
	local playerID = popupInfo.Data1;
	local affinityID = popupInfo.Data2;
	local affinityLevel = popupInfo.Data3;
	local affinityInfo = GameInfo.Affinity_Types[affinityID];

	Controls.FlavorLabel:SetText(ConstructFlavorText(playerID, affinityInfo, affinityLevel));
	Controls.AffinityImage:SetTexture(affinityInfo.IconImage);
	Controls.TitleLabel:LocalizeAndSetText("{TXT_KEY_AFFINITY_PROGRESS:upper}");
	Controls.DetailsLabel:SetText(ConstructDetailsText(playerID, affinityInfo, affinityLevel));
	SizeWindowToContent();
end

function SizeWindowToContent()
	Controls.ContentStack:CalculateSize();
	Controls.ContentStack:ReprocessAnchoring();
	
	local contentSize : number = Controls.ContentStack:GetSizeY();
	Controls.OuterGrid:SetSizeY(contentSize + 260);
	
	Controls.OuterGrid:ReprocessAnchoring();
end

function ConstructFlavorText(playerID, affinityInfo, affinityLevel)
	local s = "";
	local affinityLevelInfo = GameInfo.Affinity_Levels[affinityLevel];
	if (affinityLevelInfo ~= nil) then
		local flavorTextKey = nil;
		if (affinityInfo.Type == "AFFINITY_TYPE_HARMONY") then
			flavorTextKey = affinityLevelInfo.HarmonyFlavorText;
		elseif (affinityInfo.Type == "AFFINITY_TYPE_PURITY") then
			flavorTextKey = affinityLevelInfo.PurityFlavorText;
		elseif (affinityInfo.Type == "AFFINITY_TYPE_SUPREMACY") then
			flavorTextKey = affinityLevelInfo.SupremacyFlavorText;
		end

		if (flavorTextKey ~= nil) then
			s = s .. Locale.ConvertTextKey(flavorTextKey);
		end
	end
	
	return s;
end

function ConstructDetailsText(playerID, affinityInfo, affinityLevel)
	local s = "";
	s = s .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_UP_DETAILS_LEVEL", affinityLevel, affinityInfo.IconString, affinityInfo.Description);
	
	-- Perks, covert ops, etc.
	local bonusText = GetHelpTextForAffinityLevel(affinityInfo.ID, affinityLevel);
	if (bonusText ~= "") then
		s = s .. "[NEWLINE][ICON_BULLET]" .. bonusText;
	end

	-- Unlocked Unit Upgrades?
	if (Players[playerID]:HasAnyPendingUpgrades()) then
		s = s .. "[NEWLINE][ICON_BULLET]" .. Locale.ConvertTextKey("TXT_KEY_AFFINITY_LEVEL_UP_DETAILS_UNIT_UPGRADES_AVAILABLE_NOW");
	end

	return s;
end

-------------------------------------------------------------------------------
-- Input and Events
-------------------------------------------------------------------------------
function OnPopup(popupInfo)	
    if(popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_AFFINITY_LEVEL_UP and ContextPtr:IsHidden()) then
		m_PopupInfo = popupInfo;
		UpdatePopup(popupInfo);
		UIManager:QueuePopup(ContextPtr, PopupPriority.NewEraPopup);
		Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WINDOW");
    end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            ClosePopup();
            return true;
        end
    end
end
ContextPtr:SetInputHandler(InputHandler);

function ClosePopup()
	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, ClosePopup);

function ShowHideHandler( bIsHide, bInitState )
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			print("AffinityLevelUpPopup, Blur On");
			Events.BlurStateChange(0);
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_AFFINITY_LEVEL_UP, 0);
			Events.BlurStateChange(1);
			print("AffinityLevelUpPopup, Blur Off");
	    end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		ContextPtr:SetHide(true);
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);