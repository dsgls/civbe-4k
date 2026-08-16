-------------------------------------------------
-- Game View 
--
-- this is the parent of both WorldView and CityView
--
-- This is the final lua message handler that will be 
-- processed in the processing chain, after this is 
-- it is in engine side C++
-------------------------------------------------
include( "FLuaVector" );
include( "GameplayUtilities" );
include( "InstanceManager" );
include( "Bombardment");
include( "Planetfall");
include( "VoiceChatLogic" );

local g_InstanceManager = InstanceManager:new( "AlertMessageInstance", "AlertTop", Controls.AlertStack );
local g_PopupIM			= InstanceManager:new( "PopupText", "Anchor", Controls.PopupTextContainer );
local g_InstanceMap		= {};

local alertTable = {};
local mustRefreshAlerts = false;

local bHideDebug = true;
local g_ShowWorkerRecommendation = not Game.IsNetworkMultiPlayer();
local lastCityEntered = nil;
local lastCityEnteredPlot = nil;
local aWorkerSuggestHighlightPlots;
local aFounderSuggestHighlightPlots;
local aExpeditionSuggestHighlightPlots;
local bCityScreenOpen = false;
local bTechWebOpen = false;

local genericUnitHexBorder = "GUHB";
local pathBorderStyle = "MovementRangeBorder";
local attackPathBorderStyle = "AMRBorder"; -- attack move

local g_OrbitalCoverageStyle = "OrbitalCoverage";
local g_OrbitalCoverageStyleInactve = "OrbitalCoverageInactive";
local g_OrbitalRocktopusMarker = "OrbitalRocktopusMarker";
local g_OrbitalEffectSelfStyle = "OrbitalEffectSelf";
local g_OrbitalEffectOtherStyle = "OrbitalEffectOther";
local g_OrbitalEffectValidLaunchStyle = "OrbitalEffectValidLaunch";
local g_OrbitalEffectInvalidLaunchStyle = "OrbitalEffectInvalidLaunch";
local g_OrbitalParadropRangeStyle = "OrbitalParadropRange";

-- Event requires a color parameter, but many styles never use this color information
-- In that case, set the color in Highlights.xml
local g_OrbitalDefaultStyleColor = Vector4(0.2, 0.4, 0, 0.5);

local workerSuggestHighlightColor = Vector4( 0.0, 0.5, 1.0, 0.65 );

local InterfaceModeMessageHandler = 
{
	[InterfaceModeTypes.INTERFACEMODE_DEBUG] = {},
	[InterfaceModeTypes.INTERFACEMODE_SELECTION] = {},
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO] = {},
	[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO] = {},
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT] = {},
	[InterfaceModeTypes.INTERFACEMODE_PARADROP] = {},
	[InterfaceModeTypes.INTERFACEMODE_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK] = {},
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE] = {},
	[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP] = {},
	[InterfaceModeTypes.INTERFACEMODE_REBASE] = {},
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT] = {},
	[InterfaceModeTypes.INTERFACEMODE_EMBARK] = {},
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK] = {},
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT] = {},
	[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT] = {},
	[InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT] = {},
	[InterfaceModeTypes.INTERFACEMODE_PLANETFALL] = {},
};

local DefaultMessageHandler = {};

DefaultMessageHandler[KeyEvents.KeyDown] =
function( wParam, lParam )
	if( wParam == Keys.VK_ESCAPE ) then
		if (UI.IsInOrbitalView()) then
			Events.SerialEventSetOrbitalView( false );
		else
			Events.SerialEventShowInGameMenu();
		end
		return true;
    end
    return false;
end

function ShowInGameMenu()
	if( not UI.IsDiploActive() ) then
		Events.SerialEventRealizeInGameMenu();
		UIManager:QueuePopup( Controls.GameMenu, PopupPriority.InGameMenu );
	end
end
Events.SerialEventShowInGameMenu.Add( ShowInGameMenu );

DefaultMessageHandler[KeyEvents.KeyUp] =
function( wParam, lParam )

	-- Shift+H hides UI - Using Alpha as Show/Hide will stop messages from pumpin (e.g., will hide but not show again)
    if ( wParam == Keys.H and UI:ShiftKeyDown() and UI:DebugFlag() ) then 	
		local alpha = ContextPtr:GetAlpha();
		if ( alpha == 0 ) then alpha = 1; else alpha = 0; end
		ContextPtr:SetAlpha( alpha );
        return true;
	end

    if ( wParam == Keys.VK_OEM_3 and UI:ShiftKeyDown() and UI:DebugFlag() and PreGame.IsMultiplayerGame()) then -- shift - ~
        Controls.NetworkDebug:SetHide( not Controls.NetworkDebug:IsHidden() );
        return true;
        
	elseif ( wParam == Keys.VK_OEM_3 and UI:CtrlKeyDown() and UI:DebugFlag() and not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then -- ctrl - ~
        bHideDebug = not bHideDebug;
        Controls.DebugMenu:SetHide( bHideDebug );
        return true;
        
    elseif ( wParam == Keys.Z and UIManager:GetControl() and UI:DebugFlag() and not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then
        Game.ToggleDebugMode();
		local pPlot;
		local team = Game.GetActiveTeam();
		local bIsDebug = Game.IsDebugMode();

		for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
			pPlot = Map.GetPlotByIndex(iPlotLoop);

			if (pPlot:GetVisibilityCount() > 0) then
				pPlot:ChangeVisibilityCount(team, -1, -1, true, true);
			end
			pPlot:SetRevealed(team, false);

			pPlot:ChangeVisibilityCount(team, 1, -1, true, true);
			pPlot:SetRevealed(team, bIsDebug);
		end       
		return true;

	elseif ( wParam == Keys.O and UI:ShiftKeyDown() and not UI:CtrlKeyDown() and not UI:AltKeyDown()) then
		Events.SerialEventSetOrbitalView( true );
		return true;
    end
    return false;
end

-- add all of the Interface Mode specific handling

----------------------------------------------------------
----------------------------------------------------------

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLANETFALL][KeyEvents.KeyDown] =
function( wParam, lParam )
	if( wParam == Keys.VK_ESCAPE ) then
		-- don't allow escape key during planetfall
        return true;
    end
    return false;
end


InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.LButtonUp] = 
function( wParam, lParam )

	-- Give the strategic view a chance to process the click first
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	if plot then
		local bShift = UIManager:GetShift();
		local bAlt = UIManager:GetAlt();
		local bCtrl = UIManager:GetControl();
		UI.LocationSelect(plot, bCtrl, bAlt, bShift);
	end
	return true;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.PointerUp] = 
