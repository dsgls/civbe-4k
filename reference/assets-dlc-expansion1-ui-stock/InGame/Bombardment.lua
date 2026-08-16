-------------------------------------------------
-- Bombardment
-------------------------------------------------

local redColor = Vector4( 0.7, 0, 0, 1 );
local highlightColor = Vector4( 0.7, 0.7, 0, 1 ); -- depending on the theme these may not actually be used (for example SplineBorder do not)
local ms_CityBombardPlayer = -1;
local ms_CityBombardID = -1;
local ms_SiteBombardPlotIndex = -1;

local blueColor = Vector4( 0, 0.7, 0, 1 );

-------------------------------------------------
function RangedStrikeHighlight()
	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();

	local selectedLocX = UI.GetSelectedImprovementPlotX();
	local selectedLocY = UI.GetSelectedImprovementPlotY();
	local selectedSitePlot = Map.GetPlot(selectedLocX, selectedLocY);
	local selectedSite = selectedSitePlot:GetPlotStrategicSite();

	local thingThatCanActuallyFire = nil;
	
	local iRange;
	local bIndirectFireAllowed;
	local bDomainOnly;
	local thisPlot = nil;
	local thisX;
	local thisY;
	local thisTeam;

	if pHeadSelectedCity and pHeadSelectedCity:CanRangeStrike() then
		iRange = pHeadSelectedCity:GetStrikeRange();
		selectedSite = pHeadSelectedCity:GetStrategicSite();
		bIndirectFireAllowed = selectedSite ~= nil and selectedSite:CanUseIndirectFire();
		thisPlot = pHeadSelectedCity:Plot();
		thisX = pHeadSelectedCity:GetX();
		thisY = pHeadSelectedCity:GetY();
		thisTeam = pHeadSelectedCity:GetTeam();
		thingThatCanActuallyFire = pHeadSelectedCity;
		bDomainOnly = false;
	elseif pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrike() then
		iRange = pHeadSelectedUnit:Range();
		bIndirectFireAllowed = pHeadSelectedUnit:IsRangeAttackIgnoreLOS();
		thisPlot = pHeadSelectedUnit:GetPlot();
		thisX = pHeadSelectedUnit:GetX();
		thisY = pHeadSelectedUnit:GetY();
		thisTeam = pHeadSelectedUnit:GetTeam();
		thingThatCanActuallyFire = pHeadSelectedUnit;
		bDomainOnly = pHeadSelectedUnit:IsRangeAttackOnlyInDomain();
		--print("bDomainOnly:"..tostring(bDomainOnly))
	elseif selectedSite ~= nil and selectedSite:CanRangeStrike() then
		iRange = selectedSite:GetStrikeRange();
		bIndirectFireAllowed = selectedSite:CanUseIndirectFire();
		thisPlot = selectedSitePlot;
		thisX = selectedLocX;
		thisY = selectedLocY;
		thisTeam = selectedSitePlot:GetTeam();
		thingThatCanActuallyFire = selectedSite;
	end
	if thingThatCanActuallyFire ~= nil and thisPlot then
		-- highlight the bombardable plots
		local NO_DIRECTION = -1;
		for iDX = -iRange, iRange do
			for iDY = -iRange, iRange do
				local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
				local bCanRangeStrike = true;

				if pTargetPlot then
					if not bIndirectFireAllowed then
						if not thisPlot:CanSeePlot(pTargetPlot, thisTeam, iRange - 1, NO_DIRECTION) then
							bCanRangeStrike = false;
						end
					end
					
					-- Unit domain constraint
					if bDomainOnly then
						if (thingThatCanActuallyFire.GetDomainType ~= nil) then
							if thingThatCanActuallyFire:GetDomainType() == DomainTypes.DOMAIN_LAND and pTargetPlot:IsWater() then
								bCanRangeStrike = false;
							elseif thingThatCanActuallyFire:GetDomainType() == DomainTypes.DOMAIN_SEA and not pTargetPlot:IsWater() then
								bCanRangeStrike = false;
							end
						end
					end

					if bCanRangeStrike then
						if pTargetPlot:IsVisible(thisTeam, false) then
							local plotX = pTargetPlot:GetX();
							local plotY = pTargetPlot:GetY();
							local plotDistance = Map.PlotDistance(thisX, thisY, plotX, plotY);

							local inRange : boolean = plotDistance <= iRange;

							if (inRange) then
								local hexID = ToHexFromGrid(Vector2(plotX, plotY));
								Events.SerialEventHexHighlight(hexID, true, highlightColor, "FireRangeBorder");

								if thingThatCanActuallyFire:CanRangeStrikeAt(plotX,plotY) then
									Events.SerialEventHexHighlight( hexID, true, redColor, "ValidFireTargetBorder");
								end
							end
						end
					end
				end
			end
		end
	end
