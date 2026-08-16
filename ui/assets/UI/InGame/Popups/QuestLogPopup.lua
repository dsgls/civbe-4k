-- ===========================================================================
--	QuestLogPopup
--	Handles Quests and Victory Conditions
-- ===========================================================================

-- ===========================================================================
--	INCLUDES
-- ===========================================================================
include("TabSupport");
include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("UIExtras");
include("GameplayUtilities");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local FilterType			= { QUEST = 1, VICTORY = 2 };
local COLOR_QUEST_FAILED	= 0xff2211aa;
local COLOR_QUEST_COMPLETE	= 0xff806050;

-- ===========================================================================
--	MEMBERS
-- ===========================================================================

local m_IsInitialized				= false;
local m_ScrollPanelSizeDefault		= 0;
local m_CurrentFilter				= FilterType.QUEST;
local m_QuestExpandedTable			= {};
local m_CurrentExpandedQuestIndex	= -1;
local m_PopupInfo					= nil;
local m_uiMainContentStackInstances	= nil;
local m_tabs;



-- ===========================================================================
--	Functions
-- ===========================================================================
function TeamsHaveMet(team1Id, team2Id)
	local team1 = Teams[team1Id];
	local team2 = Teams[team2Id];

	return team1:IsHasMet(team2Id);
end

-- Get the leader name of toPlayerId with regards to fromPlayerId (if not nil)
function GetLeaderName(toPlayer, fromPlayer)
	if(fromPlayer ~= nil) then
		if(not TeamsHaveMet(fromPlayer:GetTeam(), toPlayer:GetTeam())) then
			return "TXT_KEY_UNMET_PLAYER_SHORT";
		end
	end

	if(toPlayer:GetNickName() ~= "" and Game.IsGameMultiPlayer() and toPlayer:IsHuman()) then 
		return toPlayer:GetNickName();
	else
		return toPlayer:GetNameKey();
	end
end



-- ===========================================================================
function OnPopup(popupInfo)

	-- Is a popup occuring while this is up?  If so, close the log...
	if (popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_QUEST_PROMPT) then
		if (not ContextPtr:IsHidden()) then
			OnClose();
			return;
		end
	end
	

	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_QUEST_LOG) then
		return;
	end

	-- It's this screen, but is it initialized...
	if (m_IsInitialized == false) then
		Initialize();
	end

	m_PopupInfo = popupInfo;

	LuaEvents.SubDiploPanelOpen( self );

	if (popupInfo.Data1 ~= -1) then
		local isVictory = popupInfo.Data3 == 1;

		local selectedTab;
		if (isVictory == true) then
			selectedTab = Controls.VictoryTab;
		else
			selectedTab = Controls.QuestsTab;
		end
		m_tabs.SelectTab( selectedTab );
	end

	if (popupInfo.Data1 == 1) then
		if (ContextPtr:IsHidden() == false) then
			ContextPtr:SetHide(true);
		else
			ContextPtr:SetHide(false);
		end
	else
		ContextPtr:SetHide(false);
	end

	-- -1 means no specific quest expanded, otherwise index of the quest
	m_CurrentExpandedQuestIndex = popupInfo.Data2;
	UpdateWindow();

	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
end
Events.SerialEventGameMessagePopup.Add(OnPopup);

-- ===========================================================================
-- 'Active' (local human) player has changed
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		OnClose();
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

-- ===========================================================================
function ShowHideHandler( isHide, isInit )
	if (not isInit) then
		if (not isHide) then
			Events.SerialEventGameMessagePopupShown(m_PopupInfo);
			UpdateWindow();
		else
			if(m_PopupInfo ~= nil) then
				Events.SerialEventGameMessagePopupProcessed.CallImmediate(m_PopupInfo.Type, 0);
            end
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);


-- ===========================================================================
function OnClose()
	ContextPtr:SetHide(true);
	LuaEvents.SubDiploPanelClosed();
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);


-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose();
            return true;
        end
    end
