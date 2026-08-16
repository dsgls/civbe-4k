-- ===========================================================================
--		IntrigueHelper
-- ===========================================================================


-- ===========================================================================
--		CONSTANTS
-- ===========================================================================
local COLOR_RGB_INTRIGUE_LOW				= { r=0x22,g=0x5c,b=0xb0 };
local COLOR_RGB_INTRIGUE_HIGH				= { r=0xb4,g=0x1f,b=0x74 };


-- ===========================================================================
-- intrigue, Value from 1 to 100
-- RETURNS: an ABGR uint of the color for that intrigue level
-- ===========================================================================
function IntrigueToABGRColor( intrigue )
	if ( intrigue < 1 ) then
		intrigue = 1;
	elseif ( intrigue > 100 ) then
		intrigue = 100;
	end
	local percent = intrigue * 0.01;

	local red	= ((COLOR_RGB_INTRIGUE_HIGH.r - COLOR_RGB_INTRIGUE_LOW.r) * percent) + COLOR_RGB_INTRIGUE_LOW.r;
	local green = ((COLOR_RGB_INTRIGUE_HIGH.g - COLOR_RGB_INTRIGUE_LOW.g) * percent) + COLOR_RGB_INTRIGUE_LOW.g;
	local blue	= ((COLOR_RGB_INTRIGUE_HIGH.b - COLOR_RGB_INTRIGUE_LOW.b) * percent) + COLOR_RGB_INTRIGUE_LOW.b;

	-- combine the ingredients, stiring gently
	local abgr = 0xff000000 + lshift( blue, 16 ) + lshift( green, 8 ) + red;
	return abgr;
end
