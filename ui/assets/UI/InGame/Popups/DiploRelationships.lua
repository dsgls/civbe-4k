-- ===========================================================================
--	Diplomatic Relationships
-- ===========================================================================

include( "IconSupport" );
include( "SupportFunctions"  );
include( "InstanceManager" );
include( "InfoTooltipInclude" );
include( "CityStateStatusHelper" );
include( "UIExtras" );


-- ===========================================================================
--		CONSTANTS
-- ===========================================================================
local ART_LIST_ITEM_W_SCROLLBAR_WIDTH		= 180;
local Y_PADDING_AFFINITIES_BOX				= 10;
local Y_PADDING_WONDERS_BOX					= 10;
local Y_PADDING_STATUS_BOX					= 12;
local HEIGHT_NAMEBOX_WITH_TEAM_LABEL		= 110;
local MAX_SIZE_WONDER_TEXT					= 150;

local g_colorGood  			=  0xff50dd80;	-- colors are packed: alpha,blue,green,red
local g_colorGoodGlow  		=  0xaa50dd80;
local g_colorNeutral		=  0xffbebebe;
local g_colorNeutralGlow  	=  0x33bebebe;
local g_colorBad  			=  0xff4444e0;
local g_colorBadGlow  		=  0xaa4444e0;
local g_colorVeryBad		=  0xff2020aa;
local g_colorVeryBadGlow  	=  0xdd2020aa;




-- ===========================================================================
--		MEMBERS
-- ===========================================================================

local g_LeaderButtonIM	= InstanceManager:new( "LeaderButtonInstance",	"LeaderButton", Controls.MajorStack );

local g_leaderRowsTable		= {};
local g_iDealDuration		= Game.GetDealDuration();
local g_Deal				= UI.GetScratchDeal();
local g_iPlayer				= Game.GetActivePlayer();
local g_pPlayer				= Players[ g_iPlayer ];
local g_iTeam				= g_pPlayer:GetTeam();
local g_pTeam				= Teams[ g_iTeam ];
local g_uiListItems;
local m_referencedControls	= {};
local g_WarTarget;

local g_bAlwaysWar			= Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_WAR );
local g_bAlwaysPeace		= Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_PEACE );
local g_bNoChangeWar		= Game.IsOption( GameOptionTypes.GAMEOPTION_NO_CHANGING_WAR_PEACE );


local DiploRequestIncoming = Locale.ConvertTextKey( "TXT_KEY_DIPLO_REQUEST_INCOMING" );
local DiploRequestOutgoing = Locale.ConvertTextKey( "TXT_KEY_DIPLO_REQUEST_OUTGOING" );

local AlwaysWarStr				= Locale.ConvertTextKey( "TXT_KEY_ALWAYS_WAR_TT" );
local DiploRequestInProgressStr = Locale.ConvertTextKey( "TXT_KEY_DIPLO_REQUEST_IN_PROGRESS" );


local LeaderNameOriginalColor0 = RGBAValuesToABGRHex(157/255, 173/255, 190/255, 255/255);
local LeaderNameOriginalColor1 = RGBAValuesToABGRHex(0, 0, 0, 255/255);
----------------------------------------------------------------
-- Key Down Processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
	
		if wParam == Keys.VK_ESCAPE then
    	    if( Controls.WarConfirm:IsHidden() == false ) then
	            OnNo();
				return true;
    	    end
		end
    end
	return false;
end
ContextPtr:SetInputHandler( InputHandler );


----------------------------------------------------------------
----------------------------------------------------------------
function OnYes()
	Network.SendChangeWar( g_WarTarget, true);
    Controls.WarConfirm:SetHide( true );
end
Controls.Yes:RegisterCallback( Mouse.eLClick, OnYes );

----------------------------------------------------------------
----------------------------------------------------------------
function OnNo()
    Controls.WarConfirm:SetHide( true );
end
Controls.No:RegisterCallback( Mouse.eLClick, OnNo );


-------------------------------------------------
-------------------------------------------------
function ShowHideHandler( bIsHide )
    if( not bIsHide ) then
        UpdateDisplay();
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-------------------------------------------------
-- On Leader Selected
-------------------------------------------------
function LeaderSelected( ePlayer )

	if not Players[Game.GetActivePlayer()]:IsTurnActive() or Game.IsProcessingMessages() then
		return;
	end

	-- Without clearing out the highlight, it's likely the enter/exit reference
	-- counts will be off when the advisor pops up; coming back from it will
	-- have them in an inconsistent state.
	ClearMouseOverReferencesAcrossTableOfControls();

    if( Players[ePlayer]:IsHuman() ) then
        Events.OpenPlayerDealScreenEvent( ePlayer );
    else        
        UI.SetRepeatActionPlayer(ePlayer);
        UI.ChangeStartDiploRepeatCount(1);
    	Players[ePlayer]:DoBeginDiploWithHuman();    
	end
