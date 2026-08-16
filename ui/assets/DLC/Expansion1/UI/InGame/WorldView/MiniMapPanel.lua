----------------------------------------------------------------        
----------------------------------------------------------------        
include( "InstanceManager" );

local g_LegendIM = InstanceManager:new( "LegendKey", "Item", Controls.LegendStack );
local g_Overlays = {}; -- remove: GetStrategicViewOverlays();
local g_IconModes = {}; -- GetStrategicViewIconSettings();

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnMinimapInfo( uiHandle, width, height, paddingX )
    
	local BORDER_ART_SIZE = 44;
	--width = 245; height = 140;	-- force value for debug test
	--width = 600; height = 400;	-- force value for debug test

	Controls.MinimapHolder:SetSizeVal( width, height );
	Controls.Minimap:SetTextureHandle( uiHandle );
	Controls.Minimap:SetSizeVal(width, height);
	Controls.MinimapButton:SetSizeVal( width, height );
	Controls.MiniMapButtonOverImage:SetSizeVal( width, height );
	Controls.MiniMapButtonOutImage:SetSizeVal( width, height );
	Controls.MinimapOverlapImage:SetSizeVal( width + BORDER_ART_SIZE, height + BORDER_ART_SIZE);

	if OptionsManager.GetEnableTransparentMinimap() then
		Controls.MinimapBacking:SetColor( 0x88000000 );
	else
		Controls.MinimapBacking:SetColor( 0xff202020 );
	end
end
Events.MinimapTextureBroadcastEvent.Add( OnMinimapInfo );
UI:RequestMinimapBroadcast();

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnMinimapClick( _, _, _, x, y )
    Events.MinimapClickedEvent( x, y );
end
Controls.MinimapButton:RegisterCallback( Mouse.eLClick, OnMinimapClick );
     
function OnMapOptions()	

	local panelWidth = Controls.OptionsPanel:GetSizeX();
	Controls.OptionsPanel:SetOffsetX( -panelWidth );
	Controls.OptionsPanel:SetHide( not Controls.OptionsPanel:IsHidden() );
    UpdateOptionsPanel();
end
Controls.MapOptionsButton:RegisterCallback( Mouse.eLClick, OnMapOptions );

-------------------------------------------------
-------------------------------------------------      
function OnStagingRoom()
	local eViewType = GetGameViewRenderType();
	if (eViewType == GameViewTypes.GAMEVIEW_NONE) then
		SetGameViewRenderType(GameViewTypes.GAMEVIEW_STANDARD);			
	else
		SetGameViewRenderType(GameViewTypes.GAMEVIEW_NONE);
	end
end
Controls.StagingRoomButton:RegisterCallback( Mouse.eLClick, OnStagingRoom );  



----------------------------------------------------------------        
----------------------------------------------------------------        
g_MapOptionDefaults = nil;
local g_PerPlayerMapOptions = {};
----------------------------------------------------------------    
-- Get the map option defaults from the options manager    
----------------------------------------------------------------        
function GetMapOptionDefaults()
	if (g_MapOptionDefaults == nil) then
		-- Pull in the current setting the first time through
		g_MapOptionDefaults = {};
		g_MapOptionDefaults.ShowTrade = OptionsManager.GetShowTradeOn();
		g_MapOptionDefaults.ShowGrid = OptionsManager.GetGridOn();
		g_MapOptionDefaults.ShowYield = OptionsManager.GetYieldOn();
		g_MapOptionDefaults.ShowResources = OptionsManager.GetResourceOn();
		g_MapOptionDefaults.ShowArtifacts = OptionsManager.GetArtifactOn();
		g_MapOptionDefaults.ShowNests = OptionsManager.GetNestsOn();
		g_MapOptionDefaults.HideTileRecommendations = OptionsManager.IsNoTileRecommendations();
		
		g_MapOptionDefaults.SVIconMode = 1;
		g_MapOptionDefaults.SVOverlayMode = 1;
		g_MapOptionDefaults.SVShowFeatures = true;
		g_MapOptionDefaults.SVShowFOW = true;
	end
	
	local mapOptions = {};
	for k, v in pairs(g_MapOptionDefaults) do mapOptions[k] = v; end 
	
	return mapOptions;
end

