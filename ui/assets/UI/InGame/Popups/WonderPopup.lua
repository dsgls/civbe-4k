-------------------------------------------------
-- Wonder popup
-------------------------------------------------

include( "IconSupport" );
include( "InfoTooltipInclude" );

local m_fAnimSeconds = 5;
local m_fScaleFactor = 0.5;
local m_fPct = 0;
local m_fOriginalSizeX = 0;
local m_fOriginalSizeY = 0;
local m_strAudioFile = "";
local m_PopupInfo = nil;

local lastBackgroundImage = "WonderTemp.dds"

-------------------------------------------------
-- On Popup
-------------------------------------------------
function OnPopup( popupInfo )

	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_WONDER_COMPLETED_ACTIVE_PLAYER ) then
		return;
	end
	
	if(Game == nil or Game.GetGameTurn() <= Game.GetStartTurn()) then
		return;
	end
	
	local iBuildingID = popupInfo.Data1;
	local thisBuilding = GameInfo.Buildings[ iBuildingID ];
	if( thisBuilding == nil ) then
    	return;
	end

	m_PopupInfo = popupInfo;

    if( thisBuilding.WonderSplashImage ~= nil ) then
    
        lastBackgroundImage = thisBuilding.WonderSplashImage;
        Controls.WonderSplash:SetTexture( thisBuilding.WonderSplashImage );
    	
    end

	IconHookup( thisBuilding.PortraitIndex, 64, thisBuilding.IconAtlas, Controls.WonderIcon)

    if( thisBuilding.Description ~= nil ) then
    	Controls.Title:SetText( Locale.ToUpper( thisBuilding.Description ) );
    	Controls.Title:SetHide( false );
    else
    	Controls.Title:SetHide( true );
	end
    if( thisBuilding.Quote ~= nil ) then
        Controls.Quote:SetText( Locale.ConvertTextKey( thisBuilding.Quote ) );
    	Controls.Quote:SetHide( false );
    else
    	Controls.Quote:SetHide( true );
    end

	-- Game Info
	local strGameInfo = GetHelpTextForBuilding(iBuildingID, true, true, true);
    if( strGameInfo ~= nil ) then
        Controls.Stats:SetText( Locale.ConvertTextKey( strGameInfo ) );
    	Controls.Stats:SetHide( false );
    else
    	Controls.Stats:SetHide( true );
    end

	-- Reset panning animation
	Controls.PanningAnimation:SetToBeginning();
	Controls.PanningAnimation:Play();
    
	UIManager:QueuePopup( ContextPtr, PopupPriority.WonderPopup );
	
    m_fPct = 0;
end
Events.SerialEventGameMessagePopup.Add( OnPopup );





-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose);


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
    if( not bInitState ) then
        Controls.WonderSplash:UnloadTexture();
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			Controls.WonderSplash:SetTexture( lastBackgroundImage );
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_WONDER_COMPLETED_ACTIVE_PLAYER, 0);
            ContextPtr:ClearUpdate();
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnClose);
