-- ===========================================================================
-- FiraxisLive / My2k
-- ===========================================================================

include( "InstanceManager" );



-- ===========================================================================
--	DEFINES
-- ===========================================================================

local SIZE_DIALOG_ART_SPACE_Y = 128+30+30;	-- For resizing based on contents

local DIALOG_MAIN_MENU		= 1;
local DIALOG_LOGIN			= 2;
local DIALOG_NEW_USER		= 3;		-- email / dob
local DIALOG_USER_NAME		= 4;
local DIALOG_DOB			= 5;
local DIALOG_LEGAL			= 6;
local DIALOG_LEGAL_ITEM		= 7;
local DIALOG_LOGOUT			= 8;
-- all Dialogs below here must be message only dialogs
local DIALOG_MESSAGE		= 9;
local DIALOG_LOGGED_OUT		= 10;


-- ===========================================================================
--	MEMBERS
--	TODO:	Consider making the managers local to an Initialize and keeping
--			the dialogs themselves.
-- ===========================================================================
local m_2KMainMenuManager		= InstanceManager:new( "2KMainMenuInstance",		"Dialog",		Controls.My2KBG );
local m_LoginDialogManager		= InstanceManager:new( "LoginDialogInstance", 	 	"Dialog", 		Controls.My2KBG );
local m_NewUserDialogManager	= InstanceManager:new( "NewUserDialogInstance", 	"Dialog", 		Controls.My2KBG );
local m_UserNameDialogManager	= InstanceManager:new( "UserNameDialogInstance",	"Dialog",		Controls.My2KBG );
local m_DOBDialogManager		= InstanceManager:new( "DOBDialogInstance",			"Dialog",		Controls.My2KBG );
local m_LegalDialogManager		= InstanceManager:new( "LegalDialogInstance", 	 	"Dialog", 		Controls.My2KBG );
local m_LegalItemDialogManager	= InstanceManager:new( "LegalItemDialogInstance",	"Dialog",		Controls.My2KBG );
local m_MessageDialogManager	= InstanceManager:new( "MessageDialogInstance", 	"Dialog", 		Controls.My2KBG );
local m_LogoutDialogManager		= InstanceManager:new( "LogoutDialogInstance", 	 	"Dialog", 		Controls.My2KBG );

local m_currentDialogID			= DIALOG_MAIN_MENU;
local m_currentDialog			= nil;
local m_currentDialogData		= nil;
local m_legalItemIndex			= -1;

local m_bESCEnabled				= true;
local m_CancelFunction          = nil;

local m_dobMonth= nil;	-- for new user info validation...
local m_dobYear	= nil;
local m_dobDay	= nil;

-- ===========================================================================
--  Helper functions
-- ===========================================================================

function FixupText( text )
	-- Replace tabs with spaces
	text = string.gsub( text, "\t", "    " );
	-- Replace Newlines with [NEWLINE]
	text = string.gsub( text, "\n", "[NEWLINE]" );

	return text;
end

-- ===========================================================================
--	Leave My2K popup dialog
-- ===========================================================================
function OnReturn()
	UIManager:DequeuePopup( ContextPtr );

	-- Clear any prior dialogs:
	DestroyDialogIfExists( m_2KMainMenuManager );
	DestroyDialogIfExists( m_LoginDialogManager );
	DestroyDialogIfExists( m_NewUserDialogManager );
	DestroyDialogIfExists( m_UserNameDialogManager );
	DestroyDialogIfExists( m_DOBDialogManager );
	DestroyDialogIfExists( m_LegalDialogManager );
	DestroyDialogIfExists( m_LegalItemDialogManager );
	DestroyDialogIfExists( m_MessageDialogManager );
	DestroyDialogIfExists( m_LogoutDialogManager );

	local m_previousDialogData = m_currentDialogData;

	m_currentDialog		= nil;
	m_currentDialogData = nil;
	m_dobMonth			= nil;
	m_dobYear			= nil;
	m_dobDay			= nil;

	m_legalItemIndex	= -1;

	m_bESCEnabled		= true;
	m_cancelFunction	= nil;

	return m_previousDialogData;
end
LuaEvents.CloseAnyQueuedMy2KPopup.Add( OnReturn );