function( wParam, lParam )
	-- Just released the last pointer
	-- Only allow pan-to logic if not selected, otherwise double tapping to move a unit will
	-- pan the camera and, upon no longer panning, select the tile.
	if( UIManager:GetNumPointers() == 0 and UI.GetHeadSelectedUnit() == nil ) then
		local plot = Map.GetPlot( UI.GetMouseOverHex() );
		if plot then
			local bShift= UIManager:GetShift();
			local bAlt	= UIManager:GetAlt();
			local bCtrl	= UIManager:GetControl();
			UI.LocationSelect(plot, bCtrl, bAlt, bShift);
		end
		return true;
	end
	return false;
end



function EjectHandler( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	--print("INTERFACEMODE_PLACE_UNIT");
		
	local unit = UI.GetPlaceUnit();
	UI.ClearPlaceUnit();	
	local returnValue = false;
		
	if (unit ~= nil) then
		--print("INTERFACEMODE_PLACE_UNIT - got placed unit");
		local city = unitPlot:GetPlotCity();
		if (city ~= nil) then
			--print("INTERFACEMODE_PLACE_UNIT - not nil city");
			if UI.CanPlaceUnitAt(unit, plot) then
				--print("INTERFACEMODE_PLACE_UNIT - Can eject unit");
				--Network.SendCityEjectGarrisonChoice(city:GetID(), plotX, plotY);
				returnValue =  true;					
			end
		end
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	
	return returnValue;
end
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT][MouseEvents.LButtonUp] = EjectHandler;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT][MouseEvents.RButtonUp] = EjectHandler;
if (UI.IsTouchScreenEnabled()) then
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT][MouseEvents.PointerUp] = EjectHandler;
end

function GiftUnit( wParam, lParam )
	local returnValue = false;
	
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	
	local iToPlayer = UI.GetInterfaceModeValue();
	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];

	if (player == nil) then
		--print("Error - player index not correct");		
		return;	
	end
	
	
	local pUnit = nil;
    local unitCount = plot:GetNumUnits();
    
    for i = 0, unitCount - 1, 1
    do
    	local pFoundUnit = plot:GetUnit(i);
		if (pFoundUnit:GetOwner() == iPlayerID) then
			pUnit = pFoundUnit;
		end
    end
		
	if (pUnit) then
		
		if (pUnit:CanDistanceGift(iToPlayer)) then
			
			--print("Picked unit");
			returnValue = true;
			
			--print("iPlayerID " .. iPlayerID);
			--print("Other player id (interfacemodevalue) " .. UI.GetInterfaceModeValue());
			--print("UnitID " .. pUnit:GetID());
			
			local popupInfo = {
				Type = ButtonPopupTypes.BUTTONPOPUP_GIFT_CONFIRM,
				Data1 = iPlayerID;
				Data2 = iToPlayer;
				Data3 = pUnit:GetID();
			}
			Events.SerialEventGameMessagePopup(popupInfo);
		end
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	
	return returnValue;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT][MouseEvents.LButtonUp] = GiftUnit;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT][MouseEvents.RButtonUp] = GiftUnit;
if (UI.IsTouchScreenEnabled()) then
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT][MouseEvents.PointerUp] = GiftUnit;
end

function AttackIntoTile( wParam, lParam)
	--print("Calling attack into tile");
	local returnValue = false;
	
	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];

	if (player == nil) then
		--print("Error - player index not correct");		
		return;	
	end
	
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();	

	local pUnit = UI.GetHeadSelectedUnit();
	
	if (plot:IsVisible(player:GetTeam(), false) and (plot:IsVisibleEnemyUnit(pUnit) or plot:IsEnemyCity(pUnit))) then
		Game.SelectionListMove(plot, false, false, false);
		returnValue = true;
	end
    
	ClearUnitHexHighlights();
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return returnValue;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ATTACK][MouseEvents.LButtonUp] = AttackIntoTile;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ATTACK][MouseEvents.RButtonUp] = AttackIntoTile;
if (UI.IsTouchScreenEnabled()) then
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ATTACK][MouseEvents.PointerUp] = AttackIntoTile;
end
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT][MouseEvents.LButtonUp] = GiftTileImprovement;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT][MouseEvents.RButtonUp] = GiftTileImprovement;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT][MouseEvents.PointerUp] = GiftTileImprovement;
----------------------------------------------------------------        
-- Input handling
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	local interfaceMode = UI.GetInterfaceMode();
	local currentInterfaceModeHandler = InterfaceModeMessageHandler[interfaceMode];
	if currentInterfaceModeHandler and currentInterfaceModeHandler[uiMsg] then
		return currentInterfaceModeHandler[uiMsg]( wParam, lParam );
	elseif DefaultMessageHandler[uiMsg] then
		if( DefaultMessageHandler[uiMsg]( wParam, lParam ) ) then
			return true;
		end
	end
	return VoiceChatInputHandler( uiMsg, wParam, lParam ); 
end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------
-------------------------------------------------
function SetRecommendationCheck(value)	
	-- Value is true if recommendations are hidden.
	g_ShowWorkerRecommendation = not value;
	OnUpdateSelection( value );
end
LuaEvents.OnRecommendationCheckChanged.Add( SetRecommendationCheck );

----------------------------------------------------------------        
---------------------------------------------------------------- 
function OnGameOptionsChanged()
	local value = not OptionsManager.IsNoTileRecommendations();
	g_ShowWorkerRecommendation = value;
	OnUpdateSelection( value );
end
Events.GameOptionsChanged.Add(OnGameOptionsChanged);

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnEnterCityScreen()

    Controls.UnitFlagManager:SetHide( true );
    Controls.ImprovementSiteFlagManager:SetHide( true );
    Controls.CityBannerManager:SetHide( true );
    
	lastCityEntered = UI.GetHeadSelectedCity();

    if( lastCityEntered ~= nil ) then
		lastCityEnteredPlot = lastCityEntered:Plot();
        Events.RequestYieldDisplay( YieldDisplayTypes.CITY_WORKED, lastCityEntered:GetX(), lastCityEntered:GetY() );
    else
		lastCityEnteredPlot = nil;
    end
    Controls.CityView:SetHide( false );
    Controls.WorldView:SetHide( true );

	if (aWorkerSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aWorkerSuggestHighlightPlots) do
			if (v.plot ~= nil) then
				local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
				Events.SerialEventHexHighlight( hexID, false, workerSuggestHighlightColor, genericUnitHexBorder );
				Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, false, v.plot:GetX(), v.plot:GetY(), v.buildType );
			end
		end
	end

	if (aFounderSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aFounderSuggestHighlightPlots) do
			local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
			Events.SerialEventHexHighlight( hexID, false, workerSuggestHighlightColor, genericUnitHexBorder );
			Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, false, v:GetX(), v:GetY(), -1 );
		end
	end

	if (aExpeditionSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aExpeditionSuggestHighlightPlots) do
			local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
			Events.SerialEventHexHighlight( hexID, false, workerSuggestHighlightColor, genericUnitHexBorder );
			Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_EXPLORER, false, v:GetX(), v:GetY(), -1 );
		end
	end

	-- Grid is always shown in city screen (even if user currently has it off).
	if (not OptionsManager.GetGridOn()) then
		Events.SerialEventHexGridOn();
	end
	
	bCityScreenOpen = true;
	StopScrolling();
	
	--UI.LookAt(lastCityEntered:Plot(), 1);
	
