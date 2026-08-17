-- ===========================================================================
--	Diplomacy
--	Wheel... Of... Affinity!
--
--	Tabs set to 4 spaces.
-- ===========================================================================
include("InstanceManager");
include("MathHelpers");
include("InfoTooltipInclude");
include("DiplomacyUIUtilities");
include("AffinityInclude");


-- ===========================================================================
--	CONSTANTS	/ DEFINES
-- ===========================================================================
local	MAX_AFFINITY_LEVELS		:number		= 20;
local	RADIUS_START			:number		= 18;
local	RADIUS_MULT				:number		= 30;
local	DEBUG_CACHE_SCREEN_NAME	:string		= "DiplomacyState_Affinity";	--hotloading support
local	AFFINITY_UNLOCK_ENUM	:number		= 0x10c;						--'lock' enum for unlocked perks button
local	MODE					:table		= { wheel=1, affinityInfo=2, unlocks=3 };

local	DEGREES					:table		= {};
		DEGREES[AFFINITY.purity]			= 30;
		DEGREES[AFFINITY.supremacy]			= 150;
		DEGREES[AFFINITY.harmony]			= 270
		DEGREES[AFFINITY.supremacypurity]	= 90;
		DEGREES[AFFINITY.harmonysupremacy]	= 210;
		DEGREES[AFFINITY.purityharmony]		= 330;

-- Contains the suffix for corresponding textures, and the coordinates for each type of texture.
local	IMAGES			:table				= {};
		IMAGES[AFFINITY.purity]				= { suffix="P",  background={ x=614, y=550, w=484, h=480},	hover={ x=548,  y=544,  w=554, h=488} };
		IMAGES[AFFINITY.supremacy]			= { suffix="S",  background={ x=4,	 y=550, w=500, h=482},	hover={ x=0,	y=552,  w=560, h=486}  };
		IMAGES[AFFINITY.harmony]			= { suffix="H",  background={ x=272, y=6,	w=562, h=466},	hover={ x=274,  y=0,	w=560, h=562} };
		IMAGES[AFFINITY.supremacypurity]	= { suffix="SP", background={ x=276, y=654, w=556, h=448},	hover={ x=276,  y=552,	w=554, h=554} };
		IMAGES[AFFINITY.harmonysupremacy]	= { suffix="HS", background={ x=4,	 y=76,	w=504, h=488},	hover={ x=2,	y=76,	w=560, h=486}  };
		IMAGES[AFFINITY.purityharmony]		= { suffix="PH", background={ x=602, y=76,	w=498, h=486},	hover={ x=550,  y=74,	w=554, h=484} };

-- Maps affinity types to the victory quest that matches it
local m_affinityQuests : table = {};
m_affinityQuests[AFFINITY.purity]		= GameInfo.Quests["QUEST_VICTORY_PROMISED_LAND"];
m_affinityQuests[AFFINITY.supremacy]	= GameInfo.Quests["QUEST_VICTORY_EMANCIPATION"];
m_affinityQuests[AFFINITY.harmony]	= GameInfo.Quests["QUEST_VICTORY_TRANSCENDENCE"];

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_GlowLineIM		 	: table		= InstanceManager:new( "GlowLineInstance",	"Content",	Controls.LineCanvas);
local m_NodeIM				: table		= InstanceManager:new( "NodeInstance",		"Node",		Controls.NodeCanvas);
local m_NodeGlowIM			: table		= InstanceManager:new( "NodeGlowInstance",	"Glow",		Controls.GlowCanvas);
local m_AffinityIM			: table		= InstanceManager:new( "UnlockInstance",	"Content",	Controls.PerksStack);
local m_UnlockIM			: table		= InstanceManager:new( "UnlockInstance",	"Content",	Controls.UnlockStack);
local m_player				: object	= nil;
local m_selectedPlayer		: object	= nil;
local m_hiddenAtShutdown	: boolean	= true;	-- debug hotload
local m_purity				: number	= 0;
local m_supremacy			: number	= 0;
local m_harmony				: number	= 0;
local m_mode				: number	= MODE.wheel;
local m_selectedAffinity	: number	= AFFINITY.purity;
local m_affinityInfo		: table		= {};				-- perks list
		m_affinityInfo[AFFINITY.purity]				= {};
		m_affinityInfo[AFFINITY.harmony]			= {};
		m_affinityInfo[AFFINITY.supremacy]			= {};
		m_affinityInfo[AFFINITY.purityharmony]		= {};
		m_affinityInfo[AFFINITY.harmonysupremacy]	= {};
		m_affinityInfo[AFFINITY.supremacypurity]	= {};

m_affinityInfo[AFFINITY.purity].Title			= Locale.Lookup("TXT_KEY_AFFINITY_TYPE_PURITY");		
m_affinityInfo[AFFINITY.harmony].Title			= Locale.Lookup("TXT_KEY_AFFINITY_TYPE_HARMONY");
m_affinityInfo[AFFINITY.supremacy].Title		= Locale.Lookup("TXT_KEY_AFFINITY_TYPE_SUPREMACY");
m_affinityInfo[AFFINITY.harmonysupremacy].Title	= Locale.Lookup("TXT_KEY_AFFINITY_TYPE_HARMONY").." / "..Locale.Lookup("TXT_KEY_AFFINITY_TYPE_SUPREMACY");
m_affinityInfo[AFFINITY.purityharmony].Title	= Locale.Lookup("TXT_KEY_AFFINITY_TYPE_PURITY")	.." / "..Locale.Lookup("TXT_KEY_AFFINITY_TYPE_HARMONY");
m_affinityInfo[AFFINITY.supremacypurity].Title	= Locale.Lookup("TXT_KEY_AFFINITY_TYPE_SUPREMACY") .." / "..Locale.Lookup("TXT_KEY_AFFINITY_TYPE_PURITY");

