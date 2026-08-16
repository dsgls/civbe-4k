-- ===========================================================================
--
--	CivBE Covert Operations Panel
--	Shows/sets which spies are performing operations in cities
--	Raised (and contained) by CovertOpsPopup
--
-- ===========================================================================

include("IconSupport");
include("InstanceManager");
include("SupportFunctions");
include("UIExtras");
include("GameplayUtilities");

-- ===========================================================================
--		CONSTANTS
-- ===========================================================================
local ART_PROGRESS_BAR_WIDTH				= 155 * 2;			-- progress bars
local ART_INTRIGUE_WIDTH					= 102;
local ART_INTRIGUE_HEIGHT					= 24;
local ART_MAINSCROLLPANEL_WITH_CHOICE_HEIGHT= 518;
local ART_MAINSCROLLPANEL_FULL_HEIGHT		= 575;
local ART_LIST_ITEM_W_SCROLLBAR_WIDTH		= 426;
local ICON_RANK_HEIGHT 						= 32 * 2;
local COLOR_DISABLED_TEXT					= 0xcca0a0a0;
local PARENT_CONTEXT_PATH					= "/InGame/CovertOpsPopup/";
local PARENT_CONTROL_NAME					= "InnerGridBG";


-- ===========================================================================
--		GLOBALS
-- ===========================================================================
local MODE_AGENTS	= "agents";
local MODE_CITIES	= "cities";
local MODE_PROJECTS	= "projects";
local g_mode		= MODE_AGENTS;

local g_headerHighIntrigueWarningInstanceManager = InstanceManager:new("HighIntrigueWarningInstance", "Header", Controls.HQStack);
local g_headerHQInstanceManager		= InstanceManager:new( "HeaderHQInstance",		"Header", 	Controls.HQStack );
local g_headerMissionInstanceManager= InstanceManager:new( "HeaderMissionInstance",	"Header", 	Controls.MissionStack );
local g_headerCounterintelInstanceManager= InstanceManager:new( "HeaderCounterintelInstance",	"Header", 	Controls.CounterintelStack );
local g_headerCityInstanceManager	= InstanceManager:new( "HeaderCityInstance",	"Header", 	Controls.CityStack );

local g_spyHQInstanceManager		= InstanceManager:new( "SpyHQInstance",			"Spy", 		Controls.HQStack );
local g_spyMissionInstanceManager	= InstanceManager:new( "SpyMissionInstance",	"Spy",		Controls.MissionStack );
local g_spyCounterintelInstanceManager = InstanceManager:new( "SpyMissionInstance",	"Spy",		Controls.CounterintelStack );
local g_spyCityInstanceManager		= InstanceManager:new( "SpyCityInstance",		"Spy",		Controls.CityStack );
local g_cityInstanceManager			= InstanceManager:new( "CityInstance",			"City",		Controls.CityStack );
local g_projectInstanceManager		= InstanceManager:new( "NationalSecurityProjectInstance", "Project", Controls.ProjectStack );


local g_isInit		= false;
local g_isVisible	= false;
local g_nextId		= 0;

local g_city		= nil;					-- current city
local g_agent		= nil;					-- current agent
local g_currentProjectType = -1;			-- current project
local g_agents		= {};					-- all loaded agents in UI
local g_uiListItems = {};					-- each UI element (needed for resizing when scrollbar occurs.)
local g_uiSelected	= nil;					-- the UI of the currently selected list item (agent or city)


-- ===========================================================================
--		CTOR
-- ===========================================================================
function Initialize()
	g_isInit = true;
	-- Do not update window here; CovertOps system may not have finished loading.	
end

-- ===========================================================================
--		Choose what to show base on the mode
-- ===========================================================================
function UpdateWindow()	

	-- Clear out cached and selected items, as well as lists

	g_agents		= {};
	g_uiListItems	= {};
	g_uiSelected	= nil;

	g_headerHighIntrigueWarningInstanceManager:DestroyInstances();
	g_headerHQInstanceManager:DestroyInstances();
	g_headerMissionInstanceManager:DestroyInstances();
	g_headerCounterintelInstanceManager:DestroyInstances();
	g_headerCityInstanceManager:DestroyInstances();

	g_spyHQInstanceManager:DestroyInstances();
	g_spyMissionInstanceManager:DestroyInstances();
	g_spyCounterintelInstanceManager:DestroyInstances();
	g_spyCityInstanceManager:DestroyInstances();
	g_cityInstanceManager:DestroyInstances();
	g_projectInstanceManager:DestroyInstances();

	Controls.HQStack		:DestroyAllChildren();
	Controls.MissionStack	:DestroyAllChildren();
	Controls.CounterintelStack	:DestroyAllChildren();
	Controls.CityStack		:DestroyAllChildren();
	Controls.ProjectStack	:DestroyAllChildren();

	-- If one or more of our cities has high intrigue, show a
	-- warning.
	if (GameplayUtilities.DoesPlayerHaveHighIntrigueCities(Game.GetActivePlayer())) then
		g_headerHighIntrigueWarningInstanceManager:GetInstance();
	end

	-- Build new list based on the mode

	if (g_mode == MODE_CITIES) then
		UpdateWindow_Cities();
	elseif (g_mode == MODE_AGENTS) then
		UpdateWindow_Agents();
	else
		UpdateWindow_Projects();
	end

