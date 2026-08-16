------------------------------------------------------------------------------
-- Misc Support Functions
------------------------------------------------------------------------------

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_strEllipsis = Locale.ConvertTextKey("TXT_KEY_GENERIC_DOT_DOT_DOT");


-- ===========================================================================
--	Sets a Label or control that contains a label (e.g., GridButton) with
--	a string that, if necessary, will be truncated.
--
--	RETURNS: true if truncated.
-- ===========================================================================
function TruncateString(control, resultSize, longStr, trailingText)

	-- Ensure this has the actual text control
	if control.GetTextControl ~= nil then
		control = control:GetTextControl();
	end

	local isTruncated = false;
	if(longStr == nil)then
		longStr = control:GetText();
		
		if(trailingText == nil)then
			longStr = "";
		end
	end
	
	if(control ~= nil)then

		-- Determine full length of control.
		control:SetText(longStr);
		local fullStrExtent = control:GetSizeX();
		
		-- Determine how long a trailing text portion will be.
		if(trailingText == nil)then
			trailingText = "";
		end
		control:SetText(trailingText);
		local trailingExtent = control:GetSizeX();
		
		local sizeAfterTruncate = resultSize - trailingExtent;
		if(sizeAfterTruncate > 0)then
			local truncatedSize = fullStrExtent;
			local newString = longStr;
			
			local ellipsis = "";
			
			if( sizeAfterTruncate < truncatedSize ) then
				ellipsis = m_strEllipsis;
				isTruncated = true;
			end
			
			control:SetText(ellipsis);
			local ellipsisExtent = control:GetSizeX();
			sizeAfterTruncate = sizeAfterTruncate - ellipsisExtent;
			
			while (sizeAfterTruncate < truncatedSize and Locale.Length(newString) > 1) do
				newString = Locale.Substring(newString, 1, Locale.Length(newString) - 1);
				control:SetText(newString);
				truncatedSize = control:GetSizeX();
			end
			
			control:SetText(newString .. ellipsis .. trailingText);
		end
	else
		print("ERROR: Attempt to TruncateString but NIL control passed in!. string=", longStr);
	end
	return isTruncated;
end


-- ===========================================================================
--	Same as TruncateString(), but if truncation occurs automatically adds
--	the full text as a tooltip.
-- ===========================================================================
function TruncateStringWithTooltip(control, resultSize, longStr, trailingText)
	local isTruncated = TruncateString( control, resultSize, longStr, trailingText );
	if isTruncated then
		control:SetToolTipString( longStr );
	else
		control:SetToolTipString( nil );
	end
	return isTruncated;
end


-- ===========================================================================
--	Performs a truncation based on the control's contents
-- ===========================================================================
function TruncateSelfWithTooltip( control )
	local resultSize = control:GetSizeX();
	local longStr	 = control:GetText();
	return TruncateStringWithTooltip(control, resultSize, longStr);
end