end
Events.SerialEventEnterCityScreen.Add( OnEnterCityScreen );


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnExitCityScreen()

	Controls.UnitFlagManager:SetHide( false );
	Controls.ImprovementSiteFlagManager:SetHide( false );
    Controls.CityBannerManager:SetHide( false );

    RequestYieldDisplay();
	
    Controls.CityView:SetHide( true );
    Controls.WorldView:SetHide( false );

	-- Player can disable tile recommendations
	if (not OptionsManager.IsNoTileRecommendations()) then
		if (aWorkerSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aWorkerSuggestHighlightPlots) do
				if (v.plot ~= nil) then
					local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
					if(g_ShowWorkerRecommendation) then
						Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, true, v.plot:GetX(), v.plot:GetY(), v.buildType );
					end
				end
			end
		end
		    
		if (aFounderSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aFounderSuggestHighlightPlots) do
				local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
				if(g_ShowWorkerRecommendation) then
					Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, true, v:GetX(), v:GetY(), -1 );
				end
			end
		end

		if (aExpeditionSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aExpeditionSuggestHighlightPlots) do
				local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
				if(g_ShowWorkerRecommendation) then
					Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_EXPLORER, true, v:GetX(), v:GetY(), -1 );
				end
			end
		end
    end

	-- Grid is hidden when leaving the city screen (unless the user had it turned on
	-- when entering the city screen).
	if (not OptionsManager.GetGridOn()) then
		Events.SerialEventHexGridOff();
	end

	ClearAllHighlights();
	
	if lastCityEnteredPlot then
		UI.LookAt(lastCityEnteredPlot, 2);
	end
	
	UI.ClearSelectedCities();
	lastCityEntered = nil;
	bCityScreenOpen = false;
	
	UI.SetDirty(InterfaceDirtyBits.GameData_DIRTY_BIT, true);
end
Events.SerialEventExitCityScreen.Add( OnExitCityScreen );

----------------------------------------------------------------        
----------------------------------------------------------------  
function OnTechTreeToggled( enabled ) 
	bTechWebOpen = enabled;
	if(bTechWebOpen) then
		StopScrolling();
	end
end
Events.SerialEventToggleTechWeb.Add( OnTechTreeToggled );

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnGameplayAlertMessage( data )
	local newAlert = {};
	newAlert.text = data;
	newAlert.elapsedTime = 0;
	newAlert.shownYet = false;
	table.insert(alertTable,newAlert);
	mustRefreshAlerts = true;
end
Events.GameplayAlertMessage.Add( OnGameplayAlertMessage );

----------------------------------------------------------------        
-- Allow Lua to do any post and pre-processing of the InterfaceMode change
----------------------------------------------------------------       

-- add any functions that you want to have called to the handler table
local giftUnitColor = Vector4( 1.0, 1.0, 0.0, 0.65 );

function HighlightGiftUnits ()
	
	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];
	
	if (player == nil) then
		--print("Error - player index not correct");		
		return;	
	end
	
	local iToPlayer = UI.GetInterfaceModeValue();
	
	--print("iToPlayer: " .. iToPlayer);
	
	for unit in player:Units() do
		if (unit:CanDistanceGift(iToPlayer)) then
			local hexID = ToHexFromGrid( Vector2( unit:GetX(), unit:GetY() ) );
			Events.SerialEventHexHighlight( hexID, true, Vector4( 1.0, 1.0, 0.0, 1 ), genericUnitHexBorder );
		end
	end
    
end


local embarkColor = Vector4( 1.0, 1.0, 0.0, 0.65 );

function HighlightEmbarkPlots()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local checkFunction = nil;
	if unit:IsEmbarked() then
		checkFunction = function(targetPlot) 
			return unit:CanDisembarkOnto(targetPlot) 
		end;
	else
		checkFunction = function(targetPlot)
			return unit:CanEmbarkOnto(unit:GetPlot(), targetPlot);
		end;
	end
	
	local unitTeam = unit:GetTeam();
	local unitX = unit:GetX();
	local unitY = unit:GetY();
	
	local iRange = 1;
	for iX = -iRange, iRange, 1 do
		for iY = -iRange, iRange, 1 do
			local evalPlot = Map.PlotXYWithRangeCheck(unitX, unitY, iX, iY, iRange);
			if evalPlot then
				local evalPlotX = evalPlot:GetX();
				local evalPlotY = evalPlot:GetY();
				if evalPlotX ~= unitX or evalPlotY ~= unitY then -- we are looking at a different plot than us
					if evalPlot:IsRevealed(unitTeam, false) then
						if checkFunction(evalPlot) then -- tricky
							local hexID = ToHexFromGrid( Vector2( evalPlotX, evalPlotY ) );
							Events.SerialEventHexHighlight( hexID, true, embarkColor, genericUnitHexBorder );
						end
					end
				end
			end
		end
	end
end

local upgradeColor = Vector4( 0.0, 1.0, 0.5, 0.65 );

function HighlightUpgradePlots()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local unitX = unit:GetX();
	local unitY = unit:GetY();

	for thisDirection = 0, (DirectionTypes.NUM_DIRECTION_TYPES-1), 1 do
		local adjacentPlot = Map.PlotDirection(unitX, unitY, thisDirection);
		if (adjacentPlot) then
			local adjacentUnit = unit:GetUpgradeUnitFromPlot(adjacentPlot);
			if adjacentUnit then
				local hexID = ToHexFromGrid( Vector2( adjacentPlot:GetX(), adjacentPlot:GetY() ) );
				Events.SerialEventHexHighlight( hexID, true, upgradeColor, genericUnitHexBorder );
			end
		end
	end
end

function ClearAllHighlights()
	--Events.ClearHexHighlights(); other systems might be using these!
	Events.ClearHexHighlightStyle("");
	ClearUnitHexHighlights();
end

function ClearUnitHexHighlights()
	Events.ClearHexHighlightStyle(pathBorderStyle);
	Events.ClearHexHighlightStyle(attackPathBorderStyle);
	Events.ClearHexHighlightStyle(genericUnitHexBorder);  
	Events.ClearHexHighlightStyle("FireRangeBorder");
	Events.ClearHexHighlightStyle("RebaseMarker");
	Events.ClearHexHighlightStyle("ValidFireTargetBorder");
	Events.ClearHexHighlightStyle("PlanetfallRange");
	ClearOrbitalHighlights();
end