end

-------------------------------------------------
function AirStrikeHighlight(bHighlightTargets)
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	local thingThatCanActuallyFire = nil;
	
	local iRange;
	local bIndirectFireAllowed;
	local thisPlot;
	local thisX;
	local thisY;
	local thisTeam;
	
	if pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrike() then
		iRange = pHeadSelectedUnit:Range();
		thisPlot = pHeadSelectedUnit:GetPlot();
		thisX = pHeadSelectedUnit:GetX();
		thisY = pHeadSelectedUnit:GetY();
		thisTeam = pHeadSelectedUnit:GetTeam();
		thingThatCanActuallyFire = pHeadSelectedUnit;
	end
	if thingThatCanActuallyFire ~= nil then
		-- highlight the bombardable plots
		local NO_DIRECTION = -1;
		for iDX = -iRange, iRange, 1 do
			for iDY = -iRange, iRange, 1 do
				local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
				if pTargetPlot ~= nil then
					local plotX = pTargetPlot:GetX();
					local plotY = pTargetPlot:GetY();
					local plotDistance = Map.PlotDistance(thisX, thisY, plotX, plotY);
					if plotDistance <= iRange then
						local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
						if thingThatCanActuallyFire:CanRangeStrikeAt(plotX,plotY) then
							Events.SerialEventHexHighlight( hexID, true, highlightColor, "FireRangeBorder" );
							if (bHighlightTargets) then
								Events.SerialEventHexHighlight( hexID, true, redColor, "ValidFireTargetBorder");
							end
						else
							Events.SerialEventHexHighlight( hexID, true, highlightColor, "FireRangeBorder" );
						end
					end
				end
			end
		end
	end
end

-------------------------------------------------
function OrbitalStrikeHighlight()
	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();

	if pHeadSelectedUnit and pHeadSelectedUnit:CanAttackOrbital() then

		local iRange = pHeadSelectedUnit:OrbitalAttackRange();
		local thisPlot = pHeadSelectedUnit:GetPlot();
		local thisX = pHeadSelectedUnit:GetX();
		local thisY = pHeadSelectedUnit:GetY();
		local thisTeam = pHeadSelectedUnit:GetTeam();
		
		-- highlight the strikable plots
		local NO_DIRECTION = -1;
		for iDX = -iRange, iRange, 1 do
			for iDY = -iRange, iRange, 1 do
				
				local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
				if pTargetPlot ~= nil then

					local plotX = pTargetPlot:GetX();
					local plotY = pTargetPlot:GetY();
					local plotDistance = Map.PlotDistance(thisX, thisY, plotX, plotY);
					if plotDistance <= iRange then

						local hexID = ToHexFromGrid( Vector2( plotX, plotY) );

						if pHeadSelectedUnit:CanAttackOrbitalAt(plotX,plotY) then
							Events.SerialEventHexHighlight( hexID, true, highlightColor, "FireRangeBorder" );
						end
					end
				end
			end
		end
	elseif pHeadSelectedCity and pHeadSelectedCity:CanAttackOrbital() then
		local iRange = pHeadSelectedCity:GetOrbitalStrikeRange();
		local thisX = pHeadSelectedCity:GetX();
		local thisY = pHeadSelectedCity:GetY();
		
		-- highlight the strikable plots
		local NO_DIRECTION = -1;
		for iDX = -iRange, iRange, 1 do
			for iDY = -iRange, iRange, 1 do
				local pTargetPlot = Map.GetPlotXY(thisX, thisY, iDX, iDY);
				if pTargetPlot ~= nil then
					local plotX = pTargetPlot:GetX();
					local plotY = pTargetPlot:GetY();
					if pHeadSelectedCity:CanAttackOrbitalAt(plotX,plotY) then
						local hexID = ToHexFromGrid( Vector2( plotX, plotY) );
						Events.SerialEventHexHighlight( hexID, true, highlightColor, "FireRangeBorder" );
					end
				end
			end
		end
	end
end

