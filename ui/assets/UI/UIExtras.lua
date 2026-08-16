-- ===========================================================================
--	Functionality that should be evaluated to be moved directly into ForgeUI
-- ===========================================================================



-- ===========================================================================
--	Resize a grid button control based on it's contents.
--
--	gridButtonControl,	The forgeUI gridbutton control to work on.
--	textString,			Text string to put into the grid button control
--	optionalPadding,	The padding (in pixels) to apply to the control
-- ===========================================================================
function SetAutoWidthGridButton( gridButtonControl, textString, optionalPadding )
	if optionalPadding == nil then
		optionalPadding = 0;
	end

	gridButtonControl:SetText(textString);
	local textControl = gridButtonControl:GetTextControl();
	if textControl == nil then
		print("ERROR: Could not set the text '"..textString.."' on the control (which SHOULD be a GridButton).");
		return;
	end
	local sizeX = textControl:GetSizeX();
	sizeX = sizeX + optionalPadding;
	gridButtonControl:SetSizeX( sizeX );
	gridButtonControl:SetText(textString);	-- Set text once more at new size to reposition text. (Alas Reposition anchoring fails; hackz!)
end




-- ===========================================================================
--	Returns true if a scrollbar (should be) shown for the panel.

--	uiScrollPanel,	The forgeUI scrollPanel control to work on.
-- ===========================================================================
function IsScrollbarShowing( uiScrollPanel )
	local ratio = uiScrollPanel:GetRatio();
	return not ( ratio >= 1 or ratio == 0.0 );
end
