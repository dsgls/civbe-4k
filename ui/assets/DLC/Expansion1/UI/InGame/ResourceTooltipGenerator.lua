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

function GenerateImprovementToolTip(plot)
    
	local improvementID = plot:GetImprovementType(Game.GetActiveTeam());
    local improvementInfo = GameInfo.Improvements[improvementID];
    if (improvementInfo == nil) then
		return nil;
	end

	-- Only certain improvements have tooltips like this
	if (improvementInfo.Type == "IMPROVEMENT_ALIEN_NEST" or
		improvementInfo.Type == "IMPROVEMENT_ALIEN_NEST_OCEAN")
	then
		-- Name
		local strToolTip = "[COLOR_YELLOW]" .. Locale.ToUpper(Locale.ConvertTextKey(improvementInfo.Description)) .. "[ENDCOLOR]";
		strToolTip = strToolTip .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("TXT_KEY_ALIEN_NEST_PLOT_TOOLTIP");

		return strToolTip;
	elseif(improvementInfo.MinorMarvel == true) then
		-- Name
		local strToolTip = "[COLOR_CYAN]" .. Locale.ToUpper(Locale.ConvertTextKey(improvementInfo.Description)) .. "[ENDCOLOR]";

		-- Append description based on quest state
		local questID : number = GameInfo.Quests["QUEST_MARVEL"].ID;
		if (Players[Game.GetActivePlayer()]:HasPlayerDoneQuestType(questID)) then 
			local marvel : table = GameInfo.Marvels[improvementInfo.MarvelType];
			strToolTip = strToolTip .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_MINOR_MARVEL_QUEST_KNOWN_TT", marvel.QuestName);
		else
			strToolTip = strToolTip .. "[NEWLINE]" .. Locale.Lookup("TXT_KEY_MINOR_MARVEL_QUEST_UNKNOWN_TT");
		end

		return strToolTip;

	end

	return "";
end