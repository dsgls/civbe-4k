-------------------------------------------------
-- Resource Icon Manager
-------------------------------------------------
include( "InstanceManager" );
include( "ResourceTooltipGenerator" );
include( "IconSupport" );

local g_ResourceManager = InstanceManager:new( "ResourceIcon", "Anchor", Controls.ResourceIconContainer );
local g_ArtifactManager = InstanceManager:new( "ArtifactIcon", "Anchor", Controls.ArtifactIconContainer );
local g_NestManager = InstanceManager:new( "NestIcon", "Anchor", Controls.NestIconContainer );

local g_ResourceIconOffsetX = -30; -- this is in world space and corresponds to the top-left vertex of the hex
local g_ResourceIconOffsetY = 15;  -- this is in world space and corresponds to the top-left vertex of the hex
local g_ResourceIconOffsetZ = 0;   -- this is in world space and corresponds to the top-left vertex of the hex

local g_bHideResourceIcons = not OptionsManager.GetResourceOn();
local g_bHideArtifactIcons = not OptionsManager.GetArtifactOn();
local g_bHideNestIcons = not OptionsManager.GetNestsOn();
local g_bIsStrategicView   = false;

local g_ActiveSet = {};
local g_PerPlayerResourceTables = {};
local g_PerPlayerImprovementTables = {};

local g_gridWidth, _ = Map.GetGridSize();
------------------------------------------------------------------
------------------------------------------------------------------
function IndexFromGrid( x, y )
    return x + (y * g_gridWidth);
end

------------------------------------------------------------------
------------------------------------------------------------------
function GridFromIndex( index )
	local y = math.floor(index / g_gridWidth);
    return (index - (y * g_gridWidth)), y;
end

------------------------------------------------------------------
------------------------------------------------------------------
function DestroyResource( index )
    local pair = g_ActiveSet[ index ];
    if ( pair ~= nil and pair.Instance ~= nil and pair.IsResource == true ) then
		if ( pair.IsArtifact ) then
			g_ArtifactManager:ReleaseInstance( pair.Instance );
		else
			g_ResourceManager:ReleaseInstance( pair.Instance );
		end
        g_ActiveSet[ index ] = nil;
	end
end

------------------------------------------------------------------
------------------------------------------------------------------
function DestroyImprovement( index )

    local pair = g_ActiveSet[ index ];
    if (pair ~= nil and pair.Instance ~= nil and pair.IsResource == false) then

		g_NestManager:ReleaseInstance( pair.Instance );

        g_ActiveSet[ index ] = nil;
	end
end

-------------------------------------------------
-------------------------------------------------
function BuildResource( index, gridX, gridY, resourceType )

	DestroyResource(index);

	local resourceInfo = GameInfo.Resources[resourceType];
	local instance = nil;

	if (resourceInfo.ResourceClassType == "RESOURCECLASS_ARTIFACT" or resourceInfo.ResourceClassType == "RESOURCECLASS_QUEST_ARTIFACT") then
		instance = g_ArtifactManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = true, IsResource = true };
	else
		instance = g_ResourceManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = false, IsResource = true };
	end
		
	local x, y, z = GridToWorldClamped( gridX, gridY ); -- Keep above water.

	instance.Anchor:SetWorldPositionVal( x + g_ResourceIconOffsetX,
										 y + g_ResourceIconOffsetY,
										 z + g_ResourceIconOffsetZ );
										 										 
	IconHookup(resourceInfo.PortraitIndex, 64, resourceInfo.IconAtlas, instance.Icon);
	
	-- Tool Tip
	local plot = Map.GetPlot( gridX, gridY );
	local strToolTip = GenerateResourceToolTip(plot);
	if( strToolTip ~= nil ) then
		instance.Icon:SetToolTipString(strToolTip);
	end
end

