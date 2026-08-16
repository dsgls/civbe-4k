-------------------------------------------------
-- Plot Bonus Popup
-------------------------------------------------

function OnPopup( popupInfo )	
    if(popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_PLOT_BONUS) then
		local playerID = popupInfo.Data1;
		local x = popupInfo.Data2;
		local y = popupInfo.Data3;
		local fromExpedition = popupInfo.Option1;
		local player = Players[playerID];
		if (player ~= nil and player:HasPlotBonusMessage(x, y) and not OptionsManager.IsNoRewardPopups() ) then
			local messageTextTable = player:RetrieveAndRemovePlotBonusMessageText(x, y);
			DisplayPopup(fromExpedition, messageTextTable);
		end
    end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );



function DisplayPopup(fromExpedition, messageTextTable)
	Controls.AlphaAnim:SetToBeginning();
	Controls.AlphaAnim:Play();
	
	-- Add generic window title so user knows where the data is coming from. This should be separate for each type (goody hut, or expedition site)
	local title : string = "";
	if (fromExpedition) then
		title = Locale.ConvertTextKey("{TXT_KEY_EXPEDITION_COMPLETE:upper}");
		Controls.Banner:SetTexture("Popup_Image_Expedition.dds");
	else
		title = Locale.ConvertTextKey("{TXT_KEY_RESOURCE_POD_SEARCHED:upper}");
		Controls.Banner:SetTexture("Popup_Image_Resource_Pod.dds");
	end
	Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WINDOW");
	local details = "";
	if (messageTextTable.Details ~= nil) then
		details = Locale.ConvertTextKey(messageTextTable.Details);
	end

	Controls.TitleLabel:SetText(title);	
	Controls.DetailsLabel:SetText(details);

	local textSizeY : number = Controls.DetailsLabel:GetSizeY();
	Controls.Content:SetSizeY(textSizeY + 275);

	Controls.Content:ReprocessAnchoring();

	UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost);
end

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

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local s_Shown = false;

function ShowHideHandler( bIsHide, bInitState )
    if( not bInitState ) then
        if( not bIsHide ) then
			if( not s_Shown ) then
				s_Shown = true;
        		UI.incTurnTimerSemaphore();
        		Events.SerialEventGameMessagePopupShown(m_PopupInfo);
				print("PlotBonusPopup, Blur On");
				Events.BlurStateChange(0);
			end
        else
			if( s_Shown ) then
				s_Shown = false;
				UI.decTurnTimerSemaphore();
				Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_PLOT_BONUS, 0);
				Events.BlurStateChange(1);
				print("PlotBonusPopup, Blur Off");
			end
		end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		ClosePopup();
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);