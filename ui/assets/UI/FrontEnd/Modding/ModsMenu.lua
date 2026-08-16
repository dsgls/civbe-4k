-- ===========================================================================
--	Mods Menu
-- ===========================================================================
include( "InstanceManager" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_bDebugFillWithFakeData = false;	-- Fill list with fake data



-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local g_InstanceManager = InstanceManager:new( "ModInstance", "Label", Controls.ModsStack );



-- ===========================================================================
-- Navigation Routines (Installed,Online,Back)
-- ===========================================================================
function NavigateBack()
	UIManager:SetUICursor( 1 );
	Modding.DeactivateMods();
	UIManager:DequeuePopup( ContextPtr );
	UIManager:SetUICursor( 0 );
	
	Events.SystemUpdateUI( SystemUpdateUIType.RestoreUI, "ModsBrowserReset" );
end
Controls.BackButton:RegisterCallback(Mouse.eLClick, NavigateBack);

-- ===========================================================================
-- UI Event Handlers
-- ===========================================================================
function OnSinglePlayerClick()
	UIManager:QueuePopup( Controls.ModdingSinglePlayer, PopupPriority.ModdingSinglePlayer );
end
Controls.SinglePlayerButton:RegisterCallback(Mouse.eLClick, OnSinglePlayerClick);

-- ===========================================================================
function OnMultiPlayerClick()
	UIManager:QueuePopup( Controls.ModdingMultiplayer, PopupPriority.ModMultiplayerSelectScreen );
end
Controls.MultiPlayerButton:RegisterCallback(Mouse.eLClick, OnMultiPlayerClick);


-- ===========================================================================
function UpdateDisplay()
	local supportsSinglePlayer	= Modding.AllEnabledModsContainPropertyValue("SupportsSinglePlayer", 1);
	local supportsMultiplayer	= Modding.AllEnabledModsContainPropertyValue("SupportsMultiplayer", 1);
		
	Controls.SinglePlayerButton:SetDisabled(not supportsSinglePlayer);
	Controls.MultiPlayerButton:SetDisabled(not supportsMultiplayer);
		
	g_InstanceManager:ResetInstances();
	
	local mods = Modding.GetEnabledModsByActivationOrder();
	Controls.NoMods:SetHide( #mods ~= 0 );

	if( #mods ~= 0) then
		for i,v in ipairs(mods) do
			local displayName			= Modding.GetModProperty(v.ModID, v.Version, "Name");
			local displayNameVersion	= string.format("[ICON_BULLET] %s (v. %i)", displayName, v.Version);			
			local listing				= g_InstanceManager:GetInstance();
			listing.Label:SetText(displayNameVersion);
			listing.Label:SetToolTipString(displayNameVersion);
		end
	end

	-- Fill with debug data (for testing?)
	if (m_bDebugFillWithFakeData) then
		local FAKE_DATA_ENTRIES_NUM = 30;
		for i=1,FAKE_DATA_ENTRIES_NUM,1 do
			local listing				= g_InstanceManager:GetInstance();
			listing.Label:SetText( "[ICON_BULLET] Somename"..tostring(i).." (v. 1.3)" );
			listing.Label:SetToolTipString(displayNameVersion);
		end
		Controls.NoMods:SetHide( true );
	end

	Controls.ModsScrollPanel:CalculateInternalSize();
end


-- ===========================================================================
--	Show/Hide Handler
-- ===========================================================================
ContextPtr:SetShowHideHandler(function(isHiding)
	if (not isHiding) then
		UpdateDisplay();
	end
end);

-- ===========================================================================
-- Input Handler
-- ===========================================================================
ContextPtr:SetInputHandler( function(uiMsg, wParam, lParam)

	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			NavigateBack();
		end
	end

	return true;
end);

--Controls.MultiPlayerButton:SetHide(true);
