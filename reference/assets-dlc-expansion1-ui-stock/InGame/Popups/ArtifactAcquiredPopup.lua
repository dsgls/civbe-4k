-------------------------------------------------
-- Wonder popup
-------------------------------------------------

include( "IconSupport" );
include( "InfoTooltipInclude" );

local m_PopupInfo = nil;

local lastBackgroundImage = "WonderTemp.dds"

-------------------------------------------------
-- On Popup
-------------------------------------------------
function OnPopup( popupInfo )
	if( popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_ARTIFACT_ACQUIRED ) then
		return;
	end

	if(not ContextPtr:IsHidden()) then
		return;
	end

	if(Game == nil or Game.GetGameTurn() < Game.GetStartTurn()) then
		return;
	end

	local playerType : number = popupInfo.Data1;	
	local player : object = Players[playerType];
	if(player == nil) then
		error("player was nil");
	end

	-- return if the active player isn't acquiring the artifact
	if(playerType ~= Game.GetActivePlayer()) then
		return;
	end

	Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WINDOW");
	Events.AudioPlay2DSound("AS2D_EVENT_NOTIFICATION_DISCOVER_ARTIFACT");

	m_PopupInfo = popupInfo;

	-- popup ui logic
	local artifactType : number = popupInfo.Data2;
	local artifactInfo : table = GameInfo.Artifacts[artifactType];
	IconHookup(artifactInfo.PortraitIndex, 200, artifactInfo.IconAtlas, Controls.PortraitImage);

	local artifactValue : number = player:GetArtifactValueAtIndex(m_PopupInfo.Data3);
	if(artifactValue == nil) then
		error("artifactValue was nil");
	end

	local colorString : string;

	if(artifactValue == 0) then
		colorString = "[COLOR_RED]"
	elseif(artifactValue == 1) then
		colorString = "[COLOR_YELLOW]"
	elseif(artifactValue == 2) then
		colorString = "[COLOR_GREEN]"
	end

	Controls.ArtifactDescriptionLabel:LocalizeAndSetText("TXT_KEY_ARTIFACTS_POPUP_ARTIFACT_DESCRIPTION", artifactInfo.Description, colorString, GameInfo.ArtifactValues[artifactValue].Description);

	Controls.ArtifactExplanationLabel:LocalizeAndSetText(artifactInfo.Explanation);

	Controls.AcquiredArtifactInfoStack:CalculateSize();
	Controls.AcquiredArtifactInfoStack:ReprocessAnchoring();

	UIManager:QueuePopup( ContextPtr, PopupPriority.ArtifactAcquiredPopup );
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClickViewArtifactsButton()
	OnClose();

	local playerType : number = m_PopupInfo.Data1;	
	local player : object = Players[playerType];
	if(player == nil) then
		error("player was nil");
	end
    
	player:ShowArtifactSelectedInPopup(m_PopupInfo.Data3);
end
Controls.ViewArtifactsButton:RegisterCallback( Mouse.eLClick, OnClickViewArtifactsButton);

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnAccept()
    UIManager:DequeuePopup( ContextPtr );
end
Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept);

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
    UIManager:DequeuePopup( ContextPtr );
end

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
        --Controls.WonderSplash:UnloadTexture();
        if( not bIsHide ) then
        	--UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			Events.BlurStateChange(0);
			print("ArtifactAcquiredPopup, Blur On");

			Controls.AlphaAnim:SetToBeginning();
			Controls.AlphaAnim:Play();

			--Controls.WonderSplash:SetTexture( lastBackgroundImage );
        else
            --UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_ARTIFACT_ACQUIRED, 0);
            ContextPtr:ClearUpdate();
			Events.BlurStateChange(1);
			print("ArtifactAcquiredPopup, Blur Off");
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnClose);
