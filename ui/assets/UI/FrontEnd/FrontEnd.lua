-------------------------------------------------
-- FrontEnd
-------------------------------------------------

function ShowHideHandler( bIsHide, bIsInit )

		-- Check for game invites first.  If we have a game invite, we will have flipped 
		-- the CivBEApp::eHasShownLegal and not show the legal/touch screens.
		UI:CheckForCommandLineInvitation();
		
    if( not UI:HasShownLegal() ) then
        UIManager:QueuePopup( Controls.LegalScreen, PopupPriority.LegalScreen );
    end

    if( not bIsHide ) then
		screenWidth, screenHeight = UIManager:GetScreenSizeVal();
		--Controls.AtlasLogo:SetSizeVal(((19*screenHeight)/12),screenHeight);
        Controls.AtlasLogo:SetTexture( "CivilizationBEAtlas.dds" );
    	UIManager:SetUICursor( 0 );
        UIManager:QueuePopup( Controls.MainMenu, PopupPriority.MainMenu );
    else
        Controls.AtlasLogo:UnloadTexture();
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
