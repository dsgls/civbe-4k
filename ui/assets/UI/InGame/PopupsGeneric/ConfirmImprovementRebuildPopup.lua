
-- CONFIRM IMPROVEMENT REBUILD POPUP
-- This popup occurs when the player is trying to construct an Improvement over the top of another one.
PopupLayouts[ButtonPopupTypes.BUTTONPOPUP_CONFIRM_IMPROVEMENT_BUILD] = function(popupInfo)

	local iActivePlayer	= Game.GetActivePlayer();
	local iAction		= popupInfo.Data1;
	local iBuild		= popupInfo.Data2;
	local iPlotIndex	= popupInfo.Data3;
	local bAlt		= popupInfo.Option1;

	local pAction = GameInfoActions[iAction];
	local pBuild = GameInfo.Builds[iBuild];

	local pPlot = Map.GetPlotByIndex(iPlotIndex);
	local ePlotImprovement = pPlot:GetImprovementType();
	local ePlotResource = pPlot:GetResourceType();

	local bDestroysImprovement = false;
	local bDestroysResource = false;
	
	local eFailQuestForActivePlayer = -1;
	local bFailsAnyQuestForOtherPlayer = false;
	
	local bArtifactResourceOnPlot = false;
	local bQuestArtifactResourceOnPlot = false;
	if (ePlotResource ~= -1) then
		local pResourceInfo = GameInfo.Resources[ePlotResource];
		if (pResourceInfo ~= nil) then
			local eResourceClass = GameInfo.ResourceClasses[pResourceInfo.ResourceClassType].ID;
			if (eResourceClass == GameDefines["ARTIFACT_RESOURCECLASS"]) then
				bArtifactResourceOnPlot = true;
			elseif (eResourceClass == GameDefines["QUEST_ARTIFACT_RESOURCECLASS"]) then
				bQuestArtifactResourceOnPlot = true;
			end
		end
	end

	if (pBuild ~= nil) then

		if (pPlot ~= nil) then
			local temp = Game.CheckBuildFailsQuestForPlayer(pPlot:GetX(), pPlot:GetY(), iActivePlayer, iBuild, iActivePlayer);
			if (temp ~= -1) then
				eFailQuestForActivePlayer = temp;
			elseif (Game.CheckBuildFailsQuestForAnyPlayer(pPlot:GetX(), pPlot:GetY(), iActivePlayer, iBuild)) then
				bFailsAnyQuestForOtherPlayer = true;
			end
		end

		if pBuild.ImprovementType ~= nil then
			-- Check for removed resources or improvements
			local pNewImprovementInfo = GameInfo.Improvements[pBuild.ImprovementType];
			if (pNewImprovementInfo ~= nil) then
				if (iBuild == GameDefines["BUILD_EXPEDITION"] and (bArtifactResourceOnPlot or bQuestArtifactResourceOnPlot)) then
					-- Removing artifacts is an expedition's purpose
				elseif (pNewImprovementInfo.RemovesArtifactResource and (bArtifactResourceOnPlot or bQuestArtifactResourceOnPlot)) then
					bDestroysImprovement = true;
					bDestroysResource = true;
				elseif (pNewImprovementInfo.RemovesAnyResource and ePlotResource ~= -1) then
					bDestroysImprovement = true;
					bDestroysResource = true;
				end
			end
		end

		-- Terraforming (changing terrain and/or feature) destroys both improvements and resources
		if pBuild.TerrainTypeChange ~= nil or pBuild.FeatureTypeChange ~= nil then
			bDestroysImprovement = true;
			bDestroysResource = true;
		end
	end

	if (pAction.Type == "MISSION_FOUND") then
		if (pPlot ~= nil) then
			local temp = Game.CheckFoundFailsQuestForPlayer(pPlot:GetX(), pPlot:GetY(), iActivePlayer, iActivePlayer);
			if (temp ~= -1) then
				eFailQuestForActivePlayer = temp;
			elseif (Game.CheckFoundFailsQuestForAnyPlayer(pPlot:GetX(), pPlot:GetY(), iActivePlayer)) then
				bFailsAnyQuestForOtherPlayer = true;
			end
		end

		bDestroysResource = true;
	end

	-- Special prompt for actions that fail quests
	if (eFailQuestForActivePlayer ~= -1) then
		local questInfo = GameInfo.Quests[eFailQuestForActivePlayer];
		if (questInfo ~= nil) then
			local questName = Locale.ConvertTextKey(questInfo.Description);
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_QUEST_FAIL_ACTIVE_PLAYER", pAction.TextKey, questName);
		else
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_QUEST_FAIL_OTHER_PLAYER", pAction.TextKey);
		end
		SetPopupText(popupText);
	elseif (bFailsAnyQuestForOtherPlayer) then
		popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_QUEST_FAIL_OTHER_PLAYER", pAction.TextKey);
		SetPopupText(popupText);
	-- Terraform actions check to remove improvements AND resources
	elseif (bDestroysImprovement and bDestroysResource) then
		if (ePlotImprovement ~= -1 and ePlotResource == -1) then
			local pImprovementInfo = GameInfo.Improvements[ePlotImprovement];
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_IMPROVEMENT_REMOVE", pAction.TextKey, pImprovementInfo.Description);
			SetPopupText(popupText);
		elseif (ePlotResource ~= -1 and ePlotImprovement == -1) then
			local pResourceInfo = GameInfo.Resources[ePlotResource];
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_IMPROVEMENT_REMOVE", pAction.TextKey, pResourceInfo.Description);
			SetPopupText(popupText);
		elseif (ePlotImprovement ~= -1 and ePlotResource ~= -1) then
			local pImprovementInfo = GameInfo.Improvements[ePlotImprovement];
			local pResourceInfo = GameInfo.Resources[ePlotResource];
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_IMPROVEMENT_AND_RESOURCE_REMOVE", pAction.TextKey, pResourceInfo.Description, pImprovementInfo.Description);
			SetPopupText(popupText);
		else
			-- Catch all
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_ACTION", pAction.TextKey );
			SetPopupText(popupText);
		end
	elseif (bDestroysImprovement) then -- Non-terraform actions only remove improvements, resources remain		
		if (ePlotImprovement ~= -1) then
			local pImprovementInfo = GameInfo.Improvements[ePlotImprovement];
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_IMPROVEMENT_REMOVE", pAction.TextKey, pImprovementInfo.Description);
			SetPopupText(popupText);
		elseif ( ePlotResource ~= -1 ) then
			local pResourceInfo = GameInfo.Resources[ePlotResource];
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_IMPROVEMENT_REMOVE", pAction.TextKey, pResourceInfo.Description);
			SetPopupText(popupText);
		else
			-- Catch all
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_ACTION", pAction.TextKey );
			SetPopupText(popupText);
		end
	elseif (bDestroysResource) then
		if (ePlotResource ~= -1) then
			local pResourceInfo = GameInfo.Resources[ePlotResource];
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_IMPROVEMENT_REMOVE", pAction.TextKey, pResourceInfo.Description);
			SetPopupText(popupText);
		else
			-- Catch all
			popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_ACTION", pAction.TextKey );
			SetPopupText(popupText);
		end
	else
		-- Catch all
		popupText = Locale.ConvertTextKey("TXT_KEY_POPUP_ARE_YOU_SURE_ACTION", pAction.TextKey );
		SetPopupText(popupText);
	end
		
	-- Initialize 'yes' button.
	local OnYesClicked = function()
		
		-- Confirm action
		local gameMessagePushMission = GameMessageTypes.GAMEMESSAGE_PUSH_MISSION;
		Game.SelectionListGameNetMessage(gameMessagePushMission, pAction.MissionType, pAction.MissionData, -1, 0, bAlt);
	end
	
	local buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_YES");
	AddButton(buttonText, OnYesClicked)
		
	-- Initialize 'no' button.
	local buttonText = Locale.ConvertTextKey("TXT_KEY_POPUP_NO");
	AddButton(buttonText, nil);

end