end

-- ===========================================================================
--	Callback time is done, do the update.
-- ===========================================================================
function OnUpdateFromAnim()
	if ( Controls.RefreshCallbackHelper:IsStopped() ) then
		UpdateWindow();
	end
end

-- ===========================================================================
--		Update List of agents
-- ===========================================================================
function UpdateWindow_Agents()	
	local player = Players[Game.GetActivePlayer()];

	-- Create headers, and store them in-case a resize is needed.
	local header;
	header = g_headerHQInstanceManager:GetInstance();
	table.insert( g_uiListItems, header );
	
	header = g_headerMissionInstanceManager:GetInstance();
	table.insert( g_uiListItems, header );	

	header = g_headerCounterintelInstanceManager:GetInstance();
	table.insert( g_uiListItems, header );

	local agents = player:GetCovertAgents();
	local agent;
	local i;
	local hqAgentNum		= 0;
	local missionAgentNum	= 0;
	local counterintelAgentNum = 0;
	
	MakeNationalSecurityProjectHeader();

	for i,agent in ipairs(agents) do
		if (not agent:IsDead()) then
			if ( agent:CanTravel() and agent:GetCity() == nil ) then			
				CreateHQAgent( agent );
				hqAgentNum = hqAgentNum + 1;
			else
				if (not agent:IsDoingCounterIntelligence()) then
					CreateMissionAgent( agent );
					missionAgentNum = missionAgentNum + 1;
				else
					CreateCounterintelAgent( agent );
					counterintelAgentNum = counterintelAgentNum + 1;
				end
			end		
		end
	end

	local noneInstance;
	if ( hqAgentNum < 1 ) then
		noneInstance = {};
		ContextPtr:BuildInstanceForControl("NoneInstance", noneInstance, Controls.HQStack );
		table.insert( g_uiListItems, noneInstance );
	end

	if ( missionAgentNum < 1 ) then
		noneInstance = {};
		ContextPtr:BuildInstanceForControl("NoneInstance", noneInstance, Controls.MissionStack );
		table.insert( g_uiListItems, noneInstance );
	end

	if (counterintelAgentNum < 1) then
		noneInstance = {};
		ContextPtr:BuildInstanceForControl("NoneInstance", noneInstance, Controls.CounterintelStack );
		table.insert( g_uiListItems, noneInstance );
	end

	RealizeScrollArea( nil, nil );
end

function UpdateWindow_Projects()
	local player = Players[Game.GetActivePlayer()];
	if (g_currentProjectType == -1) then
		g_currentProjectType = player:GetNationalSecurityProject();
	end

	for projectInfo in GameInfo.NationalSecurityProjects() do
		local instance = g_projectInstanceManager:GetInstance();

		local perkInfo = GameInfo.PlayerPerks[projectInfo.PlayerPerk];

		instance.ProjectNameLabel:SetText(Locale.ConvertTextKey(projectInfo.Description));
		instance.ProjectEffectLabel:SetText(Locale.ConvertTextKey(perkInfo.Help));

		if (g_currentProjectType == projectInfo.ID) then
			instance.Selected:SetHide(false);
		else
			instance.Selected:SetHide(true);

			local tempProjectInfo = projectInfo;
			instance.Project:RegisterCallback(Mouse.eLClick, function() 
				g_currentProjectType = projectInfo.ID;
				UpdateWindow();
			end);
		end

		table.insert( g_uiListItems, instance);
	end

	-- If this is the first time we're selecting a project, don't allow the player
	-- to cancel
	if (player:GetNationalSecurityProject() == -1 and player:GetNumCovertAgents() > 0) then
		RealizeScrollArea(OnAssignProject, nil);
	else
		RealizeScrollArea( OnAssignProject, OnCancelProject );
	end

end