----------------------------------------------------------------    
-- Take the current options and apply them to the game
----------------------------------------------------------------        
function ApplyMapOptions(mapOptions)

	UI.SetGridVisibleMode( mapOptions.ShowGrid );
	UI.SetYieldVisibleMode( mapOptions.ShowYield );
	UI.SetResourceVisibleMode( mapOptions.ShowResources );
	UI.SetArtifactVisibleMode( mapOptions.ShowArtifacts );
	UI.SetNestsVisibleMode( mapOptions.ShowNests );
	UI.SetTradeRouteVisibleMode( mapOptions.ShowTrade );
	
	LuaEvents.OnRecommendationCheckChanged(mapOptions.HideTileRecommendations);
	
	-- Because outside contexted will also want to access the settings, we have to push them back to the OptionsManager	
	if (PreGame.IsHotSeatGame()) then
		local bChanged = false;
		
		if (OptionsManager.GetGridOn() ~= mapOptions.ShowGrid) then
			OptionsManager.SetGridOn_Cached( mapOptions.ShowGrid );
			bChanged = true;
		end
		if (OptionsManager.GetShowTradeOn() ~= mapOptions.ShowTrade) then 
			OptionsManager.SetShowTradeOn_Cached( mapOptions.ShowTrade );
			bChanged = true;
		end
		if (OptionsManager.GetYieldOn() ~= mapOptions.ShowYield) then
			OptionsManager.SetYieldOn_Cached( mapOptions.ShowYield );
			bChanged = true;
		end
		if (OptionsManager.GetResourceOn() ~= mapOptions.ShowResources) then
			OptionsManager.SetResourceOn_Cached( mapOptions.ShowResources );
			bChanged = true;
		end
		if (OptionsManager.GetArtifactOn() ~= mapOptions.ShowArtifacts) then
			OptionsManager.SetArtifactOn_Cached( mapOptions.ShowArtifacts );
			bChanged = true;
		end
		if (OptionsManager.GetNestsOn() ~= mapOptions.ShowNests) then
			OptionsManager.SetNestsOn_Cached( mapOptions.ShowNests );
			bChanged = true;
		end
		if (OptionsManager.IsNoTileRecommendations() ~= mapOptions.HideTileRecommendations) then
			OptionsManager.SetNoTileRecommendations_Cached(mapOptions.HideTileRecommendations );
			bChanged = true;
		end
		-- We will tell the manager to not write them out
		if (bChanged) then 
			OptionsManager.CommitGameOptions(true);
		end
	end
	
	--StrategicViewShowFeatures( mapOptions.SVShowFeatures );
	--StrategicViewShowFogOfWar( mapOptions.SVShowFOW );
	--SetStrategicViewIconSetting( mapOptions.SVIconMode ); 
	--SetStrategicViewOverlay( mapOptions.SVOverlayMode ); 
end

----------------------------------------------------------------    
-- Store the current options to the specified player's slot
----------------------------------------------------------------        
function StoreMapOptions(iPlayer, mapOptions)
	g_PerPlayerMapOptions[iPlayer] = mapOptions;
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function GetMapOptions(iPlayer)

	local mapOptions;
	
	-- Get the options from the local player cache
	if (g_PerPlayerMapOptions[iPlayer] == nil) then
		-- Initialize with the defaults
		mapOptions = GetMapOptionDefaults();			
		StoreMapOptions(iPlayer, mapOptions);
	else
		mapOptions = g_PerPlayerMapOptions[iPlayer];
	end
	
	return mapOptions;
end		

----------------------------------------------------------------        
----------------------------------------------------------------        
function UpdateOptionsPanel()
	
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	
	Controls.ShowTrade:SetCheck( mapOptions.ShowTrade );
	Controls.ShowGrid:SetCheck( mapOptions.ShowGrid );
	Controls.ShowYield:SetCheck( mapOptions.ShowYield );
	Controls.ShowResources:SetCheck( mapOptions.ShowResources );
	Controls.ShowArtifacts:SetCheck( mapOptions.ShowArtifacts );
	Controls.ShowNests:SetCheck( mapOptions.ShowNests );
	Controls.HideRecommendation:SetCheck( mapOptions.HideTileRecommendations );
	Controls.StrategicStack:SetHide( true );
	
	Controls.ShowFeatures:SetCheck( mapOptions.SVShowFeatures );
	Controls.ShowFogOfWar:SetCheck( mapOptions.SVShowFOW );	

	--show/hide the staging room button.
	Controls.StagingRoomButton:SetHide(not Network.IsDedicatedServer());

   	--Controls.OverlayDropDown:GetButton():SetText(Locale.ConvertTextKey( g_Overlays[mapOptions.SVOverlayMode] ));
	--SetLegend(mapOptions.SVOverlayMode);
	
	--Controls.IconDropDown:GetButton():SetText( Locale.ConvertTextKey( g_IconModes[mapOptions.SVIconMode] ));
	
	Controls.StrategicStack:CalculateSize();
	Controls.MainStack:CalculateSize();
	Controls.OptionsPanel:DoAutoSize();
	
