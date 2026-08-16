-- ===========================================================================
-- World View 
-- ===========================================================================

include( "FLuaVector" );
include( "Planetfall" );
include( "GameplayUtilities" );

-- ===========================================================================
--	MEMBERS / CONSTANTS
-- ===========================================================================

local g_turn1Color					= Vector4( 0, 1, 0, 0.25 );
local g_turn2Color					= Vector4( 1, 1, 0, 0.25 );
local pathBorderStyle				= "MovementRangeBorder";
local attackPathBorderStyle			= "AMRBorder"; -- attack move

local g_pathFromSelectedUnitToMouse = nil;
local g_isRightButtonDown			= false;
local g_isEattingNextUp				= false;

local g_allowPointerMoveTo			= false;
local g_allowPointerPosition		= Vector2( 0, 0 );

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
         
function UpdatePathFromSelectedUnitToMouse()
	local interfaceMode = UI.GetInterfaceMode();
	if	(interfaceMode == InterfaceModeTypes.INTERFACEMODE_SELECTION and g_isRightButtonDown) or 
		(interfaceMode == InterfaceModeTypes.INTERFACEMODE_MOVE_TO) then
		Events.DisplayMovementIndicator( true );
	else
		Events.DisplayMovementIndicator( false );
	end
	
end

function ShowMovementRangeIndicator()
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return;
	end
	
	local iPlayerID = Game.GetActivePlayer();

	Events.ShowMovementRange( iPlayerID, unit:GetID() );
end

-- Add any interface modes that need special processing to this table
-- (look at InGame.lua for a bigger example)
local InterfaceModeMessageHandler = 
{
	[InterfaceModeTypes.INTERFACEMODE_DEBUG]			= {},
	[InterfaceModeTypes.INTERFACEMODE_SELECTION]		= {},
	[InterfaceModeTypes.INTERFACEMODE_MOVE_TO]			= {},
	[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO]			= {},
	[InterfaceModeTypes.INTERFACEMODE_AIRLIFT]			= {},
	[InterfaceModeTypes.INTERFACEMODE_PARADROP]			= {},
	[InterfaceModeTypes.INTERFACEMODE_ATTACK]			= {},
	[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK]		= {},
	[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK]= {},
	[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK]={},
	[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK]	= {},
	[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE]		= {},
	[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP]		= {},
	[InterfaceModeTypes.INTERFACEMODE_REBASE]			= {},
	[InterfaceModeTypes.INTERFACEMODE_EMBARK]			= {},
	[InterfaceModeTypes.INTERFACEMODE_DISEMBARK]		= {},
	[InterfaceModeTypes.INTERFACEMODE_PLACE_UNIT]		= {},
	[InterfaceModeTypes.INTERFACEMODE_GIFT_UNIT]		= {},
	[InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT] = {},
	[InterfaceModeTypes.INTERFACEMODE_PLANETFALL]		= {},
}

local DefaultMessageHandler = {};


DefaultMessageHandler[KeyEvents.KeyDown] =
function( wParam, lParam )
	if ( wParam == Keys.VK_LEFT ) then
		Events.SerialEventCameraStopMovingRight();
		Events.SerialEventCameraStartMovingLeft();
		return true;
	elseif ( wParam == Keys.VK_RIGHT ) then
		Events.SerialEventCameraStopMovingLeft();
		Events.SerialEventCameraStartMovingRight();
		return true;
	elseif ( wParam == Keys.VK_UP ) then
		Events.SerialEventCameraStopMovingBack();
		Events.SerialEventCameraStartMovingForward();
		return true;
	elseif ( wParam == Keys.VK_DOWN ) then
		Events.SerialEventCameraStopMovingForward();
		Events.SerialEventCameraStartMovingBack();
		return true;
	elseif ( wParam == Keys.VK_NEXT or wParam == Keys.VK_OEM_MINUS ) then
		Events.SerialEventCameraOut( Vector2(0,0) );
		return true;
	elseif ( wParam == Keys.VK_PRIOR or wParam == Keys.VK_OEM_PLUS ) then
		Events.SerialEventCameraIn( Vector2(0,0) );
		return true;	
	end
end


DefaultMessageHandler[KeyEvents.KeyUp] =
function( wParam, lParam )
	if ( wParam == Keys.VK_LEFT ) then
		Events.SerialEventCameraStopMovingLeft();
        return true;
	elseif ( wParam == Keys.VK_RIGHT ) then
		Events.SerialEventCameraStopMovingRight();
        return true;
	elseif ( wParam == Keys.VK_UP ) then
		Events.SerialEventCameraStopMovingForward();
        return true;
	elseif ( wParam == Keys.VK_DOWN ) then
		Events.SerialEventCameraStopMovingBack();
        return true;
	end
	return false;
end


-- Emergency key up handler
function KeyUpHandler( wParam )
	if ( wParam == Keys.VK_LEFT ) then
		Events.SerialEventCameraStopMovingLeft();
	elseif ( wParam == Keys.VK_RIGHT ) then
		Events.SerialEventCameraStopMovingRight();
	elseif ( wParam == Keys.VK_UP ) then
		Events.SerialEventCameraStopMovingForward();
	elseif ( wParam == Keys.VK_DOWN ) then
		Events.SerialEventCameraStopMovingBack();
	end
