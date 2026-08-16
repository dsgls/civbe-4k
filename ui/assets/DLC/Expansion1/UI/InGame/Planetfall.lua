-------------------------------------------------
-- Planetfall
-------------------------------------------------

local highlightStyle = "PlanetfallRange";
local highlightColor = Vector4( 1, 1, 0.4, 1 ); -- depending on the theme these may not actually be used (for example SplineBorder do not)

-------------------------------------------------
function BeginPlanetfall()

	local pPlayer = Players[Game.GetActivePlayer()];
	local pStartPlot = pPlayer:GetStartingPlot();

	-- Reveal planetfall target plots
	if pStartPlot == nil then
		error("Player start location must be a valid plot");
	end

	local sightRange = GameDefines.PLANETFALL_DEFAULT_SIGHT_RANGE;
	sightRange = sightRange + pPlayer:GetPlanetfallSightChange();

	local startX = pStartPlot:GetX();
	local startY = pStartPlot:GetY();

	Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(startX, startY)), true, highlightColor, highlightStyle );
	Events.RequestYieldDisplay( YieldDisplayTypes.AREA, sightRange, startX, startY );

	for iX = -sightRange, sightRange, 1 do
		for iY = -sightRange, sightRange, 1 do

			local candidatePlot = Map.PlotXYWithRangeCheck(startX, startY, iX, iY, sightRange);
			if candidatePlot then
				local candidateX = candidatePlot:GetX();
				local candidateY = candidatePlot:GetY();

				if pPlayer:CanPlanetfallFound(candidateX, candidateY) then
					Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(candidateX, candidateY)), true, highlightColor, highlightStyle);
				end
			end
		end
	end

	Map.UpdateDeferredFog();
	UI.LookAt(pStartPlot, 6);

	-- Set turn blocking notification
	pPlayer:AddNotification(NotificationTypes.NOTIFICATION_PLANETFALL, Locale.Lookup("TXT_KEY_NOTIFICATION_PLANETFALL_TT"), Locale.Lookup("TXT_KEY_NOTIFICATION_PLANETFALL"), startX, startY, -1);
end

function EndPlanetfall()
	
end

function ActivatePlanetfall()

	local plot = Map.GetPlot(UI.GetMouseOverHex());
	if plot ~= nil then
		
		local plotX = plot:GetX();
		local plotY = plot:GetY();

		local playerID = Game.GetActivePlayer();
		local pPlayer = Players[playerID];

		if pPlayer:CanPlanetfallFound(plotX, plotY) then

			Events.RequestYieldDisplay( YieldDisplayTypes.AREA, 0, 0, 0 );	-- Turn off the yields we manually turned on.

			Network.SendPlanetfall(playerID, plotX, plotY, false);
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
		end
	end
end