end
Events.GameOptionsChanged.Add(UpdateOptionsPanel);
	
----------------------------------------------------------------        
----------------------------------------------------------------        
--[[function PopulateOverlayPulldown( pullDown )

	for i, text in pairs( g_Overlays ) do
	    controlTable = {};
        pullDown:BuildEntry( "InstanceOne", controlTable );

        controlTable.Button:SetVoid1( i );
        controlTable.Button:SetText( Locale.ConvertTextKey( text ) );
   	end
   	
   	Controls.OverlayDropDown:GetButton():SetText(Locale.ConvertTextKey( g_Overlays[1] ));
	
	pullDown:CalculateInternals();
    pullDown:RegisterSelectionCallback( OnOverlaySelected );
end]]


----------------------------------------------------------------        
----------------------------------------------------------------        
--[[function OnOverlaySelected( index )
	SetStrategicViewOverlay(index); 
	
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.SVOverlayMode = index;
	
	Controls.OverlayDropDown:GetButton():SetText( Locale.ConvertTextKey( g_Overlays[index] ));
	SetLegend(index);
end]]

----------------------------------------------------------------        
----------------------------------------------------------------        
--[[function SetLegend(index)
	g_LegendIM:ResetInstances();
	
	local info = GetOverlayLegend();
	if(index ~= nil) then
		Controls.OverlayTitle:SetText(Locale.ConvertTextKey( g_Overlays[index] ));
	end
	
	Controls.LegendFrame:SetHide(true);
    Controls.SideStack:CalculateSize();
    Controls.SideStack:ReprocessAnchoring();
	
end]]

----------------------------------------------------------------        
----------------------------------------------------------------        
--[[function PopulateIconPulldown( pullDown )
	
	for i, text in pairs(g_IconModes) do
	    controlTable = {};
        pullDown:BuildEntry( "InstanceOne", controlTable );

        controlTable.Button:SetVoid1( i );
        controlTable.Button:SetText( Locale.ConvertTextKey( text ) );
   	end
   	
   	Controls.IconDropDown:GetButton():SetText(Locale.ConvertTextKey( g_IconModes[1] ));
	
	pullDown:CalculateInternals();
    pullDown:RegisterSelectionCallback( OnIconModeSelected );
end]]


----------------------------------------------------------------        
----------------------------------------------------------------        
--[[function OnIconModeSelected( index )
	SetStrategicViewIconSetting(index); 
	
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.SVIconMode = index;
	
	Controls.IconDropDown:GetButton():SetText( Locale.ConvertTextKey( g_IconModes[index] ));
end]]


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnShowFeaturesChecked( bIsChecked )
	StrategicViewShowFeatures( bIsChecked );
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.SVShowFeatures = bIsChecked;
end
Controls.ShowFeatures:RegisterCheckHandler( OnShowFeaturesChecked );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnShowFOWChecked( bIsChecked )
	StrategicViewShowFogOfWar( bIsChecked );
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.SVShowFOW = bIsChecked;
end
Controls.ShowFogOfWar:RegisterCheckHandler( OnShowFOWChecked );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnShowGridChecked( bIsChecked )
	
	UI.SetGridVisibleMode(bIsChecked);
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowGrid = bIsChecked;
	
	OptionsManager.SetGridOn_Cached( bIsChecked );
	OptionsManager.CommitGameOptions( PreGame.IsHotSeatGame() );
		
end
Controls.ShowGrid:RegisterCheckHandler( OnShowGridChecked );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnGridOn()
    Controls.ShowGrid:SetCheck( true );
    
    local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowGrid = true;
	
end
Events.SerialEventHexGridOn.Add( OnGridOn )


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnGridOff()
    Controls.ShowGrid:SetCheck( false );
    
    local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowGrid = false;
	
end
Events.SerialEventHexGridOff.Add( OnGridOff )

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnShowTradeToggled( bIsChecked )
	Controls.ShowTrade:SetCheck(bIsChecked);
	
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowTrade = bIsChecked;
end
Events.Event_ToggleTradeRouteDisplay.Add( OnShowTradeToggled )

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnShowTradeChecked( bIsChecked )
	UI.SetTradeRouteVisibleMode( bIsChecked );
	
	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowTrade = bIsChecked;
    
	OptionsManager.SetShowTradeOn_Cached( bIsChecked );
	OptionsManager.CommitGameOptions( PreGame.IsHotSeatGame() );
