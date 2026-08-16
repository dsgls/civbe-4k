-- ===========================================================================
--	Functionality that should be evaluated to be moved directly into ForgeUI
-- ===========================================================================

AFFINITY = {};
AFFINITY.purity					= 1;
AFFINITY.supremacy				= 2;
AFFINITY.harmony				= 3;
AFFINITY.supremacypurity		= 4;
AFFINITY.harmonysupremacy		= 5;
AFFINITY.purityharmony			= 6;
AFFINITY.harmonypuritysupremacy	= 7;


-- ===========================================================================
function GetAffinityEnum( purity:number, harmony:number, supremacy:number )	
	if		purity>0 and	harmony>0	and	supremacy>0	then return AFFINITY.harmonypuritysupremacy; 
	elseif	purity>0 and	harmony>0					then return AFFINITY.purityharmony; 
	elseif	purity>0 and 					supremacy>0 then return AFFINITY.supremacypurity; 
	elseif					harmony>0	and	supremacy>0 then return AFFINITY.harmonysupremacy;
	elseif	purity>0									then return AFFINITY.purity; 
	elseif					harmony>0					then return AFFINITY.harmony;
	elseif									supremacy>0 then return AFFINITY.supremacy;
	else													 return 0;
	end
end

-- ===========================================================================
function GetAffinityTextIcon( affinityEnum:number )
	if affinityEnum == AFFINITY.purity				then return "[ICON_PURITY]"; end
	if affinityEnum == AFFINITY.supremacy			then return "[ICON_SUPREMACY]"; end
	if affinityEnum == AFFINITY.harmony				then return "[ICON_HARMONY]"; end
	if affinityEnum == AFFINITY.supremacypurity		then return "[ICON_SUPREMACY_PURITY]"; end 
	if affinityEnum == AFFINITY.harmonysupremacy	then return "[ICON_HARMONY_SUPREMACY]"; end 
	if affinityEnum == AFFINITY.purityharmony		then return "[ICON_PURITY_HARMONY]"; end 
	return "";
end

-- ===========================================================================
--	Color set should be definied in ColorAtlas.xml
function GetAffinityColorSet( affinityEnum:number )
	if affinityEnum == AFFINITY.purity				then return "AffinityPuritySet"; end
	if affinityEnum == AFFINITY.supremacy			then return "AffinitySupremacySet"; end
	if affinityEnum == AFFINITY.harmony				then return "AffinityHarmonySet"; end
	if affinityEnum == AFFINITY.supremacypurity		then return "AffinitySupremacyPuritySet"; end 
	if affinityEnum == AFFINITY.harmonysupremacy	then return "AffinityHarmonySupremacySet"; end 
	if affinityEnum == AFFINITY.purityharmony		then return "AffinityPurityHarmonySet"; end 
	return nil;
end

-- ===========================================================================
function IsHybridAffinity( affinityEnum:number )
	if affinityEnum == AFFINITY.supremacypurity		then return true; end
	if affinityEnum == AFFINITY.harmonysupremacy	then return true; end
	if affinityEnum == AFFINITY.purityharmony		then return true; end
	return false;
end

-- ===========================================================================
--	Return the first of two affinities in a hybrid affinity.
--	(For non-hybrid affinities, will just return same affinity enum.)
function GetHybridAffinity1( affinityEnum:number )
	if affinityEnum == AFFINITY.supremacypurity		then return AFFINITY.supremacy; end
	if affinityEnum == AFFINITY.harmonysupremacy	then return AFFINITY.harmony; end
	if affinityEnum == AFFINITY.purityharmony		then return AFFINITY.purity; end
	return affinityEnum;
end

-- ===========================================================================
--	Return the second of two affinities in a hybrid affinity.
--	(For non-hybrid affinities, will just return same affinity enum.)
function GetHybridAffinity2( affinityEnum:number )
	if affinityEnum == AFFINITY.supremacypurity		then return AFFINITY.purity; end
	if affinityEnum == AFFINITY.harmonysupremacy	then return AFFINITY.supremacy; end
	if affinityEnum == AFFINITY.purityharmony		then return AFFINITY.harmony; end
	return affinityEnum;
end

-- ===========================================================================
--	Return a string that represents the amount of progress the player has
--	before obtaining the next affinity level.
--	player,			Player to look up
--	affinityEnum
--	isShowIcon		(optional) show an icon of the affinity after the ratio
-- ===========================================================================
function GetAffinityStatusProgressString( player:table, affinityEnum:number, isShowIcon:boolean  )

	-- Hybrid?  Recurse on each part.
	if IsHybridAffinity( affinityEnum ) then
		return
			GetAffinityStatusProgressString( player, GetHybridAffinity1(affinityEnum),isShowIcon ) 
			.." ".. 
			Locale.ConvertTextKey("TXT_KEY_AND") 
			.." " .. 
			GetAffinityStatusProgressString( player, GetHybridAffinity2(affinityEnum), isShowIcon );
	else
		local	affinityInfo:table = nil;
		if		affinityEnum == AFFINITY.purity		then affinityInfo = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"];
		elseif	affinityEnum == AFFINITY.supremacy	then affinityInfo = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"];
		elseif	affinityEnum == AFFINITY.harmony	then affinityInfo = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"];
		end

		return Locale.ConvertTextKey(
			"TXT_KEY_AFFINITY_RATIO", 
			player:GetAffinityScoreTowardsNextLevel(affinityInfo.ID), 
			player:CalculateAffinityScoreNeededForNextLevel(affinityInfo.ID))..
			(isShowIcon and Locale.Lookup(GetAffinityTextIcon(affinityEnum)) or "" );
	end
end