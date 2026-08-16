-- CAPTURE CITY POPUP
-- This popup occurs when a city is capture and must be annexed or puppeted.

PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_CITY_CAPTURED] = function(popupInfo)

	local cityID				= popupInfo.Data1;
	local iCaptureGold			= popupInfo.Data2;
	local iCaptureCulture		= popupInfo.Data3;
	local iCaptureGreatWorks    = popupInfo.Data4;
	local iLiberatedPlayer		= popupInfo.Data5;
	local bMinorCivBuyout		= popupInfo.Option1;
	
	local activePlayer	= Players[Game.GetActivePlayer()];
	local newCity		= activePlayer:GetCityByID(cityID);
	
	if newCity == nil then
		return false;
	end

	--if (0 ~= GameDefines["PLAYER_ALWAYS_RAZES_CITIES"]) then
	--
		--activePlayer:Raze(newCity);
		--return false;
	--end
	
	-- Initialize popup text.	
	local cityNameKey = newCity:GetNameKey();
	if (iCaptureCulture > 0 or iCaptureGold > 0 or iCaptureGreatWorks > 0) then
	    if (iCaptureCulture >0 or iCaptureGreatWorks > 0) then
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ENERGY_AND_CULTURE_CITY_CAPTURE", iCaptureGold, iCaptureCulture, iCaptureGreatWorks, cityNameKey);
	    else
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ENERGY_CITY_CAPTURE", iCaptureGold, cityNameKey);
		end
	else
		popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_NO_ENERGY_CITY_CAPTURE", cityNameKey);
	end
		
	-- Ask the player what he wants to do with this City
	popupText = popupText .. "  " .. Locale.ConvertTextKey("TXT_KEY_POPUP_CITY_CAPTURE_INFO");
	
	SetPopupText(popupText);
	
	-- Calculate Health info
	local iUnhealthNoCity = activePlayer:GetUnhealth();
	local iUnhealthAnnexedCity = activePlayer:GetUnhealthForecast(newCity, nil);	-- pAssumeCityAnnexed, pAssumeCityPuppeted
	if (bMinorCivBuyout) then
		-- For minor civ buyout (Austria UA), there are no unhealth benefits of annexing because the city is not occupied
		iUnhealthAnnexedCity = activePlayer:GetUnhealthForecast(nil, newCity);
	end
	local iUnhealthPuppetCity = activePlayer:GetUnhealthForecast(nil, newCity);		-- pAssumeCityAnnexed, pAssumeCityPuppeted
	
	local iUnhealthForAnnexing = iUnhealthAnnexedCity - iUnhealthNoCity;
	local iUnhealthForPuppeting = iUnhealthPuppetCity - iUnhealthNoCity;
	
	-- Initialize 'Liberate' button.
	if (iLiberatedPlayer ~= -1) then
		local OnLiberateClicked = function()
			Network.SendLiberateMinor(iLiberatedPlayer, cityID);
		end
		
		local buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_LIBERATE_CITY");
		local strToolTip = Locale.ConvertTextKey("TXT_KEY_POPUP_CITY_CAPTURE_INFO_LIBERATE", Players[iLiberatedPlayer]:GetNameKey());
		AddButton(buttonText, OnLiberateClicked, strToolTip);
	end
	
	-- Initialize 'Annex' button.
	local OnCaptureClicked = function()
		Network.SendDoTask(cityID, TaskTypes.TASK_ANNEX_PUPPET, -1, -1, false, false, false, false);
		newCity:ChooseProduction();
	end
	
	if (not activePlayer:MayNotAnnex()) then
		local buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_ANNEX_CITY");
		local strToolTip = Locale.ConvertTextKey("TXT_KEY_POPUP_CITY_CAPTURE_INFO_ANNEX", iUnhealthForAnnexing);
		AddButton(buttonText, OnCaptureClicked, strToolTip);
	end
		
	-- Initialize 'Puppet' button.
	local OnPuppetClicked = function()
		Network.SendDoTask(cityID, TaskTypes.TASK_CREATE_PUPPET, -1, -1, false, false, false, false);
	end
	
	buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_PUPPET_CAPTURED_CITY");
	strToolTip = Locale.ConvertTextKey("TXT_KEY_POPUP_CITY_CAPTURE_INFO_PUPPET", iUnhealthForPuppeting);
	AddButton(buttonText, OnPuppetClicked, strToolTip);
	
	-- Initialize 'Raze' button.
	local bRaze = activePlayer:CanRaze(newCity);
	if (bRaze) then
		local OnRazeClicked = function()
			Network.SendDoTask(cityID, TaskTypes.TASK_RAZE, -1, -1, false, false, false, false);
		end
		
		buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_RAZE_CAPTURED_CITY");
		strToolTip = Locale.ConvertTextKey("TXT_KEY_POPUP_CITY_CAPTURE_INFO_RAZE", iUnhealthForAnnexing);
		AddButton(buttonText, OnRazeClicked, strToolTip);
	end

	-- CITY SCREEN CLOSED - uh oh, original comment: "Don't look, Marc"
	local CityScreenClosed = function()
		UIManager:DequeuePopup(Controls.EmptyPopup);
		if ( CityScreenClosed ~= nil ) then
			Events.SerialEventExitCityScreen.Remove(CityScreenClosed);
		end
	end
	
	-- Initialize 'View City' button.
	local OnViewCityClicked = function()
		
		-- Queue up an empty popup at a higher priority so that it prevents other cities from appearing while we're looking at this one!
		UIManager:QueuePopup(Controls.EmptyPopup, PopupPriority.GenericPopup+1);
		
		Events.SerialEventExitCityScreen.Add(CityScreenClosed);
		
		UI.SetCityScreenViewingMode(true);
		UI.DoSelectCityAtPlot( newCity:Plot() );
	end
	
	buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_VIEW_CITY");
	strToolTip = Locale.ConvertTextKey("TXT_KEY_POPUP_VIEW_CITY_DETAILS");
	AddButton(buttonText, OnViewCityClicked, strToolTip, true);	-- true is bPreventClose
end

-- =============================================================================
--	OUTPOST CAPTURED
--	Triggered by Liberation Army virtue, allows player to elect to destroy the
--	outpost instead of capturing it.
-- =============================================================================
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_OUTPOST_CAPTURED] = function(popupInfo)

	local plotX : number = popupInfo.Data1;
	local plotY : number = popupInfo.Data2;
	
	local activePlayer	= Players[Game.GetActivePlayer()];

	-- Initialize popup text.
	local popupTitle : string = Locale.ConvertTextKey("TXT_KEY_POPUP_OUTPOST_CAPTURE");
	local popupInfo : string = Locale.ConvertTextKey("TXT_KEY_POPUP_OUTPOST_CAPTURE_INFO");
	SetPopupText(popupTitle .. " " .. popupInfo);

	-- Initialize 'Capture' button.
	local OnCaptureClicked = function()
		activePlayer:InitOutpost(plotX, plotY);
	end
	buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_CONVERT_OUTPOST");
	AddButton(buttonText, OnCaptureClicked);

	-- Initialize 'Destroy' button.
	local OnDestroyClicked = function()
		-- This should do nothing as the outpost will already be removed prior to this popup
	end
	buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_DESTROY_OUTPOST");
	AddButton(buttonText, OnDestroyClicked);
end