m_affinityInfo[AFFINITY.purity].Quote			= Locale.Lookup("TXT_KEY_AFFINITY_QUOTE_PURITY");
m_affinityInfo[AFFINITY.harmony].Quote			= Locale.Lookup("TXT_KEY_AFFINITY_QUOTE_HARMONY");
m_affinityInfo[AFFINITY.supremacy].Quote		= Locale.Lookup("TXT_KEY_AFFINITY_QUOTE_SUPREMACY");
m_affinityInfo[AFFINITY.harmonysupremacy].Quote	= Locale.Lookup("TXT_KEY_AFFINITY_QUOTE_HARMONY_SUPREMACY");
m_affinityInfo[AFFINITY.purityharmony].Quote	= Locale.Lookup("TXT_KEY_AFFINITY_QUOTE_PURITY_HARMONY");
m_affinityInfo[AFFINITY.supremacypurity].Quote	= Locale.Lookup("TXT_KEY_AFFINITY_QUOTE_SUPREMACY_PURITY");

m_affinityInfo[AFFINITY.purity].Description				= Locale.Lookup("TXT_KEY_AFFINITY_DESCRIPTION_PURITY");
m_affinityInfo[AFFINITY.harmony].Description			= Locale.Lookup("TXT_KEY_AFFINITY_DESCRIPTION_HARMONY");
m_affinityInfo[AFFINITY.supremacy].Description			= Locale.Lookup("TXT_KEY_AFFINITY_DESCRIPTION_SUPREMACY");
m_affinityInfo[AFFINITY.harmonysupremacy].Description	= Locale.Lookup("TXT_KEY_AFFINITY_DESCRIPTION_HARMONY_SUPREMACY");
m_affinityInfo[AFFINITY.purityharmony].Description		= Locale.Lookup("TXT_KEY_AFFINITY_DESCRIPTION_PURITY_HARMONY");
m_affinityInfo[AFFINITY.supremacypurity].Description	= Locale.Lookup("TXT_KEY_AFFINITY_DESCRIPTION_SUPREMACY_PURITY");



-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function Close()
	ContextPtr:SetHide(true);
end

-- ===========================================================================
--	RETURNS texture name, x, y, width, height
-- ===========================================================================
function GetBackgroundTextureInfo( affinityEnum:number )
	return	"AffinityIndicator"..IMAGES[affinityEnum].suffix..".dds", 
			IMAGES[affinityEnum].background.x, 
			IMAGES[affinityEnum].background.y,
			IMAGES[affinityEnum].background.w,
			IMAGES[affinityEnum].background.h;
end

-- ===========================================================================
--	RETURNS texture name, x, y, width, height
-- ===========================================================================
function GetHoverTextureInfo( affinityEnum:number )
	return	"AffinityHover"..IMAGES[affinityEnum].suffix..".dds", 
			IMAGES[affinityEnum].hover.x, 
			IMAGES[affinityEnum].hover.y,
			IMAGES[affinityEnum].hover.w, 
			IMAGES[affinityEnum].hover.h;
end

-- ===========================================================================
function DrawGlowLine( sx, sy, ex, ey)
	local lineInstance = m_GlowLineIM:GetInstance();
	lineInstance.Line1:SetStartVal(sx,sy);
	lineInstance.Line1:SetEndVal(ex,ey);
	lineInstance.Line2:SetStartVal(sx,sy);
	lineInstance.Line2:SetEndVal(ex,ey);	
	lineInstance.Line3:SetStartVal(sx,sy);
	lineInstance.Line3:SetEndVal(ex,ey);
	lineInstance.Line4:SetStartVal(sx,sy);
	lineInstance.Line4:SetEndVal(ex,ey);
end

-- ===========================================================================
--	Returns true if past a specific affinity level
function IsPastAffinityLevel( affinityEnum:number, level:number )
	if affinityEnum == AFFINITY.purity				then return m_purity > level; end
	if affinityEnum == AFFINITY.supremacy			then return m_supremacy > level; end
	if affinityEnum == AFFINITY.harmony				then return m_harmony > level; end
	if affinityEnum == AFFINITY.supremacypurity		then return (m_supremacy > level and m_purity > level); end
	if affinityEnum == AFFINITY.harmonysupremacy	then return (m_harmony > level   and m_supremacy > level); end
	if affinityEnum == AFFINITY.purityharmony		then return (m_purity > level    and m_harmony > level); end
	return false;
end

-- ===========================================================================
function GetCurrentAffinityLevel( affinityEnum:number )
	if affinityEnum == AFFINITY.purity				then return m_purity; end
	if affinityEnum == AFFINITY.supremacy			then return m_supremacy; end
	if affinityEnum == AFFINITY.harmony				then return m_harmony; end 
	if affinityEnum == AFFINITY.supremacypurity		then return math.min(m_supremacy, m_purity); end
	if affinityEnum == AFFINITY.harmonysupremacy	then return math.min(m_harmony, m_supremacy); end
	if affinityEnum == AFFINITY.purityharmony		then return math.min(m_purity, m_harmony); end
	return -1;
end


-- ===========================================================================
function GetMaxAffinityLevel( affinityEnum:number )
	return m_affinityInfo[affinityEnum].HighestLevel;
end