-------------------------------------------------
-------------------------------------------------
function BuildImprovement( index, gridX, gridY, improvementType )

	DestroyImprovement(index);

	local improvementInfo = GameInfo.Improvements[improvementType];
	local instance = nil;

	if (improvementInfo.AlienNest == true) then
		instance = g_NestManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = false; IsResource = false };

		local x, y, z = GridToWorldClamped( gridX, gridY ); -- Keep above water.

		instance.Anchor:SetWorldPositionVal( x + g_ResourceIconOffsetX,
											 y + g_ResourceIconOffsetY,
											 z + g_ResourceIconOffsetZ );
										 										 
		IconHookup(improvementInfo.PortraitIndex, 64, improvementInfo.IconAtlas, instance.Icon);
	
		-- Tool Tip
		local plot = Map.GetPlot( gridX, gridY );
		local strToolTip = nil; --GenerateResourceToolTip(plot);
		if( strToolTip ~= nil ) then
			instance.Icon:SetToolTipString(strToolTip);
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function OnResourceAdded( hexPosX, hexPosY, ImprovementType, ResourceType, ImprovementState, Layer )

	-- TODO: Allow multiple resource icons
	--if Layer ~= 2 then
	--	return;
	--end

	if ResourceType > -1 then
		local gridX, gridY  = ToGridFromHex( hexPosX, hexPosY );
        local plot = Map.GetPlot( gridX, gridY );

		-- Because we will get this message at load time as well as while the game is
		-- in progress, if this is a hotseat game, add the resource icons for all players
		-- This should be safe to do for a game with a single human, but its a bit slower so we'll keep it separate.
		if ( PreGame.IsHotSeatGame() ) then
			local bIsBuilt = false;
			for iPlayerID = 0, GameDefines.MAX_PLAYERS do
				local pPlayer = Players[iPlayerID];
				if( pPlayer ~= nil and pPlayer:IsHuman() ) then
					if( plot:IsRevealed( pPlayer:GetTeam(), false ) ) then
						-- Build the icon
						local index = IndexFromGrid( gridX, gridY );
						-- Only need to build the resource if the active team can see this
						if( not bIsBuilt and pPlayer:GetTeam() == Game.GetActiveTeam() ) then
							BuildResource( index, gridX, gridY, ResourceType );
							bIsBuilt = true;
						end
						
						-- Store the resource for the player
						if (g_PerPlayerResourceTables[ iPlayerID ] == nil) then
							g_PerPlayerResourceTables[ iPlayerID ] = {};
						end
						
						local playerResourceTable = g_PerPlayerResourceTables[ iPlayerID ];		
						playerResourceTable[index] = ResourceType;
					end
				end
			end
		else
			if( not plot:IsRevealed( Game.GetActiveTeam(), false ) ) then
				return;
			end

			-- Build the icon
			local index = IndexFromGrid( gridX, gridY );
			BuildResource( index, gridX, gridY, ResourceType );
			
			-- Store the resource for the current player
			local iPlayerID = Game.GetActivePlayer();		
			if (g_PerPlayerResourceTables[ iPlayerID ] == nil) then
				g_PerPlayerResourceTables[ iPlayerID ] = {};
			end
			
			local playerResourceTable = g_PerPlayerResourceTables[ iPlayerID ];		
			playerResourceTable[index] = ResourceType;			
		end
    end
end
Events.SerialEventRawResourceIconCreated.Add( OnResourceAdded )

-------------------------------------------------
-------------------------------------------------
function OnResourceRemoved( hexPosX, hexPosY, Layer )

	-- TODO: Allow multiple resource icons
	--if Layer ~= 2 then
	--	return;
	--end

	local gridX, gridY  = ToGridFromHex( hexPosX, hexPosY );
    local plot = Map.GetPlot( gridX, gridY );

	if( not plot:IsRevealed( Game.GetActiveTeam(), false ) ) then
		return;
	end

	-- Remove the icon
	local index = IndexFromGrid( gridX, gridY );
	DestroyResource(index);
	
	-- Remove the resource from the current player
	for iPlayerID = 0, GameDefines.MAX_PLAYERS do
		local playerResourceTable = g_PerPlayerResourceTables[ iPlayerID ];		
		if (g_PerPlayerResourceTables[ iPlayerID ] ~= nil) then
			playerResourceTable[index] = nil;
		end
	end
end
Events.SerialEventRawResourceIconDestroyed.Add( OnResourceRemoved )

