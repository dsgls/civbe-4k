-------------------------------------------------
-- Select Civ Names
-------------------------------------------------

local g_EditSlot = 0;

local badPasswordStr = Locale.ConvertTextKey( "TXT_KEY_HOTSEAT_BAD_PASSWORD" );
local badCivNameStr = Locale.ConvertTextKey( "TXT_KEY_HOTSEAT_BAD_CIV_NAME" );
local passwordsNotMatchStr = Locale.ConvertTextKey( "TXT_KEY_HOTSEAT_PASSWORD_MISMATCH" );


-------------------------------------------------
-------------------------------------------------
function OnCancel()
    UIManager:PopModal( ContextPtr );
    ContextPtr:CallParentShowHideHandler( false );
    ContextPtr:SetHide( true );
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );


-------------------------------------------------
-------------------------------------------------
function OnAccept()

	-- Don't store the string if it is the same as the default.
   	local civIndex = PreGame.GetCivilization( g_EditSlot );
	local civ = nil;
	
	if(civIndex > -1 ) then
		civ = GameInfo.Civilizations[civIndex];
	end

	local szDefaultPlayerLeader = "";
	local szDefaultPlayerCiv = "";
	local szDefaultPlayerShortCiv = "";
	local szDefaultPlayerCivAdjective = "";
	
    if( civ ~= nil ) then        
        -- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		local leaderDescription = leader.Description;
		
		szDefaultPlayerLeader = Locale.ConvertTextKey( leaderDescription );
		szDefaultPlayerCiv = Locale.ConvertTextKey( civ.Description );
		szDefaultPlayerShortCiv = Locale.ConvertTextKey( civ.ShortDescription );
		szDefaultPlayerCivAdjective = Locale.ConvertTextKey( civ.Adjective );		
    else
    	szDefaultPlayerLeader = Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER" );
		szDefaultPlayerCiv = Locale.ConvertTextKey( "TXT_KEY_RANDOM_SPONSOR" );
		szDefaultPlayerShortCiv = szDefaultPlayerCiv;
		szDefaultPlayerCivAdjective = szDefaultPlayerCiv;		
	end
	
	if (Controls.EditCivLeader:GetText() ~= szDefaultPlayerLeader) then
		print("setting Leader Name");
		PreGame.SetLeaderName( g_EditSlot, Controls.EditCivLeader:GetText());
	end
	if (Controls.EditCivName:GetText() ~= szDefaultPlayerCiv) then
		print("setting civ Name");
		PreGame.SetCivilizationDescription( g_EditSlot, Controls.EditCivName:GetText());
	end
	if (Controls.EditCivShortName:GetText() ~= szDefaultPlayerShortCiv) then
		print("setting short Name");
		PreGame.SetCivilizationShortDescription( g_EditSlot, Controls.EditCivShortName:GetText());
	end
	if (Controls.EditCivAdjective:GetText() ~= szDefaultPlayerCivAdjective) then
		print("setting adj Name");
		PreGame.SetCivilizationAdjective( g_EditSlot, Controls.EditCivAdjective:GetText());
	end
    
    if ( PreGame.IsHotSeatGame() ) then
		PreGame.SetNickName( g_EditSlot, Controls.EditNickName:GetText() );
		if ( Controls.UsePasswordCheck:IsChecked() ) then
			PreGame.SetPassword( g_EditSlot, Controls.EditPassword:GetText() );
		else
			PreGame.SetPassword( g_EditSlot, "" );
		end		
	end
	
	Events.PreGameDirty();
	
	UIManager:PopModal( ContextPtr );
    ContextPtr:CallParentShowHideHandler( false );
    ContextPtr:SetHide( true );
end
Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept );


-------------------------------------------------
-------------------------------------------------
function OnUsePasswordCheck(bCheck)
	if(not bCheck) then
		-- when we say that we want to not use a password, blank out the password editboxes.
		Controls.EditPassword:SetText("");
		Controls.EditRetypePassword:SetText("");
		Validate();
	end
end
Controls.UsePasswordCheck:RegisterCheckHandler(OnUsePasswordCheck);


----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE then
            OnCancel();  
        end
        if wParam == Keys.VK_RETURN then
            OnAccept();  
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );


----------------------------------------------------------------
----------------------------------------------------------------
function ValidateText(text)
	if(text == nil) then
		return false;
	end

	local isAllWhiteSpace = true;
	for i = 1, #text, 1 do
		if(string.byte(text, i) ~= 32) then
			isAllWhiteSpace = false;
			break;
		end
	end
	
	if(isAllWhiteSpace) then
		return false;
	end
	
	-- don't allow % character
	for i = 1, #text, 1 do
		if string.byte(text, i) == 37 then
			return false;
		end
	end
	
	local invalidCharArray = { '\"', '<', '>', '|', '\b', '\0', '\t', '\n', '/', '\\', '*', '?' };

	for i, ch in ipairs(invalidCharArray) do
		if(string.find(text, ch) ~= nil) then
			return false;
		end
	end
	
	-- don't allow control characters
	for i = 1, #text, 1 do
		if (string.byte(text, i) < 32) then
			return false;
		end
	end

	return true;
end

function SetAcceptButton(bDisabled, bBadPassword, bPasswordsMatch, bBadCivNames)
	Controls.AcceptButton:SetDisabled( bDisabled );   	
	if(bDisabled) then
		local reasonStr = "";
		if(bBadCivNames) then
			reasonStr = reasonStr .. badCivNameStr;
		end
		if(bBadPassword) then
			if(reasonStr ~= "") then
				reasonStr = reasonStr .. "[NEWLINE]";
			end
			reasonStr = reasonStr .. badPasswordStr;
		end
		if(not bPasswordsMatch) then
			if(reasonStr ~= "") then
				reasonStr = reasonStr .. "[NEWLINE]";
			end
			reasonStr = reasonStr .. passwordsNotMatchStr;
		end
		Controls.AcceptButton:SetToolTipString(reasonStr);
	else
		Controls.AcceptButton:LocalizeAndSetToolTip("");
	end
end

---------------------------------------------------------------
function Validate()
	local bValid = false;
	local bBadPassword = false;
	local bPassMatch = true;
	local bBadCivNames = false;

	-- Update Use Password checkbox
	local editPassStr = Controls.EditPassword:GetText();
	local retypePassStr = Controls.EditRetypePassword:GetText();
	if ((editPassStr ~= nil and editPassStr ~= "") or (retypePassStr ~= nil and retypePassStr ~= "")) then
		Controls.UsePasswordCheck:SetCheck( true );
	end

	if(	ValidateText(Controls.EditCivShortName:GetText()) and
		ValidateText(Controls.EditCivLeader:GetText()) and
		ValidateText(Controls.EditCivName:GetText()) and
		ValidateText(Controls.EditCivAdjective:GetText())) then	
		if ( PreGame.IsHotSeatGame() ) then
			local nickName = Controls.EditNickName:GetText();
			if ( nickName == nil or ValidateText(nickName) ) then -- must use default or valid nickname.
				-- Using a password?
				if ( Controls.UsePasswordCheck:IsChecked() ) then
					-- Must be valid and the two fields must match
					if ( ValidateText(editPassStr) and editPassStr ~= "" ) then
						if ( editPassStr == retypePassStr ) then
							bValid = true;
						else 
							bPassMatch = false;
						end
					else
						bBadPassword = true;
					end
				else
					bValid = true;
				end
			else
				bBadCivNames = true;
			end
		else			
			bValid = true;
		end
	else
		bBadCivNames = true;
	end
	
	SetAcceptButton(not bValid, bBadPassword, bPassMatch, bBadCivNames);
end
---------------------------------------------------------------
Controls.EditCivName:RegisterStringChangedCallback(Validate);
Controls.EditCivLeader:RegisterStringChangedCallback(Validate);
Controls.EditCivShortName:RegisterStringChangedCallback(Validate);
Controls.EditCivAdjective:RegisterStringChangedCallback(Validate);
Controls.EditNickName:RegisterStringChangedCallback(Validate);
Controls.EditPassword:RegisterStringChangedCallback(Validate);
Controls.EditRetypePassword:RegisterStringChangedCallback(Validate);


