-------------------------------------------------
-- Premium Content Menu
-------------------------------------------------
include( "InstanceManager" );

g_InstanceManager = InstanceManager:new( "ListingButtonInstance", "Base", Controls.ListingStack );

g_DLCState = {};
--------------------------------------------------
-- Explicit Event Handlers
--------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )

	if(uiMsg == KeyEvents.KeyDown) then

		if wParam == Keys.VK_ESCAPE then
			OnCancel();
		end
	end

	return true;
end
ContextPtr:SetInputHandler(InputHandler);

function OnCancel()
	UIManager:DequeuePopup(ContextPtr);
end
Controls.BackButton:RegisterCallback(Mouse.eLClick, OnCancel);

function OnOK()

	local packages = {}
	for i, v in ipairs(g_DLCState) do	
		if(v.Active ~= v.InitiallyActive) then
			table.insert(packages, {
				v.ID,
				ContentType.GAMEPLAY,
				v.Active
			});
		end
    end
    
    if(#packages > 0) then
		UIManager:SetUICursor(1);
		ContentManager.SetActive(packages);
		UIManager:SetUICursor(0);
    end
    
    UIManager:DequeuePopup(ContextPtr);
end
Controls.AcceptButton:RegisterCallback(Mouse.eLClick, OnOK);

function RefreshDLC()

	g_InstanceManager:ResetInstances();
		
	g_DLCState = {};
	local packageIDs = ContentManager.GetAllPackageIDs();
	for i, v in ipairs(packageIDs) do	
		
		if(not ContentManager.IsUpgrade(v)) then
		
			local bActive = ContentManager.IsActive(v, ContentType.GAMEPLAY);
			table.insert(g_DLCState, {
				ID = v,
				Description = Locale.Lookup(ContentManager.GetPackageDescription(v)),
				InitiallyActive = bActive,
				Active = bActive
			});			
		end
    end
    
    table.sort(g_DLCState, function(a,b)
		return Locale.Compare(a.Description, b.Description) == -1;
    end);
    
    local bHasExpansion1 :boolean = false;
	local bHasExoPlanets :boolean = false;
        
    for i,v in ipairs(g_DLCState) do
    
		if v.ID == "54D2B257-C591-4045-8F17-A69F033166C7" then
			bHasExpansion1 = true;
	
			Controls.Expansion1Title:SetText(v.Description);
			Controls.EnableExpansion1:SetHide(v.Active);
			Controls.DisableExpansion1:SetHide(not v.Active);
			
			function ToggleExpansion1()
				v.Active = not v.Active;
				Controls.EnableExpansion1:SetHide(v.Active);
				Controls.DisableExpansion1:SetHide(not v.Active);
			end
			
			Controls.EnableExpansion1:RegisterCallback(Mouse.eLClick, ToggleExpansion1);
			Controls.DisableExpansion1:RegisterCallback(Mouse.eLClick, ToggleExpansion1);
			
		elseif v.ID == "3F49DF54-68B6-44D1-A930-A168628FAA59" then
			bHasExoPlanets = true;

			Controls.ExoPlanetsTitle:SetText(v.Description);
			Controls.EnableExoPlanets:SetHide(v.Active);
			Controls.DisableExoPlanets:SetHide(not v.Active);
			
			function ToggleExoPlanets()
				v.Active = not v.Active;
				Controls.EnableExoPlanets:SetHide(v.Active);
				Controls.DisableExoPlanets:SetHide(not v.Active);
			end
			
			Controls.EnableExoPlanets:RegisterCallback(Mouse.eLClick, ToggleExoPlanets);
			Controls.DisableExoPlanets:RegisterCallback(Mouse.eLClick, ToggleExoPlanets);

		else
			local controlTable = g_InstanceManager:GetInstance();
			controlTable.PackageName:SetText(v.Description);
				
			controlTable.EnableDLC:SetHide(v.Active);
			controlTable.DisableDLC:SetHide(not v.Active);
				
			function ToggleDLC()
				v.Active = not v.Active;
				controlTable.EnableDLC:SetHide(v.Active);
				controlTable.DisableDLC:SetHide(not v.Active);
			end
			controlTable.EnableDLC:RegisterCallback(Mouse.eLClick, ToggleDLC);
			controlTable.DisableDLC:RegisterCallback(Mouse.eLClick, ToggleDLC);
		end
    end
    
    Controls.Expansion1Panel:SetHide(not bHasExpansion1);
	Controls.ExoPlanetsPanel:SetHide(not bHasExoPlanets);
        
	Controls.ListingStack:CalculateSize();
	Controls.ListingScrollPanel:CalculateInternalSize();
end


function ShowHideHandler( bIsHide, bIsInit )
    if( not bIsHide ) then
		RefreshDLC();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

RefreshDLC();