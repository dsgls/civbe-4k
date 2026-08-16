--------------------------------------
-- CommonBehaviors.lua
-- Contains helpers for implementing many common user interface behaviors
-- Behaviors include:
-- * Tab Pages
-- * Sorting
--------------------------------------

--------------------------------------------------------------------------
-- TABBING
--
-- To quickly support tabbing, simply call RegisterTabBehavior at the end
-- of your Lua script.
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- RegisterTabBehavior
-- Description: Registers the tab behavior with a set of controls
-- Params:
--	@tabs - A table or array representing the tab data. (See example)
--  @defaultTab - (Optional) The initial entry to select.
--  @onBeforeTabSelectFunction - (Optional) A method to call before any tab has been selected.
--	@onAfterTabSelectFunction - (Optional) A method to call after any tab has been selected.
-- Example:
--	tabs = {
--		["SocialPolicies"] = {
--			Button = Controls.TabButtonSocialPolicies,
--			Panel = Controls.SocialPolicyPane,
--			SelectHighlight = Controls.TabButtonSocialPolicies,
--			OnDeselect = nil,
--			OnSelect = RefreshSocialPolicies,
--		},
--	
--		["Ideologies"] = {
--			Button = Controls.TabButtonIdeologies,
--			Panel = Controls.IdeologyPane,
--			SelectHighlight = Controls.TabButtonIdeologiesHL,
--			OnDeselect = nil,
--			OnSelect = RefreshIdeologies,
--		},
--	};
--	SelectTab = RegisterTabBehavior(tabs, tabs["SocialPolicies"], OnAnyTabSelect);
--	-- NOTE: SelectTab is now a global method which can be used to explicitly select a tab.
--------------------------------------------------------------------------
function RegisterTabBehavior(tabs, defaultTab, onBeforeTabSelectFunction, onAfterTabSelectFunction)
	
	-- Register global 
	g_CurrentTab = nil;
	
	function TabSelect(tab)	
		if(tab ~= g_CurrentTab) then
			if(onBeforeTabSelectFunction ~= nil) then
				onBeforeTabSelectFunction(g_CurrentTab, tab);
			end
			
			if(g_CurrentTab ~= nil and g_CurrentTab.OnDeselect ~= nil) then
				g_CurrentTab.OnDeselect();
			end
			
			for _,v in pairs(tabs) do
				local bHide = v ~= tab;
				v.Panel:SetHide(bHide);
				v.SelectHighlight:SetHide(bHide);
			end
			g_CurrentTab = tab;	
			
			if(tab.OnSelect ~= nil) then
				tab.OnSelect();
			end
			
			if(onAfterTabSelectFunction ~= nil) then
				onAfterTabSelectFunction(tab);
			end
		end
	end
	
	for _,v in pairs(tabs) do
		v.Button:RegisterCallback(Mouse.eLclick, function() TabSelect(v) end);
	end
	
	if(defaultTab ~= nil) then
		TabSelect(defaultTab);
	end

	return TabSelect;
end



----------------------------------------------------------------------------------------
---- ZoomOut Animation Effect
----------------------------------------------------------------------------------------
function ZoomOutEffect(data)
	
	local originalSizeX, originalSizeY = data.SplashControl:GetSizeVal();
	
	data.SplashControl:SetSizeVal( originalSizeX * (1 + data.ScaleFactor), originalSizeY * (1 + data.ScaleFactor) );
    	  
    local state = {
		Percent = 0;
    };
   
    local function OnUpdate( fDTime )
		state.Percent = state.Percent + (fDTime / data.AnimSeconds);
		
		if( state.Percent >= 1 ) then
			data.SplashControl:SetSizeVal( originalSizeX, originalSizeY );
    		return true;
		else
			local fScale = 1 + ((1 - state.Percent) * (1 - state.Percent) * data.ScaleFactor);
    		data.SplashControl:SetSizeVal( originalSizeX * fScale, originalSizeY * fScale );
    		return false;
		end
	end
	
	 OnUpdate(0);
	 
	 return OnUpdate;
end


----------------------------------------------------------------------------------------
---- Collapseable Panels
-- Example Usage:
-- RegisterCollapseBehavior{	
--		Header = Controls.ActiveResolutionsHeader2, 
--		HeaderLabel = Controls.ActiveResolutionsHeaderLabel2, 
--		HeaderExpandedLabel = "[ICON_MINUS] " .. activeResolutionsText,
--		HeaderCollapsedLabel = "[ICON_PLUS] " .. activeResolutionsText,
--		Panel = Controls.ActiveResolutionStack2,
--		Collapsed = false,
-- };
----------------------------------------------------------------------------------------
function RegisterCollapseBehavior(data)
	local Expand = function()
		data.HeaderLabel:SetText(data.HeaderExpandedLabel);
		data.Panel:SetHide(false);
		if(data.OnExpand) then
			data.OnExpand();
		end
	end
	
	local Collapse = function()
		data.HeaderLabel:SetText(data.HeaderCollapsedLabel);
		data.Panel:SetHide(true);
		if(data.OnCollapse) then
			data.OnCollapse();
		end
	end
	
	data.Header:RegisterCallback(Mouse.eLClick, function() 
		if(data.Panel:IsHidden()) then
			Expand();
		else
			Collapse();
		end
	end);
	
	if(data.Collapsed == true) then
		Collapse();
	else
		Expand();
	end
end