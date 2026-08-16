-------------------------------------------------
-- End-game screen
-------------------------------------------------
include( "IconSupport" );
include( "TabSupport" );
include( "CommonBehaviors" );

local FadeType : table = { IN = 1, OUT = 2 };

local HARMONY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_HARMONY"].ID;
local PURITY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_PURITY"].ID;
local SUPREMACY_AFFINITY_TYPE : number = GameInfo.Affinity_Types["AFFINITY_TYPE_SUPREMACY"].ID;
local LOSS_BINK_PATH : string = "GameOverLost.bk2";

local m_subtitledLanguages =
{
	["ja_JP"] = true,
	["ko_KR"] = true,
	["zh_Hans_CN"] = true,
	["zh_Hant_HK"] = true,
};

local m_subtitleTextKeys = 
{
	["Domination"] = 
	{
		"TXT_KEY_VICTORY_MESSAGE_DOMINATION_SUBTITLE1",
		"TXT_KEY_VICTORY_MESSAGE_DOMINATION_SUBTITLE2",
		"TXT_KEY_VICTORY_MESSAGE_DOMINATION_SUBTITLE3",
	},
	["Contact"] = 
	{
		"TXT_KEY_VICTORY_MESSAGE_CONTACT_SUBTITLE1",
		"TXT_KEY_VICTORY_MESSAGE_CONTACT_SUBTITLE2",
		"TXT_KEY_VICTORY_MESSAGE_CONTACT_SUBTITLE3",
	},
	["PromisedLand"] = 
	{
		"TXT_KEY_VICTORY_MESSAGE_PROMISED_LAND_SUBTITLE1",
		"TXT_KEY_VICTORY_MESSAGE_PROMISED_LAND_SUBTITLE2",
		"TXT_KEY_VICTORY_MESSAGE_PROMISED_LAND_SUBTITLE3",
	},
	["Emancipation"] = 
	{
		"TXT_KEY_VICTORY_MESSAGE_EMANCIPATION_SUBTITLE1",
		"TXT_KEY_VICTORY_MESSAGE_EMANCIPATION_SUBTITLE2",
		"TXT_KEY_VICTORY_MESSAGE_EMANCIPATION_SUBTITLE3",
	},
	["Transcendence"] = 
	{
		"TXT_KEY_VICTORY_MESSAGE_TRANSCENDENCE_SUBTITLE1",
		"TXT_KEY_VICTORY_MESSAGE_TRANSCENDENCE_SUBTITLE2",
		"TXT_KEY_VICTORY_MESSAGE_TRANSCENDENCE_SUBTITLE3",
	},
	["Loss"] = 
	{
		"TXT_KEY_VICTORY_FLAVOR_LOSS_SUBTITLE1",
		"TXT_KEY_VICTORY_FLAVOR_LOSS_SUBTITLE2",
		"TXT_KEY_VICTORY_FLAVOR_LOSS_SUBTITLE3",
	},
};

local m_player : object = nil;
local m_isPlayingMovie : boolean = false;
local m_showSubtitles : boolean = false;
local m_gameOverData : table = nil;
local m_isDebug : boolean = false;

function Fade(fadeType : number, onComplete : ifunction)
	Controls.FadeAlphaAnim:SetHide(false);
	Controls.FadeAlphaAnim:Stop();
	Controls.FadeAlphaAnim:SetToBeginning();
	Controls.FadeAlphaAnim:RegisterEndCallback(onComplete);

	if (fadeType == FadeType.IN and not Controls.FadeAlphaAnim:IsReversing()) then
		Controls.FadeAlphaAnim:Reverse();
	elseif (fadeType == FadeType.OUT and Controls.FadeAlphaAnim:IsReversing()) then
		Controls.FadeAlphaAnim:Reverse();
	else
		Controls.FadeAlphaAnim:Play();
	end
end

