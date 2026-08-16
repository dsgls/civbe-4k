-- ===========================================================================
--
--	Game Setup / Seeded Start
--
-- ===========================================================================
include( "IconSupport" );
include( "SupportFunctions" );
include( "UniqueBonuses" );
include( "LoadoutUtils" );
include( "SeededStartCommon" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

-- order based on SectionType
local SectionTitles =
	{
		Locale.ConvertTextKey("TXT_KEY_DESIGNATE_SPONSOR"),
		Locale.ConvertTextKey("TXT_KEY_CHOOSE_COLONISTS"),
		Locale.ConvertTextKey("TXT_KEY_CHOOSE_SPACECRAFT"),
		Locale.ConvertTextKey("TXT_KEY_CHOOSE_CARGO"),
		Locale.ConvertTextKey("TXT_KEY_CHOOSE_PLANET")
	};

-- order based on SectionType
local m_SectionBackgrounds =
	{
		"Assets/UI/Art/GameSetup/SeededStartLeaderSelectBack.dds",
		"Assets/UI/Art/GameSetup/SeededStartColonistSelectBack.dds",
		"Assets/UI/Art/GameSetup/SeededStartShipSelectBack.dds",
		"Assets/UI/Art/GameSetup/SeededStartCargoSelectBack.dds",
		"Assets/UI/Art/GameSetup/SeededStartWorldSelectBack.dds"
	};

local SectionType = 
	{ 
		SPONSOR 	= 1, 
		COLONISTS 	= 2, 
		SPACECRAFT 	= 3, 
		CARGO 		= 4, 
		PLANET 		= 5
	};


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local bIsModding = (ContextPtr:GetID() == "ModdingGameSetupScreen");

local m_LastSection			= nil;
local m_CurrentSection		= SectionType.SPONSOR;

local m_sponsorIconInfo		= {};
local m_isSponsorSelected	= false;
local m_isColonistsSelected	= false;
local m_isSpacecraftSelected= false;
local m_isCargoSelected		= false;
local m_isPlanetSelected	= false;

local g_planetIcon = nil;


-- ===========================================================================
--	Back (Button) Handler
-- ===========================================================================
function OnBack()

	-- We're heading back to the main menu, reset our currently selected items
	m_LastSelection			= nil;
	m_CurrentSelection		= SectionType.SPONSOR;

	m_sponsorIconInfo		= {};
	m_isSponsorSelected		= false;
	m_isColonistsSelected	= false;
	m_isSpacecraftSelected	= false;
	m_isCargoSelected		= false;

	PreGame.SetLoadoutColonist(LoadoutUtils.GetPlayerID(),	ID_NO_SELECTED);
	PreGame.SetLoadoutCargo(LoadoutUtils.GetPlayerID(),		ID_NO_SELECTED );
	PreGame.SetLoadoutSpacecraft(LoadoutUtils.GetPlayerID(),ID_NO_SELECTED );

	LuaEvents.PlanetSelected( {nil,nil,nil} );	

	UIManager:DequeuePopup( ContextPtr );
	ContextPtr:SetHide( true );

	-- Was a games setup screen presented before going into seeded start?
	-- If so, pop dialog that too...
	local otherPopup	= ContextPtr:LookUpControl("../../GameSetupScreen");
	if ( otherPopup ~= nil ) then
		UIManager:DequeuePopup( otherPopup );
	end

	Events.AudioPlay2DSound("AS2D_INTERFACE_BUTTON_CLICK_BACK");
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );


------------------------------------------------------------------------------
--	Start the game
------------------------------------------------------------------------------
function OnStart()

	PreGame.SetPersistSettings(not bIsModding); -- Whether or not to save settings for the "Play Now" option.
	
	if( bIsModding and IsWBMap(PreGame.GetMapScript()) ) then
		PreGame.SetRandomMapScript(false);
		PreGame.SetLoadWBScenario(PreGame.GetLoadWBScenario());
		PreGame.SetOverrideScenarioHandicap(true);
	else
		PreGame.SetLoadWBScenario(false);
	end
	
	-- Unload background textures
	Controls.Background:SetHide( true );
	for _,texturePath in ipairs(m_SectionBackgrounds) do	
		Controls.Background:SetTexture( texturePath );
		Controls.Background:UnloadTexture();
	end

	Events.SerialEventStartGame();
	UIManager:SetUICursor( 1 );
end
Controls.StartButton:RegisterCallback( Mouse.eLClick, OnStart );


