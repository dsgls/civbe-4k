----------------------------------------------------------------        
----------------------------------------------------------------        

include( "IconSupport" );
include( "SupportFunctions" );
include( "GameplayUtilities" );
include( "InfoTooltipInclude" );

function ShowHideHandler(isHide, isInit)
end
ContextPtr:SetShowHideHandler(ShowHideHandler);

function OnGameInitComplete()
	ContextPtr:SetHide(false);
end
Events.SequenceGameInitComplete.Add(OnGameInitComplete);

local s_AnimatingIn = false;
local s_AnimatingOut = false;

-- ===========================================================================
--	Animate all controls for when the screen first comes up
--	Kicked off by the game engine
-- ===========================================================================
function OnAnimateIn(control : object, progress : number)
	
	if( UI.GetLeaderHeadRootUp() == false ) then
		UI.SetLeaderHeadRootUp(true);
		Controls.GamestateTransitionAnimOut:SetToEnd();
		Controls.GamestateTransitionAnimOut:Stop();
		s_AnimatingIn = true;
		s_AnimatingOut = false;
	end

	if(progress >= 1 and s_AnimatingIn == true) then
		s_AnimatingIn = false;
		LuaEvents.Diplomacy_Open();
	end

end
Controls.GamestateTransitionAnimIn:RegisterAnimCallback( OnAnimateIn );

-- ===========================================================================
--	Animate all controls for when the screen is being dismissed
-- ===========================================================================
function OnAnimateOut(control : object, progress : number)

	if( UI.GetLeaderHeadRootUp() == true ) then
		Controls.GamestateTransitionAnimIn:SetToEnd();
		Controls.GamestateTransitionAnimIn:Stop();
		UI.SetLeaderHeadRootUp(false);
		s_AnimatingIn = false;
		s_AnimatingOut = true;
	end

	if(progress >= 1 and s_AnimatingOut == true) then
		s_AnimatingOUt = false;
		LuaEvents.Diplomacy_Close();
	end
end
Controls.GamestateTransitionAnimOut:RegisterAnimCallback( OnAnimateOut );