function ClearOrbitalHighlights()
	Events.ClearHexHighlightStyle(g_OrbitalCoverageStyle);
	Events.ClearHexHighlightStyle(g_OrbitalCoverageStyleInactve);
	Events.ClearHexHighlightStyle(g_OrbitalRocktopusMarker);
	Events.ClearHexHighlightStyle(g_OrbitalEffectSelfStyle);
	Events.ClearHexHighlightStyle(g_OrbitalEffectOtherStyle);
	Events.ClearHexHighlightStyle(g_OrbitalParadropRangeStyle);
	ClearOrbitalPlacementHighlights();
end

function ClearOrbitalPlacementHighlights()
	Events.ClearHexHighlightStyle(g_OrbitalEffectValidLaunchStyle);
	Events.ClearHexHighlightStyle(g_OrbitalEffectInvalidLaunchStyle);
end

function ShowMovementRangeIndicator()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local iPlayerID = Game.GetActivePlayer();

	Events.ShowMovementRange( iPlayerID, unit:GetID() );
	UI.SendPathfinderUpdate();
	Events.DisplayMovementIndicator( true );
end

function HideMovementRangeIndicator()
	ClearUnitHexHighlights();
	Events.DisplayMovementIndicator( false );
end


function ShowRebaseRangeIndicator()
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local iRange= pHeadSelectedUnit:Range();
	
	--print("iRange: " .. iRange);
	
	iRange = iRange * GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER;
	iRange = iRange / 100;

	--print("iRange: " .. iRange);
	
	local thisPlot = pHeadSelectedUnit:GetPlot();
	local thisX = pHeadSelectedUnit:GetX();
	local thisY = pHeadSelectedUnit:GetY();
	
	for iDX = -iRange, iRange, 1 do
		for iDY = -iRange, iRange, 1 do
			local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
			if pTargetPlot ~= nil then
				local plotX = pTargetPlot:GetX();
				local plotY = pTargetPlot:GetY();
				local plotDistance = Map.PlotDistance(thisX, thisY, plotX, plotY);
				if plotDistance <= iRange then
					local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
					--Events.SerialEventHexHighlight( hexID, true, g_turn1Color, pathBorderStyle );
					if pHeadSelectedUnit:CanRebaseAt(thisPlot,plotX,plotY) then
						Events.SerialEventHexHighlight( hexID, true, g_turn2Color, "RebaseMarker" );
					end
				end
			end
		end
	end

end

function HideRebaseRangeIndicator()
	ClearUnitHexHighlights();
end


function ShowParadropRangeIndicator()
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local thisPlot = pHeadSelectedUnit:GetPlot();
	if pHeadSelectedUnit:CanParadrop(thisPlot, false) then

		local tPlots = Players[pHeadSelectedUnit:GetOwner()]:GetParadropCapabilityPlots();
		for i, tPlot in ipairs(tPlots) do
			if (tPlot ~= nil) then
				local targetPlot = Map.GetPlotByIndex(tPlot.Index);
				if (targetPlot ~= nil and pHeadSelectedUnit:CanParadropAt(thisPlot, targetPlot:GetX(), targetPlot:GetY())) then
					local hexID = ToHexFromGrid(Vector2(targetPlot:GetX(), targetPlot:GetY()));
					Events.SerialEventHexHighlight(hexID, true, g_OrbitalDefaultStyleColor, g_OrbitalParadropRangeStyle);
				end
			end
		end
	end
end

function HideParadropRangeIndicator()
	ClearUnitHexHighlights();
end

function ShowAirliftRangeIndicator()

	--print ("In ShowAirliftRangeIndicator()");
	
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local thisPlot = pHeadSelectedUnit:GetPlot();
	if pHeadSelectedUnit:CanAirlift(thisPlot, false) then		
		for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
			pPlot = Map.GetPlotByIndex(iPlotLoop);
			local plotX = pPlot:GetX();
			local plotY = pPlot:GetY();
			if pHeadSelectedUnit:CanAirliftAt(thisPlot, plotX, plotY) then
				local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
				Events.SerialEventHexHighlight( hexID, true, g_turn1Color, pathBorderStyle );
			end
		end
	end
end

function HideAirliftRangeIndicator()
	--print ("In HideAirliftRangeIndicator()");
	
	ClearUnitHexHighlights();
end

function ShowAttackTargetsIndicator()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end;
	
	local iPlayerID = Game.GetActivePlayer();
	Events.ShowAttackTargets(iPlayerID, unit:GetID());
end


local vGiftTileImprovementColor = Vector4( 1.0, 0.0, 1.0, 1.0 );

function HighlightImprovableCityStatePlots()
	local iFromPlayer = Game.GetActivePlayer();
	local iToPlayer = UI.GetInterfaceModeValue();
	local pToPlayer = Players[iToPlayer];
	if (pToPlayer == nil) then
		--print("Error - pToPlayer is nil");
		return;
	end
	
	--print("iToPlayer: " .. iToPlayer);
	
	local pCityStateCity = Players[iToPlayer]:GetCapitalCity()
	if (pCityStateCity == nil) then
		--print("Error - pCityStateCity is nil");
		return;
	end
	
	local iCityStateX = pCityStateCity:GetX();
	local iCityStateY = pCityStateCity:GetY();
	
	local iRange = GameDefines["MINOR_CIV_RESOURCE_SEARCH_RADIUS"];
	for iX = -iRange, iRange, 1 do
		for iY = -iRange, iRange, 1 do
			local pPlot = Map.PlotXYWithRangeCheck(iCityStateX, iCityStateY, iX, iY, iRange);
			if (pPlot) then
				local iPlotX = pPlot:GetX();
				local iPlotY = pPlot:GetY();
				if (pToPlayer:CanMajorGiftTileImprovementAtPlot(iFromPlayer, iPlotX, iPlotY)) then
					local iHexID = ToHexFromGrid( Vector2( iPlotX, iPlotY) );
					Events.SerialEventHexHighlight( iHexID, true, vGiftTileImprovementColor, genericUnitHexBorder );
				end
			end
		end
	end
end

local vPossibleTradeRouteColor = Vector4( 1.0, 0.0, 1.0, 1.0 );

function HighlightPossibleTradeCities()
	--print("HighlightPossibleTradeCities");
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if not pHeadSelectedUnit then
		return;
	end
	
	local iActivePlayer = Game.GetActivePlayer();
	local pActivePlayer = Players[iActivePlayer];
	local thisPlot = pHeadSelectedUnit:GetPlot();
	if pHeadSelectedUnit:CanMakeTradeRoute(thisPlot, false) then

		local potentialTradeSpots = pActivePlayer:GetUnitAvailableTradeRoutes(pHeadSelectedUnit);
		for i,v in ipairs(potentialTradeSpots) do

			if pHeadSelectedUnit:CanMakeTradeRouteAt(thisPlot, v.X, v.Y) then

				local hexID = ToHexFromGrid( Vector2( v.X, v.Y) );
				Events.SerialEventHexHighlight( hexID, true, vPossibleTradeRouteColor, genericUnitHexBorder );
			end
		end
	end
