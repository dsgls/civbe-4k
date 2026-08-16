-- ===========================================================================
--	MiniMap o' Technologies
--	(for the CivBE Technology Web)
--
--	Uses a "real" area to compute how the rect moves around and contains a
--	"visible" area which may change when nearing an edge.  This is to work
--	around forge using a shader for clipping scroll regions; preventing nesting
--	two of them (one horizontal, one vertical) to auto-clip.
--
-- ===========================================================================
include( "InstanceManager" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local m_colorNotResearched 				= 0x70ffffff;
local m_colorAvailable					= 0x90b4366b;
local m_colorCurrent 					= 0x70f09020;
local m_colorAlreadyResearched			= 0x70a69873; -- not dark enough: 0x70d6b8a3

local m_nodeColors = {};
m_nodeColors["AlreadyResearched"]		= m_colorAlreadyResearched;
m_nodeColors["Free"]					= m_colorNotResearched;
m_nodeColors["CurrentlyResearching"]	= m_colorCurrent;
m_nodeColors["Available"]				= m_colorAvailable;
m_nodeColors["Locked"]					= m_colorNotResearched;
m_nodeColors["Unavailable"]				= m_colorNotResearched;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================

local m_displayRatio		= 1;
local m_screenWidth			= -1;					-- screen resolution
local m_screenHeight		= -1;					-- screen resolution
local m_miniWidth			= -1;					-- minimap size
local m_miniHeight			= -1;					-- minimap size
local m_visBoxWidth			= -1;					-- visible area box size
local m_visBoxHeight		= -1;					-- visible area box size
local m_webExtents			= { xmin=0, ymin= 0, xmax= 0, ymax= 0 };
local m_xmlCanvasOffsetX	= 0;

local m_NodeManager 		= InstanceManager:new( "NodeInstance", 	"Node", Controls.TechTreeMiniMapCanvas );


-- ===========================================================================
--	CTOR
-- ===========================================================================
function Initialize()	
	m_screenWidth,	m_screenHeight 	= UIManager:GetScreenSizeVal();	
	m_miniWidth,	m_miniHeight	= Controls.TechTreeMiniMap:GetSizeVal();
	m_xmlCanvasOffsetX				= Controls.TechTreeMiniMapCanvas:GetOffsetX();
end


-- ===========================================================================
function SetSize( x, y )

	local EXTRA_BACKGROUND_Y = 20;

	Controls.TechTreeMiniMap:SetSizeVal( x, y );
	Controls.Background:SetSizeVal( x, y + EXTRA_BACKGROUND_Y );	
	Controls.ClipRect:SetSizeVal( x, y + (EXTRA_BACKGROUND_Y-4) );
	Controls.TechTreeMiniMapCanvas:SetSizeVal( x, y );
	Controls.TechTreeMiniMapCanvas:SetOffsetVal( (x/2) + m_xmlCanvasOffsetX, y/2 );	

	Controls.ClipRect:CalculateInternalSize();
	Controls.ClipRect:ReprocessAnchoring();
end


-- ===========================================================================
--	Obtain (an updated) size of the tech web.
--	extents,	Objext with xmin,xmax and ymin,ymax of tech web bounds.
-- ===========================================================================
function OnSetExtents( extents )
	
	-- Copy and then add padding
	m_webExtents = extents;
	
	local treeWidth				= m_webExtents.xmax - m_webExtents.xmin;
	local treeHeight			= m_webExtents.ymax - m_webExtents.ymin;

	-- Adjust height to match ratio
	local ratio = treeHeight / treeWidth;
	m_miniHeight = ratio * m_miniWidth;

	SetSize( m_miniWidth, m_miniHeight );
		
	m_displayRatio = m_miniWidth / treeWidth;
	
	-- Visible area box is in proportion to minimap's area
	m_visBoxWidth	= m_screenWidth * m_displayRatio;
	m_visBoxHeight	= m_screenHeight * m_displayRatio;
	Controls.VisibleArea:SetSizeVal( m_visBoxWidth, m_visBoxHeight );
end
LuaEvents.TechWebMiniMapSetExtents.RemoveAll();
LuaEvents.TechWebMiniMapSetExtents.Add( OnSetExtents );


-- ===========================================================================
--	techNodes
-- ===========================================================================
function OnDrawNodes( techNodes )

	m_NodeManager:ResetInstances();

	if techNodes == nil then
		print("ERROR: no nodes, not drawing a thing!");
		return;
	end	

	for _,node in ipairs(techNodes) do
		local nodeInstance	= m_NodeManager:GetInstance();
		local nodeX			= m_displayRatio * node.TechButton:GetOffsetX();
		local nodeY			= m_displayRatio * node.TechButton:GetOffsetY();
		nodeInstance.Node:SetOffsetVal( nodeX, nodeY );
		nodeInstance.Node:SetColor( m_nodeColors[node.techStateString] );
		if node.techStateString=="CurrentlyResearching" then
			nodeInstance.NodeAnim:Play();
		else
			nodeInstance.NodeAnim:Stop();
		end

		if ( node.isLeaf) then
			nodeInstance.Node:SetSizeVal(11,3);
		end
	end
end
LuaEvents.TechWebMiniMapDrawNodes.RemoveAll();
LuaEvents.TechWebMiniMapDrawNodes.Add( OnDrawNodes );


-- ===========================================================================
--	New drag location
-- ===========================================================================
function OnTechWebMiniMapNewPosition( x, y )	
	if (not Controls ) then return; end
		
	local lx		= x * m_displayRatio;
	local ly		= y * m_displayRatio;
	local xOffset	= (-(lx - (m_miniWidth / 2))) + m_xmlCanvasOffsetX;
	local yOffset	= -(ly - (m_miniHeight / 2));

	Controls.VisibleArea:SetOffsetVal( xOffset, yOffset );
end	
LuaEvents.TechWebMiniMapNewPosition.RemoveAll();
LuaEvents.TechWebMiniMapNewPosition.Add( OnTechWebMiniMapNewPosition );


-- ===========================================================================
function OnFadeOut()
	Controls.FadeAnimation:SetToBeginning();	-- resets any reverse
	Controls.FadeAnimation:RegisterAnimCallback(
		function() 
			if ( Controls.FadeAnimation:IsStopped() ) then
				Controls.TechTreeMiniMap:SetHide( true );	-- no input
			end
		end
	);
	Controls.FadeAnimation:Play();

end
LuaEvents.TechWebMiniMapFadeOut.RemoveAll();
LuaEvents.TechWebMiniMapFadeOut.Add( OnFadeOut );


-- ===========================================================================
function OnFadeIn()
	Controls.TechTreeMiniMap:SetHide( false );
	Controls.FadeAnimation:SetToBeginning();
	Controls.FadeAnimation:Reverse();
	Controls.FadeAnimation:RegisterAnimCallback( function() end );
	Controls.FadeAnimation:Play();
end
LuaEvents.TechWebMiniMapFadeIn.RemoveAll();
LuaEvents.TechWebMiniMapFadeIn.Add( OnFadeIn );


-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )
	--print("ShowHide called!",bIsHide,bIsInit);
	
	if not bIsInit then
		if ( bIsHide ) then
		else
			--Initialize();	-- ??TRON debug: so it re-initializes whenever shown
		end
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
Initialize();


