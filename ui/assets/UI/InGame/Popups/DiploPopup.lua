-- ===========================================================================
--	INCLUDES
-- ===========================================================================
include("TabSupport");


-- ===========================================================================
--	GLOBALS
-- ===========================================================================
local g_tabs;
local g_isInit = false;

local m_PopupInfo = nil;

-- ===========================================================================
-- Key Down Processing
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
-- ===========================================================================
function OnPopup(popupInfo)	
	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_DIPLOMACY ) then		
	    return;
	end	

	m_PopupInfo = popupInfo;

	if (popupInfo.Data1 == 1) then
		if (ContextPtr:IsHidden() == false) then
			ContextPtr:SetHide(true);
		else
			ContextPtr:SetHide(false);
		end
	else
		ContextPtr:SetHide(false);
	end

	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

-------------------------------------------------
-------------------------------------------------
function ShowHideHandler(isHide)
	if isHide then
		Controls.RelationshipsPanel:SetHide( true );
		Controls.DealHistoryPanel:SetHide( true );
		if (m_PopupInfo ~= nil) then
			Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
		end
	else	
		Events.SerialEventGameMessagePopupShown(m_PopupInfo);

		if ( g_tabs.selectedControl ~= nil ) then
			if ( g_tabs.selectedControl == Controls.RelationshipsTab ) then 
				Controls.RelationshipsPanel:SetHide( false ); 
			elseif ( g_tabs.selectedControl == Controls.DealHistoryTab ) then 
				Controls.DealHistoryPanel:SetHide( false ); 
			end
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

-------------------------------------------------
-------------------------------------------------
function OnClose( )
	
    ContextPtr:SetHide( true );
	LuaEvents.SubDiploPanelClosed();
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );


-- ===========================================================================
-- ===========================================================================
function OnTabRelationships( control )
	Controls.RelationshipsPanel:SetHide( false );
	Controls.DealHistoryPanel:SetHide( true );	
end

-- ===========================================================================
-- ===========================================================================
function OnTabDealHistory( selectedTabControl )
	Controls.RelationshipsPanel:SetHide( true );
	Controls.DealHistoryPanel:SetHide( false );	
end


-- ===========================================================================
--	Initialize
-- ===========================================================================
function Initialize()
	if ( g_isInit ) then
		return;
	end

	g_isInit = true;
	g_tabs = CreateTabs( Controls.TabRow, 64, 32 );
	g_tabs.AddTab( Controls.RelationshipsTab,		OnTabRelationships );
	g_tabs.AddTab( Controls.DealHistoryTab,			OnTabDealHistory );
	g_tabs.CenterAlignTabs(0);
	g_tabs.SelectTab( Controls.RelationshipsTab );
end
Initialize();

