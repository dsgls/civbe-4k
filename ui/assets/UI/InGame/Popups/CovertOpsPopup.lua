-- ===========================================================================
--	Covert Ops (similar concepts to Espionage from CivBE)
--	Contains the covert ops panel (separate as it use to hold tabbed contents)
-- ===========================================================================



-- ===========================================================================
--	GLOBALS
-- ===========================================================================
local g_isInit = false;

local m_PopupInfo = nil;

if not g_isInit then
	g_isInit = true;
	LuaEvents.CovertOpsHide( true );
end


-- ===========================================================================
--	Key Down Processing
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
	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_ESPIONAGE_OVERVIEW ) then
		if ( not ContextPtr:IsHidden() ) then
			LuaEvents.CovertOpsCloseAnyOpenPulldowns();
		end
	    return;
	end	

	m_PopupInfo = popupInfo;
	local cityX = popupInfo.Data2;
	local cityY = popupInfo.Data3;

	if (popupInfo.Data1 == 1) then
		if (ContextPtr:IsHidden() == false) then
			UI.ClearCovertOpsSelectedCity();
			ContextPtr:SetHide(true);
		else
			SelectCovertOpsCity(cityX, cityY);
			ContextPtr:SetHide(false);
		end
	else
		SelectCovertOpsCity(cityX, cityY);
		ContextPtr:SetHide(false);
	end
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

-- ===========================================================================
--	Civilopedia doesn't receive a pop-up message; but is raised via a search.
--	If it's called and this is open, make sure any open pulldown's are closed.
function OnCivilopediaSearch()
	if ( not ContextPtr:IsHidden() ) then
		LuaEvents.CovertOpsCloseAnyOpenPulldowns();
	end
end
Events.SearchForPediaEntry.Add( OnCivilopediaSearch );

-- ===========================================================================
function SelectCovertOpsCity(x, y)
	local plot = Map.GetPlot(x, y);
	if (plot ~= nil) then
		local city = plot:GetPlotCity();
		if (city ~= nil) then
			UI.SetCovertOpsSelectedCity(city);
		end
	else
		UI.ClearCovertOpsSelectedCity();
	end
end

-- ===========================================================================
-- ===========================================================================
function ShowHideHandler( isHide, isInit )
	if not isInit then
		if isHide then	
			Controls.CovertOpsPanel:SetHide(true);
			Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_ESPIONAGE_OVERVIEW, 0);
		else
			Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			Controls.CovertOpsPanel:SetHide(false);
			LuaEvents.SubDiploPanelOpen();
		end
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------
-------------------------------------------------
function OnClose()	
    ContextPtr:SetHide( true );
	LuaEvents.SubDiploPanelClosed();
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );



-- ===========================================================================
--	If still open, close the Covert Ops popup when "next turn" is pressed.
-- ===========================================================================
function OnActivePlayerTurnEnd()
	if not ContextPtr:IsHidden() then
		OnClose();
	end
end
Events.ActivePlayerTurnEnd.Add( OnActivePlayerTurnEnd );