-- ===========================================================================
--		Update selected national security project
-- ===========================================================================
function MakeNationalSecurityProjectHeader()
	local player = Players[Game.GetActivePlayer()];

	local instance = {};
	ContextPtr:BuildInstanceForControl("NationalSecurityProjectHeaderInstance", instance, Controls.HQStack);

	instance.UnavailableContent:SetHide(true);
	instance.NoneSelectedContent:SetHide(true);
	instance.ActiveContent:SetHide(true);
	instance.StartingProjectContent:SetHide(true);
	instance.ProjectNameLabel:SetHide(false);

	instance.SelectProjectButton:RegisterCallback(Mouse.eLClick, OnSelectProject);
	instance.SwitchProjectFromStartingButton:RegisterCallback(Mouse.eLClick, OnSelectProject);

	if (player:GetNumCovertAgents() == 0) then
		instance.ProjectNameLabel:SetHide(true);
		instance.UnavailableContent:SetHide(false)
	else
		local projectType = player:GetNationalSecurityProject();

		if (projectType ~= -1) then
			local projectInfo = GameInfo.NationalSecurityProjects[projectType];
			local perkInfo = GameInfo.PlayerPerks[projectInfo.PlayerPerk];
			instance.ProjectNameLabel:SetText(Locale.ConvertTextKey(projectInfo.Description));
			instance.EffectLabel:SetText(Locale.ConvertTextKey(perkInfo.Help));

			if (player:IsNationalSecurityProjectActive()) then
				instance.ActiveContent:SetHide(false);
				instance.SwitchProjectFromActiveButton:RegisterCallback(Mouse.eLClick, OnSelectProject);
			else
			
				instance.StartingProjectContent:SetHide(false);

				local progress = player:GetProgressToNationalSecurityProjectActivates();
				local goal = progress + player:GetTurnsUntilNationalSecurityProjectActivates();
				local turnsLeft = goal - progress;
			
				local turnsString = Locale.Lookup("TXT_KEY_STR_TURNS", turnsLeft);
				
				local barCurrent = ART_PROGRESS_BAR_WIDTH - (( progress / goal ) * ART_PROGRESS_BAR_WIDTH);
				local barNext = ART_PROGRESS_BAR_WIDTH - (( (1 + progress) / goal ) * ART_PROGRESS_BAR_WIDTH);
				if (barNext < 0) then
					barNext = 0;
				end

				instance.BarNext:SetTextureOffsetVal(barNext, 0);
				instance.BarCurrent:SetTextureOffsetVal(barCurrent, 0);
				instance.Turns:SetText(turnsString);

				instance.SwitchProjectFromStartingButton:RegisterCallback(Mouse.eLClick, OnSelectProject);
			end
		else
			instance.NoneSelectedContent:SetHide(false);
			instance.ProjectNameLabel:SetText(Locale.ConvertTextKey("TXT_KEY_NO_NATIONAL_SECURITY_PROJECT_SELECTED"));
		end
	end

	instance.ContentStack:CalculateSize();
	instance.ContentStack:ReprocessAnchoring();

	table.insert(g_uiListItems, instance);
end

-- ===========================================================================
--		Update which city to sent the current spy
-- ===========================================================================
function UpdateWindow_Cities()	
	local player = Players[Game.GetActivePlayer()];

	-- Currently selected agent...

	local agent = g_agent;
	local ui	= g_spyCityInstanceManager:GetInstance();
	ui.Name		:LocalizeAndSetText( agent:GetName() );
	table.insert( g_uiListItems, ui );


	-- Obtain the city the spy is in; if in no city put them in the capital
	local isAtHQ = false;
	local city = agent:GetCity();
	if ( city == nil ) then
		city = player:GetCapitalCity();
		isAtHQ = true;
	end

	if ( isAtHQ ) then
		ui.CityName	:SetText( city:GetName().." ("..Locale.ConvertTextKey("TXT_KEY_COVERT_HQ")..")" );
	else
		ui.CityName	:SetText( city:GetName() );
	end
	CivIconHookup( city:GetOwner(), 45, ui.CivIcon, ui.CivIconBG, nil, false, false, ui.CivIconHighlight );

	-- As agent already at HQ?
	if ( isAtHQ )  then
		ui.Assign		:SetHide( true );
	else
		-- Create option to go back home...
		ui.Assign		:SetText( Locale.ConvertTextKey("TXT_KEY_COVERT_RETURN_TO_HQ") );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnReturnToHQ );
	end

	SetProgressBar( ui, agent );	

	-- Add the header between the selected agent and the cities list
	ui = g_headerCityInstanceManager:GetInstance();
	table.insert( g_uiListItems, ui );
	
	-- All the cities...

	local city;
	local playerID;
	local otherPlayer;
	local cityAgent;

	-- Loop through all active players (including self; for counter intelligence)...
	for playerID = 0, GameDefines.MAX_MAJOR_CIVS - 1, 1 do
		if (Players[playerID] ~= nil) then
			otherPlayer = Players[playerID];
			if otherPlayer:IsAlive() then 

				-- Loop through all the cities of the active players...
				for city in otherPlayer:Cities() do
					
					-- If a player already has an agent in the city, do not add it to the list.
					if ( agent:CanTravelToCity(city) ) then
						ui = CreateCity( city, agent );
						table.insert( g_uiListItems, ui );
					end
				end								
			end
		end
	end

	RealizeScrollArea( OnAssignAgentToCity, OnCancelAssignAgent );

end