end
Events.KeyUpEvent.Add( KeyUpHandler );

-- INTERFACEMODE_DEBUG

g_UnitPlopper =
{
	UnitType = -1,
	UnitUpgrade = -1,
	Embarked = false,
	
	Plop =
	function(plot)
		if (g_PlopperSettings.Player ~= -1 and g_UnitPlopper.UnitType ~= -1) then
			local player = Players[g_PlopperSettings.Player];
			if (player ~= nil) then
				local unit;
				
				print(g_UnitPlopper.UnitNameOffset);
				print(player.InitUnitWithNameOffset);
				if(g_UnitPlopper.UnitNameOffset ~= nil and player.InitUnitWithNameOffset ~= nil) then
					unit = player:InitUnitWithNameOffset(g_UnitPlopper.UnitType, g_UnitPlopper.UnitNameOffset, plot:GetX(), plot:GetY());
				else
					unit = player:InitUnit(g_UnitPlopper.UnitType, plot:GetX(), plot:GetY());
				end 
						
				if (g_UnitPlopper.Embarked) then
					unit:Embark();
				end

				if (g_UnitPlopper.UnitUpgrade ~= -1) then
					unit:ChangeUnitType(g_UnitPlopper.UnitUpgrade);
				end
			end
		end
	end,
	
	Deplop =
	function(plot)
		local unitCount = plot:GetNumUnits();
		for i = 0, unitCount - 1 do
			local unit = plot:GetUnit(i);
			if unit ~= nil then
				unit:Kill(true, -1);
			end
		end
	end
}

g_ResourcePlopper =
{
	ResourceType = -1,
	ResourceAmount = 1,
	ResourceLayer = 0;
	
	Plop =
	function(plot)
		if (g_ResourcePlopper.ResourceType ~= -1) then
			if(plot.SetLayerResourceType ~= nil) then
				plot:SetLayerResourceType(g_ResourcePlopper.ResourceLayer, g_ResourcePlopper.ResourceType, g_ResourcePlopper.ResourceAmount);
			else
				plot:SetResourceType(g_ResourcePlopper.ResourceType, g_ResourcePlopper.ResourceAmount);
			end
		end
	end,
	
	Deplop =
	function(plot)
		if(plot.SetLayerResourceType ~= nil) then
			plot:SetLayerResourceType(g_ResourcePlopper.ResourceLayer, -1);
		else
			plot:SetResourceType(-1);
		end
	end
}

g_ImprovementPlopper =
{
	ImprovementType = -1,
	Pillaged = false,
	HalfBuilt = false,
	
	Plop =
	function(plot)
		if (g_ImprovementPlopper.ImprovementType ~= -1) then
			if (g_ImprovementPlopper.HalfBuilt) then
				-- ChangeBuildProgress needs a Build.ID.  The Build.ID comes from the CivBEBuilds.xml.
				-- The lookup into the CivBEBuilds database is BUILD_(IMPROVEMENT_NAME)

				local buildName = "BUILD_" .. string.gsub(GameInfo.Improvements[g_ImprovementPlopper.ImprovementType].Type, "IMPROVEMENT_", "");
				local buildInfo = GameInfo.Builds[buildName];

				if buildInfo ~= nil then
					plot:SetImprovementType(-1);
					plot:ChangeBuildProgress(buildInfo.ID, 100, Players[g_PlopperSettings.Player]);
					plot:ChangeBuildProgress(buildInfo.ID, 100, Players[g_PlopperSettings.Player]);
				end
			else
				plot:SetImprovementType(g_ImprovementPlopper.ImprovementType);
				if (g_ImprovementPlopper.Pillaged) then
					plot:SetImprovementPillaged(true);
				end
			end
		end
	end,
	
	Deplop =
	function(plot)
		-- GetBuildProgress needs a Build.ID.  The Build.ID comes from the CivBEBuilds.xml.
		-- The lookup into the CivBEBuilds database is BUILD_(IMPROVEMENT_NAME)

		local buildName = "BUILD_" .. string.gsub(GameInfo.Improvements[g_ImprovementPlopper.ImprovementType].Type, "IMPROVEMENT_", "");
		local buildInfo = GameInfo.Builds[buildName];

		if buildInfo ~= nil then
			local progress = plot:GetBuildProgress(buildInfo.ID);
			if (progress ~= -1) then
				local buildTime = plot:GetBuildTime(buildInfo.ID, Players[g_PlopperSettings.Player]);
				plot:ChangeBuildProgress(buildInfo.ID, buildTime, Players[g_PlopperSettings.Player]);
			end
		end

		plot:SetImprovementType(-1);
	end
}

g_CityPlopper =
{
	Plop =
	function(plot)
		if (g_PlopperSettings.Player ~= -1) then
			local player = Players[g_PlopperSettings.Player];
			if (player ~= nil) then
				player:InitCity(plot:GetX(), plot:GetY());
			end
		end
	end,
	
	Deplop =
	function(plot)
		local city = plot:GetPlotCity();
		if (city ~= nil) then
			city:Kill();
		end
	end
}

