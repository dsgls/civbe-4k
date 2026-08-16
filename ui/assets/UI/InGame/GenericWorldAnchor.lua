include( "IconSupport" );

-------------------------------------------------
-------------------------------------------------
local m_SettlerWorldAnchorStore = {};
local m_WorkerWorldAnchorStore = {};
local m_ExplorerWorldAnchorStore = {};
local m_gridWidth, _ = Map.GetGridSize();

local g_RecommendationIconOffsetX = 0;
local g_RecommendationIconOffsetY = 0;
local g_RecommendationIconOffsetZ = 0;

-------------------------------------------------
-------------------------------------------------
function IndexFromGrid( x, y )
    return x + (y * m_gridWidth);
end


-------------------------------------------------
-------------------------------------------------
function OnGenericWorldAnchor( type, bShow, iPlotX, iPlotY, iData1 )

	--print("World anchor event called");
	--print("Data1 is... " .. tostring(iData1));

    if( type == GenericWorldAnchorTypes.WORLD_ANCHOR_SETTLER ) then
        HandleSettlerRecommendation( bShow, iPlotX, iPlotY, iData1 );
    elseif( type == GenericWorldAnchorTypes.WORLD_ANCHOR_WORKER ) then
        HandleWorkerRecommendation( bShow, iPlotX, iPlotY, iData1 );
    elseif( type == GenericWorldAnchorTypes.WORLD_ANCHOR_EXPLORER ) then
		HandleExplorerRecommendation( bShow, iPlotX, iPlotY, iData1 );
	end

end
Events.GenericWorldAnchor.Add( OnGenericWorldAnchor );

-------------------------------------------------
-------------------------------------------------
function DestroySettlerAnchor( hexIndex )
	local instance = m_SettlerWorldAnchorStore[ hexIndex ];
	if( instance ~= nil ) then
		Controls.SettlerRecommendationStore:ReleaseChild( instance.Anchor );
		m_SettlerWorldAnchorStore[ hexIndex ] = nil;
	end
end