-- ===========================================================================
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if( uiMsg == KeyEvents.KeyDown ) 
	then
		if (wParam == Keys.VK_ESCAPE and m_bESCEnabled == true) then
			if( m_cancelFunction ~= nil ) then
				m_cancelFunction();
			else
				OnReturn();
			end
		end
	end
	return true;
end
ContextPtr:SetInputHandler( InputHandler );


-- ===========================================================================
-- ===========================================================================
function DestroyDialogIfExists( dialogManager )
	if (dialogManager) then
		dialogManager:ResetInstances();
	end
end


-- ===========================================================================
-- ===========================================================================
function ShowHideHandler( bIsHide, bIsInit )	
	if( bIsHide ) then
		return;
	end

	if( gCurrentDialogID == nil ) then
		gCurrentDialogID = DIALOG_MAIN_MENU;
	end

	--m_currentDialogID = DIALOG_LOGIN; --debug

	if ( m_currentDialogID == DIALOG_MAIN_MENU )	then Create2KMainMenu();		end
	if ( m_currentDialogID == DIALOG_LOGIN )		then CreateLoginDialog();		end
	if ( m_currentDialogID == DIALOG_NEW_USER )		then CreateNewUserDialog();		end
	if ( m_currentDialogID == DIALOG_USER_NAME )	then CreateUserNameDialog();	end
	if ( m_currentDialogID == DIALOG_DOB )			then CreateDOBDialog();			end
	if ( m_currentDialogID == DIALOG_LEGAL )		then CreateLegalDialog();		end
	if ( m_currentDialogID == DIALOG_LEGAL_ITEM )	then CreateLegalItemDialog();	end
	if ( m_currentDialogID == DIALOG_MESSAGE )		then CreateMessageDialog();		end
	if ( m_currentDialogID == DIALOG_LOGOUT )		then CreateLogoutDialog();		end

end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-- ===========================================================================
-- ===========================================================================

function ResizeInstance( instance )
	if (instance ~= nil) then
		instance.WindowData:CalculateSize();
		local contentSizeY	= instance.WindowData:GetSizeY();
		instance.Dialog:SetSizeY( contentSizeY + SIZE_DIALOG_ART_SPACE_Y );
		instance.WindowBacking:SetSizeY( contentSizeY + SIZE_DIALOG_ART_SPACE_Y );
		instance.WindowOutline:SetSizeY( contentSizeY + SIZE_DIALOG_ART_SPACE_Y );
	end
end


-- ===========================================================================
-- ===========================================================================
function IsValidEmail( email )

	if ( email == nil ) then
		return false
	end

	local _,numAts = email:gsub('@','@'); -- Counts the number of '@' symbol

	if  (numAts > 1 or numAts == 0 or email:len() > 254 or email:find('%s') ) then
		return false;
	end

	local atPos = string.find(email, '@');
	local localPart = string.sub(email,0,atPos-1); -- Gets the substring before '@' symbol
	local domainPart = string.sub(email,atPos+1); -- Gets the substring after '@' symbol

	-- if there is no local or domain, then invalid email.
	if ( not localPart or not domainPart ) then
		return false;
	end

	-- Check the local for validity
	if ( not localPart:match("[%w!#%$%%&'%*%+%-/=%?^_`{|}~]+") or (localPart:len() > 64) ) then
		return false;
	end
	if ( localPart:match('^%.+') or localPart:match('%.+$') or localPart:find('%.%.+') ) then
		return false;
	end

	-- Check the domain for validity
	if ( not domainPart:match('[%w%-_]+%.%a%a+$') or domainPart:len() > 253 ) then
		return false;
	end
	local fDomain = string.sub(domainPart,0,string.find(domainPart,'%.')-1); -- Gets the substring in the domain-part before the last (dot) character
	if ( fDomain:match('^[_%-%.]+') or fDomain:match('[_%-%.]+$') or fDomain:find('%.%.+') ) then
		return false;
	end

	return true;

end