g_PlopperSettings =
{
	Player = -1,
	Plopper = g_UnitPlopper,
	EnabledWhenInTab = false
}

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_DEBUG][MouseEvents.LButtonUp] = 
function( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pActivePlayer = Players[Game.GetActivePlayer()];
	local debugItem1 = UI.GetInterfaceModeDebugItemID1();
	
	-- City
	if (UI.debugItem1 == 0) then
		pActivePlayer:InitCity(plotX, plotY);
	-- Unit
	elseif (debugItem1 == 1) then
		local iUnitID = UI.GetInterfaceModeDebugItemID2();
		pActivePlayer:InitUnit(iUnitID, plotX, plotY);
	-- Improvement
	elseif (debugItem1 == 2) then
		local iImprovementID = UI.GetInterfaceModeDebugItemID2();
		plot:SetImprovementType(iImprovementID);
	-- Route
	elseif (debugItem1 == 3) then
		local iRouteID = UI.GetInterfaceModeDebugItemID2();
		plot:SetRouteType(iRouteID);
	-- Feature
	elseif (debugItem1 == 4) then
		local iFeatureID = UI.GetInterfaceModeDebugItemID2();
		plot:SetFeatureType(iFeatureID);
	-- Resource
	elseif (debugItem1 == 5) then
		local iResourceID = UI.GetInterfaceModeDebugItemID2();
		plot:SetResourceType(iResourceID, 5);
	-- Plopper
	elseif (debugItem1 == 6 and
	        type(g_PlopperSettings) == "table" and
	        type(g_PlopperSettings.Plopper) == "table" and
	        type(g_PlopperSettings.Plopper.Plop) == "function") then
	        
		g_PlopperSettings.Plopper.Plop(plot);
		return true; -- Do not allow the interface mode to be set back to INTERFACEMODE_SELECTION
	-- Miasma
	elseif (debugItem1 == 7) then
		local addRemove = UI.GetInterfaceModeDebugItemID2();
		if (addRemove > 0) then
			plot:SetMiasma(true);
		else
			plot:SetMiasma(false);
		end
	-- Stations
	elseif (debugItem1 == 8) then
		local iStationID = UI.GetInterfaceModeDebugItemID2();
		Game.CreateStationOfType(iStationID, plot);
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return true;
end



-- ===========================================================================
function OnRightDown_InterfaceModeDebug( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local debugItem1 = UI.GetInterfaceModeDebugItemID1();
	
	-- Plopper
	if (debugItem1 == 6 and
	        type(g_PlopperSettings) == "table" and
	        type(g_PlopperSettings.Plopper) == "table" and
	        type(g_PlopperSettings.Plopper.Deplop) == "function") then
	        
		g_PlopperSettings.Plopper.Deplop(plot);
	end
	
	return true;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][KeyEvents.KeyDown] = 
function( wParam, lParam )
	if ( wParam == Keys.VK_ESCAPE ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	elseif (wParam == Keys.VK_NUMPAD1 or wParam == Keys.VK_NUMPAD3 or wParam == Keys.VK_NUMPAD4 or wParam == Keys.VK_NUMPAD6 or wParam == Keys.VK_NUMPAD7 or wParam == Keys.VK_NUMPAD8 ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	else
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	end
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK][KeyEvents.KeyDown] = 
function( wParam, lParam )
	if ( wParam == Keys.VK_ESCAPE ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	elseif (wParam == Keys.VK_NUMPAD1 or wParam == Keys.VK_NUMPAD3 or wParam == Keys.VK_NUMPAD4 or wParam == Keys.VK_NUMPAD6 or wParam == Keys.VK_NUMPAD7 or wParam == Keys.VK_NUMPAD8 ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	else
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	end
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK][KeyEvents.KeyDown] = 
function( wParam, lParam )
	if ( wParam == Keys.VK_ESCAPE ) then
		UI.ClearSelectedCities();
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	elseif (wParam == Keys.VK_NUMPAD1 or wParam == Keys.VK_NUMPAD3 or wParam == Keys.VK_NUMPAD4 or wParam == Keys.VK_NUMPAD6 or wParam == Keys.VK_NUMPAD7 or wParam == Keys.VK_NUMPAD8 ) then
		UI.ClearSelectedCities();
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	else
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	end
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK][KeyEvents.KeyDown] = 
function( wParam, lParam )
	if ( wParam == Keys.VK_ESCAPE ) then
		UI.ClearSelectedCities();
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	elseif (wParam == Keys.VK_NUMPAD1 or wParam == Keys.VK_NUMPAD3 or wParam == Keys.VK_NUMPAD4 or wParam == Keys.VK_NUMPAD6 or wParam == Keys.VK_NUMPAD7 or wParam == Keys.VK_NUMPAD8 ) then
		UI.ClearSelectedCities();
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	else
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	end
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK][KeyEvents.KeyDown] = 
function( wParam, lParam )
	if ( wParam == Keys.VK_ESCAPE ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	elseif (wParam == Keys.VK_NUMPAD1 or wParam == Keys.VK_NUMPAD3 or wParam == Keys.VK_NUMPAD4 or wParam == Keys.VK_NUMPAD6 or wParam == Keys.VK_NUMPAD7 or wParam == Keys.VK_NUMPAD8 ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	else
		return DefaultMessageHandler[KeyEvents.KeyDown]( wParam, lParam );
	end
end

-- this is a default handler for all Interface Modes that correspond to a mission
function missionTypeLButtonUpHandler( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	if plot then
		local plotX = plot:GetX();
		local plotY = plot:GetY();
		local bShift = UIManager:GetShift();
		local interfaceMode = UI.GetInterfaceMode();
		local eInterfaceModeMission = GameInfoTypes[GameInfo.InterfaceModes[interfaceMode].Mission];
		if eInterfaceModeMission ~= MissionTypes.NO_MISSION then
			if UI.CanDoInterfaceMode(interfaceMode) then
				Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, eInterfaceModeMission, plotX, plotY, 0, false, bShift);
				UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
				return true;
			end
		end
	end
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return true;
end

-- ===========================================================================
function AirStrike( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	local bShift = UIManager:GetShift();
	local interfaceMode = InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK;
	
	-- Don't let the user do a ranged attack on a plot that contains some fighting.
	if plot:IsFighting() then
		return true;
	end
		
	-- should handle the case of units bombarding tiles when they are already at war
	if pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrikeAt(plotX, plotY, true, true) then
		local interfaceMode = UI.GetInterfaceMode();
		local eInterfaceModeMission = GameInfoTypes[GameInfo.InterfaceModes[interfaceMode].Mission];
		Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, eInterfaceModeMission, plotX, plotY, 0, false, bShift);
    	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	-- Unit Range Strike - special case for declaring war with range strike
	elseif pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrikeAt(plotX, plotY, false, true) then
		-- Is there someone here that we COULD bombard, perhaps?
		local eRivalTeam = pHeadSelectedUnit:GetDeclareWarRangeStrike(plot);
		if (eRivalTeam ~= -1) then							
			UIManager:SetUICursor(0);
			
			local popupInfo = 
			{
				Type  = ButtonPopupTypes.BUTTONPOPUP_DECLAREWARRANGESTRIKE,
				Data1 = eRivalTeam,
				Data2 = plotX,
				Data3 = plotY
			};
			Events.SerialEventGameMessagePopup(popupInfo);
        	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			return true;	
		end
	end
						
	return true;
end

-- ===========================================================================
function RangeAttack( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	local bShift = UIManager:GetShift();
	local interfaceMode = InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK;
	
	-- Don't let the user do a ranged attack on a plot that contains some fighting.
	if plot:IsFighting() then
		return true;
	end
		
	-- should handle the case of units bombarding tiles when they are already at war
	if pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrikeAt(plotX, plotY, true, true) then
		Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_RANGE_ATTACK, plotX, plotY, 0, false, bShift);
    	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	-- Unit Range Strike - special case for declaring war with range strike
	elseif pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrikeAt(plotX, plotY, false, true) then
		-- Is there someone here that we COULD bombard, perhaps?
		local eRivalTeam = pHeadSelectedUnit:GetDeclareWarRangeStrike(plot);
		if (eRivalTeam ~= -1) then		
			UIManager:SetUICursor(0);
							
			local popupInfo = 
			{
				Type  = ButtonPopupTypes.BUTTONPOPUP_DECLAREWARRANGESTRIKE,
				Data1 = eRivalTeam,
				Data2 = plotX,
				Data3 = plotY,
				Data4 = pHeadSelectedUnit:GetOwner()
			};
			Events.SerialEventGameMessagePopup(popupInfo);
        	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			return true;	
		end
	end
						
	return true;
end

-- ===========================================================================
function CityBombard( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	local bShift = UIManager:GetShift();
	
	-- Don't let the user do a ranged attack on a plot that contains some fighting.
	if plot:IsFighting() then
		UI.ClearSelectedCities();
    	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	end
		
	if pHeadSelectedCity and pHeadSelectedCity:CanRangeStrike() then
		if pHeadSelectedCity:CanRangeStrikeAt(plotX,plotY, true, true) then
			Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_TASK, TaskTypes.TASK_RANGED_ATTACK, plotX, plotY);
			local activePlayerID = Game.GetActivePlayer();
			Events.SpecificCityInfoDirty( activePlayerID, pHeadSelectedCity:GetID(), CityUpdateTypes.CITY_UPDATE_TYPE_BANNER);
		end
		UI.ClearSelectedCities();
    	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		return true;
	end	
	
	return true;
end

-- ===========================================================================
function OrbitalAttack( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	local bShift = UIManager:GetShift();

	-- SEND ORBITAL ATTACK
	if pHeadSelectedUnit and pHeadSelectedUnit:CanAttackOrbitalAt(plotX, plotY) then
		Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_ORBITAL_ATTACK, plotX, plotY, 0, false, bShift);
	elseif pHeadSelectedCity and pHeadSelectedCity:CanAttackOrbitalAt(plotX, plotY) then
		Game.SelectedCitiesGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_TASK, TaskTypes.TASK_ATTACK_ORBITAL, plotX, plotY);
		local activePlayerID = Game.GetActivePlayer();
		Events.SpecificCityInfoDirty( activePlayerID, pHeadSelectedCity:GetID(), CityUpdateTypes.CITY_UPDATE_TYPE_BANNER);
		UI.ClearSelectedCities(); --here
	end

	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return true;
end

-- ===========================================================================
-- If the user presses the right mouse button when in city range attack mode, make sure and clear the
-- mode and also clear the selection.
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK][MouseEvents.RButtonUp] = 
function ( wParam, lParam )
	UI.ClearSelectedCities();
   	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return true;
end

InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK][MouseEvents.RButtonUp] = 
function ( wParam, lParam )
	UI.ClearSelectedCities();
   	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	return true;