-- ===========================================================================
-- ===========================================================================
function OnClick()
	
	local mouseX, mouseY    = UIManager:GetMousePos();
	local mapX, mapY		= Controls.TechTreeMiniMap:GetOffsetVal();		-- assume offset is to screen!

	-- Anchoring UPPER-LEFT
	--local px = (mouseX - mapX) / (m_screenWidth - mapX);
	--local py = (mouseY - mapY) / (m_screenHeight - mapY);

	-- Get % anchoring UPPER-RIGHT
	local ADJUST_OFFSET_X = (m_visBoxWidth / 8 );
	local px = (((mouseX - (m_screenWidth-m_miniWidth)) - ADJUST_OFFSET_X) - m_xmlCanvasOffsetX) / m_miniWidth;	      
	local py = (mouseY - mapY) / m_miniHeight;
	
	px = math.clamp( px, 0, 1.0 );
	py = math.clamp( py, 0, 1.0 );

	LuaEvents.TechTreePanToPercent( px, py );
end
Controls.TechTreeMiniMap:RegisterCallback( Mouse.eLClick, OnClick );




-- ===========================================================================
--	??TRON debug - force reload
-- ===========================================================================
function OnForceReload()
	print("TechMiniMap.OnForceReload()");
	LuaEvents.TechWebResendMiniMapData();
end
Controls.TechTreeMiniMap:RegisterCallback( Mouse.eRClick, OnForceReload );