----------------------------------------------------------------
----------------------------------------------------------------
function LoadDefaults()

   	local civIndex = PreGame.GetCivilization( g_EditSlot );
	local civ = nil;
	
	if(civIndex > -1 ) then
		civ = GameInfo.Civilizations[civIndex];
		if(civ == nil) then
			PreGame.SetCivilization(g_EditSlot, -1);
		end
	end
	
    if( civ ~= nil ) then
        
        -- Use the Civilization_Leaders table to cross reference from this civ to the Leaders table
		local leader = nil;
		for leaderRow in GameInfo.Civilization_Leaders{CivilizationType = civ.Type} do
			leader = GameInfo.Leaders[ leaderRow.LeaderheadType ];
		end
		local leaderDescription = leader.Description;
		
		PlayerLeader = Locale.ConvertTextKey( leaderDescription );
		PlayerCiv = Locale.ConvertTextKey( civ.Description );
		PlayerShortCiv = Locale.ConvertTextKey( civ.ShortDescription );
		PlayerCivAdjective = Locale.ConvertTextKey( civ.Adjective );
		Controls.EditCivLeader:SetText( PlayerLeader );
        Controls.EditCivName:SetText( PlayerCiv );
        Controls.EditCivShortName:SetText( PlayerShortCiv );
        Controls.EditCivAdjective:SetText( PlayerCivAdjective );
    else
    	PlayerLeader = Locale.ConvertTextKey( "TXT_KEY_RANDOM_LEADER" );
		PlayerCiv = Locale.ConvertTextKey( "TXT_KEY_RANDOM_SPONSOR" );
		Controls.EditCivLeader:SetText( PlayerLeader );
        Controls.EditCivName:SetText( PlayerCiv );
        Controls.EditCivShortName:SetText( PlayerCiv );
        Controls.EditCivAdjective:SetText( PlayerCiv );
	end

	local name = PreGame.GetLeaderName(g_EditSlot);
	if(name ~= "") then
		Controls.EditCivLeader:SetText( name );
	end
	
	name = PreGame.GetCivilizationDescription(g_EditSlot);
	if(name ~= "") then
		Controls.EditCivName:SetText( name );
	end
	
	name = PreGame.GetCivilizationShortDescription(g_EditSlot);
	if(name ~= "") then
		Controls.EditCivShortName:SetText( name );
	end
	
	name = PreGame.GetCivilizationAdjective(g_EditSlot);
	if(name ~= "") then
		Controls.EditCivAdjective:SetText( name );
	end
	
    if ( PreGame.IsHotSeatGame() ) then
		name = PreGame.GetNickName( g_EditSlot );
		if(name ~= "") then
			Controls.EditNickName:SetText( name );
		end
		
		name = PreGame.GetPassword( g_EditSlot );
		Controls.EditPassword:SetText( name );
		Controls.EditRetypePassword:SetText( name );
		
		Controls.UsePasswordCheck:SetCheck( name ~= "" ); 
	end
	
end

-------------------------------------------------
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
    
    if( not bIsHide ) then
		local bIsHotSeat = PreGame.IsHotSeatGame();
		Controls.NickName:SetHide(not bIsHotSeat);
		Controls.NickNameEditbox:SetHide(not bIsHotSeat);
		Controls.PasswordStack:SetHide(not bIsHotSeat);
				
		-- Adjust the overall size of the box
		local iBoxHeight = 808;
		if ( bIsHotSeat ) then
			iBoxHeight = 1168;
		end
		
		local frameSize = {};
--		frameSize = Controls.MainBox:GetSize();
		frameSize.y = iBoxHeight;
--		Controls.MainBox:SetSize( frameSize );
		frameSize = Controls.BackgroundBox:GetSize();
		frameSize.y = iBoxHeight;
		Controls.BackgroundBox:SetSize( frameSize );
--		frameSize = Controls.FrameBox:GetSize();
		frameSize.y = iBoxHeight;
--		Controls.FrameBox:SetSize( frameSize );
		
        LoadDefaults();
				Validate();
        
		if (bIsHotSeat) then
			Controls.EditNickName:TakeFocus();
		else
			Controls.EditCivLeader:TakeFocus();
		end        
	end

end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
LuaEvents.SetCivNameEditSlot.Add(function(iSlot)
	if(iSlot > -1 ) then
		g_EditSlot = iSlot;
		LoadDefaults();
	end
end);
       
LoadDefaults();