end

function EnterOrbitalView()
	-- Show our coverage
	HighlightOrbitalCoveragePlots();

	-- Show all orbital units
	local iActivePlayer = Game.GetActivePlayer();
	for iPlayer = 0, GameDefines.MAX_PLAYERS do
		local player = Players[iPlayer];
		if (player ~= nil) then
			for unit in player:Units() do
				if (unit:IsInOrbit()) then
					local plotStyles = {};
					if (unit:GetOwner() == iActivePlayer) then
						table.insert(plotStyles, g_OrbitalEffectSelfStyle);
					else
						table.insert(plotStyles, g_OrbitalEffectOtherStyle);
					end
					HighlightOrbitalEffectPlots(unit, unit:GetX(), unit:GetY(), g_OrbitalDefaultStyleColor, plotStyles, nil);
				end
			end
		end
	end
end

function ExitOrbitalView()
	if (UI.GetInterfaceMode() ~= InterfaceModeTypes.INTERFACEMODE_PLANETFALL) then
		ClearUnitHexHighlights();
	end
	if (UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	end
end

function RefreshOrbitalView()
	if (UI.IsInOrbitalView()) then
		ClearOrbitalHighlights();
		EnterOrbitalView();
	end
	local mousePlot = Map.GetPlot(UI.GetMouseOverHex());
	if(mousePlot ~= nil) then
		OnMouseOverHex(mousePlot:GetX(), mousePlot:GetY());
	end
end
Events.SerialEventGameDataDirty.Add(RefreshOrbitalView);
Events.SerialEventHexGridOn.Add(RefreshOrbitalView);
Events.SerialEventHexGridOff.Add(RefreshOrbitalView);

function HighlightOrbitalEffectPlots(unit, centerX, centerY, highlightColor, plotStyles, overlapStyles)
	if (not unit) then
		return;
	end
	local iRange = unit:GetOrbitalEffectRange();
	if (iRange < 0) then
		return;
	end

	for iX = -iRange, iRange, 1 do
		for iY = -iRange, iRange, 1 do
			local pPlot = Map.PlotXYWithRangeCheck(centerX, centerY, iX, iY, iRange);
			if (pPlot) then
				local iPlotX = pPlot:GetX();
				local iPlotY = pPlot:GetY();
				iHexID = ToHexFromGrid( Vector2( iPlotX, iPlotY) );
				if (plotStyles ~= nil) then
					for i,style in ipairs(plotStyles) do
						Events.SerialEventHexHighlight(iHexID, true, highlightColor, style);
					end
				end
				if (pPlot:HasInfluencingOrbitalUnit() and overlapStyles ~= nil) then
					for i,style in ipairs(overlapStyles) do
						Events.SerialEventHexHighlight(iHexID, true, highlightColor, style);
					end
				end
			end
		end
	end
end

function HighlightOrbitalCoveragePlots()
	local selectedUnit = UI.GetHeadSelectedUnit();
	local selectedUnitOrbitalInfo = nil;
	if (selectedUnit ~= nil and selectedUnit:IsOrbitalUnit()) then
		selectedUnitOrbitalInfo = GameInfo.OrbitalUnits[selectedUnit:GetOrbitalUnitType()];
	end
			
	local tPlots = Players[Game.GetActivePlayer()]:GetOrbitalCoveragePlots();
	for i, tPlot in ipairs(tPlots) do
		if (tPlot ~= nil) then
			local plot = Map.GetPlotByIndex(tPlot.Index);
			if (plot ~= nil) then
				local hexID = ToHexFromGrid(Vector2(plot:GetX(), plot:GetY()));
				-- For a selected unit that can only launch straight above itself, draw a special highlight instead of normal coverage
				if (selectedUnit ~= nil and selectedUnitOrbitalInfo ~= nil and selectedUnitOrbitalInfo.FloatsIntoOrbit) then
					if (selectedUnit:GetX() == plot:GetX() and selectedUnit:GetY() == plot:GetY()) then
						Events.SerialEventHexHighlight(hexID, true, g_OrbitalDefaultStyleColor, g_OrbitalRocktopusMarker);
					else
						Events.SerialEventHexHighlight(hexID, true, g_OrbitalDefaultStyleColor, g_OrbitalCoverageStyleInactve);
					end
				else
					Events.SerialEventHexHighlight(hexID, true, g_OrbitalDefaultStyleColor, g_OrbitalCoverageStyle);
				end
			end
		end
	end
end

--function EnterCityPlotSelection()
    --if( lastCityEntered ~= nil ) then
		--Events.RequestYieldDisplay( YieldDisplayTypes.CITY_OWNED, lastCityEntered:GetX(), lastCityEntered:GetY() );
	--end
--end
--
--function ExitCityPlotSelection()
	--if( lastCityEntered ~= nil ) then
		--Events.RequestYieldDisplay( YieldDisplayTypes.CITY_WORKED, lastCityEntered:GetX(), lastCityEntered:GetY() );
	--end
--end
--
-- don't actually add the nils to the table
local OldInterfaceModeChangeHandler = 
{
	--[InterfaceModeTypes.INTERFACEMODE_DEBUG] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_SELECTION] = nil,
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO] = HideMovementRangeIndicator,
	--[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO] = nil,
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT] = HideAirliftRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_PARADROP] = HideParadropRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_ATTACK] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK] = EndRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK] = EndRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK] = EndOrbitalAttack,
	[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK] = EndOrbitalAttack,
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE] = EndAirAttack,
	[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP] = EndAirSweep,
	[InterfaceModeTypes.INTERFACEMODE_REBASE] = HideRebaseRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_EMBARK] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT] = ClearUnitHexHighlights,
	--[InterfaceModeTypes.INTERFACEMODE_CITY_PLOT_SELECTION] = ExitCityPlotSelection
	[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT] = function() Events.SerialEventSetOrbitalView(false, false); end,
	[InterfaceModeTypes.INTERFACEMODE_PLANETFALL] = EndPlanetfall,
};