end
ContextPtr:SetInputHandler(InputHandler);


-- ===========================================================================
function Initialize()
	
	m_ScrollPanelSizeDefault	= Controls.MainContentScrollPanel:GetSizeY();

	m_tabs = CreateTabs( Controls.TabRow, 64, 32 );
	m_tabs.AddTab( Controls.QuestsTab,		OnTabQuests );
	m_tabs.AddTab( Controls.VictoryTab,		OnTabVictory );
	m_tabs.CenterAlignTabs();	

	m_IsInitialized = true;
end


-- ===========================================================================
function OnTabQuests( control )
	m_CurrentFilter = FilterType.QUEST;
	UpdateWindow();
end

-- ===========================================================================
function OnTabVictory( control)
	m_CurrentFilter = FilterType.VICTORY;
	UpdateWindow();
end

-- ===========================================================================
function OptionsGridHide( isHidden )
	
	Controls.OptionsPanel:SetHide( isHidden );
	
	local offsetY = Controls.TabRow:GetOffsetY() + Controls.TabRow:GetSizeY();

	if ( isHidden ) then
		Controls.MainContentScrollPanel:SetSizeY( m_ScrollPanelSizeDefault );
	else
		local ART_EXTRA_PADDING = 7;
		local optionPanelY		= Controls.OptionsPanel:GetSizeY();

		offsetY = offsetY + (optionPanelY - ART_EXTRA_PADDING);
		Controls.MainContentScrollPanel:SetSizeY( m_ScrollPanelSizeDefault - (optionPanelY - ART_EXTRA_PADDING) );		
	end
	
	Controls.MainContentScrollPanel:SetOffsetY( offsetY );

end