-- ===========================================================================
--	Returns enum of which affinity is most followed
function GetAffinityMostFollowed()
	if m_purity > m_supremacy	and m_purity > m_harmony	then return AFFINITY.purity; end
	if m_supremacy > m_harmony	and m_supremacy > m_purity	then return AFFINITY.supremacy; end
	if m_harmony > m_purity		and m_harmony > m_supremacy	then return AFFINITY.harmony; end
	
	if m_purity == m_supremacy	and m_purity > m_harmony	then return AFFINITY.supremacypurity; end
	if m_supremacy == m_harmony	and m_supremacy > m_purity	then return AFFINITY.harmonysupremacy; end
	if m_harmony == m_purity	and m_harmony > m_supremacy	then return AFFINITY.purityharmony; end
	return -1;
end

-- ===========================================================================
function DrawNode( perkAtLevel:table, affinityEnum:number )
	local level	:number = perkAtLevel.level; 
	local degree:number = DEGREES[affinityEnum];
	local radius:number = RADIUS_START + (level * RADIUS_MULT);	
	local x:number,y:number = PolarToCartesian( radius, degree);
	local nodeInstance :table = m_NodeIM:GetInstance();
	nodeInstance.Node:SetOffsetVal(x,y);

	if perkAtLevel.highest then
		nodeInstance.Node:SetTextureOffsetVal(0,72);		
		local glowInstance :table = m_NodeGlowIM:GetInstance();
		glowInstance.Glow:SetOffsetVal(x,y);
		glowInstance.Glow:SetSpeed( 1 + (math.random() * 0.25) );	-- Make organic: slightly offset blinky glows!
	elseif IsPastAffinityLevel( affinityEnum, level ) then
		nodeInstance.Node:SetTextureOffsetVal(0,36);
	end

	local tt:string = Locale.Lookup("TXT_KEY_AFFINITY_LEVEL", level) .. "[NEWLINE]" .. Locale.Lookup(perkAtLevel.perk.Help);
	nodeInstance.Node:SetToolTipString( tt );
end

-- ===========================================================================
function DrawProjectNode( projectAtLevel:table, affinityEnum:number)
	local level	:number = projectAtLevel.level; 
	local degree:number = DEGREES[affinityEnum];
	local radius:number = RADIUS_START + (level * RADIUS_MULT);	
	local x:number,y:number = PolarToCartesian( radius, degree);
	local nodeInstance :table = m_NodeIM:GetInstance();
	local projectInfo	:table	= GameInfo.Projects[projectAtLevel.projectType];
	local questInfo		:table	= m_affinityQuests[affinityEnum];
	nodeInstance.Node:SetOffsetVal(x,y);

	if projectAtLevel.highest then
		nodeInstance.Node:SetTextureOffsetVal(0,72);		
		local glowInstance :table = m_NodeGlowIM:GetInstance();
		glowInstance.Glow:SetOffsetVal(x,y);
		glowInstance.Glow:SetSpeed( 1 + (math.random() * 0.25) );	-- Make organic: slightly offset blinky glows!
	elseif IsPastAffinityLevel( affinityEnum, level ) then
		nodeInstance.Node:SetTextureOffsetVal(0,36);
	end

	local tt:string = Locale.Lookup("TXT_KEY_AFFINITY_LEVEL", level) .. "[NEWLINE]" .. Locale.ConvertTextKey( "TXT_KEY_AFFINITY_UNLOCK_CAN_BUILD", projectInfo.Description, questInfo.Description );
	nodeInstance.Node:SetToolTipString( tt );
end

-- ===========================================================================
function AddAffinityUnlock( perkAtLevel:table, affinityEnum:number )
	
	local PADDING_Y		:number	= 50;
	local level			:number = perkAtLevel.level; 
	local degree		:number = DEGREES[affinityEnum];
	local unlockInstance:table	= m_AffinityIM:GetInstance();
	
	unlockInstance.TextIcon:SetText( GetAffinityTextIcon(affinityEnum) );
	unlockInstance.Amt:SetColorByName( GetAffinityColorSet( affinityEnum ) );
	unlockInstance.Amt:SetText( tostring(level) );
	unlockInstance.Info:SetText( Locale.Lookup(perkAtLevel.perk.Help) )
	unlockInstance.Content:SetSizeY( math.max(unlockInstance.Info:GetSizeY() + PADDING_Y, 110) );
end

-- ===========================================================================
function AddAffinityProjectUnlock( projectAtLevel:table, affinityEnum:number )
	
	local PADDING_Y		:number	= 50;
	local level			:number = projectAtLevel.level; 
	local degree		:number = DEGREES[affinityEnum];
	local unlockInstance:table	= m_AffinityIM:GetInstance();
	local projectInfo	:table	= GameInfo.Projects[projectAtLevel.projectType];
	local questInfo		:table = m_affinityQuests[affinityEnum];

	unlockInstance.TextIcon:SetText( GetAffinityTextIcon(affinityEnum) );
	unlockInstance.Amt:SetColorByName( GetAffinityColorSet( affinityEnum ) );
	unlockInstance.Amt:SetText( tostring(level) );
	unlockInstance.Info:SetText( Locale.ConvertTextKey( "TXT_KEY_AFFINITY_UNLOCK_CAN_BUILD", projectInfo.Description, questInfo.Description ) );
	unlockInstance.Content:SetSizeY( math.max(unlockInstance.Info:GetSizeY() + PADDING_Y, 110) );
end