end

-------------------------------------------------
-- On War Button Clicked
-------------------------------------------------
function OnWarButton( ePlayer )
	if (g_pTeam:CanDeclareWar(Players[ ePlayer ]:GetTeam())) then
		g_WarTarget = Players[ ePlayer ]:GetTeam();
		Controls.WarConfirm:SetHide( false );
	end	
end


-- ===========================================================================	
--	Find control with largest height and apply it to all.
-- ===========================================================================	
function ApplyHeightToTallestControl( controls )
	
	local tallestHeight = 0;
	
	-- Find tallest control
	local height = 0;	
	for _,control in ipairs(controls) do
		height = control:GetSizeY();
		if ( height > tallestHeight) then
			tallestHeight = height;
		end		
	end

	-- Apply to all controls
	for _,control in ipairs(controls) do
		control:SetSizeY( tallestHeight );
	end
end


-- ===========================================================================	
--	controls				table of controls to apply this to
-- ===========================================================================	
function ApplyMouseOverAcrossTableOfControls( controls  )

	-- Apply to all controls
	for _,control in ipairs(controls) do
		
		-- Keep track of enter/exit callbacks as one cell affects all.
		-- Without reference counting enter/exists it's not too difficult mouse
		-- between two and get the row of cells into an inconsistent state.
		control.highlightRefCount = 0;
		table.insert( m_referencedControls, control );

		control:RegisterMouseEnterCallback( 
			function() 
				for _,currentControl in ipairs(controls) do
					if currentControl ~= control then					-- current control auto switches texture by C++ button logic						

						-- Via pop-ups, this can get into a bad state having count below 0...
						if ( currentControl.highlightRefCount < 0 ) then
							currentControl.highlightRefCount  = 0;
						end

						currentControl.highlightRefCount = currentControl.highlightRefCount + 1;
						if (currentControl.highlightRefCount > 0) then
							currentControl:SetTextureOffsetVal( 0, 64 );
						end
					end
				end
			end );

		control:RegisterMouseExitCallback( 			
			function() 
				for _,currentControl in ipairs(controls) do
					if currentControl ~= control then
						currentControl.highlightRefCount = currentControl.highlightRefCount - 1;
						if (currentControl.highlightRefCount < 1) then
							currentControl.highlightRefCount = 0;
							currentControl:SetTextureOffsetVal( 0, 0 );
						end
					end
				end
			end );
	end	
end

-- ===========================================================================	
function ClearMouseOverReferencesAcrossTableOfControls()
	-- Apply to all controls
	for _,currentControl in pairs( m_referencedControls ) do
		currentControl.highlightRefCount = 0;
		currentControl:SetTextureOffsetVal( 0, 0 );
	end
end


-- ===========================================================================	
--	Clear out all the dynamically created display data.
-- ===========================================================================	
function ClearOutPreviousDisplayData()
	
	for _,leaderButtonIM in ipairs(g_leaderRowsTable) do
		if leaderButtonIM["statusIM"] ~= nil then
			leaderButtonIM["statusIM"]:DestroyInstances();

			leaderButtonIM["statusIM"] = nil;
		end
		if leaderButtonIM["wondersIM"] ~= nil then
			leaderButtonIM["wondersIM"]:DestroyInstances();
			leaderButtonIM["wondersIM"] = nil;
		end
		if leaderButtonIM["affinitiesIM"] ~= nil then
			leaderButtonIM["affinitiesIM"]:DestroyInstances();
			leaderButtonIM["affinitiesIM"] = nil;
		end
	end
	g_LeaderButtonIM:ResetInstances();
	g_leaderRowsTable = {};
	g_uiListItems = {};
end


