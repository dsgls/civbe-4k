
-- OUTPOST POPUP
-- This popup occurs when a player clicks on an outpost
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_OUTPOST] = function(popupInfo)

	--local plotIndex = popupInfo.Data1;


	Controls.CloseButton:SetHide( false );	
end

----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
PopupInputHandlers[ButtonPopupTypes.BUTTONPOPUP_STATION] = function( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if( wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN ) then
			HideWindow();
            return true;
        end
    end
end

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(HideWindow);
