--------------------------------------
-- TurnStatusBehavior.lua
-- Contains helpers for implementing turn status buttons
-- 
-- Requirements:
--  The turn status buttons must exist in table with properly named sub-elements
--		controlInstance.ActiveTurnAnim - alpha animation for fading the buttons.
--------------------------------------

----------------------------------------------
-- Get the current progress of the turn status animations.
function GetTurnStatusAnimProgress( controlInstances )
    for iSlot, curInstance in pairs( controlInstances ) do
			if(not curInstance.ActiveTurnAnim:IsStopped()) then
				return curInstance.ActiveTurnAnim:GetProgress();			
			end
    end	
    
    return 0;
end

----------------------------------------------
-- Check to see if the current turn status animation is reversing.
function GetTurnStatusAnimIsReversing( controlInstances )
-- determine if the currently playing active turn animations are playing in reverse.
    for iSlot, curInstance in pairs( controlInstances ) do
			if(not curInstance.ActiveTurnAnim:IsStopped()) then
				return curInstance.ActiveTurnAnim:IsReversing();			
			end
    end	
    
    return 0;
end

----------------------------------------------
function UpdateTurnStatus( pPlayer, iconBox, activeTurnAnim, controlInstances )
	if( PreGame.GameStarted() and pPlayer ~= nil ) then
		if( not pPlayer:IsAlive()
			or pPlayer:HasReceivedNetTurnComplete() -- Human player finished with turn
			or (not pPlayer:IsHuman() and not pPlayer:IsTurnActive())  ) then -- AI player finished with turn
			iconBox:SetAlpha( 0.2 );
			activeTurnAnim:SetToBeginning();
		else
			iconBox:SetAlpha( 1 );
			if(pPlayer:IsTurnActive() and not pPlayer:HasTurnTimerExpired()) then
				if(activeTurnAnim:IsStopped()) then
					-- Start playing turn active animation, but make sure it's in sync with the other turn active animations.				
					if(GetTurnStatusAnimIsReversing(controlInstances)) then
						-- current turn active animations are reversed.
						activeTurnAnim:Reverse();
					end
					activeTurnAnim:SetProgress(GetTurnStatusAnimProgress(controlInstances));
					activeTurnAnim:Play();
				end
			else 
				activeTurnAnim:SetToBeginning();
			end
		end
	end
end