-- ===========================================================================
--	Add ALL the unlocks the player currently has.
-- ===========================================================================
function AddUnlocksForAffinity( affinityEnum:number )
	local currentLevel:number = GetCurrentAffinityLevel(affinityEnum);
	for k,v in pairs(m_affinityInfo[affinityEnum].Perks) do
		if v.level <= currentLevel then
			AddCurrentPerkUnlock( v, affinityEnum );
		end
	end	

	for k,v in pairs(m_affinityInfo[affinityEnum].Projects) do
		if v.level < currentLevel then
			AddCurrentProjectUnlock( v, affinityEnum );
		end
	end
end

-- ===========================================================================
function AddCurrentPerkUnlock( perkAtLevel:table, affinityEnum:number )
	
	local PADDING_Y		:number	= 50;
	local level			:number = perkAtLevel.level; 
	local degree		:number = DEGREES[affinityEnum];
	local unlockInstance:table	= m_UnlockIM:GetInstance();
	
	unlockInstance.TextIcon:SetText( GetAffinityTextIcon(affinityEnum) );
	unlockInstance.Amt:SetColorByName( GetAffinityColorSet( affinityEnum ) );
	unlockInstance.Amt:SetText( tostring(level) );
	unlockInstance.Info:SetText( Locale.Lookup(perkAtLevel.perk.Help) )
	unlockInstance.Content:SetSizeY( math.max(unlockInstance.Info:GetSizeY() + PADDING_Y, 110) );
end

-- ===========================================================================
function AddCurrentProjectUnlock( projectAtLevel:table, affinityEnum:number )
	
	local PADDING_Y		:number	= 50;
	local level			:number = projectAtLevel.level; 
	local degree		:number = DEGREES[affinityEnum];
	local unlockInstance:table	= m_UnlockIM:GetInstance();
	
	unlockInstance.TextIcon:SetText( GetAffinityTextIcon(affinityEnum) );
	unlockInstance.Amt:SetColorByName( GetAffinityColorSet( affinityEnum ) );
	unlockInstance.Amt:SetText( tostring(level) );
	unlockInstance.Info:SetText( Locale.Lookup(GameInfo.Projects[projectAtLevel.projectType].Description) )
	unlockInstance.Content:SetSizeY( math.max(unlockInstance.Info:GetSizeY() + PADDING_Y, 110) );
end

-- ===========================================================================
--	Line for a "PURE" affinity amount
-- ===========================================================================
function DrawAffinityLine( affinity:number, degrees:number )
	if affinity > 0 then
		local ex:number, ey:number = PolarToCartesian(RADIUS_START + (affinity*RADIUS_MULT), degrees);
		DrawGlowLine(0,0,ex,ey);
	end
end

-- ===========================================================================
function DrawAffinityArc( affinity1:number, affinity2:number, level:number )

	local distance	:number = RADIUS_START + (level*RADIUS_MULT);
	local start		:number = DEGREES[affinity1];
	local stop		:number = DEGREES[affinity2];
	local step		:number = 360 / ( 300 + ((math.ceil(distance/100) * 4) ));
	local x			:number;
	local y			:number;

	-- Deal with wrap around:
	if start > stop then
		stop = stop + 360;
	end
	--print("Arcsegs: " .. tostring((stop-start)/math.floor(step)) );	-- Debug

	local ox,oy = PolarToCartesian( distance, start );
	for degrees = start+step,stop,step do
		x, y = PolarToCartesian( distance, degrees );
		DrawGlowLine(x,y,ox,oy);		
		ox = x;
		oy = y;
	end
end

-- ===========================================================================
--	Show a pie-slice graphic on the wheel when hovering over an affinity type.
-- ===========================================================================
function OnHoverBoxOfAffinity( control:table )
	local affinityEnum:number = -1;
	if control == Controls.PButton then affinityEnum = AFFINITY.purity; end
	if control == Controls.HButton then affinityEnum = AFFINITY.harmony; end
	if control == Controls.SButton then affinityEnum = AFFINITY.supremacy; end
	if control == Controls.PHButton then affinityEnum = AFFINITY.purityharmony; end
	if control == Controls.HSButton then affinityEnum = AFFINITY.harmonysupremacy; end
	if control == Controls.SPButton then affinityEnum = AFFINITY.supremacypurity; end
	if affinityEnum ~= -1 then
		textureName, x, y, w, h = GetHoverTextureInfo( affinityEnum );
		Controls.Hover:SetTexture( textureName );
		Controls.Hover:SetSizeVal( w, h );
		Controls.Hover:SetOffsetVal( x, y );
		Controls.Hover:SetHide(false);
	end
end

-- ===========================================================================
--	Hide the pie!
-- ===========================================================================
function OnBlurBoxOfAffinity( control:table )
	Controls.Hover:SetHide(true);
end