-- ===========================================================================
--	Create City
--	RETURNS: UI reference to city	
-- ===========================================================================
function CreateCity( city, agent )

	local playerID	= city:GetOwner();
	local ui		= g_cityInstanceManager:GetInstance();
	local cityName	= city:GetName();

	ui.Name:SetText ( cityName );
	ui.City:RegisterCallback( Mouse.eLClick, function(void1,void2,button) OnSelectCity( ui, city); end );		
	CivIconHookup( playerID, 45, ui.CivIcon, ui.CivIconBG, nil, false, false, ui.CivIconHighlight );
	
	RealizeIntrigueArt( ui.Intrigue, city:GetIntrigue() );

	return ui;
end


-- ===========================================================================
--	ui,		User Interface element for intrigue
--	amount,	A value 0 to 5 for intrigue
-- ===========================================================================
function RealizeIntrigueArt( ui, amount )
	if ( amount > 0 ) then
		local percent = amount / 100;
		ui:SetSizeVal( ART_INTRIGUE_WIDTH * percent , ART_INTRIGUE_HEIGHT);
	else
		ui:SetHide( true );
	end
end


-- ===========================================================================
--		Create and populate UI piece for HQ agent
-- ===========================================================================
function CreateHQAgent( agent )	

	-- Dead men tell no tales.
	if ( agent:IsDead() ) then
		return;
	end

	-- Create UI...
	local ui = g_spyHQInstanceManager:GetInstance();
	
	ui.id			= GetNextID();
	ui.agent		= agent;

	--local agentInfo = Locale.ConvertTextKey( agent:GetName() ) .. " (" ..GetRankString( agent:GetRank() ) .. ")";
	--ui.Name			:SetText( agentInfo );
	ui.Name			:SetText( Locale.ConvertTextKey( agent:GetName() ) .. " (" .. GetRankString(agent:GetRank()) .. ") " );
	ui.LevelValue	:SetTextureOffsetVal( 0, agent:GetRank() * ICON_RANK_HEIGHT );

	ui.Turns		:SetHide( true );

	ui.Assign		:SetVoid1( ui.id );
	ui.Assign		:RegisterCallback( Mouse.eLClick, OnPrepareAgentForAssignedCity );

	StoreAgentUI( ui );
end


