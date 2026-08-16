-------------------------------------------------
-- Change password screen
-------------------------------------------------
include( "IconSupport" );

local badPasswordStr		= Locale.ConvertTextKey( "TXT_KEY_HOTSEAT_BAD_PASSWORD" );
local badOldPasswordStr		= Locale.ConvertTextKey( "TXT_KEY_HOTSEAT_WRONG_OLD_PASSWORD" );
local passwordsNotMatchStr	= Locale.ConvertTextKey( "TXT_KEY_HOTSEAT_PASSWORD_MISMATCH" );

-------------------------------------------------
-------------------------------------------------
function OnOK()
	local ePlayer = Game.GetActivePlayer();
	if (PreGame.TestPassword( ePlayer, Controls.OldPasswordEditBox:GetText() ) ) then
		if ( Controls.NewPasswordEditBox:GetText() == Controls.RetypeNewPasswordEditBox:GetText() ) then
			PreGame.SetPassword( ePlayer, Controls.NewPasswordEditBox:GetText(), Controls.OldPasswordEditBox:GetText() );
			
			UIManager:PopModal( ContextPtr );
			ContextPtr:SetHide( true );
			LuaEvents.PasswordChanged( Game.GetActivePlayer() );
		end
	end
end
Controls.OKButton:RegisterCallback( Mouse.eLClick, OnOK );

-------------------------------------------------
-------------------------------------------------
function OnCancel()
	UIManager:PopModal( ContextPtr );
	ContextPtr:SetHide( true );
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_RETURN then
            OnOK();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );

----------------------------------------------------------------
----------------------------------------------------------------
function ValidateText(text)
	if(text == nil) then
		return false;
	end

	local isAllWhiteSpace = true;
	for i = 1, #text, 1 do
		if(string.byte(text, i) ~= 32) then
			isAllWhiteSpace = false;
			break;
		end
	end
	
	if(isAllWhiteSpace) then
		return false;
	end
	
	-- don't allow % character
	for i = 1, #text, 1 do
		if string.byte(text, i) == 37 then
			return false;
		end
	end
	
	local invalidCharArray = { '\"', '<', '>', '|', '\b', '\0', '\t', '\n', '/', '\\', '*', '?' };

	for i, ch in ipairs(invalidCharArray) do
		if(string.find(text, ch) ~= nil) then
			return false;
		end
	end
	
	-- don't allow control characters
	for i = 1, #text, 1 do
		if (string.byte(text, i) < 32) then
			return false;
		end
	end

	return true;
end

-- ===========================================================================
function Validate()
	local bOldPasswordValid = true;
	local bNewPasswordValid = true;
	local bPasswordsMatch = true;
	local bValid = true;

	if(not PreGame.TestPassword( Game.GetActivePlayer(), Controls.OldPasswordEditBox:GetText() ) ) then
		bValid = false;
		bOldPasswordValid = false;
	end

	if(bValid and not ValidateText(Controls.NewPasswordEditBox:GetText()) ) then
		bValid = false;
		bNewPasswordValid = false;
	end

	if( bValid and Controls.NewPasswordEditBox:GetText() ~= Controls.RetypeNewPasswordEditBox:GetText() ) then
		bValid = false;
		bPasswordsMatch = false;
	end

	if(bValid) then
		Controls.OKButton:SetDisabled(false);
		Controls.OKButton:LocalizeAndSetToolTip("");
	else
		Controls.OKButton:SetDisabled(true);
		if(not bOldPasswordValid) then
			Controls.OKButton:SetToolTipString(badOldPasswordStr);
		elseif(not bNewPasswordValid) then 
			Controls.OKButton:SetToolTipString(badPasswordStr);
		elseif(not bPasswordsMatch) then
			Controls.OKButton:SetToolTipString(passwordsNotMatchStr);
		end
	end
end
Controls.OldPasswordEditBox:RegisterCharCallback(Validate);
Controls.NewPasswordEditBox:RegisterCharCallback(Validate);
Controls.RetypeNewPasswordEditBox:RegisterCharCallback(Validate);


-- ===========================================================================
function UpdateWindow()

	local bHasPassword = PreGame.HasPassword( Game.GetActivePlayer() );
	Controls.OldPasswordStack:SetHide( not bHasPassword );
	Controls.OldPasswordEditBox:SetText( "" );
	Controls.NewPasswordEditBox:SetText( "" );
	Controls.RetypeNewPasswordEditBox:SetText( "" );		

	Validate();
		
	if (bHasPassword) then
		Controls.OldPasswordEditBox:TakeFocus();
	else
		Controls.NewPasswordEditBox:TakeFocus();
	end
       	
	local pPlayer = Players[Game.GetActivePlayer()];
	if(pPlayer ~= nil) then
		local civ = GameInfo.Civilizations[pPlayer:GetCivilizationType()];
		if(civ ~= nil) then
			CivIconHookup( pPlayer:GetID(), 64, Controls.CivIcon, Controls.CivIconBG, nil, true, false, Controls.CivIconHighlight );
		end
	end

	Controls.PasswordStack:CalculateSize();
end


-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )
    
	if( not bIsHide ) then		
		UpdateWindow();
	end		
end
ContextPtr:SetShowHideHandler( ShowHideHandler );



-- ===========================================================================
--	Init
-- ===========================================================================
UpdateWindow();