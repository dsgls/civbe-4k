-- ===========================================================================
--	Common defines for Seeded Start
-- ===========================================================================

ID_NO_SELECTED		= -1;
ID_EXPLICITLY_RANDOM  = -2; -- See CvEnums.h

local m_randomIcon =
{
	index	= 4, 
	size	= 64,
	atlas	= "WORLDTYPE_ATLAS"
}

-- ===========================================================================
function SetSeededIcon( id, collection, control )

	if ( id == ID_NO_SELECTED ) then		
		IconHookup( 0, 64, "GAME_SETUP_ATLAS", control );
	elseif ( id == ID_EXPLICITLY_RANDOM ) then
		IconHookup( m_randomIcon.index, m_randomIcon.size, m_randomIcon.atlas, control );
	else
		local item = collection[ id ];		
		IconHookup( item.PortraitIndex, 64, item.IconAtlas, control);
	end	
	control:SetHide( id == ID_NO_SELECTED );
end


-- ===========================================================================
function SetRandomSeededListItem( selectedIndex, control )

	control.Highlight:SetHide( not (selectedIndex == ID_EXPLICITLY_RANDOM) );
	control.CheckMark:SetHide( not (selectedIndex == ID_EXPLICITLY_RANDOM) );
	control.NameLabel:LocalizeAndSetText( "TXT_KEY_MAP_OPTION_RANDOM" );
	control.DescriptionLabel:LocalizeAndSetText( "" );
	
	IconHookup( m_randomIcon.index, m_randomIcon.size, m_randomIcon.atlas, control.Portrait );
end