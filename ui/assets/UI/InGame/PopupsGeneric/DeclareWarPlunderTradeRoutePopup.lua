
-- DECLARE WAR MOVE POPUP
-- This popup occurs when a team unit moves onto rival territory
-- or attacks an rival unit
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_DECLAREWAR_PLUNDER_TRADE_ROUTE] = function(popupInfo)
	local eRivalTeam = popupInfo.Data1;
	local eOtherTeam = popupInfo.Data2;
	
	-- If there's a rival team, let the declare war popup handle this.
	if(eRivalTeam ~= nil and eRivalTeam ~= -1) then
		return false;
	end
	
	local popupText = Locale.ConvertTextKey("TXT_KEY_LEAGUE_OVERVIEW_CONFIRM", Teams[eOtherTeam]:GetNameKey());
	SetPopupText(popupText);
	
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		if (eOtherTeam ~= -1) then
			Network.SendIgnoreWarning(eOtherTeam);
		end
		
		Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_PLUNDER_TRADE_ROUTE, -1, -1, 0, false, false);
	end
	
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_YES");
	AddButton(buttonText, OnYesClicked);
	
	-- Initialize 'no' button.
	local buttonText = Locale.ConvertTextKey("TXT_KEY_DECLARE_WAR_NO");
	AddButton(buttonText, nil);
	
	Controls.CloseButton:SetHide(true);
end

----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
PopupInputHandlers[ButtonPopupTypes.BUTTONPOPUP_DECLAREWARMOVE] = function( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if( wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN ) then
			HideWindow();
            return true;
        end
    end
end