end
Controls.ShowTrade:RegisterCheckHandler( OnShowTradeChecked );

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnYieldChecked( bIsChecked )
    UI.SetYieldVisibleMode(bIsChecked);
    local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowYield = bIsChecked;
    
	OptionsManager.SetYieldOn_Cached( bIsChecked );
	OptionsManager.CommitGameOptions( PreGame.IsHotSeatGame() );
end
Controls.ShowYield:RegisterCheckHandler( OnYieldChecked );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnResourcesChecked( bIsChecked )
    UI.SetResourceVisibleMode(bIsChecked);
    local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowResources = bIsChecked;
    
	OptionsManager.SetResourceOn_Cached( bIsChecked );
	OptionsManager.CommitGameOptions(PreGame.IsHotSeatGame());
    
end
Controls.ShowResources:RegisterCheckHandler( OnResourcesChecked );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnArtifactsChecked( bIsChecked )
    UI.SetArtifactVisibleMode(bIsChecked);
    local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowArtifacts = bIsChecked;
    
	OptionsManager.SetArtifactOn_Cached( bIsChecked );
	OptionsManager.CommitGameOptions(PreGame.IsHotSeatGame());
    
end
Controls.ShowArtifacts:RegisterCheckHandler( OnArtifactsChecked );

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnNestsChecked( bIsChecked )
    UI.SetNestsVisibleMode(bIsChecked);
    local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.ShowNests = bIsChecked;
    
	OptionsManager.SetNestsOn_Cached( bIsChecked );
	OptionsManager.CommitGameOptions(PreGame.IsHotSeatGame());
    
end
Controls.ShowNests:RegisterCheckHandler( OnNestsChecked );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnYieldDisplay( type )

	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	
    if( type == YieldDisplayTypes.USER_ALL_ON ) then
        Controls.ShowYield:SetCheck( true );
        mapOptions.ShowYield = true;
        
    elseif( type == YieldDisplayTypes.USER_ALL_OFF ) then
        Controls.ShowYield:SetCheck( false );
         mapOptions.ShowYield = false;
        
    elseif( type == YieldDisplayTypes.USER_ALL_RESOURCE_ON ) then
        Controls.ShowResources:SetCheck( true );
        mapOptions.ShowResources = true;
        
    elseif( type == YieldDisplayTypes.USER_ALL_RESOURCE_OFF ) then
        Controls.ShowResources:SetCheck( false );
        mapOptions.ShowResources = false;
    
	elseif( type == YieldDisplayTypes.USER_ALL_ARTIFACT_ON ) then
		Controls.ShowArtifacts:SetCheck( true );
		mapOptions.ShowArtifacts = true;

	elseif( type == YieldDisplayTypes.USER_ALL_ARTIFACT_OFF ) then
		Controls.ShowArtifacts:SetCheck( false );
		mapOptions.ShowArtifacts = false;

	elseif( type == YieldDisplayTypes.USER_ALL_NESTS_ON ) then
		Controls.ShowNests:SetCheck( true );
		mapOptions.ShowNests = true;

	elseif( type == YieldDisplayTypes.USER_ALL_NESTS_OFF ) then
		Controls.ShowNests:SetCheck( false );
		mapOptions.ShowNests = false;

	end
    
end
Events.RequestYieldDisplay.Add( OnYieldDisplay );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnRecommendationChecked( bIsChecked )

	local mapOptions = GetMapOptions(Game.GetActivePlayer());
	mapOptions.HideTileRecommendations = bIsChecked;
	
	OptionsManager.SetNoTileRecommendations_Cached( bIsChecked );
	OptionsManager.CommitGameOptions(PreGame.IsHotSeatGame());
	LuaEvents.OnRecommendationCheckChanged( bIsChecked );
end
Controls.HideRecommendation:RegisterCheckHandler( OnRecommendationChecked );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged(iActivePlayer, iPrevActivePlayer)

	local mapOptions = GetMapOptions(iActivePlayer);
	ApplyMapOptions(mapOptions);
	UpdateOptionsPanel();
	
	if (not Controls.OptionsPanel:IsHidden()) then
		OnMapOptions();
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

--PopulateOverlayPulldown( Controls.OverlayDropDown );
--PopulateIconPulldown( Controls.IconDropDown );
UpdateOptionsPanel();