-- ===========================================================================
function InsertQuestEntry(quest)
	local player		= Players[quest:GetOwner()];
	local info			= GameInfo.Quests[quest:GetType()];
	local name			= info.Description;
	local nameOverride	= quest:GetNameOverride();
	
	if nameOverride ~= nil then
		name = nameOverride;
	end

	-- Create the UI element instance
	local questInstance = {};
	if (info.Victory) then
		ContextPtr:BuildInstanceForControl("VictoryEntryInstance", questInstance, Controls.MainContentStack);
	else
		ContextPtr:BuildInstanceForControl("QuestEntryInstance", questInstance, Controls.MainContentStack);
	end

	-- Hide sets of controls based on status
	local isFinished = not quest:IsInProgress();
	local isFailed	 = isFinished and quest:DidFail();
	questInstance.ActiveControls:SetHide(isFinished);
	questInstance.InactiveControls:SetHide(not isFinished);

	local prefix				= isFinished and "Inactive" or "Active";	
	local expandButton			= questInstance[prefix .. "ExpandButton"];
	local expandButtonLabel		= questInstance[prefix .. "ExpandButtonLabel"];
	local objectivesContracted	= questInstance[prefix .. "ObjectivesContracted"];
	local objectivesExpanded	= questInstance[prefix .. "ObjectivesExpanded"];
		

	-- Keep copy of instance for later element manipulation if there is no scrollbar.
	table.insert( m_uiMainContentStackInstances, questInstance );


	local MAX_QUEST_NAME_LENGTH = 400;
	local questNameTitle		= "";
	if (name ~= nil) then
		if (isFinished) then
			if (isFailed) then
				questNameTitle = Locale.ToUpper(Locale.Lookup(name)) .. " (" .. Locale.Lookup("TXT_KEY_QUEST_FAILED") ..")";
				expandButtonLabel:SetColor( COLOR_QUEST_FAILED, 0 );
			else
				questNameTitle = Locale.ToUpper(Locale.Lookup(name)) .. " (" .. Locale.Lookup("TXT_KEY_QUEST_COMPLETE") ..")";
				expandButtonLabel:SetColor( COLOR_QUEST_COMPLETE, 0 );
			end
		else
			questNameTitle = Locale.ToUpper(Locale.Lookup(name));
		end
	end
	TruncateStringWithTooltip( expandButtonLabel, MAX_QUEST_NAME_LENGTH, questNameTitle);


	--questInstance.UpdatedIcon:SetHide(false);
	questInstance.UpdatedIcon:SetHide( not quest:WasUpdated() );

	if (info.Victory) then
		
		local civStack		= questInstance[prefix .. "CivStack"];
		local civData		= {};
		local portraitImage	= questInstance.PortraitImage;

		-- Big image representing the victory:
		IconHookup(info.PortraitIndex, 91, info.IconAtlas, portraitImage);

		local otherPlayer;
		for i=0,GameDefines.MAX_MAJOR_CIVS-1, 1 do
			otherPlayer = Players[i];
			local otherQuest = otherPlayer:GetQuest(info.ID);

			if (otherPlayer:IsAlive() and otherQuest ~= nil) then
				table.insert(civData, {
					PlayerID = i,
					Progress = otherQuest:GetProgress(),
				});
			end
		end

		table.sort(civData, function(a, b) 
			if(a.Progress == b.Progress) then
				return a.PlayerID < b.PlayerID;
			else
				return a.Progress > b.Progress; 
			end
		end);

		local rankCtr = 1;
		local isRanked = false;
		local currentScore = nil;
		for i,data in ipairs(civData) do
			
			-- Temporary Patch!
			-- Because this screen was not designed for more than 8 players, only show the first 8.
			if(8 < i) then
				break;
			end

			local otherPlayer		= Players[data.PlayerID];
			local civInstance		= {};
			local backingImageName	= "Assets/UI/Art/Quests/VictoryIconBackingThem";
			local isUs				= (data.PlayerID == Game.GetActivePlayer());
			local civEntry			= GameInfo.Civilizations[otherPlayer:GetCivilizationType()];
			local iconSize			= 57;
			ContextPtr:BuildInstanceForControl("CivVictoryEntryInstance", civInstance, civStack);

			-- First one (they are sorted) is leading!
			if ( i == 1 and data.Progress ~= 0) then
				isRanked = true;									-- If the person in first has made some progress, then this IS a ranked list
			end
			if( isRanked ) then
				if (currentScore == nil) then
					currentScore = data.Progress;
				end
				if (data.Progress < currentScore) then 
					currentScore = data.Progress; 
					rankCtr = rankCtr + 1; 
		        end 
			end
			if( rankCtr == 1 and isRanked ) then
				civInstance.First:SetHide(false);
			end
			civInstance.VictoryProgress:SetPercent(data.Progress / 100);

			local civIconID = -1;
			if(TeamsHaveMet(player:GetTeam(), otherPlayer:GetTeam())) then
				civIconID = data.PlayerID;
			end

			CivIconHookup(civIconID, iconSize, civInstance.CivIcon, civInstance.CivIconBG, nil, true, false, civInstance.CivIconHighlight );
			if( isUs == false and civIconID ~= -1) then
				civInstance.CivIcon:SetAlpha( .6 );
				civInstance.CivIconBG:SetAlpha( .4 );
				civInstance.CivIconHighlight:SetAlpha( .4 );
			else
				civInstance.CivIconBG:SetAlpha(1);
				civInstance.CivIconHighlight:SetAlpha(1);
			end

			--Construct tooltip string
			local s : string = "";
			s = s .. "[COLOR_BLUE_SUBHEADER]".. Locale.ConvertTextKey("TXT_KEY_RANKING_TITLE") .. " : " .. "[ENDCOLOR]";
			if( isRanked ) then
				s = s .. rankCtr;
			else
				s = s .. Locale.ConvertTextKey("TXT_KEY_COVERT_NONE");
			end
			s = s .. "[NEWLINE]";
			local leaderNameString = Locale.Lookup(GetLeaderName(otherPlayer, player));
			s = s .. leaderNameString;
			if( isUs ) then
				s = s .. " " .. "[COLOR_BRIGHTBLUE_SUBHEADER]".. Locale.ConvertTextKey(Locale.ToUpper("TXT_KEY_YOU")) .. "[ENDCOLOR]";
			end
			s = s .. "[NEWLINE]";

			--s = s .. "[COLOR_PLAYER_GRAY_TEXT]".. Locale.ConvertTextKey("TXT_KEY_VP_TT") .. " : " .. "[ENDCOLOR]".. data.Progress;

			-- List current objective and any completed objectives for the current player
			local currentPlayerQuestData : object = otherPlayer:GetQuest(quest:GetType());
			if( currentPlayerQuestData ~= nil ) then

				local questObjectives = currentPlayerQuestData:GetObjectives();
				local objectiveStrings = {};
				for i,objective in ipairs(questObjectives) do 
				
					local objectiveStr : string = "";

					-- Completed objective
					if (objective:DidSucceed()) then
						objectiveStr = objective:GetSummary();
						objectiveStr = objectiveStr .. " (" .. Locale.ConvertTextKey("TXT_KEY_QUEST_COMPLETE") .. ")";
						table.insert(objectiveStrings, "[COLOR_PLAYER_GRAY_TEXT]" .. objectiveStr .. "[ENDCOLOR]");
					-- Current objective in progress
					elseif (objective:IsInProgress()) then
						objectiveStr = objective:GetSummary();
						objectiveStr = objectiveStr .. " (" .. Locale.ConvertTextKey("TXT_KEY_QUEST_IN_PROGRESS") .. ")";
						table.insert(objectiveStrings, "[COLOR_PLAYER_LIGHT_GREEN_TEXT]" .. objectiveStr .. "[ENDCOLOR]");
					end
				end 

				if (#objectiveStrings > 0) then
					s = s .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_QUEST_OBJECTIVES_TITLE") .. ":[NEWLINE]";
					s = s .. table.concat(objectiveStrings, "[NEWLINE]");	
				end

			end
			
			civInstance.CivIconFrame:SetToolTipString(s);
		end

	else

		local BANNER_IMAGE_HEIGHT	= 46;	
		local bannerTypeImage		= questInstance[prefix .. "BannerImage"];
		bannerTypeImage:SetTextureOffsetVal(0, info.PortraitIndex * BANNER_IMAGE_HEIGHT );		-- affinity, covertops, domestic, exploration, diplomatic
		--bannerTypeImage:SetAlpha( 0.5 );
	end

	-- Victory-specific control setup
	if (info.Victory) then
	end

	expandButton:RegisterCallback(Mouse.eLClick, function() 
		if (m_CurrentExpandedQuestIndex == quest:GetIndex()) then
			m_CurrentExpandedQuestIndex = -1;
		else
			m_CurrentExpandedQuestIndex = quest:GetIndex();
		end

		UpdateWindow();
	end);

	local isQuestExpanded = m_CurrentExpandedQuestIndex == quest:GetIndex();

	if (isQuestExpanded) then
		objectivesExpanded:SetHide(false);
		objectivesContracted:SetHide(true);

		-- Rewards
		local rewardStrings = {quest:GetReward()};
		local noReward		= "$NO REWARD$";				-- defined in CvLuaQuest.cpp

		if (quest:DidSucceed()) then					
			if (#rewardStrings > 0) and (not ( #rewardStrings == 1 and rewardStrings[1] == noReward )) then

				--"Rewards Received" text goes on its own line, the rewards stack below it
				local rewardInstance = {};
				ContextPtr:BuildInstanceForControl("RewardInstance", rewardInstance, Controls.MainContentStack);
				rewardInstance.Header:SetText( Locale.ToUpper( Locale.ConvertTextKey("TXT_KEY_QUEST_REWARDS_RECEIVED", #rewardStrings )) );

				for i,reward in pairs(rewardStrings) do
					rewardInstance = {};
					ContextPtr:BuildInstanceForControl("RewardInstance", rewardInstance, Controls.MainContentStack);
					rewardInstance.Header:SetHide( true );
					rewardInstance.Reward:SetText( Locale.ConvertTextKey(reward) );
				end
			end
		end

		-- Add the quest description
		local descriptionMessageInstance = {};
		ContextPtr:BuildInstanceForControl("MessageEntryInstance", descriptionMessageInstance, Controls.MainContentStack);
		descriptionMessageInstance.Label:LocalizeAndSetText(quest:GetPrologue());
		descriptionMessageInstance.Grid:SetSizeX(Controls.MainContentStack:GetSizeX() - 2);
		descriptionMessageInstance.Grid:SetSizeY(descriptionMessageInstance.Label:GetSizeY() + 20);

		local objectives = quest:GetObjectives();
		for i,objective in ipairs(objectives) do
			-- Create instance
			local objectiveInstance = {};
			ContextPtr:BuildInstanceForControl("ObjectiveEntryInstance", objectiveInstance, Controls.MainContentStack);

			objectiveInstance.Content:SetHide(false);

			-- Hide sets of controls based on isFinished
			objectiveInstance.ActiveControls:SetHide(isFinished);
			objectiveInstance.InactiveControls:SetHide(not isFinished);

			-- Extract controls
--			local completeBox				= (isFinished and objectiveInstance.InactiveCompleteBox or objectiveInstance.ActiveCompleteBox);
--			local incompleteBox				= (isFinished and objectiveInstance.InactiveIncompleteBox or objectiveInstance.ActiveIncompleteBox);
			local completeObjectiveLabel	= (isFinished and objectiveInstance.InactiveCompleteLabel or objectiveInstance.ActiveCompleteLabel);
			local incompleteObjectiveLabel	= (isFinished and objectiveInstance.InactiveIncompleteLabel or objectiveInstance.ActiveIncompleteLabel);
			local checkBox					= (isFinished and objectiveInstance.InactiveCheckBox or objectiveInstance.ActiveCheckBox);
			local focusButton				= (isFinished and objectiveInstance.InactiveFocusButton or objectiveInstance.ActiveFocusButton);

			-- Text
			local newSizeX = 0;
			local newSizeY = 0;
			if (objective:IsInProgress()) then
				incompleteObjectiveLabel:SetHide(false);
				completeObjectiveLabel:SetHide(true);
				incompleteObjectiveLabel:LocalizeAndSetText(objective:GetSummary());

				newSizeX = Controls.MainContentStack:GetSizeX() - 2;
				newSizeY = incompleteObjectiveLabel:GetSizeY() + 20;
			else
				incompleteObjectiveLabel:SetHide(true);
				completeObjectiveLabel:SetHide(false);
				completeObjectiveLabel:LocalizeAndSetText(objective:GetSummary());

				newSizeX = Controls.MainContentStack:GetSizeX() - 2;
				newSizeY = completeObjectiveLabel:GetSizeY() + 20;

				if (objective:DidSucceed()) then
					local objectiveMessageInstance = {};
					ContextPtr:BuildInstanceForControl("MessageEntryInstance", objectiveMessageInstance, Controls.MainContentStack);
					objectiveMessageInstance.Label:LocalizeAndSetText(objective:GetEpilogue());
					objectiveMessageInstance.Grid:SetSizeX(Controls.MainContentStack:GetSizeX());
					objectiveMessageInstance.Grid:SetSizeY(objectiveMessageInstance.Label:GetSizeY() + 20);
				end
			end
			objectiveInstance.Content:SetSizeX(newSizeX);
			objectiveInstance.Content:SetSizeY(newSizeY);
			objectiveInstance.Highlight:SetSizeX(newSizeX);
			objectiveInstance.Highlight:SetSizeY(newSizeY);


			-- Checkmark
			if objective:IsInProgress() then
				objectiveInstance.Highlight:SetHide( false );
				objectiveInstance.Highlight:SetColor( 0xff62341F );
			elseif (objective:DidSucceed()) then
				checkBox:SetTextureOffsetVal(0, 32);	-- 2nd texture in strip is checked
			end
			
			-- Focus Button (aka: "showme")
			local plotX, plotY = objective:GetFocusPlot();
			local plot = Map.GetPlot(plotX, plotY);
			if (plot ~= nil) then
				focusButton:SetHide(false);
				focusButton:RegisterCallback(Mouse.eLClick, function() 
					--LookAtPlot(objective:GetOwner(), plot, 8);
					UI.LookAt(plot, 8);
					local hex = ToHexFromGrid(Vector2(plot:GetX(), plot:GetY()));
					Events.GameplayFX(hex.x, hex.y);

					--[[
					UI.LookAt(plot, 8);		-- CameraLookAtTypes.CAMERALOOKAT_FIT_FIRST_THIRD = 8
					local hex = ToHexFromGrid(Vector2(plot:GetX(), plot:GetY()));
					Events.GameplayFX(hex.x, hex.y);
					]]--
				end);
			else
				focusButton:SetHide(true);
			end
		end -- objectives

		-- Add failed message at bottom.
		if ( isFailed ) then

			local questFailedText = Locale.ConvertTextKey("TXT_KEY_QUEST_FAILED_FOOTER");
			local questFailureSummary = quest:GetFailureSummary();

			local failedMessageInstance = {};
			ContextPtr:BuildInstanceForControl("MessageEntryInstance", failedMessageInstance, Controls.MainContentStack);
			failedMessageInstance.Label:SetColor( 0xff0000dd, 0 );
			failedMessageInstance.Label:LocalizeAndSetText(questFailedText .. " " .. questFailureSummary);
			failedMessageInstance.Grid:SetSizeX(Controls.MainContentStack:GetSizeX());
			failedMessageInstance.Grid:SetSizeY(failedMessageInstance.Label:GetSizeY() + 20);
		end

	else
		objectivesExpanded:SetHide(true);
		objectivesContracted:SetHide(false);
	end
end

-- ===========================================================================
function UpdateWindow()

	-- Destroy and reset...	
	Controls.MainContentStack:DestroyAllChildren();
	m_uiMainContentStackInstances = {};
	
	-- Build...

	local player = Players[Game.GetActivePlayer()];
		
	OptionsGridHide( m_CurrentFilter == FilterType.VICTORY );

	local numVictoryQuestsUpdated = player:GetNumVictoryQuestsMarkedUpdated();
	local numQuestsUpdated = player:GetNumQuestsMarkedUpdated();

	if (numVictoryQuestsUpdated ~= 0) then
		Controls.VictoryTabUpdatedBadge:SetHide(false);
		Controls.VictoryTabUpdatedLabel:SetHide(false);
		Controls.VictoryTabUpdatedLabel:SetText(numVictoryQuestsUpdated);
	else
		Controls.VictoryTabUpdatedBadge:SetHide(true);
		Controls.VictoryTabUpdatedLabel:SetHide(true);
	end

	if (numQuestsUpdated ~= 0) then
		Controls.QuestTabUpdatedBadge:SetHide(false);
		Controls.QuestTabUpdatedLabel:SetHide(false);
		Controls.QuestTabUpdatedLabel:SetText(numQuestsUpdated);
	else
		Controls.QuestTabUpdatedBadge:SetHide(true);
		Controls.QuestTabUpdatedLabel:SetHide(true);
	end

	-- Update filter boxes
	Controls.FilterShowCompleted:SetCheck(not OptionsManager.GetHideCompletedQuests_Cached());
	Controls.FilterShowFailed:SetCheck(not OptionsManager.GetHideFailedQuests_Cached());

	-- Sort by finished vs unfinished, and those done if they failed vs succeeded
	local quests = player:GetQuests();
	table.sort(quests, 
		function(a, b) 
			if a:IsInProgress() then
				return not b:IsInProgress();
			elseif b:IsInProgress() then 
				return false;
			-- Both are finished. Did one fail and one succeed?
			elseif a:DidFail() ~= b:DidFail() then
				return not a:DidFail();
			-- Both failed or succeeded. Sort by completion turn (latest to earliest).
			else
				return a:GetCompletionTurn() > b:GetCompletionTurn();
			end
		end);

	Controls.NoQuestsLabel:SetHide(m_CurrentFilter ~= FilterType.QUEST);
	for i,quest in ipairs(quests) do
		if (ShouldDisplayQuest(quest)) then
			InsertQuestEntry(quest);
		end

		if (GameInfo.Quests[quest:GetType()].Victory ~= true and m_CurrentFilter == FilterType.QUEST) then
			Controls.NoQuestsLabel:SetHide(true);
		end
	end

	Controls.MainContentStack:CalculateSize();
	Controls.MainContentStack:ReprocessAnchoring();
	Controls.MainContentScrollPanel:CalculateInternalSize();
	Controls.MainContentScrollPanel:ReprocessAnchoring();


	-- Resize the contents based on whether or not a scrollbar is present.
	-- This is a bit ugly due to resizing in scrollable areas not playing nice with scrollbars.
	local WIDTH_WITH_SCROLL_BAR = 550;	
	if IsScrollbarShowing( Controls.MainContentScrollPanel ) then
		
		Controls.MainContentScrollPanel:SetSizeX( WIDTH_WITH_SCROLL_BAR );
		
		for _,uiInstance in pairs(m_uiMainContentStackInstances) do			
			local size = uiInstance.ActiveExpandButton:GetSizeX();
			--uiInstance.Top:SetSizeX( size - SCROLL_BAR_WIDTH );
			--uiInstance.ActiveExpandButton:SetSizeX( size - SCROLL_BAR_WIDTH );
			--uiInstance.InactiveExpandButton:SetSizeX( size - SCROLL_BAR_WIDTH );			
			uiInstance.Top:SetSizeX( WIDTH_WITH_SCROLL_BAR );
			uiInstance.ActiveExpandButton:SetSizeX( WIDTH_WITH_SCROLL_BAR );
			uiInstance.InactiveExpandButton:SetSizeX( WIDTH_WITH_SCROLL_BAR );
		end
		
		Controls.MainContentStack:CalculateSize();
		Controls.MainContentStack:ReprocessAnchoring();
		Controls.MainContentScrollPanel:CalculateInternalSize();		
		Controls.MainContentScrollBar:ChangeParent( Controls.MainContentScrollPanel );	-- Forces to be on top.
		Controls.MainContentScrollBar:SetHide( false );
	else
		Controls.MainContentScrollBar:SetHide( true );
	end
	
end

-- ===========================================================================
function ShouldDisplayQuest(quest)
	local questInfo = GameInfo.Quests[quest:GetType()];

	if ( m_CurrentFilter == FilterType.VICTORY ) then
		return questInfo.Victory == true;
	else

		if ( questInfo.Victory == false ) then

			local isFinished	= not quest:IsInProgress();
			local isFailed		= isFinished and quest:DidFail();

			local passCurrent	= (not isFinished) and (not isFailed );
			local passCompleted = (not OptionsManager.GetHideCompletedQuests_Cached() and isFinished) and not isFailed;
			local passFailed	= (not OptionsManager.GetHideFailedQuests_Cached()) and isFailed;
			
			-- Any of these cases are reason to show.
			return passCurrent or passFailed or passCompleted;

		end
		return false;
	end
end

-- ===========================================================================
function OnFilterCompleted( bCheck )
	OptionsManager.SetHideCompletedQuests_Cached(not bCheck);
	OptionsManager.CommitGameOptions();

	UpdateWindow();
end
Controls.FilterShowCompleted:RegisterCheckHandler( OnFilterCompleted );

-- ===========================================================================
function OnFilterFailed( bCheck )
	OptionsManager.SetHideFailedQuests_Cached(not bCheck);
	OptionsManager.CommitGameOptions();

	UpdateWindow();
end
Controls.FilterShowFailed:RegisterCheckHandler( OnFilterFailed );