local NewInterfaceModeChangeHandler = 
{
	--[InterfaceModeTypes.INTERFACEMODE_DEBUG] = nil,
	[InterfaceModeTypes.INTERFACEMODE_SELECTION] = ClearUnitHexHighlights,
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO] = ShowMovementRangeIndicator,
	--[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_TYPE] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_MOVE_TO_ALL] = nil,
	--[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO] = nil,
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT] = ShowAirliftRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_PARADROP] = ShowParadropRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_ATTACK] = ShowAttackTargetsIndicator,
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK] = BeginRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK] = BeginRangedAttack,
	[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK] = BeginOrbitalAttack,
	[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK] = BeginOrbitalAttack,
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE] = BeginAirAttack,
	[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP] = BeginAirSweep,
	[InterfaceModeTypes.INTERFACEMODE_REBASE] = ShowRebaseRangeIndicator,
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT] = nil, -- this actually has some special case code with it in CityBannerManager and/or CityView
	[InterfaceModeTypes.INTERFACEMODE_EMBARK] = HighlightEmbarkPlots,
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK] = HighlightEmbarkPlots,
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT] = HighlightGiftUnits,
	--[InterfaceModeTypes.INTERFACEMODE_CITY_PLOT_SELECTION] = EnterCityPlotSelection
	[InterfaceModeTypes.INTERFACEMODE_GIFT_TILE_IMPROVEMENT] = HighlightImprovableCityStatePlots,
	[InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT] = function() Events.SerialEventSetOrbitalView(false, true); end,
	[InterfaceModeTypes.INTERFACEMODE_PLANETFALL] = BeginPlanetfall,
};

local defaultCursor = GameInfoTypes[GameInfo.InterfaceModes[InterfaceModeTypes.INTERFACEMODE_SELECTION].CursorType];

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnInterfaceModeChanged( oldInterfaceMode, newInterfaceMode)
	--print("OnInterfaceModeChanged");
	--print("oldInterfaceMode: " .. oldInterfaceMode);
	--print("newInterfaceMode: " .. newInterfaceMode);
	if (oldInterfaceMode ~= newInterfaceMode) then
		-- do any cleanup of the old mode
		local oldInterfaceModeHandler = OldInterfaceModeChangeHandler[oldInterfaceMode];
		if oldInterfaceModeHandler then
			oldInterfaceModeHandler();
		end
		
		-- update the cursor to reflect this mode - these cursor are defined in CivBECursorInfo.xml
		local cursorIndex = GameInfoTypes[GameInfo.InterfaceModes[newInterfaceMode].CursorType];
		if cursorIndex then
			UIManager:SetUICursor(cursorIndex);
		else
			UIManager:SetUICursor(defaultCursor);
		end
		
		-- do any setup for the new mode
		local newInterfaceModeHandler = NewInterfaceModeChangeHandler[newInterfaceMode];
		if newInterfaceModeHandler then
			newInterfaceModeHandler();
		end
	end
	RefreshOrbitalView();
end
Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );

----------------------------------------------------------------
----------------------------------------------------------------
function OnSetOrbitalView()
	if (UI.IsInOrbitalView()) then
		EnterOrbitalView();
	else
		ExitOrbitalView();
	end
end
Events.SerialEventSetOrbitalView.Add(OnSetOrbitalView);

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnActivePlayerTurnEnd()
	UIManager:SetUICursor(1); -- busy
end
Events.ActivePlayerTurnEnd.Add( OnActivePlayerTurnEnd );

function OnActivePlayerTurnStart()
	local interfaceMode = UI.GetInterfaceMode();
	local cursorIndex = GameInfoTypes[GameInfo.InterfaceModes[interfaceMode].CursorType];
	if cursorIndex then
		UIManager:SetUICursor(cursorIndex);
	else
		UIManager:SetUICursor(defaultCursor);
	end

	-- Check to see if we need to switch to the planetfall interface mode.
	local pActivePlayer	= Players[Game.GetActivePlayer()];
	if(not pActivePlayer:IsObserver() 
		and pActivePlayer:IsAlive() 
		and not pActivePlayer:IsFoundedFirstCity()
		and pActivePlayer:IsTurnActive() 
		and UI.GetInterfaceMode() ~= InterfaceModeTypes.INTERFACEMODE_PLANETFALL) then 
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_PLANETFALL);
	end	
end
Events.ActivePlayerTurnStart.Add( OnActivePlayerTurnStart );

local g_PerPlayerOrbitalViewSettings = {}
----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged(iActivePlayer, iPrevActivePlayer)

	-- Reset the alert table and display
	alertTable = {};
	g_InstanceManager:ResetInstances();	
	KillAllPopupText();
	mustRefreshAlerts = false;	

	if (iPrevActivePlayer ~= -1) then
		g_PerPlayerOrbitalViewSettings[ iPrevActivePlayer + 1 ] = UI.IsInOrbitalView();
	end

	if (iActivePlayer ~= -1 ) then
		if (g_PerPlayerOrbitalViewSettings[ iActivePlayer + 1] and not UI.IsInOrbitalView()) then
			Events.SerialEventSetOrbitalView( true );
		else
			if (not g_PerPlayerOrbitalViewSettings[ iActivePlayer + 1] and UI.IsInOrbitalView()) then
				Events.SerialEventSetOrbitalView( false );
			end
		end
	end

	HideMovementRangeIndicator();

end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUnitSelectionChange( p, u, i, j, k, isSelected )
	local interfaceMode = UI.GetInterfaceMode();
	if interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK and interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK and not UI.IsInOrbitalView() then -- this is a bit hacky, but the order of event processing is what it is
		ClearUnitHexHighlights();
	end
	if interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_SELECTION and interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK  and interfaceMode ~= InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	end
	OnUpdateSelection( isSelected );
end
Events.UnitSelectionChanged.Add( OnUnitSelectionChange );

function OnMouseOverHex(x, y)
	if (UI.GetInterfaceMode() == InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT) then
		ClearOrbitalPlacementHighlights();
		local iPlayerID = Game.GetActivePlayer();
		local player = Players[iPlayerID];
		local unit = UI.GetHeadSelectedUnit();
		local plotStyles = {};
		local overlapStyles = {};
		if (unit:CanLaunchIntoOrbitTo(x, y)) then
			table.insert(plotStyles, g_OrbitalEffectValidLaunchStyle);
		else
			table.insert(plotStyles, g_OrbitalEffectInvalidLaunchStyle);
		end
		HighlightOrbitalEffectPlots(unit, x, y, g_OrbitalDefaultStyleColor, plotStyles, overlapStyles);
	end
end
Events.SerialEventMouseOverHex.Add(OnMouseOverHex);

