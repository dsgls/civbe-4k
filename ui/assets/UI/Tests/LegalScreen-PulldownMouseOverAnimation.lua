local pullDown = Controls.thePullDown;
local instance = {};
pullDown:BuildEntry( "PullDownEntry", instance );
instance.Button:LocalizeAndSetText("1. Foo");

pullDown:BuildEntry( "PullDownEntry", instance );
instance.Button:LocalizeAndSetText("2. Bar");

pullDown:CalculateInternals();

-------------------------------------------------
-------------------------------------------------

Controls.ContinueButton:RegisterCallback(Mouse.eLClick, function()
	UIManager:DequeuePopup(ContextPtr);
end);