-- ===========================================================================
--		Create and populate UI piece for an agent on assignment
-- ===========================================================================
function CreateMissionAgent( agent )	

	local ui = g_spyMissionInstanceManager:GetInstance();

	ui.id			= GetNextID();
	ui.agent		= agent;

	--local agentInfo = Locale.ConvertTextKey( agent:GetName() ) .. " (" ..GetRankString( agent:GetRank() ) .. ")";
	--ui.Name			:SetText( agentInfo );
	ui.Name			:SetText( Locale.ConvertTextKey( agent:GetName() ) .. " (" .. GetRankString(agent:GetRank()) .. ") "  );
	ui.LevelValue	:SetTextureOffsetVal( 0, agent:GetRank() * ICON_RANK_HEIGHT );

	SetProgressBar( ui, agent );

	local city		= agent:GetCity();
	ui.CityName	:SetText( city:GetName() );

	local playerID	= city:GetOwner();
	--CivIconHookup( , 45, ui.CivIcon, nil, nil, false, false );
	CivIconHookup( playerID, 45, ui.CivIcon, ui.CivIconBG, nil, false, false, ui.CivIconHighlight );

	if (agent:IsTravelling()) then

		-- Traveling to a city
		ui.Spy			:RegisterCallback( Mouse.eLClick, function() OnSelectAgent(ui); OnShowCity(city); end );
		ui.Assign		:SetVoid1( ui.id );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnAbortTravel );	
		ui.Action		:SetText( Locale.ConvertTextKey( "TXT_KEY_COVERT_TRAVELING" ));
		ui.Assign		:SetText( Locale.ConvertTextKey( "{TXT_KEY_COVERT_ABORT:upper}" ));
		ui.OperationList:SetHide( true );
		ui.OperationIcon:SetHide(true);
		
	elseif (agent:IsIdle()) then

		ui.Spy			:RegisterCallback( Mouse.eLClick, function() OnSelectAgent(ui); OnShowCity(city); end );
		ui.Assign		:SetVoid1( ui.id );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnPrepareAgentForAssignedCity );	
		ui.OperationIcon:SetHide(true);
		--ui.Assign		:SetToolTipString( "this is a test abc def ghi jkl mno pqr stu vwx yz!" );

		ui.OperationList:ClearEntries();

		local uiOperation;
		local turns;
		local operations = agent:GetOperations();

		table.sort(operations, function(opA, opB) 
			local infoA = GameInfo.CovertOperations[opA.Type];
			local infoB = GameInfo.CovertOperations[opB.Type];

			if (infoA.IsQuestOp and not infoB.IsQuestOp) then
				return true;
			elseif (not infoA.IsQuestOp and infoB.IsQuestOp) then
				return false;
			elseif (opA.RequiredIntrigueLevel < opB.RequiredIntrigueLevel) then
				return true;
			elseif (opA.RequiredIntrigueLevel > opB.RequiredIntrigueLevel) then
				return false;
			else
				return opA.Difficulty < opB.Difficulty;
			end
		end);

		for i,operation in ipairs(operations) do
			local operationInfo = GameInfo.CovertOperations[operation.Type];
			local isQuestOp = operationInfo.IsQuestOp;
			if (isQuestOp and operation.CanDo or not isQuestOp) then

				uiOperation = {}
				ui.OperationList		:BuildEntry( "OperationPulldownInstance", uiOperation );
				uiOperation.Action		:SetText( operation.String );
				IconHookup(operationInfo.PortraitIndex, 45, operationInfo.IconAtlas, uiOperation.Icon);

				local difficultyText;
				if ( operation.Difficulty > 80 ) then
					difficultyText = Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_VERY_HARD");
				elseif ( operation.Difficulty > 60 ) then
					difficultyText = Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_HARD");
				elseif ( operation.Difficulty > 40 ) then
					difficultyText = Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_MODERATE");
				elseif ( operation.Difficulty > 20 ) then
					difficultyText = Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_EASY");
				elseif ( operation.Difficulty > 0 ) then
					difficultyText = Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_VERY_EASY");
				else
					difficultyText = Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_NONE");
				end
				uiOperation.Difficulty	:SetText( Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY") .. ": " .. difficultyText);			

				--RealizeIntrigueArt( uiOperation.Intrigue, operation.RequiredIntrigueLevel);
						
				--local percent = (operation.Intrigue) / 100;
				
				--uiOperation.AddedIntrigue:SetSizeVal(ART_INTRIGUE_WIDTH * percent , ART_INTRIGUE_HEIGHT);
				if ( operation.RequiredIntrigueLevel == 0 ) then
					uiOperation.ReqIntrigue:SetTextureOffsetVal((2+(operation.RequiredIntrigueLevel*20)) * 2, 0);
				else
					uiOperation.ReqIntrigue:SetTextureOffsetVal((2+(operation.RequiredIntrigueLevel*20)-20) * 2, 24 * 2);
				end
				uiOperation.ReqIntrigueLabel:SetText(operation.RequiredIntrigueLevel);

				local descriptionTT = operation.DescriptionToolTip;
				descriptionTT = descriptionTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_COVERT_DIFFICULTY_PERCENT", 100 - operation.Difficulty);
				descriptionTT = descriptionTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_COVERT_RISK_PERCENT", 100 - operation.Risk);

				if ( operation.CanDo) then
			
					turns = operation.Turns;
					uiOperation.TurnsValue:SetText(Locale.Lookup("TXT_KEY_STR_TURNS", turns));
										
					-- Selected an operation.
					uiOperation.Operation:RegisterCallback( Mouse.eLClick, 
						function(void1,void2,button)
							OnSetAgentOperation( agent, operation );
						end );

					uiOperation.Operation:SetToolTipString(descriptionTT);
				else
					uiOperation.TurnsValue:SetText("-");	-- Can't do, no turns for you!

					uiOperation.Action		:SetColor( COLOR_DISABLED_TEXT, 0 );
					uiOperation.TurnsValue	:SetColor( COLOR_DISABLED_TEXT, 0 );
					uiOperation.Difficulty	:SetColor( COLOR_DISABLED_TEXT, 0 );

					uiOperation.Operation:SetToolTipString(descriptionTT .. "[NEWLINE][NEWLINE]" .. "[COLOR_WARNING_TEXT]" .. Locale.ConvertTextKey(operation.DisabledReason) .. "[ENDCOLOR]" );

				end
			end			
		end		

		ui.OperationList:CalculateInternals();			-- Pulldown will autosize 
		ui.OpGrid:SetSizeY( ui.OpGrid:GetSizeY() + 8 );	-- ... so fix grid art to be slighty taller so it doesn't look like text is running over edges.


	elseif (agent:GetOperation() ~= nil  ) then
		
		local operation		= agent:GetOperation();
		local operationInfo = GameInfo.CovertOperations[operation.Type];

		ui.Spy			:RegisterCallback( Mouse.eLClick, function() OnSelectAgent(ui); OnShowCity(city); end );
		ui.Assign		:SetText( Locale.ConvertTextKey( "{TXT_KEY_COVERT_ABORT:upper}" ));				-- abort (stays in city)
		ui.Assign		:SetVoid1( ui.id );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnAbortOperation );

		ui.OperationList:SetHide( true );
		ui.Action		:SetText( Locale.ConvertTextKey( operation.String ) );

		ui.OperationIcon:SetHide(false);
		IconHookup( operationInfo.PortraitIndex, 45, operationInfo.IconAtlas, ui.OperationIcon );
		
		SetProgressBar( ui, agent );
	
	elseif ( agent:IsDoingCounterIntelligence() ) then
		-- here if an agent is in the home city.
		ui.Assign		:SetVoid1( ui.id );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnPrepareAgentForAssignedCity );
		ui.Spy			:RegisterCallback( Mouse.eLClick, function() OnSelectAgent(ui); OnShowCity(city); end );
		ui.OperationList:SetHide( true );
		ui.OperationIcon:SetHide(true);
	else
		-- error
		print("**** ERROR: CovertOps ****   agent: ", agent, agent:GetName() );

	end

	if (city == UI.GetCovertOpsSelectedCity()) then
		OnSelectCity(ui, city);
	end

	StoreAgentUI( ui );