end

function EmbarkInputHandler( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	local bShift = UIManager:GetShift();

	if pHeadSelectedUnit then
		if (pHeadSelectedUnit:CanEmbarkOnto(pHeadSelectedUnit:GetPlot(), plot)) then
			Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_EMBARK, plotX, plotY, 0, false, bShift);
		end
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end
-- Have either right or left click trigger this
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_EMBARK][MouseEvents.LButtonUp] = EmbarkInputHandler;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_EMBARK][MouseEvents.RButtonUp] = EmbarkInputHandler;
if (UI.IsTouchScreenEnabled()) then
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_EMBARK][MouseEvents.PointerUp] = EmbarkInputHandler;
end

-- ===========================================================================
function DisembarkInputHandler( wParam, lParam )
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	local bShift = UIManager:GetShift();

	if pHeadSelectedUnit then
		if (pHeadSelectedUnit:CanDisembarkOnto(plot)) then
			Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, MissionTypes.MISSION_DISEMBARK, plotX, plotY, 0, false, bShift);
		end
	end
	
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end
-- Have either right or left click trigger this
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_DISEMBARK][MouseEvents.LButtonUp] = DisembarkInputHandler;
InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_DISEMBARK][MouseEvents.RButtonUp] = DisembarkInputHandler;
if (UI.IsTouchScreenEnabled()) then
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_DISEMBARK][MouseEvents.PointerUp] = DisembarkInputHandler;
end


