include( "IconSupport" );
include( "UniqueBonuses" );
include( "VoiceChatLogic" );
include( "GameplayUtilities" );

local iCivID = -1;
local g_iPrologueState = -1;
local g_tPrologueStates = {
	{
		["TitleText"] = "{TXT_KEY_BEGIN_GAME_PROLOGUE_AFFINITIES_TITLE:upper}",
		["InfoText"] = "TXT_KEY_BEGIN_GAME_PROLOGUE_AFFINITIES_INFO",
		["ButtonText"] = "{TXT_KEY_BEGIN_GAME_BUTTON_CONTINUE:upper}",
		["AudioTag"] = "AS2D_NARRATOR_SPEECH_PROLOGUE_AFFINITIES",
		["PrologueTexture"] = "prologue_affinities.dds";
		["OnStart"] = function() Controls.PrologueContainer:SetHide(false); Controls.AffinityInfo:SetHide(false); end,
		["OnlyForNewGame"] = true,
	},
	{
		["TitleText"] = "{TXT_KEY_BEGIN_GAME_PROLOGUE_EXPLORATION_TITLE:upper}",
		["InfoText"] = "TXT_KEY_BEGIN_GAME_PROLOGUE_EXPLORATION_INFO",
		["ButtonText"] = "{TXT_KEY_BEGIN_GAME_BUTTON:upper}",
		["AudioTag"] = "AS2D_NARRATOR_SPEECH_PROLOGUE_ALIENS_EXPEDITIONS",
		["PrologueTexture"] = "prologue_exploration.dds";
		["OnStart"] = function() Controls.AffinityInfo:SetHide(true); end,
		["OnlyForNewGame"] = true,
	},
}

local g_loadScreenImages = {
	"DOM_EyeOfTheOrbiter_1920x1080.dds",
	"DOM_XenoTitan_Attack_1920x1080.dds",
	"DOM_Rig_Floatstone.dds",
	"DOM_Kraken_1920x1080.dds",
	"DOM_SiegeWorm_1920x1080.dds",
	"DOM_City_1920x1080.dds",
};

local g_bLoadComplete;

function OnShowHide( isHide, isInit )

	if ( not isInit ) then
		if ( isHide == true ) then
			UIManager:SetUICursor( 0 );
			Controls.BackgroundImage:UnloadTexture();
			--print("Texture is unloaded");
			if (iCivID ~= -1) then
				Events.SerialEventDawnOfManHide(iCivID);
			end
		else
			OnInitScreen();
			UIManager:SetUICursor( 1 );
			if (iCivID ~= -1) then
				Events.SerialEventDawnOfManShow(iCivID);        
			end
		end
	end
	
	if(not isHide) then
		UI.SetDontShowPopups(true);
	end
end


-- Controls.ProgressBar:SetPercent( 1 );

