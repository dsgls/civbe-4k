-------------------------------------------------
-- TestCivBEUIScreen
-------------------------------------------------
include( "InstanceManager" );
local g_LineManager = InstanceManager:new( "LineInstance",  "TheLine", Controls.UIDynamicLines );


-- ===========================================================================
--	Main (show/hide)
-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsHide ) then
        if ( Controls.CivBELogo ~= nil ) then
            Controls.CivBELogo:SetTexture( "CivilizationBE_Logo.dds" );        
        end            
        --HideIfExist( Controls.MainMenuScreenUI );
		DrawDynamicLines();
        UIManager:SetDrawControlBounds( false );

		LuaEvents.MyLuaDebugEvent();
    else
        if ( Controls.CivBELogo ~= nil ) then
            Controls.CivBELogo:UnloadTexture();
        end 
        UIManager:SetDrawControlBounds( false );
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
function OnClose()
    UIManager:DequeuePopup( ContextPtr );
end
--Controls.BackButton:RegisterCallback( Mouse.eLClick, OnClose );


-- ===========================================================================
--
-- ===========================================================================
function DrawDynamicLines()
    if ( g_LineManager == nil ) then
        return;
    end

	for i=0,20 do
		local lineInstance 	= g_LineManager:GetInstance();
		lineInstance.TheLine:SetWidth( 1 + ( i % 3) );		
		lineInstance.TheLine:SetColor( 0xfffbb34a );
		lineInstance.TheLine:SetStartVal(0, i*10);
		lineInstance.TheLine:SetEndVal(i*10, 200);
	end
end


-- ===========================================================================
function HideIfExist(control, hiding )
    if ( hiding == nil ) then 
        hiding = true;
    end
    if ( control ~= nil ) then
        control:SetHide( hiding );
    end
end


-- ===========================================================================
-- Input processing
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            OnClose();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
function OnUpdate()
    
    local test = Controls.test;
    if ( test == nil ) then
        return;
    end

    -- Set disabled if mouse is high up; on enabled if it is low, close to the label.
    local mouseX, mouseY    = UIManager:GetMousePos();
    local screenX, screenY  = UIManager:GetScreenSizeVal();
    if (mouseY < (screenY - 150) ) then
        test:SetDisabled( true );
    else
        test:SetDisabled( false  );
    end
end
ContextPtr:SetUpdate( OnUpdate );


-- ===========================================================================
function OnMyLuaDebugEvent()
	print("TestCivBEUIScreen... Just got a lua debug event!");
end
LuaEvents.MyLuaDebugEvent.Add( OnMyLuaDebugEvent );


function OnEditCallback( str, ctrl, enterPressedOrLostFocus )
	print("OnEditCallback: " ,str,ctrl,enterPressedOrLostFocus );
end
Controls.EditCityName:RegisterCallback(OnEditCallback);