function OnUpdateSelection( isSelected )
    RequestYieldDisplay();	
	RefreshOrbitalView();

	local iPlayerID = Game.GetActivePlayer();
	local player = Players[iPlayerID];

	--print("Unit selection changed!");

	-- workers - clear old list first
	if (aWorkerSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aWorkerSuggestHighlightPlots) do
			if (v.plot ~= nil) then
				local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
				Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, false, v.plot:GetX(), v.plot:GetY(), v.buildType );
			end
		end
	end	
	aWorkerSuggestHighlightPlots = nil;
		
	-- founders - clear old list first
	if (aFounderSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aFounderSuggestHighlightPlots) do
			local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
			Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, false, v:GetX(), v:GetY(), -1 );
		end
	end	
	aFounderSuggestHighlightPlots = nil;

	-- explorers - clear old list first
	if (aExpeditionSuggestHighlightPlots ~= nil) then
		for i, v in ipairs(aExpeditionSuggestHighlightPlots) do
			local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
			Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_EXPLORER, false, v:GetX(), v:GetY(), -1 );
		end
	end
	aExpeditionSuggestHighlightPlots = nil;
		
	if isSelected ~= true then
		return
	end

	if (UI.CanSelectionListWork()) then
		aWorkerSuggestHighlightPlots = player:GetRecommendedWorkerPlots();
		aExpeditionSuggestHighlightPlots = player:GetRecommendedExpeditionPlots();

		-- Player can disable tile recommendations
		if (not OptionsManager.IsNoTileRecommendations()) then
			for i, v in ipairs(aWorkerSuggestHighlightPlots) do
				if (v.plot ~= nil) then
					local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
					if(g_ShowWorkerRecommendation) then
						Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, true, v.plot:GetX(), v.plot:GetY(), v.buildType );
					end
				end
			end

			if (aExpeditionSuggestHighlightPlots ~= nil) then
				for i, v in ipairs(aExpeditionSuggestHighlightPlots) do
					local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
					if (g_ShowWorkerRecommendation) then
						Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_EXPLORER, true, v:GetX(), v:GetY(), -1 );
					end
				end
			end
		end
	end
		
	if (UI.CanSelectionListFound() and player:GetNumCities() > 0) then
		if(g_ShowWorkerRecommendation) then
			aFounderSuggestHighlightPlots = player:GetRecommendedFoundCityPlots();
			--print("Founder check");
			--print("aFounderSuggestHighlightPlots " .. tostring(aFounderSuggestHighlightPlots));
		
			-- Player can disable tile recommendations
			if (not OptionsManager.IsNoTileRecommendations()) then
				for i, v in ipairs(aFounderSuggestHighlightPlots) do
					--print("founder highlight x: " .. v:GetX() .. " y: " .. v:GetY());
					local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
					Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, true, v:GetX(), v:GetY(), -1 );
				end
			end
		end
	end
end
----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUnitSelectionCleared()

    RequestYieldDisplay();	

	if (not UI.CanSelectionListWork()) then
		-- Clear Worker recommendations
		if (aWorkerSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aWorkerSuggestHighlightPlots) do
				if (v.plot ~= nil) then
					local hexID = ToHexFromGrid( Vector2( v.plot:GetX(), v.plot:GetY() ) );
					Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER, false, v.plot:GetX(), v.plot:GetY(), v.buildType );
				end
			end
		end	
		aWorkerSuggestHighlightPlots = nil;

		-- Clear Explorer Recommendations
		if (aExpeditionSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aExpeditionSuggestHighlightPlots) do
				local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
				Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_EXPLORER, false, v:GetX(), v:GetY(), -1 );
			end
		end
		aExpeditionSuggestHighlightPlots = nil;
	end
	
	-- Clear Settler Recommendations
	if (not UI.CanSelectionListFound()) then
		if (aFounderSuggestHighlightPlots ~= nil) then
			for i, v in ipairs(aFounderSuggestHighlightPlots) do
				local hexID = ToHexFromGrid( Vector2( v:GetX(), v:GetY() ) );
				Events.GenericWorldAnchor( GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER, false, v:GetX(), v:GetY() );
			end
		end	
		aFounderSuggestHighlightPlots = nil;
	end
end
Events.UnitSelectionCleared.Add( OnUnitSelectionCleared );

-------------------------------------------------
-- On Unit Destroyed
-------------------------------------------------
function OnUnitDestroyed( playerID, unitID )
    if( playerID == Game.GetActivePlayer() ) then
        RequestYieldDisplay();
    end
end
Events.SerialEventUnitDestroyed.Add( OnUnitDestroyed );

------------------------------------------------------------------------------     
-- The alert messages that appear in the upper center of the screen
------------------------------------------------------------------------------
function OnUpdate(fDTime)
	
	local secondsToShowAlert = 8;

	if #alertTable > 0 then
		for i, v in ipairs( alertTable ) do
			if v.shownYet == true then
				v.elapsedTime = v.elapsedTime + fDTime;
			end
			if v.elapsedTime >= secondsToShowAlert then
				mustRefreshAlerts = true;
			end
		end

		if mustRefreshAlerts then
			local newAlertTable = {};
			g_InstanceManager:ResetInstances();
			for i, v in ipairs( alertTable ) do
				if v.elapsedTime < secondsToShowAlert then
					v.shownYet = true;
					table.insert( newAlertTable, v );
				end
			end
			alertTable = newAlertTable;
			for i, v in ipairs( alertTable ) do
				local controlTable = g_InstanceManager:GetInstance();
				controlTable.AlertMessageLabel:SetText( v.text );
				local sizeX = controlTable.AlertMessageLabel:GetSizeX();
				controlTable.AlertTop:SetSizeX( sizeX );
			end
			Controls.AlertStack:CalculateSize();				
			Controls.AlertContainer:ReprocessAnchoring();
			Controls.AlertStack:ReprocessAnchoring();

		end

	end
	
	mustRefreshAlerts = false;
end
ContextPtr:SetUpdate( OnUpdate );

-- This will be used to identify the instance when it comes time to remove it from the screen.
local g_PopupInstanceNumber = 1;
----------------------------------------------------------------        
----------------------------------------------------------------        
function AddPopupText( worldPosition, text, delay )
    local instance = g_PopupIM:GetInstance();
    instance.Anchor:SetWorldPosition( worldPosition );
    instance.Text:SetText( text );
    instance.AlphaAnimOut:RegisterAnimCallback( KillPopupText );
	instance.AlphaAnimOut:SetVoid1( g_PopupInstanceNumber );
    instance.Anchor:BranchResetAnimation();
    instance.SlideAnim:SetPauseTime( delay );
    instance.AlphaAnimIn:SetPauseTime( delay );
    instance.AlphaAnimOut:SetPauseTime( delay + 0.75 );
    
    g_InstanceMap[ g_PopupInstanceNumber ] = instance;

	g_PopupInstanceNumber = g_PopupInstanceNumber + 1;
end
Events.AddPopupTextEvent.Add( AddPopupText );