end

function CreateCounterintelAgent( agent )
	local ui = g_spyCounterintelInstanceManager:GetInstance();

	ui.id			= GetNextID();
	ui.agent		= agent;

	--local agentInfo = Locale.ConvertTextKey( agent:GetName() ) .. " (" ..GetRankString( agent:GetRank() ) .. ")";
	--ui.Name			:SetText( agentInfo );
	ui.Name			:SetText( Locale.ConvertTextKey( agent:GetName() ) .. " (" .. GetRankString(agent:GetRank()) .. ") "  );
	ui.LevelValue	:SetTextureOffsetVal( 0, agent:GetRank() * ICON_RANK_HEIGHT );

	SetProgressBar( ui, agent );

	local city		= agent:GetCity();
	ui.CityName	:SetText( city:GetName() );

	local playerID	= city:GetOwner();
	--CivIconHookup( playerID, 45, ui.CivIcon, nil, nil, false, false );
	CivIconHookup( playerID, 45, ui.CivIcon, ui.CivIconBG, nil, false, false, ui.CivIconHighlight );

	ui.OperationList:SetHide( true );
	ui.OperationIcon:SetHide(true);

	if (agent:IsTravelling()) then

		-- Traveling to a city
		ui.Spy			:RegisterCallback( Mouse.eLClick, function() OnSelectAgent(ui); OnShowCity(city); end );
		ui.Assign		:SetVoid1( ui.id );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnAbortTravel );	
		ui.Action		:SetText( Locale.ConvertTextKey( "TXT_KEY_COVERT_TRAVELING" ));
		ui.Assign		:SetText( Locale.ConvertTextKey( "{TXT_KEY_COVERT_ABORT:upper}" ));
	else
		ui.Assign		:SetVoid1( ui.id );
		ui.Assign		:RegisterCallback( Mouse.eLClick, OnPrepareAgentForAssignedCity );
		ui.Spy			:RegisterCallback( Mouse.eLClick, function() OnSelectAgent(ui); OnShowCity(city); end );
		ui.OperationList:SetHide( true );
		ui.OperationIcon:SetHide(true);
	end

	if (city == UI.GetCovertOpsSelectedCity()) then
		OnSelectCity(ui, city);
	end

	StoreAgentUI( ui );
end

-- ===========================================================================
--	Set the progress bar for a given agent
--	ui, instance with all the pieces of the art for a progress bar and label
--	agent, the covert operative
-- ===========================================================================
function SetProgressBar( ui, agent )
	
	local goal			= agent:GetGoal();
	if ( goal == 0 ) then
		ui.ProgressBar:SetHide( true );
		return;
	end

	local progress		= agent:GetProgress();
	local turnsLeft		= goal - progress;

	local turnsString = Locale.Lookup("TXT_KEY_STR_TURNS", turnsLeft);

	local barCurrent	= ART_PROGRESS_BAR_WIDTH - (( progress / goal ) * ART_PROGRESS_BAR_WIDTH);
	local barNext		= ART_PROGRESS_BAR_WIDTH - (( (1 + progress) / goal ) * ART_PROGRESS_BAR_WIDTH);
	if (barNext < 0 ) then
		barNext = 0;
	end

	--print("SetProgressBar: ", agent:GetGoal(), agent:GetProgress(), turnsLeft, "'"..turnsString.."'" );

	ui.BarNext		:SetTextureOffsetVal( barNext, 0);
	ui.BarCurrent	:SetTextureOffsetVal( barCurrent, 0);
	ui.Turns		:SetText( turnsString );
end


-- ===========================================================================
--	Select an agent and raise the available city list.
-- ===========================================================================
function OnPrepareAgentForAssignedCity( void1, void2, button )
	if (not IsMyTurn()) then return end;

	g_agent			= g_agents[void1];
	g_mode			= MODE_CITIES;
	UpdateWindow();
end


-- ===========================================================================
-- ===========================================================================
function OnAbortTravel( void1, void2, button )
	if (not IsMyTurn()) then return end;

	agent			= g_agents[void1];

	-- Since this is a user command, send it as a netmessage.
	Network.SendCovertReturnToHeadquarters(agent.GetOwner(), agent.GetIndex());

	g_mode			= MODE_AGENTS;
end


-- ===========================================================================
--	Stops an agent from finishing an in-progress operation in a city.
-- ===========================================================================
function OnAbortOperation( void1, void2, button )
	if (not IsMyTurn()) then return end;
	
	agent			= g_agents[void1];
	agent			:AbortOperation();
	g_mode			= MODE_AGENTS;
end