-- ===========================================================================	
--	Update the list of other civs												
-- ===========================================================================	
function UpdateDisplay()
	
	-- If not being displayed, ignore the call to update the display...
	if ContextPtr:IsHidden() then
		return;
	end

	ClearOutPreviousDisplayData();

	local bScenario		= PreGame.GetLoadWBScenario();
	local iProposalTo	= UI.HasMadeProposal( g_iPlayer );

	local playerIdsInOrderOfDisplay = {};
	table.insert( playerIdsInOrderOfDisplay, g_iPlayer );
	for i = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		local player = Players[i];
		-- Is this player me, or is he/she alive, or has he/she made planetfall?	
		if (i ~= g_iPlayer and 
			player:IsAlive() and 
			not player:IsObserver() and 
			(player:GetNumCities() + player:GetNumOutposts()) > 0) 
		then
			local iOtherTeam = player:GetTeam();
			if ( g_pTeam:IsHasMet(iOtherTeam)) then				-- Have I (or my team) met this player?
				table.insert( playerIdsInOrderOfDisplay, i );	-- add to to-be-displayed list
			end
		end
	end

	-- Sort by Score
	table.sort(playerIdsInOrderOfDisplay, function(a, b)
		local playerA = Players[a];
		local playerB = Players[b];
		if (playerA ~= nil and playerB ~= nil) then
			if (playerA:GetScore() ~= playerB:GetScore()) then
				return playerA:GetScore() > playerB:GetScore();
			end
		end
		return a < b;
	end);

    --------------------------------------------------------------------
	-- Loop through all the Majors the active player knows
    --------------------------------------------------------------------
	for _,iPlayerLoop in ipairs(playerIdsInOrderOfDisplay) do
		
		local pOtherPlayer = Players[iPlayerLoop];
		local iOtherTeam = pOtherPlayer:GetTeam();
		local pOtherTeam = Teams[ iOtherTeam ];
		

		local controlTable = g_LeaderButtonIM:GetInstance();

		controlTable["affinitiesIM"]= InstanceManager:new( "AffinitiesLineInstance",	"Box", controlTable.AffinitiesStack );
		controlTable["wondersIM"]	= InstanceManager:new( "WondersLineInstance",	"Box", controlTable.PoliticsStack );
		controlTable["statusIM"]	= InstanceManager:new( "StatusLineInstance",	"Box", controlTable.StatusStack );
				
		local textBoxSize			= controlTable.NameBox:GetSizeX() - controlTable.LeaderName:GetOffsetX();

		local leaderNameString;
		if(pOtherPlayer:GetNickName() ~= "" and Game.IsGameMultiPlayer() and pOtherPlayer:IsHuman()) then
			local MAX_NAME_CHARS= 20;
			local nickName		= TruncateStringByLength(pOtherPlayer:GetNickName(), MAX_NAME_CHARS);
			leaderNameString = nickName; 
		else
			leaderNameString = pOtherPlayer:GetName();
		end
		TruncateStringWithTooltip( controlTable.LeaderName, textBoxSize, leaderNameString ); 
				
		local civType			= pOtherPlayer:GetCivilizationType();
		local civInfo			= GameInfo.Civilizations[civType];				
		local otherLeaderType	= pOtherPlayer:GetLeaderType();
		local otherLeaderInfo	= GameInfo.Leaders[otherLeaderType];

		local civPrimaryColorString = g_colorNeutral;
		local civSecondaryColorString = g_colorNeutralGlow;
		if (civInfo ~= nil and g_iPlayer == iPlayerLoop) then
			local primaryColorRaw, secondaryColorRaw = pOtherPlayer:GetPlayerColors();
			civPrimaryColorString = RGBAObjectToABGRHex(primaryColorRaw);
			civSecondaryColorString = RGBAObjectToABGRHex(secondaryColorRaw);
			controlTable.LeaderName:SetColor(civPrimaryColorString, 0);
			controlTable.LeaderName:SetColor(civSecondaryColorString, 1);
		else
			controlTable.LeaderName:SetColor(LeaderNameOriginalColor0, 0);
			controlTable.LeaderName:SetColor(LeaderNameOriginalColor1, 1);
		end
				
		local leaderButtonTooltip = nil;

		local civName = pOtherPlayer:GetCivilizationDescription();
		civName = Locale.ToUpper( civName );
		controlTable.CivName:SetText( civName );
		CivIconHookup( iPlayerLoop, 64, controlTable.CivIcon, controlTable.CivIconBG, nil, false, false, controlTable.CivIconHighlight );

		IconHookup( otherLeaderInfo.PortraitIndex, 64, otherLeaderInfo.IconAtlas, controlTable.LeaderPortrait );			
				
		-- team indicator
        if( pOtherTeam:GetNumMembers() > 1 ) then
            controlTable.TeamID	:LocalizeAndSetText( "TXT_KEY_MULTIPLAYER_DEFAULT_TEAM_NAME", pOtherTeam:GetID() + 1 );
            controlTable.TeamID	:SetHide( false );
			controlTable.NameBox:SetSizeY( HEIGHT_NAMEBOX_WITH_TEAM_LABEL );
        else
			controlTable.TeamID:SetHide( true );
        end
				

        -- Overall disposition
        local statusString;
        local statusColorString = g_colorNeutral;
		local glowColorString =	g_colorNeutralGlow;

		if g_iPlayer == iPlayerLoop then						
			statusString = Locale.ConvertTextKey( "{TXT_KEY_YOU:upper}" );
			statusColorString = civPrimaryColorString;
			glowColorString = civSecondaryColorString;
		elseif( iOtherTeam == g_iTeam ) then
            -- team mate
            local currentTech = pOtherPlayer:GetCurrentResearch();
            if( currentTech ~= -1 and 
                GameInfo.Technologies[currentTech] ~= nil and
                not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
                statusString = "[ICON_RESEARCH] " .. Locale.ConvertTextKey( GameInfo.Technologies[currentTech].Description );
            end
                    
        else
    		if( g_pTeam:IsAtWar( iOtherTeam ) ) then
    			if (g_bAlwaysWar) then
    				leaderButtonTooltip = AlwaysWarStr;
    			end
        		statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR" );
				statusColorString = g_colorVeryBad;
			elseif( g_pTeam:IsForcePeace( iOtherTeam ) ) then -- force peace = truce
				local peaceDealTurnsLeft = g_pPlayer:GetPeaceDealTurnsRemaining(iPlayerLoop);
				if (peaceDealTurnsLeft >= 0) then
					statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_TRUCE", peaceDealTurnsLeft );
					statusColorString = g_colorGood;
				else
					print("No peace treaty deal found, duration is invalid");
				end
			elseif (pOtherPlayer:IsDenouncingPlayer(g_iPlayer)) then
				statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_DENOUNCING" );
				statusColorString = g_colorBad;
			elseif (pOtherPlayer:WasResurrectedThisTurnBy(g_iPlayer)) then
				statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_LIBERATED" );
				statusColorString = g_colorGood;
    		elseif (pOtherPlayer:IsHuman() or pOtherTeam:IsHuman()) then
				statusColorString = g_colorNeutral;
    		else			
    			local eApproachGuess = g_pPlayer:GetApproachTowardsUsGuess( iPlayerLoop );
    					
				if( eApproachGuess == MajorCivApproachTypes.MAJOR_CIV_APPROACH_WAR ) then						
					statusString = Locale.ConvertTextKey( "TXT_KEY_WAR_CAPS" );
					statusColorString = g_colorVeryBad;
				elseif( eApproachGuess == MajorCivApproachTypes.MAJOR_CIV_APPROACH_HOSTILE ) then
					statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_HOSTILE", otherLeaderInfo.Description );
					statusColorString = g_colorVeryBad;
				elseif( eApproachGuess == MajorCivApproachTypes.MAJOR_CIV_APPROACH_GUARDED ) then
					statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_GUARDED", otherLeaderInfo.Description );
					statusColorString = g_colorBad;
				elseif( eApproachGuess == MajorCivApproachTypes.MAJOR_CIV_APPROACH_AFRAID ) then
					statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_AFRAID", otherLeaderInfo.Description);
					statusColorString = g_colorBad;
				elseif( eApproachGuess == MajorCivApproachTypes.MAJOR_CIV_APPROACH_FRIENDLY ) then
					statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_FRIENDLY", otherLeaderInfo.Description );
					statusColorString = g_colorGood;
				elseif( eApproachGuess == MajorCivApproachTypes.MAJOR_CIV_APPROACH_NEUTRAL ) then
					statusString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_NEUTRAL", otherLeaderInfo.Description );
					statusColorString = g_colorNeutral;
				end
				--??TRON TODO or remove?; update for Relationships screen:			PopulateTrade(iPlayerLoop, controlTable);
			end		
		end
		
		-- Set the overall mood/team/string		
		if( statusString ~= nil ) then
			if	( statusColorString == g_colorGood )		then glowColorString = g_colorGoodGlow; 
			elseif	( statusColorString == g_colorNeutral ) then glowColorString = g_colorNeutralGlow; 
			elseif	( statusColorString == g_colorBad )		then glowColorString = g_colorBadGlow; 
			elseif	( statusColorString == g_colorVeryBad ) then glowColorString = g_colorVeryBadGlow; end

			controlTable.DiploState:SetHide( false );
			controlTable.DiploState:SetColor( statusColorString, 0 );
			controlTable.DiploState:SetColor( glowColorString, 1 );
			controlTable.DiploState:SetText( statusString );
        else
			controlTable.DiploState:SetHide( true );
		end


		-- SCORE cell
		controlTable.Score:SetText( pOtherPlayer:GetScore() );
		local otherScoreEntries = {};
		GetPlayersScorePieces( pOtherPlayer, otherScoreEntries );			
		local strOtherScoreTooltip = table.concat(otherScoreEntries, "[NEWLINE]");
		controlTable.ScoreBox:SetToolTipString(strOtherScoreTooltip);
				
		
--[[ Diplomatic request
		-- Update diplomatic request button.
		local localPlayer = Game.GetActivePlayer();
		if(UI.ProposedDealExists(localPlayer, iPlayerLoop)) then
			-- We proposed something to them.
			controlTable.DiploWaiting:SetHide(false);
			controlTable.DiploWaiting:SetAlpha( 0.5 );
			controlTable.DiploWaiting:SetToolTipString( DiploRequestOutgoing );
		elseif(UI.ProposedDealExists(iPlayerLoop, localPlayer)) then
			--They proposed something to us.
			controlTable.DiploWaiting:SetHide(false);
			controlTable.DiploWaiting:SetAlpha( 1.0 );
			controlTable.DiploWaiting:SetToolTipString( DiploRequestIncoming );
		else
			-- No deals in progress.
			controlTable.DiploWaiting:SetHide(true);
		end
]]


--[[ WAR
        if( pOtherPlayer:IsHuman() ) then
            -- don't open trade if we're at war and war status cannot be changed
            if( not( g_pTeam:IsAtWar( pOtherPlayer:GetTeam() ) and (g_bAlwaysWar or g_bNoChangeWar) ) ) then                    
                controlTable.LeaderButton:SetDisabled( true );
            else
                controlTable.LeaderButton:SetDisabled( false );
            end
                    
    		-- Show or hide war button if it's a human
    		if( not g_bAlwaysWar and not g_bAlwaysPeace and not g_bNoChangeWar and
    			not g_pTeam:IsAtWar( pOtherPlayer:GetTeam()) and g_pTeam:CanDeclareWar(pOtherPlayer:GetTeam()) and
    			g_iTeam ~= iOtherTeam ) then
    			controlTable.WarButton:SetHide(false);
    					
        		controlTable.WarButton:SetVoid1( iPlayerLoop ); -- indicates type
        		controlTable.WarButton:RegisterCallback( Mouse.eLClick, OnWarButton );
    		else
    			controlTable.WarButton:SetHide(true);
    		end
    	else
    		controlTable.WarButton:SetHide(true);    			
		end
]]
		
		-- Fill AFFINITIES box

		for affinityInfo in GameInfo.Affinity_Types() do
			local level = pOtherPlayer:GetAffinityLevel(affinityInfo.ID);
			local affinityLine = controlTable["affinitiesIM"]:GetInstance();
			local text = affinityInfo.IconString .. "[" .. affinityInfo.ColorType .. "]" .. level .. "[ENDCOLOR]";
			affinityLine.Label:SetText(text);
		end
		
		controlTable.AffinitiesStack:CalculateSize();
		controlTable.AffinitiesStack:ReprocessAnchoring();
		controlTable.AffinitiesBox:SetSizeY( controlTable.AffinitiesStack:GetSizeY() + Y_PADDING_AFFINITIES_BOX );

		
		-- Fill POLITICS box

		-- Favors
		if (pOtherPlayer:IsHuman()) then
			controlTable.Favors:SetHide( true );
		else			
			local numFavorsStr = "0 ";
			local numFavors = g_pPlayer:GetNumFavors(iPlayerLoop);
			if (numFavors > 0) then
				numFavorsStr = "[COLOR_YELLOW]" .. tostring(numFavors) .. "[ENDCOLOR] ";
			end
			local favorsStr = numFavorsStr .. Locale.ConvertTextKey("{TXT_KEY_DIPLO_FAVORS:upper}");
			controlTable.Favors:SetHide( false );
			controlTable.Favors:SetText(favorsStr);
		end

		-- Wonders list
		local WorldWonders = {};
		for building in GameInfo.Buildings() do
			local buildingClass = GameInfo.BuildingClasses[building.BuildingClass];
			if (	(buildingClass.MaxGlobalInstances > 0) or
					(buildingClass.MaxPlayerInstances > 0) or			-- ??TRON temp: Remove this, as it's not really a wonder
					(building.Type == "BUILDING_HERMITAGE") or 
					(building.Type == "BUILDING_OXFORD_UNIVERSITY")
			   ) then
				table.insert(WorldWonders, {
					BuildingID			= building.ID,
					BuildingClassID		= buildingClass.ID,
					PortraitIndex		= building.PortraitIndex,
					IconAtlas			= building.IconAtlas,
					Description			= building.Description,
				});
			end
		end

		for city in pOtherPlayer:Cities() do
	        for _, wonder in ipairs(WorldWonders) do
				if (city:IsHasBuilding(wonder.BuildingID)) then
					local wondersLine = controlTable["wondersIM"]:GetInstance();
					local wonderText  = Locale.ConvertTextKey( wonder.Description );					
					TruncateStringWithTooltip(wondersLine.Label, MAX_SIZE_WONDER_TEXT, wonderText );
				end
			end
		end
		controlTable.PoliticsStack:CalculateSize();
		controlTable.PoliticsStack:ReprocessAnchoring();
		controlTable.PoliticsBox:SetSizeY( controlTable.PoliticsStack:GetSizeY() + Y_PADDING_WONDERS_BOX );
		

		-- Fill STATUS box

		if(not pOtherPlayer:IsHuman()) then
			local aOpinion = pOtherPlayer:GetOpinionTable( g_iPlayer );
			for i,opinion in ipairs(aOpinion) do
				local statusLine = controlTable["statusIM"]:GetInstance();
				statusLine.Label:SetText( opinion );
				
				local height = statusLine.Label:GetSizeY();
				statusLine.Box:SetSizeY( height );
			end
		end

		controlTable.StatusStack:CalculateSize();
		controlTable.StatusStack:ReprocessAnchoring();
		controlTable.StatusBox:SetSizeY( controlTable.StatusStack:GetSizeY() + Y_PADDING_STATUS_BOX );

		local rowOfControls =
			{
				controlTable.LeaderButton,
				controlTable.NameBox, 
				controlTable.ScoreBox,
				controlTable.AffinitiesBox,
				controlTable.PoliticsBox,
				controlTable.StatusBox
			};
		ApplyHeightToTallestControl( rowOfControls );
		table.insert( g_uiListItems, controlTable.StatusBox );

		-----------------------------------------------------------------------------
		-- disable the button if this is a human, and we have a pending deal, and
		-- the deal is not with this player
		-----------------------------------------------------------------------------
		local bCanOpenDeal = true;
				
		if(iProposalTo ~= -1 and not UI.ProposedDealExists(localPlayer, iPlayerLoop) and not UI.ProposedDealExists(iPlayerLoop, localPlayer)) then
			bCanOpenDeal = false;
		end
		controlTable.LeaderButton:SetDisabled( not bCanOpenDeal );
		if(not bCanOpenDeal) then
			leaderButtonTooltip = DiploRequestInProgressStr;
		end

		-- Set diplo list tooltip.
		controlTable.LeaderButton:SetToolTipString( leaderButtonTooltip );

		-- Enable/Disable based on if it's the current player.
		controlTable.NameBox	:SetDisabled( iPlayerLoop == g_iPlayer );
		controlTable.ScoreBox	:SetDisabled( iPlayerLoop == g_iPlayer );
		controlTable.AffinitiesBox	:SetDisabled( iPlayerLoop == g_iPlayer );
		controlTable.PoliticsBox	:SetDisabled( iPlayerLoop == g_iPlayer );
		controlTable.StatusBox	:SetDisabled( iPlayerLoop == g_iPlayer );
		
		-- Callbacks
		if ( iPlayerLoop ~= g_iPlayer ) then

			ApplyMouseOverAcrossTableOfControls( rowOfControls );

			controlTable.LeaderButton:SetVoid1( iPlayerLoop ); -- indicates type
			controlTable.LeaderButton:RegisterCallback( Mouse.eLClick, LeaderSelected );

			controlTable.NameBox	:SetVoid1( iPlayerLoop );
			controlTable.ScoreBox	:SetVoid1( iPlayerLoop );
			controlTable.AffinitiesBox	:SetVoid1( iPlayerLoop );
			controlTable.PoliticsBox	:SetVoid1( iPlayerLoop );
			controlTable.StatusBox	:SetVoid1( iPlayerLoop );

			controlTable.NameBox	:RegisterCallback( Mouse.eLClick, LeaderSelected );
			controlTable.ScoreBox	:RegisterCallback( Mouse.eLClick, LeaderSelected );
			controlTable.AffinitiesBox	:RegisterCallback( Mouse.eLClick, LeaderSelected );
			controlTable.PoliticsBox	:RegisterCallback( Mouse.eLClick, LeaderSelected );
			controlTable.StatusBox	:RegisterCallback( Mouse.eLClick, LeaderSelected );
		end

		table.insert( g_leaderRowsTable, controlTable );
	end

	RealizeScrollArea();	

end
Events.SerialEventScoreDirty.Add( UpdateDisplay );
Events.SerialEventCityInfoDirty.Add(UpdateDisplay);
Events.SerialEventGameDataDirty.Add(UpdateDisplay);
Events.MultiplayerGamePlayerDisconnected.Add(UpdateDisplay);


----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnDiploListActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	g_iPlayer	= Game.GetActivePlayer();
	g_pPlayer	= Players[ g_iPlayer ];
	g_iTeam		= g_pPlayer:GetTeam();
	g_pTeam		= Teams[ g_iTeam ];
end
Events.GameplaySetActivePlayer.Add(OnDiploListActivePlayerChanged);




-- ===========================================================================
function PopulateTrade(iPlayer, pStack)
	local g_MajorCivTradeRowIM = InstanceManager:new( "MajorCivTradeRowInstance", "Row", pStack.TradeStack );
	g_MajorCivTradeRowIMList[iPlayer] = g_MajorCivTradeRowIM;
	local pPlayer = Players[iPlayer];
	local iTeam = Players[iPlayer]:GetTeam();
	local pTeam = Teams[iTeam];
	
	local iItemToBeChanged = -1;	-- This is -1 because we're not changing anything right now
	local tradeRow = nil;
    ---------------------------------------------------------------------------------- 
    -- pocket Energy
    ---------------------------------------------------------------------------------- 
	-- Removed the negative check, as you can already see this in the diplo trade screen
	-- bGoldTradeAllowed = g_Deal:IsPossibleToTradeItem(iPlayer, g_iPlayer, TradeableItems.TRADE_ITEM_ENERGY, 1);	-- 1 here is 1 Energy, which is the minimum possible
	
	-- if (bGoldTradeAllowed) then
		local iGold = g_Deal:GetGoldAvailable(iPlayer, iItemToBeChanged);
		local strGoldString = Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY") .." (" .. iGold .. "[ICON_ENERGY])";
		tradeRow = AddTrade(strGoldString, tradeRow, g_MajorCivTradeRowIM);
	-- end
	---------------------------------------------------------------------------------- 
    -- pocket Energy Per Turn  
    ---------------------------------------------------------------------------------- 
	-- Removed the negative check, as you can already see this in the diplo trade screen
	-- local bGPTAllowed = g_Deal:IsPossibleToTradeItem(iPlayer, g_iPlayer, TradeableItems.TRADE_ITEM_ENERGY_PER_TURN, 1, g_iDealDuration);	-- 1 here is 1 GPT, which is the minimum possible
	
    -- if (bGPTAllowed) then
		local iEnergyPerTurn = pPlayer:CalculateGoldRate();
		local strGoldString = Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY_PER_TURN") .. " (" .. iEnergyPerTurn .. "[ICON_ENERGY])";
		tradeRow = AddTrade(strGoldString, tradeRow, g_MajorCivTradeRowIM);
	-- end

	---------------------------------------------------------------------------------- 
    -- pocket Favors
    ----------------------------------------------------------------------------------
	local iFavors = 1; -- TEMP
	local strFavorString = ""
	if (pPlayer:IsHuman()) then
		strFavorString = Locale.ConvertTextKey("TXT_KEY_DIPLO_SPEND_FAVORS") .." (" .. iFavors .. ")";
	else
		strFavorString = Locale.ConvertTextKey("TXT_KEY_DIPLO_GAIN_FAVORS") .." (" .. iFavors .. ")";
	end	
	tradeRow = AddTrade(strFavorString, tradeRow, g_MajorCivTradeRowIM);
   
	---------------------------------------------------------------------------------- 
    -- pocket Open Borders
    ---------------------------------------------------------------------------------- 
    local bOpenBordersForMe = pTeam:IsAllowsOpenBordersToTeam(g_iTeam);
    local bOpenBordersForThem = g_pTeam:IsAllowsOpenBordersToTeam(iTeam);
    if (bOpenBordersForThem or bOpenBordersForMe) then
		local strOpenBordersKey = "";
		if (bOpenBordersForThem and bOpenBordersForMe) then
			strOpenBordersKey = "TXT_KEY_DIPLO_RELATION_OPEN_BORDERS_SHARED";
		elseif (bOpenBordersForMe) then	
			strOpenBordersKey = "TXT_KEY_DIPLO_RELATION_OPEN_BORDERS_THEIR";
		elseif (bOpenBordersForThem) then
			strOpenBordersKey = "TXT_KEY_DIPLO_RELATION_OPEN_BORDERS_YOUR";
		end
				
		tradeRow = AddTrade(Locale.ConvertTextKey(strOpenBordersKey), tradeRow, g_MajorCivTradeRowIM);
    end
	
	---------------------------------------------------------------------------------- 
    -- pocket Alliance
    ---------------------------------------------------------------------------------- 
    if (g_pTeam:IsAlliance(iTeam)) then
		tradeRow = AddTrade(Locale.ConvertTextKey("TXT_KEY_DIPLO_ALLIANCE"), tradeRow, g_MajorCivTradeRowIM);
    end

    ---------------------------------------------------------------------------------- 
    -- pocket Trade Agreement
    ---------------------------------------------------------------------------------- 
     bTradeAgreementAllowed = g_Deal:IsPossibleToTradeItem(iPlayer, g_iPlayer, TradeableItems.TRADE_ITEM_TRADE_AGREEMENT, g_iDealDuration);  
    -- Are they not allowed to give RA? (don't have tech, or are already providing it to us)
    if (bTradeAgreementAllowed) then
		tradeRow = AddTrade(Locale.ConvertTextKey("TXT_KEY_DIPLO_TRADE_AGREEMENT"), tradeRow, g_MajorCivTradeRowIM);
    end
    ---------------------------------------------------------------------------------- 
    -- pocket resources for them
    ---------------------------------------------------------------------------------- 
	local strategicCount = 0;
	local luxuryCount = 0;
	local strStrategic = Locale.ConvertTextKey("TXT_KEY_DIPLO_STRATEGIC_RESOURCES");
	local strLuxury = Locale.ConvertTextKey("TXT_KEY_DIPLO_LUXURY_RESOURCES");
	for pResource in GameInfo.Resources() do
		iResourceLoop = pResource.ID;
		local bCanTradeResource = g_Deal:IsPossibleToTradeItem(iPlayer, g_iPlayer, TradeableItems.TRADE_ITEM_RESOURCES, iResourceLoop, 1);	-- 1 here is 1 quanity of the Resource, which is the minimum possible

		if(bCanTradeResource) then
			v = GameInfo.Resources[iResourceLoop];
			local iResourceCount = Players[iPlayer]:GetNumResourceAvailable( iResourceLoop, false );

			if(v.ResourceClassType == "RESOURCECLASS_BASIC") then
				strLuxury = strLuxury .. " " .. iResourceCount  ..v.IconString ;
				luxuryCount = luxuryCount + 1;
			else
				strStrategic = strStrategic .. " " .. iResourceCount  ..v.IconString;
				strategicCount = strategicCount + 1;
			end
		end
	end
	
	if(strategicCount > 0) then
		tradeRow = AddTrade(strStrategic, tradeRow, g_MajorCivTradeRowIM);
	end
	
	--if(luxuryCount > 0) then
		--tradeRow = AddTrade(strLuxury, tradeRow, g_MajorCivTradeRowIM);
	--end
end

-- ===========================================================================
function AddTrade(tradeString, tradeRow, tradeMgr)
	if(tradeRow == nil) then
		tradeRow = tradeMgr:GetInstance();
		tradeRow.Item0:SetText(tradeString);
	else
		tradeRow.Item1:SetText(tradeString);
		tradeRow = nil;
	end	
	return tradeRow;
end


-- ===========================================================================
--	Fill a table up with the pieces that determine a player's score
--	player			Player to get score pieces from
--	outScoreTable	Table to contain scores entries.
-- ===========================================================================
function GetPlayersScorePieces( player, outScoreTable  )

	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_CITIES",			player:GetScoreFromCities()));
	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_POPULATION",		player:GetScoreFromPopulation()));
	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_LAND",			player:GetScoreFromLand()));
	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_WONDERS",			player:GetScoreFromWonders()));

	if (not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_SCIENCE)) then
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_TECH",		player:GetScoreFromTechs()));
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_FUTURE_TECH", player:GetScoreFromFutureTech()));
	end
	if (not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_POLICIES)) then
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_POLICIES",	player:GetScoreFromPolicies()));
		table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_FUTURE_POLICIES", player:GetScoreFromFuturePolicies()));
	end

	--if (not Game.IsOption(GameOptionTypes.GAMEOPTION_NO_RELIGION)) then
	--	table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_RELIGION",	player:GetScoreFromReligion()));
	--end
	if (bScenario) then
		if(Locale.HasTextKey("TXT_KEY_DIPLO_MY_SCORE_SCENARIO1")) then
			table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_SCENARIO1", player:GetScoreFromScenario1()));
		end
		if(Locale.HasTextKey("TXT_KEY_DIPLO_MY_SCORE_SCENARIO2")) then
			table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_SCENARIO2", player:GetScoreFromScenario2()));
		end
		if(Locale.HasTextKey("TXT_KEY_DIPLO_MY_SCORE_SCENARIO3")) then
			table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_SCENARIO3", player:GetScoreFromScenario3()));
		end
		if(Locale.HasTextKey("TXT_KEY_DIPLO_MY_SCORE_SCENARIO4")) then
			table.insert(outScoreTable, Locale.Lookup("TXT_KEY_DIPLO_MY_SCORE_SCENARIO4", player:GetScoreFromScenario4()));
		end
	end

end


-- ===========================================================================
--	Resize the width of the last box based on whether or not a scrollbar exists
-- ===========================================================================
function RealizeScrollArea()
	
	Controls.MajorStack:CalculateSize();
	Controls.MainScrollPanel:CalculateInternalSize();

	-- Scrollbar needed?  If so, make room for it...
	if IsScrollbarShowing( Controls.MainScrollPanel ) then
			
		local ui;
		for _,ui in ipairs( g_uiListItems ) do
			ui:SetSizeX( ART_LIST_ITEM_W_SCROLLBAR_WIDTH );
		end
	end

end

-- ===========================================================================
--	Remove extra newline off the end if we have one	
-- ===========================================================================
function RemoveTrailingNewLine( strInfo )
	if (Locale.EndsWith(strInfo, "[NEWLINE]")) then
		local iNewLength = Locale.Length(strInfo)-9;
		strInfo = Locale.Substring(strInfo, 1, iNewLength);
	end
	return strInfo;
end	
