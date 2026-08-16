-- CONFIRM WONDER SITE POPUP
-- This popup occurs when an action needs confirmation.
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_CHOOSE_PLOT_PROJECT_SITE] = function(popupInfo)

	local plotIndex : number = popupInfo.Data1;
	local eOrder : number = popupInfo.Data2;
	local eProjectType : number = popupInfo.Data3;
	local cityPlotIndex : number = popupInfo.Data4;

	local pCityPlot : object = Map.GetPlotByIndex(cityPlotIndex);
	local pCity : object = pCityPlot:GetPlotCity();

	local pPlot : object = Map.GetPlotByIndex(plotIndex);
	local projectInfo : table = GameInfo.Projects[eProjectType];

	-- Double-check the project is valid here
	if (not pCity:CanPlaceProjectAt(pPlot:GetX(), pPlot:GetY(), projectInfo.ID)) then
		HideWindow();
		return false;
	end

	local popupText : string = Locale.Lookup("TXT_KEY_POPUP_ARE_YOU_SURE");

	-- Notify if a feature will be removed
	-- Does not apply to the Move City project, which uses this popup
	local ePlotResource = pPlot:GetResourceType();
	if (eProjectType ~= GameInfo.Projects["PROJECT_MOVE_CITY"].ID) then
		if (ePlotResource ~= -1) then
			local pResourceInfo : table = GameInfo.Resources[ePlotResource];
			popupText = popupText .. " " .. Locale.ConvertTextKey("TXT_KEY_BUILD_FEATURE_CLEARED", pResourceInfo.Description);
		end	
	end

	SetPopupText(popupText);
		
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		
		-- Confirm action
		Game.CityPushOrderWithPlot(pCity, pPlot, eOrder, eProjectType, false, true, false); 

		-- Play sound
		if (projectInfo.PlotPlacementConfirmSound ~= nil and projectInfo.PlotPlacementConfirmSound ~= "") then
			Events.AudioPlay2DSound(projectInfo.PlotPlacementConfirmSound);
		end
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