-- ===========================================================================
--	An agent is selected from the list.
-- ===========================================================================
function OnSelectAgent( ui )
	if (not IsMyTurn()) then return end;

	if ( g_uiSelected ~= nil ) then
		g_uiSelected.Selected:SetHide( true )
	end
	g_uiSelected = ui;
	g_uiSelected.Selected:SetHide( false );
end


-- ===========================================================================
--	An city is selected from the list.
-- ===========================================================================
function OnSelectCity( ui, city )
	if (not IsMyTurn()) then return end;

	if ( g_uiSelected ~= nil ) then
		g_uiSelected.Selected:SetHide( true )
	end
	g_uiSelected = ui;
	g_uiSelected.Selected:SetHide( false );

	g_city = city;
	OnShowCity( city ); 			
end



-- ===========================================================================
-- ===========================================================================
function OnSetAgentOperation( agent, operation )
	if (not IsMyTurn()) then return end;

	agent:DoOperation( operation.Type );
end


-- ===========================================================================
-- ===========================================================================
function OnCancelAssignAgent( void1, void2, button )
	if (not IsMyTurn()) then return end;

	g_agent			= nil;
	g_city			= nil;
	g_mode			= MODE_AGENTS;
	UpdateWindow();
end

function OnSelectProject( void1, void2, button )
	if (not IsMyTurn()) then return end;

	g_agent			= nil;
	g_mode			= MODE_PROJECTS;
	UpdateWindow();
end

function OnAssignProject()
	if (not IsMyTurn()) then return end;

	local player = Players[Game.GetActivePlayer()];

	if (g_currentProjectType ~= player:GetNationalSecurityProject()) then
		player:StartNationalSecurityProject(g_currentProjectType);
	end

	g_agent			= nil;
	g_currentProjectType = -1;
	g_mode			= MODE_AGENTS;
	UpdateWindow();
end

function OnCancelProject()
	if (not IsMyTurn()) then return end;

	g_agent			= nil;
	g_currentProjectType = -1;
	g_mode			= MODE_AGENTS;
	UpdateWindow();
end

function OnReturnToHQ()
	if (not IsMyTurn()) then return end;

	if (g_agent == nil) then
		return;
	end

	g_agent:ReturnToHeadquarters();

	g_agent = nil;
	g_mode = MODE_AGENTS;
	UpdateWindow();
end

-- ===========================================================================
--		Player selected a city for an agent to travel to.
-- ===========================================================================
function OnAssignAgentToCity()
	if (not IsMyTurn()) then return end;

	if (g_city ~= nil) then
		g_agent:TravelToCity( g_city );
		g_agent			= nil;
		g_city			= nil;
		g_mode			= MODE_AGENTS;
		UI.ClearCovertOpsSelectedCity();
	end
end

-- ===========================================================================
--	rank	An enum of the rank
--	RETURNS:	A string representing the rank value.
-- ===========================================================================
function GetRankString( rank )

	-- Enum in CvCovertOpsClasses not exposed to this LUA context...
	if ( rank == 0 ) then
		return Locale.ConvertTextKey("TXT_KEY_COVERT_SPY_RANK_RECRUIT");
	elseif (rank == 1) then
		return Locale.ConvertTextKey("TXT_KEY_COVERT_SPY_RANK_AGENT");
	elseif (rank == 2) then
		return Locale.ConvertTextKey("TXT_KEY_COVERT_SPY_RANK_SPECIAL_AGENT");	
	end
	
	return "RANK_UNKNOWN" .. tostring( math.floor(rank) );
end


-- ===========================================================================
--	HELPER: Hand out next, temporary, ID for a created UI control to assist
--			in tracking which is clicked.
-- ===========================================================================
function GetNextID()
	g_nextId = g_nextId + 1;
	return g_nextId;
end

-- ===========================================================================
--	HELPER: When switching between modes, add agent to global list
-- ===========================================================================
function StoreAgentUI( ui )
	g_agents[ ui.id ] = ui.agent;		-- store actual agent
	table.insert( g_uiListItems, ui );	-- store UI (for scrollbar / resizing)
end


-- ===========================================================================
--	Send camera to the selected city
-- ===========================================================================
function OnShowCity( city )	
    --local plot = Map.GetPlot( x, y );
	local plot = city:Plot();
	local x = plot:GetX();
	local y = plot:GetY();
	
	-- Focus on the plot a little left of the camera, especially key for min-spec
	plot = Map.GetPlot(x + 2, y);
    if( plot ~= nil ) then
		UI.SetCovertOpsSelectedCity(city);
		UI.LookAt( plot );
	end
end


