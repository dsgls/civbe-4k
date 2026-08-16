------------------------------------------------- 
-- Voice Chat Logic (Input/Event Handling)
-------------------------------------------------


-------------------------------------------------
-- Globals
-------------------------------------------------
local m_bHoldingGlobalVCButton = false;	--holding the global voice chat button.
local m_bHoldingTeamVCButton = false;		--holding down the team voice chat button.

-------------------------------------------------
-- Helper Functions
-------------------------------------------------			
function UpdateVoiceChat( iPlayerID, voiceChatIcon, chatting, teamChat )
	if(chatting) then
		voiceChatIcon:SetHide(false);
		if(teamChat) then
			voiceChatIcon:SetTextureOffsetVal(32,0);
		else
			voiceChatIcon:SetTextureOffsetVal(0,0);
		end
	else
		voiceChatIcon:SetHide(true);
	end
end


-------------------------------------------------
-- Input Functions
-------------------------------------------------	
function VoiceChatInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if (wParam == Keys.V) then
			--print("Global voice chat key down");
			m_bHoldingGlobalVCButton = true;
			if( not m_bHoldingTeamVCButton ) then
				-- team chat has higher priority than global chat.
				Network.SetVoiceChatTalkMode(VoiceChatTalkMode.VOICECHAT_GLOBAL);
			end
			return true;
		elseif (wParam == Keys.X) then
			--print("Team voice chat key down");
			m_bHoldingTeamVCButton = true;
			Network.SetVoiceChatTalkMode(VoiceChatTalkMode.VOICECHAT_TEAM);
			return true;
		end
	end
	
  if( uiMsg == KeyEvents.KeyUp ) then
		if (wParam == Keys.V) then
			--print("Global voice chat key up");
			m_bHoldingGlobalVCButton = false;
			if( not m_bHoldingTeamVCButton ) then
				-- toggle off voice chat team mode if no vc buttons are being held.
				Network.SetVoiceChatTalkMode(VoiceChatTalkMode.VOICECHAT_NONE);
			end
			return true;
		elseif (wParam == Keys.X) then
			--print("Team voice chat key up");
			m_bHoldingTeamVCButton = false;
			if( not m_bHoldingGlobalVCButton ) then
				-- toggle off voice chat team mode if no vc buttons are being held.
				Network.SetVoiceChatTalkMode(VoiceChatTalkMode.VOICECHAT_NONE);
			end
			return true;
		end
	end

	return false;
end