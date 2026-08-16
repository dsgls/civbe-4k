include( "InstanceManager" );

----------------------------------------------------------------   
function UpdateNetworkDisplay()
end
ContextPtr:SetUpdate(UpdateNetworkDisplay);

---------------------------------------------------------------------
function VerboseLoggingToggleClicked()
	if (Controls.VerboseLoggingToggle:IsChecked()) then
		Network.SetDebugLogLevel(2);
	else
		Network.SetDebugLogLevel(1);
	end
end

Controls.VerboseLoggingToggle:RegisterCallback( Mouse.eLClick, VerboseLoggingToggleClicked );

---------------------------------------------------------------------
function ExitClicked( void1, Control )
	ContextPtr:SetHide( true );
end

Controls.Exit_Button:RegisterCallback( Mouse.eLClick, ExitClicked );

---------------------------------------------------------------------
function ShowHideHandler( bIsHide )
    if( not bIsHide ) then
		
		Controls.VerboseLoggingToggle:SetCheck(Network.GetDebugLogLevel() == 2);		
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