function OnRightDown_InterfaceModeSelect( wParam, lParam )
	ShowMovementRangeIndicator();
	UI.SendPathfinderUpdate();
	UpdatePathFromSelectedUnitToMouse();
end

function ClearAllHighlights()
	--Events.ClearHexHighlights(); other systems might be using these!
	Events.ClearHexHighlightStyle("");
	Events.ClearHexHighlightStyle(pathBorderStyle);
	Events.ClearHexHighlightStyle(attackPathBorderStyle);
	Events.ClearHexHighlightStyle(genericUnitHexBorder);  
	Events.ClearHexHighlightStyle("FireRangeBorder");
	Events.ClearHexHighlightStyle("RebaseMarker");
	Events.ClearHexHighlightStyle("ValidFireTargetBorder");
	Events.ClearHexHighlightStyle("PlanetfallRange");
end

function TouchDownMoveToHandler( wParam, lParam )
	--print("TouchDownMoveToHandler() p: " .. tostring(UIManager:GetNumPointers()), "mode: " .. tostring( UI.GetInterfaceMode()) );
    if( UIManager:GetNumPointers() > 1 ) then
		UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		UI.ClearSelectionList();
		UI.VisuallyDeselectHeadSelectedUnit();
		g_allowPointerMoveTo = false;
		g_allowPointerPosition = Vector2( 0, 0 );
	end
	return false;
end

function TouchDownSelectHandler( wParam, lParam )
	--print("TouchDownSelectHandler() p: " .. tostring(UIManager:GetNumPointers()), "mode: " .. tostring( UI.GetInterfaceMode()) );
	return false;	-- If true, breaks entering city
end

function TouchUpMoveHandler( wParam, lParam )
	--print("TouchUpMoveHandler, eating: " .. tostring(g_isEattingNextUp));
    if( g_isEattingNextUp == true ) then
        g_isEattingNextUp = false;
        return true;
    end

	local handled = MovementRButtonUp( wParam, lParam );
	Events.DisplayMovementIndicator( false );

	return handled;
end

