-------------------------------------------------
-- Resource Icon Manager
-------------------------------------------------
include( "InstanceManager" );
include( "ResourceTooltipGenerator" );
include( "IconSupport" );

local g_ResourceManager = InstanceManager:new( "ResourceIcon", "Anchor", Controls.ResourceIconContainer );
local g_ArtifactManager = InstanceManager:new( "ArtifactIcon", "Anchor", Controls.ArtifactIconContainer );
local g_NestManager = InstanceManager:new( "NestIcon", "Anchor", Controls.NestIconContainer );
local g_MinorMarvelManager = InstanceManager:new( "MinorMarvelIcon", "Anchor", Controls.MinorMarvelContainer );

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

local g_NEST_ICON_ONLY = 0;
local g_ARTIFACT_OR_RESOURCE = 1;
local g_ANY = 2;

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
function DestroyIcon( index, type )
    local pair = g_ActiveSet[ index ];
    if ( pair ~= nil and pair.Instance ~= nil ) then

		if( pair.IsArtifact and ( type ~= g_NEST_ICON_ONLY ) ) then
			g_ArtifactManager:ReleaseInstance( pair.Instance );
			g_ActiveSet[ index ] = nil;
		elseif( pair.IsNest and type ~= g_ARTIFACT_OR_RESOURCE ) then
			g_NestManager:ReleaseInstance( pair.Instance );
			g_ActiveSet[ index ] = nil;
		elseif( pair.IsMinorMarvel ) then
			g_MinorMarvelManager:ReleaseInstance( pair.Instance );
			g_ActiveSet[ index ] = nil;
		elseif( type ~= g_NEST_ICON_ONLY ) then
			g_ResourceManager:ReleaseInstance( pair.Instance );
			g_ActiveSet[ index ] = nil;
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function BuildResource( index, gridX, gridY, resourceType )

	DestroyIcon(index, g_ARTIFACT_OR_RESOURCE);

	local resourceInfo = GameInfo.Resources[resourceType];
	local instance = nil;

	if (resourceInfo.ResourceClassType == "RESOURCECLASS_ARTIFACT" or resourceInfo.ResourceClassType == "RESOURCECLASS_QUEST_ARTIFACT") then
		instance = g_ArtifactManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = true,  IsNest = false };
	else
		instance = g_ResourceManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = false, IsNest = false };
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

	local improvementInfo = GameInfo.Improvements[improvementType];
	local instance = nil;

	if (improvementInfo.AlienNest == true) then

		DestroyIcon(index, g_NEST_ICON_ONLY);

		instance = g_NestManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = false, IsNest = true };

		local x, y, z = GridToWorldClamped( gridX, gridY ); -- Keep above water.

		instance.Anchor:SetWorldPositionVal( x + g_ResourceIconOffsetX,
											 y + g_ResourceIconOffsetY,
											 z + g_ResourceIconOffsetZ );
										 										 
		IconHookup(improvementInfo.PortraitIndex, 64, improvementInfo.IconAtlas, instance.Icon);
	
		-- Tool Tip
		local plot = Map.GetPlot( gridX, gridY );
		local strToolTip = GenerateImprovementToolTip(plot);
		if( strToolTip ~= nil ) then
			instance.Icon:SetToolTipString(strToolTip);
		end
	elseif (improvementInfo.MinorMarvel == true) then
		DestroyIcon(index);

		instance = g_MinorMarvelManager:GetInstance();
		g_ActiveSet[ index ] = { Instance = instance, IsArtifact = false, IsNest = false, IsMinorMarvel = true };

		local x, y, z = GridToWorldClamped( gridX, gridY ); -- Keep above water.

		instance.Anchor:SetWorldPositionVal( x + g_ResourceIconOffsetX,
											 y + g_ResourceIconOffsetY,
											 z + g_ResourceIconOffsetZ );
		
		local playerType : number = Game.GetActivePlayer();
		local player : object = Players[playerType];

		local marvelType : number = GameInfo.Marvels[improvementInfo.MarvelType].ID;
		local plot : object = Map.GetPlot( gridX, gridY );
					
		local isUsed : boolean = player:IsMinorMarvelPlotUnused(marvelType, plot:GetPlotIndex());

		local iconIndex : number;
		local iconAtlas : string;
		if(isUsed == true) then
			iconIndex = improvementInfo.MinorMarvelUsedFlagIconIndex;
			iconAtlas = improvementInfo.MinorMarvelUsedFlagIconAtlas;
		else
			iconIndex = improvementInfo.MinorMarvelUnusedFlagIconIndex;
			iconAtlas = improvementInfo.MinorMarvelUnusedFlagIconAtlas;
		end
									 										 
		IconHookup(iconIndex, 64, iconAtlas, instance.Icon);
	
		-- Tool Tip
		local strToolTip = GenerateImprovementToolTip(plot);
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
	DestroyIcon(index, g_ARTIFACT_OR_RESOURCE );
	
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
						
						-- Store the resource for the player
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
	DestroyIcon(index, g_NEST_ICON_ONLY );
	
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
		Controls.MinorMarvelContainer:SetHide( g_bHideArtifactIcons );
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
		if( t.Instance ~= nil and t.IsNest == false) then
			DestroyIcon( index, g_ARTIFACT_OR_RESOURCE );
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

function OnMinorMarvelUsed(playerType : number, plotIndex : number, marvelType : number)

	if(playerType ~= Game.GetActivePlayer()) then
		return;
	end

	local t : table = g_ActiveSet[plotIndex];
	if(t == nil) then
		return;
	end

	if( t.Instance ~= nil and t.IsMinorMarvel == true) then
		DestroyIcon( plotIndex );

		local plot : object = Map.GetPlotByIndex(plotIndex);
		if(plot == nil) then
			return;
		end

		local improvementType : number = plot:GetImprovementType();
		if(improvementType == nil) then
			return;
		end

		BuildImprovement( plotIndex, plot:GetX(), plot:GetY(), improvementType);
	end
end
Events.MinorMarvelUsed.Add(OnMinorMarvelUsed);
