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
	
	local strOtherTraitValue = "";
	local iOtherTraitBonus = pPlayer:GetInternationalTradeRouteOtherTraitBonus(pOriginCity, pTargetCity, eDomain, true);
	if (iOtherTraitBonus ~= 0) then
		strOtherTraitValue = Locale.ConvertTextKey("TXT_KEY_CHOOSE_INTERNATIONAL_TRADE_ROUTE_ITEM_TT_OTHER_TRAIT", pOtherPlayer:GetCivilizationAdjectiveKey(), iOtherTraitBonus / 100);
	end

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

	strResult = strResult .. "[NEWLINE]";
	
	if (strYourBuildingValue ~= "") then
		strResult = strResult .. strYourBuildingValue;
		strResult = strResult .. "[NEWLINE]";
	end

	if (strTheirBuildingValue ~= "") then
		strResult = strResult .. strTheirBuildingValue;
		strResult = strResult .. "[NEWLINE]";
	end
	
	if (strOtherTraitValue ~= "") then
		strResult = strResult .. strOtherTraitValue;
		strResult = strResult .. "[NEWLINE]";
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

function GetResourceTradeRouteTip(resourceType : number, rate : number)
	local tipString : string = "";
	local resourceInfo = GameInfo.Resources[resourceType];
	if (resourceInfo ~= nil) then
		tipString = Locale.ConvertTextKey("TXT_KEY_TRADE_ROUTE_TIP_RESOURCE", rate, resourceInfo.IconString, Locale.Lookup(resourceInfo.Description));
	end

	return tipString;
end

-------------------------------------------------------------------------------
-- SORT FUNCTIONS
-------------------------------------------------------------------------------
function IsUnsortableRoute(r : table)
	return r.TradeConnectionType == TradeConnectionTypes.TRADE_CONNECTION_OUTPOST;
end

function SortBySiteName(a, b)
	return Locale.Compare(a.RouteName, b.RouteName) == -1;
end

function SortByCivName(a, b)
	local result = Locale.Compare(a.CivName, b.CivName);
	if(result == 0) then
		return SortBySiteName(a,b);
	else
		return result == -1;
	end
end

function SortByNearest(unit:object, a, b)
	if unit == nil then
		return;
	end

	local pPlot = unit:GetPlot();
	local distA = Map.PlotDistance(pPlot:GetX(), pPlot:GetY(), a.PlotX, a.PlotY);
	local distB = Map.PlotDistance(pPlot:GetX(), pPlot:GetY(), b.PlotX, b.PlotY);
	return distA < distB;
end

function SortByMaxYield(a, b, yieldType)
	if (IsUnsortableRoute(a)) then
		return false;
	elseif (IsUnsortableRoute(b)) then
		return true;
	end

	if(a.Yields ~= nil and b.Yields ~= nil) then
		local yieldTableIndex = yieldType+1;
		local yieldDataA = a.Yields[yieldTableIndex];
		local yieldDataB = b.Yields[yieldTableIndex];
		return yieldDataA.Mine > yieldDataB.Mine;
	end

	return false;
end

function SortByYieldDelta(a, b, yieldType)
	if (IsUnsortableRoute(a)) then
		return false;
	elseif (IsUnsortableRoute(b)) then
		return true;
	end

	if(a.Yields ~= nil and b.Yields~= nil) then
		local yieldTableIndex = yieldType+1;
		local yieldDataA = a.Yields[yieldTableIndex];
		local yieldDataB = b.Yields[yieldTableIndex];
		local yieldDeltaA = yieldDataA.Mine - yieldDataA.Theirs;
		local yieldDeltaB = yieldDataB.Mine - yieldDataB.Theirs;
		return yieldDeltaA > yieldDeltaB;
	end

	return false;
end

function SortByMaxEnergy(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_ENERGY);
end

function SortByEnergyDelta(a, b)
	return SortByYieldDelta(a, b, YieldTypes.YIELD_ENERGY);
end

function SortByMaxScience(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_SCIENCE);
end

function SortByScienceDelta(a, b)
	return SortByYieldDelta(a, b, YieldTypes.YIELD_SCIENCE);
end

function SortByMaxFood(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_FOOD);
end

function SortByMaxProduction(a, b)
	return SortByMaxYield(a, b, YieldTypes.YIELD_PRODUCTION);
end

function SortByMaxResources(a, b)
	if (IsUnsortableRoute(a)) then
		return false;
	elseif (IsUnsortableRoute(b)) then
		return true;
	end

	if(a.Resources ~= nil and b.Resources ~= nil) then
		local aTotal : number = 0;
		local bTotal : number = 0;
		for j,u in ipairs(a.Resources) do
			aTotal = aTotal + u.Mine;
		end
		for j,u in ipairs(b.Resources) do
			bTotal = bTotal + u.Mine;
		end
		return aTotal > bTotal;
	end

	return false;
end

function SortByResourceDelta(a, b)
	if (IsUnsortableRoute(a)) then
		return false;
	elseif (IsUnsortableRoute(b)) then
		return true;
	end

	if(a.Resources ~= nil and b.Resources ~= nil) then
		local aDelta : number = 0;
		local bDelta : number = 0;
		for j,u in ipairs(a.Resources) do
			aDelta = aDelta + (u.Mine - u.Theirs);
		end
		for j,u in ipairs(b.Resources) do
			bDelta = bDelta + (u.Mine - u.Theirs);
		end
		return aDelta > bDelta;
	end

	return false;
end