-- ===========================================================================
-- ===========================================================================
function IsValidDate( year, month, day )

	if ( year == nil or month == nil or day == nil ) then
		return false;
	end

	-- Make sure we're dealing with numbers here.
	year = tonumber(year);
	month = tonumber(month);
	day = tonumber(day);

	if day < 0 or day > 31 or month < 0 or month > 12 or year < 0 then
		-- Cases that don't make sense
		return false
	elseif month == 4 or month == 6 or month == 9 or month == 11 then 
		-- Apr, Jun, Sep, Nov can have at most 30 day
		return day <= 30
	elseif month == 2 then
		-- Feb
		if year%400 == 0 or (year%100 ~= 0 and year%4 == 0) then
			-- if leap year, day can be at most 29
			return day <= 29
		else
			-- else 28 days is the max
			return day <= 28
		end
	else 
		-- all other monthonths can have at monthost 31 dayays
		return day <= 31
	end
end


-- ===========================================================================
-- ===========================================================================

function ChangeMy2KTexture( control, loggedIn )
	if( control ~= nil ) then
		if( loggedIn ) then
			control:SetTexture("My2KLogoButtonLoggedIn.dds");
		else
			control:SetTexture("My2KLogoButton.dds");
		end
	end
end

function LoggedIn( firaxisLiveLoggedIn, my2KLoggedIn )
	local control = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2KLogin" );
	if( firaxisLiveLoggedIn ) then
		control:SetDisabled(false);
		ChangeMy2KTexture( control, my2KLoggedIn );
	else
		ChangeMy2KTexture( control, false );
		control:SetDisabled(true);
	end
end

function LoggedOut()
	local control = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2KLogin" );
	ChangeMy2KTexture( control, false );
end

function ClosePreviousMenu()
	if m_currentDialog ~= nil then
		OnReturn();
	end
end

-- ===========================================================================
-- ===========================================================================

function Create2KMainMenu()
	local instance = m_2KMainMenuManager:GetInstance();
	
	instance.LoginButton:SetDisabled(false);
	instance.LoginButton:RegisterCallback( Mouse.eLClick, 
		function()
			FiraxisLive.My2KBeginLogin();
			instance.LoginButton:SetDisabled(true);
			instance.NewUserButton:SetDisabled(true);
			instance.CancelButton:SetDisabled(true);
		end );

	instance.NewUserButton:SetDisabled(false);
	instance.NewUserButton:RegisterCallback( Mouse.eLClick,
		function()
			FiraxisLive.My2KCreateNewUser();
			instance.LoginButton:SetDisabled(true);
			instance.NewUserButton:SetDisabled(true);
			instance.CancelButton:SetDisabled(true);
		end );

	m_bESCEnabled = true;
	m_cancelFunction = function()
		OnReturn();
	end;
	instance.CancelButton:SetDisabled(false);
	instance.CancelButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	ResizeInstance( instance );

	m_currentDialog = instance;
end

