

function ModeClicked( void1, Control )
	if Control == 0 then
		ContextPtr:SetHide( true );
	end
end

Controls.Exit_Button:RegisterCallback( Mouse.eLClick, ModeClicked );

------------------------------------------------
-- Terrain Debug Panel Buttons
-------------------------------------------------

function ReloadIce( Inc )
	Ice_Reload();
end

Controls.RebuildIce:RegisterCallback( Mouse.eLClick, ReloadIce );