-- ===========================================================================
--	Truncate string based on # of characters
--	(Most useful when having to truncate a string *in* a tooltip.
-- ===========================================================================
function TruncateStringByLength( textString, textLen )
	if ( string.len(textString) > textLen ) then
		return Locale.Substring(textString, 1, textLen, true) .. Locale.ConvertTextKey("TXT_KEY_GENERIC_DOT_DOT_DOT");
	end
	return textString;
end


-- ===========================================================================
-- Convert a set of values (red, green, blue, alpha) into a single hex value.
-- Values are from 0.0 to 1.0
-- return math.floor(value is a single, unsigned uint as ABGR
-- ===========================================================================
function RGBAValuesToABGRHex( red, green, blue, alpha )

	-- optionally pass in alpha, to taste
	if alpha==nil then
		alpha = 1.0;
	end

	-- prepare ingredients so they are clamped from 0 to 255
	red 	= math.max( 0, math.min( 255, red*255 ));
	green 	= math.max( 0, math.min( 255, green*255 ));
	blue	= math.max( 0, math.min( 255, blue*255 ));
	alpha	= math.max( 0, math.min( 255, alpha*255 ));

	-- combine the ingredients, stiring gently
	local value = lshift( alpha, 24 ) + lshift( blue, 16 ) + lshift( green, 8 ) + red;

	-- return the baked goodness
	return math.floor(value);
end

-- ===========================================================================
--	Use to convert from CivBE style colors to ForgeUI color
-- ===========================================================================
function RGBAObjectToABGRHex( colorObject )
	return RGBAValuesToABGRHex( colorObject.x, colorObject.y, colorObject.z, colorObject.w );
end

-- ===========================================================================
--	Guess what, TextControls still use legacy color; use to convert to it.
--	RETURNS: Object with R G B A to a vector like format with fields X Y Z W 
-- 
--	??TRON: MOD isn't sufficient as higher bits change the value.  
-- ===========================================================================
function Broken_ABGRHExToRGBAObject( hexColor )
	local ret = {};
	ret.w = math.floor( math.fmod( rshift(hexColor,24), 256)); 
	ret.z = math.floor( math.fmod( rshift(hexColor,16), 256));
	ret.y = math.floor( math.fmod( rshift(hexColor,8), 256));
	ret.x = math.floor( math.fmod( hexColor, 0x256 ));	-- lower MODs are messed up due what is in higher bits, need an AND!
	return ret;
end



-- ===========================================================================
-- Support for shifts
-- ===========================================================================
local g_supportFunctions_shiftTable = {};
g_supportFunctions_shiftTable[0] = 1;
g_supportFunctions_shiftTable[1] = 2;
g_supportFunctions_shiftTable[2] = 4;
g_supportFunctions_shiftTable[3] = 8;
g_supportFunctions_shiftTable[4] = 16;
g_supportFunctions_shiftTable[5] = 32;
g_supportFunctions_shiftTable[6] = 64;
g_supportFunctions_shiftTable[7] = 128;
g_supportFunctions_shiftTable[8] = 256;
g_supportFunctions_shiftTable[9] = 512;
g_supportFunctions_shiftTable[10] = 1024;
g_supportFunctions_shiftTable[11] = 2048;
g_supportFunctions_shiftTable[12] = 4096;
g_supportFunctions_shiftTable[13] = 8192;
g_supportFunctions_shiftTable[14] = 16384;
g_supportFunctions_shiftTable[15] = 32768;
g_supportFunctions_shiftTable[16] = 65536;
g_supportFunctions_shiftTable[17] = 131072;
g_supportFunctions_shiftTable[18] = 262144;
g_supportFunctions_shiftTable[19] = 524288;
g_supportFunctions_shiftTable[20] = 1048576;
g_supportFunctions_shiftTable[21] = 2097152;
g_supportFunctions_shiftTable[22] = 4194304;
g_supportFunctions_shiftTable[23] = 8388608;
g_supportFunctions_shiftTable[24] = 16777216;

-- ===========================================================================
-- Left shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function lshift( value, shift )
	return math.floor(value) * g_supportFunctions_shiftTable[shift];
end

-- ===========================================================================
-- Right shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function rshift( value, shift )
	return math.floor(value) / g_supportFunctions_shiftTable[shift];
end



-- ===========================================================================
--	Determine if string is IP4, IP6, or invalid
--
--	Based off of: 
--	http://stackoverflow.com/questions/10975935/lua-function-check-if-ipv4-or-ipv6-or-string
--
--	Returns: 4 if IP4, 6 if IP6, or 0 if not valid
-- ===========================================================================
function GetIPType( ip )

    if ip == nil or type(ip) ~= "string" then
        return 0;
    end

    -- Check for IPv4 format, 4 chunks between 0 and 255 (e.g., 1.11.111.111)
    local chunks = {ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
    if (#chunks == 4) then
        for _,v in pairs(chunks) do
            if (tonumber(v) < 0 or tonumber(v) > 255) then
                return 0;
            end
        end
        return 4;	-- This is IP4
    end

	-- Check for ipv6 format, should be 8 'chunks' of numbers/letters without trailing chars
	local chunks = {ip:match(("([a-fA-F0-9]*):"):rep(8):gsub(":$","$"))}
	if #chunks == 8 then
		for _,v in pairs(chunks) do
			if #v > 0 and tonumber(v, 16) > 65535 then 
				return 0;
			end
		end
		return 6;	-- This is IP6
	end

	return 0;
end