function OnInitScreen()
	
	g_bLoadComplete = false;
	
	Controls.ActivateButton:SetHide(true);

	Controls.DontShowAdvisorIntroCheckBox:SetCheck(OptionsManager.GetHideAdvisorIntro_Cached());
	Controls.TutorialLevelPull:ClearEntries();
	local tutorialLevels = GameplayUtilities.GetTutorialLevels();
	for i,level in ipairs(tutorialLevels) do
		local instance = {};
		Controls.TutorialLevelPull:BuildEntry("InstanceOne", instance);
		instance.Button:SetText(level);
		instance.Button:SetVoid1(i - 1);
	end
	Controls.TutorialLevelPull:CalculateInternals();
	Controls.TutorialLevelPull:GetButton():SetText(GameplayUtilities.GetTutorialLevels()[OptionsManager.GetTutorialLevel_Cached() + 1]);

	local civIndex = PreGame.GetCivilization( Game:GetActivePlayer() );
	
	local civ = GameInfo.Civilizations[civIndex];
	
	if(civ == nil) then
		PreGame.SetCivilization(0, -1);
	end
	
	if ( not PreGame.IsMultiplayerGame() ) then
		-- Force some settings off when loading a HotSeat game.
		PreGame.SetGameOption("GAMEOPTION_DYNAMIC_TURNS", false);
		PreGame.SetGameOption("GAMEOPTION_SIMULTANEOUS_TURNS", false);
		PreGame.SetGameOption("GAMEOPTION_PITBOSS", false);
	end	
	
	UpdateStartButtonText();

	-- Sets up Selected Civ Slot
	if( civ ~= nil ) then
		iCivID = civ.ID;

		-- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		local leaderDescription = leader.Description;

		-- Set Civ Icon
		SimpleCivIconHookup( Game.GetActivePlayer(), 64, Controls.CivIcon );

		-- Set a random Introduction Quote
		local introductionQuotes = {};
		local query = string.format("select * from Language_en_US where Tag Like '%s'", civ.IntroductionQuote);
		for row in DB.Query(query) do
			table.insert(introductionQuotes, row.Tag);
		end
		
		local quote = "ERROR NO QUOTE FOUND";
		if #introductionQuotes > 0 then
			quote = introductionQuotes[math.random(#introductionQuotes)];
		end		
		Controls.BackgroundText:LocalizeAndSetText(quote);

		local w : number = Controls.TextBacking:GetSizeX();
		local h : number = Controls.BackgroundText:GetSizeY() + 145;
		Controls.TextBacking:SetSizeVal(w, h);

		-- Sets Dawn of Man Image
		local screenWidth, screenHeight = UIManager:GetScreenSizeVal();
		Controls.BackgroundImage:SetSizeVal(((1920*screenHeight)/1080),screenHeight);
		local imagePath : string = g_loadScreenImages[math.random(#g_loadScreenImages)];
		Controls.BackgroundImage:SetTexture(imagePath);		
	end
end      


function OnActivateButtonClicked ()
	Controls.ActivateButton:SetHide(true);

	if (not OptionsManager.GetHideAdvisorIntro_Cached() and not UI:IsLoadedGame()) then
		StartIntro();
	else
		EndPrologue();
	end

	Controls.ActivateContainer:SetHide(true);
end
Controls.ActivateButton:RegisterCallback( Mouse.eLClick, OnActivateButtonClicked );

function OnIntroPlayButtonClicked ()
	OptionsManager.CommitGameOptions();
	PreGame.SetUsingFirstTimeUserExperience(false);
	EndPrologue();
end
Controls.IntroPlayButton:RegisterCallback(Mouse.eLClick, OnIntroPlayButtonClicked);

function OnIntroGuidedTourButtonClicked ()
	OptionsManager.CommitGameOptions();
	OptionsManager.ResetTutorial();
	PreGame.SetUsingFirstTimeUserExperience(true);
	Controls.IntroContainer:SetHide(true);
	StartPrologue();
end
Controls.IntroGuidedTourButton:RegisterCallback(Mouse.eLClick, OnIntroGuidedTourButtonClicked);

function OnPrologueButtonClicked ()
	AdvancePrologue();
end
Controls.PrologueButton:RegisterCallback( Mouse.eLClick, OnPrologueButtonClicked );

function OnDontShowAdvisorIntroCheckBox (isChecked)
	OptionsManager.SetHideAdvisorIntro_Cached(isChecked);
end
Controls.DontShowAdvisorIntroCheckBox:RegisterCheckHandler(OnDontShowAdvisorIntroCheckBox);

function OnTutorialLevelPull(level)
	OptionsManager.SetTutorialLevel_Cached(level);
	UpdateStartButtonText();
end
Controls.TutorialLevelPull:RegisterSelectionCallback(OnTutorialLevelPull);


function UpdateStartButtonText()
	local level = OptionsManager.GetTutorialLevel_Cached();
	local levelsTable = GameplayUtilities.GetTutorialLevels();

	Controls.TutorialLevelPull:GetButton():SetText(levelsTable[level + 1]);
	
	if (level == (#levelsTable - 1)) then
		Controls.IntroPlayButton:SetText(Locale.ToUpper(Locale.Lookup("TXT_KEY_BEGIN_GAME_BUTTON_CONTINUE")));
	else
		Controls.IntroPlayButton:SetText(Locale.ToUpper(Locale.Lookup("TXT_KEY_ADVISOR_INTRO_PLAY_NORMALLY")));
	end
end

function StartIntro()
	UI.PlayDawnOfManSound("AS2D_ADVISOR_SPEECH_INTRO_01");
	Controls.BackgroundAlphaAnim:Play();
	Controls.IntroContainer:SetHide(false);
end

function StartPrologue()
	g_iPrologueState = 0;
	AdvancePrologue();
end

function AdvancePrologue()
	g_iPrologueState = g_iPrologueState + 1;
	local prologueData = g_tPrologueStates[g_iPrologueState];
	if (prologueData == nil or (prologueData.OnlyForNewGame and UI:IsLoadedGame())) then
		EndPrologue();
	else
		-- Show next Prologue screen
		local titleText = prologueData.TitleText;
		local infoText = prologueData.InfoText;
		local buttonText = prologueData.ButtonText;
		if (titleText ~= nil) then
			Controls.Title:LocalizeAndSetText(titleText);
		end
		if (infoText ~= nil) then
			Controls.Info1:LocalizeAndSetText(infoText);
		end
		if (buttonText ~= nil) then
			Controls.PrologueButton:LocalizeAndSetText(buttonText);
		end
		if (prologueData.OnStart ~= nil) then
			prologueData.OnStart();
		end
		UI.StopDawnOfManSound();
		if (prologueData.AudioTag ~= nil) then
			UI.PlayDawnOfManSound(prologueData.AudioTag);	
		end
		Controls.PrologueImage:UnloadTexture();
		if (prologueData.PrologueTexture ~= nil) then
			Controls.PrologueImage:SetTexture(prologueData.PrologueTexture);
		end
	end
end

function EndPrologue()
	UI.StopDawnOfManSound();

	-- Prologue is complete, enter the game
	Controls.AllAlphaAnim:RegisterAnimCallback( OnAnimScreenOut );
	Controls.AllAlphaAnim:Play();
	--Controls.AllSlideAnim:Play();	
	--Controls.AllAlphaAnim:Play();
end

function OnAnimScreenOut()
	local pActivePlayer	= Players[Game.GetActivePlayer()];
	if ( Controls.AllAlphaAnim:IsStopped() ) then
	--print("Activate button clicked!");
		Events.LoadScreenClose();
		if (not PreGame.IsMultiplayerGame() and not PreGame.IsHotSeatGame()) then
			Game.SetPausePlayer(-1);
		end
	
		UI.SetDontShowPopups(false);
		--Controls.SlideAnim:Play();
		if(not pActivePlayer:IsObserver() 
			and pActivePlayer:IsAlive() 
			and not pActivePlayer:IsFoundedFirstCity()
			and pActivePlayer:IsTurnActive() 
			and UI.GetInterfaceMode() ~= InterfaceModeTypes.INTERFACEMODE_PLANETFALL) then 
			UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_PLANETFALL);
		end	
	else
		local plot		= pActivePlayer:GetStartingPlot();
		--UI.LookAt( plot, 1);	 -- CameraLookAtTypes.CAMERALOOKAT_CITY_ZOOM_IN
	end
end


-- ===========================================================================
--	Callback when slide animation is occuring
--	fComplete	How complete animation is (from 0.0 to 1.0)
-- ===========================================================================
--[[
function OnSlide( fComplete )
	if ( Controls.SlideAnim:IsStopped() ) then
		Controls.ActivateButton:SetHide(false);
	end
end
--]]


----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
function OnInput( uiMsg, wParam, lParam )
	if( uiMsg == KeyEvents.KeyDown ) then
		if( wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN ) then
			if (g_bLoadComplete) then
				if (Controls.ActivateButton:IsHidden()) then
					-- We are still on the "Intro" portion of the screen.  Hitting escape
					-- should be the same as pressing "Play"
					if( wParam == Keys.VK_ESCAPE ) then
						OnIntroPlayButtonClicked();
					else
						AdvancePrologue();
					end
				elseif (g_iPrologueState == -1) then
					OnActivateButtonClicked();
				end
			end
		end
	end

	VoiceChatInputHandler( uiMsg, wParam, lParam );
	return true;
end



function AllInitComplete()
	
	g_bLoadComplete = true;
	
	--[[ Camera zoom out to in for planet fall?
	local pPlayer	= Players[Game.GetActivePlayer()];
	local plot		= pPlayer:GetStartingPlot();	
	local x = plot:GetX();
	local y = plot:GetY() - 5;
	plot = Map.GetPlot(x , y);

	UI.LookAt( plot, 2 );	-- CameraLookAtTypes.
	]]

	if (PreGame.IsMultiplayerGame() or PreGame.IsHotSeatGame()) then
		EndPrologue();
	else
		Game.SetPausePlayer(Game.GetActivePlayer());
		--[[
		local strGameButtonName;
		if (not UI:IsLoadedGame()) then
			strGameButtonName = Locale.ConvertTextKey("{TXT_KEY_BEGIN_GAME_BUTTON:upper}");
		else
			strGameButtonName = Locale.ConvertTextKey("{TXT_KEY_BEGIN_GAME_BUTTON_CONTINUE:upper}");
		end
	
		Controls.ActivateButton:SetText(strGameButtonName);
		--]]
		--Controls.SlideAnim:Play();
		Controls.ActivateButton:SetHide(false);

		UIManager:SetUICursor( 0 );

		if( PreGame:GetAutorunTurnLimit() > 0 ) then

			OnActivateButtonClicked();

		end
		--[[
		-- Update Icons to now have tooltips.
		local civIndex = PreGame.GetCivilization( Game:GetActivePlayer() );
		local civ = GameInfo.Civilizations[civIndex];
	
		-- Sets up Selected Civ Slot
		if( civ ~= nil ) then
			
			-- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
			local leader = nil;
			for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
				leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
			end

			 -- Sets Bonus Icons
			local bonusText = PopulateUniqueBonuses( Controls, civ, leader, true, false);
		end
		--]]
	end
end


-- ===========================================================================
--	Game data initialized, finish any behind the scenes-screen updates.
function OnSequenceGameInitComplete()
	ContextPtr:SetUpdate( OnUpdate_TechTree );
end

-- ===========================================================================
function OnUpdate_TechTree()
	-- Tech tree is hidden so it does not update; give it a time slice via LUA Events.
	LuaEvents.LoadScreen_TechTreeGivenTimeSliceRemotely( OnGivenTimeSliceRemotely );
end

-- ===========================================================================
function OnTechTreeDoneLoading()
	ContextPtr:ClearUpdate();
	AllInitComplete();
end


-- ===========================================================================
function OnInit( isHotload:boolean )
end

-- ===========================================================================
function OnShutdown()
	LuaEvents.TechTree_OnDoneLoading.Remove( OnTechTreeDoneLoading );
end

-- ===========================================================================
function Initialize()

	-- UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInput );
	ContextPtr:SetShowHideHandler( OnShowHide );
	ContextPtr:SetShutdown( OnShutdown );

	Events.SequenceGameInitComplete.Add( OnSequenceGameInitComplete );
	LuaEvents.TechTree_OnDoneLoading.Add( OnTechTreeDoneLoading );
end
Initialize();