function OnMovieFrame(frameNumber : number, totalFrames : number)
	if (not m_showSubtitles or m_gameOverData.Subtitles == nil) then
		return;
	end

	if (totalFrames == 0) then
		return;
	end

	local subtitles : table = m_gameOverData.Subtitles;

	local percent : number = frameNumber / totalFrames;
	local subtitleIndex : number = math.floor(#subtitles * percent) + 1;
	if (subtitleIndex <= #subtitles) then
		local textKey : string = subtitles[subtitleIndex];
		Controls.Subtitles:SetText(Locale.Lookup(textKey));
	end
end

function DoEndGameMovie()
	if (m_gameOverData.DidWin) then
		Game.PlayMusicEvent(m_player:GetID(), GameDefines["MUSIC_EVENT_VICTORY"]);
		if (m_gameOverData.VictoryInfo.Audio ~= nil) then
			Events.AudioPlay2DSound(m_gameOverData.VictoryInfo.Audio);
		end
	else
		Game.PlayMusicEvent(m_player:GetID(), GameDefines["MUSIC_EVENT_DEFEAT"]);
		Events.AudioPlay2DSound("AS2D_DEFEAT_SPEECH");
	end

	if (m_gameOverData.ShouldPlayMovie and m_gameOverData.Movie ~= nil) then
		-- See if we should play subtitles
		local languageInfo : table = Locale.GetCurrentLanguage();
		m_showSubtitles = m_subtitledLanguages[languageInfo.Type] == true;

		-- Face and play movie
		m_isPlayingMovie = true;
		Fade(FadeType.OUT, function() 
			Controls.Movie:SetHide(false);
			Controls.Subtitles:SetHide(not m_showSubtitles);
			Controls.Subtitles:SetText("");
			Controls.Movie:SetMovie(m_gameOverData.Movie);
			Controls.Movie:ReprocessAnchoring();
			Controls.Movie:SetMovieFrameCallback(OnMovieFrame);
			Controls.Movie:SetMovieFinishedCallback(function() 
				m_isPlayingMovie = false;
				Controls.Movie:MovieClose();
				Controls.Movie:SetHide(true);
				Controls.Subtitles:SetHide(true);

				DoEndGameMenu();
			end);
		end);
	else
		DoEndGameMenu();
	end
end

function DoEndGameMenu()
	if (m_isPlayingMovie) then
		-- Stop movie	
		m_isPlayingMovie = false;
		Controls.Movie:SetHide(true);
	end

	Events.BlurStateChange(0);
	print("GameOver, Blur On");

	Controls.FadeAlphaAnim:SetHide(true);
	Controls.Movie:SetHide(true);
	Controls.BGBlock:SetHide(false);
	Controls.GameOverContent:SetHide(false);
	Controls.AlphaAnim:SetToBeginning();
	Controls.AlphaAnim:Play();

	if (m_gameOverData.Image ~= nil) then
		Controls.Banner:SetTexture(m_gameOverData.Image);
	end

	if (m_gameOverData.VictoryInfo ~= nil) then
		Controls.Header:SetText(Locale.Lookup(m_gameOverData.VictoryInfo.VictoryStatement));
	else
		Controls.Header:SetText(Locale.Lookup("TXT_KEY_DEFEAT_BANG"));
	end

	local civInfo : table = GameInfo.Civilizations[m_player:GetCivilizationType()];
	CivIconHookup(m_player:GetID(), 64, Controls.CivIcon, Controls.CivIconBG, nil, false, false, Controls.CivIconHighlight);
	IconHookup(civInfo.PortraitIndex, 128, civInfo.AlphaIconAtlas, Controls.BigCivIcon);
	Controls.Name:SetText(Locale.Lookup(m_player:GetNameKey()));
	Controls.CivName:SetText(Locale.Lookup(civInfo.Description));

	if (m_gameOverData.Text ~= nil) then
		Controls.Text:SetHide(false);
		Controls.Text:SetText(m_gameOverData.Text);
	else
		Controls.Text:SetHide(true);
	end

	local sizeY : number = Controls.Text:GetSizeY() + 300;
	Controls.GameOverContent:SetSizeY(sizeY);
	Controls.GameOverContent:ReprocessAnchoring();

	Controls.MainMenuButton:RegisterCallback(Mouse.eLClick, function() 
		Close();

		if (m_isDebug) then
			return;
		end

		if (Game.IsHotSeat() and Game.CountHumanPlayersAlive() > 0) then
			local activePlayer : number = Game.GetActivePlayer();
			local player : object = Players[activePlayer];

			if (not player:IsAlive()) then
				local found : boolean = false;

				local nextPlayer : number = activePlayer + 1;
				for playerLoop : number = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
					if (nextPlayer >= GameDefines.MAX_MAJOR_CIVS) then
						nextPlayer = 0;
					end

					player = Players[nextPlayer];
					if (activePlayer ~= nextPlayer and player:IsAlive() and player:IsHuman()) then
						Game.SetActivePlayer(nextPlayer);
						Game.SetGameState(GameplayGameStateTypes.GAMESTATE_ON);
						found = true;
						break;
					end
					nextPlayer = nextPlayer + 1;
				end

				if (not found) then
					Events.ExitToMainMenu();
				end
			else
				Events.ExitToMainMenu();
			end
		else
			Events.ExitToMainMenu();
		end
	end);

	Controls.KeepPlayingButton:RegisterCallback(Mouse.eLClick, function()
		Close();

		if (m_isDebug) then
			return;
		end
			
		Network.SendExtendedGame();
	end);

	Controls.KeepPlayingButton:SetHide(not m_gameOverData.AllowBack);
	
	Controls.ButtonStack:CalculateSize();
	Controls.ButtonStack:ReprocessAnchoring();
end

function Close()
	UIManager:DequeuePopup(ContextPtr);
	Controls.Banner:UnloadTexture();
end

function GetGameOverData(endGameType : number, teamType : number)
	local data : table = {};

	data.EndGameType = endGameType;
	data.ShouldPlayMovie = teamType ~= -1;
	data.TeamType = teamType;
	data.DidWin = teamType == m_player:GetTeam();
	data.Text = "";
	data.AllowBack = false;

	if (data.DidWin) then
		if (endGameType == EndGameTypes.Time) then
			data.VictoryInfo = GameInfo.Victories["VICTORY_TIME"];
			data.Image = "GameOverBannerTime.dds";
			data.Movie = nil;
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_MESSAGE_TIME");
			data.Subtitles = nil
		elseif (endGameType == EndGameTypes.Domination) then
			data.VictoryInfo = GameInfo.Victories["VICTORY_DOMINATION"];
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_MESSAGE_DOMINATION");
			data.Subtitles = m_subtitleTextKeys.Domination;

			local affinityType : number = m_player:GetDominantAffinityType();
		
			if (affinityType == HARMONY_AFFINITY_TYPE) then
				data.Image = "GameOverBannerDominationHarmony.dds";
				data.Movie = Game.GetLocalizedFile("GameOverDominationHarmony.bk2");
			elseif (affinityType == PURITY_AFFINITY_TYPE) then
				data.Image = "GameOverBannerDominationPurity.dds";
				data.Movie = Game.GetLocalizedFile("GameOverDominationPurity.bk2");
			elseif (affinityType == SUPREMACY_AFFINITY_TYPE) then
				data.Image = "GameOverBannerDominationSupremacy.dds";
				data.Movie = Game.GetLocalizedFile("GameOverDominationSupremacy.bk2");
			else
				data.Image = "GameOverBannerDominationPurity.dds";
				data.Movie = nil;
			end
		elseif (endGameType == EndGameTypes.Contact) then
			data.VictoryInfo = GameInfo.Victories["VICTORY_CONTACT"];
			data.Image = "GameOverBannerContact.dds";
			data.Movie = Game.GetLocalizedFile("GameOverContact.bk2");
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_MESSAGE_CONTACT");
			data.Subtitles = m_subtitleTextKeys.Contact;
		elseif (endGameType == EndGameTypes.PromisedLand) then
			data.VictoryInfo = GameInfo.Victories["VICTORY_PROMISED_LAND"];
			data.Image = "GameOverBannerPurity.dds";
			data.Movie = Game.GetLocalizedFile("GameOverPurity.bk2");
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_MESSAGE_PROMISED_LAND");
			data.Subtitles = m_subtitleTextKeys.PromisedLand;
		elseif (endGameType == EndGameTypes.Emancipation) then
			data.VictoryInfo = GameInfo.Victories["VICTORY_EMANCIPATION"];
			data.Image = "GameOverBannerSupremacy.dds";
			data.Movie = Game.GetLocalizedFile("GameOverSupremacy.bk2");
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_MESSAGE_EMANCIPATION");
			data.Subtitles = m_subtitleTextKeys.Emancipation;
		elseif (endGameType == EndGameTypes.Transcendence) then
			data.VictoryInfo = GameInfo.Victories["VICTORY_TRANSCENDENCE"];
			data.Image = "GameOverBannerHarmony.dds";
			data.Movie = Game.GetLocalizedFile("GameOverHarmony.bk2");
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_MESSAGE_TRANSCENDENCE");
			data.Subtitles = m_subtitleTextKeys.Transcendence;
		end

		if(data.VictoryInfo ~= nil and PreGame.GetGameOption("GAMEOPTION_NO_EXTENDED_PLAY") ~= 1) then
			data.AllowBack = true;
		else
			data.AllowBack = false;
		end
	else
		data.Image = "GameOverBannerLost.dds";
		data.Movie = Game.GetLocalizedFile("GameOverLost.bk2");

		if (teamType ~= -1) then
			local winningCivNameKey : string = Teams[teamType]:GetNameKey();

			if (endGameType == EndGameTypes.Time) then
				data.Text = Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_TIME", winningCivNameKey);
			elseif (endGameType == EndGameTypes.Domination) then
				data.Text = Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_DOMINATION", winningCivNameKey);
			elseif (endGameType == EndGameTypes.Contact) then
				data.Text = Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_CONTACT", winningCivNameKey);
			elseif (endGameType == EndGameTypes.PromisedLand) then
				data.Text = Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_PROMISED_LAND", winningCivNameKey);
			elseif (endGameType == EndGameTypes.Emancipation) then
				data.Text = Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_EMANCIPATION", winningCivNameKey);
			elseif (endGameType == EndGameTypes.Transcendence) then
				data.Text = Locale.ConvertTextKey("TXT_KEY_DEFEAT_MESSAGE_TRANSCENDENCE", winningCivNameKey);
			end

			data.Text = data.Text .. "[NEWLINE][NEWLINE]";
			data.Text = data.Text .. Locale.ConvertTextKey("TXT_KEY_VICTORY_FLAVOR_LOSS");
		else
			data.ShouldPlayMovie = true;
			data.Text = Locale.ConvertTextKey("TXT_KEY_VICTORY_FLAVOR_LOSS");
		end

		data.Subtitles = m_subtitleTextKeys.Loss;

		if (not Game.IsNetworkMultiPlayer() and Players[Game.GetActivePlayer()]:IsAlive() and PreGame.GetGameOption("GAMEOPTION_NO_EXTENDED_PLAY") ~= 1) then
			if	(endGameType == EndGameTypes.Contact) or
				(endGameType == EndGameTypes.PromisedLand) or
				(endGameType == EndGameTypes.Emancipation) or
				(endGameType == EndGameTypes.Transcendence) or
				(endGameType == EndGameTypes.Domination) or
				(endGameType == EndGameTypes.Time) 
				--( endGameType == EndGameTypes.Loss ) then	-- Also will be set if user chooses to retire game.
			then
				
				data.AllowBack = true;
			end
		end
	end

	return data;
end

-------------------------------------------------
-- Context Callbacks
-------------------------------------------------
function ShowHideHandler(isHide : boolean, isInit : boolean) 
	if (isInit) then
		return;
	end

	if (not isHide) then
		LuaEvents.GameOverShown();

		UI.incTurnTimerSemaphore();

		Controls.GameOverContent:SetHide(true);
		Controls.Movie:SetHide(true);
		Controls.BGBlock:SetHide(true);

		DoEndGameMovie();
	else
		LuaEvents.GameOverHidden();

		Events.BlurStateChange(1);
		print("GameOver, Blur Off");
		UI.decTurnTimerSemaphore();
		Controls.Banner:UnloadTexture();

		UI.StopAllSpeech(true);
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function InputHandler(msg : number, wParam : number, lParam : number)
	if (msg == KeyEvents.KeyDown) then
		if (wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN) then
			if (m_isPlayingMovie) then
				DoEndGameMenu();
			elseif (m_isDebug) then
				Close();
			end

			return true;
		end
	end
end
ContextPtr:SetInputHandler(InputHandler)

function OnInitialize(isHotLoad : boolean)
	-- Register events
	Events.EndGameShow.Add(OnEndGameShow);
	LuaEvents.DebugEndGameShow.Add(OnDebugEndGameShow);

	Controls.Subtitles:SetWrapWidth(ContextPtr:GetSizeX() - 15);
end
ContextPtr:SetInitHandler(OnInitialize);

function OnShutdown()
	-- Unregister events
	Events.EndGameShow.Remove(OnEndGameShow);
	LuaEvents.DebugEndGameShow.Remove(OnDebugEndGameShow);
end
ContextPtr:SetShutdown(OnShutdown);

-------------------------------------------------
-- Event listeners
-------------------------------------------------
function __EndGameShow(endGameType : number, teamType : number)
	-- This does nothing other than tell other popups to close
	Events.SerialEventGameMessagePopup{
		Type = ButtonPopupTypes.BUTTONPOPUP_END_MENU,
	};

	m_player = Players[Game.GetActivePlayer()];
	m_gameOverData = GetGameOverData(endGameType, teamType);
	
	UIManager:SetUICursor(0);
	UIManager:QueuePopup(ContextPtr, PopupPriority.EndGameMenu);
end

function OnEndGameShow(endGameType : number, teamType : number, playMusic : boolean)
	m_isDebug = false;
	__EndGameShow(endGameType, teamType);
end

function OnDebugEndGameShow(endGameType : number, teamType : number, playMusic : boolean)
	m_isDebug = true;
	__EndGameShow(endGameType, teamType);
end