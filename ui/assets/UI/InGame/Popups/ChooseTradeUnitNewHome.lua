-- ===========================================================================
--	Change Trade Route origin city
-- ===========================================================================


include( "IconSupport" );
include( "InstanceManager" );

-- Used for Piano Keys
local ltBlue = {19/255,32/255,46/255,120/255};
local dkBlue = {12/255,22/255,30/255,120/255};

local g_ItemManager = InstanceManager:new( "ItemInstance", "Button", Controls.ItemStack );

g_iUnitIndex = -1;
g_iPlayer = -1;

local bHidden = true;
local pUnitPlot;
local g_PopupInfo = nil;





-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function Initialize()

	local m_screenSizeX, m_screenSizeY	= UIManager:GetScreenSizeVal()
	local spHeight						= Controls.ItemScrollPanel:GetSizeY();
	local bpHeight						= Controls.BottomPanel:GetSizeY();

	local ART_BUFFER					= 5;
	Controls.BottomPanel:SetSizeY( m_screenSizeY - ART_BUFFER );
	Controls.BottomPanel:ReprocessAnchoring();

	local ART_BUFFER_SCROLLAREA			= 211;
	Controls.ItemScrollPanel:SetSizeY( Controls.BottomPanel:GetSizeY() - ART_BUFFER_SCROLLAREA );
	Controls.ItemScrollPanel:CalculateInternalSize();
	Controls.ItemScrollPanel:ReprocessAnchoring();

end



-------------------------------------------------
-------------------------------------------------
function OnPopupMessage(popupInfo)
	  
	local popupType = popupInfo.Type;
	if popupType ~= ButtonPopupTypes.BUTTONPOPUP_CHOOSE_TRADE_UNIT_NEW_HOME then
		return;
	end	

	g_PopupInfo = popupInfo;
		
	g_iUnitIndex = popupInfo.Data1;
   	UIManager:QueuePopup( ContextPtr, PopupPriority.SocialPolicy );
end
Events.SerialEventGameMessagePopup.Add( OnPopupMessage );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    ----------------------------------------------------------------        
    -- Key Down Processing
    ----------------------------------------------------------------        
    if uiMsg == KeyEvents.KeyDown then
        if (wParam == Keys.VK_ESCAPE) then
			if(not Controls.ChooseConfirm:IsHidden()) then
				Controls.ChooseConfirm:SetHide(true);
			else
				OnClose();
			end
        	return true;
        end
    end
end
ContextPtr:SetInputHandler( InputHandler );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function TradeOverview()
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_TRADE_ROUTE_OVERVIEW,
	}
	Events.SerialEventGameMessagePopup(popupInfo);