------------------------------------------------------------------------------
--	Show player advanced options...
------------------------------------------------------------------------------
function OnAdvanced()
	UIManager:QueuePopup( Controls.AdvancedSetup, PopupPriority.AdvancedSetup );
end
Controls.AdvancedButton:RegisterCallback( Mouse.eLClick, OnAdvanced );


-- ===========================================================================
--	Determine the next section to enter seeded start information
--	fromSection,	The current section the player is coming from
--	startSection,	(optional/internal) used when recursing to know the first
--					section that was attempted.
-- ===========================================================================
function GetNextUnassignedSectionTypeAfter( fromSection, startSection )

	-- Setup optional parameter for recurrsing
	if ( startSection == nil ) then
		startSection = fromSection;
	end

	-- Bounds check
	if ( fromSection < SectionType.SPONSOR ) then
		fromSection = SectionType.SPONSOR;
	elseif ( fromSection > SectionType.PLANET) then
		fromSection = SectionType.PLANET;
	end

	fromSection = fromSection + 1;

	-- Loop around to beginning
	if (fromSection > SectionType.PLANET ) then
		fromSection = SectionType.SPONSOR;
	end
	
	-- If back at the start, then this was 
	if ( fromSection == startSection ) then
		return startSection;
	end

	if ( fromSection == SectionType.SPONSOR ) and not m_isSponsorSelected then
		return SectionType.SPONSOR;
	end

	if ( fromSection == SectionType.COLONISTS ) and not m_isColonistsSelected then
		return SectionType.COLONISTS;
	end

	if ( fromSection == SectionType.SPACECRAFT ) and not m_isSpacecraftSelected then
		return SectionType.SPACECRAFT;
	end

	if ( fromSection == SectionType.CARGO ) and not m_isCargoSelected then
		return SectionType.CARGO;
	end

	if ( fromSection == SectionType.PLANET ) and not m_isPlanetSelected then
		return SectionType.PLANET;
	end

	-- One not found; recurse.
	return GetNextUnassignedSectionTypeAfter( fromSection, startSection );
	
end


-- ===========================================================================
function RealizeSection( sectionEnum )
	m_LastSection	 = m_CurrentSection;
	m_CurrentSection = sectionEnum;   
	UpdateDisplay();
end


------------------------------------------------------------------------------
--	Pressed select sponsor button.
------------------------------------------------------------------------------
function OnSelectSponsor( atlas, offset )
	RealizeSection( SectionType.SPONSOR );
end
Controls.SponsorButton:RegisterCallback( Mouse.eLClick, OnSelectSponsor );

------------------------------------------------------------------------------
--	Pressed select colonists button.
------------------------------------------------------------------------------
function OnSelectColonists()	
	RealizeSection( SectionType.COLONISTS );
end
Controls.ColonistsButton:RegisterCallback( Mouse.eLClick, OnSelectColonists );

------------------------------------------------------------------------------
--	Pressed select spacecraft button.
------------------------------------------------------------------------------
function OnSelectSpacecraft()		
	RealizeSection( SectionType.SPACECRAFT );
end
Controls.SpacecraftButton:RegisterCallback( Mouse.eLClick, OnSelectSpacecraft );

------------------------------------------------------------------------------
--	Pressed select cargo button.
------------------------------------------------------------------------------
function OnSelectCargo()
	RealizeSection( SectionType.CARGO );
end
Controls.CargoButton:RegisterCallback( Mouse.eLClick, OnSelectCargo );

------------------------------------------------------------------------------
--	Pressed select planet button.
------------------------------------------------------------------------------
function OnSelectPlanet()	
	RealizeSection( SectionType.PLANET );	
end
Controls.PlanetButton:RegisterCallback( Mouse.eLClick, OnSelectPlanet );




------------------------------------------------------------------------------
--	PreGame doesn't have setup for icon, info sent across wire
------------------------------------------------------------------------------
function OnSponsorSelected()
	UpdateDisplay();	
end
LuaEvents.SponsorSelected.Add( OnSponsorSelected );

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function OnColonistsSelected()
	UpdateDisplay();
end
LuaEvents.ColonistsSelected.Add( OnColonistsSelected );

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function OnSpacecraftSelected()
	UpdateDisplay();
end
LuaEvents.SpacecraftSelected.Add( OnSpacecraftSelected );

------------------------------------------------------------------------------
------------------------------------------------------------------------------
function OnCargoSelected()	
	UpdateDisplay();
end
LuaEvents.CargoSelected.Add( OnCargoSelected );
  