function TouchMoveSelectHandler( wParam, lParam )
	-- If we have a unit selected, and we've moved out of the selected unit's hex, put us into MOVE_TO move
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if( pHeadSelectedUnit ~= nil ) then
		-- Only switch if we are allowed to.  If we touch with a second input, that cancels the
		-- movement mode.  If we're still keeping our initial touch point down, we don't want that
		-- to start movement mode again.
		if (g_allowPointerMoveTo) then
			if (pHeadSelectedUnit:GetPlot() ~= Map.GetPlot( UI.GetMouseOverHex() ) ) then
				UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_MOVE_TO);
				return true;
			end
		else
			if (pHeadSelectedUnit:GetPlot() == Map.GetPlot( UI.GetMouseOverHex() ) ) then
				-- Because we can get a little movement when we first touch, or we touch
				-- with a second input, we don't want that to register that we can move
				-- the unit yet.  Allow a little bit of "give" before allowing movement.
				local mouseX, mouseY = UIManager:GetMousePos();

				if( g_allowPointerPosition.x == 0 and g_allowPointerPosition.y == 0 ) then
					g_allowPointerPosition.x = mouseX;
					g_allowPointerPosition.y = mouseY;
				end

				if( math.abs(g_allowPointerPosition.x - mouseX) > 10 or math.abs(g_allowPointerPosition.y - mouseY) > 10 ) then
					g_allowPointerMoveTo = true;
				end
			end
		end
	end
	return false;
end

function TouchUpSelectHandler( wParam, lParam )
	--print("TouchUpSelectHandler");
	return false;	-- Needs to be false since Selection done in GameViewState.
end

function MovementRButtonUp( wParam, lParam )

	if( UI.IsTouchScreenEnabled() ) then
	    if( UIManager:GetNumPointers() == 1 ) then	-- one just went up
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		end
	end

	local bShift = UIManager:GetShift();
	local bAlt = UIManager:GetAlt();
	local bCtrl = UIManager:GetControl();
	local plot = Map.GetPlot( UI.GetMouseOverHex() );
	if not plot then
		return true;
	end
	
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	UpdatePathFromSelectedUnitToMouse();

	if pHeadSelectedUnit then
		if (UI.IsCameraMoving() and not Game.GetAllowRClickMovementWhileScrolling()) then
			print("Blocked by moving camera");
			ClearAllHighlights();
			return;
		end
	
		Game.SetEverRightClickMoved(true);
	
		local bBombardEnemy = false;

		-- Is there someone here that we COULD bombard perhaps?
		local eRivalTeam = pHeadSelectedUnit:GetDeclareWarRangeStrike(plot);
		if (eRivalTeam ~= -1) then
			UIManager:SetUICursor(0);
										
			local popupInfo = 
			{
				Type  = ButtonPopupTypes.BUTTONPOPUP_DECLAREWARRANGESTRIKE,
				Data1 = eRivalTeam,
				Data2 = plotX,
				Data3 = plotY
			};
			Events.SerialEventGameMessagePopup(popupInfo);
			return true;
		end

		-- Visible enemy... bombardment?
		if (plot:IsVisibleEnemyUnit(pHeadSelectedUnit:GetOwner()) or plot:IsEnemyCity(pHeadSelectedUnit) or plot:IsStation()) then		
			
			local bNoncombatAllowed = false;
			
			if plot:IsFighting() then
				return true;		-- Already some combat going on in there, just exit
			end
			
			if pHeadSelectedUnit:CanRangeStrikeAt(plotX, plotY, true, bNoncombatAllowed) then
				
				local iMission;
				if (pHeadSelectedUnit:GetDomainType() == DomainTypes.DOMAIN_AIR) then
					iMission = MissionTypes.MISSION_MOVE_TO;		-- Air strikes are moves... yep
				else
					iMission = MissionTypes.MISSION_RANGE_ATTACK;
				end
				
				Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_PUSH_MISSION, iMission, plotX, plotY, 0, false, bShift);
				UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
				--Events.ClearHexHighlights();
				ClearAllHighlights();
				return true;
			end
		end

		-- No visible enemy to bombard, just move
		--print("bBombardEnemy check");
		if bBombardEnemy == false then
			if bShift == false and pHeadSelectedUnit:AtPlot(plot) then
				--print("Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_COMMAND, CommandTypes.COMMAND_CANCEL_ALL);");
				Game.SelectionListGameNetMessage(GameMessageTypes.GAMEMESSAGE_DO_COMMAND, CommandTypes.COMMAND_CANCEL_ALL);
			else--if plot == UI.GetGotoPlot() then
				--print("Game.SelectionListMove(plot,  bAlt, bShift, bCtrl);");
				Game.SelectionListMove(plot,  bAlt, bShift, bCtrl);
				--UI.SetGotoPlot(nil);
			end
			--Events.ClearHexHighlights();
			ClearAllHighlights();
			return true;
		end
	end
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
		local city = unitPlot:GetPlotCity();
		if (city ~= nil) then
			if UI.CanPlaceUnitAt(unit, plot) then
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

function SelectHandler( wParam, lParam )
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end

DefaultMessageHandler[MouseEvents.RButtonUp] = SelectHandler;
if (UI.IsTouchScreenEnabled()) then
	DefaultMessageHandler[MouseEvents.PointerUp] = SelectHandler;
end


   