-------------------------------------------------
-------------------------------------------------
function OnImprovementAdded( hexPosX, hexPosY, ImprovementType, ResourceType, ImprovementState, Layer )

	if ImprovementType > -1 then
		local gridX, gridY  = ToGridFromHex( hexPosX, hexPosY );
        local plot = Map.GetPlot( gridX, gridY );

		-- Don't show completed expeditions
		if( ImprovementType ~= -1 and GameInfo.Improvements[ImprovementType].Type == "IMPROVEMENT_EXPEDITION") then
			if( ImprovementState == 2 ) then
				return;
			end
		end

		-- Because we will get this message at load time as well as while the game is
		-- in progress, if this is a hotseat game, add the icons for all players
		-- This should be safe to do for a game with a single human, but its a bit slower so we'll keep it separate.
		if ( PreGame.IsHotSeatGame() ) then
			local bIsBuilt = false;
			for iPlayerID = 0, GameDefines.MAX_PLAYERS do
				local pPlayer = Players[iPlayerID];
				if( pPlayer ~= nil and pPlayer:IsHuman() ) then
					if( plot:IsRevealed( pPlayer:GetTeam(), false ) ) then
						-- Build the icon
						local index = IndexFromGrid( gridX, gridY );
						-- Only need to build the icon if the active team can see this
						if( not bIsBuilt and pPlayer:GetTeam() == Game.GetActiveTeam() ) then
							BuildImprovement( index, gridX, gridY, ImprovementType );
							bIsBuilt = true;
						end
						
						-- Store the improvement for the player
						if (g_PerPlayerImprovementTables[ iPlayerID ] == nil) then
							g_PerPlayerImprovementTables[ iPlayerID ] = {};
						end
						
						local playerImprovementTable = g_PerPlayerImprovementTables[ iPlayerID ];
						playerImprovementTable[index] = ImprovementType;
					end
				end
			end
		else
			if( not plot:IsRevealed( Game.GetActiveTeam(), false ) ) then
				return;
			end

			-- Build the icon
			local index = IndexFromGrid( gridX, gridY );
			BuildImprovement( index, gridX, gridY, ImprovementType );
			
			-- Store the resource for the current player
			local iPlayerID = Game.GetActivePlayer();		
			if (g_PerPlayerImprovementTables[ iPlayerID ] == nil) then
				g_PerPlayerImprovementTables[ iPlayerID ] = {};
			end
			
			local playerImprovementTable = g_PerPlayerImprovementTables[ iPlayerID ];		
			playerImprovementTable[index] = ImprovementType;			
		end
    end
end
Events.SerialEventImprovementIconCreated.Add( OnImprovementAdded )

-------------------------------------------------
-------------------------------------------------
function OnImprovementRemoved( hexPosX, hexPosY, Layer )

	local gridX, gridY  = ToGridFromHex( hexPosX, hexPosY );
    local plot = Map.GetPlot( gridX, gridY );

	if( not plot:IsRevealed( Game.GetActiveTeam(), false ) ) then
		return;
	end

	-- Remove the icon
	local index = IndexFromGrid( gridX, gridY );
	DestroyImprovement(index);
	
	-- Remove the resource from the current player
	for iPlayerID = 0, GameDefines.MAX_PLAYERS do
		local playerImprovementTable = g_PerPlayerImprovementTables[ iPlayerID ];		
		if (g_PerPlayerImprovementTables[ iPlayerID ] ~= nil) then
			playerImprovementTable[index] = nil;
		end
	end
end
Events.SerialEventImprovementIconDestroyed.Add( OnImprovementRemoved )

-------------------------------------------------
-------------------------------------------------
function OnRequestYieldDisplay( type )

    if( type == YieldDisplayTypes.USER_ALL_RESOURCE_ON ) then
        g_bHideResourceIcons = false;
    elseif( type == YieldDisplayTypes.USER_ALL_RESOURCE_OFF ) then
        g_bHideResourceIcons = true;
    elseif( type == YieldDisplayTypes.USER_ALL_ARTIFACT_ON ) then
		g_bHideArtifactIcons = false;
	elseif( type == YieldDisplayTypes.USER_ALL_ARTIFACT_OFF ) then
		g_bHideArtifactIcons = true;
	elseif( type == YieldDisplayTypes.USER_ALL_NESTS_ON ) then
		g_bHideNestIcons = false;
	elseif( type == YieldDisplayTypes.USER_ALL_NESTS_OFF ) then
		g_bHideNestIcons = true;
	end
    
    if( not g_bIsStrategicView ) then
        Controls.ResourceIconContainer:SetHide( g_bHideResourceIcons );
		Controls.ArtifactIconContainer:SetHide( g_bHideArtifactIcons );
		Controls.NestIconContainer:SetHide( g_bHideNestIcons );
    end
end
Events.RequestYieldDisplay.Add( OnRequestYieldDisplay );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged(iActivePlayer, iPrevActivePlayer)
	
	-- Reset the resource data.
	for index, t in pairs( g_ActiveSet ) do
		if( t.IsResource ) then
			DestroyResource( index );
		else
			DestroyImprovement( index );
		end
   	end

	-- Rebuild with the current player's stored data.
	local playerResourceTable = g_PerPlayerResourceTables[ iActivePlayer ];
	if (playerResourceTable ~= nil) then
		for index, resource in pairs( playerResourceTable ) do
			local gridX, gridY = GridFromIndex(index);
			BuildResource( index, gridX, gridY, resource );
   		end
   	end
		
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);