-------------------------------------------------
-------------------------------------------------
function HandleSettlerRecommendation( bShow, iPlotX, iPlotY, iData1 )
	
	local hexIndex = IndexFromGrid( iPlotX, iPlotY );
	
	local pPlot = Map.GetPlot(iPlotX, iPlotY);
	
	-- If we can't actually found here, don't show the recommendation!
	if (bShow and not Players[Game.GetActivePlayer()]:CanFound(iPlotX, iPlotY)) then
		print("Can't found at: " .. iPlotX .. ", " .. iPlotY);
		return;
	end

	if( bShow ) then
		--print("Showing Settler Recommendation at " .. iPlotX .. ", " .. iPlotY);
		
		local instance = m_SettlerWorldAnchorStore[ hexIndex ];
        
		-- Don't make another copy of something that exists here already
		if( instance == nil ) then
			instance = {};
			ContextPtr:BuildInstanceForControl( "SettlerRecommendation", instance, Controls.SettlerRecommendationStore );
			m_SettlerWorldAnchorStore[ hexIndex ] = instance;

			local x, y, z = GridToWorld( iPlotX, iPlotY );
			instance.Anchor:SetWorldPositionVal( x + g_RecommendationIconOffsetX, y + g_RecommendationIconOffsetY, z + g_RecommendationIconOffsetZ );
			
			local iActiveTeam = Game.GetActiveTeam();
			local pPlayer = Players[Game.GetActivePlayer()];
	        
	        local strToolTip = "";
	        
	        strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_SETTLER_BASE");
			strToolTip = strToolTip .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("TXT_KEY_RECOMMEND_SETTLER_MESSAGE");
	        
	        --local iTotalFood = 0;
	        --local iTotalProduction = 0;
	        --local iTotalEnergy = 0;
	        --local iBasicResources = 0;
	        --local iStrategicResources = 0;
	        
	        --local iNumPlots = 0;
	        
	        ---- Loop around this plot to see what's nearby
			--local iRange = 2;
			--for iDX = -iRange, iRange, 1 do
				--for iDY = -iRange, iRange, 1 do
					--local pTargetPlot = Map.GetPlotXY(iPlotX, iPlotY, iDX, iDY);
					--if pTargetPlot ~= nil then
						--local plotX = pTargetPlot:GetX();
						--local plotY = pTargetPlot:GetY();
						--local plotDistance = Map.PlotDistance(iPlotX, iPlotY, plotX, plotY);
						--if (plotDistance <= iRange) then
							
							--iNumPlots = iNumPlots + 1;
							
							---- Sum up what we find on this plot
							--iTotalFood = iTotalFood + pTargetPlot:GetYield(YieldTypes.YIELD_FOOD);
							--iTotalProduction = iTotalProduction + pTargetPlot:GetYield(YieldTypes.YIELD_PRODUCTION);
							--iTotalEnergy = iTotalEnergy + pTargetPlot:GetYield(YieldTypes.YIELD_ENERGY);
							
							---- Resource
							--if (not pTargetPlot:IsOwned()) then
								--local iResource = pTargetPlot:GetResourceType(iActiveTeam);
								--if (iResource ~= -1) then

									--local iResourceClass = Game.GetResourceClassType(iResource);
									
									--if (iResourceClass == GameInfo.ResourceClasses["RESOURCECLASS_BASIC"].ID) then
										--iBasicResources = iBasicResources + 1;
									--elseif (iUsage == GameInfo.ResourceClasses["RESOURCECLASS_STRATEGIC"].ID) then
										--iStrategicResources = iStrategicResources + 1;
									--end
								--end
							--end
						--end
					--end
				--end
			--end 			

	        ---- So, what's near this spot?

	        ---- Basic Resources
	        --if (iBasicResources > 0) then
				--strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
				--strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_SETTLER_RESOURCES");
			---- Strategic Resources
	        --elseif (iStrategicResources > 0) then
				--strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
				--strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_SETTLER_STRATEGIC");
			---- Energy
	        --elseif (iTotalEnergy / iNumPlots > 0.75) then
				--strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
				--strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_SETTLER_GOLD");
			---- Production
	        --elseif (iTotalProduction / iNumPlots > 0.75) then
				--strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
				--strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_SETTLER_PRODUCTION");
			---- Food
			--elseif (iTotalFood / iNumPlots > 1.2) then
				--strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
				--strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_SETTLER_FOOD");
	        --end
	        
			instance.Icon:SetToolTipString(strToolTip);
		end
	else
		DestroySettlerAnchor( hexIndex );
	end
	
end

-------------------------------------------------
-------------------------------------------------
function DestroyWorkerAnchor( hexIndex )
    local instance = m_WorkerWorldAnchorStore[ hexIndex ];
    if( instance ~= nil ) then
        Controls.WorkerRecommendationStore:ReleaseChild( instance.Anchor );
        m_WorkerWorldAnchorStore[ hexIndex ] = nil;
    end