----------------------------------------------------------------
-- Input handling 
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )

	if uiMsg == MouseEvents.RButtonDown then
		g_isRightButtonDown = true;
	elseif uiMsg == MouseEvents.RButtonUp then
		g_isRightButtonDown = false;
	end
	
	local interfaceMode = UI.GetInterfaceMode();

	--[[ ??TRON debug: 12=mouseMove, 27=touchUpdate, 13=buttonDown
	if (uiMsg ~= 12 and uiMsg ~= 1 and uiMsg ~= 27 and uiMsg ~= 13) then
		print("WV:IH( " .. tostring(uiMsg) .. ", " .. tostring(wParam) .. ", " .. tostring(lParam) .. " )  mode: " .. tostring(interfaceMode) .. " misc: " .. 
			tostring(MouseEvents.LButtonDoubleClick).." ".. tostring(InterfaceModeTypes.INTERFACEMODE_SELECTION));
	end
	]]

	local currentInterfaceModeHandler = InterfaceModeMessageHandler[interfaceMode];
	if currentInterfaceModeHandler and currentInterfaceModeHandler[uiMsg] then
		return currentInterfaceModeHandler[uiMsg]( wParam, lParam );
	elseif DefaultMessageHandler[uiMsg] then
		return DefaultMessageHandler[uiMsg]( wParam, lParam );
	end
	return false;
end
ContextPtr:SetInputHandler( InputHandler );

---------------------------------------------------------------- 
-- Deal with a new path from the path finder 
-- this is a place holder implementation to give an example of how to handle it       
----------------------------------------------------------------
function OnUIPathFinderUpdate( thePath )
	--g_pathFromSelectedUnitToMouse = thePath;
	UpdatePathFromSelectedUnitToMouse();
end
Events.UIPathFinderUpdate.Add( OnUIPathFinderUpdate );

function OnMouseMoveHex( hexX, hexY )
	local interfaceMode = UI.GetInterfaceMode();	
	--print("OnMouseMoveHex(): " .. tostring(interfaceMode) .. "  rdown: " .. tostring(g_isRightButtonDown) );	--??TRON debug remove
	if	(interfaceMode == InterfaceModeTypes.INTERFACEMODE_SELECTION and g_isRightButtonDown) or 
		(interfaceMode == InterfaceModeTypes.INTERFACEMODE_MOVE_TO) then
		UI.SendPathfinderUpdate();
	end
end
Events.SerialEventMouseOverHex.Add( OnMouseMoveHex );

function OnClearUnitMoveHexRange()
	Events.ClearHexHighlightStyle(pathBorderStyle);
	Events.ClearHexHighlightStyle(attackPathBorderStyle);
end
Events.ClearUnitMoveHexRange.Add( OnClearUnitMoveHexRange );

function OnStartUnitMoveHexRange()
	Events.ClearHexHighlightStyle(pathBorderStyle);
	Events.ClearHexHighlightStyle(attackPathBorderStyle);
end
Events.StartUnitMoveHexRange.Add( OnStartUnitMoveHexRange );

function OnAddUnitMoveHexRangeHex(i, j, k, attackMove, unitID)
	if attackMove then
		Events.SerialEventHexHighlight( Vector2( i, j ), true, g_turn1Color, attackPathBorderStyle );
	else
		Events.SerialEventHexHighlight( Vector2( i, j ), true, g_turn1Color, pathBorderStyle );
	end
end
Events.AddUnitMoveHexRangeHex.Add( OnAddUnitMoveHexRangeHex );

--Events.EndUnitMoveHexRange.Add( OnEndUnitMoveHexRange );

-------------------------------------------------
function OnMultiplayerGameAbandoned(eReason)
	-- UI.AddPopup will delay display this popup if popups are suppressed, like when we're loading the game.
	local popupInfo = 
	{
		Type  = ButtonPopupTypes.BUTTONPOPUP_KICKED,
		Data1 = eReason
	};
	UI.AddPopup(popupInfo);
end
Events.MultiplayerGameAbandoned.Add( OnMultiplayerGameAbandoned );

-------------------------------------------------
function OnMultiplayerGameLastPlayer()
	UI.AddPopup( { Type = ButtonPopupTypes.BUTTONPOPUP_TEXT, 
	Data1 = 800, 
	Option1 = true, 
	Text = "TXT_KEY_MP_LAST_PLAYER" } );
end
Events.MultiplayerGameLastPlayer.Add( OnMultiplayerGameLastPlayer );

-- ===========================================================================
function OnInterfaceModeChanged( oldInterfaceMode, newInterfaceMode)
	if ( newInterfaceMode == InterfaceModeTypes.INTERFACEMODE_PLANETFALL) then
		Controls.NewTurn:SetHide(true);
		Controls.TurnProcessing:SetHide(true);
		Controls.MPTurnPanel:SetHide(true);
		Controls.ActionInfoPanel:SetHide(true);
		Controls.InfoCorner:SetHide(true);
		Controls.DiploCorner:SetHide(true);

	elseif ( oldInterfaceMode == InterfaceModeTypes.INTERFACEMODE_PLANETFALL) then
		Controls.NewTurn:SetHide(false);
		Controls.TurnProcessing:SetHide(false);
		Controls.MPTurnPanel:SetHide(false);
		Controls.ActionInfoPanel:SetHide(false);
		Controls.InfoCorner:SetHide(false);
		Controls.DiploCorner:SetHide(false);

	end
