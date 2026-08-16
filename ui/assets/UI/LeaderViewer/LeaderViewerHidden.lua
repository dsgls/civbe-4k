function OnExitGame()
	UI.ExitGame();
end
Events.UserRequestClose.Add( OnExitGame );