end
-------------------------------------------------
-------------------------------------------------
function HandleWorkerRecommendation( bShow, iPlotX, iPlotY, iData1 )

    local hexIndex = IndexFromGrid( iPlotX, iPlotY );

    if( bShow ) then
		--print("Showing Worker Recommendation at " .. iPlotX .. ", " .. iPlotY);
		
        local instance = m_WorkerWorldAnchorStore[ hexIndex ];
        
        -- Don't make another copy of something that exists here already
        if( instance == nil ) then
			instance = {};
			ContextPtr:BuildInstanceForControl( "WorkerReccomendation", instance, Controls.WorkerRecommendationStore );
			m_WorkerWorldAnchorStore[ hexIndex ] = instance;

			local x, y, z = GridToWorld( iPlotX, iPlotY );
			instance.Anchor:SetWorldPositionVal( x + g_RecommendationIconOffsetX, y + g_RecommendationIconOffsetY, z + g_RecommendationIconOffsetZ );
	        
	        local iBuild = iData1;
	        local pBuildInfo = GameInfo.Builds[iBuild];
	        local iImprovement = pBuildInfo.ImprovementType;
	        local iRoute = pBuildInfo.RouteType;
	        local thisInfo;
	        
	        -- Tooltip
	        local strToolTip = Locale.ConvertTextKey("TXT_KEY_RECOMMEND_WORKER", pBuildInfo.Description);
	        
			local pPlot = Map.GetPlot(iPlotX, iPlotY);
	        local iResource = pPlot:GetResourceType(Game.GetActiveTeam());
	        
	        -- Resource here to be hooked up?
	        if (iResource ~= -1 and GameInfo.Resources[iResource].ResourceClassType == GameDefines["STRATEGIC_RESOURCECLASS"]) then
				-- Strategic
				strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
				strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_WORKER_STRATEGIC");
				
	        -- Custom help?
			else
				local strCustomHelp = pBuildInfo.Recommendation;
		        
				if (strCustomHelp ~= nil) then
					strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
					strToolTip = strToolTip .. Locale.ConvertTextKey(strCustomHelp);
				else
					local iYieldChange;
					for iYield = 0, YieldTypes.NUM_YIELD_TYPES-1, 1 do
						iYieldChange = pPlot:GetYieldWithBuild(iBuild, iYield, false, Game.GetActivePlayer());
						iYieldChange = iYieldChange - pPlot:CalculateYield(iYield);
			
						if (iYieldChange > 0) then
							strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";
							if (iYield == YieldTypes.YIELD_FOOD) then
								strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_BUILD_FOOD_REC");
							elseif (iYield == YieldTypes.YIELD_PRODUCTION) then
								strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_BUILD_PROD_REC");
							elseif (iYield == YieldTypes.YIELD_ENERGY) then
								strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_BUILD_ENERGY_REC");
							elseif (iYield == YieldTypes.YIELD_CULTURE) then
								strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_BUILD_CULTURE_REC");
							elseif (iYield == YieldTypes.YIELD_SCIENCE) then
								strToolTip = strToolTip .. Locale.ConvertTextKey("TXT_KEY_BUILD_SCIENCE_REC");
							end							
						end
					end
				end
	        end
	        
			instance.Icon:SetToolTipString(strToolTip);
	    	IconHookup( pBuildInfo.IconIndex, 45, pBuildInfo.IconAtlas, instance.Icon );		
		end
    else
		DestroyWorkerAnchor( hexIndex );
    end
end

-------------------------------------------------
-------------------------------------------------
function DestroyExplorerAnchor( hexIndex )
    local instance = m_ExplorerWorldAnchorStore[ hexIndex ];
    if( instance ~= nil ) then
        Controls.ExplorerRecommendationStore:ReleaseChild( instance.Anchor );
        m_ExplorerWorldAnchorStore[ hexIndex ] = nil;
    end
end
-------------------------------------------------
-------------------------------------------------
function HandleExplorerRecommendation( bShow, iPlotX, iPlotY, iData1 )

    local hexIndex = IndexFromGrid( iPlotX, iPlotY );

    if( bShow ) then
        local instance = m_ExplorerWorldAnchorStore[ hexIndex ];
        -- Don't make another copy of something that exists here already
        if( instance == nil ) then
			instance = {};
			ContextPtr:BuildInstanceForControl( "ExplorerRecommendation", instance, Controls.ExplorerRecommendationStore );
			m_ExplorerWorldAnchorStore[ hexIndex ] = instance;
			local x, y, z = GridToWorld( iPlotX, iPlotY );
			instance.Anchor:SetWorldPositionVal( x + g_RecommendationIconOffsetX, y + g_RecommendationIconOffsetY, z + g_RecommendationIconOffsetZ );

			local tooltip = Locale.ConvertTextKey("TXT_KEY_RECOMMEND_EXPLORER_BASE");
			tooltip = tooltip .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_RECOMMEND_EXPLORER_MESSAGE");
			instance.Icon:SetToolTipString(tooltip);
		end
    else
		DestroyExplorerAnchor( hexIndex );
    end
end

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged(iActivePlayer, iPrevActivePlayer)
	
	-- Currently, all Generic World Anchors only exist for one turn, so just 
	-- remove all of the old player's anchors
	for index, pResource in pairs( m_SettlerWorldAnchorStore ) do
        DestroySettlerAnchor( index );
   	end
	for index, pResource in pairs( m_WorkerWorldAnchorStore ) do
        DestroyWorkerAnchor( index );
   	end
	for index, pResource in pairs( m_ExplorerWorldAnchorStore ) do
		DestroyExplorerAnchor( index );
	end
		
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);
