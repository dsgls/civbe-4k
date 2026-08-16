-------------------------------------------------
-- Choose Free Item Popup
-------------------------------------------------
include("IconSupport");
include("InfoTooltipInclude");

-- This global table handles how items are populated based on an identifier.
g_NumberOfFreeItems = 0;

local m_PopupInfo = nil;

PopulateItems = {};
CommitItems = {};

SelectedItems = {};
 
function DisplayPopup(playerID, classType, numberOfFreeItems)
	
	if(numberOfFreeItems ~= 1) then
		error("This UI currently only supports 1 free item for the time being.");
	end
	
	local count = PopulateItems[classType](Controls.ItemStack, playerID);
	
	Controls.ItemStack:CalculateSize();
	Controls.ItemStack:ReprocessAnchoring();
	Controls.ItemScrollPanel:CalculateInternalSize();
	
	if(count > 0 and numberOfFreeItems > 0) then
		g_NumberOfFreeItems = math.min(numberOfFreeItems, count);
	
		Controls.ConfirmButton:SetDisabled(true);
		UIManager:QueuePopup( ContextPtr, PopupPriority.eUtmost );
	else
	
	--	ContextPtr:SetHide(true);
	end 
	
	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, function()
		CommitItems[classType](SelectedItems, playerID);
		OnClose();
	end);
	
end

function OnClose()
	UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);

function OnPopup( popupInfo )	
    if( popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_CHOOSE_FREE_GREAT_PERSON and
        ContextPtr:IsHidden() == true ) then
        
        m_PopupInfo = popupInfo;
        
        print("Displaying Choose Free Item Popup");
        DisplayPopup(popupInfo.Data1, "GreatPeople", 1);
    end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    ----------------------------------------------------------------        
    -- Key Down Processing
    ----------------------------------------------------------------        
    if uiMsg == KeyEvents.KeyDown then
        if (wParam == Keys.VK_ESCAPE) then
		    OnClose();
	    	return true;
        end
        
        -- Do Nothing.
        if(wParam == Keys.VK_RETURN) then
			return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );
  
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_CHOOSE_FREE_GREAT_PERSON, 0);
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		ContextPtr:SetHide(true);
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);
