-------------------------------------------------
-- Choose Affinity Popup
-------------------------------------------------
include("IconSupport");
include("InfoTooltipInclude");

-- This global table handles how items are populated based on an identifier.
g_NumberOfFreeItems = 0;
local m_PopupInfo = nil;
local pPlayer = nil;
PopulateItems = {};
CommitItems = {};
SelectedItems = {};

PopulateItems["FreeAffinityLevels"] = function(stackControl, playerID)
	
	local count = 0;
	Controls.TitleLabel:LocalizeAndSetText("TXT_KEY_CHOOSE_FREE_AFFINITY_LEVEL_TITLE");
	Controls.DescriptionLabel:LocalizeAndSetText("TXT_KEY_CHOOSE_FREE_AFFINITY_LEVEL_DESCRIPTION");
	SelectedItems = {};
	stackControl:DestroyAllChildren();
	
	local iIndex = 0;
	
	for info in GameInfo.Affinity_Types() do	
		local iAffinityType = iIndex;
			
		local controlTable = {};
		ContextPtr:BuildInstanceForControl( "ItemInstance", controlTable, stackControl );

		local name = info.IconString .. " " .. Locale.ConvertTextKey(info.Description);
		local details = GetHelpTextForAffinity(iAffinityType, Players[playerID]);

		local isMaxLevel = Players[playerID]:GetAffinityPercentTowardsMaxLevel(iAffinityType) >= 100;
		if (isMaxLevel) then
			name = "[COLOR_GREY]" .. name .. "[ENDCOLOR]";
		end

		controlTable.Name:SetText(name);
		controlTable.Name:SetToolTipString(details);
		controlTable.Button:SetToolTipString(details);
		local selectionAnim = controlTable.SelectionAnim;
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()  
			local foundIndex = nil;
			for i,v in ipairs(SelectedItems) do
				if(v[1] == iAffinityType) then
					foundIndex = i;
					break;
				end
			end
			
			if(foundIndex ~= nil) then
				if(g_NumberOfFreeItems > 1) then
					selectionAnim:SetHide(true);
					table.remove(SelectedItems, foundIndex);
				end
			else
				if(g_NumberOfFreeItems > 1) then
					if(#SelectedItems < g_NumberOfFreeItems) then
						selectionAnim:SetHide(false);
						table.insert(SelectedItems, {iAffinityType, controlTable});
					end
				else
					if(#SelectedItems > 0) then
						for i,v in ipairs(SelectedItems) do
							v[2].SelectionAnim:SetHide(true);	
						end
						SelectedItems = {};
					end
					
					selectionAnim:SetHide(false);
					table.insert(SelectedItems, {iAffinityType, controlTable});
				end	
			end
			
			Controls.ConfirmButton:SetDisabled(g_NumberOfFreeItems ~= #SelectedItems);
			
		end);

		count = count + 1;
		iIndex = iIndex + 1;
	end
	
	return count;
end

CommitItems["FreeAffinityLevels"] = function(selection, playerID)
	
	local activePlayer = Players[playerID];
	if(activePlayer ~= nil) then
		for i,v in ipairs(selection) do
			local iAffinityType = v[1];
			Network.SendChooseFreeAffinityLevel(playerID, iAffinityType);
		end
	end
end
 
function DisplayPopup(playerID, classType, numberOfFreeItems)
	
	if(numberOfFreeItems ~= 1) then
		error("This UI currently only supports 1 free item for the time being.");
	end
	
	local count = PopulateItems[classType](Controls.ItemStack, playerID);
	
	Controls.ItemStack:CalculateSize();
	Controls.ItemStack:ReprocessAnchoring();
	Controls.ItemScrollPanel:CalculateInternalSize();
	
	if(count > 0 and numberOfFreeItems > 0) then
		g_NumberOfFreeItems = math.min(numberOfFreeItems, count);
		Controls.ConfirmButton:SetDisabled(true);
		ContextPtr:SetHide(false);
	else
		ContextPtr:SetHide(true);
	end 
	
	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, function()
		CommitItems[classType](SelectedItems, playerID);
		ContextPtr:SetHide(true);
	end);
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnPopup( popupInfo )	
    if( popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_CHOOSE_AFFINITY and ContextPtr:IsHidden() == true ) then    
        m_PopupInfo = popupInfo;
        pPlayer = Players[popupInfo.Data1];
        
        DisplayPopup(m_PopupInfo.Data1, "FreeAffinityLevels", 1);
    end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );
  

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

    if( not bInitState ) then
        if( not bIsHide ) then
        	UI.incTurnTimerSemaphore();
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo);
        else
            UI.decTurnTimerSemaphore();
            Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_CHOOSE_AFFINITY, 0);
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------------------------------------
-- 'Active' (local human) player has changed
-------------------------------------------------------------------------------
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		ContextPtr:SetHide(true);
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);


-------------------------------------------------------------------------------
-----------------------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if not ContextPtr:IsHidden() and uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			ContextPtr:SetHide(true);
			return true;
		end
	end
end
ContextPtr:SetInputHandler( InputHandler );