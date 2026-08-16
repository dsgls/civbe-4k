include("StationHelper");

-- STATION POPUP
-- This popup occurs when a player clicks on a station
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_STATION] = function(popupInfo)

	local plotIndex = popupInfo.Data1;
	local station = Game.GetStationByPlot(plotIndex);

	if (station ~= nil) then
		
		-- Initialize popup text	
		local titleText = Locale.ConvertTextKey("TXT_KEY_POPUP_VIEW_STATION")
		local messageText = station:GetMessageString(Game.GetActivePlayer());
		local levelText = station:GetLevelString(Game.GetActivePlayer());

		-- Populate text
		local popupText = titleText .. "[NEWLINE][NEWLINE]" .. messageText .. "[NEWLINE][NEWLINE]" .. levelText;
		SetPopupText(popupText);
	end

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
