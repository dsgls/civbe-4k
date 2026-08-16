-------------------------------------------------
-- Exit Game
-------------------------------------------------

local m_PopupDisplayed = false;

----------------------------------------------------------------        
----------------------------------------------------------------
function OnYes( )
	--UIManager:DequeuePopup( ContextPtr );
	m_PopupDisplayed = false;
	UIManager:PopModal( ContextPtr );
	Game.SetGameState(GameplayGameStateTypes.GAMESTATE_OVER);
end
Controls.Yes:RegisterCallback( Mouse.eLClick, OnYes );


----------------------------------------------------------------        
----------------------------------------------------------------
function OnNo( )
	m_PopupDisplayed = false;
	UIManager:PopModal( ContextPtr );
end
Controls.No:RegisterCallback( Mouse.eLClick, OnNo );

----------------------------------------------------------------  
----------------------------------------------------------------        
function OnShowHide( isHide, isInit )
	
	if(not isHide) then
		Controls.Message:LocalizeAndSetText( "TXT_KEY_RETIRE_CONFIRMATION" );
	end	
end
ContextPtr:SetShowHideHandler( OnShowHide );


----------------------------------------------------------------        
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            OnNo()
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );
