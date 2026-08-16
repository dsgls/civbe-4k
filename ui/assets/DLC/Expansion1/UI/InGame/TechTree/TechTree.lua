------------------------------------------------------------------------------
-- Technology Web
------------------------------------------------------------------------------
include( "InstanceManager" );
include( "SupportFunctions" );
include( "TechButtonInclude" );
include( "TechHelpInclude" );
include( "AffinityInclude" );
include( "MathHelpers" );
include( "TechFilterFunctions" );


-- ===== 1 Time Toggable Options =============================================

local m_fastDebug						= false; 	-- Debug: Use to animated in all nodes while debugging (before they are done loaded.)
local m_profiling						= false;		-- Debug: turn on profile functions
local m_showTechIDsDebug				= false;	-- Debug: Show technology IDs in their names
local m_forceNodesNum					= -1; 		-- Debug: Force only this many nodes on the tree
local isLookLikeWindows95				= false;	-- Miss windows 95? Turn this on.
local isHasLineSparkles					= false;	-- Faint Sparkles along ALL lines
local isHasLineSparklesAvailable		= true;		-- Same as above but for available lines only.


-- ===== COLOR and TEXTURE constants =========================================

-- Colors are in ABGR hex format:
local MAX_LINE_SPARKLES					= 12;				-- Number of art elements moving on a line
local g_colorLine 						= 0x7f74564a;
local g_colorAvailableLine				= 0xffb4366b; --0xffF05099; --0xff501040; --0xffb4366b;	 -- purple 	

local g_colorNotResearched 				= 0x50ffffff; --0xbb7d7570;	 -- gray 		125, 117, 	112
local g_colorAvailable					= 0xaaffffff;
local g_colorCurrent 					= 0xfff09020;	 -- blue 		251, 187, 	74
local g_colorAlreadyResearched			= 0xffd6b8a3;	 -- 
local g_colorWhiteAlmost			 	= 0xfffafafa;	 -- white		250, 250, 	250
local g_colorNodeSelectedCursor			= 0xffe09050;
local g_colorNotResearchedSmallIcons	= 0xfff0e0d0;

-- TechWebAtlas:
local g_textureTearFullNotResearched	= { u=1,	v=1 };		-- 68x68
local g_textureTearFullResearched		= { u=69,	v=1 };
local g_textureTearFullSelected			= { u=137,	v=1 };
local g_textureTearFullAvailable		= { u=205,	v=1 };
local g_textureTearLeafNotResearched	= { u=1,	v=70 };
local g_textureTearLeafResearched		= { u=54,	v=70 };
local g_textureTearLeafSelected			= { u=107,	v=70 };
local g_textureTearLeafAvailable		= { u=160,	v=70 };


local m_textColors = {};
m_textColors["AlreadyResearched"]		= g_colorWhiteAlmost;
m_textColors["Free"]					= g_colorNotResearched;
m_textColors["CurrentlyResearching"]	= g_colorCurrent;
m_textColors["Available"]				= g_colorNotResearched;
m_textColors["Locked"]					= g_colorNotResearched;
m_textColors["Unavailable"]				= g_colorNotResearched;

local m_iconColors = {};
m_iconColors["AlreadyResearched"]		= g_colorWhiteAlmost;
m_iconColors["Free"]					= g_colorAvailable;
m_iconColors["CurrentlyResearching"]	= g_colorWhiteAlmost;
m_iconColors["Available"]				= g_colorAvailable;
m_iconColors["Locked"]					= g_colorNotResearched;
m_iconColors["Unavailable"]				= g_colorNotResearched;

local m_smallIconColors = {};
m_smallIconColors["AlreadyResearched"]		= g_colorWhiteAlmost;
m_smallIconColors["Free"]					= g_colorNotResearchedSmallIcons;
m_smallIconColors["CurrentlyResearching"]	= g_colorWhiteAlmost;
m_smallIconColors["Available"]				= g_colorNotResearchedSmallIcons;
m_smallIconColors["Locked"]					= g_colorNotResearchedSmallIcons;
m_smallIconColors["Unavailable"]			= g_colorNotResearchedSmallIcons;

local m_textureBgFull = {};
m_textureBgFull["AlreadyResearched"]		= g_textureTearFullResearched;
m_textureBgFull["Free"]						= g_textureTearFullAvailable;
m_textureBgFull["CurrentlyResearching"]		= g_textureTearFullSelected;
m_textureBgFull["Available"]				= g_textureTearFullAvailable;
m_textureBgFull["Locked"]					= g_textureTearFullNotResearched;
m_textureBgFull["Unavailable"]				= g_textureTearFullNotResearched;

local m_textureBgLeaf = {};
m_textureBgLeaf["AlreadyResearched"]		= g_textureTearLeafResearched;
m_textureBgLeaf["Free"]						= g_textureTearLeafAvailable;
m_textureBgLeaf["CurrentlyResearching"]		= g_textureTearLeafSelected;
m_textureBgLeaf["Available"]				= g_textureTearLeafAvailable;
m_textureBgLeaf["Locked"]					= g_textureTearLeafNotResearched;
m_textureBgLeaf["Unavailable"]				= g_textureTearLeafNotResearched;

local m_colorAffinity:table	= {};
m_colorAffinity["AFFINITY_TYPE_HARMONY"] 	= 0xffa7d74a;
m_colorAffinity["AFFINITY_TYPE_PURITY"] 	= 0xff1d1ad8;
m_colorAffinity["AFFINITY_TYPE_SUPREMACY"] 	= 0xff2fbcff;

local AFFINITY_RING_SIZE	:number				= 46;		-- 46x46
local m_affinityRingUVIndex	:table				= {};			
m_affinityRingUVIndex[AFFINITY.harmony]			= {u=0,v=0};
m_affinityRingUVIndex[AFFINITY.purity]			= {u=1,v=0};
m_affinityRingUVIndex[AFFINITY.supremacy]		= {u=2,v=0};
m_affinityRingUVIndex[AFFINITY.purityharmony]	= {u=0,v=1};
m_affinityRingUVIndex[AFFINITY.supremacypurity]	= {u=1,v=1};
m_affinityRingUVIndex[AFFINITY.harmonysupremacy]= {u=2,v=1};
m_affinityRingUVIndex[AFFINITY.harmonypuritysupremacy]= {u=0,v=2};	-- Yes there is one that has all three.




-- ===== Static Constants ===================================================

local NUM_SEARCH_CONTROLS		:number = 5;		-- Number of search result fields.
local SIZE_SMALL_BUTTON_TEXTURE :number = 45;
local MAX_SMALL_BUTTONS 		:number = 6;		-- Maximum number of small buttons per tech
local MAX_TECH_NAME_LENGTH 		:number = 32; 		-- Locale.Length(Locale.Lookup("TXT_KEY_TURNS"));
local SEARCH_TYPE_MAIN_TECH		:number = 1;
local SEARCH_TYPE_UNLOCKABLE	:number = 2;
local SEARCH_TYPE_MISC_TEXT		:number = 3;
local SEARCH_SCORE_HIGH			:number = 5;		-- Be favored in search results
local SEARCH_SCORE_MEDIUM		:number = 3;		-- Less favored in search results
local SEARCH_SCORE_LOW			:number = 1;		-- Less favored in search results
local REFRESH_ALL_IDS			:table	= { 51 };	-- Memetwork (in Orbital Networks); Techs, that if completed, affect TT or other values on all nodes


-- ===== Members ===================================================

local g_loadedTechButtonNum :number	= 1;	-- number of tech buttons created
local g_maxTechs			:number	= 0;

local m_PopupInfo			:table = nil;
local g_isOpen				:boolean = false;

local g_TechLineManager 	:table = InstanceManager:new( "TechLineInstance", 	 	"TechLine", 		Controls.TechTreeDragPanel );
local g_BGLineManager 		:table = InstanceManager:new( "BackgroundLineInstance",	"Line", 			Controls.TechTreeDragPanel );
local g_SparkleManager 		:table = InstanceManager:new( "SparkleInstance",		"Sparkle", 			Controls.TechTreeDragPanel );
local g_SelectedTechManager :table = InstanceManager:new( "SelectedWebInstance", 	"Accoutrements",	Controls.TechTreeDragPanel );
local g_FilteredTechManager :table = InstanceManager:new( "SelectedWebInstance", 	"Accoutrements",	Controls.FilteredDragPanel );
local g_TechInstanceManager :table = InstanceManager:new( "TechWebNodeInstance", 	"TechButton", 		Controls.TechTreeDragPanel );
local g_LeafInstanceManager :table = InstanceManager:new( "TechWebLeafInstance", 	"TechButton", 		Controls.TechTreeDragPanel );
local m_HighlightNodeIM		:table = InstanceManager:new( "HighlightNodeInstance", 	"Content", 			Controls.TechTreeDragPanel );



local g_NeedsFullRefreshOnOpen 	:boolean= false;
local g_NeedsFullRefresh 		:boolean= false;
local g_NeedsNodeArtRefresh		:boolean= true;
local m_numQueuedItems			:number	= 0;

-- Game information
local m_playerID 			= Game.GetActivePlayer();	
local g_player 				= Players[m_playerID];
local civType 				= GameInfo.Civilizations[g_player:GetCivilizationType()].Type;
local activeTeamID 			= Game.GetActiveTeam();
local activeTeam 			= Teams[activeTeamID];

local g_radiusScalar		:number = 400;		-- applied to the GridRadius value set on a tech entry to produce the true screen-unit value
local g_gridRatio			:number = 0.6;		-- default ratio of y-axis to x-axis. Anything other than 1 will produce an elliptical look to the web
local g_lineInstances 		:table = {};		-- offsets are synced with table above for corresponding, actual line coordinates to draw

local g_screenWidth			:number = -1;					-- screen resolution width
local g_screenHeight		:number = -1;					-- screen resolution height
local g_screenCenterH		:number = -1;					-- half screen width
local g_screenCenterV		:number = -1;					-- half screen height
local g_webExtents			:table = { xmin=0, ymin= 0, xmax= 0, ymax= 0 };	-- how far does diagram


local g_currentTechButton	:table;					-- Button of the tech currently being researched
local g_selectedArt			:table;					-- Art for the selected node.
local g_selectedFilteredArt	:table;					-- Art for the selected node if it's filtered out.
local m_highlightedArt		:table;					-- Art to callout a node.

local g_techButtons 		:table = {};			-- Collection of all the buttons
local m_allTechs			:table;					-- cache of techs for across-frame (stream) loading

local g_techLeafToParent	:table = {};			-- Temporary, for storing leaf techs
local g_techParentToLeafs	:table = {};

local m_isEnterPressedInSearch		:boolean = false;	-- Was enter pressed while doing a search (instead of using mouse to click).
local m_isClickBlockedByRecentDrag	:boolean = false;	-- Used to help prevent accidently selection after a drag operation

local g_filterTable			= {};					-- Contains table of filters
local g_currentFilter		= nil;					-- Filter currently being used in displaying techs.
local g_currentFilterLabel	= nil;					-- Filter text for the current filter.



-- ===========================================================================
--	Create collection of coordiantes that map lines between techs
-- ===========================================================================
function BuildTechConnections()	

	print("BuildTechConnection");

	local connectionsSeen = {};
	g_lineInstances = {};

	for row in GameInfo.Technology_Connections() do
		local firstTech = GameInfo.Technologies[row.FirstTech];
		local secondTech = GameInfo.Technologies[row.SecondTech];

		-- Techs must be valid and both cannot be leafs
		if ( firstTech ~= nil and secondTech ~= nil ) then

			-- Swap based on ID or if a child tech
			if (firstTech.ID > secondTech.ID) or (firstTech.LeafTech and not secondTech.LeafTech) then
				local temp = firstTech;
				firstTech = secondTech;
				secondTech = temp;
			end

			-- Now smaller ids are first in the list with the accept of children techs.

			-- One parent may have many leaves
			if ( g_techParentToLeafs[firstTech.ID] == nil) then
				g_techParentToLeafs[firstTech.ID] = {};
			end

			if (firstTech.LeafTech and secondTech.LeafTech) then
			
				-- If there is a chain of children, more likely they will need to be sorted out
				-- by traversing from parent to most leaf child.  This will have to be done later.
				print("(Maybe) TODO: Implement chained leafs; if we use them");

			elseif ( secondTech.LeafTech ) then
				
				local leafs = g_techParentToLeafs[firstTech.ID];
				table.insert( leafs, secondTech );

				-- One leaf can only have one parent
				g_techLeafToParent[secondTech.ID] = firstTech;
			
			else
			
				local hash = firstTech.ID .. '_' .. secondTech.ID;

				-- Draw a line for unseen connections
				if not connectionsSeen[hash] then
					connectionsSeen[hash] = true;
				
					-- Protect the flock (even in script... make sure DB entry has proper values!)
					if firstTech.GridRadius ~= nil and secondTech.GridRadius ~= nil then

						local startX, startY= GetTechXY( firstTech );
						local endX, endY 	= GetTechXY( secondTech );
						local lineInstance 	= g_TechLineManager:GetInstance();

						lineInstance["firstTechId"]	= firstTech.ID;
						lineInstance["secondTechId"]= secondTech.ID;
						lineInstance["sX"]			= startX;
						lineInstance["sY"]			= startY;
						lineInstance["eX"]			= endX;
						lineInstance["eY"]			= endY;
						if ( isHasLineSparkles ) then
							lineInstance["sparkle1"]	= g_SparkleManager:GetInstance();
							lineInstance["sparkle2"]	= g_SparkleManager:GetInstance();
							lineInstance["sparkle3"]	= g_SparkleManager:GetInstance();
						end
						if ( isHasLineSparklesAvailable ) then
							--print("Sparkles for: ", startX .. ", ".. startY .." to ".. endX ..", ".. endY );
							for availSparkleIdx=1,MAX_LINE_SPARKLES,1 do
								lineInstance["extra"..tostring(availSparkleIdx)]	= g_SparkleManager:GetInstance();
							end
						end

						table.insert( g_lineInstances,	lineInstance );
					else
						print("Tech "..tech.Description.." misisng <GridRadius>.");
					end
				end
			end
		end -- if nil
	end
end

-- ===========================================================================
--	Read in line values 
-- ===========================================================================
function DrawLines()

	local i				:number;
	local lineInstance	:table;
	local startX		:number;
	local startY		:number;
	local endX			:number;
	local endY			:number;
	local color			:number;
	local firstTechId	:number;
	local secondTechId	:number;
	local lineWidth		:number = 5;
	local currentResearchID :number = g_player:GetCurrentResearch();

	for i,lineInstance in ipairs(g_lineInstances) do

		startX	= lineInstance["sX"];
		startY	= lineInstance["sY"];
		endX	= lineInstance["eX"];
		endY	= lineInstance["eY"];

		firstTechId 	= lineInstance["firstTechId"];
		secondTechId 	= lineInstance["secondTechId"];

		local hasFirst		= activeTeam:GetTeamTechs():HasTech( firstTechId );
		local hasSecond		= activeTeam:GetTeamTechs():HasTech( secondTechId );


		if 	(firstTechId == currentResearchID and hasSecond) or 
			(secondTechId == currentResearchID and hasFirst) then
			color = g_colorCurrent;					
		elseif hasFirst or hasSecond then
			if hasFirst and hasSecond then
				color = g_colorAlreadyResearched;
			else
				--print("Available tech: ",firstTechId.." to "..secondTechId);
				color = g_colorAvailableLine;
			end
		else
			color = g_colorNotResearched;
		end
		
		lineInstance.TechLine:SetWidth( lineWidth );		
		lineInstance.TechLine:SetColor( color );
		lineInstance.TechLine:SetStartVal(startX, startY);
		lineInstance.TechLine:SetEndVal(endX, endY);
		lineInstance.TechLine:SetHide(false);

		-- Animation on *ALL* lines
		if isHasLineSparkles then
			local speed :number = 0.2;
			for i=1,MAX_LINE_SPARKLES,1 do				
				local sparkleInstance = lineInstance["extraAll" .. tostring(i) ];
				sparkleInstance.Sparkle:SetBeginVal(startX, startY);
				sparkleInstance.Sparkle:SetEndVal(endX, endY);
				sparkleInstance.Sparkle:SetProgress( math.random() );
				sparkleInstance.Sparkle:SetSpeed( speed + (math.random() *0.2) );
				sparkleInstance.Sparkle:Play();
				sparkleInstance.Sparkle:SetHide(false);					
			end

		elseif isHasLineSparklesAvailable then					
			
			-- Animation only on the available tech lines

			local speed :number = 0.2;
			for i=1,MAX_LINE_SPARKLES,1 do
				local sparkleInstance	= lineInstance["extra" .. tostring(i) ];
				if ( color == g_colorAvailableLine ) then
					sparkleInstance.Sparkle:SetBeginVal(startX, startY);
					sparkleInstance.Sparkle:SetEndVal(endX, endY);
					sparkleInstance.Sparkle:SetProgress( math.random() );
					sparkleInstance.Sparkle:SetSpeed( speed + (math.random() *0.1) );
					sparkleInstance.Sparkle:Play();
					sparkleInstance.Sparkle:SetHide(false);					
				else
					sparkleInstance.Sparkle:SetHide(true);
				end
			end			
		end
		
	end

end

-- ===========================================================================
function OnDragCompleteAllowClicks()
	m_isClickBlockedByRecentDrag = false;
end



-- ===========================================================================
--
--	eventRaiser,	Control hosting the tech web
--	x,				horizontal offset amount
--	y,				vertical offset amount
-- ===========================================================================
function OnDragChange( eventRaiser, x, y )

	m_isClickBlockedByRecentDrag = true;
	Controls.ClickAfterDragBlocker:SetToBeginning();
	Controls.ClickAfterDragBlocker:Play();

	-- Clamp to tree's dimensions (clamp half to max as we shift the screen over to center)

	-- Get center
	x = x - g_screenCenterH;
	y = y - g_screenCenterV;

	-- Clamp
	local EXTRA_SPACE = 150;
	local clampx = math.clamp(x, g_webExtents.xmin - EXTRA_SPACE, g_webExtents.xmax );
	local clampy = math.clamp(y, g_webExtents.ymin, g_webExtents.ymax );

	-- Put back the offset
	x = clampx + g_screenCenterH;
	y = clampy + g_screenCenterV;

	Controls.TechTreeDragPanel:SetDragOffset( x, y );
	Controls.FilteredDragPanel:SetDragOffset( x, y );

	--print( "extens: ", g_webExtents.xmin..","..g_webExtents.xmax, g_webExtents.ymin..","..g_webExtents.ymax, "   clamp: ",clampx..","..clampy,"   xy: ",x..","..y );	
end


-- ===========================================================================
--	Tech tree node was clicked
--	eTech	the tech to select
-- ===========================================================================
function OnClickTech( eTech, iDiscover)

	-- Prevents accidental clicks
	-- If a drag operation just finished, this will continue to block until
	-- the (very short) timer completes and sets this to be permissive.	
	if m_isClickBlockedByRecentDrag then
		return;
	end


	--print("eTech:"..tostring(eTech));
	if eTech > -1 then		
		g_NeedsNodeArtRefresh = true;
		local isShiftHeld = UIManager:GetShift();

		if ( isShiftHeld ) then
			
			-- Shift select, only allow on the last node if already in queue.
			local queuePosition = g_player:GetQueuePosition( eTech );			
			local isLastItem	= (queuePosition == m_numQueuedItems );
			local isNotInQueue	= (queuePosition < 1);

			if  (isNotInQueue or isLastItem ) then
				-- It is either not in the current queue, or in the queue by the last item, 

				-- Normal select
				Network.SendResearch(eTech, g_player:GetNumFreeTechs(), -1, true);
				Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WEB_CONFIRM");
			else
				-- Ignore
			end
		else
			-- Normal select
			Network.SendResearch(eTech, g_player:GetNumFreeTechs(), -1, false);
			Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WEB_CONFIRM");
		end 		
		
		-- Do not call RefreshDisplay() here as it is expensive with the art refresh yet
		-- the engine will have not selected the new tech yet to be considered research.
		-- Wait for the callback from the dirty event being triggered.
   	end

end


-- ===========================================================================
--	Create a new node in the web based on a tech
--		tech, The technology the node should be representing.
-- ===========================================================================
function AddTechNode( tech )

	-- Build node type based on if this is a "full" node or a leaf node.
	local thisTechButtonInstance;
	if (tech.LeafTech) then
		thisTechButtonInstance = g_LeafInstanceManager:GetInstance();
	else
		thisTechButtonInstance = g_TechInstanceManager:GetInstance();
	end

	if thisTechButtonInstance then
		
		thisTechButtonInstance.tech = tech;						-- point back to tech (easy access)		
		g_techButtons[tech.ID] = thisTechButtonInstance;		-- store this instance off for later		
		
		-- add the input handler to this button
		thisTechButtonInstance.TechButton:SetVoid1( tech.ID ); 	-- indicates tech to add to queue
		thisTechButtonInstance.TechButton:SetVoid2( 0 ); 		-- how many free techs		
		thisTechButtonInstance.NodeName:SetVoid1( tech.ID );	-- ditto to label
		thisTechButtonInstance.NodeName:SetVoid2( 0 );

		thisTechButtonInstance.TechButton:RegisterCallback( Mouse.eRClick, GetTechPedia );

		techPediaSearchStrings[tostring(thisTechButtonInstance.TechButton)] = tech.Description;

		local scienceDisabled = Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE);
 		if (not scienceDisabled) then
			thisTechButtonInstance.TechButton	:RegisterCallback( Mouse.eLClick, OnClickTech );
			thisTechButtonInstance.NodeName		:RegisterCallback( Mouse.eLClick, OnClickTech );

			-- Double click closes.
			thisTechButtonInstance.TechButton	:RegisterCallback( Mouse.eLDblClick, OnClose );
			thisTechButtonInstance.NodeName		:RegisterCallback( Mouse.eLDblClick, OnClose );
		end

		thisTechButtonInstance.TechButton:SetToolTipString( GetHelpTextForTech(tech.ID) );

		if ( tech.LeafTech ) then
			thisTechButtonInstance.parent 	= g_techLeafToParent[tech.ID];
			thisTechButtonInstance.isLeaf	= true;
		else
			thisTechButtonInstance.children = g_techParentToLeafs[tech.ID];
			thisTechButtonInstance.isLeaf	= false;
		end
		
		-- Update the picture
		if IconHookup( tech.PortraitIndex, 64, tech.IconAtlas, thisTechButtonInstance.TechPortrait ) then
--			thisTechButtonInstance.TechPortrait:SetHide( false  );
		else
			thisTechButtonInstance.TechPortrait:SetHide( true );
		end

		-- Affinity ring
		local affinities:table = {};
		local hasPurity		:boolean= false;
		local hasSupremacy	:boolean= false;
		local hasHarmony	:boolean= false;
		local affinity		:number;
		for techAffinityPair in GameInfo.Technology_Affinities()  do
			if techAffinityPair.TechType == tech.Type then
				if		techAffinityPair.AffinityType == "AFFINITY_TYPE_SUPREMACY"	then hasSupremacy=true; 
				elseif	techAffinityPair.AffinityType == "AFFINITY_TYPE_PURITY"		then hasPurity	=true; 
				elseif	techAffinityPair.AffinityType == "AFFINITY_TYPE_HARMONY"	then hasHarmony	=true; 
				end
			end
		end

		if hasPurity and hasSupremacy and hasHarmony then	
			affinity = AFFINITY.harmonypuritysupremacy;
		elseif hasPurity and hasSupremacy then				affinity = AFFINITY.supremacypurity;
		elseif hasHarmony and hasPurity then				affinity = AFFINITY.purityharmony;
		elseif hasSupremacy and hasHarmony then				affinity = AFFINITY.harmonysupremacy;
		elseif hasPurity				then				affinity = AFFINITY.purity;
		elseif hasSupremacy				then				affinity = AFFINITY.supremacy;
		elseif hasHarmony				then				affinity = AFFINITY.harmony;
		end
		thisTechButtonInstance.AffinityRing:SetHide( affinity==nil );
		if affinity ~= nil then
			thisTechButtonInstance.AffinityRing:SetTextureOffsetVal( 
				m_affinityRingUVIndex[affinity].u * AFFINITY_RING_SIZE, 
				m_affinityRingUVIndex[affinity].v * AFFINITY_RING_SIZE 
			);
		end
		
	
		-- Unlocks
		AddSmallButtons( thisTechButtonInstance );

		-- Add the tech's name and contents from "small buttons" (buildings, etc...) for search system
		
		local techName = Locale.ConvertTextKey( tech.Description );
		table.insert( g_searchTable, { word=techName, tech=tech, type=SEARCH_TYPE_MAIN_TECH } );
		
		for _,smallButtonText in pairs(g_recentlyAddedUnlocks) do
			--print("text: ", smallButtonText);
			smallButtonText = Locale.ConvertTextKey(smallButtonText);
			table.insert( g_searchTable, { word=smallButtonText, tech=tech, type=SEARCH_TYPE_UNLOCKABLE } );
		end

		--[[ Too fine detail
		for _,smallButtonText in pairs(g_recentlyAddedUnlocks) do
			smallButtonText = Locale.ConvertTextKey(smallButtonText);

			-- For each word in the tooltip text
			for word in string.gmatch(smallButtonText, "%S+") do
				table.insert( g_searchTable, { word=word, tech=tech, type=SEARCH_TYPE_MISC_TEXT } );
			end
		end
		]]

		--[[ ??TRON - Darken, issue is that alphaed elements see through each other (overlap)
		-- Darken / alpha nodes farther away (in response to play tests where full tree felt busy.)		
		local amount		= 1;
		local pathLength	= g_player:FindPathLength( tech.ID );
		if ( pathLength > 0 ) then
			amount = math.clamp( 1 / (pathLength*0.02), 0.2, 1);			-- values: 0 to xxxxx map to 0.2 to 1
		end
		thisTechButtonInstance["visibleIndex"] = amount;

		local argb = RGBAValuesToABGRHex( amount, amount, amount, amount );
		thisTechButtonInstance.bg:SetColor( argb );
		thisTechButtonInstance.Tear:SetColor( argb );
		thisTechButtonInstance.NodeName:SetColor( argb );		
		thisTechButtonInstance.NodeName:SetAlpha( amount );
		thisTechButtonInstance.TechPortrait:SetAlpha( amount );
		for i=1,MAX_SMALL_BUTTONS,1 do
			thisTechButtonInstance["B"..tostring(i)]:SetAlpha( amount );
		end
		if ( thisTechButtonInstance.isLeaf) then
			thisTechButtonInstance.spacer:SetColor( argb );
		end
		]]
	else
		print("ERROR: Unable to create a new tech button instance for ", tech.Description);
	end
end


-- ===========================================================================
-- On Display
-- ===========================================================================
function OnDisplay( popupInfo )
	
	if popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TECH_TREE then
		-- Stop pop-ups from fighting for you eyes; if a new one is requested and this is up, shutdown this screen.
		if not ContextPtr:IsHidden() and popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TUTORIAL then
			OnClose();
		end
		return;
	end

	m_highlightedArt.Content:SetHide( true );

	m_PopupInfo 			= popupInfo;
	g_NeedsNodeArtRefresh 	= true;
    g_isOpen 				= true;

	Events.SerialEventToggleTechWeb(true);

    if not g_NeedsFullRefresh then
		g_NeedsFullRefresh = g_NeedsFullRefreshOnOpen;
	end
	g_NeedsFullRefreshOnOpen = false;

	if( m_PopupInfo.Data1 == 1 ) then
    	if( ContextPtr:IsHidden() == false ) then
    	    OnClose();
    	    return;
    	else
        	UIManager:QueuePopup( ContextPtr, PopupPriority.InGameUtmost );
    	end
	else
        UIManager:QueuePopup( ContextPtr, PopupPriority.TechTree );
    end
    
	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
	Game.SetAdvisorRecommenderTech( m_playerID );

  	RefreshDisplay();  	

	-- Focus on a tech value passed in
	if m_PopupInfo.Data2 ~= nil then
		for _,tech in ipairs(m_allTechs) do
			if tech.ID == m_PopupInfo.Data2 then
				PanToTech( tech );
				break;
			end
		end
	end

end


-- ===========================================================================
-- ===========================================================================
function RefreshDisplay()
	
	g_currentTechButton = nil;

	DrawLines();

	-- Hide selected art for cases of "free" tech being granted or just completed
	-- researching tech.  If it needs to be turned on, the node that is selected
	-- will turn it on.
	g_selectedArt.Accoutrements:SetHide( true );
	g_selectedFilteredArt.Accoutrements:SetHide( true );

	m_numQueuedItems			= 0;
	local queuePosition :number = 0;
	for tech in GameInfo.Technologies() do
		queuePosition = g_player:GetQueuePosition( tech.ID );		
		if ( queuePosition > 0 ) then
			m_numQueuedItems = m_numQueuedItems + 1;
		end
	end


	-- Draw only the techs that have finished loading.
	local iTech :number = 0;
	for tech in GameInfo.Technologies() do
		iTech = iTech + 1;
		if iTech <= g_loadedTechButtonNum then
			RefreshDisplayOfSpecificTech( tech );
		end
	end	

	-- Is a filter active? If so raise the art wall for those that don't pass the filter.
	Controls.FilteredTechWall:SetHide( g_currentFilter == nil );
	
	g_NeedsFullRefresh = false;	
	g_NeedsNodeArtRefresh = false;
end


-- ===========================================================================
--	Returns width and height from a set of extents.
-- ===========================================================================
function GetExtentDimensions( extent )
	-- protect the flock, return 0 if not an initialized (or proper) object
	if extent.xmax == nil then
		return 0,0;
	end
	local width 	= extent.xmax - extent.xmin;
	local height	= extent.ymax - extent.ymin;
	return width, height;
end



-- ===========================================================================
-- ===========================================================================
function GetTurnText( turnNumber )
	local turnText = "";
	if 	g_player:GetScience() > 0 then
		local turns = tonumber( turnNumber );
		turnText = "("..turns..")";
	end
	return turnText;
end


-- ===========================================================================
-- 	Update queue number if needed, place in proper position.
-- ===========================================================================
function RealizeTechQueue( thisTechButton, techID )
	
	local queuePosition = g_player:GetQueuePosition( techID );
	
	if queuePosition == -1 then
		thisTechButton.TechQueueLabel:SetHide( true );
	else
		thisTechButton.TechQueueLabel:SetHide( false );					
		thisTechButton.TechQueueLabel:SetText( tostring( queuePosition-1 ) );

		if ( queuePosition == m_numQueuedItems ) then
			thisTechButton.TechQueueLabel:SetColor( 0xeeffffff, 2 );	-- glow on (last item)
		else
			thisTechButton.TechQueueLabel:SetColor( 0x00000000, 2 );	-- glow off
		end


	end

	-- Reposition if a leaf
	if ( thisTechButton.isLeaf ) then
		thisTechButton.TechQueueLabel:SetOffsetVal( 52, 0 );
	else
		thisTechButton.TechQueueLabel:SetOffsetVal( 70, 0 );
	end

end

-- ===========================================================================
--	
-- ===========================================================================
function AddSmallButtons( techButtonInstance )
	AddSmallButtonsToTechButton( techButtonInstance, techButtonInstance.tech, MAX_SMALL_BUTTONS, SIZE_SMALL_BUTTON_TEXTURE, 1);
end


-- ===========================================================================
--	Given a tech, update it's corresponding button
-- ===========================================================================
function RefreshDisplayOfSpecificTech( tech )

	local techID 			= tech.ID;
	local thisTechButton 	= g_techButtons[techID];
  	local numFreeTechs 		= g_player:GetNumFreeTechs();
 	local researchTurnsLeft = g_player:GetResearchTurnsLeft( techID, true ); 	
 	local turnText 			= GetTurnText( researchTurnsLeft );
 	local isTechOwner 		= activeTeam:GetTeamTechs():HasTech(techID);
 	local isNowResearching	= (g_player:GetCurrentResearch() == techID);


	-- Advisor recommendations...

	-- Setup the stack to hold (any) advisor recommendations.
	-- Do this first as it may effect the amount of space for the node's name.
	thisTechButton.AdvisorStack:DestroyAllChildren();
	thisTechButton.advisorsNum = 0;
	local advisorInstance  = {};
	ContextPtr:BuildInstanceForControl( "AdvisorRecommendInstance", advisorInstance, thisTechButton.AdvisorStack );
	
	-- Create instance(s) per advisors for this tech.
	for iAdvisorLoop = 0, AdvisorTypes.NUM_ADVISOR_TYPES - 1, 1 do
		if Game.IsTechRecommended(tech.ID, iAdvisorLoop) then

			local advisorX			= -2;
			local advisorY			= -6;
			local advisorTooltip	= "";
			if ( thisTechButton.isLeaf ) then
				advisorX = 11;
			end			

			advisorInstance.EconomicRecommendation:SetHide( true );
			advisorInstance.MilitaryRecommendation:SetHide( true );
			advisorInstance.ScienceRecommendation:SetHide( true );
			advisorInstance.CultureRecommendation:SetHide( true );
			advisorInstance.GrowthRecommendation:SetHide( true );

			local pControl = nil;
			if (iAdvisorLoop	== AdvisorTypes.ADVISOR_ECONOMIC) then			
				advisorToolTip	= Locale.ConvertTextKey( "TXT_KEY_TECH_CHOOSER_ADVISOR_RECOMMENDATION_ECONOMIC");
				pControl		= advisorInstance.EconomicRecommendation;
			elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_MILITARY) then
				advisorToolTip	= Locale.ConvertTextKey( "TXT_KEY_TECH_CHOOSER_ADVISOR_RECOMMENDATION_MILITARY");
				pControl		= advisorInstance.MilitaryRecommendation;
			elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_SCIENCE) then
				advisorToolTip	= Locale.ConvertTextKey( "TXT_KEY_TECH_CHOOSER_ADVISOR_RECOMMENDATION_SCIENCE");
				pControl		= advisorInstance.ScienceRecommendation;
			elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_FOREIGN) then	-- ADVISOR_CULTURE?
				advisorToolTip	= Locale.ConvertTextKey( "TXT_KEY_TECH_CHOOSER_ADVISOR_RECOMMENDATION_FOREIGN");
				pControl		= advisorInstance.CultureRecommendation;
			elseif (iAdvisorLoop == AdvisorTypes.ADVISOR_GROWTH) then	-- Does not exist?
				advisorToolTip	= Locale.ConvertTextKey( "TXT_KEY_TECH_CHOOSER_ADVISOR_RECOMMENDATION_GROWTH");
				pControl		= advisorInstance.GrowthRecommendation;
			end

			if (pControl) then
				pControl:SetHide( false );
				thisTechButton.advisorsNum  = thisTechButton.advisorsNum + 1;	-- track amt for other code
			end
		
			--advisorInstance.AdvisorMarking:ChangeParent( thisTechButton.bg );
			advisorInstance.AdvisorMarking:SetOffsetVal( 0, -2 );
			--advisorInstance.AdvisorBackground:SetOffsetVal( advisorX, advisorY );
			advisorInstance.AdvisorMarking:SetToolTipString( advisorTooltip );
			
		end
	end


	-- Update the name of this node's instance
	local techName = Locale.ConvertTextKey( tech.Description );
	techName = Locale.TruncateString(techName, MAX_TECH_NAME_LENGTH, true);
	if ( m_showTechIDsDebug ) then
		techName = tostring(techID) .. " " .. techName;
	end
	if ( not isTechOwner ) then
		techName = Locale.ToUpper(techName) .. " ".. turnText;
	else
		techName = Locale.ToUpper(techName);
	end
	--TruncateStringWithTooltip( thisTechButton.NodeName, 
	thisTechButton.NodeName	:SetText( techName );


	-- Update queue & tooltip regions.	
	if ( m_numQueuedItems > 0 ) then
		
		local progressAmount	= nil;
		local queuePosition		= g_player:GetQueuePosition( tech.ID );
		if queuePosition ~= 1 then 
			-- If queue is active, then only show spill-over tech for that one.
			-- But still show progress we have past that (ex. from Expeditions)
			local overflowResearch = g_player:GetOverflowResearch();
			local researchTowardsThis = g_player:GetResearchProgress(tech.ID);
			progressAmount = researchTowardsThis - overflowResearch;
			if (progressAmount < 0) then
				progressAmount = 0;
			end
		end

		thisTechButton.TechButton:SetToolTipString( GetHelpTextForTech(techID, progressAmount) );
		thisTechButton.NodeName:SetToolTipString( GetHelpTextForTech(techID, progressAmount) );
		
	else
		thisTechButton.TechButton:SetToolTipString( GetHelpTextForTech(techID), nil );
		thisTechButton.NodeName:SetToolTipString( GetHelpTextForTech(techID), nil );
	end


 	-- Rebuild the small buttons if needed
 	if (g_NeedsFullRefresh) then
		AddSmallButtons( thisTechButton )
 	end
 	
 	local scienceDisabled = Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE);
 	
	if(not scienceDisabled) then
		thisTechButton.TechButton:SetVoid1( techID ); -- indicates tech to add to queue
		thisTechButton.TechButton:SetVoid2( numFreeTechs ); -- how many free techs
		AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, techID, numFreeTechs, Mouse.eLClick, OnClickTech );
		AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, techID, numFreeTechs, Mouse.eLDblClick, OnClose );
	end

 	if isTechOwner then -- the player (or more accurately his team) has already researched this one
		ShowTechState( thisTechButton, "AlreadyResearched");
		if(not scienceDisabled) then
			thisTechButton.TechQueueLabel:SetHide( true );
			thisTechButton.TechButton:SetVoid2( 0 ); -- num free techs
			thisTechButton.TechButton:SetVoid1( -1 ); -- indicates tech is invalid
			AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, -1, 0, Mouse.eLClick, OnClickTech );
			AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, -1, 0, Mouse.eLDblClick, OnClose );
 		end
 		
 	elseif isNowResearching then -- the player is currently researching this one
				
		RealizeTechQueue( thisTechButton, techID );
		if g_player:GetNumFreeTechs() > 0 then
			
			ShowTechState( thisTechButton, "Free");		-- over-write tech queue #
			thisTechButton.TechQueueLabel:SetText( freeString );
			thisTechButton.TechQueueLabel:SetHide( false );

			-- Keep selected node's art hidden while choosing a free tech.

		else
			g_currentTechButton = thisTechButton;
 			ShowTechState( thisTechButton, "CurrentlyResearching");
			thisTechButton.TechQueueLabel:SetHide( true );

	 		-- Determine values for the memeter
			local researchProgressPercent 		= 0;
			local researchProgressPlusThisTurnPercent = 0;
			local researchTurnsLeft 			= g_player:GetResearchTurnsLeft(techID, true);
			local currentResearchProgress 		= g_player:GetResearchProgress(techID);
			local researchNeeded 				= g_player:GetResearchCost(techID);
			local researchPerTurn 				= g_player:GetScience();
			local currentResearchPlusThisTurn 	= currentResearchProgress + researchPerTurn;		
			researchProgressPercent 			= currentResearchProgress / researchNeeded;
			researchProgressPlusThisTurnPercent = currentResearchPlusThisTurn / researchNeeded;		
			if (researchProgressPlusThisTurnPercent > 1) then
				researchProgressPlusThisTurnPercent = 1
			end

			currentResearchPlusThisTurn = currentResearchPlusThisTurn * 0.1;

			-- Set art, etc... based on if it's a leaf or not.

			local x,y 		= GetTechXY( tech );
			local width 	= thisTechButton.TechButton:GetSizeX();
			local height 	= thisTechButton.TechButton:GetSizeY();
			local accoutrementx;
			local accoutrementy;
			local meterx;
			local metery;
			local meterHeight;

			-- Set the selected art based on if a filter is active for this.
			local selectedArt = g_selectedArt;
			if ( g_currentFilter ~= nil ) then
				-- In filter mode, is this tech in the filter?
				if not g_currentFilter( tech ) then
					-- Current tech isn't in the filter, use the filtered version of the art.
					selectedArt = g_selectedFilteredArt;					
				end
			end
			selectedArt.Accoutrements:SetHide( false );


			if ( thisTechButton.isLeaf ) then
				
				-- Show selecetd leaf art				
				selectedArt.FullPieces:SetHide( true );
				selectedArt.LeafPieces:SetHide( false );

				accoutrementx 	= x - 34;
				accoutrementy 	= y - 30;
				meterx 			= width + thisTechButton.bg:GetSizeX() - 11;
				metery  		= 1;
				meterHeight 	= selectedArt.AmountLeaf:GetSizeY();

				-- Since art is interlaced, ensure offsets are even
				local nextHeight= math.floor(-meterHeight + (meterHeight * researchProgressPlusThisTurnPercent));
				local thisHeight= math.floor(-meterHeight + (meterHeight * researchProgressPercent));
				if ( (nextHeight) % 2 == 0) then nextHeight = nextHeight - 1; end
				if ( (thisHeight) % 2 == 1) then thisHeight = thisHeight - 1; end

				selectedArt.Accoutrements	:SetOffsetVal( accoutrementx, accoutrementy );
				selectedArt.BorderLeaf		:SetHide( false );
				selectedArt.MeterLeaf		:SetOffsetVal( meterx, metery );
				selectedArt.NewAmountLeaf	:SetTextureOffsetVal( 0, nextHeight);
				selectedArt.AmountLeaf 		:SetTextureOffsetVal( 0, thisHeight);
	
			else

				-- Show non-leaf stuff for a selected piece.
				selectedArt.FullPieces:SetHide( false );
				selectedArt.LeafPieces:SetHide( true );
					
				accoutrementx 	= x - 46;
				accoutrementy 	= y - 36;
				meterx 			= width + thisTechButton.bg:GetSizeX() - 10;
				metery  		= 0;
				meterHeight 	= selectedArt.AmountFull:GetSizeY();

				-- Since art is interlaced, ensure offsets are even
				local nextHeight= math.floor(-meterHeight + (meterHeight * researchProgressPlusThisTurnPercent));
				local thisHeight= math.floor(-meterHeight + (meterHeight * researchProgressPercent));
				if ( (nextHeight) % 2 == 0) then nextHeight = nextHeight - 1; end
				if ( (thisHeight) % 2 == 1) then thisHeight = thisHeight - 1; end

				selectedArt.Accoutrements	:SetOffsetVal( accoutrementx, accoutrementy );
				selectedArt.BorderFull		:SetHide( false );
				selectedArt.MeterFull		:SetOffsetVal( meterx, metery );
				selectedArt.NewAmountFull	:SetTextureOffsetVal( 0, nextHeight);
				selectedArt.AmountFull 		:SetTextureOffsetVal( 0, thisHeight);
			end
		end

 	elseif (g_player:CanResearch( techID ) and not scienceDisabled) then -- the player research this one right now if he wants
 		-- deal with free 		
		RealizeTechQueue( thisTechButton, techID );
		if g_player:GetNumFreeTechs() > 0 then
 			ShowTechState( thisTechButton, "Free");		-- over-write tech queue #
			-- update queue number to say "FREE"
			thisTechButton.TechQueueLabel:SetText( freeString );
			thisTechButton.TechQueueLabel:SetHide( false );
		else
			ShowTechState( thisTechButton, "Available");			
		end

 	elseif (not g_player:CanEverResearch( techID ) or g_player:GetNumFreeTechs() > 0) then
  		ShowTechState( thisTechButton, "Locked");
		-- have queue number say "LOCKED"
		thisTechButton.TechQueueLabel:SetText( "" );
		thisTechButton.TechQueueLabel:SetHide( false );
		if(not scienceDisabled) then
			thisTechButton.TechButton:SetVoid1( -1 ); 
			thisTechButton.TechButton:SetVoid2( 0 ); -- num free techs
			AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, -1, 0, Mouse.eLClick, OnClickTech );
			AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, -1, 0, Mouse.eLDblClick, OnClose );
 		end
 	else -- currently unavailable
 		ShowTechState( thisTechButton, "Unavailable");		
		RealizeTechQueue( thisTechButton, techID );
		if g_player:GetNumFreeTechs() > 0 then
			thisTechButton.TechButton:SetVoid1( -1 ); 
			AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, -1, 0, Mouse.eLClick, function() end );
		else
			if(not scienceDisabled) then
				thisTechButton.TechButton:SetVoid1( tech.ID );
				AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, techID, numFreeTechs, Mouse.eLClick, OnClickTech );
				AddCallbackToSmallButtons( thisTechButton, MAX_SMALL_BUTTONS, techID, numFreeTechs, Mouse.eLDblClick, OnClose );
			end
		end
	end

	-- Place the node in the web.
	local x,y = GetTechXY( tech );
	x = x - (thisTechButton.TechButton:GetSizeX() / 2);
	y = y - (thisTechButton.TechButton:GetSizeY() / 2);
	thisTechButton.TechButton:SetOffsetVal( x, y );
	

	-- Update extends of web if this node pushes it out some.
	local TECH_NODE_WIDTH = 250;
	if (x - TECH_NODE_WIDTH) < g_webExtents.xmin then
		g_webExtents.xmin = (x - TECH_NODE_WIDTH);
	elseif x > g_webExtents.xmax then
		g_webExtents.xmax = x;
	end

	if y < g_webExtents.ymin then
		g_webExtents.ymin = y;
	elseif y > g_webExtents.ymax then
		g_webExtents.ymax = y;
	end


	-- Filter, if one is set.
	if g_currentFilter ~= nil then
		if g_currentFilter( tech ) then
			thisTechButton.TechButton:ChangeParent( Controls.TechTreeDragPanel );
		else
			thisTechButton.TechButton:ChangeParent( Controls.FilteredDragPanel );
		end
	else
		thisTechButton.TechButton:ChangeParent( Controls.TechTreeDragPanel );
	end
end


-- ===========================================================================
--	Obtain the screen space X and Y coordiantes for a tech
--	ARGS:	tech object
--	RETURNS: x,y
-- ===========================================================================
function GetTechXY( tech )
	--print("GetTechXY ", tech.Description );

	if tech.LeafTech then

		local button:table = g_techButtons[ tech.ID ];

		-- Only dynamically place children if guaranteed all are loaded.
		if ( g_loadedTechButtonNum >= g_maxTechs ) then
			
			button.TechButton:SetHide( false );			

			-- Obtain the parent to this leaf
			local parentTech 	= button.parent;
			local parentButton 	= g_techButtons[ parentTech.ID ];

			-- Loop through the children of the parent, when it eventually finds
			-- this child... do all the maths and return.
			for i,child in ipairs(parentButton.children) do
				if (child.ID == tech.ID) then
					local parentx:number ,parenty :number = parentButton.TechButton:GetOffsetVal();
					return parentx + 38, parenty + (36 + (i*69));
				end
			end
			print("WARNING: A leaf tech couldn't be dynamically positioned against it's parent.", tech.Type, parentTech.Type );
		else
			button.TechButton:SetHide( true );
		end
	end


	if tech.GridRadius == 0 then
		return 0,0;
	end

	local x,y = PolarToRatioCartesian( tech.GridRadius * g_radiusScalar, tech.GridDegrees, g_gridRatio );
	return x, y;
end


-- ===========================================================================
--	ARGS:	Tech button to show
--			Name of the state of the button
-- ===========================================================================
function ShowTechState( thisTechButton, techStateString )

	-- Store last tech state for minimap to read.
	thisTechButton["techStateString"] = techStateString;

	if ( not g_NeedsNodeArtRefresh ) then
		return;
	end
	
	thisTechButton.TechPortrait	:SetColor( m_iconColors[techStateString] );
	thisTechButton.NodeName		:SetColor( m_textColors[techStateString] );

	-- Increase background size to match text width
	local spaceUsedByAdvisors = (32 * thisTechButton.advisorsNum);
	local extraSpaceNeeded	  = 40;
	if ( thisTechButton.NodeName:GetSizeX() > (thisTechButton.bg:GetSizeX() - (extraSpaceNeeded + spaceUsedByAdvisors)) ) then
		thisTechButton.bg:SetSizeVal( thisTechButton.NodeName:GetSizeX() + (extraSpaceNeeded + spaceUsedByAdvisors), thisTechButton.bg:GetSizeY() );
	end

	-- Is it a full node or leaf node?
	if thisTechButton.tech.LeafTech then

		-- Leaf
		for i=1,MAX_SMALL_BUTTONS do
			if ( thisTechButton["B"..i] == nil ) then
				break;
			end
			thisTechButton["B"..i]:SetColor( m_smallIconColors[techStateString] );
		end	

		thisTechButton.Tear 			:SetTextureOffsetVal ( m_textureBgLeaf[techStateString].u, m_textureBgLeaf[techStateString].v );		
		thisTechButton.TechButton		:SetSizeVal(50, 50);
		--thisTechButton.spacer			:SetHide(false);
		thisTechButton.bg 				:SetHide(false);
		thisTechButton.Tear 			:SetHide(false);
		thisTechButton.NodeName 		:SetHide(false);

	else			

		for i=1,MAX_SMALL_BUTTONS do
			if ( thisTechButton["B"..i] == nil ) then
				break;
			end
		end	

		thisTechButton.Tear				:SetTextureOffsetVal ( m_textureBgFull[techStateString].u, m_textureBgFull[techStateString].v );
		thisTechButton.bg 				:SetHide(false);
		thisTechButton.NodeName 		:SetHide(false);
		thisTechButton.NodeHolder		:SetHide(true);
	end
end



-- ===========================================================================
-- ===========================================================================
function OnClose ()
	UIManager:DequeuePopup( ContextPtr );
    Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, 0);
	Events.SerialEventToggleTechWeb(false);
    g_isOpen = false;	
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnClose );


-- ===========================================================================
--	Input Processing
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if g_isOpen and uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose();
            return true;
		end
		if m_profiling then
			if wParam == Keys.C then ProfileClear(); end
			if wParam == Keys.D then ProfileDump(); end
		end
    elseif g_isOpen and uiMsg == 2 and Keys.VK_RETURN then	-- 2 = CHAR message
		if Controls.SearchEditBox:HasFocus() then
			-- HACK: Since the general input cascade happens after the editbox
			--		 fires back, call for the search to occur again, but mark
			--		 a global so it will pull from the first item.
			m_isEnterPressedInSearch = true;
			OnKeywordSearchHandler( "" );
		end
		return true;
	elseif g_isOpen and uiMsg == MouseEvents.MButtonUp then
		OnClose();
	end

    return false;    
end
ContextPtr:SetInputHandler( InputHandler );


function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsInit ) then		
        if( not bIsHide ) then
			-- show
        	UI.incTurnTimerSemaphore();

			-- Clears out any in-progress UI state (like range attack/bombard)
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
			UI.ClearSelectedCities();
        else
			-- hide
        	UI.decTurnTimerSemaphore();
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

local g_PerPlayerTechFilterSettings = {}

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnTechTreeActivePlayerChanged( iActivePlayer, iPrevActivePlayer )

	-- print("OnTechTreeActivePlayerChanged", iActivePlayer, iPrevActivePlayer );

	-- Save/Restore the tech web filters.
	if (iPrevActivePlayer ~= -1) then
		if (g_PerPlayerTechFilterSettings[ iPrevActivePlayer + 1 ] == nil) then
			g_PerPlayerTechFilterSettings[ iPrevActivePlayer + 1 ] = {};
		end

		g_PerPlayerTechFilterSettings[ iPrevActivePlayer + 1 ].filterFunc = g_currentFilter;
		g_PerPlayerTechFilterSettings[ iPrevActivePlayer + 1 ].filterLabel = g_currentFilterLabel;
	end

	if (iActivePlayer ~= -1 ) then
		if (g_PerPlayerTechFilterSettings[ iActivePlayer + 1] ~= nil) then
			g_currentFilter = g_PerPlayerTechFilterSettings[ iActivePlayer + 1].filterFunc;
			g_currentFilterLabel = g_PerPlayerTechFilterSettings[ iActivePlayer + 1].filterLabel;
		else
			g_currentFilter = nil;
			g_currentFilterLabel = nil;
		end

		RefreshFilterDisplay();
	end

	m_playerID 	= Game.GetActivePlayer();	
	g_player 	= Players[m_playerID];
	civType 	= GameInfo.Civilizations[g_player:GetCivilizationType()].Type;
	activeTeamID= Game.GetActiveTeam();
	activeTeam 	= Teams[activeTeamID];	
	
	-- Rebuild some tables	
	GatherInfoAboutUniqueStuff( civType );	
	
	-- So some extra stuff gets re-built on the refresh call
	if not g_isOpen then
		g_NeedsFullRefreshOnOpen = true;	
	else
		g_NeedsFullRefresh = true;
	end
	
	-- Close it, so the next player does not have to.
	OnClose();
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnEventResearchDirty()
	if (g_isOpen) then
		g_NeedsNodeArtRefresh = true;
		RefreshDisplay();
	end
end

-- ===========================================================================	
--	GAME EVENT
-- ===========================================================================	
function OnTechAcquired( eTeam:number, techID:number )

	if activeTeam:GetTeamTechs():HasTech(techID) then
		-- Look through to see if the tech obtained updates all information for the player.
		for _,v in ipairs(REFRESH_ALL_IDS) do
			if v == id then
				g_NeedsFullRefresh = true;
				break;
			end
		end
	end	
end


-------------------------------------------------------------------------------
--	Needed for tooltip updates after Memetwork discount is applied but seems
--	overkill for simple node selection (slows it down).
-------------------------------------------------------------------------------
function OnEventGameDataDirty()
	return;
	--[[
	if not g_isOpen then
		g_NeedsFullRefreshOnOpen = true;	
	else
		g_NeedsFullRefresh = true;
		RefreshDisplay();
	end
	]]
end

-- ===========================================================================
--	Adds a few techs at a time; essentially streaming them into existance
--	as a single allocation in LUA for the whole web takes quite a while.
--	fDTime, delta time frame previous frame.
-- ===========================================================================
function OnUpdateAddTechs( fDTime )

	g_loadedTechButtonNum = g_loadedTechButtonNum + 1;

	local tech = m_allTechs[g_loadedTechButtonNum];
	
	AddTechNode( tech );
	RefreshDisplayOfSpecificTech( tech );

	Controls.LoadingBarBacking:SetHide( false );
	Controls.LoadingBar:SetSizeX( g_screenWidth * (g_loadedTechButtonNum / g_maxTechs) );

	if g_loadedTechButtonNum >= g_maxTechs then
		ContextPtr:SetUpdate( OnUpdateAnimateAfterLoad );  	-- animate in
		g_NeedsNodeArtRefresh = true;						-- initialize art in leaf node.
		g_selectedArt.Accoutrements:SetHide( false );	   	-- show current selection
	end
	
end

-- ===========================================================================
-- ===========================================================================
function OnGivenTimeSliceRemotely()

	g_loadedTechButtonNum = g_loadedTechButtonNum + 1;

	local tech = m_allTechs[g_loadedTechButtonNum];
	
	AddTechNode( tech );
	RefreshDisplayOfSpecificTech( tech );

	Controls.LoadingBarBacking:SetHide( false );
	Controls.LoadingBar:SetSizeX( g_screenWidth * (g_loadedTechButtonNum / g_maxTechs) );

	if g_loadedTechButtonNum >= g_maxTechs then
		Controls.LoadingBarBacking:SetHide( true );
		g_NeedsNodeArtRefresh = true;						-- initialize art in leaf node.
		g_selectedArt.Accoutrements:SetHide( false );	   	-- show current selection
		ContextPtr:ClearUpdate();  -- Turn off callback.
		LuaEvents.TechTree_OnDoneLoading();

		RefreshDisplay();
	end
end


-- ===========================================================================
-- ===========================================================================
function OnUpdateAnimateAfterLoad( fDTime )

	Controls.LoadingBarBacking:SetHide( true );
	g_animValueAfterLoad = 1;
	ContextPtr:ClearUpdate();  -- Turn off callback.

	RefreshDisplay();
end


-- ===========================================================================
--	Take a search string and based on the entry, determine a match score
--	RETURNS: A score for the match, higher score the closer to front.
-- ===========================================================================
function GetPotentialSearchMatch( searchString, searchEntry )
	local word = searchEntry["word"];

	if string.len(searchString) > string.len( word ) then
		return -1;
	end

	-- Escape out minus sign before doing a match call.
	searchString = string.gsub( searchString, "[%-%*%.%~%$%^%?]", " " );		-- Looks ineffective but it's doing work: param 2 is using % as an escape character, param 3 is a literal!
	local status, match = pcall( string.match, Locale.ToLower(word), Locale.ToLower(searchString) );

	if status then
		if match == nil then
			return -1;
		else				
			local score = string.len( match );		
		
			-- adjust score with importance
			if ( searchEntry["type"] == SEARCH_TYPE_MAIN_TECH ) then
				score = score + SEARCH_SCORE_HIGH;
			elseif ( searchEntry["type"] == SEARCH_TYPE_UNLOCKABLE ) then
				score = score + SEARCH_SCORE_MEDIUM;
			elseif ( searchEntry["type"] == SEARCH_TYPE_MISC_TEXT ) then
				score = score + SEARCH_SCORE_LOW;
			end

			-- adjust score to be higher if pattern is found closer to front
			local num = string.find( Locale.ToLower(word), match );
			if ( num ~= nil and (10-num) > 0) then
				num = (10-num) * 4;
			else
				num = 0;
			end
		
			score = score + num;
			return score;
		end
	end

	return -1;
end


-- ===========================================================================
-- ===========================================================================
function ClearSearchResults()
	Controls.SearchResult1:SetText( "" );
	Controls.SearchResult2:SetText( "" );
	Controls.SearchResult3:SetText( "" );
	Controls.SearchResult4:SetText( "" );
	Controls.SearchResult5:SetText( "" );

	Controls.SearchResult1["tech"] = nil;
	Controls.SearchResult2["tech"] = nil;
	Controls.SearchResult3["tech"] = nil;
	Controls.SearchResult4["tech"] = nil;
	Controls.SearchResult5["tech"] = nil;
end


-- ===========================================================================
--	Pan the web to the specified tech.
--	tech,		The tech to go to.
-- ===========================================================================
function PanToTech( tech )

	-- Clear out any searches (as they may have caused the pan)	
	ClearSearchResults();

	-- Fill search with where it's panning...
	Controls.SearchEditBox:SetText( Locale.ConvertTextKey( tech.Description) );
	Controls.SearchEditBox:SetColor( 0x80808080 );

	local sx:number, sy:number	= Controls.TechTreeDragPanel:GetDragOffsetVal();
	local x	:number, y:number	= GetTechXY( tech );

	Controls.PanControl:RegisterAnimCallback( OnPanTech );
	Controls.PanControl:SetBeginVal(sx, sy);
	Controls.PanControl:SetEndVal( -x + g_screenCenterH, -y + g_screenCenterV );
	Controls.PanControl:SetToBeginning();
	Controls.PanControl:Play();

	-- Highlight the selected node
	m_highlightedArt.Content:SetHide( false );
	m_highlightedArt.Content:ChangeParent( g_techButtons[tech.ID].TechButton );
	m_highlightedArt.Content:SetOffsetVal(0,0);
	m_highlightedArt.Content:ReprocessAnchoring();
	m_highlightedArt.Content:SetToBeginning();
	m_highlightedArt.Content:Play();

end


-- ===========================================================================
--	Callback per-frame for slide animation.
-- ===========================================================================
function OnPanTech()
	local x:number, y:number = Controls.PanControl:GetOffsetVal();
	Controls.TechTreeDragPanel:SetDragOffset( x,y );
	Controls.FilteredDragPanel:SetDragOffset( x,y );
end


-- ===========================================================================
--	px, % 0 to 1
--	py, % 0 to 1
-- ===========================================================================
function OnPanToPercent( px, py )

	local x:number = (-px * (g_webExtents.xmax - g_webExtents.xmin)) - g_webExtents.xmin;
	local y:number = (-py * (g_webExtents.ymax - g_webExtents.ymin)) - g_webExtents.ymin;

	x = x + g_screenCenterH;
	y = y + g_screenCenterV;

	Controls.TechTreeDragPanel:SetDragOffset( x,y );
	Controls.FilteredDragPanel:SetDragOffset( x,y );
end


-- ===========================================================================
-- ===========================================================================
function OnSearchResult1ButtonClicked() PanToTech( Controls.SearchResult1["tech"] ); end
function OnSearchResult2ButtonClicked() PanToTech( Controls.SearchResult2["tech"] ); end
function OnSearchResult3ButtonClicked() PanToTech( Controls.SearchResult3["tech"] ); end
function OnSearchResult4ButtonClicked() PanToTech( Controls.SearchResult4["tech"] ); end
function OnSearchResult5ButtonClicked() PanToTech( Controls.SearchResult5["tech"] ); end


-- ===========================================================================
-- 	Search Input processing
-- ===========================================================================
function OnSearchInputHandler( charJustPressed, searchString )	

	ClearSearchResults();	

	-- Nothing to search?  Then done...
	if string.len(searchString) < 1 then
		return;
	end
	

	-- Obtain words that have a match
	local results 	= {};
	local strength 	= 0;
	for i,searchEntry in ipairs(g_searchTable) do
		strength = GetPotentialSearchMatch( searchString, searchEntry );
		if strength > 0 then
			table.insert( results, { strength=strength, searchEntry=searchEntry } );
		end
	end

	-- Sort by strength
	local ResultsSort = function(a, b)
		return a.strength > b.strength;
	end
	table.sort( results, ResultsSort );

	local searchControl;
	local searchControlName;
	for i,resultEntry in ipairs(results) do

		if i > NUM_SEARCH_CONTROLS then	
			break;
		end	

		searchControlName = "SearchResult"..str(i);
		searchControl = Controls[searchControlName];

		local text = resultEntry["searchEntry"]["word"];
		if ( resultEntry["searchEntry"]["type"] == SEARCH_TYPE_UNLOCKABLE ) then
			local techDescription = Locale.ConvertTextKey( resultEntry["searchEntry"]["tech"].Description);
			text = text .." (" .. techDescription .. ")";
		end

		searchControl:SetText( text );
		searchControl["tech"] = resultEntry["searchEntry"]["tech"];

		--print("Sorted: ", i, resultEntry["searchEntry"]["word"] );
	end

end
Controls.SearchEditBox:RegisterCharCallback( OnSearchInputHandler );


-- ===========================================================================
--	Enter was pressed or editbox lost focus due to click outside it.
-- ===========================================================================
function OnKeywordSearchHandler( searchString )	
	-- BONUS: Common commands to effect the tech web other than searchincloseg
	--		  NOTE: English only... translations? localization look ups?
	if ( searchString == "close" or searchString == "exit") then
		local defaultSearchlabel = Locale.Lookup("TXT_KEY_TECHWEB_SEARCH");
		Controls.SearchEditBox:SetText(defaultSearchlabel);
		Controls.SearchEditBox:SetColor( 0x80808080 );
		OnClose();		-- Fake a close button clicked
		return;
	end
	
	-- BONUS: Common geek society search strings which translate to "home" node, the center of the techweb 
	if ( searchString == "~" or searchString == "localhost" or searchString == "127.0.0.1" ) then
		searchString = Locale.ConvertTextKey( m_allTechs[1].Description );
	end

	if searchString=="" then
		ClearSearchResults();
		local defaultSearchlabel = Locale.Lookup("TXT_KEY_TECHWEB_SEARCH");
		Controls.SearchEditBox:SetText(defaultSearchlabel);
		Controls.SearchEditBox:SetColor( 0x80808080 );
	else
		local mostLikelySearchText = Controls.SearchResult1:GetText();
		if ( m_isEnterPressedInSearch and Controls.SearchResult1["tech"] ~= nil and mostLikelySearchText ~= "" ) then
			PanToTech( Controls.SearchResult1["tech"] );
		end
	end

	m_isEnterPressedInSearch = false;
end
Controls.SearchEditBox:RegisterCommitCallback( OnKeywordSearchHandler );



-- ===========================================================================
function OnSearchHasFocus()
	Controls.SearchEditBox:SetText( "" );
	Controls.SearchEditBox:SetColor( 0xffffffff );
	Controls.SearchEditBox:ReprocessAnchoring();
end
Controls.SearchEditBox:RegisterHasFocusCallback( OnSearchHasFocus );


-- ===========================================================================
-- Debug helper
-- ===========================================================================
function str( val )
	return tostring( math.floor(val));
end


-- ===========================================================================
-- Update the Filter text with the current label.
-- ===========================================================================
function RefreshFilterDisplay()
	local pullDownButton = Controls.FilterPulldown:GetButton();	
	if ( g_currentFilter == nil ) then
		pullDownButton:SetText( "  "..Locale.ConvertTextKey("TXT_KEY_TECHWEB_FILTER"));
	else
		pullDownButton:SetText( "  "..Locale.ConvertTextKey(g_currentFilterLabel));
	end
end

-- ===========================================================================
--	filterLabel,	Readable lable of the current filter.
--	filterFunc,		The funciton filter to apply to each node as it's built,
--					nil will reset the filters to none.
-- ===========================================================================
function OnFilterClicked( filterLabel, filterFunc )		
	g_currentFilter=filterFunc;
	g_currentFilterLabel=filterLabel;

	RefreshFilterDisplay();
	RefreshDisplay();
end


-- ===========================================================================
--	Programmatically Draw an oval via line segments
-- ===========================================================================
function DrawBackgroundOval( distance, color )

	local start = 0;
	local step	= 360 / ( 50 + ((math.ceil(distance/100) * 4) ));

	local x,y;
	local ox,oy = PolarToRatioCartesian( distance, start, g_gridRatio );
	for degrees = start+step,361, step do
		x, y = PolarToRatioCartesian( distance, degrees, g_gridRatio );

		local lineInstance 	= g_BGLineManager:GetInstance();
		lineInstance.Line:SetWidth( 2 + ((distance/2500) * 16) );
		lineInstance.Line:SetColor( color );
		lineInstance.Line:SetStartVal( x, y);
		lineInstance.Line:SetEndVal( ox, oy );
		lineInstance.Line:SetHide(false);		
		
		-- Save old points for ending of line for next loop...
		ox = x;
		oy = y;
	end

end


-- ===========================================================================
--	Programmatically draw the background.
-- ===========================================================================
function DrawBackground()

	local MAX_BOUNDS	= 1900;
	local MAX_SPARKLES	= 200;

	g_BGLineManager:ResetInstances();

	-- Draw multiple rings pointing to center
	for distance=100,MAX_BOUNDS,370 do
		--DrawBackgroundOval( distance-5, 0x03f0c0b0 );	-- style it, slightly smaller ring with each ring
		DrawBackgroundOval( distance, 0x14f0c0b0 );
	end

	-- Experimental starfield, looks a little too cheesy right now; may repurpose for other background animation.
	-- ??TRON When on, many dots align despite progress being random.
	if ( isLookLikeWindows95 ) then
		g_SparkleManager:ResetInstances();
		for i=1,MAX_SPARKLES,1 do
			local instance	= g_SparkleManager:GetInstance();
			local degrees	= math.random(1,360);
			local endx,endy = PolarToRatioCartesian( MAX_BOUNDS, degrees, g_gridRatio );
			instance.Sparkle:SetBeginVal(0, 0);
			instance.Sparkle:SetEndVal(endx, endy);
			instance.Sparkle:SetSpeed( 0.1 );
			instance.Sparkle:SetProgress( math.random() );
			instance.Sparkle:Play();
		end
	end
end


-- ===========================================================================
--	PROFILE (DEBUG) functions
-- ===========================================================================

local m_profileTimes :table = {};
local m_profilesOpen :table = {};
hstructure ProfileTimeStruct
	start	: number
	finish	: number
	count	: number	-- which one this hit
	scope	: number	-- reserved
	id		: string	-- reserved 
end

function ProfileClear()
	m_profileTimes = {};
	m_profilesOpen = {};
end
function ProfileStart( id:string )
	if not m_profiling then return; end
	if m_profileTimes[id] == nil then 
		m_profileTimes[id] = {}; 
		m_profilesOpen[id] = 0; 
	end
	m_profilesOpen[id] = m_profilesOpen[id] + 1;
	table.insert( m_profileTimes[id], hmake ProfileTimeStruct {
		start = os.clock(),
		finish = 0,
		count = table.count(m_profileTimes[id]),
		scope = 1,
	});
end

function ProfileFinish( id:string )
	if not m_profiling then return; end
	local info:ProfileTimeStruct = m_profileTimes[id][table.count(m_profileTimes[id])];
	info.finish = os.clock();
	m_profileTimes[id][table.count(m_profileTimes[id])] = info;

	m_profilesOpen[id] = m_profilesOpen[id] - 1;
	if m_profilesOpen[id] < 0 then
		print("ERROR: Finished called more often than Start for profiling id '"..tostring(id).."'");
	end
end

function ProfileDumpRaw()
	for k,v in pairs(m_profileTimes) do
		print("PROFILE: ", k, " = time: ", tostring(v.finish-v.start), "  count: ", tostring(v.count) );
	end
end

function ProfileDump()
	local sum:table = {};
	for id,profile in pairs(m_profileTimes) do
		sum[id] = hmake ProfileTimeStruct{ start = 0, finish = 0, count =0, scope=0, id=id }; 
		for k,v in pairs(profile) do
			sum[id].start = sum[id].start + v.start;
			sum[id].finish = sum[id].finish + v.finish;
			if v.count > sum[id].count then
				sum[id].count = v.count;
			end
		end
	end

	for k,v in pairs(sum) do
		print("PROFILE: ", k, " = time: ", tostring(v.finish-v.start), "  count: ", tostring(v.count), "  avg: ", tostring((v.finish-v.start)/v.count) );
	end		
end


-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isHotload )
	if isHotload then
		ContextPtr:SetUpdate( OnUpdateAddTechs );
	end
end

-- ===========================================================================
--	UI Event
-- ===========================================================================

function ResetSelectedInstance(instance : table)
	instance.Accoutrements:ChangeParent( Controls.TechTreeDragPanel );
end
function ResetFilteredInstance(instance : table)
	instance.Accoutrements:ChangeParent( Controls.FilteredDragPanel );
end
function ResetTechButton(instance : table)
	instance.TechButton:ChangeParent( Controls.TechTreeDragPanel );
end

function OnShutdown()

	LuaEvents.TechTreePanToPercent.Remove( OnPanToPercent );
	LuaEvents.LoadScreen_TechTreeGivenTimeSliceRemotely.Remove( OnGivenTimeSliceRemotely );

	g_TechInstanceManager:RunProcess( ResetTechButton, true );	-- Allow allocated but unused instances to be called as well
	g_LeafInstanceManager:RunProcess( ResetTechButton, true );	-- Allow allocated but unused instances to be called as well
end

-- ===========================================================================
--	One-time startup / CTOR
-- ===========================================================================
function Initialize()

	-- Setup filter area
	local pullDownButton = Controls.FilterPulldown:GetButton();	
	pullDownButton:SetText( "   "..Locale.ConvertTextKey("TXT_KEY_TECHWEB_FILTER"));	
	local pullDownLabel = pullDownButton:GetTextControl();
	pullDownLabel:SetAnchor("L,C");
	pullDownLabel:ReprocessAnchoring();


	-- Hard coded/special filters:
	table.insert( g_filterTable, { "", "TXT_KEY_TECHWEB_FILTER_NONE", nil } );
	table.insert( g_filterTable, { "", "TXT_KEY_TECHWEB_FILTER_RECOMMENDED", g_TechFilters.TECHFILTER_RECOMMENDED } );

	-- Load entried into filter table from TechFilters XML data
	for row in GameInfo.TechFilters() do
		table.insert(g_filterTable, { row.IconString, row.Description, g_TechFilters[row.Type] });
	end

	for i,filterType in ipairs(g_filterTable) do

		local filterIconText = filterType[1];
		local filterLabel	 = Locale.ConvertTextKey( filterType[2] );
		local filterFunction = filterType[3];
        
		local controlTable	 = {};        
		Controls.FilterPulldown:BuildEntry( "FilterItemInstance", controlTable );

		controlTable.Button:SetText( filterLabel );
		local labelControl = controlTable.Button:GetTextControl();
		labelControl:SetAnchor("L,C");
		labelControl:ReprocessAnchoring();

		-- If a text icon exists, use it and bump the label in the button over.
		if filterIconText ~= nil and filterIconText ~= "" then
			controlTable.IconText:SetText( filterIconText );
			labelControl:SetOffsetVal(35, 0);
			filterLabel = filterIconText .." ".. filterLabel;
		else
			labelControl:SetOffsetVal(5, 0);	-- Move over ever so slightly anyway.
			filterLabel = filterLabel;
		end

		-- Use a lambda function to organize how paramters will be passed...
		controlTable.Button:RegisterCallback( Mouse.eLClick,  function() OnFilterClicked( filterLabel, filterFunction ); end );
	end
	Controls.FilterPulldown:CalculateInternals();


	DrawBackground();

	Controls.SearchResult1:RegisterCallback( Mouse.eLClick, OnSearchResult1ButtonClicked );
	Controls.SearchResult2:RegisterCallback( Mouse.eLClick, OnSearchResult2ButtonClicked );
	Controls.SearchResult3:RegisterCallback( Mouse.eLClick, OnSearchResult3ButtonClicked );
	Controls.SearchResult4:RegisterCallback( Mouse.eLClick, OnSearchResult4ButtonClicked );
	Controls.SearchResult5:RegisterCallback( Mouse.eLClick, OnSearchResult5ButtonClicked );

	-- gather info about this player's unique units and buldings
	GatherInfoAboutUniqueStuff( civType );

	g_screenWidth, g_screenHeight 	= UIManager:GetScreenSizeVal();
	g_screenCenterH = g_screenWidth / 2;
	g_screenCenterV = g_screenHeight / 2;

	-- Clear extends, rebuild when tech buttons are layed out.
	g_webExtents = { 
		xmin=-g_screenCenterH, 
		ymin=-g_screenCenterV, 
		xmax=g_screenCenterH, 
		ymax=g_screenCenterV 
	};

	BuildTechConnections();

	-- Create instance here that shows selected node.
	-- This is not in the XML but exactly here so it's created after the lines, but
	-- before the Nodes are created.  Otherwise, z-order will make the art look bad
	-- (lines going through nodes, etc.. )
	g_selectedArt = g_SelectedTechManager:GetInstance();
	g_selectedArt.LeafPieces:SetHide( true );
	g_selectedArt.FullPieces:SetHide( true );

	m_highlightedArt = m_HighlightNodeIM:GetInstance();
	m_highlightedArt.Content:SetHide( false );

	-- Now create one for the filtered layer, so if an item is filtered out but is selected this
	-- will be used instead of the one above.		
	g_selectedFilteredArt = g_FilteredTechManager:GetInstance();
	g_selectedFilteredArt.LeafPieces:SetHide( true );
	g_selectedFilteredArt.FullPieces:SetHide( true );
	g_selectedFilteredArt.Accoutrements:ChangeParent( Controls.FilteredDragPanel );
	
	techPediaSearchStrings = {};

	-- Load initial amount of techs displayed; stream the rest in across frames for a better user experience.
	local nodesToPreload = 8;
	if ( not (m_forceNodesNum == -1) ) then
		nodesToPreload = m_forceNodesNum;
	end
	local iTech = 0;
	m_allTechs = {};
	for tech in GameInfo.Technologies() do
		iTech = iTech + 1;		
		if iTech < nodesToPreload then
			AddTechNode( tech );			
			g_loadedTechButtonNum = iTech;
		end
		m_allTechs[iTech] = tech;
	end	
	g_maxTechs = table.count(m_allTechs);
	if (m_fastDebug) then					g_maxTechs = 40; end -- debug: - faster debugging by limiting techs
	if ( not (m_forceNodesNum == -1) ) then	g_maxTechs = m_forceNodesNum; end

	-- resize the panel to fit the contents
    Controls.TechTreeDragPanel:CalculateInternalSize();
	Controls.FilteredDragPanel:CalculateInternalSize();

    -- Set callbacks from drag control
    Controls.TechTreeDragPanel:SetDragCallback( OnDragChange );
    
    -- start centered
	Controls.TechTreeDragPanel:SetDragOffset( g_screenCenterH, g_screenCenterV );
	Controls.FilteredDragPanel:SetDragOffset( g_screenCenterH, g_screenCenterV );

	-- Initial setup takes a few seconds as pieces are built
	-- Do this when game is first loading to prevent hitch the first time techweb is brought up
	ClearSearchResults();
	RefreshDisplay();

	-- Debug: Needed for hotloading or certain things (keyboard input, won't work.)
	if ( not ContextPtr:IsHidden() ) then
		g_isOpen = true;
		Events.SerialEventToggleTechWeb(false);
	end

	Controls.ClickAfterDragBlocker:RegisterEndCallback( OnDragCompleteAllowClicks );	
	
	-- ..::;{ EVENTS };::..
	-- UI
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );

	-- LUA /UI
	LuaEvents.TechTreePanToPercent.Add( OnPanToPercent );
	LuaEvents.LoadScreen_TechTreeGivenTimeSliceRemotely.Add( OnGivenTimeSliceRemotely );

	-- Game
	Events.GameplaySetActivePlayer.Add(OnTechTreeActivePlayerChanged);
	Events.SerialEventResearchDirty.Add(OnEventResearchDirty);
	Events.SerialEventGameDataDirty.Add(OnEventGameDataDirty);
	Events.SerialEventGameMessagePopup.Add(OnDisplay);
	Events.TechAcquired.Add( OnTechAcquired );
end
Initialize();
