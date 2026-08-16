-------------------------------------------------
-- Alien Nest Popup
-------------------------------------------------

local m_PopupInfo = nil;

-------------------------------------------------
-------------------------------------------------
function OnPopup( popupInfo )
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_BARBARIAN_CAMP_REWARD) then
		return;
	end

	m_PopupInfo = popupInfo;

	local yieldType = popupInfo.Data1;     
	local rewardYield = popupInfo.Data2;
	local rewardScience = popupInfo.Data3;
	local cityID : number = popupInfo.Data4;
	local city : object = nil;
	if (cityID >= 0) then
		city = Players[Game.GetActivePlayer()]:GetCityByID(cityID);
	end

	Controls.TitleLabel:SetText(Locale.Lookup("{TXT_KEY_POP_ALIEN_CLEARED:upper}"));

	local yieldInfo : table = GameInfo.Yields[yieldType];
	if (yieldInfo.ID == YieldTypes.YIELD_FOOD) then
		if (city == nil) then
			print("Alien Nest Popup Error! City was invalid");
			return;
		end

		if (rewardScience > 0) then
			Controls.DetailsLabel:SetText(Locale.ConvertTextKey("TXT_KEY_MISC_DESTROYED_ALIEN_NEST_CITY_FOOD_AND_SCIENCE", rewardScience, rewardYield, city:GetNameKey()));
		else
			Controls.DetailsLabel:SetText(Locale.ConvertTextKey("TXT_KEY_MISC_DESTROYED_ALIEN_NEST_CITY_FOOD", rewardYield, city:GetNameKey()));
		end
	else
		if (rewardScience > 0) then
			Controls.DetailsLabel:SetText(Locale.ConvertTextKey("TXT_KEY_MISC_DESTROYED_ALIEN_NEST_ENERGY_AND_SCIENCE", rewardScience, rewardYield));
		else
			Controls.DetailsLabel:SetText(Locale.ConvertTextKey("TXT_KEY_MISC_DESTROYED_ALIEN_NEST_ENERGY", rewardYield));
		end
	end	
	
	local textSizeY : number = Controls.DetailsLabel:GetSizeY();
	Controls.Content:SetSizeY(textSizeY + 275);
	Controls.Content:ReprocessAnchoring();

	UIManager:QueuePopup( ContextPtr, PopupPriority.BarbarianCamp );
	Events.AudioPlay2DSound("AS2D_INTERFACE_ENERGY_GAIN");
	
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            ClosePopup();
            return true;
        end
    end
end
ContextPtr:SetInputHandler(InputHandler);

-------------------------------------------------------------------------------
function ClosePopup()
	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, ClosePopup);

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			Events.BlurStateChange(0);
			print("BarbarianCampPopup, Blur On");
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_BARBARIAN_CAMP_REWARD, 0);
			Events.BlurStateChange(1);
			print("BarbarianCampPopup, Blur Off");
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
