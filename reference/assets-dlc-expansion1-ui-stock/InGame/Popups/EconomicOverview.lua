-------------------------------------------------
-- Economic
-------------------------------------------------
include("TabSupport");
include( "IconSupport" );

local m_CurrentPanel = Controls.EconomicGeneralInfo;
local m_tabs;
local m_currentTab = Controls.GeneralInfoButton;

-------------------------------------------------
-- On Popup
-------------------------------------------------
function OnPopup( popupInfo )
	if( popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW ) then
		m_PopupInfo = popupInfo;
		
		if( m_PopupInfo.Data1 == 1 ) then
        	if( ContextPtr:IsHidden() == false ) then
        	    OnClose();
        	    return;
    	    else
            	UIManager:QueuePopup( ContextPtr, PopupPriority.InGameUtmost );
        	end
    	else
        	UIManager:QueuePopup( ContextPtr, PopupPriority.EconOverview );
    	end
	end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose);
LuaEvents.LeaveEconomyOverview.Add(OnClose);

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose();
            return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )
    local pPlayer = Players[ Game.GetActivePlayer() ];
    if( pPlayer == nil ) then
        print( "Could not get player... huh?" );
        return;
    end
	
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	
        	-- trigger the show/hide handler to update state
        	m_CurrentPanel:SetHide( false );
        	
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW, 0);
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnGeneralInfoButton()
	-- Set Tabs
	-- Controls.GeneralInfoSelectHighlight:SetHide(false);
	-- Controls.HealthSelectHighlight:SetHide(true);
	
	-- Set Panels
    Controls.EconomicGeneralInfo:SetHide( false );
    Controls.HealthInfo:SetHide( true );
    m_CurrentPanel = Controls.EconomicGeneralInfo;
	m_currentTab = Controls.GeneralInfoButton;
end
--Controls.GeneralInfoButton:RegisterCallback( Mouse.eLClick, OnGeneralInfoButton );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnHealthButton()
	-- Set Tabs
	-- Controls.GeneralInfoSelectHighlight:SetHide(true);
	-- Controls.HealthSelectHighlight:SetHide(false);
	
	-- Set Panels
    Controls.EconomicGeneralInfo:SetHide( true );
    Controls.HealthInfo:SetHide( false );
    m_CurrentPanel = Controls.HealthInfo;
	m_currentTab = Controls.HealthButton;
end
--Controls.HealthButton:RegisterCallback( Mouse.eLClick, OnHealthButton );


function Initialize()
	m_tabs = CreateTabs( Controls.TabContainer, 64, 32 );
	m_tabs.AddTab( Controls.GeneralInfoButton, OnGeneralInfoButton );
	m_tabs.AddTab( Controls.HealthButton, OnHealthButton);
	m_tabs.CenterAlignTabs();
	m_tabs.SelectTab(m_currentTab);
end

OnGeneralInfoButton();

-- Disable Health section if Health is turned off.
if (Game.IsOption(GameOptionTypes.GAMEOPTION_NO_HEALTH)) then
	Controls.HealthButton:SetDisabled(true);
	Controls.HealthButton:LocalizeAndSetToolTip("TXT_KEY_TOP_PANEL_Health_OFF_TOOLTIP");
end

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnClose);
Initialize();