end
Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );

-- ===========================================================================
function HideInGameControl( pathToControl, isHiding )
	local inGameControl = ContextPtr:LookUpControl( pathToControl );
	if inGameControl  ~= nil then
		inGameControl:SetHide( isHiding );
	else
		print("ERROR: Unable to Show/Hide InGame control from WorldView. Control Path: "..pathToControl,"hiding: ", isHiding);
	end
end


-- ===========================================================================
--	Initialize
--	Set handlers, etc...
-- ===========================================================================
function InitializeWorldView()

	-- *** TOUCH SCREENS ***
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLANETFALL][MouseEvents.PointerDown]		= function(w,l) return true; end
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.PointerDown]		= TouchDownSelectHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][MouseEvents.PointerDown]			= TouchDownMoveToHandler;

	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.PointerUp]			= TouchUpSelectHandler; 
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][MouseEvents.PointerUp]			= TouchUpMoveHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO][MouseEvents.PointerUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_AIRLIFT][MouseEvents.PointerUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PARADROP][MouseEvents.PointerUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE][MouseEvents.PointerUp]			= AirStrike;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP][MouseEvents.PointerUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_REBASE][MouseEvents.PointerUp]				= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT][MouseEvents.PointerUp]= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK][MouseEvents.PointerUp]		= RangeAttack;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK][MouseEvents.PointerUp]	= CityBombard;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK][MouseEvents.PointerUp]= OrbitalAttack;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK][MouseEvents.PointerUp]		= OrbitalAttack;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLANETFALL][MouseEvents.PointerUp]			= ActivatePlanetfall;
	
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.PointerUpdate]		= TouchMoveSelectHandler;

	-- Double touch handlers that are only active when using touch.
	-- Consider reworking when a native "double tap" is enabled.
	if (UI.IsTouchScreenEnabled()) then

		InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.LButtonDoubleClick] = 
			function( wParam, lParam )
				if( UI.GetHeadSelectedUnit() ~= NULL ) then
					UI.SetInterfaceMode( InterfaceModeTypes.INTERFACEMODE_MOVE_TO );
					g_isEattingNextUp = true;
				end
			end
		InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][MouseEvents.LButtonDoubleClick]	= function(w,l) print("DBL move to"); end
		InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO][MouseEvents.LButtonDoubleClick]	= function(w,l) print("DBL route to"); end

	end -- is touch enabled



	--	*** LEFT MOUSE BUTTON ***
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][MouseEvents.LButtonUp]			= function(w,l) print("mouse move"); missionTypeLButtonUpHandler(w,l); end;	--??TRON debug msg
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ROUTE_TO][MouseEvents.LButtonUp]			= function(w,l) print("mouse route"); missionTypeLButtonUpHandler(w,l); end	--??TRON debug msg
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_AIRLIFT][MouseEvents.LButtonUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PARADROP][MouseEvents.LButtonUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_AIRSTRIKE][MouseEvents.LButtonUp]			= AirStrike;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_AIR_SWEEP][MouseEvents.LButtonUp]			= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_REBASE][MouseEvents.LButtonUp]				= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_LAUNCH_ORBITAL_UNIT][MouseEvents.LButtonUp]= missionTypeLButtonUpHandler;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK][MouseEvents.LButtonUp]		= RangeAttack;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK][MouseEvents.LButtonUp]	= CityBombard;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_CITY_ORBITAL_ATTACK][MouseEvents.LButtonUp]= OrbitalAttack;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_ORBITAL_ATTACK][MouseEvents.LButtonUp]		= OrbitalAttack;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLANETFALL][MouseEvents.LButtonUp]			= ActivatePlanetfall;

	--	*** RIGHT MOUSE BUTTON ***
	-- right down...
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_DEBUG][MouseEvents.RButtonDown]		= OnRightDown_InterfaceModeDebug;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.RButtonDown]	= OnRightDown_InterfaceModeSelect;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLANETFALL][MouseEvents.RButtonDown]	= function(wParam,lParam) return true; end;

	-- right up...
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_DEBUG][MouseEvents.RButtonUp]			= function(wParam,lParam) return true; end;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_SELECTION][MouseEvents.RButtonUp]		= MovementRButtonUp;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_MOVE_TO][MouseEvents.RButtonUp]		= MovementRButtonUp;
	InterfaceModeMessageHandler[InterfaceModeTypes.INTERFACEMODE_PLANETFALL][MouseEvents.RButtonUp]		= function(wParam,lParam) return true; end;

	-- Observer mode disables some of the HUD because the HUD assumes an active civ.
	local pActivePlayer = Players[Game.GetActivePlayer()];
	if(pActivePlayer ~= nil and pActivePlayer:IsObserver()) then
		Controls.InfoCorner:SetHide(true);
	end


	--OnInterfaceModeChanged(0,InterfaceModeTypes.INTERFACEMODE_PLANETFALL); --??TRON debug, force testing mode when hotloading
end

function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	Events.DisplayMovementIndicator( false );
	g_isRightButtonDown = false;
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

InitializeWorldView();
