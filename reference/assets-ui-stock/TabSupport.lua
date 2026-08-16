-- ===========================================================================
--	Takes a bunch of (Grid)Button controls in a container and gives them
--	tab-like functionality.
--
-- ===========================================================================


-- ===========================================================================
--	tabContainerControl		The container (parent) control for the tabs
--	sizeX					(optional) Size of texture X length
--	sizeY					(optional) Size of texture Y height
--
--	RETURNS: tab object for working with controls in a tabby manner.
-- ===========================================================================
function CreateTabs( tabContainerControl, sizeX, sizeY )
	
	-- Set default options if not passed in.
	if sizeX == nil then sizeX = 64; end;
	if sizeY == nil then sizeY = 32; end;

	local tabs = {};
	tabs.containerControl	= tabContainerControl;
	tabs.tabControls		= {};
	tabs.selectedControl	= nil;		

	-- Set size, used in operation to get the selected state from sprite sheet.
	tabs.textureSizeX = sizeX;
	tabs.textureSizeY = sizeY;


	-- ===========================================================================
	--	(PRIVATE) Sets the visual style of the selected tab.
	-- ===========================================================================
	tabs.SetSelectedTabVisually =
		function ( tabControl )
			if ( tabs.selectedControl ~= nil ) then
				tabs.selectedControl:SetTextureOffsetVal( 0, 0 );
				tabs.selectedControl = nil;
			end
			if ( tabControl ~= nil ) then
				-- HACK: change parent back to container, this will re-add it to the end of the 
				--		 child list, thereby drawing last (on top of other tabs if they overlap).
				tabControl:ChangeParent( tabs.containerControl ); 

				tabControl:SetTextureOffsetVal( 0, tabs.textureSizeY * 2 );
				tabs.selectedControl = tabControl;
			end
		end

	-- ===========================================================================
	-- ===========================================================================
	tabs.SelectTab =
		function ( tabControl )
			-- If NIL select no tabs.
			if ( tabControl == nil ) then
				SetSelectedTabVisually( nil );
			else
				local callback = tabControl["CallbackFunc"];
				if ( callback == nil ) then
					print("ERROR: Cannot manually select a tab because a callback function was never set.");
					return;
				end
				callback();
			end
		end

	-- ===========================================================================
	--	Add a tab control to be managed by tab manager.
	--	tabContainerControl		The group of tabs to add this tab to
	--	tabControl				The tab UI element to be managed.
	--	focusCallback			A callback to call when the tab is focused
	-- ===========================================================================
	tabs.AddTab =	
		function ( tabControl, focusCallBack )

			-- Protect the flock
			if ( focusCallBack == nil ) then
				print("ERROR: NIL focusCallback for tabControl");
			end

			tabControl["CallbackFunc"] = function()
				tabs.SetSelectedTabVisually( tabControl );	-- Our function to change UI appearance
				focusCallBack( tabControl );				-- User's function to do stuff when tab is clicked
				end;

			-- Register callback when tab is click/pressed.
			tabControl:RegisterCallback( Mouse.eLClick, tabControl["CallbackFunc"] );

			table.insert( tabs.tabControls, tabControl );	-- Add to list of controls in tabs.
		end

	-- ===========================================================================
	--	Spreads out the tabs evenly, from end-to-end using maths!
	-- ===========================================================================
	tabs.EvenlySpreadTabs =
		function()			
			local width			= tabs.containerControl:GetSizeX();
			local tabNum		= #tabs.tabControls;

			if ( tabNum < 1 ) then
				print("ERROR: Attempting to evenly spread tabs but no tabs to spread in: ", tabs.containerControl );
				return;
			end

			-- Adjust with to starting X offsets with the last offset being the width of the last tab.
			local lastControl	= tabs.tabControls[tabNum];
			width = width - lastControl:GetSizeX();
			local step = width / (tabNum - 1);

			for i,control in ipairs(tabs.tabControls) do
				control:SetOffsetX( step * (i-1) );
			end
		end

	-- ===========================================================================
	--	Spreads out the tabs within the center of the given area
	-- ===========================================================================
	tabs.CenterAlignTabs =
		function( tabOverlapSpace )			
			local DEFAULT_TAB_OVERLAP_SPACE = 20;
			local width				= tabs.containerControl:GetSizeX();
			local tabNum			= #tabs.tabControls;

			if tabOverlapSpace == nil then
				tabOverlapSpace = DEFAULT_TAB_OVERLAP_SPACE;
			end

			if ( tabNum < 1 ) then
				print("ERROR: Attempting to center align tabs but no tabs to center in: ", tabs.containerControl );
				return;
			end

			-- Determine total width of tabs
			local totalTabsWidth = 0;
			for _,control in ipairs(tabs.tabControls) do				
				totalTabsWidth = totalTabsWidth + control:GetSizeX() - tabOverlapSpace;
			end			

			local nextX	= (width/2) - (totalTabsWidth/2 );

			for i,control in ipairs(tabs.tabControls) do
				control:SetOffsetX( nextX );
				nextX = nextX + control:GetSizeX() - tabOverlapSpace;
			end
		end

	return tabs;

end
