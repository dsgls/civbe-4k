
function OnClipped( a, b, c )
	--print( "OnClipped occurred: "..tostring(a)..",  "..tostring(b)..",  "..tostring(c) );
	local control = a;
	local amt = 1.0 - c;
	print( "OnClipped : "..tostring( amt ).."  curr: "..tostring(control:GetAlpha()).."    -"..tostring(b));
	control:SetAlpha( amt );
end

Controls.boxa:RegisterWhenClippedCallback( OnClipped );
Controls.boxb:RegisterWhenClippedCallback( OnClipped );
Controls.boxc:RegisterWhenClippedCallback( OnClipped );
Controls.boxd:RegisterWhenClippedCallback( OnClipped );
Controls.boxe:RegisterWhenClippedCallback( 
	function(a,b,c) OnClipped( a, Controls.foo, c ); end	 
);
Controls.boxf:RegisterWhenClippedCallback( OnClipped );
Controls.boxg:RegisterWhenClippedCallback( OnClipped );	


-------------------------------------------------
-------------------------------------------------

Controls.ContinueButton:RegisterCallback(Mouse.eLClick, function()
	UIManager:DequeuePopup(ContextPtr);
end);