-------------------------------------------------
function SupportActionHighlight(missionID : number)

	local headSelectedUnit : object = UI.GetHeadSelectedUnit();
	if headSelectedUnit and headSelectedUnit:CanDoSupportAction(missionID) then

		local missionInfo = GameInfo.Missions[missionID];
		if (missionInfo == nil) then
			error("Mission info not found");
			return;
		end

		local unitInfo = GameInfo.Units[headSelectedUnit:GetUnitType()];
		local unitMissionInfo : table = nil;
		for row in GameInfo.Unit_SupportMissions{ UnitType = unitInfo.Type, MissionType = missionInfo.Type } do
			unitMissionInfo = row;
			break;
		end

		local plotX : number;
		local plotY : number;

		local range : number = headSelectedUnit:Range();
		if (unitMissionInfo ~= nil and unitMissionInfo.RangeOverride >= 0) then
			range = unitMissionInfo.RangeOverride;
		end
		local currentPlot = headSelectedUnit:GetPlot();
		if (currentPlot ~= nil) then
			plotX = headSelectedUnit:GetX();
			plotY = headSelectedUnit:GetY();
		end
		local unitTeam : number = headSelectedUnit:GetTeam();
		
		-- highlight the plots this unit can target
		local NO_DIRECTION : number = -1;
		local dirX : number;
		local dirY : number;

		for dirX = -range, range, 1 do
			for dirY = -range, range, 1 do

				local targetPlot = Map.GetPlotXY(plotX, plotY, dirX, dirY);
				if targetPlot ~= nil then

					local targetX : number = targetPlot:GetX();
					local targetY : number = targetPlot:GetY();
					local plotDistance : number = Map.PlotDistance(plotX, plotY, targetX, targetY);
					if plotDistance <= range then

						if currentPlot:CanSeePlot(targetPlot, unitTeam, range - 1, NO_DIRECTION) then

							local hexID = ToHexFromGrid(Vector2(targetX, targetY));
							Events.SerialEventHexHighlight(hexID, true, blueColor, "SupportActionBorder" );

							if headSelectedUnit:CanDoSupportActionAt(missionID, targetX, targetY) then
								Events.SerialEventHexHighlight(hexID, true, blueColor, "SupportActionTargetBorder");
							end
						end
					end
				end
			end
		end
	end
end

-------------------------------------------------
function DisplayBombardArrow( hexX, hexY )
	--find the selected attacker
	local unit = UI.GetHeadSelectedUnit();
	local city = UI.GetHeadSelectedCity();
	local selectedLocX = UI.GetSelectedImprovementPlotX();
	local selectedLocY = UI.GetSelectedImprovementPlotY();
	local selectedSitePlot = Map.GetPlot(selectedLocX, selectedLocY);
	local selectedSite = selectedSitePlot:GetPlotStrategicSite();

	local attacker;
	if city and city:CanRangeStrike() then
		attacker = city;
	elseif unit and unit:CanRangeStrike() then
		attacker = unit
	elseif selectedSite and selectedSite:CanRangeStrike() then
		attacker = selectedSite;
	end
	
	if attacker == nil then
		return
	end
	
	--get bombard end hex
	if attacker:CanRangeStrikeAt( hexX, hexY ) then
		Events.SpawnArrowEvent( attacker:GetX(), attacker:GetY(), hexX, hexY );
	else
		Events.RemoveAllArrowsEvent();
	end
	
end


-------------------------------------------------
function DisplayNukeArrow( hexX, hexY )
	----find the selected attacker
	--local unit = UI.GetHeadSelectedUnit();
	--if unit and unit:CanNuke() then
		--attacker = unit
	--end
	--
	--if attacker == nil then
		--return
	--end
	--
	----get bombard end hex
	--if attacker:CanNukeAt( hexX, hexY ) then
		--Events.SpawnArrowEvent( attacker:GetX(), attacker:GetY(), hexX, hexY );
	--else
		--Events.RemoveAllArrowsEvent();
	--end
	--
end


-------------------------------------------------
-------------------------------------------------

function BeginRangedAttack()

	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();

	local selectedLocX = UI.GetSelectedImprovementPlotX();
	local selectedLocY = UI.GetSelectedImprovementPlotY();
	local selectedSitePlot = Map.GetPlot(selectedLocX, selectedLocY);
	local selectedSite = selectedSitePlot:GetPlotStrategicSite();

	-- Validate the Interface Mode
	local interfaceMode = UI.GetInterfaceMode();
	if (interfaceMode == InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK) then
		if (pHeadSelectedCity ~= nil) then
			-- Keep track of the city, in case the selection changes
			ms_CityBombardPlayer = pHeadSelectedCity:GetOwner();
			ms_CityBombardID = pHeadSelectedCity:GetID();			
		elseif (selectedSite ~= nil) then			
			ms_CityBombardPlayer = selectedSitePlot:GetOwner();
			ms_SiteBombardPlotIndex = selectedSitePlot:GetPlotIndex();
		else
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			return;
		end
	end

	if (interfaceMode == InterfaceModeTypes.INTERFACEMODE_RANGE_ATTACK) then
		if (pHeadSelectedUnit == nil) then
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			return;
		end
	end
	
	local cityCanStrike : boolean = pHeadSelectedCity and pHeadSelectedCity:CanRangeStrike();
	local unitCanStrike : boolean = pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrike();
	local siteCanStrike : boolean = selectedSite and selectedSite:CanRangeStrike();
	if (cityCanStrike or unitCanStrike or siteCanStrike) then
		Events.SerialEventMouseOverHex.Add( DisplayBombardArrow );
		RangedStrikeHighlight();
	end
