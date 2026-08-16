-------------------------------------------------
-- Station Greeting Popup
-------------------------------------------------
include("StationHelper");

local m_PopupInfo = nil;

-------------------------------------------------
-------------------------------------------------
function OnPopup( popupInfo )

	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_STATION_GREETING and
		popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_STATION_CONQUERED ) then
		return;
	end

	m_PopupInfo = popupInfo;

	if popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_STATION_GREETING then
		OnStationGreeting();
	elseif popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_STATION_CONQUERED then
		OnStationConquered();
	end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );
-------------------------------------------------
-------------------------------------------------
function SizeWindowToContent()
	Controls.ContentStack:CalculateSize();
	Controls.ContentStack:ReprocessAnchoring();
	local windowx = 500;
	if(Controls.ContentStack:GetSizeX() > Controls.TitleLabel:GetSizeX()) then
		windowx = Controls.ContentStack:GetSizeX() + 40;
	else
		windowx = Controls.TitleLabel:GetSizeX() + 40;
	end
	local windowy = Controls.ContentStack:GetSizeY() + 75;
	Controls.Window:SetSizeX(windowx);
	Controls.WindowHeader:SetSizeX(windowx);
	Controls.HeaderSeparator:SetSizeX(windowx);
	Controls.Window:SetSizeY(windowy);
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnStationGreeting()

	local strTitle = "";
	local strDescription = "";

	local stationID = m_PopupInfo.Data1;
	local station = Game.GetStationByID(stationID);

	-- Title
	strTitle = Locale.ConvertTextKey("{TXT_KEY_POPUP_STATION_FOUND:upper}");

	-- Description
	local stationNameKey = station:GetNameKey();
	local descriptionText = Locale.ConvertTextKey("TXT_KEY_POPUP_STATION_FOUND_DESC", stationNameKey);

	local stationMessage = station:GetMessageString(Game.GetActivePlayer());
	local stationWarning = Locale.ConvertTextKey("TXT_KEY_STATION_TRADE_ROUTE_WARNING");

	-- Set strings
	Controls.TitleLabel:SetText(strTitle);
	Controls.DescriptionLabel:SetText(descriptionText .. "[NEWLINE][NEWLINE]" .. stationMessage .. "[NEWLINE][NEWLINE]" .. stationWarning);
	
	-- Queue popup
	UIManager:QueuePopup( ContextPtr, PopupPriority.CityStateGreeting );
	
	-- Size Window
	SizeWindowToContent();

	Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WINDOW");
end

function OnStationConquered()
	local strTitle = "";
	local strDescription = "";

	local stationType = m_PopupInfo.Data1;
	local energyReward = m_PopupInfo.Data2;
	local scienceReward = m_PopupInfo.Data3;

	local stationInfo = GameInfo.Stations[stationType];
	if stationInfo == nil then
		error("Station Conquest Popup: station type invalid");
	end

	-- Title
	strTitle = Locale.ConvertTextKey("{TXT_KEY_POPUP_STATION_CONQUERED:upper}");

	-- Description
	local descriptionText = Locale.ConvertTextKey("TXT_KEY_POPUP_STATION_CONQUERED_DESC", stationInfo.Description, energyReward, scienceReward);

	-- Set strings
	Controls.TitleLabel:SetText(strTitle);
	Controls.DescriptionLabel:SetText(descriptionText);
	
	-- Queue popup
	UIManager:QueuePopup( ContextPtr, PopupPriority.CityStateGreeting );
	
	-- Size Window
	SizeWindowToContent();

	Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WINDOW");
end

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
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnCloseButtonClicked);
