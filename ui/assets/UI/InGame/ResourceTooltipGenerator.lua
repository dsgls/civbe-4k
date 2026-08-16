-------------------------------------------------
-- Resource Tooltip Generator
-------------------------------------------------

function GenerateResourceToolTip(plot)
	-- Resource
    local iResourceID = plot:GetResourceType(Game.GetActiveTeam());
    local pResourceInfo = GameInfo.Resources[iResourceID];
    if (pResourceInfo == nil) then
		return nil;
	end
    
    -- Quantity
    local strQuantity = "";
    if (plot:GetNumResource() > 1) then
		strQuantity = plot:GetNumResource() .. " ";
    end
    
    -- Name
    local strToolTip = "[COLOR_POSITIVE_TEXT]" .. strQuantity .. Locale.ToUpper(Locale.ConvertTextKey(pResourceInfo.Description)) .. "[ENDCOLOR]";
	
	-- Extra Help Text (e.g. for strategic resources)
	if (pResourceInfo.Help) then
		-- Basic tooltips get extra info
		strToolTip = strToolTip .. "[NEWLINE]";
		strToolTip = strToolTip .. Locale.ConvertTextKey(pResourceInfo.Help);
		strToolTip = strToolTip .. "[NEWLINE]";
	end
	
	-- "With Improvement" Resource Text
	local strYieldToolTip = "";
	local condition = "ResourceType = '" .. pResourceInfo.Type .. "'";
	local pYieldInfo;
	local bFirst = true;

	-- Find the yield value of the resource based on its improvement
	for row in GameInfo.Improvement_ResourceType_Yields(condition) do

		local lines = {};

		local pImprovementInfo = GameInfo.Improvements[row.ImprovementType];
		pYieldInfo = GameInfo.Yields[row.YieldType];

		-- Improved Yield
		if row.Yield > 0 then
			local yieldStr = Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD", pYieldInfo.IconString, row.Yield);
			table.insert(lines, yieldStr);
		end
			
		-- Improved Health
		if (pResourceInfo.Health and pResourceInfo.Health ~= 0) then
			local healthStr = Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD", "[ICON_HEALTH]", pResourceInfo.Health);
			table.insert(lines, healthStr);
		end

		-- Something to say? Build the tooltip
		if #lines > 0 then			
			-- Improvement name
			strYieldToolTip = Locale.ConvertTextKey("TXT_KEY_RESOURCE_TOOLTIP_IMPROVED", pImprovementInfo.Description);
			strYieldToolTip = strYieldToolTip .. "[NEWLINE]";

			-- Tip lines
			strYieldToolTip = strYieldToolTip .. table.concat(lines, " ");
		end
	end

	-- Something in the yield tooltip?
	if (strYieldToolTip ~= "") then
		
		--strYieldToolTip = Locale.ConvertTextKey("TXT_KEY_RESOURCE_TOOLTIP_IMPROVED_WORKED") .. "[NEWLINE]" .. strYieldToolTip;
		
		--strToolTip = strToolTip .. "[NEWLINE][NEWLINE]";

		strToolTip = strToolTip .. "[NEWLINE]" .. strYieldToolTip;
	end
	
	return strToolTip;
end
