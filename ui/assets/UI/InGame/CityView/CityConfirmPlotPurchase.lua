-- ===========================================================================
--
--	Confirm Purchase A Plot
--	(From a City Screen)
--
-- ===========================================================================

-- ===========================================================================
--	GLOBALS
-- ===========================================================================

local g_plotIndex;
local g_cost;



-- ===========================================================================
--	METHODS
-- ===========================================================================


-- ===========================================================================
-- Input handling 
-- (this may be overkill for now because there is currently only 
-- one InterfaceMode on this display, but if we add some, which we did...)
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )

	if ( uiMsg == 2 and wParam == Keys.VK_ESCAPE ) then
		OnCancelClick();
		return true;
	end
	return false;
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
function OnBuyClick()
	LuaEvents.DoPlotPurchase( g_plotIndex );
	ContextPtr:SetHide( true );	
end
Controls.BuyButton:RegisterCallback( Mouse.eLClick, OnBuyClick );

-- ===========================================================================
function OnCancelClick()
	ContextPtr:SetHide( true );
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancelClick );


-- ===========================================================================
function OnRaiseConfirmPlotPurchase( iPlotIndex, iCost )
	print("received OnRaiseConfirmPlotPurchase", iPlotIndex);

	g_plotIndex = iPlotIndex;
	g_cost = iCost;

	Controls.BuyLabel:SetText( tostring(iCost).." [ICON_ENERGY]" );
	ContextPtr:SetHide( false );
end
LuaEvents.RaiseConfirmPlotPurchase.Add( OnRaiseConfirmPlotPurchase );