-- ===========================================================================
function Show2KMainMenu( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_MAIN_MENU;
	m_currentDialogData = {};

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end

-- ===========================================================================
-- ===========================================================================
function ValidateLoginButtons( instance )
	if ( (instance.Email:GetText() ~= nil and IsValidEmail( instance.Email:GetText() ) ) and
		 (instance.Password:GetText() ~= nil and instance.Password:GetText():len() > 0 ) ) then
		instance.LoginButton:SetDisabled(false);
	else
		instance.LoginButton:SetDisabled(true);
	end
end

function CreateLoginDialog()
	local instance = m_LoginDialogManager:GetInstance();

	instance.Title:SetText( m_currentDialogData.title );	
	instance.Message:SetText( m_currentDialogData.message );
	instance.EMailTitle:SetText( m_currentDialogData.emailTitle );
	instance.PasswordTitle:SetText( m_currentDialogData.passwordTitle );

	instance.Email:SetText("");
	instance.Email:RegisterStringChangedCallback(
		function()
			ValidateLoginButtons(instance);
		end
	);

	instance.Password:SetText("");
	instance.Password:RegisterStringChangedCallback(
		function()
			ValidateLoginButtons(instance);
		end
	);

	m_bESCEnabled = true;
	m_cancelFunction =
		function()
			FiraxisLive.My2KLoginUser( "", "", false );
			Show2KMainMenu();
		end;

	instance.CancelText:SetText(m_currentDialogData.cancel);
	instance.CancelButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	instance.LoginText:SetText(m_currentDialogData.login);
	instance.LoginButton:SetDisabled( true );
	instance.LoginButton:RegisterCallback( Mouse.eLClick, 
		function()
			if (instance.Email:GetText() ~= nil and IsValidEmail( instance.Email:GetText() ) ) then
				local password = instance.Password:GetText();
				if password == nil then
					password = "";
				end
				FiraxisLive.My2KLoginUser( instance.Email:GetText(), password, true );
			end
		end );

	ResizeInstance( instance );

	m_currentDialog = instance;

	ValidateLoginButtons(instance);
end

-- ===========================================================================
function ShowLoginDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_LOGIN;
	m_currentDialogData = dialogData;

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end



-- ===========================================================================
-- ===========================================================================

-- ===========================================================================
function RealizeOkForNewUserDialog( instance )
	local bDOBValid = false;
	local bEmailValid = false;

	if( IsValidDate( m_dobYear, m_dobMonth, m_dobDay ) ) then
		bDOBValid = true;
	end

	if (instance.Email:GetText() ~= nil and IsValidEmail( instance.Email:GetText() ) ) then
		bEmailValid = true;
	end

	instance.NewUserButton:SetDisabled( bDOBValid ~= true or bEmailValid ~= true );

end

-- ===========================================================================
function CreateNewUserDialog()
	local instance = m_NewUserDialogManager:GetInstance();

	--instance.Title:SetText( m_currentDialogData.title );		
	--instance.Message:SetText( m_currentDialogData.message );
	--instance.EMailTitle:SetText( m_currentDialogData.emailTitle );

	instance.Email:SetDisabled(false);
	instance.Email:SetText("");
	instance.Email:RegisterStringChangedCallback(
		function()
			RealizeOkForNewUserDialog( instance );
		end
	);

	local currentYear = os.date("%Y");
	instance.Year:SetDisabled(false);
	instance.Year:GetButton():SetText( "" );
	instance.Year:ClearEntries();
	for i=currentYear,currentYear-100,-1 do
		local controlTable = {};
		instance.Year:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText( tostring(i) );		
		controlTable.Button:SetVoid1( i );
	end
	instance.Year:CalculateInternals();
	instance.Year:RegisterSelectionCallback( 
		function( index )
			instance.Year:GetButton():SetText( tostring(index) );
			m_dobYear = index;
			RealizeOkForNewUserDialog( instance );
		end
	);
	
	instance.Month:SetDisabled(false);
	instance.Month:GetButton():SetText( "" );
	instance.Month:ClearEntries();
	for i=1,12,1 do
		local controlTable = {};
		instance.Month:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText( tostring(i) );		
		controlTable.Button:SetVoid1( i );
	end
	instance.Month:CalculateInternals();
	instance.Month:RegisterSelectionCallback( 
		function( index )
			instance.Month:GetButton():SetText( tostring(index) );
			m_dobMonth = index;
			RealizeOkForNewUserDialog( instance );
		end
	);

	instance.Day:SetDisabled(false);
	instance.Day:GetButton():SetText( "" );
	instance.Day:ClearEntries();
	instance.ContentStack:CalculateSize();
		for i=1,31,1 do
		local controlTable = {};
		instance.Day:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText( tostring(i) );		
		controlTable.Button:SetVoid1( i );
	end
	instance.Day:CalculateInternals();	
	instance.Day:RegisterSelectionCallback( 
		function( index )
			instance.Day:GetButton():SetText( tostring(index) );
			m_dobDay = index;
			RealizeOkForNewUserDialog( instance );
		end
	);
	

	m_bESCEnabled = true;
	m_cancelFunction =
		function()
			Show2KMainMenu();
		end;
		
	--instance.CancelText:SetText(m_currentDialogData.cancel);
	instance.CancelButton:SetDisabled(false);
	instance.CancelButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	--instance.NewUserText:SetText(m_currentDialogData.newuser);
	instance.NewUserButton:SetDisabled( true );
	instance.NewUserButton:RegisterCallback( Mouse.eLClick, 
		function()
			if (instance.Email:GetText() ~= nil and IsValidEmail( instance.Email:GetText() ) and IsValidDate( m_dobYear, m_dobMonth, m_dobDay ) ) then
				-- Disable all the things!
				m_bESCEnabled = false;
				instance.Email:SetDisabled(true);
				instance.Year:SetDisabled(true);
				instance.Month:SetDisabled(true);
				instance.Day:SetDisabled(true);
				instance.CancelButton:SetDisabled(true);
				instance.NewUserButton:SetDisabled(true);

				local dob = instance.Month:GetButton():GetText() .. "/" .. instance.Day:GetButton():GetText() .. "/" .. instance.Year:GetButton():GetText();
				FiraxisLive.My2KNewUserResponse( instance.Email:GetText(), dob );
			end
		end );
		
	ResizeInstance( instance );

	m_currentDialog = instance;

	RealizeOkForNewUserDialog(instance);
end

-- ===========================================================================
function ShowNewUserDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_NEW_USER;
	m_currentDialogData = dialogData;

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end

-- ===========================================================================
-- ===========================================================================

function RealizeOkForDOBDialog( instance )
	if( IsValidDate( m_dobYear, m_dobMonth, m_dobDay ) ) then
		instance.OkButton:SetDisabled( false );
	else
		instance.OkButton:SetDisabled( true );
	end
end

-- ===========================================================================
function CreateDOBDialog()
	local instance = m_DOBDialogManager:GetInstance();

	instance.Title:SetText( m_currentDialogData.title );
	instance.Message:SetText( m_currentDialogData.message );

	local currentYear = os.date("%Y");
	instance.Year:ClearEntries();
	instance.Year:SetDisabled(false);
	instance.Year:GetButton():SetText( "" );
	for i=currentYear,currentYear-100,-1 do
		local controlTable = {};
		instance.Year:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText( tostring(i) );		
		controlTable.Button:SetVoid1( i );
	end
	instance.Year:CalculateInternals();
	instance.Year:RegisterSelectionCallback( 
		function( index )
			instance.Year:GetButton():SetText( tostring(index) );
			m_dobYear = index;
			RealizeOkForDOBDialog( instance );
		end
	);

	instance.Month:ClearEntries();
	instance.Month:SetDisabled(false);
	instance.Month:GetButton():SetText( "" );
	for i=1,12,1 do
		local controlTable = {};
		instance.Month:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText( tostring(i) );		
		controlTable.Button:SetVoid1( i );
	end
	instance.Month:CalculateInternals();
	instance.Month:RegisterSelectionCallback( 
		function( index )
			instance.Month:GetButton():SetText( tostring(index) );
			m_dobMonth = index;
			RealizeOkForDOBDialog( instance );
		end
	);

	instance.Day:CalculateInternals();	
	instance.Day:SetDisabled(false);
	instance.Day:GetButton():SetText( "" );
	for i=1,31,1 do
		local controlTable = {};
		instance.Day:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText( tostring(i) );		
		controlTable.Button:SetVoid1( i );
	end
	instance.Day:RegisterSelectionCallback( 
		function( index )
			instance.Day:GetButton():SetText( tostring(index) );
			m_dobDay = index;
			RealizeOkForDOBDialog( instance );
		end
	);
		

	m_bESCEnabled = true;
	m_cancelFunction =
		function()
			FiraxisLive.My2KDOBResponse( "", false );
			ShowNewUserDialog( );
		end;

	instance.CancelText:SetText(m_currentDialogData.cancel);
	instance.CancelButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	instance.OkText:SetText(m_currentDialogData.ok);
	instance.OkButton:SetDisabled( true );
	instance.OkButton:RegisterCallback( Mouse.eLClick, 
		function()
			if( IsValidDate( m_dobYear, m_dobMonth, m_dobDay ) ) then
				-- Disable all the things!
				m_bESCEnabled = false;
				instance.Email:SetDisabled(true);
				instance.Year:SetDisabled(true);
				instance.Month:SetDisabled(true);
				instance.Day:SetDisabled(true);
				instance.CancelButton:SetDisabled(true);
				instance.NewUserButton:SetDisabled(true);

				local dob = instance.Month:GetButton():GetText() .. "/" .. instance.Day:GetButton():GetText() .. "/" .. instance.Year:GetButton():GetText();
				FiraxisLive.My2KDOBResponse( dob, true );
			end
		end );

	ResizeInstance( instance );	

	m_currentDialog = instance;
end

-- ===========================================================================
function ShowDOBDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_DOB;
	m_currentDialogData = dialogData;
	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end



-- ===========================================================================
-- ===========================================================================

-- ===========================================================================
function RealizeOkForUserNameDialog( instance )

	if (instance.Email:GetText() ~= nil and IsValidEmail( instance.Email:GetText() ) ) then
		instance.OkButton:SetDisabled( false );		
	else
		instance.OkButton:SetDisabled( true );		
	end

end

-- ===========================================================================
function CreateUserNameDialog()
	local instance = m_UserNameDialogManager:GetInstance();

	instance.Title:SetText( m_currentDialogData.title );		
	instance.Message:SetText( m_currentDialogData.message );
	instance.EMailTitle:SetText( m_currentDialogData.emailTitle );

	instance.Email:RegisterCharCallback(
		function()
			RealizeOkForUserNameDialog( instance );
		end
	);
	

	m_bESCEnabled = true;
	m_cancelFunction = 
		function()
			FiraxisLive.My2KEmailResponse( "", false );
			ShowNewUserDialog( );
		end;
		
	instance.CancelText:SetText(m_currentDialogData.cancel);
	instance.CancelButton:SetDisabled(false);
	instance.CancelButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	instance.OkText:SetText(m_currentDialogData.ok);
	instance.OkButton:SetDisabled( true );
	instance.OkButton:RegisterCallback( Mouse.eLClick, 
		function()
			if (instance.Email:GetText() ~= nil and IsValidEmail( instance.Email:GetText() ) ) then
				m_bESCEnabled = false;
				instance.OkButton:SetDisabled(true);
				instance.CancelButton:SetDisabled(true);
				FiraxisLive.My2KEmailResponse( instance.Email:GetText(), true );
			end
		end );

	ResizeInstance( instance );

	m_currentDialog = instance;

	RealizeOkForUserNameDialog(instance);
end

-- ===========================================================================
function ShowUserNameDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_USER_NAME;
	m_currentDialogData = dialogData;

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end


-- ===========================================================================
-- ===========================================================================

function CreateLegalDialog()
	
	local instance			= m_LegalDialogManager:GetInstance();

	local LegalItemManager	= InstanceManager:new( "LegalItemInstance", "Group", instance.ContentStack );
	
	instance.ContentStack:DestroyAllChildren();

	m_bESCEnabled = false;	-- No cancelling the Legal screen

	instance.Title:SetText( m_currentDialogData.title );
	instance.Message:SetText( m_currentDialogData.message );

	-- Create a button for each document
	local docInstance;
	for i,document in ipairs(m_currentDialogData.documents) do
		docInstance = LegalItemManager:GetInstance();
		-- Change all tabs into 4 spaces
		docInstance.ItemName:SetText( FixupText( document.Name ) );
		docInstance.ReadButton:RegisterCallback( Mouse.eLClick,
			function()
				ShowLegalItemDialog( m_currentDialogData, i );
			end );
	end

	-- Set buttons
	instance.DisagreeAllText:SetText( m_currentDialogData.disagree );
	instance.DisagreeAllButton:RegisterCallback( Mouse.eLClick, 
		function()

			local agreeList = {};
			agreeList["AgreeCount"] = 0;

			FiraxisLive.My2KLegalResponse( agreeList );
		end );

	instance.AgreeAllText:SetText( m_currentDialogData.agree );
	instance.AgreeAllButton:RegisterCallback( Mouse.eLClick, 
		function()
			local agreeList = {};

			agreeList["AgreeCount"] = #m_currentDialogData.documents;
			for i,document in ipairs(m_currentDialogData.documents) do
				agreeList[i] = document.ID;
			end

			FiraxisLive.My2KLegalResponse( agreeList );
		end );

	instance.ContentStack:CalculateSize();
	instance.ContentArea:CalculateInternalSize();

	instance.ContentArea:SetScrollValue(0);

	ResizeInstance( instance );

	m_currentDialog = instance;
end

-- ===========================================================================
function ShowLegalDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_LEGAL;
	m_currentDialogData = dialogData;

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end

-- ===========================================================================
-- ===========================================================================

function CreateLegalItemDialog()
	
	local instance			= m_LegalItemDialogManager:GetInstance();

	local LegalTextManager	= InstanceManager:new( "LegalTextInstance", "LegalText", instance.ContentStack );
	
	instance.ContentStack:DestroyAllChildren();

	instance.Title:SetText( m_currentDialogData.title );

	-- Split EULA into individual paragraphs based on \n
	local textAreas = {};
	for para in string.gmatch( m_currentDialogData.documents[m_legalItemIndex].Text .. "\n", "(.-)\n") do
		table.insert( textAreas, FixupText( para ) )
	end

	-- Create a text area for each paragraph.
	local textArea;
	for iArea=1,#textAreas,1 do
		textArea = LegalTextManager:GetInstance();
		textArea.LegalText:SetText( Locale.ConvertTextKey( textAreas[iArea] ) );
	end

	-- Set buttons

	m_bESCEnabled = true;
	m_cancelFunction = 
		function()
			ShowLegalDialog( m_currentDialogData );
		end

	instance.OkButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	instance.ContentStack:CalculateSize();
	instance.ContentArea:CalculateInternalSize();

	instance.ContentArea:SetScrollValue(0);

	-- Grab one of the callbacks (doesn't matter which) and if enough scrollage has
	-- occurred, enabled the okay button.
	--instance.ContentArea:RegisterDownEndCallback(
		--function( control )
			--local scrollAmount = instance.ContentArea:GetScrollValue();
			--if scrollAmount > 0.95 then
				--instance.OkButton:SetDisabled( false );
			--end
		--end		
	--);

	m_currentDialog = instance;
end

-- ===========================================================================
function ShowLegalItemDialog( dialogData, documentIndex )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_LEGAL_ITEM;
	m_currentDialogData = dialogData;
	m_legalItemIndex = documentIndex;

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end


-- ===========================================================================
-- ===========================================================================
function CreateMessageDialog()
	local instance = m_MessageDialogManager:GetInstance();
	
	instance.Title:SetText( m_currentDialogData.title );
	instance.Message:SetText( m_currentDialogData.message );
	instance.OkText:SetText( m_currentDialogData.ok );
	

	m_bESCEnabled = true;
	m_cancelFunction =
		function()
			FiraxisLive.My2KMessageResponse( m_currentDialogData.dialogID, true );
			OnReturn();
		end

	instance.OkButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	ResizeInstance( instance );

	m_currentDialog = instance;
end

-- ===========================================================================
function ShowMessageDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_MESSAGE;
	m_currentDialogData = dialogData;
	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end


-- ===========================================================================
-- ===========================================================================
function CreateLogoutDialog()
	local instance = m_LogoutDialogManager:GetInstance();

	instance.Title:SetText( m_currentDialogData.title );
	instance.Message:SetText( m_currentDialogData.message );
	

	m_bESCEnabled = true;
	m_cancelFunction =
		function()
			FiraxisLive.My2KMessageResponse( m_currentDialogID, false );
			OnReturn();
		end;

	instance.CancelText:SetText(m_currentDialogData.cancel);
	instance.CancelButton:RegisterCallback( Mouse.eLClick, m_cancelFunction );

	instance.OkText:SetText(m_currentDialogData.ok);
	instance.OkButton:RegisterCallback( Mouse.eLClick,
		function()
			FiraxisLive.My2KMessageResponse( m_currentDialogID, true );
			OnReturn();
		end );

	ResizeInstance( instance );

	m_currentDialog = instance;
end

-- ===========================================================================
function ShowLogOutDialog( dialogData )

	ClosePreviousMenu();

	m_currentDialogID = DIALOG_LOGOUT;
	m_currentDialogData = dialogData;

	local My2KPanel = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/My2K" );
	if( My2KPanel ~= nil ) then
		UIManager:QueuePopup( My2KPanel, PopupPriority.Priority_My2KDialogs );
	end
end