-- ===========================================================================
--	Fill out values showing the number of affinities of the current player
-- ===========================================================================
function RealizeBoxOfAffinities()
	Controls.PButton:SetText( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_PURITY_AMT", m_purity));
	Controls.HButton:SetText( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_HARMONY_AMT", m_harmony));
	Controls.SButton:SetText( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_SUPREMACY_AMT", m_supremacy));
	Controls.PHButton:SetText( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_PURITY_HARMONY_AMT", math.min(m_purity,m_harmony) ));
	Controls.HSButton:SetText( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_HARMONY_SUPREMACY_AMT", math.min(m_harmony,m_supremacy) ));
	Controls.SPButton:SetText( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_SUPREMACY_PURITY_AMT", math.min(m_supremacy,m_purity) ));
end

-- ===========================================================================
function CloseInfo()
	m_mode = MODE.wheel;
	View();
end

-- ===========================================================================
function OnClickUnlocks()

	-- Check the special enum to see if unlock is currently showing, and if it
	-- is have this click of the button close it.
	if m_selectedAffinity == AFFINITY_UNLOCK_ENUM then
		m_mode				= MODE.wheel;
		m_selectedAffinity	= nil;
		View();	
	else
		m_mode				= MODE.unlocks;
		m_selectedAffinity	= AFFINITY_UNLOCK_ENUM;
		View();
	end
end

-- ===========================================================================
function OnClickAffinity( affinityVoid1 )
	-- If the same affinity that is showing, close it.
	if m_selectedAffinity == affinityVoid1 then
		-- Same affinity, close.
		m_mode				= MODE.wheel;
		m_selectedAffinity	= nil;
		View();
	else
		-- Different affinity than what is showing.
		m_mode				= MODE.affinityInfo;
		m_selectedAffinity	= affinityVoid1;
		View();
	end
end

-- ===========================================================================
function OnClickCloseInfo()
	m_mode				= MODE.wheel;
	m_selectedAffinity	= nil;
	View();
end
Controls.CloseInfoButton:RegisterCallback( Mouse.eLClick, OnClickCloseInfo );


-- ===========================================================================
--	Display the wheel
-- ===========================================================================
function ViewWheel()
	
	m_GlowLineIM:ResetInstances();
	m_NodeIM:ResetInstances();
	m_NodeGlowIM:ResetInstances();

	Controls.InfoGrid:SetHide(true);

	-- Draw background
	local mostAffinityEnum :number = GetAffinityMostFollowed();
	if mostAffinityEnum ~= -1 then
		local textureName:string, x:number, y:number, w:number, h:number  = GetBackgroundTextureInfo( mostAffinityEnum );
		Controls.Background:SetTexture( textureName );
		Controls.Background:SetSizeVal( w, h );
		Controls.Background:SetOffsetVal( x, y );
	end
	Controls.Background:SetHide( mostAffinityEnum == -1 );
	
	-- Draw lines
	DrawAffinityLine(m_harmony,		DEGREES[AFFINITY.harmony]);
	DrawAffinityLine(m_purity,		DEGREES[AFFINITY.purity]);
	DrawAffinityLine(m_supremacy,	DEGREES[AFFINITY.supremacy]);

	-- Draw Arcs
	local i:number;
	for _,perkData in ipairs(m_affinityInfo[AFFINITY.purityharmony].Perks ) do
		if perkData.highest then
			DrawAffinityArc(AFFINITY.harmony, AFFINITY.purity, perkData.level);
			break;
		end
	end
	for _,perkData in ipairs(m_affinityInfo[AFFINITY.harmonysupremacy].Perks ) do
		if perkData.highest then
			DrawAffinityArc(AFFINITY.supremacy, AFFINITY.harmony, perkData.level);
			break;
		end
	end
	for _,perkData in ipairs(m_affinityInfo[AFFINITY.supremacypurity].Perks ) do
		if perkData.highest then
			DrawAffinityArc(AFFINITY.purity, AFFINITY.supremacy, perkData.level);
			break;
		end
	end

	--Draw buttons for affinity perks
	for k,v in pairs(m_affinityInfo[AFFINITY.purity].Perks) do
		DrawNode( v, AFFINITY.purity );
	end	
	for k,v in pairs(m_affinityInfo[AFFINITY.supremacy].Perks) do
		DrawNode( v, AFFINITY.supremacy );
	end
	for k,v in pairs(m_affinityInfo[AFFINITY.harmony].Perks) do
		DrawNode( v, AFFINITY.harmony );
	end
	for k,v in pairs(m_affinityInfo[AFFINITY.supremacypurity].Perks) do	
		DrawNode( v, AFFINITY.supremacypurity );
	end
	for k,v in ipairs(m_affinityInfo[AFFINITY.harmonysupremacy].Perks) do
		DrawNode( v, AFFINITY.harmonysupremacy );
	end
	for k,v in ipairs(m_affinityInfo[AFFINITY.purityharmony].Perks) do
		DrawNode( v, AFFINITY.purityharmony );
	end

	for k,v in ipairs(m_affinityInfo[AFFINITY.purity].Projects) do
		DrawProjectNode( v, AFFINITY.purity );
	end
	for k,v in ipairs(m_affinityInfo[AFFINITY.harmony].Projects) do
		DrawProjectNode( v, AFFINITY.harmony );
	end
	for k,v in ipairs(m_affinityInfo[AFFINITY.supremacy].Projects) do
		DrawProjectNode( v, AFFINITY.supremacy );
	end

	RealizeBoxOfAffinities();
end

-- ===========================================================================
--	Display which perks have been unlcoked
-- ===========================================================================
function ViewUnlocks()
	Controls.InfoGrid:SetHide(false);
	Controls.AffinityDisplay:SetHide(true);
	Controls.UnlockDisplay:SetHide(false);

	Controls.PanelTitle:SetText( Locale.ToUpper( Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_MY_PERKS")) );

	m_UnlockIM:ResetInstances();
	AddUnlocksForAffinity( AFFINITY.purity );
	AddUnlocksForAffinity( AFFINITY.supremacy );
	AddUnlocksForAffinity( AFFINITY.harmony );
	AddUnlocksForAffinity( AFFINITY.supremacypurity );
	AddUnlocksForAffinity( AFFINITY.harmonysupremacy );
	AddUnlocksForAffinity( AFFINITY.purityharmony );

	Controls.UnlockStack:CalculateSize();
	Controls.UnlockStack:ReprocessAnchoring();
	Controls.UnlockScroll:CalculateInternalSize();
	Controls.UnlockScroll:ReprocessAnchoring();

	RealizeBoxOfAffinities();
end

-- ===========================================================================
--	Display affinity info
-- ===========================================================================
function ViewAffinityInfo()
	Controls.InfoGrid:SetHide(false);
	Controls.AffinityDisplay:SetHide(false);
	Controls.UnlockDisplay:SetHide(true);

	local currentLevel : number = GetCurrentAffinityLevel(m_selectedAffinity);

	-- Fill up the top of the affinity info area
	Controls.PanelTitle			:SetText( Locale.ToUpper(m_affinityInfo[m_selectedAffinity].Title) );
	Controls.AffinityPortrait	:SetTexture("AffinityPortrait"..IMAGES[m_selectedAffinity].suffix..".dds");
	Controls.AffinityIcon		:SetText( GetAffinityTextIcon(m_selectedAffinity) );
	Controls.AffinityAmount		:SetText( tostring( currentLevel ) );
	Controls.AffinityDescription:SetText( m_affinityInfo[m_selectedAffinity].Description );
	Controls.AffinityQuote		:SetText( m_affinityInfo[m_selectedAffinity].Quote );

	-- Add affinity info
	m_AffinityIM:ResetInstances();
	for k,v in pairs(m_affinityInfo[m_selectedAffinity].Perks) do
		AddAffinityUnlock( v, m_selectedAffinity );
	end
	
	for k,v in pairs(m_affinityInfo[m_selectedAffinity].Projects) do
		AddAffinityProjectUnlock( v, m_selectedAffinity );
	end

	local details:string = "";
	if IsHybridAffinity(m_selectedAffinity) then
		details = Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_HYBRID") .. "[NEWLINE]";
	end

	if m_affinityInfo[m_selectedAffinity].NextPerkLevel == -1 then
		details = details .. Locale.Lookup("TXT_KEY_DIPLOMACYUI_AFFINITY_DETAILS_HIGHEST");		--TXT_KEY_AFFINITY_STATUS_MAX_LEVEL		
	else
		details = details .. 
			GetAffinityStatusProgressString( m_player, m_selectedAffinity, true ) 
			.. " " .. 
			Locale.Lookup("TXT_KEY_AFFINITY_STATUS_TOWARDS_LEVEL", currentLevel + 1 );
	end

	Controls.AffinityDetails:SetText( details );

	Controls.PerksStack:CalculateSize();
	Controls.PerksScroll:CalculateInternalSize();
	Controls.PerksScroll:ReprocessAnchoring();
	
	RealizeBoxOfAffinities();
end

-- ===========================================================================
--	Display contents based on current screen 'mode'
-- ===========================================================================
function View()
	if		m_mode == MODE.affinityInfo then	ViewAffinityInfo(); 
	elseif	m_mode == MODE.unlocks		then	ViewUnlocks(); 
	else										ViewWheel();
	end
end


-- ===========================================================================
--	Obtain all the perks for a given affinity.
--	Perks are placed in a member table
-- ===========================================================================
function CollectPerksForAffinity( affinityEnum:number, query:string )
		
	local highestLevelWithPerk	:number = 0;
	local affinityInRowString1	:string = "";
	local currentVal1			:number = 0;
	local currentVal2			:number = 0;
	
	if affinityEnum == AFFINITY.supremacy			then	currentVal1 = m_supremacy;								affinityInRowString1 = "SupremacyLevelNeeded"; end
	if affinityEnum == AFFINITY.harmony				then	currentVal1 = m_harmony;								affinityInRowString1 = "HarmonyLevelNeeded"; end
	if affinityEnum == AFFINITY.purity				then	currentVal1 = m_purity;									affinityInRowString1 = "PurityLevelNeeded"; end
	if affinityEnum == AFFINITY.supremacypurity		then	currentVal1 = m_supremacy;	currentVal2 = m_purity;		affinityInRowString1 = "SupremacyLevelNeeded";	affinityInRowString2 = "PurityLevelNeeded"; end
	if affinityEnum == AFFINITY.harmonysupremacy	then	currentVal1 = m_harmony;	currentVal2 = m_supremacy;	affinityInRowString1 = "HarmonyLevelNeeded";	affinityInRowString2 = "SupremacyLevelNeeded"; end
	if affinityEnum == AFFINITY.purityharmony		then	currentVal1 = m_purity;		currentVal2 = m_harmony;	affinityInRowString1 = "PurityLevelNeeded";		affinityInRowString2 = "HarmonyLevelNeeded"; end

	m_affinityInfo[affinityEnum].Perks = {};
	m_affinityInfo[affinityEnum].Projects = {};
	local levels:table = {};

	-- Collect perks
	for row in GameInfo.Affinity_Perks(query) do
		local perk			:table	= GameInfo.PlayerPerks[ row.PlayerPerk];
		local description	:string = Locale.Lookup( perk.Help );
		table.insert(m_affinityInfo[affinityEnum].Perks, {
			level	= row[affinityInRowString1],
			perk	= perk,
			highest	= false
		});
		table.insert(levels, row[affinityInRowString1]);


		if affinityEnum == AFFINITY.supremacypurity or affinityEnum == AFFINITY.harmonysupremacy or affinityEnum == AFFINITY.purityharmony then
			-- Because query string will only return exact single or combo affinities, only need one check for highest.
			-- (e.g., Purposely there is only one affinityInRowSwing because it's the same value for either affinity).
			if	currentVal1 >= row[affinityInRowString1] and 
				currentVal2 >= row[affinityInRowString1] and
				row[affinityInRowString1] > highestLevelWithPerk then 
					highestLevelWithPerk = row[affinityInRowString1];
			end
		else
			-- Simple single check
			if currentVal1 >= row[affinityInRowString1] and  row[affinityInRowString1] > highestLevelWithPerk then 
				highestLevelWithPerk = row[affinityInRowString1];
			end
		end
	end

	-- Collect project unlocks
	if (not IsHybridAffinity(affinityEnum)) then
		local typeStr : string;
		if (affinityEnum == AFFINITY.harmony) then 
			typeStr = "AFFINITY_TYPE_HARMONY"; 
		elseif (affinityEnum == AFFINITY.purity) then 
			typeStr = "AFFINITY_TYPE_PURITY";
		else
			typeStr = "AFFINITY_TYPE_SUPREMACY";
		end		

		local projectQuery : string = string.format("SELECT Project_AffinityPrereqs.Level AS Level, Projects.Type AS ProjectType FROM Project_AffinityPrereqs INNER JOIN Projects ON Project_AffinityPrereqs.ProjectType = Projects.Type WHERE Project_AffinityPrereqs.AffinityType = '%s'", typeStr);
		for row in DB.Query(projectQuery) do
			table.insert(m_affinityInfo[affinityEnum].Projects, { projectType = row.ProjectType, level = row.Level, highest = false });
			table.insert(levels, row.Level);

			if( currentVal1 >= row.Level and row.Level > highestLevelWithPerk ) then
				highestLevelWithPerk = row.Level;
			end
		end
	end

	m_affinityInfo[affinityEnum].HighestLevelWithPerk = highestLevelWithPerk;

	-- Store the highest achieved perk for this affinity.
	if highestLevelWithPerk > 0 then
		for _,nodeData in ipairs( m_affinityInfo[affinityEnum].Perks ) do
			if nodeData.level == highestLevelWithPerk then
				nodeData.highest = true;
			end
		end
		for _,projectData in ipairs( m_affinityInfo[affinityEnum].Projects ) do
			if projectData.level == highestLevelWithPerk then
				projectData.highest = true;
			end
		end
	end

	-- Find next perk or -1 for none...
	table.sort( levels, function(a,b) return a < b; end );
	local amt			:number = table.count(levels);
	local nextLevel		:number = levels[1];
	local nextPerkLevel	:number = levels[1];
	for n,level in pairs(levels) do
		if level == highestLevelWithPerk then
			nextLevel = highestLevelWithPerk + 1;
			if n < amt then
				nextPerkLevel = levels[n+1];				
			else
				nextPerkLevel = -1;
			end
			break;
		end
	end
	if nextLevel > levels[table.count(levels)] then
		nextLevel = -1;
	end

	m_affinityInfo[affinityEnum].NextLevel		= nextLevel;
	m_affinityInfo[affinityEnum].NextPerkLevel	= nextPerkLevel;
	m_affinityInfo[affinityEnum].HighestLevel	= levels[table.count(levels)];

end


-- ===========================================================================
--	Collect the data to display
-- ===========================================================================
function UpdateData()
	
	m_purity	= m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID);
	m_supremacy	= m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID);
	m_harmony	= m_player:GetAffinityLevel(GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID);

	CollectPerksForAffinity( AFFINITY.supremacy,		"SupremacyLevelNeeded > 0 and PurityLevelNeeded == 0 and HarmonyLevelNeeded == 0" );
	CollectPerksForAffinity( AFFINITY.harmony,			"HarmonyLevelNeeded > 0 and SupremacyLevelNeeded == 0 and PurityLevelNeeded == 0" );
	CollectPerksForAffinity( AFFINITY.purity,			"PurityLevelNeeded > 0 and HarmonyLevelNeeded == 0 and SupremacyLevelNeeded == 0" );
	CollectPerksForAffinity( AFFINITY.purityharmony,	"PurityLevelNeeded > 0 and HarmonyLevelNeeded > 0" );
	CollectPerksForAffinity( AFFINITY.supremacypurity,	"SupremacyLevelNeeded > 0 and PurityLevelNeeded > 0" );
	CollectPerksForAffinity( AFFINITY.harmonysupremacy, "HarmonyLevelNeeded > 0 and SupremacyLevelNeeded > 0" );
end


-- ===========================================================================
--	Should be guaranteed to be called every time the window is shown.
-- ===========================================================================
function ShowWindow()	
	m_player			= Players[Game.GetActivePlayer()];
	m_selectedPlayer	= Players[selectedPlayer];
	UpdateData();
	View();

	ShowDiploTutorial("DIPLOMACY_AFFINITY", GameInfo.Tutorials["TUTORIAL_DIPLOMACY_AFFINITY"].ID, "TXT_KEY_DIPLOMACYUI_TUTORIAL_AFFINITY");
end


-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnStateChanged(state : number, selectedPlayer : number)
	if state == g_diplomacyUIStates.AFFINITY then
		if ContextPtr:IsHidden() then
			ContextPtr:SetHide(false);
		end
	else
		if not ContextPtr:IsHidden() then
			Close();
		end
	end
end


-- ===========================================================================
--	LUA Event
--	Debug only, reload cached values across reload for this context.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == DEBUG_CACHE_SCREEN_NAME and contextTable ~= nil then
		m_hiddenAtShutdown	= contextTable["m_hiddenAtShutdown"];
		m_mode				= contextTable["m_mode"];
		m_selectedAffinity	= contextTable["m_selectedAffinity"];
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isHotload : boolean)
	m_player = Players[Game.GetActivePlayer()];	
	if isHotload then
		LuaEvents.GameDebug_GetValues(DEBUG_CACHE_SCREEN_NAME);
		ContextPtr:SetHide(m_hiddenAtShutdown);
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShowWindow()
	ShowWindow();
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInput( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			if m_mode ~= MODE.wheel then
				CloseInfo();
			else
				Close();
				LuaEvents.DiplomacyUI_PlayerSelected(m_player:GetID());	-- Reshow menu for selected player if exiting via keyboards
			end
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_hiddenAtShutdown",	ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_mode",				m_mode );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_selectedAffinity",	m_selectedAffinity );
	LuaEvents.GameDebug_Return.Remove( OnGameDebugReturn );
	LuaEvents.DiplomacyUI_StateChanged.Remove(OnStateChanged);
end

-- ===========================================================================
--
--	Start it up...
--
-- ===========================================================================
function Initialize()

	m_mode = MODE.wheel;

	-- Resizing based on resolution
	local width:number, height:number = UIManager:GetScreenSizeVal();
	Controls.InfoGrid:SetSizeY(height - 234);
	Controls.PerksScroll:SetSizeY(height - 515);

	local cardOffsetX	:number = 5;	
	local cardOffsetY	:number = 20;	

	-- Items are setup for min-spec
	-- Use formula from other screens to determine if offsets should utilize more screen space.
	local otherOffsetX	:number = width*.11;	
	print("OTHER:",otherOffsetX,"total:",(width-otherOffsetX*2));
	if not ((width-otherOffsetX*2)<970) then
		cardOffsetX = width*.085;
		cardOffsetY = 50;
	end

	Controls.WheelCenter:SetSizeY(height -215);
	Controls.WheelCenter:SetOffsetX(cardOffsetX);
	Controls.AffinityBox:SetOffsetX(cardOffsetX);	
	Controls.AffinityBox:SetOffsetY(cardOffsetY);

	-- Tweak anchoring and position of gridbutton control's internal text control.
	Controls.PButton :GetTextControl():SetAnchor("L,C");
	Controls.HButton :GetTextControl():SetAnchor("L,C");
	Controls.SButton :GetTextControl():SetAnchor("L,C");
	Controls.PHButton:GetTextControl():SetAnchor("L,C");
	Controls.HSButton:GetTextControl():SetAnchor("L,C");
	Controls.SPButton:GetTextControl():SetAnchor("L,C");
	Controls.PButton :GetTextControl():SetOffsetVal(20,0);
	Controls.HButton :GetTextControl():SetOffsetVal(20,0);
	Controls.SButton :GetTextControl():SetOffsetVal(20,0);
	Controls.PHButton:GetTextControl():SetOffsetVal(20,0);
	Controls.HSButton:GetTextControl():SetOffsetVal(20,0);
	Controls.SPButton:GetTextControl():SetOffsetVal(20,0);	

	-- Setup button callbacks
	Controls.PButton :SetVoid1( AFFINITY.purity );
	Controls.HButton :SetVoid1( AFFINITY.harmony );
	Controls.SButton :SetVoid1( AFFINITY.supremacy );
	Controls.PHButton:SetVoid1( AFFINITY.purityharmony );
	Controls.HSButton:SetVoid1( AFFINITY.harmonysupremacy );
	Controls.SPButton:SetVoid1( AFFINITY.supremacypurity );
	Controls.PButton :RegisterCallback( Mouse.eLClick, OnClickAffinity );
	Controls.HButton :RegisterCallback( Mouse.eLClick, OnClickAffinity );
	Controls.SButton :RegisterCallback( Mouse.eLClick, OnClickAffinity );
	Controls.PHButton:RegisterCallback( Mouse.eLClick, OnClickAffinity );
	Controls.HSButton:RegisterCallback( Mouse.eLClick, OnClickAffinity );
	Controls.SPButton:RegisterCallback( Mouse.eLClick, OnClickAffinity );
	Controls.UnlockButton:RegisterCallback( Mouse.eLClick, OnClickUnlocks );	

	-- Setup hover callbacks (also on the button)
	Controls.PButton :RegisterMouseEnterCallback( OnHoverBoxOfAffinity );
	Controls.HButton :RegisterMouseEnterCallback( OnHoverBoxOfAffinity );
	Controls.SButton :RegisterMouseEnterCallback( OnHoverBoxOfAffinity );
	Controls.PHButton:RegisterMouseEnterCallback( OnHoverBoxOfAffinity );
	Controls.HSButton:RegisterMouseEnterCallback( OnHoverBoxOfAffinity );
	Controls.SPButton:RegisterMouseEnterCallback( OnHoverBoxOfAffinity );
	Controls.PButton :RegisterMouseExitCallback( OnBlurBoxOfAffinity );
	Controls.HButton :RegisterMouseExitCallback( OnBlurBoxOfAffinity );
	Controls.SButton :RegisterMouseExitCallback( OnBlurBoxOfAffinity );
	Controls.PHButton:RegisterMouseExitCallback( OnBlurBoxOfAffinity );
	Controls.HSButton:RegisterMouseExitCallback( OnBlurBoxOfAffinity );
	Controls.SPButton:RegisterMouseExitCallback( OnBlurBoxOfAffinity );

	-- Native UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShowHandler( OnShowWindow );
	ContextPtr:SetInputHandler( OnInput );	
	ContextPtr:SetShutdown( OnShutdown )
	
	-- LUA Events
	LuaEvents.DiplomacyUI_StateChanged.Add( OnStateChanged );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );		-- hotloading help	
end
Initialize();
