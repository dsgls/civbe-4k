local g_BonusTips = 
{
	[YieldTypes.YIELD_FOOD] = "TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_FOOD",	
	[YieldTypes.YIELD_PRODUCTION] ="TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_PRODUCTION",
	[YieldTypes.YIELD_ENERGY] ="TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_GOLD",
	[YieldTypes.YIELD_SCIENCE] ="TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_SCIENCE",
	[YieldTypes.YIELD_CULTURE] = "TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_CULTURE",
	[YieldTypes.YIELD_FAITH] = 	"TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_FAITH",
};

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function BuildTradeRouteGoldToolTipString (pOriginCity, pTargetCity, eDomain)

	local iPlayer = pOriginCity:GetOwner();
	local pPlayer = Players[iPlayer];
	local iOtherPlayer = pTargetCity:GetOwner();
	local pOtherPlayer = Players[iOtherPlayer];
	local strOtherLeaderName;
	if(pOtherPlayer:GetNickName() ~= "" and Game:IsNetworkMultiPlayer()) then		
		local MAX_NAME_CHARS= 20;
		strOtherLeaderName	= TruncateStringByLength( pOtherPlayer:GetNickName(), MAX_NAME_CHARS);
	else
		strOtherLeaderName = pOtherPlayer:GetName();
	end

	local strResult = "";

	-- DEPRECATED
	--local strBaseValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_BASE", pPlayer:GetInternationalTradeRouteBaseBonus(pOriginCity, pTargetCity, true) / 100);
	--local strYourGPTValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_GPT_YOURS", pOriginCity:GetNameKey(), pPlayer:GetInternationalTradeRouteGPTBonus(pOriginCity, pTargetCity, true) / 100);
	--local strTheirGPTValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_GPT_YOURS", pTargetCity:GetNameKey(), pPlayer:GetInternationalTradeRouteGPTBonus(pOriginCity, pTargetCity, false) / 100);

	-- DEPRECATED
	local strPolicyValue = "";
	--local iPolicyBonus = pPlayer:GetInternationalTradeRoutePolicyBonus(pOriginCity, pTargetCity, eDomain);	
	--if (iPolicyBonus ~= 0) then
		--strPolicyValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_POLICIES", iPolicyBonus / 100);
	--end

	local iYourBuildingBonus = pPlayer:GetInternationalTradeRouteYourBuildingBonus(pOriginCity, pTargetCity, eDomain, true);
	local strYourBuildingValue = "";
	if (iYourBuildingBonus ~= 0) then
		strYourBuildingValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_BUILDING", pOriginCity:GetNameKey(), iYourBuildingBonus / 100);
	end
	
	local iTheirBuildingBonus = pPlayer:GetInternationalTradeRouteTheirBuildingBonus(pOriginCity, pTargetCity, eDomain, true);
	local strTheirBuildingValue = "";
	if (iTheirBuildingBonus ~= 0) then
		strTheirBuildingValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_BUILDING", pTargetCity:GetNameKey(), iTheirBuildingBonus / 100);
	end
	
	-- DEPRECATED
	local strResourceList = "";
	--local strResourceHeader = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_RESOURCE_HEADER");
	--strResourceHeader = strResourceHeader .. "[NEWLINE]";
	--
	--for pResource in GameInfo.Resources() do
		--local iResourceLoop = pResource.ID;
		--local iUsage = Game.GetResourceUsageType(iResourceLoop);
		--if (iUsage == ResourceUsageTypes.RESOURCEUSAGE_LUXURY or iUsage == ResourceUsageTypes.RESOURCEUSAGE_STRATEGIC) then
			--if (pOriginCity:IsHasResourceLocal(iResourceLoop) ~= pTargetCity:IsHasResourceLocal(iResourceLoop)) then
				--local iGoldFromResource = 50.0;
				--iGoldFromResource = (iGoldFromResource) * (100 + pPlayer:GetInternationalTradeRouteResourceTraitModifier());
				--iGoldFromResource = (iGoldFromResource) / 100;
				--strResourceList = strResourceList .. Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_RESOURCE_DIFFERENT", pResource.IconString, pResource.Description, iGoldFromResource / 100);
				--strResourceList = strResourceList .. "[NEWLINE]";
			--end
		--end
	--end

	-- DEPRECATED
	local strExclusiveValue = "";
	--local iExclusiveBonus = pPlayer:GetInternationalTradeRouteExclusiveBonus(pOriginCity, pTargetCity);
	--if (iExclusiveBonus ~= 0) then
		--strExclusiveValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_EXCLUSIVE_CONNECTION", iExclusiveBonus / 100);
	--end

	local strOtherTraitValue = "";
	local iOtherTraitBonus = pPlayer:GetInternationalTradeRouteOtherTraitBonus(pOriginCity, pTargetCity, eDomain, true);
	if (iOtherTraitBonus ~= 0) then
		strOtherTraitValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_OTHER_TRAIT", pOtherPlayer:GetCivilizationAdjectiveKey(), iOtherTraitBonus / 100);
	end

	-- DEPRECATED
	local strRiverModifier = "";	
	--local iRiverModifier = pPlayer:GetInternationalTradeRouteRiverModifier(pOriginCity, pTargetCity, eDomain, true);
	--if (iRiverModifier ~= 0) then
		--strRiverModifier = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_RIVER_MODIFIER", iRiverModifier);
	--end

	local strDomainModifier = "";
	local iDomainModifier = pPlayer:GetInternationalTradeRouteDomainModifier(eDomain);
	if (iDomainModifier ~= 0) then
		if (eDomain == DomainTypes.DOMAIN_SEA) then
			strDomainModifier = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_DOMAIN_SEA_MODIFIER", (iDomainModifier + 100) / 100);
		end
	end

	local strTotal = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_TOTAL", pPlayer:GetInternationalTradeRouteTotal(pOriginCity, pTargetCity, eDomain, true) / 100);
	
	local strOtherTotal = "";
	local iTradeeAmount = pOtherPlayer:GetInternationalTradeRouteTotal(pOriginCity, pTargetCity, eDomain, false);
	if (iTradeeAmount ~= 0) then
		local strOtherRevenueHeader;
		if (iPlayer == Game.GetActivePlayer()) then
			strOtherRevenueHeader = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_THEIR_REVENUE");
		else
			strOtherRevenueHeader = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_YOUR_REVENUE");
		end
		 
		strOtherTotal = strOtherTotal .. strOtherRevenueHeader;
		strOtherTotal = strOtherTotal .. "[NEWLINE]";
		
		-- DEPRECATED
		--local iOtherBase = pOtherPlayer:GetInternationalTradeRouteBaseBonus(pOriginCity, pTargetCity, false);
		--if (iOtherBase ~= 0) then
			--strOtherTotal = strOtherTotal .. Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_BASE", iOtherBase / 100);
			--strOtherTotal = strOtherTotal .. "[NEWLINE]";
		--end
		
		-- DEPRECATED
		--local iRiverModifier = pPlayer:GetInternationalTradeRouteRiverModifier(pOriginCity, pTargetCity, eDomain, false);
		--if (iRiverModifier ~= 0) then
			--strOtherTotal = strOtherTotal .. Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_RIVER_MODIFIER", iRiverModifier);
			--strOtherTotal = strOtherTotal .. "[NEWLINE]";
		--end
		
		if (strDomainModifier ~= "") then
			strOtherTotal = strOtherTotal .. strDomainModifier;
			strOtherTotal = strOtherTotal .. "[NEWLINE]";
		end
		
		local iOtherBuildingBonus = pOtherPlayer:GetInternationalTradeRouteTheirBuildingBonus(pOriginCity, pTargetCity, eDomain, false);
		if (iOtherBuildingBonus ~= 0) then
			strOtherTotal = strOtherTotal .. Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_BUILDING", pTargetCity:GetNameKey(), iOtherBuildingBonus / 100);
			strOtherTotal = strOtherTotal .. "[NEWLINE]";
		end
		
		strOtherTotal = strOtherTotal .. Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_TRADEE_TOTAL", strOtherLeaderName, iTradeeAmount / 100);
	end
	
	if (iPlayer ~= Game.GetActivePlayer()) then
		strResult = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_THEIR_REVENUE");
	else
		strResult = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_YOUR_REVENUE");
	end

	-- DEPRECATED
	strResult = strResult .. "[NEWLINE]";
	--strResult = strResult .. strBaseValue;
	--strResult = strResult .. "[NEWLINE]";
	--strResult = strResult .. strYourGPTValue;
	--strResult = strResult .. "[NEWLINE]";
	--strResult = strResult .. strTheirGPTValue;
	--strResult = strResult .. "[NEWLINE]";

	if (strPolicyValue ~= "") then
		strResult = strResult .. strPolicyValue;
		strResult = strResult .. "[NEWLINE]";
	end
	
	if (strYourBuildingValue ~= "") then
		strResult = strResult .. strYourBuildingValue;
		strResult = strResult .. "[NEWLINE]";
	end

	if (strTheirBuildingValue ~= "") then
		strResult = strResult .. strTheirBuildingValue;
		strResult = strResult .. "[NEWLINE]";
	end
	
	if (strResourceList ~= "") then
		strResult = strResult .. strResourceHeader;
		strResult = strResult .. strResourceList;
	end
	
	if (strExclusiveBonus ~= "") then
		strResult = strResult .. strExclusiveValue;	
	end
	
	if (strOtherTraitValue ~= "") then
		strResult = strResult .. strOtherTraitValue;
		strResult = strResult .. "[NEWLINE]";
	end
	
	if (strRiverModifier ~= "") then
		strResult = strResult .. strRiverModifier;
	end
	
	if (strDomainModifier ~= "") then
		strResult = strResult .. strDomainModifier;
	end
	strResult = strResult .. "[NEWLINE]";
	strResult = strResult .. strTotal;
	strResult = strResult .. "[NEWLINE]";
	
	if (strOtherTotal ~= "") then
		strResult = strResult .. "[NEWLINE]";
		strResult = strResult .. strOtherTotal;
	end
	
	return strResult;
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function GetYieldTradeRouteTip (yieldType)
	return g_BonusTips[yieldType];
end