-------------------------------------------------
-- Select City Names
-------------------------------------------------

local m_PopupInfo = nil;

-------------------------------------------------
-------------------------------------------------
function OnCancel()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );


-------------------------------------------------
-------------------------------------------------
function OnAccept()
	local pCity = UI.GetHeadSelectedCity();
	if pCity then
		Network.SendRenameCity(pCity:GetID(), Controls.EditCityName:GetText());
	end
	
    UIManager:DequeuePopup( ContextPtr );
end
Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept );

----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            OnCancel();  
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );


----------------------------------------------------------------
----------------------------------------------------------------
local invalidCharArray = { '\"', '\'', '<', '>', '|', '\b', '\0', '\t', '\n', '/', '\\', '*', '?', '\[', '\]', '\%', '\&' };

function IsInvalidCharacter(inputChar)

	for _,v in pairs(invalidCharArray) do
		if v == inputChar then
			return true;
		end
	end

	if string.byte(inputChar,1) < 32 then
		return true;
	end

	return false;
end


function ValidateText(text)

	local numNonWhiteSpace = 0;
	for i = 1, #text, 1 do
		if string.byte(text, i) ~= 32 then
			numNonWhiteSpace = numNonWhiteSpace + 1;
		end
	end
	
	if numNonWhiteSpace < 3 then
		return false;
	end

	for i = 1, #text, 1 do
		if IsInvalidCharacter( string.byte(text, i) ) then
			return false;
		end
	end
	
	return true;
end

-- ===========================================================================
function OnCharInput( inputChar, inputString, dummyControl)
	local bValid = false;

	if IsInvalidCharacter(inputChar) and (inputChar ~= '\b') then
		Controls.EditCityName:SetText( string.sub(Controls.EditCityName:GetText(), 1, -2) );
	end

	if ValidateText(inputString) then
		bValid = true;
	end
	
	Controls.AcceptButton:SetDisabled(not bValid);
end
Controls.EditCityName:RegisterCharCallback(OnCharInput);


----------------------------------------------------------------
----------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )
    if( not bInitState ) then
        if( not bIsHide ) then
	     	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			Events.BlurStateChange( 0 );
			print("SetCityName, Blur On");
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_RENAME_CITY, 0);
			Events.BlurStateChange( 1 );
			print("SetCityName, Blur Off");
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


function OnPopup( popupInfo )
	if ( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_RENAME_CITY ) then
		return;
	end
	
	m_PopupInfo = popupInfo;
	
	local pCity = UI.GetHeadSelectedCity();

	if pCity then
		local cityName = pCity:GetNameKey();
		local convertedKey = Locale.ConvertTextKey(cityName);
		
		Controls.EditCityName:SetText(convertedKey);
		Controls.AcceptButton:SetDisabled(true);
		
		UIManager:QueuePopup( ContextPtr, PopupPriority.Priority_GreatPersonReward );
	end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );


----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnCancel);