----------------------------------------------------------------        
----------------------------------------------------------------        
function KillPopupText( control, progress )

	if ( progress < 1 ) then
		return;
	end

	local instanceKey = control:GetVoid1();
    local instance = g_InstanceMap[ instanceKey ];
    
    if ( instance == nil ) then
        --print( "Error killing popup text" );
    else
        g_PopupIM:ReleaseInstance( instance );
        g_InstanceMap[ instanceKey ] = nil;
		if (table.count( g_InstanceMap ) == 0) then
			-- If empty, reset the counter.
			g_PopupInstanceNumber = 1;
			g_PopupIM:DestroyInstances();		-- Prevent a late game leak as UI controls keep allocating.  (re: TTP 1240)
		end
    end
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function KillAllPopupText( )

	for i, v in pairs(g_InstanceMap) do
		if (v ~= nil) then
	        g_PopupIM:ReleaseInstance( v );
		end
	end
	g_InstanceMap = {};
	g_PopupInstanceNumber = 1;
end


----------------------------------------------------------------        
----------------------------------------------------------------        
function OnUnitHexHighlight( i, j, k, bOn, unitId )

    --print( "GotEvent " .. unitId );
    local unit = UI.GetHeadSelectedUnit();
    
    if( unit ~= nil and
        unit:GetID() == unitId and
	    UI.CanSelectionListFound() ) then
	    
		-- Yield icons off by default
	    if (OptionsManager.IsCivilianYields()) then
			local gridX, gridY = ToGridFromHex( i, j );
			Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 2, gridX, gridY );
		end
    end
    
end
Events.UnitHexHighlight.Add( OnUnitHexHighlight )


----------------------------------------------------------------        
----------------------------------------------------------------        
function RequestYieldDisplay()

	-- Yield icons off by default
	local bDisplayCivilianYields = OptionsManager.IsCivilianYields();
	
    local unit = UI.GetHeadSelectedUnit();
	
	local bShowYields = true;
    if( unit ~= nil ) then
		if (GameInfo.Units[unit:GetUnitType()].DontShowYields) then
			bShowYields = false;
		end
	end
	
	if( bDisplayCivilianYields and UI.CanSelectionListWork() and bShowYields) then
        Events.RequestYieldDisplay( YieldDisplayTypes.EMPIRE );
		
	elseif( bDisplayCivilianYields and UI.CanSelectionListFound() ) then
	    if( unit ~= nil ) then
            Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 2, unit:GetX(), unit:GetY() );
		end
		
    elseif( not bCityScreenOpen ) then
        Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 0 );
	end
end


----------------------------------------------------------------        
----------------------------------------------------------------        
local TOP    = 0;
local BOTTOM = 1;
local LEFT   = 2;
local RIGHT  = 3;

function StopScrolling()
	Events.SerialEventCameraStopMovingForward();
	Events.SerialEventCameraStopMovingBack();
	Events.SerialEventCameraStopMovingLeft();
	Events.SerialEventCameraStopMovingRight();
end

function ScrollMouseEnter( which )

    if( bCityScreenOpen or bTechWebOpen ) then
        return;
    end;

	if (not UI.IsTouchScreenEnabled()) then
		if( which == TOP ) then
			Events.SerialEventCameraStartMovingForward();
		elseif( which == BOTTOM ) then
			Events.SerialEventCameraStartMovingBack();
		elseif( which == LEFT ) then
			Events.SerialEventCameraStartMovingLeft();
		else
			Events.SerialEventCameraStartMovingRight();
		end
	end
end

function ScrollMouseExit( which )

    if( bCityScreenOpen or bTechWebOpen ) then
        return;
    end;

	if (not UI.IsTouchScreenEnabled()) then
		if( which == TOP ) then
			Events.SerialEventCameraStopMovingForward();
		elseif( which == BOTTOM ) then
			Events.SerialEventCameraStopMovingBack();
		elseif( which == LEFT ) then
			Events.SerialEventCameraStopMovingLeft();
		else
			Events.SerialEventCameraStopMovingRight();
		end
	end
end
Controls.ScrollTop:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollTop:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollTop:SetVoid1( TOP );
Controls.ScrollBottom:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollBottom:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollBottom:SetVoid1( BOTTOM );
Controls.ScrollLeft:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollLeft:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollLeft:SetVoid1( LEFT );
Controls.ScrollRight:RegisterCallback( Mouse.eMouseEnter, ScrollMouseEnter );
Controls.ScrollRight:RegisterCallback( Mouse.eMouseExit, ScrollMouseExit );
Controls.ScrollRight:SetVoid1( RIGHT );


function OnChangeGameState( newState )
	if (newState == GameStates.LeaderHead) then
		StopScrolling();
	end
end
Events.ChangeGameState.Add( OnChangeGameState );

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
function SystemUpdateUIHandler( eType )
    if( eType == SystemUpdateUIType.BulkHideUI ) then
        Controls.BulkUI:SetHide( true );
    elseif( eType == SystemUpdateUIType.BulkShowUI ) then
        Controls.BulkUI:SetHide( false );
    end
end
Events.SystemUpdateUI.Add( SystemUpdateUIHandler )


---------------------------------------------------------------------------------------
function ShowHideHandler( bIsHide )
    if( not bIsHide ) then
		-- The Mouse Binding modes have no "nice name" descriptions.  Binding 2 = "Always"
        if( OptionsManager.GetFullscreen() or OptionsManager.GetBindMouseMode() == 2 ) then
            Controls.ScreenEdgeScrolling:SetHide( false );
        else
            Controls.ScreenEdgeScrolling:SetHide( true );
		end
        
        -- Check to see if we've been kicked.  It's possible that we were kicked while 
        -- loading into the game.
        if(Network.IsPlayerKicked(Game.GetActivePlayer())) then
			-- Display kicked popup.
			local popupInfo = 
			{
				Type  = ButtonPopupTypes.BUTTONPOPUP_KICKED,
				Data1 = NetKicked.BY_HOST
			};

			Events.SerialEventGameMessagePopup(popupInfo);
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		end    
      
		Controls.WorldViewControls:SetHide( false );
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

ClearAllHighlights();

---------------------------------------------------------------------------------------
-- Check to see if the world view controls should be hidden
function OnGameViewTypeChanged(eNewType)

	local bWorldViewHide = (GetGameViewRenderType() == GameViewTypes.GAMEVIEW_NONE);
	Controls.WorldViewControls:SetHide( bWorldViewHide );
	Controls.StagingRoom:SetHide( not bWorldViewHide );
	
end
Events.GameViewTypeChanged.Add(OnGameViewTypeChanged);


---------------------------------------------------------------------------------------
-- Support for Modded Add-in UI's
---------------------------------------------------------------------------------------
g_uiAddins = {};
for addin in Modding.GetActivatedModEntryPoints("InGameUIAddin") do
	local addinFile = Modding.GetEvaluatedFilePath(addin.ModID, addin.Version, addin.File);
	local addinPath = addinFile.EvaluatedPath;
	
	-- Get the absolute path and filename without extension.
	local extension = Path.GetExtension(addinPath);
	local path = string.sub(addinPath, 1, #addinPath - #extension);
	
	table.insert(g_uiAddins, ContextPtr:LoadNewContext(path));
end



		