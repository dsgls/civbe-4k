-------------------------------------------------
-- Alien Nest Popup
-------------------------------------------------

local m_PopupInfo = nil;

-------------------------------------------------
-------------------------------------------------
function OnPopup( popupInfo )

	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_BARBARIAN_CAMP_REWARD ) then
		return;
	end

	m_PopupInfo = popupInfo;

    local iNumGold = popupInfo.Data1;
	local iNumResearch = popupInfo.Data2;

	if (iNumResearch > 0) then
		Controls.DescriptionLabel:SetText(Locale.ConvertTextKey("TXT_KEY_ALIEN_NEST_CLEARED_PLUS_RESEARCH", iNumGold, iNumResearch));
	else
		Controls.DescriptionLabel:SetText(Locale.ConvertTextKey("TXT_KEY_ALIEN_NEST_CLEARED", iNumGold));
	end
	
	UIManager:QueuePopup( ContextPtr, PopupPriority.BarbarianCamp );
	Events.AudioPlay2DSound("AS2D_INTERFACE_ENERGY_GAIN");
	
end
Events.SerialEventGameMessagePopup.Add( OnPopup );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnCloseButtonClicked ()
	UIManager:DequeuePopup( ContextPtr );
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCloseButtonClicked );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnCloseButtonClicked();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_BARBARIAN_CAMP_REWARD, 0);
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnCloseButtonClicked);
