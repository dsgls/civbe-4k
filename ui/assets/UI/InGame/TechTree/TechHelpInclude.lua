-------------------------------------------------
-- Help text for techs
-------------------------------------------------

local NOT_IMPLEMENTED_TAG = "[COLOR_WARNING_TEXT]Not Implemented[ENDCOLOR]";

-- ===========================================================================
--	iTechID,				ID of the technology to build the string for
--	forcedProgressAmount,	(optional) a value to use to show for progress
--							rather than what the system reports.  This allows
--							for reporting 0 on non-queued items when there has
--							been carry-over from the just recently completed
--							previous tech.
-- ===========================================================================
function GetHelpTextForTech( iTechID, forcedProgressAmount )
	local pTechInfo		= GameInfo.Technologies[iTechID];	
	local pActiveTeam	= Teams[Game.GetActiveTeam()];
	local pActivePlayer = Players[Game.GetActivePlayer()];
	local pTeamTechs	= pActiveTeam:GetTeamTechs();
	local iTechCost		= pActivePlayer:GetResearchCost(iTechID);
	
	local strHelpText = "";

	-- Name
	strHelpText = strHelpText .. Locale.ToUpper(Locale.ConvertTextKey( pTechInfo.Description ));

	-- Progress
	strHelpText = strHelpText .. "[NEWLINE]";
	if (pTeamTechs:HasTech(iTechID)) then
		strHelpText = strHelpText .. "[COLOR_POSITIVE_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_RESEARCHED") .. "[ENDCOLOR]";
	else
		local iProgress = pActivePlayer:GetResearchProgress(iTechID);	
		if ( forcedProgressAmount ~= nil ) then
			iProgress = forcedProgressAmount;
		end
		strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_TECH_HELP_COST_WITH_PROGRESS", iProgress, iTechCost);
	end

	-- Affinities
	local techAffinityInfo;
	for techAffinityInfo in GameInfo.Technology_Affinities()  do
		if (GameInfo.Technologies[techAffinityInfo.TechType].ID == iTechID) then
			local pAffinityInfo = GameInfo.Affinity_Types[techAffinityInfo.AffinityType];
			local iAffinityScore = pActivePlayer:GetAffinityScoreFromTech(pAffinityInfo.ID, iTechID);
			strHelpText = strHelpText .. "[NEWLINE]";
			strHelpText = strHelpText .. Locale.ConvertTextKey("TXT_KEY_TECH_HELP_AFFINITY_SCORE", iAffinityScore, pAffinityInfo.IconString, pAffinityInfo.Description);
		end
	end

	-- Pre-written help text
	strHelpText = strHelpText .. "[NEWLINE][NEWLINE]";
	strHelpText = strHelpText .. Locale.ConvertTextKey( pTechInfo.Help );
	
	return strHelpText;
end