end

-------------------------------------------------
function EndRangedAttack()
	Events.RemoveAllArrowsEvent();
	Events.SerialEventMouseOverHex.Remove( DisplayBombardArrow );
	ClearUnitHexHighlights();
end

-------------------------------------------------
function OnCityInfoDirty()
	local interfaceMode = UI.GetInterfaceMode();
	if (interfaceMode == InterfaceModeTypes.INTERFACEMODE_CITY_RANGE_ATTACK) then
		local pHeadSelectedCity = UI.GetHeadSelectedCity();

		local selectedLocX = UI.GetSelectedImprovementPlotX();
		local selectedLocY = UI.GetSelectedImprovementPlotY();
		local selectedSitePlot = Map.GetPlot(selectedLocX, selectedLocY);
		local selectedSite = selectedSitePlot:GetPlotStrategicSite();

		-- Still selected?
		if (pHeadSelectedCity == nil and selectedSite == nil) then
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			return;
		-- Same city?
		elseif (pHeadSelectedCity ~= nil) then
			if (pHeadSelectedCity:GetOwner() ~= ms_CityBombardPlayer or pHeadSelectedCity:GetID() ~= ms_CityBombardID) then
				UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			end
		end
	end
end
Events.SerialEventCityInfoDirty.Add(OnCityInfoDirty);

-------------------------------------------------
-- ORBITAL
-------------------------------------------------

function BeginOrbitalAttack()
	local pHeadSelectedCity = UI.GetHeadSelectedCity();
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	
	if (pHeadSelectedUnit and pHeadSelectedUnit:CanAttackOrbital()) then
		OrbitalStrikeHighlight();
	elseif (pHeadSelectedCity and pHeadSelectedCity:CanAttackOrbital()) then
		OrbitalStrikeHighlight();
	end
end

-------------------------------------------------
function EndOrbitalAttack()
	Events.RemoveAllArrowsEvent();
	--Events.SerialEventMouseOverHex.Remove( DisplayBombardArrow );
	ClearUnitHexHighlights();
end

-------------------------------------------------
-- AIR
-------------------------------------------------

function BeginAirAttack()
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	
	if (pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrike()) then
		Events.SerialEventMouseOverHex.Add( DisplayBombardArrow );
		AirStrikeHighlight(true);
	end

end

-------------------------------------------------
function EndAirAttack()
	Events.RemoveAllArrowsEvent();
	Events.SerialEventMouseOverHex.Remove( DisplayBombardArrow );
	ClearUnitHexHighlights();
end

-------------------------------------------------
function BeginAirSweep()
	local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	if (pHeadSelectedUnit and pHeadSelectedUnit:CanRangeStrike()) then
		AirStrikeHighlight(false);
	end
end

-------------------------------------------------
function EndAirSweep()
	ClearUnitHexHighlights();
end

-------------------------------------------------
-- SUPPORT
-------------------------------------------------

function BeginSupportAction()

	local missionID : number = UI.GetInterfaceModeValue();
	if (missionID < 0) then
		error("Invalid mission ID");
		return;
	end

	local selectedUnit : object = UI.GetHeadSelectedUnit();	
	if (selectedUnit and selectedUnit:CanDoSupportAction(missionID)) then
		SupportActionHighlight(missionID);
	end
end

-------------------------------------------------
function EndSupportAction()
	Events.RemoveAllArrowsEvent();
	ClearUnitHexHighlights();
end
-------------------------------------------------
-------------------------------------------------
function BeginNukeAttack()
	--local pHeadSelectedUnit = UI.GetHeadSelectedUnit();
	--print("pHeadSelectedUnit:"..tostring(pHeadSelectedUnit))
	--if (pHeadSelectedUnit and pHeadSelectedUnit:CanNuke()) then
		--Events.SerialEventMouseOverHex.Add( DisplayNukeArrow );
		--NukeStrikeHighlight();
	--end
--
end

-------------------------------------------------
function EndNukeAttack()
	--Events.RemoveAllArrowsEvent();
	--Events.SerialEventMouseOverHex.Remove( DisplayNukeArrow );
	--ClearUnitHexHighlights();
end