------------------------------------------------------------------------------
--	It is possible for an icon object to be passed in that is just filled
--	with NIL.  In that case, reset having a selected planet.
------------------------------------------------------------------------------
function OnPlanetSelected( icon )
	if ( icon[1] == nil ) then
		m_isPlanetSelected = false;
		g_planetIcon = nil;
	else
		m_isPlanetSelected = true;
		g_planetIcon = icon;
	end
	UpdateDisplay();
end
LuaEvents.PlanetSelected.Add( OnPlanetSelected );


------------------------------------------------------------------------------
--	Advance to next sub-section
------------------------------------------------------------------------------
function OnNextLoadout()
	local nextSection = GetNextUnassignedSectionTypeAfter( m_CurrentSection );
	if (nextSection > 0) then
		RealizeSection( nextSection );
	else
		UpdateDisplay();
	end
		Events.AudioPlay2DSound("AS2D_INTERFACE_MENU_ITEM_MOUSE_OVER");
end
LuaEvents.NextLoadout.Add( OnNextLoadout );


-- ===========================================================================
--	Display the contents based on the current section
-- ===========================================================================
function UpdateDisplay()

	Controls.SelectSponsor 		:SetHide( not (m_CurrentSection == SectionType.SPONSOR 		) );
	Controls.SelectColonists	:SetHide( not (m_CurrentSection == SectionType.COLONISTS 	) );
	Controls.SelectSpacecraft	:SetHide( not (m_CurrentSection == SectionType.SPACECRAFT 	) );
	Controls.SelectCargo		:SetHide( not (m_CurrentSection == SectionType.CARGO  		) );
	Controls.SelectPlanet		:SetHide( not (m_CurrentSection == SectionType.PLANET 		) );

	Controls.SponsorHighlight	:SetHide( not (m_CurrentSection == SectionType.SPONSOR 		) );
	Controls.ColonistsHighlight	:SetHide( not (m_CurrentSection == SectionType.COLONISTS 	) );
	Controls.SpacecraftHighlight:SetHide( not (m_CurrentSection == SectionType.SPACECRAFT	) );
	Controls.CargoHighlight		:SetHide( not (m_CurrentSection == SectionType.CARGO		) );
	Controls.PlanetHighlight	:SetHide( not (m_CurrentSection == SectionType.PLANET 		) );
	
	-- Fade from one image to another (if coming from another section and not first starting up)
	if ( m_LastSection ~= nil ) then
		Controls.OutImage:SetTexture( m_SectionBackgrounds[m_LastSection] );
		Controls.OutImage:SetHide( false );
		Controls.OutAnim:SetToBeginning();
		Controls.OutAnim:Play();
		m_LastSection = nil;
	end

	Controls.Background:SetTexture( m_SectionBackgrounds[m_CurrentSection] );

	local sectionTitleString = SectionTitles[ m_CurrentSection ];
	Controls.SectionTitle:SetText( sectionTitleString );

	local sponsorID		= PreGame.GetCivilization(LoadoutUtils.GetPlayerID());
	local colonistsID	= PreGame.GetLoadoutColonist(LoadoutUtils.GetPlayerID());
	local cargoID		= PreGame.GetLoadoutCargo(LoadoutUtils.GetPlayerID());
	local spacecraftID	= PreGame.GetLoadoutSpacecraft(LoadoutUtils.GetPlayerID());

	if (sponsorID == nil ) then		sponsorID	= ID_EXPLICITLY_RANDOM; end
	if (colonistsID == nil ) then	colonistsID = ID_EXPLICITLY_RANDOM; end
	if (cargoID == nil ) then		cargoID		= ID_EXPLICITLY_RANDOM; end
	if (spacecraftID == nil ) then	spacecraftID= ID_EXPLICITLY_RANDOM; end


	-- ===== Button bar  =====
	--[[ ??TRON remove
	if (sponsorID ~= nil and sponsorID ~= ID_NO_SELECTED) then
		local civilization = GameInfo.Civilizations[sponsorID];
		IconHookup(civilization.PortraitIndex, 64, civilization.IconAtlas, Controls.SponsorIcon);
		Controls.SponsorIcon:SetHide(false);
		Controls.SponsorTypeIcon:SetHide(true);
		m_isSponsorSelected = true;
	else
		IconHookup( 2, 64, "GAME_SETUP_ATLAS", Controls.SponsorIcon );
		Controls.SponsorIcon:SetHide(true);
		Controls.SponsorTypeIcon:SetHide(false);
	end
	--]]

	SetSeededIcon( sponsorID, GameInfo.Civilizations,  Controls.SponsorIcon);
	m_isSponsorSelected = ( sponsorID ~= ID_NO_SELECTED );
	Controls.SponsorTypeIcon:SetHide( m_isSponsorSelected );

	SetSeededIcon( colonistsID, GameInfo.Colonists,  Controls.ColonistsIcon);
	m_isColonistsSelected = ( colonistsID ~= ID_NO_SELECTED );
	Controls.ColonistsTypeIcon:SetHide( m_isColonistsSelected );

	SetSeededIcon( cargoID, GameInfo.Cargo,  Controls.CargoIcon);
	m_isCargoSelected = ( cargoID ~= ID_NO_SELECTED );
	Controls.CargoTypeIcon:SetHide( m_isCargoSelected );
	
	SetSeededIcon( spacecraftID, GameInfo.Spacecraft,  Controls.SpacecraftIcon);
	m_isSpacecraftSelected = ( spacecraftID ~= ID_NO_SELECTED );
	Controls.SpacecraftTypeIcon:SetHide( m_isSpacecraftSelected );
	


	if ( g_planetIcon ~= nil ) then
		IconHookup( g_planetIcon[1], g_planetIcon[2], g_planetIcon[3],  Controls.PlanetIcon );
		Controls.PlanetIcon		:SetHide( false );
		Controls.PlanetTypeIcon	:SetHide( true );
	else
		-- Can revert back...
		Controls.PlanetIcon		:SetHide( true );
		Controls.PlanetTypeIcon	:SetHide( false );
		IconHookup( 3, 64, "GAME_SETUP_ATLAS", Controls.PlanetIcon );
	end


	local isSeededReady = m_isSponsorSelected and m_isColonistsSelected and m_isCargoSelected and m_isSpacecraftSelected and m_isPlanetSelected;

	-- ===== Start button =====
	if ( isSeededReady ) then

		Controls.StartButton:SetHide( false );

		local isAdvancedOptionsValid = false;		
		local playerTeam			 = PreGame.GetTeam(0);

		for i = 1, GameDefines.MAX_MAJOR_CIVS-1 do
			if( PreGame.GetSlotStatus(i) == SlotStatus.SS_COMPUTER ) then
				if( PreGame.GetTeam(i) ~= playerTeam ) then
					isAdvancedOptionsValid = true;
				end
			end
		end

		if ( isAdvancedOptionsValid ) then
			Controls.StartButton:SetDisabled( false );
			Controls.StartButton:SetToolTipString( nil );
		else
			Controls.StartButton:SetDisabled( true );
			Controls.StartButton:SetToolTipString( Locale.ConvertTextKey("TXT_KEY_BAD_TEAMS") );
		end

	else
		Controls.StartButton:SetHide( true );
	end