-- ===========================================================================
--	Setup the player choice (ok/cancel) buttons at the bottom.
--	If both callbacks are nil; hides the area.
-- ===========================================================================
function RealizeScrollArea( callbackAssign, callbackCancel )
	
	local isHideBottomButtonArea = (callbackAssign == nil) and (callbackCancel == nil );
	Controls.PlayerChoice:SetHide( isHideBottomButtonArea );

	Controls.Assign:SetHide(callbackAssign == nil);
	Controls.Cancel:SetHide(callbackCancel == nil);

	if ( isHideBottomButtonArea ) then
		Controls.MainScrollPanel:SetSizeY( ART_MAINSCROLLPANEL_FULL_HEIGHT );
	else
		-- Should never be NULL but was at least once during refactor (prevent broken builds)
		local parentControl	= ContextPtr:LookUpControl( PARENT_CONTEXT_PATH .. PARENT_CONTROL_NAME );
		if (parentControl == nil) then
			print("ERROR! Missing parent control/path combo: ", PARENT_CONTENT_PATH, PARENT_CONTROL_NAME );
			Controls.PlayerChoice:SetOffsetVal(24, 1000 );
		else
			local parentSizeY	= parentControl:GetSizeY();		
			Controls.PlayerChoice:SetOffsetVal(12, parentSizeY - 20 );
		end
		Controls.MainScrollPanel:SetSizeY( ART_MAINSCROLLPANEL_WITH_CHOICE_HEIGHT );
		Controls.Assign:RegisterCallback( Mouse.eLClick, callbackAssign );
		if( callbackCancel ~= nil ) then
			Controls.Cancel:RegisterCallback( Mouse.eLClick, callbackCancel );
		end
	end

	Controls.HQStack		:CalculateSize();
	Controls.MissionStack	:CalculateSize();
	Controls.CityStack		:CalculateSize();
	Controls.ProjectStack	:CalculateSize();
	Controls.OuterStack		:CalculateSize();
	Controls.OuterStack		:ReprocessAnchoring();
	Controls.MainScrollPanel:CalculateInternalSize();

	-- Scrollbar needed?  If so, make room for it...
	if IsScrollbarShowing( Controls.MainScrollPanel ) then		
		for i,ui in ipairs(g_uiListItems) do
			if ( ui.Spy ~= nil ) then
				ui.Spy:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
				if (ui.Selected ~= nil) then
					ui.Selected:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
				end
			elseif ( ui.City ~= nil ) then
				ui.City:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
				ui.Selected:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
			elseif ( ui.Header ~= nil ) then
				ui.Header:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
			elseif ( ui.Project ~= nil ) then
				ui.Project:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
				ui.Selected:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
			elseif ( ui.None ~= nil ) then
				ui.None:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
			end
		end
		Controls.MainScrollBar:SetHide( false );
	end

	Controls.OuterStack		:CalculateSize();
	Controls.OuterStack		:ReprocessAnchoring();

end

--[[
function OnAITurnStart()
	g_isMyTurn = false;
	UpdateWindow();
end
Events.AIProcessingStartedForPlayer.Add(OnAITurnStart);]]

function OnPlayerTurnStart()
	UpdateWindow();	
end
Events.ActivePlayerTurnStart.Add(OnPlayerTurnStart);
Events.RemotePlayerTurnStart.Add(OnPlayerTurnStart);

function IsMyTurn()
	return Players[Game.GetActivePlayer()]:IsTurnActive();
end

-- ===========================================================================
--		Covert Ops data has changed
-- ===========================================================================
function OnSerialEventEspionageScreenDirty()
	UpdateWindow();
end
Events.SerialEventEspionageScreenDirty.Add(OnSerialEventEspionageScreenDirty);

-- ===========================================================================
--		Show / Hide screen
-- ===========================================================================
function ShowHideHandler( isHide, isInit )
	if (not isInit) then
    
		if ( not isHide ) then
			if (not g_isVisible) then
				g_isVisible = true;
			    Events.SetCovertOpsView(true);			
				UI.incTurnTimerSemaphore();		
			end
		else
			if (g_isVisible) then
				g_isVisible = false;
			    Events.SetCovertOpsView(false);
			    UI.ClearCovertOpsSelectedCity();
			    g_mode = MODE_AGENTS;
				UI.decTurnTimerSemaphore();
			end
	    end
    
	    g_agent			= nil;
	    g_city			= nil;
    
	    local player = Players[Game.GetActivePlayer()];
	    if (player:GetNumCovertAgents() > 0 and player:GetNationalSecurityProject() == -1) then
		    g_mode = MODE_PROJECTS;
	    else
		    g_mode	= MODE_AGENTS;
	    end
    
	    UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
--	LuaEvent send by the popup subscribed to the context
-- ===========================================================================
function OnCovertOpsCloseAnyOpenPulldowns( )
	print("OnCovertOpsCloseAnyOpenPulldowns Pressed: ");

	-- Another pop-up is being raised; be sure all pulldowns are closed.
	for i,ui in ipairs(g_uiListItems) do
		if ( ui.OperationList ~= nil ) then
			ui.OperationList:ForceClose();
		end
	end
end
LuaEvents.CovertOpsCloseAnyOpenPulldowns.Add( OnCovertOpsCloseAnyOpenPulldowns );


Initialize();