-------------------------------------------------
-- Helper constants and functions for making nice, pretty dressed UI strings without having to type a lot
-------------------------------------------------

NOT_IMPLEMENTED_TAG = " ([COLOR_WARNING_TEXT]Not Implemented[ENDCOLOR]) ";
HEALTH_ICON = "[ICON_HEALTH_1]";
UNHEALTH_ICON = "[ICON_HEALTH_4]";

function GetYieldValueString (eYield, iYieldDelta, bShowSign)
	local yieldInfo = GameInfo.Yields[eYield];

	local resultString = Locale.ConvertTextKey("SIMPLE_NUM_NAMED_YIELD", iYieldDelta, yieldInfo.IconString, yieldInfo.Description)

	if (bShowSign) then
		local signString;
		if (iYieldDelta >= 0) then
			signString = "+";
		elseif (iYieldDelta < 0) then
			signString = "-";
		end

		resultString = signString .. resultString;
	end
	
	return resultString;
end