end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function SetMapTypeForScript()
	Controls.AdvancedButton:SetDisabled(false);
	if( not PreGame.IsRandomMapScript() ) then   
		local mapScriptFileName = PreGame.GetMapScript();
		local mapScript = nil;
		
		for row in GameInfo.MapScripts() do
			if(row.FileName == mapScriptFileName) then
				mapScript = row;
			end
		end
		
		if(mapScript ~= nil) then
			IconHookup( mapScript.IconIndex or 0, 128, mapScript.IconAtlas, Controls.TypeIcon );        
		else
			PreGame.SetRandomMapScript(true);
		end
	end
	
	if(PreGame.IsRandomMapScript()) then
		IconHookup( 4, 128, "WORLDTYPE_ATLAS", Controls.TypeIcon); 
	end
end

-------------------------------------------------------------        
---------------------------------------------------------------- 
function IsWBMap(file)
	return Path.UsesExtension(file,".CivBEMap"); 
end
----------------------------------------------------------------        
----------------------------------------------------------------        
function ShowHideHandler( isHide, isInit )

	if ( not isInit ) then
		if( isHide == false ) then 		
			m_CurrentSection = SectionType.SPONSOR				
			UpdateDisplay();

			local screenWidth, screenHeight = UIManager:GetScreenSizeVal();	
			Controls.SubPanel:SetSizeY( screenHeight - 188 );
		end
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


----------------------------------------------------------------        
-- Input processing
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			OnBack();
			Events.AudioPlay2DSound("AS2D_INTERFACE_MENU_ITEM_MOUSE_OVER");
			return true;
		end
		if wParam == Keys.VK_SPACE then
			OnNextLoadout();
			Events.AudioPlay2DSound("AS2D_INTERFACE_MENU_ITEM_MOUSE_OVER");
			return true;
		end

	end
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
function Initialize()	
	TruncateSelfWithTooltip( Controls.AdvancedButton );
end


Initialize();