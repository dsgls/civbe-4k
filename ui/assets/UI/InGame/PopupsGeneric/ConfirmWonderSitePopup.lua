
-- CONFIRM WONDER SITE POPUP
-- This popup occurs when an action needs confirmation.
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_CHOOSE_PLOT_PROJECT_SITE] = function(popupInfo)

	local plotIndex = popupInfo.Data1;
	local eOrder = popupInfo.Data2;
	local eProjectType = popupInfo.Data3;
	local cityPlotIndex = popupInfo.Data4;

	local pPlot = Map.GetPlotByIndex(plotIndex);

	local popupText = Locale.Lookup("TXT_KEY_POPUP_ARE_YOU_SURE");

	-- Notify if a feature will be removed
	local ePlotResource = pPlot:GetResourceType();
	if (ePlotResource ~= -1) then
		local pResourceInfo = GameInfo.Resources[ePlotResource];
		popupText = popupText .. " " .. Locale.ConvertTextKey("TXT_KEY_BUILD_FEATURE_CLEARED", pResourceInfo.Description);
	end	

	SetPopupText(popupText);
		
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		
		-- Confirm action
		local pCityPlot = Map.GetPlotByIndex(cityPlotIndex);
		local pCity = pCityPlot:GetPlotCity();
		
		Game.CityPushOrderWithPlot(pCity, pPlot, eOrder, eProjectType, false, true, false); 
	end
	
	local buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_YES");
	AddButton(buttonText, OnYesClicked)
		
	-- Initialize 'no' button.
	local buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_NO");
	AddButton(buttonText, nil);

	Controls.CloseButton:SetHide( true );

end

----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
PopupInputHandlers[ButtonPopupTypes.BUTTONPOPUP_CHOOSE_PLOT_PROJECT_SITE] = function( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if( wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN ) then
			HideWindow();
            return true;
        end
    end
end