end
Controls.TradeOverviewButton:RegisterCallback( Mouse.eLClick, TradeOverview );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
    UIManager:DequeuePopup(ContextPtr);
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function RefreshList()
	g_ItemManager:ResetInstances();
	
	local pPlayer = Players[Game.GetActivePlayer()];
	local pUnit = pPlayer:GetUnitByID(g_iUnitIndex);
	if (pUnit == nil) then
		return;
	end
	
	local pOriginPlot = pUnit:GetPlot();
	local pOriginCity = pOriginPlot:GetPlotCity();
	
	local eDomain = pUnit:GetDomainType();

	--CivIconHookup( pPlayer:GetID(), 64, Controls.CivIcon, Controls.CivIconBG, Controls.CivIconShadow, false, true );
		
	local unitType = pUnit:GetUnitType();
	local unitInfo = GameInfo.Units[unitType];
	
	local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(unitType, pPlayer:GetID());
	IconHookup(portraitOffset, 64, portraitAtlas, Controls.TradeUnitIcon);

	Controls.StartingCity:LocalizeAndSetText("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_STARTING_CITY", pOriginCity:GetName());
	Controls.UnitInfo:LocalizeAndSetText("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_TRADE_UNIT", pUnit:GetName());
	
	local map = Map;
	
	local potentialNewHomes = pPlayer:GetPotentialTradeUnitNewHomeCity(pUnit);
	for i,v in ipairs(potentialNewHomes) do

		local pTargetCity = nil;
		local iTargetOwner = nil;
		local pLoopPlot = map.GetPlot(v.X, v.Y);
		if(pLoopPlot ~= nil) then
			pTargetCity = pLoopPlot:GetPlotCity();
			iTargetOwner = pTargetCity:GetOwner();
		end

		if pTargetCity == nil then
			error("Invalid city when choosing new trade route home city");
		end
		
		local pTargetPlayer = Players[iTargetOwner];
		local iNumRoutesAllowed = pTargetCity:GetNumTradeRoutesAllowed();
		local iNumRoutesAvailable = pTargetCity:GetNumTradeRoutesAvailable();
		local iNumRoutesOccupied = iNumRoutesAllowed - iNumRoutesAvailable;
				
		local itemInstance = g_ItemManager:GetInstance();

		SimpleCivIconHookup(pTargetPlayer:GetID(), 64, itemInstance.CivIcon);
		
		itemInstance.CityName:SetText(Locale.Lookup(pTargetCity:GetNameKey()));

		local descStr : string;
		if (iNumRoutesAllowed > 0) then
			descStr = Locale.ConvertTextKey("TXT_KEY_CHANGE_TRADE_UNIT_HOME_CITY_AVAILABLE", iNumRoutesAvailable, iNumRoutesAllowed, iNumRoutesOccupied);
			itemInstance.CityDescription:SetAlpha(1.0);
		else
			descStr = Locale.Lookup("TXT_KEY_CHANGE_TRADE_UNIT_HOME_CITY_UNAVAILABLE");

			-- Offer recommendation as to why there are no slots available
			local recStr : string = nil;
			if iNumRoutesAllowed == 0 then
				recStr = Locale.Lookup("TXT_KEY_CHANGE_TRADE_UNIT_HOME_CITY_REC_BUILDING");
			elseif iNumRoutesAllowed == iNumRoutesOccupied then
				recStr = Locale.Lookup("TXT_KEY_CHANGE_TRADE_UNIT_HOME_CITY_REC_SLOTS_FULL");
			end
			if recStr ~= nil then
				descStr = descStr .. "[NEWLINE]" .. recStr;
			end
			itemInstance.CityDescription:SetAlpha(0.5);
		end
		itemInstance.CityDescription:SetText(descStr);

		-- Update piano key color/anim
		local buttonWidth, buttonHeight = itemInstance.Button:GetSizeVal();
		local newHeight = 80;	
		itemInstance.Button:SetSizeVal(buttonWidth, newHeight);
		
		itemInstance.GoToCity:RegisterCallback(Mouse.eLClick, function() 
			UI.LookAt(pLoopPlot, 0);  
		end);

		-- Button hookup
		if (iNumRoutesAvailable > 0) then
			itemInstance.Button:RegisterCallback(Mouse.eLClick, function() 
				SelectNewHome(v.X, v.Y); 
			end);
			itemInstance.Button:SetDisabled(false);
		else
			itemInstance.Button:SetDisabled(true);
		end

		local infoHeight = itemInstance.CityName:GetSizeY() + itemInstance.CityDescription:GetSizeY() + itemInstance.CityName:GetOffsetY();
		if ( infoHeight > itemInstance.Button:GetSizeY() ) then
			itemInstance.Button:SetSizeY(infoHeight + 10);
		end
	end

	

	Controls.ItemStack:CalculateSize();
	Controls.ItemStack:ReprocessAnchoring();
	Controls.ItemScrollPanel:CalculateInternalSize();
end

function SelectNewHome(iPlotX, iPlotY) 

	g_selectedPlotX = iPlotX;
	g_selectedPlotY = iPlotY;
	
	Controls.ChooseConfirm:SetHide(false);
end

function OnConfirmYes( )
	Controls.ChooseConfirm:SetHide(true);
	
	Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_CHANGE_TRADE_UNIT_HOME_CITY, g_selectedPlotX, g_selectedPlotY, 0, false, bShift);
		
	Events.AudioPlay2DSound("AS2D_INTERFACE_TRADE_ROUTE_CONFIRM");	
	
	OnClose();	
end
Controls.ConfirmYes:RegisterCallback( Mouse.eLClick, OnConfirmYes );

function OnConfirmNo( )
	Controls.ChooseConfirm:SetHide(true);
end
Controls.ConfirmNo:RegisterCallback( Mouse.eLClick, OnConfirmNo );




-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

	bHidden = bIsHide;
    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(g_PopupInfo);
        	
        	RefreshList();
        
			local unitPanel = ContextPtr:LookUpControl( "/InGame/WorldView/UnitPanel/Base" );
			if( unitPanel ~= nil ) then
				unitPanel:SetHide( true );
			end
			
			local infoCorner = ContextPtr:LookUpControl( "/InGame/WorldView/InfoCorner" );
			if( infoCorner ~= nil ) then
				infoCorner:SetHide( true );
			end
               	
        else
      
			local unitPanel = ContextPtr:LookUpControl( "/InGame/WorldView/UnitPanel/Base" );
			if( unitPanel ~= nil ) then
				unitPanel:SetHide(false);
			end
			
			local infoCorner = ContextPtr:LookUpControl( "/InGame/WorldView/InfoCorner" );
			if( infoCorner ~= nil ) then
				infoCorner:SetHide(false);
			end
			
			if(g_PopupInfo ~= nil) then
				Events.SerialEventGameMessagePopupProcessed.CallImmediate(g_PopupInfo.Type, 0);
			end
            UI.decTurnTimerSemaphore();
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

function OnDirty()
	-- If the user performed any action that changes selection states, just close this UI.
	if not bHidden then
		OnClose();
	end
end
Events.UnitSelectionChanged.Add( OnDirty );


Initialize();