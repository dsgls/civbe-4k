----------------------------------------------------------------        
----------------------------------------------------------------        
include( "IconSupport" );
include( "InstanceManager" );
include( "SupportFunctions"  );
include( "InfoTooltipInclude"  );

local g_UsPocketCitiesIM    = InstanceManager:new( "CityInstance", "Button", Controls.UsPocketCitiesStack );
local g_ThemPocketCitiesIM  = InstanceManager:new( "CityInstance", "Button", Controls.ThemPocketCitiesStack );
local g_UsTableCitiesIM     = InstanceManager:new( "CityOfferInstance", "Button", Controls.UsTableCitiesStack );
local g_ThemTableCitiesIM   = InstanceManager:new( "CityOfferInstance", "Button", Controls.ThemTableCitiesStack );


local g_bAlwaysWar		= Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_WAR );
local g_bAlwaysPeace	= Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_PEACE );
local g_bNoChangeWar	= Game.IsOption( GameOptionTypes.GAMEOPTION_NO_CHANGING_WAR_PEACE );


----------------------------------------------------------------        
-- local storage
----------------------------------------------------------------        
local g_Deal = UI.GetScratchDeal(); 
local g_iDiploUIState = DiploUIStateTypes.NO_DIPLO_UI_STATE;
local g_bPVPTrade;
local g_bTradeReview = false;
local g_iNumOthers;
local g_bEnableThirdParty = true;
local g_OfferIsFixed = false;						-- Is the human allowed to change the offer?  Set to true when the AI is demanding or making a request

local g_iConcessionsPreviousDiploUIState = -1;
local g_bHumanOfferingConcessions = false;

local g_iDealDuration = Game.GetDealDuration();
local g_iPeaceDuration = Game.GetPeaceDuration();

local g_iUs = -1; --Game.GetActivePlayer();
local g_iThem = -1;
local g_pUs = -1;
local g_pThem = -1;
local g_iUsTeam = -1;
local g_iThemTeam = -1;
local g_pUsTeam = -1;
local g_pThemTeam = -1;
local g_pUsLeader = -1;
local g_pThemLeader = -1;
local g_UsPocketResources   = {};
local g_ThemPocketResources = {};
local g_UsTableResources    = {};
local g_ThemTableResources  = {};
local g_LuxuryList          = {};

local g_bMessageFromDiploAI = false;
local g_bAIMakingOffer = false;

local g_UsOtherPlayerMode   = -1;
local g_ThemOtherPlayerMode = -1;

local g_OtherPlayersButtons = {};

local g_bNewDeal = true;

local WAR     = 0;
local PEACE   = 1;

local PROPOSE_TYPE = 1;  -- player is making a proposal
local WITHDRAW_TYPE = 2;  -- player is withdrawing their offer
local ACCEPT_TYPE   = 3;  -- player is accepting someone else's proposal

local CANCEL_TYPE   = 0;  -- player is canceling their draft
local REFUSE_TYPE   = 1;  -- player is refusing someone else's deal

local oldCursor = 0;

local g_iThemIconSize = 64;
if(Controls.ThemCivIconBG ~= nil) then
	g_iThemIconSize = Controls.ThemCivIconBG:GetSizeX();
end

local g_iUsIconSize = 64;
if(Controls.UsCivIcon ~= nil) then
	g_iUsIconSize = Controls.UsCivIconBG:GetSizeX();
end

---------------------------------------------------------
-- LEADER MESSAGE HANDLER
---------------------------------------------------------
function LeaderMessageHandler( iPlayer, iDiploUIState, szLeaderMessage, iAnimationAction, iData1 )
    g_bPVPTrade = false;
    
    -- If we were just in discussion mode and the human offered to make concessions, make a note of that
	if (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_HUMAN_OFFERS_CONCESSIONS) then
		if (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_DISCUSS_YOU_EXPANSION_SERIOUS_WARNING) then
			--print("Human offers concessions for expansion");
			g_iConcessionsPreviousDiploUIState = g_iDiploUIState;
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_DISCUSS_YOU_PLOT_BUYING_SERIOUS_WARNING) then
			--print("Human offers concessions for plot buying");
			g_iConcessionsPreviousDiploUIState = g_iDiploUIState;
		end
	end

	g_iDiploUIState = iDiploUIState;
	
	g_iUs = Game.GetActivePlayer();
	g_pUs = Players[ g_iUs ];
    
	g_iUsTeam = g_pUs:GetTeam();
	g_pUsTeam = Teams[ g_iUsTeam ];
    
	g_iThem = iPlayer;
	g_pThem = Players[ g_iThem ];
	g_iThemTeam = g_pThem:GetTeam();
	g_pThemTeam = Teams[ g_iThemTeam ];
	g_pUsLeader = GameInfo.Leaders[g_pUs:GetLeaderType()];
	g_pThemLeader = GameInfo.Leaders[g_pThem:GetLeaderType()];
	
	local bMyMode = false;
	
	-- Are we in Trade Mode?
	if (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_HUMAN_OFFERS_CONCESSIONS) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_OFFER) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_ACCEPTS_OFFER) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_REJECTS_OFFER) then
		bMyMode = true;
	elseif (iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND) then
		bMyMode = true;
	end
	
	if (bMyMode) then
		
		--print("TradeScreen: It's MY mode!");
		
		if (ContextPtr:IsHidden()) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.LeaderTrade );
		end
		
		--print("Handling LeaderMessage: " .. iDiploUIState .. ", ".. szLeaderMessage);
	    
		g_Deal:SetFromPlayer(g_iUs);
		g_Deal:SetToPlayer(g_iThem);
		
		-- Unhide our pocket, in case the last thing we were doing in this screen was a human demand
		Controls.UsPanel:SetHide(false);
		--Controls.UsGlass:SetHide(false);
		
		local bClearTableAndDisplayDeal = false;

		g_OfferIsFixed = false;
		
		-- Is this a UI State where we should be displaying a deal?
		if (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE) then
			--print("DiploUIState: Default Trade");
			bClearTableAndDisplayDeal = true;
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND) then
			--print("DiploUIState: AI making demand");
			bClearTableAndDisplayDeal = true;
			g_Deal:SetDemandingPlayer(g_iThem);
			
			DoDemandState(true);
			
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST) then
			--print("DiploUIState: AI making Request");
			bClearTableAndDisplayDeal = true;
			g_Deal:SetRequestingPlayer(g_iThem);
			
			DoDemandState(true);
			
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND) then
			--print("DiploUIState: Human Demand");
			bClearTableAndDisplayDeal = true;
			g_Deal:SetDemandingPlayer(g_iUs);

			-- If we're demanding something, there's no need to show OUR items
			Controls.UsPanel:SetHide(true);
			--Controls.UsGlass:SetHide(true);
			
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_HUMAN_OFFERS_CONCESSIONS) then
			--print("DiploUIState: Human offers concessions");
			bClearTableAndDisplayDeal = true;
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_OFFER) then
			--print("DiploUIState: AI making offer");
			bClearTableAndDisplayDeal = true;
			g_bAIMakingOffer = true;
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_ACCEPTS_OFFER) then
			--print("DiploUIState: AI accepted offer");
			g_iConcessionsPreviousDiploUIState = -1;		-- Clear out the fact that we were offering concessions if the AI has agreed to a deal
			bClearTableAndDisplayDeal = true;
			
		-- If the AI rejects a deal, don't clear the table: keep the items where they are in case the human wants to change things
		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_REJECTS_OFFER) then
			--print("DiploUIState: AI rejects offer");
			bClearTableAndDisplayDeal = false;
		else
			--print("DiploUIState: ?????");
		end

		-- Clear table and display the deal currently stored in InterfaceBuddy
		if (bClearTableAndDisplayDeal) then
			g_bMessageFromDiploAI = true;
			
			Controls.DiscussionText:SetText( szLeaderMessage );
		    
			DoClearTable();
			DisplayDeal();
			
		-- Don't clear the table, leave things as they are
		else
			
			--print("NOT clearing table");
			
			g_bMessageFromDiploAI = true;
			
			Controls.DiscussionText:SetText( szLeaderMessage );
		end
		
		DoUpdateButtons();
		
	-- Not in trade mode
	else
		
		--print("TradeScreen: NOT my mode! Hiding!");
		--print("iDiploUIState: " .. iDiploUIState);
		
        g_Deal:ClearItems();

		if (not ContextPtr:IsHidden()) then
			ContextPtr:SetHide( true );
	    end
	
	end
	
end
--Events.AILeaderMessage.Add( LeaderMessageHandler );


----------------------------------------------------------------
-- Used by SimpleDiploTrade to display pvp deals
----------------------------------------------------------------
function OnOpenPlayerDealScreen( iOtherPlayer )
    
    --print( "OpenPlayerDealScreen: " .. iOtherPlayer );

    -- open a new deal with iThem
	g_iUs = Game.GetActivePlayer();
	g_pUs = Players[ g_iUs ];
	g_iUsTeam = g_pUs:GetTeam();
	g_pUsTeam = Teams[ g_iUsTeam ];

	g_iThem = iOtherPlayer;
	g_pThem = Players[ g_iThem ];
	g_iThemTeam = g_pThem:GetTeam();
	g_pThemTeam = Teams[ g_iThemTeam ];
	g_pUsLeader = GameInfo.Leaders[g_pUs:GetLeaderType()];
	g_pThemLeader = GameInfo.Leaders[g_pThem:GetLeaderType()];
	
	-- if someone is trying to open the deal screen when they are not allowed to negotiate peace
	-- or they already have an outgoing deal, stop them here rather than at all the places we send this event
	
    local iProposalTo = UI.HasMadeProposal( g_iUs );
	--print( "proposal: " .. iProposalTo );
	--print( "war: " .. tostring( g_pUsTeam:IsAtWar( g_iThemTeam ) ) );
	--print( "war: " .. tostring( g_bAlwaysWar or g_bNoChangeWar ) );
	

	  -- this logic should match OnOpenPlayerDealScreen in TradeLogic.lua, DiploCorner.lua, and DiploList.lua  
    if( (g_pUsTeam:IsAtWar( g_iThemTeam ) and (g_bAlwaysWar or g_bNoChangeWar) ) or																			-- Always at War
	    (iProposalTo ~= -1 and iProposalTo ~= iOtherPlayer and not UI.ProposedDealExists(iOtherPlayer, g_iUs)) ) then -- Only allow one proposal from us at a time.
	    -- do nothing
	    return;
    end
   
    --print( "where?" ); 
	if( g_iUs == g_iThem ) then
	    print( "ERROR: OpenPlayerDealScreen called with local player" );
    end
    
    if( UI.ProposedDealExists( g_iUs, g_iThem ) ) then -- this is our proposal
    	g_bNewDeal = false;
        UI.LoadProposedDeal( g_iUs, g_iThem );
    	DoUpdateButtons();
        
    elseif( UI.ProposedDealExists( g_iThem, g_iUs ) ) then -- this is their proposal
    	g_bNewDeal = false;
        UI.LoadProposedDeal( g_iThem, g_iUs );
    	DoUpdateButtons();
        
    else
    	g_bNewDeal = true;
        g_Deal:ClearItems();
    	g_Deal:SetFromPlayer( g_iUs );
    	g_Deal:SetToPlayer( g_iThem );
    	
        if( g_pUsTeam:IsAtWar( g_iThemTeam ) ) then
            g_Deal:AddPeaceTreaty( g_iUs, GameDefines.PEACE_TREATY_LENGTH );
            g_Deal:AddPeaceTreaty( g_iThem, GameDefines.PEACE_TREATY_LENGTH );
        end
        
    	DoUpdateButtons();
    end

    g_bPVPTrade = true;

	ContextPtr:SetHide( false );
    
	DoClearTable();
	DisplayDeal();
end


----------------------------------------------------------------
-- used by DiploOverview to display active deals
----------------------------------------------------------------
function OpenDealReview()

    --print( "OpenDealReview" );
    
	g_iUs = Game:GetActivePlayer();
	g_pUs = Players[ g_iUs ];
	g_iUsTeam = g_pUs:GetTeam();
	g_pUsTeam = Teams[ g_iUsTeam ];

	g_iThem = g_Deal:GetOtherPlayer( g_iUs );
	g_pThem = Players[ g_iThem ];
	g_iThemTeam = g_pThem:GetTeam();
	g_pThemTeam = Teams[ g_iThemTeam ];
	g_pUsLeader = GameInfo.Leaders[g_pUs:GetLeaderType()];
	g_pThemLeader = GameInfo.Leaders[g_pThem:GetLeaderType()];
	
	if( g_iUs == g_iThem ) then
	    print( "ERROR: OpenDealReview called with local player" );
    end
	
    g_bPVPTrade = false;
    g_bTradeReview = true;

	DoClearTable();
	DisplayDeal();
end


----------------------------------------------------------------
-- BACK
----------------------------------------------------------------
function OnBack( iType )

    if( g_bPVPTrade or g_bTradeReview ) then
        
        if( iType == CANCEL_TYPE ) then
            g_Deal:ClearItems();
        elseif( iType == REFUSE_TYPE ) then
        	UI.DoFinalizePlayerDeal( g_iThem, g_iUs, false );
        end
    	
	    ContextPtr:SetHide( true );
	    ContextPtr:CallParentShowHideHandler( false );
	else
        g_Deal:ClearItems();
		
    	-- Human refused to give into an AI demand - this button doubles as the Demand "Refuse" option
    	if (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND or
    		g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST) then
    		
    		--print("Human refused demand!");
    		
    		DoDemandState(false);
    		
    		DoClearTable();
    		ResetDisplay();
    		
    		if (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND) then
    			Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_DEMAND_HUMAN_REFUSAL, g_iThem, 0, 0 );
    		elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST) then
    			local iDealValue = 0;
				if (g_Deal) then
					iDealValue = g_pUs:GetDealMyValue(g_Deal);
				end
    			Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_REQUEST_HUMAN_REFUSAL, g_iThem, iDealValue, 0 );
    		end
    		
    		g_iDiploUIState = DiploUIStateTypes.DIPLO_UI_STATE_TRADE;
    		
    	-- Exit screen normally
        else
    		
        	if (g_iThem ~= -1) then
    			Players[g_iThem]:DoTradeScreenClosed(g_bAIMakingOffer);
    		end

    	    -- Don't assume we have a message from the AI leader any more
    		g_bMessageFromDiploAI = false;
    		
    		-- If the AI opened the screen to make an offer, clear that status
    		g_bAIMakingOffer = false;
    		
    		-- Reset value that keeps track of how many times we offered a bad deal (for dialogue purposes)
    		UI.SetOfferTradeRepeatCount(0);
    	    
    		-- If the human was offering concessions, he backed out
    		if (g_iConcessionsPreviousDiploUIState ~= -1) then
    			--print("Human backing out of Concessions Offer.  Reseting DiploUIState to trade.");
    			
    			iButtonID = 1;		-- This corresponds with the buttons in DiscussionDialog.lua
    		    
    			-- AI seriously warning us about expansion - we tell him to go away
    			if (g_iConcessionsPreviousDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_DISCUSS_YOU_EXPANSION_SERIOUS_WARNING) then
    				Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_EXPANSION_SERIOUS_WARNING_RESPONSE, g_iThem, iButtonID, 0 );
    			-- AI seriously warning us about plot buying - we tell him to go away
    			elseif (g_iConcessionsPreviousDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_DISCUSS_YOU_PLOT_BUYING_SERIOUS_WARNING) then
    				Game.DoFromUIDiploEvent( FromUIDiploEventTypes.FROM_UI_DIPLO_EVENT_PLOT_BUYING_SERIOUS_WARNING_RESPONSE, g_iThem, iButtonID, 0 );
    			end

    			g_iConcessionsPreviousDiploUIState = -1;
			end
			
    		-- Exiting human demand mode, unhide his items
    		if (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND) then
				Controls.UsPanel:SetHide(false);
				--Controls.UsGlass:SetHide(false);
    		end
					
		    UIManager:DequeuePopup( ContextPtr );

			LuaEvents.LeaderheadRootShow();	
		end
	end

end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnBack );


----------------------------------------------------------------        
-- SHOW/HIDE
----------------------------------------------------------------        
function OnShowHide( isHide, bIsInit )
	
	-- WARNING: Don't put anything important in here related to gameplay. This function may be called when you don't expect it
	
    if( not bIsInit ) then
    	-- Showing screen
        if( not isHide ) then		
    		oldCursor = UIManager:SetUICursor(0); -- make sure we start with the default cursor
    	    
    		if( g_iUs   ~= -1 ) then g_Deal:SetFromPlayer( g_iUs   ); end
    		if( g_iThem ~= -1 ) then g_Deal:SetToPlayer( g_iThem ); end
    		
            -- reset all the controls on show
            Controls.UsPocketCitiesStack:SetHide( true );
            Controls.ThemPocketCitiesStack:SetHide( true );
            Controls.UsPocketOtherPlayerStack:SetHide( true );
            Controls.ThemPocketOtherPlayerStack:SetHide( true );
            Controls.UsPocketStrategicStack:SetHide( true );
            Controls.ThemPocketStrategicStack:SetHide( true );
            
            Controls.UsPocketPanel:SetScrollValue( 0 );
            Controls.UsTablePanel:SetScrollValue( 0 );
            Controls.ThemPocketPanel:SetScrollValue( 0 );
            Controls.ThemTablePanel:SetScrollValue( 0 );
		            
            -- hide unmet players
            if( g_bEnableThirdParty ) then
                g_iNumOthers = 0;
            	for iLoopPlayer = 0, GameDefines.MAX_CIV_PLAYERS-1, 1 do
            		pLoopPlayer = Players[ iLoopPlayer ];
            		iLoopTeam = pLoopPlayer:GetTeam();
					
					--print("iLoopPlayer: " .. iLoopPlayer);
					
					if (pLoopPlayer:IsEverAlive()) then
						
        				if( g_iUs ~= iLoopPlayer and g_iThem ~= iLoopPlayer and
                			g_pUsTeam:IsHasMet( iLoopTeam ) and g_pThemTeam:IsHasMet( iLoopTeam ) and
                			pLoopPlayer:IsAlive()) then

            				g_OtherPlayersButtons[ iLoopPlayer ].UsPocket.Button:SetHide( false );
            				g_OtherPlayersButtons[ iLoopPlayer ].ThemPocket.Button:SetHide( false );
            				g_iNumOthers = g_iNumOthers + 1;
        				else
            				g_OtherPlayersButtons[ iLoopPlayer ].UsPocket.Button:SetHide( true );
            				g_OtherPlayersButtons[ iLoopPlayer ].ThemPocket.Button:SetHide( true );
            			end
            		end
            	end
        	end
            
            ResetDisplay();
            
            -- Deal can already have items in it if, say, we're at war.  In this case every time we open the trade screen there's already Peace Treaty on both sides of the table
            if (g_Deal:GetNumItems() > 0) then
    			DisplayDeal();
            end
            
    		LuaEvents.TryQueueTutorial("DIPLO_TRADE_SCREEN", true);
            
        -- Hiding screen
        else
    		UIManager:SetUICursor(oldCursor); -- make sure we retrun the cursor to the previous state
    		LuaEvents.TryDismissTutorial("DIPLO_TRADE_SCREEN");			

        end
    end
    
end
ContextPtr:SetShowHideHandler( OnShowHide );


----------------------------------------------------------------        
-- Key Down Processing
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
    if( uiMsg == KeyEvents.KeyDown ) then
        
		if( wParam == Keys.VK_ESCAPE ) then
        
			-- Don't allow any keys to exit screen when AI is asking for something - want to make sure the human has to click something
    		if (g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND and
    			g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST) then
    				    		
				OnBack();		
			end
				
			return true;
        end

		-- Consume enter here otherwise it may be 
		-- interpretted as dismissing the dialog.
		if ( wParam == Keys.VK_RETURN) then
			return true;
		end

    end
    return false;
end

---------------------------------------------------------
-- UI Deal was modified somehow
---------------------------------------------------------
function DoUIDealChangedByHuman()
	
	--print("UI Deal Changed");
		
	-- Set state to the default so that it doesn't cause any funny behavior later
	if (g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND) then
		g_iDiploUIState = DiploUIStateTypes.DIPLO_UI_STATE_TRADE;
	end
	
	DoUpdateButtons();
	
end


---------------------------------------------------------
-- Update buttons at the bottom
---------------------------------------------------------
function DoUpdateButtons()
	
	-- Dealing with a human in a MP game
    if (g_bPVPTrade) then
		
        --print( "PVP Updating ProposeButton" );
	    
        if( g_bNewDeal ) then
            Controls.ProposeButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_PROPOSE" ));
            Controls.ProposeButton:SetVoid1( PROPOSE_TYPE );
            Controls.CancelButton:SetHide( true );
            
            Controls.ModifyButton:SetHide( true );
            Controls.Pockets:SetHide( false );
            Controls.ModificationBlock:SetHide( true );
            
        elseif( UI.HasMadeProposal( g_iUs ) == g_iThem ) then
            Controls.ProposeButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_WITHDRAW" ));
            Controls.ProposeButton:SetVoid1( WITHDRAW_TYPE );
            Controls.CancelButton:SetHide( true );
            
            Controls.ModifyButton:SetHide( true );
            Controls.Pockets:SetHide( true );
            Controls.ModificationBlock:SetHide( false );
            
        else
            Controls.ProposeButton:SetVoid1( ACCEPT_TYPE );
            Controls.ProposeButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_ACCEPT" ));
            Controls.CancelButton:SetVoid1( REFUSE_TYPE );
            Controls.CancelButton:SetHide( false );
            
            Controls.ModifyButton:SetHide( false );
            Controls.Pockets:SetHide( true );
            Controls.ModificationBlock:SetHide( false );
        end
        
        Controls.MainStack:CalculateSize();
        Controls.MainGrid:DoAutoSize();

	-- Dealing with an AI
	elseif (g_bPVPTrade == false and g_bTradeReview == false) then
		
		-- Human is making a demand
        if( g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND ) then
            Controls.ProposeButton:SetText( Locale.ToUpper(Locale.ConvertTextKey( "TXT_KEY_DIPLO_DEMAND_BUTTON" )));
            Controls.CancelButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_CANCEL" ));
            
    	-- If the AI made an offer change what buttons are visible for the human to respond with
    	elseif (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_OFFER) then
    		Controls.ProposeButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_ACCEPT" ));
    		Controls.CancelButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_REFUSE" ));
    		
    	-- AI is making a demand or Request
    	elseif (	g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND or 
    				g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST) then
    				
    		Controls.ProposeButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_ACCEPT" ));
    		Controls.CancelButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_REFUSE" ));
    		
    	else
    		Controls.ProposeButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_PROPOSE" ));
    		Controls.CancelButton:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_CANCEL" ));
    	end
		
		Controls.WhatDoYouWantButton:SetHide(true);
		Controls.WhatWillYouGiveMeButton:SetHide(true);
		Controls.WhatWillMakeThisWorkButton:SetHide(true);
		Controls.WhatWillEndThisWarButton:SetHide(true);
 		Controls.WhatConcessionsButton:SetHide(true);

		-- At War: show the "what will end this war button
		if (g_iUsTeam >= 0 and g_iThemTeam >= 0 and Teams[g_iUsTeam]:IsAtWar(g_iThemTeam)) then
			Controls.WhatWillEndThisWarButton:SetHide(false);
		-- Not at war
		else
			-- AI asking player for concessions
			if (UI.IsAIRequestingConcessions()) then
	 			Controls.WhatConcessionsButton:SetHide(false);
				
			-- Is the someone making a demand?
			elseif (	g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_DEMAND and
						g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_REQUEST and
						g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND and
						g_iDiploUIState ~= DiploUIStateTypes.DIPLO_UI_STATE_TRADE_AI_MAKES_OFFER) then
				
				-- Loop through deal items to see what the situation is
				local iNumItemsFromUs = 0;
				local iNumItemsFromThem = 0;
				
				local itemType;
				local duration;
				local finalTurn;
				local data1;
				local data2;
				local data3;
				local flag1;
				local fromPlayer;
			    
				g_Deal:ResetIterator();
				itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayer = g_Deal:GetNextItem();
			    
				if( itemType ~= nil ) then
				repeat
					local bFromUs = false;
			        
					if( fromPlayer == Game.GetActivePlayer() ) then
						bFromUs = true;
						iNumItemsFromUs = iNumItemsFromUs + 1;
					else
						iNumItemsFromThem = iNumItemsFromThem + 1;
					end
					
			        itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayer = g_Deal:GetNextItem();
			        
				until( itemType == nil )
				end
				
				-- Depending on what's on the table we can ask the other player about what they think of the deal
				if (iNumItemsFromUs > 0 and iNumItemsFromThem == 0) then
					Controls.WhatWillYouGiveMeButton:SetHide(false);
				elseif (iNumItemsFromUs == 0 and iNumItemsFromThem > 0) then
					Controls.WhatDoYouWantButton:SetHide(false);
				elseif (iNumItemsFromUs > 0 and iNumItemsFromThem > 0) then
					Controls.WhatWillMakeThisWorkButton:SetHide(false);
				end
			end
		end

		-- If they're making a demand and there's nothing on our side of the table then we can't propose anything
		if (UI.IsAIRequestingConcessions() and iNumItemsFromUs == 0) then
	 		Controls.ProposeButton:SetHide(true);
		else
 			Controls.ProposeButton:SetHide(false);
		end
	end

end


---------------------------------------------------------
-- AI is making a demand of the human
---------------------------------------------------------
function DoDemandState(bDemandOn)
	
	-- AI is demanding something, hide options that are not useful
	if (bDemandOn) then
		Controls.UsPanel:SetHide(true);
		--Controls.UsGlass:SetHide(true);
		Controls.ThemPanel:SetHide(true);
		--Controls.ThemGlass:SetHide(true);
		Controls.UsTableCover:SetHide(false);
		Controls.ThemTableCover:SetHide(false);

		g_OfferIsFixed = true;
		
	-- Exiting demand mode, unhide stuff
	else
		Controls.UsPanel:SetHide(false);
		--Controls.UsGlass:SetHide(false);
		Controls.ThemPanel:SetHide(false);
		--Controls.ThemGlass:SetHide(false);
		Controls.UsTableCover:SetHide(true);
		Controls.ThemTableCover:SetHide(true);

		g_OfferIsFixed = false;
		
	    UIManager:DequeuePopup( ContextPtr );
	    
	end
	
end


---------------------------------------------------------
-- Clear all items off the table (both UI and CvDeal)
---------------------------------------------------------
function DoClearDeal()
	
	--print("Clearing Table");
	
    g_Deal:ClearItems();
    DoClearTable();
end
Events.ClearDiplomacyTradeTable.Add(DoClearDeal);



---------------------------------------------------------
-- stack open/close handlers
---------------------------------------------------------
local g_SubStacks = {};
g_SubStacks[ tostring( Controls.UsPocketOtherPlayer       ) ] = Controls.UsPocketOtherPlayerStack;
g_SubStacks[ tostring( Controls.ThemPocketOtherPlayer     ) ] = Controls.ThemPocketOtherPlayerStack;
g_SubStacks[ tostring( Controls.UsPocketStrategic   ) ] = Controls.UsPocketStrategicStack;
g_SubStacks[ tostring( Controls.ThemPocketStrategic ) ] = Controls.ThemPocketStrategicStack;

local g_SubLabels = {};
g_SubLabels[ tostring( Controls.UsPocketOtherPlayer       ) ] = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_OTHER_PLAYERS" );
g_SubLabels[ tostring( Controls.ThemPocketOtherPlayer     ) ] = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_OTHER_PLAYERS" );
g_SubLabels[ tostring( Controls.UsPocketStrategic   ) ] = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_STRATEGIC_RESOURCES" );
g_SubLabels[ tostring( Controls.ThemPocketStrategic ) ] = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_STRATEGIC_RESOURCES" );

Controls.UsPocketOtherPlayer:SetVoid1( 1 );
Controls.UsPocketStrategic:SetVoid1( 1 );

function SubStackHandler( bIsUs, none, control )
    local stack = g_SubStacks[ tostring( control ) ];
    local label = g_SubLabels[ tostring( control ) ];
    
    if( stack:IsHidden() ) then
        stack:SetHide( false );
        control:SetText( "[ICON_MINUS]" .. Locale.ConvertTextKey( label ) );
    else
        stack:SetHide( true );
        control:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( label ) );
    end
    
    if( bIsUs == 1 )
    then
        Controls.UsPocketStack:CalculateSize();
        Controls.UsPocketPanel:CalculateInternalSize();
        Controls.UsPocketPanel:ReprocessAnchoring();
    else
        Controls.ThemPocketStack:CalculateSize();
        Controls.ThemPocketPanel:CalculateInternalSize();
        Controls.ThemPocketPanel:ReprocessAnchoring();
    end
end
Controls.UsPocketOtherPlayer:RegisterCallback( Mouse.eLClick, SubStackHandler );
Controls.ThemPocketOtherPlayer:RegisterCallback( Mouse.eLClick, SubStackHandler );
Controls.UsPocketStrategic:RegisterCallback( Mouse.eLClick, SubStackHandler );
Controls.ThemPocketStrategic:RegisterCallback( Mouse.eLClick, SubStackHandler );

----------------------------------------------------------------
-- Proposal and Negotiate functions
----------------------------------------------------------------

function OnModify()
    g_bNewDeal = true;
    DoUpdateButtons();
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnPropose( iType )
	
	if (g_Deal:GetNumItems() == 0) then
		return;
	end
	
    --print( "OnPropose: " .. tostring( g_bPVPTrade ) .. " " .. iType );
    
    -- Trade between humans
    if( g_bPVPTrade ) then
        
        if( iType == PROPOSE_TYPE ) then
        	UI.DoProposeDeal();
        	
        elseif( iType == WITHDRAW_TYPE ) then
        	UI.DoFinalizePlayerDeal( g_iUs, g_iThem, false );
        
        elseif( iType == ACCEPT_TYPE ) then
        	UI.DoFinalizePlayerDeal( g_iThem, g_iUs, true );
        	
    	else
    	    print( "invalid ProposalType" );
        end
    	
	    ContextPtr:SetHide( true );
	    ContextPtr:CallParentShowHideHandler( false );
	    
	-- Trade between a human & an AI
	else
		
		-- Human Demanding something
		if (g_iDiploUIState == DiploUIStateTypes.DIPLO_UI_STATE_HUMAN_DEMAND) then
    		UI.DoDemand();
    		
    	-- Trade offer
    	else
    		UI.DoProposeDeal();
    	end
        
        -- Don't assume we have a message from the AI leader any more
        g_bMessageFromDiploAI = false;
    	
    	-- If the AI was demanding something, we're not in that state any more
    	DoDemandState(false);
	end
end
Controls.ProposeButton:RegisterCallback( Mouse.eLClick, OnPropose );


----------------------------------------------------------------
----------------------------------------------------------------
function OnEqualizeDeal()
	
	UI.DoEqualizeDealWithHuman();
    
    -- Don't assume we have a message from the AI leader any more
    g_bMessageFromDiploAI = false;
	
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnWhatDoesAIWant()
	
	UI.DoWhatDoesAIWant();
    
    -- Don't assume we have a message from the AI leader any more
    g_bMessageFromDiploAI = false;
	
end


----------------------------------------------------------------
----------------------------------------------------------------
function OnWhatWillAIGive()
	
	UI.DoWhatWillAIGive();
    
    -- Don't assume we have a message from the AI leader any more
    g_bMessageFromDiploAI = false;
	
end


----------------------------------------------------------------        
----------------------------------------------------------------        
function ResetDisplay()
	
	--print("ResetDisplay");
	
	if g_iUs == -1 or g_iThem == -1 then
		return;
	end

	Controls.UsPocketStack:SetHide( false );
	Controls.ThemPocketStack:SetHide( false );
	Controls.UsPocketLeaderStack:SetHide( true );
	Controls.ThemPocketLeaderStack:SetHide( true );
	Controls.UsPocketCitiesStack:SetHide( true );
	Controls.ThemPocketCitiesStack:SetHide( true );
	
	Controls.UsPocketFavors:SetHide( false );
    Controls.ThemPocketFavors:SetHide( false );
	Controls.UsPocketEnergy:SetHide( false );
    Controls.ThemPocketEnergy:SetHide( false );
    Controls.UsPocketEnergyPerTurn:SetHide( false );
    Controls.ThemPocketEnergyPerTurn:SetHide( false );
    Controls.UsPocketResearchPerTurn:SetHide( false );
    Controls.ThemPocketResearchPerTurn:SetHide( false );
    Controls.UsPocketOpenBorders:SetHide( false );
    Controls.ThemPocketOpenBorders:SetHide( false );
    Controls.UsPocketAlliance:SetHide( false );
    Controls.ThemPocketAlliance:SetHide( false );
    --Controls.UsPocketTradeAgreement:SetHide( false );		Trade agreement disabled for now
    --Controls.ThemPocketTradeAgreement:SetHide( false );		Trade agreement disabled for now
    if (Controls.UsPocketCoopAgreement ~= nil) then
		Controls.UsPocketCoopAgreement:SetHide( false );
		Controls.UsPocketCoopAgreement:RegisterCallback( Mouse.eLClick, PocketDoFHandler );
		Controls.UsPocketCoopAgreement:SetVoid1( 1 );		
	end
    if (Controls.ThemPocketCoopAgreement ~= nil) then
		Controls.ThemPocketCoopAgreement:SetHide( false );
		Controls.ThemPocketCoopAgreement:RegisterCallback( Mouse.eLClick, PocketDoFHandler );
		Controls.ThemPocketCoopAgreement:SetVoid1( 0 );
	end

	-- Propose button could have had its text changed to "ACCEPT" if the AI made an offer to the human 
	DoUpdateButtons();

	local bHumanToHumanTrade : boolean = (g_pUs:IsHuman() and g_pThem:IsHuman());

	if( not g_bMessageFromDiploAI ) then
		DoClearTable();
	end
	
    if( g_bTradeReview ) then
        -- review mode 

    	Controls.TradeDetails:SetHide( false );
      
	  	CivIconHookup( g_iUs, g_iUsIconSize, Controls.UsCivIcon, Controls.UsCivIconBG, nil, false, false, Controls.UsCivIconHighlight );
		CivIconHookup( g_iThem, g_iThemIconSize, Controls.ThemCivIcon, Controls.ThemCivIconBG, nil, false, false, Controls.ThemCivIconHighlight );

    	--Keep "Your": Controls.UsText:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_LABEL", Locale.ConvertTextKey( g_pUs:GetNameKey() ) ) );		
		local primaryColorRaw, secondaryColorRaw = g_pUs:GetPlayerColors();
		local primaryColor = RGBAObjectToABGRHex( primaryColorRaw );
		Controls.UsText:SetColor( primaryColor, 0 );

        if( m_bIsMulitplayer and pOtherPlayer:IsHuman() ) then
			local MAX_NAME_CHARS= 20;
			local strNickName		= TruncateStringByLength(g_pThem:GetNickName(), MAX_NAME_CHARS);
        	Controls.ThemText:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_LABEL", Locale.ConvertTextKey( strNickName ) ) );
		else
        	Controls.ThemText:SetText( Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_LABEL", Locale.ConvertTextKey( g_pThem:GetName() ) ) );
    	end

		primaryColorRaw, secondaryColorRaw = g_pThem:GetPlayerColors();
		primaryColor = RGBAObjectToABGRHex( primaryColorRaw );
		Controls.ThemText:SetColor( primaryColor, 0 );
    
    elseif( g_bPVPTrade == false ) then
	    -- ai mode
    	Controls.WhatDoYouWantButton:SetHide(true);
    	Controls.WhatWillYouGiveMeButton:SetHide(true);
    	Controls.WhatWillMakeThisWorkButton:SetHide(true);

		-- Name
    	local strString = Locale.ConvertTextKey("TXT_KEY_DIPLO_LEADER_SAYS", g_pThem:GetName());
    	Controls.NameText:SetText( Locale.ToUpper(strString));

		-- Mood
		local iApproach = g_pUs:GetApproachTowardsUsGuess(g_iThem);
		local strMoodText = Locale.ConvertTextKey("TXT_KEY_EMOTIONLESS");
	
		if (g_pUsTeam:IsAtWar(g_iThemTeam)) then
			strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR" );
		elseif (g_pThem:IsDenouncingPlayer(g_iUS)) then
			strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_DENOUNCING" );	
		elseif (g_pThem:WasResurrectedThisTurnBy(g_iUs)) then
			strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_LIBERATED" );
		else
			if( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_WAR ) then
				strMoodText = Locale.ConvertTextKey( "TXT_KEY_WAR_CAPS" );
			elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_HOSTILE ) then
				strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_HOSTILE", g_pThemLeader.Description );
			elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_GUARDED ) then
				strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_GUARDED", g_pThemLeader.Description  );
			elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_AFRAID ) then
				strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_AFRAID", g_pThemLeader.Description  );
			elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_FRIENDLY ) then
				strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_FRIENDLY", g_pThemLeader.Description  );
			elseif( iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_NEUTRAL ) then
				strMoodText = Locale.ConvertTextKey( "TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_NEUTRAL", g_pThemLeader.Description  );
			end
		end
	
		Controls.MoodText:SetText(Locale.ToUpper(strMoodText));
	
		local strMoodInfo = GetMoodInfo(g_iThem);
		Controls.MoodText:SetToolTipString(strMoodInfo);
	
    	if( not g_bMessageFromDiploAI ) then
    		Controls.DiscussionText:SetText(Locale.ConvertTextKey("TXT_KEY_DIPLO_HERE_OFFER"));
    	end
 	
    	-- Set Civ Icon
    	CivIconHookup( g_iThem, g_iThemIconSize, Controls.ThemCivIcon, Controls.ThemCivIconBG, nil, false, false, Controls.ThemCivIconHighlight );

		-- ThemText is LeaderNameItems for AI

		-- Necessary to set gender, etc... for non-English localization.
		local themNameEntireLabel	= Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_LABEL", g_pThem:GetNameKey() ); 
		local themUpper				= Locale.ToUpper( themNameEntireLabel );
    	Controls.LeaderNameItems:SetText( themUpper );

    	-- set up their portrait
    	local themCivType = g_pThem:GetCivilizationType();
    	local themCivInfo = GameInfo.Civilizations[themCivType];
    	
    	local themLeaderType = g_pThem:GetLeaderType();
    	local themLeaderInfo = GameInfo.Leaders[themLeaderType];
    	
		IconHookup( themLeaderInfo.PortraitIndex, 128, themLeaderInfo.IconAtlas, Controls.ThemPortrait );
	
    	-- Is the AI is making demand?
    	if (UI.IsAIRequestingConcessions()) then
     		Controls.WhatConcessionsButton:SetHide(false);
     	else
     		Controls.WhatConcessionsButton:SetHide(true);
     	end

    	-- If we're at war with the other guy then show the "what will end this war" button
    	if (g_iUsTeam >= 0 and g_iThemTeam >= 0 and Teams[g_iUsTeam]:IsAtWar(g_iThemTeam)) then
    		Controls.WhatWillEndThisWarButton:SetHide(false);
    	else
    		Controls.WhatWillEndThisWarButton:SetHide(true);
    	end
	
	elseif( g_bTradeReview == false ) then
	    -- PvP mode
	 	
		CivIconHookup( g_iUs, g_iUsIconSize, Controls.UsCivIcon, Controls.UsCivIconBG, nil, false, false, Controls.UsCivIconHighlight );
		CivIconHookup( g_iThem, g_iThemIconSize, Controls.ThemCivIcon, Controls.ThemCivIconBG, nil, false, false, Controls.ThemCivIconHighlight );

		TruncateString(Controls.ThemName, Controls.ThemTablePanel:GetSizeX() - Controls.ThemTablePanel:GetOffsetX(), 
						   Locale.ConvertTextKey( "TXT_KEY_DIPLO_ITEMS_LABEL", g_pThem:GetNickName() ));
        Controls.ThemCiv:SetText( "(" .. Locale.ConvertTextKey( GameInfo.Civilizations[ g_pThem:GetCivilizationType() ].ShortDescription ) .. ")" );
    
    end
   
    
    local strTooltip;
    ---------------------------------------------------------------------------------- 
    -- pocket Energy
    ---------------------------------------------------------------------------------- 
    
    local iItemToBeChanged = -1;	-- This is -1 because we're not changing anything right now
    
    -- Us
    local iEnergy = g_Deal:GetGoldAvailable(g_iUs, iItemToBeChanged);
    local strEnergyString = iEnergy .. " " .. Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY");
    Controls.UsPocketEnergy:SetText( strEnergyString );
	Controls.UsPocketEnergy:ReprocessAnchoring(); --??TRON
    
    local bGoldTradeAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_ENERGY, 1);	-- 1 here is 1 Energy, which is the minimum possible
    
    if (not bGoldTradeAllowed) then
	    Controls.UsPocketEnergy:SetDisabled(true);
	    Controls.UsPocketEnergy:GetTextControl():SetColorByName("Gray_Black");
		-- Can't trade because no energy or no coop agreement
		if (iEnergy <= 0) then
			Controls.UsPocketEnergy:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_WARNING_NOT_ENOUGH_ENERGY"));
		else
			Controls.UsPocketEnergy:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_DIPLO_NEED_DOF_TT_ONE_LINE"));
		end
	else
	    Controls.UsPocketEnergy:SetDisabled(false);
	    Controls.UsPocketEnergy:GetTextControl():SetColorByName("Beige_Black");
	    Controls.UsPocketEnergy:SetToolTipString(nil);	    
    end

	-- Them
    iEnergy = g_Deal:GetGoldAvailable(g_iThem, iItemToBeChanged);
    strEnergyString = iEnergy .. " " .. Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY");
    Controls.ThemPocketEnergy:SetText( strEnergyString );
    
    bGoldTradeAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_ENERGY, 1);	-- 1 here is 1 Energy, which is the minimum possible
    
    if (not bGoldTradeAllowed) then
	    Controls.ThemPocketEnergy:SetDisabled(true);
	    Controls.ThemPocketEnergy:GetTextControl():SetColorByName("Gray_Black");
		-- Can't trade because no energy or no coop agreement
		if (iEnergy <= 0) then
			Controls.ThemPocketEnergy:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_WARNING_NOT_ENOUGH_ENERGY"));
		else
			Controls.ThemPocketEnergy:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_DIPLO_NEED_DOF_TT_ONE_LINE"));
		end
	else
	    Controls.ThemPocketEnergy:SetDisabled(false);
	    Controls.ThemPocketEnergy:GetTextControl():SetColorByName("Beige_Black");
	    Controls.ThemPocketEnergy:SetToolTipString(nil);	    
    end
    
    ---------------------------------------------------------------------------------- 
    -- pocket Energy Per Turn  
    ---------------------------------------------------------------------------------- 

	-- Us
	local iEnergyPerTurn = g_pUs:CalculateGoldRate();
    strEnergyString = iEnergyPerTurn .. " " .. Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY_PER_TURN" );
    Controls.UsPocketEnergyPerTurn:SetText( strEnergyString );	

    local bGPTAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_ENERGY_PER_TURN, 1, g_iDealDuration);	-- 1 here is 1 GPT, which is the minimum possible    

    if (not bGPTAllowed) then
	    Controls.UsPocketEnergyPerTurn:SetDisabled(true);
	    Controls.UsPocketEnergyPerTurn:GetTextControl():SetColorByName("Gray_Black");
		-- Can't trade because no energy or no coop agreement
		if (iEnergyPerTurn <= 0) then
			Controls.UsPocketEnergyPerTurn:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_POPUP_NOT_ENOUGH_ENERGY"));
		else
			Controls.UsPocketResearchPerTurn:SetToolTipString(nil);
		end
	else
	    Controls.UsPocketEnergyPerTurn:SetDisabled(false);
	    Controls.UsPocketEnergyPerTurn:GetTextControl():SetColorByName("Beige_Black");
		Controls.UsPocketEnergyPerTurn:SetToolTipString(nil);
    end
    
    -- Them
	iEnergyPerTurn = g_pThem:CalculateGoldRate();
    strEnergyString = iEnergyPerTurn .. " " .. Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY_PER_TURN");
    Controls.ThemPocketEnergyPerTurn:SetText( strEnergyString );
    
    bGPTAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_ENERGY_PER_TURN, 1, g_iDealDuration);	-- 1 here is 1 GPT, which is the minimum possible
    
    if (not bGPTAllowed) then
	    Controls.ThemPocketEnergyPerTurn:SetDisabled(true);
	    Controls.ThemPocketEnergyPerTurn:GetTextControl():SetColorByName("Gray_Black");
		-- Can't trade because no energy or no coop agreement
		if (iEnergyPerTurn <= 0) then
			Controls.ThemPocketEnergyPerTurn:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_POPUP_NOT_ENOUGH_ENERGY"));
		else
			Controls.ThemPocketEnergyPerTurn:SetToolTipString(nil);
		end
	else
	    Controls.ThemPocketEnergyPerTurn:SetDisabled(false);
	    Controls.ThemPocketEnergyPerTurn:GetTextControl():SetColorByName("Beige_Black");
		Controls.ThemPocketEnergyPerTurn:SetToolTipString(nil);
    end
    
     ---------------------------------------------------------------------------------- 
    -- pocket Research Per Turn  
    ---------------------------------------------------------------------------------- 

	-- Us
	local iResearchPerTurn = g_pUs:GetScience();
    strBeakerString = iResearchPerTurn .. " " .. Locale.ConvertTextKey("TXT_KEY_DIPLO_RESEARCH_PER_TURN" );
    Controls.UsPocketResearchPerTurn:SetText( strBeakerString );	

    local bBPTAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_RESEARCH_PER_TURN, 1, g_iDealDuration);	-- 1 here is 1 BPT, which is the minimum possible    

    if (not bBPTAllowed) then
	    Controls.UsPocketResearchPerTurn:SetDisabled(true);
	    Controls.UsPocketResearchPerTurn:GetTextControl():SetColorByName("Gray_Black");
		if (g_Deal:GetDemandingPlayer() == -1) then
			Controls.UsPocketResearchPerTurn:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_DIPLO_NEED_DOF_TT_ONE_LINE"));
		else
			Controls.UsPocketResearchPerTurn:SetToolTipString(nil);
		end
	else
	    Controls.UsPocketResearchPerTurn:SetDisabled(false);
	    Controls.UsPocketResearchPerTurn:GetTextControl():SetColorByName("Beige_Black");
		Controls.UsPocketResearchPerTurn:SetToolTipString(nil);
    end
    
    -- Them
	iResearchPerTurn = g_pThem:GetScience();
    strBeakerString = iResearchPerTurn .. " " .. Locale.ConvertTextKey("TXT_KEY_DIPLO_RESEARCH_PER_TURN");
    Controls.ThemPocketResearchPerTurn:SetText( strBeakerString );
    
    bBPTAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_RESEARCH_PER_TURN, 1, g_iDealDuration);	-- 1 here is 1 GPT, which is the minimum possible
    
    if (not bBPTAllowed) then
	    Controls.ThemPocketResearchPerTurn:SetDisabled(true);
	    Controls.ThemPocketResearchPerTurn:GetTextControl():SetColorByName("Gray_Black");
		if (g_Deal:GetDemandingPlayer() == -1) then
			Controls.ThemPocketResearchPerTurn:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_DIPLO_NEED_DOF_TT_ONE_LINE"));
		else
			Controls.ThemPocketResearchPerTurn:SetToolTipString(nil);
		end
	else
	    Controls.ThemPocketResearchPerTurn:SetDisabled(false);
	    Controls.ThemPocketResearchPerTurn:GetTextControl():SetColorByName("Beige_Black");
		Controls.ThemPocketResearchPerTurn:SetToolTipString(nil);
    end

	---------------------------------------------------------------------------------- 
    -- pocket Favors
    ---------------------------------------------------------------------------------- 
    
    local iItemToBeChanged = -1;	-- This is -1 because we're not changing anything right now
    local strFavorString = Locale.ConvertTextKey("TXT_KEY_DIPLO_CURRENT_FAVORS_US", g_pUs:GetNumFavors(g_iThem), g_pThemLeader.Description);

    -- Us    
    Controls.UsPocketFavors:SetText( Locale.ConvertTextKey("TXT_KEY_DIPLO_SPEND_FAVORS") );
	Controls.UsPocketFavors:ReprocessAnchoring(); --??TRON
    
    local bFavorTradeAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_FAVOR, 1);	-- 1 here is 1 Favor, which is the minimum possible    

    if (not bFavorTradeAllowed) then
		-- if Favors are not allowed because its a human-human trade, don't show them at all
		if (bHumanToHumanTrade == true) then
			Controls.UsPocketFavors:SetHide(true);
		else
			Controls.UsPocketFavors:SetHide(false);
			Controls.UsPocketFavors:SetDisabled(true);
			Controls.UsPocketFavors:GetTextControl():SetColorByName("Gray_Black");
			strTooltip = "[COLOR_WARNING_TEXT]" .. strFavorString .. "[ENDCOLOR]";
			Controls.UsPocketFavors:SetToolTipString(strTooltip);
		end	    
	else
		Controls.UsPocketFavors:SetHide(false);
	    Controls.UsPocketFavors:SetDisabled(false);
	    Controls.UsPocketFavors:GetTextControl():SetColorByName("Beige_Black");
	    Controls.UsPocketFavors:SetToolTipString(strFavorString);	    
    end

	-- Them
    Controls.ThemPocketFavors:SetText( Locale.ConvertTextKey("TXT_KEY_DIPLO_GAIN_FAVORS") );
    
    bFavorTradeAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_FAVOR, 1);	-- 1 here is 1 Favor, which is the minimum possible
    
    if (not bFavorTradeAllowed) then
		-- if Favors are not allowed because its a human-human trade, don't show them at all
		if (bHumanToHumanTrade == true) then
			Controls.ThemPocketFavors:SetHide(true);
		else
			Controls.ThemPocketFavors:SetHide(false);
			Controls.ThemPocketFavors:SetDisabled(true);
			Controls.ThemPocketFavors:GetTextControl():SetColorByName("Gray_Black");
			strTooltip = "[COLOR_WARNING_TEXT]" .. strFavorString .. "[ENDCOLOR]";
			Controls.ThemPocketFavors:SetToolTipString(strTooltip);
		end
	else
		Controls.ThemPocketFavors:SetHide(false);
	    Controls.ThemPocketFavors:SetDisabled(false);
	    Controls.ThemPocketFavors:GetTextControl():SetColorByName("Beige_Black");
	    Controls.ThemPocketFavors:SetToolTipString(strFavorString);	    
    end
	
   ---------------------------------------------------------------------------------- 
    -- pocket Open Borders
    ---------------------------------------------------------------------------------- 
    
    local bOpenBordersAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_OPEN_BORDERS, g_iDealDuration);
    
    -- Are we not allowed to give Open Borders?
    strTooltip = Locale.ConvertTextKey("TXT_KEY_DIPLO_OPEN_BORDERS_TT", g_iDealDuration );
    
    local strOurTooltip = strTooltip;
    local strTheirTooltip = strTooltip;
    
    -- Are we not allowed to give OB? (don't have tech, or are already providing it to them)
    if (not bOpenBordersAllowed) then
		Controls.UsPocketOpenBorders:SetDisabled(true);
		Controls.UsPocketOpenBorders:GetTextControl():SetColorByName("Gray_Black");

		if (g_pUsTeam:IsAllowsOpenBordersToTeam(g_iThemTeam)) then
			strOurTooltip = strOurTooltip .. " " .. Locale.ConvertTextKey( "TXT_KEY_DIPLO_OPEN_BORDERS_HAVE" );
		end
		
	else
		Controls.UsPocketOpenBorders:SetDisabled(false);
		Controls.UsPocketOpenBorders:GetTextControl():SetColorByName("Beige_Black");
    end
    
	Controls.UsPocketOpenBorders:SetToolTipString(strOurTooltip);

    bOpenBordersAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_OPEN_BORDERS, g_iDealDuration);
    
    -- Are they not allowed to give OB? (don't have tech, or are already providing it to us)
    if (not bOpenBordersAllowed) then
		Controls.ThemPocketOpenBorders:SetDisabled(true);
		Controls.ThemPocketOpenBorders:GetTextControl():SetColorByName("Gray_Black");

		if (g_pUsTeam:IsAllowsOpenBordersToTeam(g_iThemTeam)) then
			strTheirTooltip = strTheirTooltip .. " " .. Locale.ConvertTextKey( "TXT_KEY_DIPLO_OPEN_BORDERS_THEY_HAVE" );
		end
	else
		Controls.ThemPocketOpenBorders:SetDisabled(false);
		Controls.ThemPocketOpenBorders:GetTextControl():SetColorByName("Beige_Black");
    end

	Controls.ThemPocketOpenBorders:SetToolTipString(strTheirTooltip);
        
    ---------------------------------------------------------------------------------- 
    -- pocket Alliance
    ---------------------------------------------------------------------------------- 
    
    local bAllianceAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_ALLIANCE, g_iDealDuration);
    
    -- Are we not allowed to give alliance? (already providing it to them)
    strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ALLIANCE_TT", g_iDealDuration );
    if (not bAllianceAllowed) then
		
		local strDisabledTT = "";

		if (g_pUsTeam:IsAlliance(g_iThemTeam)) then
			strDisabledTT = " " .. Locale.ConvertTextKey( "TXT_KEY_DIPLO_ALLIANCE_EXISTS" );
		else
			strDisabledTT = " " .. Locale.ConvertTextKey( "TXT_KEY_DIPLO_ALLIANCE_NO_AGREEMENT" );
		end
		
		strDisabledTT = "[COLOR_WARNING_TEXT]" .. strDisabledTT .. "[ENDCOLOR]";
		strTooltip = strTooltip .. strDisabledTT;
	end
	
	Controls.UsPocketAlliance:SetToolTipString(strTooltip);
	Controls.ThemPocketAlliance:SetToolTipString(strTooltip);
    
    -- Are we not allowed to give alliance? (already providing it to them)
    if (not bAllianceAllowed) then
		Controls.UsPocketAlliance:SetDisabled(true);
		Controls.UsPocketAlliance:GetTextControl():SetColorByName("Gray_Black");
	else
		Controls.UsPocketAlliance:SetDisabled(false);
		Controls.UsPocketAlliance:GetTextControl():SetColorByName("Beige_Black");
    end

    bAllianceAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_ALLIANCE, g_iDealDuration);
    
    -- Are they not allowed to give alliance? (already providing it to us)
    if (not bAllianceAllowed) then
		Controls.ThemPocketAlliance:SetDisabled(true);
		Controls.ThemPocketAlliance:GetTextControl():SetColorByName("Gray_Black");
	else
		Controls.ThemPocketAlliance:SetDisabled(false);
		Controls.ThemPocketAlliance:GetTextControl():SetColorByName("Beige_Black");
    end
        
    ---------------------------------------------------------------------------------- 
    -- pocket Trade Agreement
    ---------------------------------------------------------------------------------- 
    
    local bTradeAgreementAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_TRADE_AGREEMENT, g_iDealDuration);
    
    -- Are we not allowed to give TA? (don't have tech, or are already providing it to them)
    strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_TRADE_AGREEMENT_TT" );
    if (not bTradeAgreementAllowed) then
		
		local strDisabledTT = "";
		
		if (g_pUsTeam:IsHasTradeAgreement(g_iThemTeam)) then
			strDisabledTT = " " .. Locale.ConvertTextKey( "TXT_KEY_DIPLO_TRADE_AGREEMENT_EXISTS" );
		else
			strDisabledTT = " " .. Locale.ConvertTextKey( "TXT_KEY_DIPLO_TRADE_AGREEMENT_NO_AGREEMENT" );
		end
		
		strDisabledTT = "[COLOR_WARNING_TEXT]" .. strDisabledTT .. "[ENDCOLOR]";
		strTooltip = strTooltip .. strDisabledTT;
	end

	Controls.UsPocketTradeAgreement:SetToolTipString(strTooltip);
	Controls.ThemPocketTradeAgreement:SetToolTipString(strTooltip);
    
    -- Are we not allowed to give RA? (don't have tech, or are already providing it to them)
    if (not bTradeAgreementAllowed) then
		Controls.UsPocketTradeAgreement:SetDisabled(true);
		Controls.UsPocketTradeAgreement:GetTextControl():SetColorByName("Gray_Black");
	else
		Controls.UsPocketTradeAgreement:SetDisabled(false);
		Controls.UsPocketTradeAgreement:GetTextControl():SetColorByName("Beige_Black");
    end

    bTradeAgreementAllowed = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_TRADE_AGREEMENT, g_iDealDuration);
    
    -- Are they not allowed to give RA? (don't have tech, or are already providing it to us)
    if (not bTradeAgreementAllowed) then
		Controls.ThemPocketTradeAgreement:SetDisabled(true);
		Controls.ThemPocketTradeAgreement:GetTextControl():SetColorByName("Gray_Black");
	else
		Controls.ThemPocketTradeAgreement:SetDisabled(false);
		Controls.ThemPocketTradeAgreement:GetTextControl():SetColorByName("Beige_Black");
    end

    ---------------------------------------------------------------------------------- 
    -- Pocket Cooperation Agreement
    ---------------------------------------------------------------------------------- 

	if ( Controls.UsPocketCoopAgreement ~= nil and Controls.ThemPocketCoopAgreement ~= nil) then
		if (g_bPVPTrade) then	-- Only PvP trade, with the AI there is a dedicated interface for this trade.
		
			strTooltip = Locale.ConvertTextKey("TXT_KEY_DIPLO_DISCUSS_MESSAGE_COOP_AGREEMENT_TT");
		
			local bDoFAllowed = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_COOPERATION_AGREEMENT, g_iDealDuration);
		    
			Controls.UsPocketCoopAgreement:SetHide(false);
			Controls.ThemPocketCoopAgreement:SetHide(false);
			
			if (not bDoFAllowed) then
				Controls.UsPocketCoopAgreement:SetDisabled(true);
				Controls.UsPocketCoopAgreement:GetTextControl():SetColorByName("Gray_Black");
				Controls.ThemPocketCoopAgreement:SetDisabled(true);
				Controls.ThemPocketCoopAgreement:GetTextControl():SetColorByName("Gray_Black");
				
				if ( g_pUsTeam:IsAtWar( g_iThemTeam ) ) then
					strTooltip = strTooltip .. "[NEWLINE][NEWLINE] [COLOR_WARNING_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_DIPLO_COOPERATION_AGREEMENT_AT_WAR" ) .. "[ENDCOLOR]";
				else
					strTooltip = strTooltip .. "[NEWLINE][NEWLINE] [COLOR_WARNING_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_DIPLO_COOPERATION_AGREEMENT_ALREADY_EXISTS" ) .. "[ENDCOLOR]";
				end				
			else
				Controls.UsPocketCoopAgreement:SetDisabled(false);
				Controls.UsPocketCoopAgreement:GetTextControl():SetColorByName("Beige_Black");
				Controls.ThemPocketCoopAgreement:SetDisabled(false);
				Controls.ThemPocketCoopAgreement:GetTextControl():SetColorByName("Beige_Black");
			end
			
		    Controls.UsPocketCoopAgreement:SetToolTipString(strTooltip);
		    Controls.ThemPocketCoopAgreement:SetToolTipString(strTooltip);
			
		else
			Controls.UsPocketCoopAgreement:SetHide(true);
			Controls.ThemPocketCoopAgreement:SetHide(true);
		end
	end
	
    ---------------------------------------------------------------------------------- 
    -- Pocket Cities
    ---------------------------------------------------------------------------------- 
    local bFound = false;
    for pCity in g_pUs:Cities() do
        if( g_Deal:IsPossibleToTradeItem( g_iUs, g_iThem, TradeableItems.TRADE_ITEM_CITIES, pCity:GetX(), pCity:GetY() ) ) then
            bFound = true;
            break;
        end
    end
    if( bFound ) then
        Controls.UsPocketCities:SetDisabled( false );
        Controls.UsPocketCities:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_TO_TRADE_CITY_TT" ));
		Controls.UsPocketCities:GetTextControl():SetColorByName("Beige_Black");
    else
        Controls.UsPocketCities:SetDisabled( true );
        Controls.UsPocketCities:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_TO_TRADE_CITY_NO_TT" ));
		Controls.UsPocketCities:GetTextControl():SetColorByName("Gray_Black");
    end
    
    
    bFound = false;
    for pCity in g_pThem:Cities() do
        if( g_Deal:IsPossibleToTradeItem( g_iThem, g_iUs, TradeableItems.TRADE_ITEM_CITIES, pCity:GetX(), pCity:GetY() ) ) then
            bFound = true;
            break;
        end
    end
    if( bFound ) then
        Controls.ThemPocketCities:SetDisabled( false );
        Controls.ThemPocketCities:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_TO_TRADE_CITY_TT" ));
		Controls.ThemPocketCities:GetTextControl():SetColorByName("Beige_Black");
    else
        Controls.ThemPocketCities:SetDisabled( true );
        Controls.ThemPocketCities:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_TO_TRADE_CITY_NO_THEM" ));
		Controls.ThemPocketCities:GetTextControl():SetColorByName("Gray_Black");
    end
      

    ---------------------------------------------------------------------------------- 
    -- enable/disable pocket other civs
    ---------------------------------------------------------------------------------- 
    if( g_iNumOthers == 0 ) then
    
		Controls.UsPocketOtherPlayer:SetDisabled( true );
		Controls.UsPocketOtherPlayer:GetTextControl():SetColorByName( "Gray_Black" );
		Controls.UsPocketOtherPlayer:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_OTHER_PLAYERS_NO_PLAYERS") );
		Controls.UsPocketOtherPlayer:SetText( Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_OTHER_PLAYERS" ) );
		
		Controls.ThemPocketOtherPlayer:SetDisabled( true );
		Controls.ThemPocketOtherPlayer:GetTextControl():SetColorByName( "Gray_Black" );
		Controls.ThemPocketOtherPlayer:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_OTHER_PLAYERS_NO_PLAYERS_THEM" ));
		Controls.ThemPocketOtherPlayer:SetText( Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_OTHER_PLAYERS" ) );
		
	else
		Controls.UsPocketOtherPlayer:SetDisabled( false );
		Controls.UsPocketOtherPlayer:GetTextControl():SetColorByName( "Beige_Black" );
		Controls.UsPocketOtherPlayer:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_OTHER_PLAYERS_OPEN" ) );
		Controls.UsPocketOtherPlayer:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_OTHER_PLAYERS" ) );
		
		Controls.ThemPocketOtherPlayer:SetDisabled( false );
		Controls.ThemPocketOtherPlayer:GetTextControl():SetColorByName( "Beige_Black" );
		Controls.ThemPocketOtherPlayer:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_OTHER_PLAYERS_OPEN" ));
		Controls.ThemPocketOtherPlayer:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_OTHER_PLAYERS" ) );
    end
    	    
    
		
    ---------------------------------------------------------------------------------- 
    -- pocket resources for us
    ---------------------------------------------------------------------------------- 
    local bFoundLux = false;
    local bFoundStrat = false;
    local count;
    
    local iResourceCount;
    --local iOurResourceCount;
    --local iTheirResourceCount;
    local pResource;
    local strString;
    
    -- loop over resources
    if( g_iUs == -1 ) then
        for resType, instance in pairs( g_UsPocketResources ) do
            instance.Button:SetHide( false );
        end
        bFoundLux = true;
        bFoundStrat = true;
    else
		
		local bCanTradeResource;
		
        for resType, instance in pairs( g_UsPocketResources ) do
			
			bCanTradeResource = g_Deal:IsPossibleToTradeItem(g_iUs, g_iThem, TradeableItems.TRADE_ITEM_RESOURCES, resType, 1);	-- 1 here is 1 quanity of the Resource, which is the minimum possible
			
            if (bCanTradeResource) then
                if( g_LuxuryList[ resType ] == true ) then
                    bFoundLux = true;
                else
                    bFoundStrat = true;
                end
                instance.Button:SetHide( false );
                
                pResource = GameInfo.Resources[resType];
				iResourceCount = g_Deal:GetNumResource(g_iUs, resType);
			    strString = pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description) .. " (" .. iResourceCount .. ")";
                instance.Button:SetText( strString );
            else
                instance.Button:SetHide( true );
            end
        end
    end
    
    Controls.UsPocketStrategic:SetDisabled( not bFoundStrat );
    if (bFoundStrat) then
		Controls.UsPocketStrategic:GetTextControl():SetColorByName("Beige_Black");
		Controls.UsPocketStrategic:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_STRAT_RESCR_TRADE_YES") );
		if( Controls.UsPocketStrategicStack:IsHidden() ) then
    		Controls.UsPocketStrategic:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_STRATEGIC_RESOURCES" ) );
		else
    		Controls.UsPocketStrategic:SetText( "[ICON_MINUS]" .. Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_STRATEGIC_RESOURCES" ) );
		end
	else
		Controls.UsPocketStrategic:GetTextControl():SetColorByName("Gray_Black");
		Controls.UsPocketStrategic:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_STRAT_RESCR_TRADE_NO") );
		Controls.UsPocketStrategic:SetText( Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_STRATEGIC_RESOURCES" ) );
    end
   
   
    ---------------------------------------------------------------------------------- 
    -- pocket resources for them
    ---------------------------------------------------------------------------------- 
    bFoundLux = false;
    bFoundStrat = false;
    if( g_iThem == -1 ) then
        for resType, instance in pairs( g_ThemPocketResources ) do
            instance.Button:SetHide( false );
        end
        bFoundLux = true;
        bFoundStrat = true;
    else
		
		local bCanTradeResource;
		
        for resType, instance in pairs( g_ThemPocketResources ) do
			
			bCanTradeResource = g_Deal:IsPossibleToTradeItem(g_iThem, g_iUs, TradeableItems.TRADE_ITEM_RESOURCES, resType, 1);	-- 1 here is 1 quanity of the Resource, which is the minimum possible
			
            if (bCanTradeResource) then
                if( g_LuxuryList[ resType ] == true ) then
                    bFoundLux = true;
                else
                    bFoundStrat = true;
                end
                instance.Button:SetHide( false );
                
                pResource = GameInfo.Resources[resType];
                iResourceCount = g_Deal:GetNumResource(g_iThem, resType);
			    strString = pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description) .. " (" .. iResourceCount .. ")";
                instance.Button:SetText( strString );
            else
                instance.Button:SetHide( true );
            end
        end
    end
    
    Controls.ThemPocketStrategic:SetDisabled( not bFoundStrat );
    if (bFoundStrat) then
		Controls.ThemPocketStrategic:GetTextControl():SetColorByName("Beige_Black");
		Controls.ThemPocketStrategic:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_STRAT_RESCR_TRADE_YES_THEM" ));
		if( Controls.ThemPocketStrategicStack:IsHidden() ) then
    		Controls.ThemPocketStrategic:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_STRATEGIC_RESOURCES" ) );
		else
    		Controls.ThemPocketStrategic:SetText( "[ICON_MINUS]" .. Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_STRATEGIC_RESOURCES" ) );
		end
	else
		Controls.ThemPocketStrategic:GetTextControl():SetColorByName("Gray_Black");
		Controls.ThemPocketStrategic:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_DIPLO_STRAT_RESCR_TRADE_NO_THEM" ));
		Controls.ThemPocketStrategic:SetText( Locale.ConvertTextKey( "TXT_KEY_TRADE_ITEM_STRATEGIC_RESOURCES" ) );
    end
   
   
	-- Hide things inappropriate for teammates
	if (g_iUsTeam == g_iThemTeam) then
		--print("Teams match!");
		Controls.UsPocketOpenBorders:SetHide(true);
		Controls.UsPocketAlliance:SetHide(true);
		Controls.UsPocketOtherPlayer:SetHide(true);
		Controls.ThemPocketOpenBorders:SetHide(true);
		Controls.ThemPocketAlliance:SetHide(true);
		Controls.ThemPocketOtherPlayer:SetHide(true);
	else
		--print("Teams DO NOT match!");
		Controls.UsPocketOpenBorders:SetHide(false);
		Controls.UsPocketAlliance:SetHide(false);
		Controls.UsPocketOtherPlayer:SetHide(false);
		Controls.ThemPocketOpenBorders:SetHide(false);
		Controls.ThemPocketAlliance:SetHide(false);
		Controls.ThemPocketOtherPlayer:SetHide(false);
	end

    
    ResizeStacks();
end


----------------------------------------------------------------        
----------------------------------------------------------------        
function DoClearTable()
    g_UsTableCitiesIM:ResetInstances();
    g_ThemTableCitiesIM:ResetInstances();
    
	Controls.UsTablePeaceTreaty:SetHide( true );
	Controls.ThemTablePeaceTreaty:SetHide( true );
	Controls.UsTableFavors:SetHide( true );
	Controls.ThemTableFavors:SetHide( true );
	Controls.UsTableGold:SetHide( true );
	Controls.ThemTableGold:SetHide( true );
	Controls.UsTableGoldPerTurn:SetHide( true );
	Controls.ThemTableGoldPerTurn:SetHide( true );
	Controls.UsTableResearchPerTurn:SetHide( true );
	Controls.ThemTableResearchPerTurn:SetHide( true );
	Controls.UsTableOpenBorders:SetHide( true );
	Controls.ThemTableOpenBorders:SetHide( true );
	Controls.UsTableAlliance:SetHide( true );
	Controls.ThemTableAlliance:SetHide( true );
	Controls.UsTableTradeAgreement:SetHide( true );
	Controls.ThemTableTradeAgreement:SetHide( true );
    Controls.UsTableCitiesStack:SetHide( true );
    Controls.ThemTableCitiesStack:SetHide( true );
	Controls.UsTableStrategicStack:SetHide( true );
	Controls.ThemTableStrategicStack:SetHide( true );
	
	Controls.UsTableMakePeaceStack:SetHide( true );
	Controls.ThemTableMakePeaceStack:SetHide( true );
	Controls.UsTableDeclareWarStack:SetHide( true );
	Controls.ThemTableDeclareWarStack:SetHide( true );
	
	for n, table in pairs( g_OtherPlayersButtons ) do
	    table.UsTableWar.Button:SetHide( true );
	    table.UsTablePeace.Button:SetHide( true );
	    table.ThemTableWar.Button:SetHide( true );
	    table.ThemTablePeace.Button:SetHide( true );
    end
	
	-- loop over resources
	for n, instance in pairs( g_UsTableResources ) do
		instance.Container:SetHide( true );
	end
	for n, instance in pairs( g_ThemTableResources ) do
		instance.Container:SetHide( true );
	end
	
    if (Controls.UsTableCoopAgreement ~= nil) then
		Controls.UsTableCoopAgreement:SetHide(true);
		Controls.UsTableCoopAgreement:RegisterCallback( Mouse.eLClick, TableDoFHandler );
		Controls.UsTableCoopAgreement:SetVoid1( 1 );
	end
	if (Controls.ThemTableCoopAgreement ~= nil) then
		Controls.ThemTableCoopAgreement:SetHide(true);
		Controls.ThemTableCoopAgreement:RegisterCallback( Mouse.eLClick, TableDoFHandler );
		Controls.ThemTableCoopAgreement:SetVoid1( 0 );
	end
    
    ResizeStacks();
    
end	


----------------------------------------------------------------        
----------------------------------------------------------------        
function ResizeStacks()
    Controls.UsPocketStrategicStack:CalculateSize();
    Controls.ThemPocketStrategicStack:CalculateSize();
    Controls.UsTableStrategicStack:CalculateSize();
    Controls.ThemTableStrategicStack:CalculateSize();

	Controls.UsTableCitiesStack:CalculateSize();
	Controls.ThemTableCitiesStack:CalculateSize();
    Controls.UsPocketLeaderStack:CalculateSize();
    Controls.ThemPocketLeaderStack:CalculateSize();
    
    Controls.UsTableMakePeaceStack:CalculateSize();
    Controls.UsTableDeclareWarStack:CalculateSize();
    Controls.ThemTableMakePeaceStack:CalculateSize();
    Controls.ThemTableDeclareWarStack:CalculateSize();
    
    
    Controls.UsPocketStack:CalculateSize();
    Controls.ThemPocketStack:CalculateSize();
    Controls.UsTableStack:CalculateSize();
    Controls.ThemTableStack:CalculateSize();

    Controls.UsPocketPanel:CalculateInternalSize();
    Controls.UsPocketPanel:ReprocessAnchoring();
    Controls.ThemPocketPanel:CalculateInternalSize();
    Controls.ThemPocketPanel:ReprocessAnchoring();
    Controls.UsTablePanel:CalculateInternalSize();
    Controls.UsTablePanel:ReprocessAnchoring();
    Controls.ThemTablePanel:CalculateInternalSize();
    Controls.ThemTablePanel:ReprocessAnchoring();
    
end


----------------------------------------------------------------        
----------------------------------------------------------------        
function DisplayDeal()
    g_UsTableCitiesIM:ResetInstances();
    g_ThemTableCitiesIM:ResetInstances();
	
	if g_iUs == -1 or g_iThem == -1 then
		return;
	end
	
	--print("Displaying Deal");
	
    local itemType;
	local duration;
	local finalTurn;
	local data1;
	local data2;
	local data3;
	local flag1;
	local fromPlayer;
    
    local strString;
    local strTooltip;
	
	ResetDisplay();
	
	local iNumItemsFromUs = 0;
	local iNumItemsFromThem = 0;
    
    g_Deal:ResetIterator();
    itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayer = g_Deal:GetNextItem();
    
    local iItemToBeChanged = -1;	-- This is -1 because we're not changing anything right now
   
	--print("Going through check"); 
    if( itemType ~= nil ) then
    repeat
        local bFromUs = false;
        
		--print("Adding trade item to active deal: " .. itemType);
        
        if( fromPlayer == Game.GetActivePlayer() ) then
            bFromUs = true;
            iNumItemsFromUs = iNumItemsFromUs + 1;
        else
            iNumItemsFromThem = iNumItemsFromThem + 1;
        end
        
        if( TradeableItems.TRADE_ITEM_PEACE_TREATY == itemType ) then
			local str = Locale.ConvertTextKey("TXT_KEY_DIPLO_PEACE_TREATY", g_iPeaceDuration);
            if( bFromUs ) then
				Controls.UsTablePeaceTreaty:SetText(str);
                Controls.UsTablePeaceTreaty:SetHide( false );
	            Controls.UsTablePeaceTreaty:SetDisabled( g_OfferIsFixed );
            else
				Controls.ThemTablePeaceTreaty:SetText(str);
                Controls.ThemTablePeaceTreaty:SetHide( false );
	            Controls.ThemTablePeaceTreaty:SetDisabled( g_OfferIsFixed );
            end

		elseif( TradeableItems.TRADE_ITEM_FAVOR == itemType ) then
        
            Controls.UsPocketFavors:SetHide( true );
            Controls.ThemPocketFavors:SetHide( true );
            
            Controls.UsTableFavors:SetHide( not bFromUs );
            Controls.ThemTableFavors:SetHide( bFromUs );

            Controls.UsTableFavors:SetDisabled( g_OfferIsFixed );
            Controls.ThemTableFavors:SetDisabled( g_OfferIsFixed );			
            
            -- update quantity
            if( bFromUs ) then
                Controls.UsFavorsAmount:SetText( data1 );
	            Controls.UsFavorsAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey("TXT_KEY_DIPLO_SPEND_FAVORS");
				Controls.UsTableFavors:SetText( strString );
				--strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_FAVORS_THEM", g_pThemLeader.Description, g_pThem:GetNumFavors(g_iUs) );
				strTooltip = Locale.ConvertTextKey("TXT_KEY_DIPLO_CURRENT_FAVORS_US", g_pUs:GetNumFavors(g_iThem), g_pThemLeader.Description);
				Controls.UsTableFavors:SetToolTipString( strTooltip );
            else
                Controls.ThemFavorsAmount:SetText( data1 );
	            Controls.ThemFavorsAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey("TXT_KEY_DIPLO_GAIN_FAVORS");
				Controls.ThemTableFavors:SetText( strString );
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_FAVORS_US", g_pUs:GetNumFavors(g_iThem), g_pThemLeader.Description );
				Controls.ThemTableFavors:SetToolTipString( strTooltip )
            end

        elseif( TradeableItems.TRADE_ITEM_ENERGY == itemType ) then
        
            Controls.UsPocketEnergy:SetHide( true );
            Controls.ThemPocketEnergy:SetHide( true );
            
            Controls.UsTableGold:SetHide( not bFromUs );
            Controls.ThemTableGold:SetHide( bFromUs );
            
            Controls.UsTableGold:SetDisabled( g_OfferIsFixed );
            Controls.ThemTableGold:SetDisabled( g_OfferIsFixed );

            -- update quantity
            if( bFromUs ) then
                Controls.UsGoldAmount:SetText( data1 );
	            Controls.UsGoldAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY");
				Controls.UsTableGold:SetText( strString );
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GOLD", g_Deal:GetGoldAvailable(g_iUs, iItemToBeChanged) );
				Controls.UsTableGold:SetToolTipString( strTooltip )
            else
                Controls.ThemGoldAmount:SetText( data1 );
	            Controls.ThemGoldAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey("TXT_KEY_DIPLO_ENERGY");
				Controls.ThemTableGold:SetText( strString );
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GOLD", g_Deal:GetGoldAvailable(g_iThem, iItemToBeChanged) );
				Controls.ThemTableGold:SetToolTipString( strTooltip );
            end						
         
        elseif( TradeableItems.TRADE_ITEM_ENERGY_PER_TURN == itemType ) then
        
            Controls.UsPocketEnergyPerTurn:SetHide( true );
            Controls.ThemPocketEnergyPerTurn:SetHide( true );
            
            Controls.UsPocketEnergyPerTurn:SetDisabled( g_OfferIsFixed );
            Controls.ThemPocketEnergyPerTurn:SetDisabled( g_OfferIsFixed );			

            if( bFromUs ) then
                Controls.UsTableGoldPerTurn:SetHide( false );
                Controls.UsGoldPerTurnTurns:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
                Controls.UsGoldPerTurnAmount:SetText( data1 );
	            Controls.UsGoldPerTurnAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ENERGY_PER_TURN" );
				Controls.UsTableGoldPerTurnButton:SetText( strString );
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GPT", g_pUs:CalculateGoldRate() - data1 );
				Controls.UsTableGoldPerTurn:SetToolTipString( strTooltip );
           else
                Controls.ThemTableGoldPerTurn:SetHide( false );
                Controls.ThemGoldPerTurnTurns:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
                Controls.ThemGoldPerTurnAmount:SetText( data1 );
	            Controls.ThemGoldPerTurnAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_ENERGY_PER_TURN" );
				Controls.ThemTableGoldPerTurnButton:SetText( strString );
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GPT", g_pThem:CalculateGoldRate() - data1 );
				Controls.ThemTableGoldPerTurn:SetToolTipString( strTooltip );
            end			
        
         elseif( TradeableItems.TRADE_ITEM_RESEARCH_PER_TURN == itemType ) then
        
            Controls.UsPocketResearchPerTurn:SetHide( true );
            Controls.ThemPocketResearchPerTurn:SetHide( true );
            
            Controls.UsPocketResearchPerTurn:SetDisabled( g_OfferIsFixed );
            Controls.ThemPocketResearchPerTurn:SetDisabled( g_OfferIsFixed );			

            if( bFromUs ) then
                Controls.UsTableResearchPerTurn:SetHide( false );
                Controls.UsResearchPerTurnTurns:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
                Controls.UsResearchPerTurnAmount:SetText( data1 );
	            Controls.UsResearchPerTurnAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_RESEARCH_PER_TURN" );
				Controls.UsTableResearchPerTurnButton:SetText( strString );
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_BPT_US", g_pUs:GetScience() - data1 );
				Controls.UsTableResearchPerTurn:SetToolTipString( strTooltip );
           else
                Controls.ThemTableResearchPerTurn:SetHide( false );
                Controls.ThemResearchPerTurnTurns:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
                Controls.ThemResearchPerTurnAmount:SetText( data1 );
	            Controls.ThemResearchPerTurnAmount:SetDisabled( g_OfferIsFixed );
                
				strString = Locale.ConvertTextKey( "TXT_KEY_DIPLO_RESEARCH_PER_TURN" );
				Controls.ThemTableResearchPerTurnButton:SetText( strString );
				local iMaxBPT = (g_pThem:GetScience() * GameDefines["MAX_PERCENT_RESEARCH_TRADED"]) / 100;
				strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_BPT_THEM", g_pThem:GetScience() - data1, iMaxBPT );
				Controls.ThemTableResearchPerTurn:SetToolTipString( strTooltip );
            end			
			
         elseif( TradeableItems.TRADE_ITEM_CITIES == itemType ) then
        
            local pCity = nil;
            local instance = nil;
            local pPlot = Map.GetPlot( data1, data2 );
            if( pPlot ~= nil ) then
                pCity = pPlot:GetPlotCity();
            end
            
            if( pCity ~= nil ) then
            
                if( bFromUs ) then
            
                    instance = g_UsTableCitiesIM:GetInstance();
                    instance.Button:SetVoids( g_iUs, pCity:GetID() );
                    instance.Button:RegisterCallback( Mouse.eLClick, TableCityHandler );
		            instance.Button:SetDisabled( g_OfferIsFixed );			
                    Controls.UsTableCitiesStack:SetHide( false );
		            Controls.UsTableCitiesStack:SetDisabled( g_OfferIsFixed );			
                else
                    instance = g_ThemTableCitiesIM:GetInstance();
                    instance.Button:SetVoids( g_iThem, pCity:GetID() );
                    instance.Button:RegisterCallback( Mouse.eLClick, TableCityHandler );
		            instance.Button:SetDisabled( g_OfferIsFixed );			
                    Controls.ThemTableCitiesStack:SetHide( false );
                end
            
                instance.CityName:SetText( pCity:GetName() );
                instance.CityPop:SetText( pCity:GetPopulation() );
            else
                if( bFromUs ) then
                    instance = g_UsTableCitiesIM:GetInstance();
                    Controls.UsTableCitiesStack:SetHide( false );
                else
                    instance = g_ThemTableCitiesIM:GetInstance();
                    Controls.ThemTableCitiesStack:SetHide( false );
                end
                instance.CityName:LocalizeAndSetText( "TXT_KEY_RAZED_CITY" );
                instance.CityPop:SetText( "" );
            end
        
        elseif( TradeableItems.TRADE_ITEM_THIRD_PARTY_PEACE == itemType ) then
            DisplayOtherPlayerItem( bFromUs, itemType, duration, data1 );
            
        elseif( TradeableItems.TRADE_ITEM_THIRD_PARTY_WAR == itemType ) then
            DisplayOtherPlayerItem( bFromUs, itemType, duration, data1 );
        
        elseif( TradeableItems.TRADE_ITEM_OPEN_BORDERS == itemType ) then
        
            if( bFromUs ) then
                Controls.UsPocketOpenBorders:SetHide( true );
                Controls.UsTableOpenBorders:SetHide( false );
				Controls.UsTableOpenBordersDuration:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
	            Controls.UsTableOpenBorders:SetDisabled( g_OfferIsFixed );			
            else
                Controls.ThemPocketOpenBorders:SetHide( true );
                Controls.ThemTableOpenBorders:SetHide( false );
				Controls.ThemTableOpenBordersDuration:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
	            Controls.ThemTableOpenBorders:SetDisabled( g_OfferIsFixed );
            end
        
        elseif( TradeableItems.TRADE_ITEM_ALLIANCE == itemType ) then
        
            if( bFromUs ) then
                Controls.UsPocketAlliance:SetHide( true );
                Controls.UsTableAlliance:SetHide( false );
	            Controls.UsTableAlliance:SetDisabled( g_OfferIsFixed );
            else
                Controls.ThemPocketAlliance:SetHide( true );
                Controls.ThemTableAlliance:SetHide( false );
	            Controls.ThemTableAlliance:SetDisabled( g_OfferIsFixed );
            end
        
        elseif( TradeableItems.TRADE_ITEM_TRADE_AGREEMENT == itemType ) then
        
            if( bFromUs ) then
                Controls.UsPocketTradeAgreement:SetHide( true );
                Controls.UsTableTradeAgreement:SetHide( false );
	            Controls.UsTableTradeAgreement:SetDisabled( g_OfferIsFixed );
            else
                Controls.ThemPocketTradeAgreement:SetHide( true );
                Controls.ThemTableTradeAgreement:SetHide( false );
	            Controls.ThemTableTradeAgreement:SetDisabled( g_OfferIsFixed );
            end
        
        elseif( TradeableItems.TRADE_ITEM_RESOURCES == itemType ) then
        
            if( bFromUs ) then
				
                g_UsTableResources[ data1 ].Container:SetHide( false );
				g_UsTableResources[ data1 ].DurationEdit:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
				
                --if( GameInfo.Resources[ data1 ].ResourceUsage == 1 ) then -- is strategic
                    --Controls.UsTableStrategicStack:SetHide( false );
	                --g_UsTableResources[ data1 ].AmountEdit:SetText( data2 );
                --end

				Controls.UsTableStrategicStack:SetHide( false );
	            g_UsTableResources[ data1 ].AmountEdit:SetText( data2 );
	            g_UsTableResources[ data1 ].AmountEdit:SetDisabled( g_OfferIsFixed );
	            g_UsTableResources[ data1 ].Button:SetDisabled( g_OfferIsFixed );
            else
				
                g_ThemTableResources[ data1 ].Container:SetHide( false );
				g_ThemTableResources[ data1 ].DurationEdit:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", duration );
                
                --if( GameInfo.Resources[ data1 ].ResourceUsage == 1 ) then -- is strategic
                    --Controls.ThemTableStrategicStack:SetHide( false );
	                --g_ThemTableResources[ data1 ].AmountEdit:SetText( data2 );
                --end

				Controls.ThemTableStrategicStack:SetHide( false );
				g_ThemTableResources[ data1 ].AmountEdit:SetText( data2 );
	            g_ThemTableResources[ data1 ].AmountEdit:SetDisabled( g_OfferIsFixed );
	            g_ThemTableResources[ data1 ].Button:SetDisabled( g_OfferIsFixed );
            end
            
            g_UsPocketResources[ data1 ].Button:SetHide( true );
            g_ThemPocketResources[ data1 ].Button:SetHide( true );
        elseif( TradeableItems.TRADE_ITEM_COOPERATION_AGREEMENT == itemType ) then
			-- Cooperation Agreement must be mutual
			if (Controls.UsPocketCoopAgreement ~= nil) then 
				Controls.UsPocketCoopAgreement:SetHide( true );
			end
			if (Controls.UsTableCoopAgreement ~= nil) then
				Controls.UsTableCoopAgreement:SetHide( false );
			end
			if (Controls.ThemPocketCoopAgreement ~= nil) then
				Controls.ThemPocketCoopAgreement:SetHide( true );
			end
			if (Controls.ThemTableCoopAgreement ~= nil) then
				Controls.ThemTableCoopAgreement:SetHide( false );
			end
        end
        itemType, duration, finalTurn, data1, data2, data3, flag1, fromPlayer = g_Deal:GetNextItem();
    until( itemType == nil )
    end
	
	DoUpdateButtons();
    
    ResizeStacks();
end


-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
function DisplayOtherPlayerItem( bFromUs, itemType, duration, iOtherTeam )

	--print("iOtherTeam: " .. iOtherTeam);

	local iOtherPlayer = -1;
	for i = 0, GameDefines.MAX_CIV_PLAYERS do
		local player = Players[i];
		local iTeam = player:GetTeam();
		--print("iTeam: " .. iTeam);
		if (player:GetTeam() == iOtherTeam and player:IsAlive()) then
			--print("iOtherPlayer: " .. i);
			iOtherPlayer = i;
			break;
		end
	end
	
	--print("iOtherPlayer: " .. iOtherPlayer);
	
    if( TradeableItems.TRADE_ITEM_THIRD_PARTY_PEACE == itemType ) then
        --print( "Displaying Peace" );
		
        if( bFromUs ) then
            --print( "    from us" );
            g_OtherPlayersButtons[ iOtherPlayer ].UsTablePeace.Button:SetHide( false );
        	Controls.UsTableMakePeaceStack:SetHide( false );
        	Controls.UsTableMakePeaceStack:CalculateSize();
        	Controls.UsTableMakePeaceStack:ReprocessAnchoring();
        else
            --print( "    from them" );
            g_OtherPlayersButtons[ iOtherPlayer ].ThemTablePeace.Button:SetHide( false );
        	Controls.ThemTableMakePeaceStack:SetHide( false );
        	Controls.ThemTableMakePeaceStack:CalculateSize();
        	Controls.ThemTableMakePeaceStack:ReprocessAnchoring();
        end
        
    elseif( TradeableItems.TRADE_ITEM_THIRD_PARTY_WAR == itemType ) then
        --print( "Displaying War" );
    
        if( bFromUs ) then
            --print( "    from us" );
            g_OtherPlayersButtons[ iOtherPlayer ].UsTableWar.Button:SetHide( false );
        	Controls.UsTableDeclareWarStack:SetHide( false );
        	Controls.UsTableDeclareWarStack:CalculateSize();
        	Controls.UsTableDeclareWarStack:ReprocessAnchoring();
        else
            --print( "    from them" );
            g_OtherPlayersButtons[ iOtherPlayer ].ThemTableWar.Button:SetHide( false );
        	Controls.ThemTableDeclareWarStack:SetHide( false );
        	Controls.ThemTableDeclareWarStack:CalculateSize();
        	Controls.ThemTableDeclareWarStack:ReprocessAnchoring();
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Favors Handler
-----------------------------------------------------------------------------------------------------------------------
function PocketFavorHandler( isUs )
	
	local iAmount = 1;
	
	-- TODO_DIPLO_FAVORS
	--local iAmountAvailable;    
    --local iItemToBeChanged = -1;	-- This is -1 because we're not changing anything right now
	
    if( isUs == 1 ) then
        g_Deal:AddFavorTrade( g_iUs, iAmount );
    else
		g_Deal:AddFavorTrade( g_iThem, iAmount );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketFavors:RegisterCallback( Mouse.eLClick, PocketFavorHandler );
Controls.ThemPocketFavors:RegisterCallback( Mouse.eLClick, PocketFavorHandler );
Controls.UsPocketFavors:SetVoid1( 1 );
Controls.ThemPocketFavors:SetVoid1( 0 );

function TableFavorsHandler( isUs )
	if (not g_OfferIsFixed) then
		if( isUs == 1 ) then
			g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_FAVOR, g_iUs );
		else
			g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_FAVOR, g_iThem );
		end
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableFavors:RegisterCallback( Mouse.eLClick, TableFavorsHandler );
Controls.ThemTableFavors:RegisterCallback( Mouse.eLClick, TableFavorsHandler );
Controls.UsTableFavors:SetVoid1( 1 );
Controls.ThemTableFavors:SetVoid1( 0 );

function ChangeFavorsAmount( string, control )
	
	local iFavors : number;
	-- nil value means the player is in the process of erasing and entering a new number
	if (string == nil or string == "") then
    	iFavors = 0;
    -- non-nil and set to 0 is invalid, clamp to 1
	elseif (tonumber(string) == 0) then
        iFavors = 1;
	-- non-nil means a valid amount
	else
		iFavors = tonumber(string)
	end

	control:SetText(iFavors);

	-- Favors from us
    if( control:GetVoid1() == 1 ) then
		
		-- clamp value if human is offering the favors, since they are offering to SPEND them and can only spend what they have
		if (g_pUs:IsHuman()) then
			local numFavorsAvailable = g_pUs:GetNumFavors(g_iThem)
			if (numFavorsAvailable < iFavors) then
				iFavors = numFavorsAvailable;
			end
		end

        Controls.UsFavorsAmount:SetText(iFavors);
		g_Deal:SetFavorTrade( g_iUs, iFavors );
        
        local iItemToBeChanged = -1;
		--strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_FAVORS_THEM", g_pThemLeader.Description, g_pThem:GetNumFavors(g_iUs) );
		strTooltip = Locale.ConvertTextKey("TXT_KEY_DIPLO_CURRENT_FAVORS_US", g_pUs:GetNumFavors(g_iThem), g_pThemLeader.Description);
		Controls.UsTableFavors:SetToolTipString( strTooltip );
        
    -- Favors from them
    else
		
        g_Deal:SetFavorTrade( g_iThem, iFavors );
		Controls.ThemFavorsAmount:SetText(iFavors);
        
        local iItemToBeChanged = -1;		
		strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_FAVORS_US", g_pUs:GetNumFavors(g_iThem), g_pThemLeader.Description );
		Controls.ThemTableFavors:SetToolTipString( strTooltip );
    end
end
Controls.UsFavorsAmount:RegisterCallback( ChangeFavorsAmount );
Controls.UsFavorsAmount:SetVoid1( 1 );
Controls.ThemFavorsAmount:RegisterCallback( ChangeFavorsAmount );
Controls.ThemFavorsAmount:SetVoid1( 0 );

-----------------------------------------------------------------------------------------------------------------------
-- Energy Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketGoldHandler( isUs )
	
	local iAmount = 30;
	
	local iAmountAvailable;
    
    local iItemToBeChanged = -1;	-- This is -1 because we're not changing anything right now
	
    if( isUs == 1 ) then
    
		iAmountAvailable = g_Deal:GetGoldAvailable(g_iUs, iItemToBeChanged);
		if (iAmount > iAmountAvailable) then
			iAmount = iAmountAvailable;
		end
        g_Deal:AddGoldTrade( g_iUs, iAmount );
        
    else
		iAmountAvailable = g_Deal:GetGoldAvailable(g_iThem, iItemToBeChanged);
		if (iAmount > iAmountAvailable) then
			iAmount = iAmountAvailable;
		end
        g_Deal:AddGoldTrade( g_iThem, iAmount );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketEnergy:RegisterCallback( Mouse.eLClick, PocketGoldHandler );
Controls.ThemPocketEnergy:RegisterCallback( Mouse.eLClick, PocketGoldHandler );
Controls.UsPocketEnergy:SetVoid1( 1 );
Controls.ThemPocketEnergy:SetVoid1( 0 );

function TableGoldHandler( isUs )
	if (not g_OfferIsFixed) then
		if( isUs == 1 ) then
			g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_ENERGY, g_iUs );
		else
			g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_ENERGY, g_iThem );
		end
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableGold:RegisterCallback( Mouse.eLClick, TableGoldHandler );
Controls.ThemTableGold:RegisterCallback( Mouse.eLClick, TableGoldHandler );
Controls.UsTableGold:SetVoid1( 1 );
Controls.ThemTableGold:SetVoid1( 0 );

function ChangeGoldAmount( string, control )

	local iEnergy : number;

	-- nil value means the player is in the process of erasing and entering a new number
	if (string == nil or string == "") then
		iEnergy = 0;
	-- non-nil and set to 0 is invalid, clamp to 1
    elseif (tonumber(string) == 0) then
		iEnergy = 1;
	-- non-nil means a valid amount
	else
	    iEnergy = tonumber(string);
	end
	
	control:SetText( iEnergy );
	
	local iAmountAvailable;
	
	-- Energy from us
    if( control:GetVoid1() == 1 ) then
		
		iAmountAvailable = g_Deal:GetGoldAvailable(g_iUs, TradeableItems.TRADE_ITEM_ENERGY);
		if (iEnergy > iAmountAvailable) then
			iEnergy = iAmountAvailable;
			Controls.UsGoldAmount:SetText(iEnergy);
		end
		
        g_Deal:ChangeGoldTrade( g_iUs, iEnergy );
        
        local iItemToBeChanged = -1;
		local strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GOLD", g_Deal:GetGoldAvailable(g_iUs, iItemToBeChanged) );
		Controls.UsTableGold:SetToolTipString( strTooltip );
        
    -- Energy from them
    else
		
		iAmountAvailable = g_Deal:GetGoldAvailable(g_iThem, TradeableItems.TRADE_ITEM_ENERGY);
		if (iEnergy > iAmountAvailable) then
			iEnergy = iAmountAvailable;
			Controls.ThemGoldAmount:SetText(iEnergy);
		end
		
        g_Deal:ChangeGoldTrade( g_iThem, iEnergy );
        
        local iItemToBeChanged = -1;
		local strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GOLD", g_Deal:GetGoldAvailable(g_iThem, iItemToBeChanged) );
		Controls.ThemTableGold:SetToolTipString( strTooltip );
    end
end
Controls.UsGoldAmount:RegisterCallback( ChangeGoldAmount );
Controls.UsGoldAmount:SetVoid1( 1 );
Controls.ThemGoldAmount:RegisterCallback( ChangeGoldAmount );
Controls.ThemGoldAmount:SetVoid1( 0 );

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------





-----------------------------------------------------------------------------------------------------------------------
-- Energy Per Turn Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketGoldPerTurnHandler( isUs )
 	--print("PocketGoldPerTurnHandler")

	local iEnergyPerTurn = 5;
	
    if( isUs == 1 ) then
		
		if (iEnergyPerTurn > g_pUs:CalculateGoldRate()) then
			iEnergyPerTurn = g_pUs:CalculateGoldRate();
		end
		
        g_Deal:AddGoldPerTurnTrade( g_iUs, iEnergyPerTurn, g_iDealDuration );
    else
		
		if (iEnergyPerTurn > g_pThem:CalculateGoldRate()) then
			iEnergyPerTurn = g_pThem:CalculateGoldRate();
		end

        g_Deal:AddGoldPerTurnTrade( g_iThem, iEnergyPerTurn, g_iDealDuration );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketEnergyPerTurn:RegisterCallback( Mouse.eLClick, PocketGoldPerTurnHandler );
Controls.ThemPocketEnergyPerTurn:RegisterCallback( Mouse.eLClick, PocketGoldPerTurnHandler );
Controls.UsPocketEnergyPerTurn:SetVoid1( 1 );
Controls.ThemPocketEnergyPerTurn:SetVoid1( 0 );

function TableGoldPerTurnHandler( isUs )
	if (not g_OfferIsFixed) then
 		--print("TableGoldPerTurnHandler")
 		if( isUs == 1 ) then
    		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_ENERGY_PER_TURN, g_iUs );
 		else
    		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_ENERGY_PER_TURN, g_iThem );
 		end
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableGoldPerTurnButton:RegisterCallback( Mouse.eLClick, TableGoldPerTurnHandler );
Controls.ThemTableGoldPerTurnButton:RegisterCallback( Mouse.eLClick, TableGoldPerTurnHandler );
Controls.UsTableGoldPerTurnButton:SetVoid1( 1 );
Controls.ThemTableGoldPerTurnButton:SetVoid1( 0 );

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
function ChangeGoldPerTurnAmount( string, control )
	
	--print("ChangeGoldPerTurnAmount")
	
	local g_pUs = Players[ g_iUs ];
	local g_pThem = Players[ g_iThem ];
	
	local iEnergyPerTurn : number;
	-- nil value means the player is in the process of erasing and entering a new number
	if (string == nil or string == "") then
		iEnergyPerTurn = 0;
	-- non-nil and set to 0 is invalid, clamp to 1
    elseif (tonumber(string) == 0) then
		iEnergyPerTurn = 1;
	-- non-nil means a valid amount
	else
	    iEnergyPerTurn = tonumber(string);
	end
	
	control:SetText( iEnergyPerTurn );	
	
	-- GPT from us
    if( control:GetVoid1() == 1 ) then
		
		if (iEnergyPerTurn > g_pUs:CalculateGoldRate()) then
			iEnergyPerTurn = g_pUs:CalculateGoldRate();
			Controls.UsGoldPerTurnAmount:SetText(iEnergyPerTurn);
		end

        g_Deal:ChangeGoldPerTurnTrade( g_iUs, iEnergyPerTurn, g_iDealDuration );
		
		local strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GPT", g_pUs:CalculateGoldRate() - iEnergyPerTurn );
		Controls.UsTableGoldPerTurn:SetToolTipString( strTooltip );
		
    -- GPT from them
    else
		
		if (iEnergyPerTurn > g_pThem:CalculateGoldRate()) then
			iEnergyPerTurn = g_pThem:CalculateGoldRate();
			Controls.ThemGoldPerTurnAmount:SetText(iEnergyPerTurn);
		end

        g_Deal:ChangeGoldPerTurnTrade( g_iThem, iEnergyPerTurn, g_iDealDuration );
		
		local strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_GPT", g_pThem:CalculateGoldRate() - iEnergyPerTurn );
		Controls.ThemTableGoldPerTurn:SetToolTipString( strTooltip );
		
		--if (tonumber(iEnergyPerTurn) == 0) then
			--Controls.ThemGoldPerTurnAmount:GetTextControl():SetColorByName("Red");
		--else
			--Controls.ThemGoldPerTurnAmount:GetTextControl():SetColorByName("Beige_Black");
		--end
    end
end
Controls.UsGoldPerTurnAmount:RegisterCallback( ChangeGoldPerTurnAmount );
Controls.UsGoldPerTurnAmount:SetVoid1( 1 );
Controls.ThemGoldPerTurnAmount:RegisterCallback( ChangeGoldPerTurnAmount );
Controls.ThemGoldPerTurnAmount:SetVoid1( 0 );

-----------------------------------------------------------------------------------------------------------------------
-- Research Per Turn Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketResearchPerTurnHandler( isUs )

	local iResearchPerTurn;

	print ("in PocketResearchPerTurnHandler");
	
    if( isUs == 1 ) then
		
		iResearchPerTurn = 3;

		if (iResearchPerTurn > g_pUs:GetScience()) then
			iResearchPerTurn = g_pUs:GetScience();
		end
		
        g_Deal:AddResearchPerTurnTrade( g_iUs, iResearchPerTurn, g_iDealDuration );
    else
		
		iResearchPerTurn = math.min (3, (g_pThem:GetScience() * GameDefines["MAX_PERCENT_RESEARCH_TRADED"]) / 100);
		if (iResearchPerTurn > g_pThem:GetScience()) then
			iResearchPerTurn = g_pThem:GetScience();
		end

        g_Deal:AddResearchPerTurnTrade( g_iThem, iResearchPerTurn, g_iDealDuration );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketResearchPerTurn:RegisterCallback( Mouse.eLClick, PocketResearchPerTurnHandler );
Controls.ThemPocketResearchPerTurn:RegisterCallback( Mouse.eLClick, PocketResearchPerTurnHandler );
Controls.UsPocketResearchPerTurn:SetVoid1( 1 );
Controls.ThemPocketResearchPerTurn:SetVoid1( 0 );

function TableResearchPerTurnHandler( isUs )
	if (not g_OfferIsFixed) then
 		if( isUs == 1 ) then
    		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_RESEARCH_PER_TURN, g_iUs );
 		else
    		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_RESEARCH_PER_TURN, g_iThem );
 		end
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableResearchPerTurnButton:RegisterCallback( Mouse.eLClick, TableResearchPerTurnHandler );
Controls.ThemTableResearchPerTurnButton:RegisterCallback( Mouse.eLClick, TableResearchPerTurnHandler );
Controls.UsTableResearchPerTurnButton:SetVoid1( 1 );
Controls.ThemTableResearchPerTurnButton:SetVoid1( 0 );

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
function ChangeResearchPerTurnAmount( string, control )
	
	local g_pUs = Players[ g_iUs ];
	local g_pThem = Players[ g_iThem ];
	
	local iResearchPerTurn : number;
	-- nil value means the player is in the process of erasing and entering a new number
	if (string == nil or string == "") then
    	iResearchPerTurn = 0;
    -- non-nil and set to 0 is invalid, clamp to 1
	elseif (tonumber(string) == 0) then
        iResearchPerTurn = 1;
	-- non-nil means a valid amount
	else
		iResearchPerTurn = tonumber(string)
	end

	control:SetText(iResearchPerTurn);
	
	-- GPT from us
    if( control:GetVoid1() == 1 ) then
		
		if (iResearchPerTurn > g_pUs:GetScience()) then
			iResearchPerTurn = g_pUs:GetScience();
			Controls.UsResearchPerTurnAmount:SetText(iResearchPerTurn);
		end

        g_Deal:ChangeResearchPerTurnTrade( g_iUs, iResearchPerTurn, g_iDealDuration );
		
		local strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_BPT_US", g_pUs:GetScience() - iResearchPerTurn );
		Controls.UsTableResearchPerTurn:SetToolTipString( strTooltip );
		
    -- GPT from them
    else
		
		if (iResearchPerTurn > g_pThem:GetScience()) then
			iResearchPerTurn = g_pThem:GetScience();
			Controls.ThemResearchPerTurnAmount:SetText(iResearchPerTurn);
		end

        g_Deal:ChangeResearchPerTurnTrade( g_iThem, iResearchPerTurn, g_iDealDuration );
		
		local iMaxBPT = (g_pThem:GetScience() * GameDefines["MAX_PERCENT_RESEARCH_TRADED"]) / 100;
		local strTooltip = Locale.ConvertTextKey( "TXT_KEY_DIPLO_CURRENT_BPT_THEM", g_pThem:GetScience() - iResearchPerTurn, iMaxBPT );
		Controls.ThemTableResearchPerTurn:SetToolTipString( strTooltip );
		
    end
end
Controls.UsResearchPerTurnAmount:RegisterCallback( ChangeResearchPerTurnAmount );
Controls.UsResearchPerTurnAmount:SetVoid1( 1 );
Controls.ThemResearchPerTurnAmount:RegisterCallback( ChangeResearchPerTurnAmount );
Controls.ThemResearchPerTurnAmount:SetVoid1( 0 );

-----------------------------------------------------------------------------------------------------------------------
-- Cooperation Agreement Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketDoFHandler( isUs )
	print("PocketDoFHandler");
	-- The Cooperation Agreement must be on both sides of the deal
	g_Deal:AddCooperationAgreement(g_iUs);
	g_Deal:AddCooperationAgreement(g_iThem);
	
	DisplayDeal();
	DoUIDealChangedByHuman();
end

----------------------------------------------------
function TableDoFHandler( isUs )
	print("TableDoFHandler");
	if (not g_OfferIsFixed) then
		-- If removing the Cooperation Agreement, it must be removed from both sides
		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_COOPERATION_AGREEMENT, g_iUs );
		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_COOPERATION_AGREEMENT, g_iThem );
	
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end

-----------------------------------------------------------------------------------------------------------------------
-- Open Borders Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketOpenBordersHandler( isUs )

    if( isUs == 1 ) then
        g_Deal:AddOpenBorders( g_iUs, g_iDealDuration );
    else
        g_Deal:AddOpenBorders( g_iThem, g_iDealDuration );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketOpenBorders:RegisterCallback( Mouse.eLClick, PocketOpenBordersHandler );
Controls.ThemPocketOpenBorders:RegisterCallback( Mouse.eLClick, PocketOpenBordersHandler );
Controls.UsPocketOpenBorders:SetVoid1( 1 );
Controls.ThemPocketOpenBorders:SetVoid1( 0 );

function TableOpenBordersHandler( isUs )

	if (not g_OfferIsFixed) then
		if( isUs == 1 ) then
			print( "remove: us " .. g_iUs );
			g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_OPEN_BORDERS, g_iUs );
		else
			print( "remove: them " .. g_iThem );
			g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_OPEN_BORDERS, g_iThem );
		end
       
       
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableOpenBorders:RegisterCallback( Mouse.eLClick, TableOpenBordersHandler );
Controls.ThemTableOpenBorders:RegisterCallback( Mouse.eLClick, TableOpenBordersHandler );
Controls.UsTableOpenBorders:SetVoid1( 1 );
Controls.ThemTableOpenBorders:SetVoid1( 0 );




-----------------------------------------------------------------------------------------------------------------------
-- Alliance Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketAllianceHandler( isUs )

	-- Note that currently Alliance is required on both sides
	
    if( isUs == 1 ) then
        g_Deal:AddAlliance( g_iUs, g_iDealDuration );
        g_Deal:AddAlliance( g_iThem, g_iDealDuration );
    else
        g_Deal:AddAlliance( g_iUs, g_iDealDuration );
        g_Deal:AddAlliance( g_iThem, g_iDealDuration );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketAlliance:RegisterCallback( Mouse.eLClick, PocketAllianceHandler );
Controls.ThemPocketAlliance:RegisterCallback( Mouse.eLClick, PocketAllianceHandler );
Controls.UsPocketAlliance:SetVoid1( 1 );
Controls.ThemPocketAlliance:SetVoid1( 0 );

function TableAllianceHandler()
	if (not g_OfferIsFixed) then
		-- Remove from BOTH sides of the table
		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_ALLIANCE, g_iUs );
		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_ALLIANCE, g_iThem );
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableAlliance:RegisterCallback( Mouse.eLClick, TableAllianceHandler );
Controls.ThemTableAlliance:RegisterCallback( Mouse.eLClick, TableAllianceHandler );


-----------------------------------------------------------------------------------------------------------------------
-- Trade Agreement Handlers
-----------------------------------------------------------------------------------------------------------------------
function PocketTradeAgreementHandler( isUs )

	-- Note that currently Trade Agreement is required on both sides
	
    if( isUs == 1 ) then
        g_Deal:AddTradeAgreement( g_iUs, g_iDealDuration );
        g_Deal:AddTradeAgreement( g_iThem, g_iDealDuration );
    else
        g_Deal:AddTradeAgreement( g_iUs, g_iDealDuration );
        g_Deal:AddTradeAgreement( g_iThem, g_iDealDuration );
    end
    DisplayDeal();
    DoUIDealChangedByHuman();
end
Controls.UsPocketTradeAgreement:RegisterCallback( Mouse.eLClick, PocketTradeAgreementHandler );
Controls.ThemPocketTradeAgreement:RegisterCallback( Mouse.eLClick, PocketTradeAgreementHandler );
Controls.UsPocketTradeAgreement:SetVoid1( 1 );
Controls.ThemPocketTradeAgreement:SetVoid1( 0 );

function TableTradeAgreementHandler()
	if (not g_OfferIsFixed) then
		-- Remove from BOTH sides of the table
		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_TRADE_AGREEMENT, g_iUs );
		g_Deal:RemoveByType( TradeableItems.TRADE_ITEM_TRADE_AGREEMENT, g_iThem );
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end
Controls.UsTableTradeAgreement:RegisterCallback( Mouse.eLClick, TableTradeAgreementHandler );
Controls.ThemTableTradeAgreement:RegisterCallback( Mouse.eLClick, TableTradeAgreementHandler );





-----------------------------------------------------------------------------------------------------------------------
-- Handle the strategic and luxury resources
-----------------------------------------------------------------------------------------------------------------------
function PocketResourceHandler( isUs, resourceId )
	
	local iAmount = 5;

	--if ( GameInfo.Resources[ resourceId ].ResourceUsage == 2 ) then -- is a luxury resource
		--iAmount = 1;
	--end
	
    if( isUs == 1 ) then
		if (iAmount > g_Deal:GetNumResource(g_iUs, resourceId)) then
			iAmount = g_Deal:GetNumResource(g_iUs, resourceId);
		end
        g_Deal:AddResourceTrade( g_iUs, resourceId, iAmount, g_iDealDuration );
    else
		if (iAmount > g_Deal:GetNumResource(g_iThem, resourceId)) then
			iAmount = g_Deal:GetNumResource(g_iThem, resourceId);
		end
        g_Deal:AddResourceTrade( g_iThem, resourceId, iAmount, g_iDealDuration );
    end
    
    DisplayDeal();
    DoUIDealChangedByHuman();
end


function TableResourceHandler( isUs, resourceId )
	if (not g_OfferIsFixed) then
		g_Deal:RemoveResourceTrade( resourceId );
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end


function AddPocketResource( row, isUs, stack )
    local controlTable = {};
    ContextPtr:BuildInstanceForControl( "PocketResource", controlTable, stack );
        
    controlTable.Button:SetText( "" );		-- Text and quantity will be set for the specific player when the UI comes up
    controlTable.Button:SetVoids( isUs, row.ID );
    controlTable.Button:RegisterCallback( Mouse.eLClick, PocketResourceHandler );
    
    if( isUs == 1 ) then
        g_UsPocketResources[ row.ID ] = controlTable;
    else
        g_ThemPocketResources[ row.ID ] = controlTable;
    end
end

 
function AddTableStrategic( row, isUs, stack, instanceName )
    local controlTable = {};
    ContextPtr:BuildInstanceForControl( instanceName, controlTable, stack );
    
    local strString = row.IconString .. " " .. Locale.ConvertTextKey(row.Description);
    controlTable.Button:SetText( strString );
    controlTable.Button:SetVoids( isUs, row.ID );
    controlTable.Button:RegisterCallback( Mouse.eLClick, TableResourceHandler );
    controlTable.AmountEdit:RegisterCallback( ChangeResourceAmount );
    
    if( isUs == 1 ) then
        controlTable.AmountEdit:SetVoid1( 1 );
        g_UsTableResources[ row.ID ] = controlTable;
    else
        controlTable.AmountEdit:SetVoid1( 0 );
        g_ThemTableResources[ row.ID ] = controlTable;
    end
    
    controlTable.AmountEdit:SetVoid2( row.ID );
    
    g_LuxuryList[ row.ID ] = false;
end

-------------------------------------------------------------------
-------------------------------------------------------------------
function ChangeResourceAmount( string, control )
	
	local bIsUs = control:GetVoid1() == 1;
	local iResourceID = control:GetVoid2();
	
	local pPlayer;
	local iPlayer;
	if (bIsUs) then
		iPlayer = g_iUs;
	else
		iPlayer = g_iThem;
	end
	pPlayer = Players[iPlayer];

	local iNumResource : number;
	-- nil value means the player is in the process of erasing and entering a new number
	if (string == nil or string == "") then
    	iNumResource = 0;
    -- non-nil and set to 0 is invalid, clamp to 1
	elseif (tonumber(string) == 0) then
        iNumResource = 1;
	-- non-nil means a valid amount
	else
		iNumResource = tonumber(string)
	end

	control:SetText(iNumResource);
    
    -- Can't offer more than someone has
    if (iNumResource > g_Deal:GetNumResource(iPlayer, iResourceID)) then
		iNumResource = g_Deal:GetNumResource(iPlayer, iResourceID);
		control:SetText(iNumResource);
	end
    
    if ( bIsUs ) then
        g_Deal:ChangeResourceTrade( g_iUs, iResourceID, iNumResource, g_iDealDuration );
    else
        g_Deal:ChangeResourceTrade( g_iThem, iResourceID, iNumResource, g_iDealDuration );
    end
end


-------------------------------------------------------------------
-- Populate the lists
-------------------------------------------------------------------
for row in GameInfo.Resources( "ResourceUsage = 1" )	-- This matches what the AI is using to determing if the item is a Strategic resource.
do 
    --print( "adding strat: " .. row.Type );
    AddPocketResource( row, 1, Controls.UsPocketStrategicStack,		"TableStrategic" );
    AddPocketResource( row, 0, Controls.ThemPocketStrategicStack,	"TableStrategic" );
    AddTableStrategic( row, 1, Controls.UsTableStrategicStack,		"TableStrategic" );
    AddTableStrategic( row, 0, Controls.ThemTableStrategicStack,	"TableStrategic" );
end 

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
function OnChooseCity( playerID, cityID )
	if (not g_OfferIsFixed) then
		g_Deal:AddCityTrade( playerID, cityID );
    
		if( playerID == g_iUs ) then
			CityClose( 0, 1 );
		else
			CityClose( 0, 0 );
		end
    
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end

----------------------------------------------------
----------------------------------------------------
function CityClose( _, isUs )
        
    if( isUs == 1 ) then
        Controls.UsPocketCitiesStack:SetHide( true );
        Controls.UsPocketCitiesStack:CalculateSize();
        
        Controls.UsPocketStack:SetHide( false );
        Controls.UsPocketStack:CalculateSize();
        
        Controls.UsPocketPanel:CalculateInternalSize();
        Controls.UsPocketPanel:SetScrollValue( 0 );
    else
        Controls.ThemPocketCitiesStack:SetHide( true );
        Controls.ThemPocketCitiesStack:CalculateSize();
        
        Controls.ThemPocketStack:SetHide( false );
        Controls.ThemPocketStack:CalculateSize();
        
        Controls.ThemPocketPanel:CalculateInternalSize();
        Controls.ThemPocketPanel:SetScrollValue( 0 );
    end

end
Controls.UsPocketCitiesClose:RegisterCallback( Mouse.eLClick, CityClose );
Controls.UsPocketCitiesClose:SetVoid2( 1 );
Controls.ThemPocketCitiesClose:RegisterCallback( Mouse.eLClick, CityClose );
Controls.ThemPocketCitiesClose:SetVoid2( 0 );


-------------------------------------------------------------
function TableCityHandler( playerID, cityID )
	if (not g_OfferIsFixed) then
		g_Deal:RemoveCityTrade( playerID, cityID );

		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end

-------------------------------------------------------------
function ShowCityChooser( isUs )

    --print( "ShowCityChooser" );
    local m_pTo;
    local m_pFrom;
    local m_iTo;
    local m_iFrom;
    local m_pIM;
    local m_pocketStack;
    local m_citiesStack;
    local m_panel;
    
    if( isUs == 1 ) then
        m_pocketStack = Controls.UsPocketStack;
        m_citiesStack = Controls.UsPocketCitiesStack;
        m_panel       = Controls.UsPocketPanel;
        m_pIM   = g_UsPocketCitiesIM;
        m_iTo   = g_iThem;
        m_iFrom = g_iUs;
        m_pTo   = g_pThem;
        m_pFrom = g_pUs;
    else
        m_pocketStack = Controls.ThemPocketStack;
        m_citiesStack = Controls.ThemPocketCitiesStack;
        m_panel       = Controls.ThemPocketPanel;
        m_pIM   = g_ThemPocketCitiesIM;
        m_iTo   = g_iUs;
        m_iFrom = g_iThem;
        m_pTo   = g_pUs;
        m_pFrom = g_pThem;
    end
   
    m_pIM:ResetInstances();
    m_pocketStack:SetHide( true );
    m_citiesStack:SetHide( false );
    
    local instance; 
    local bFound = false;
    for pCity in m_pFrom:Cities() do
		
        local iCityID = pCity:GetID();
        
        if ( g_Deal:IsPossibleToTradeItem( m_iFrom, m_iTo, TradeableItems.TRADE_ITEM_CITIES, pCity:GetX(), pCity:GetY() ) ) then
            local instance = m_pIM:GetInstance();
            
            instance.CityName:SetText( pCity:GetName() );
            instance.CityPop:SetText( pCity:GetPopulation() );
            instance.Button:SetVoids( m_iFrom, iCityID );
            instance.Button:RegisterCallback( Mouse.eLClick, OnChooseCity );
            
            bFound = true;
        end
    end
    
    if( not bFound ) then
        m_pocketStack:SetHide( false );
        m_citiesStack:SetHide( true );
        
        if( isUs == 1 ) then
            Controls.UsPocketCities:SetDisabled( false );
            Controls.UsPocketCities:LocalizeAndSetToolTip( "TXT_KEY_DIPLO_TO_TRADE_CITY_NO_TT" );
    		Controls.UsPocketCities:GetTextControl():SetColorByName("Gray_Black");
        else
            Controls.ThemPocketCities:SetDisabled( true );
            Controls.ThemPocketCities:LocalizeAndSetToolTip( "TXT_KEY_DIPLO_TO_TRADE_CITY_NO_THEM" );
    		Controls.ThemPocketCities:GetTextControl():SetColorByName("Gray_Black");
        end
    end
    
    m_citiesStack:CalculateSize();
    m_pocketStack:CalculateSize();
    m_panel:CalculateInternalSize();
    m_panel:SetScrollValue( 0 );
end

Controls.UsPocketCities:SetVoid1( 1 );
Controls.UsPocketCities:RegisterCallback( Mouse.eLClick, ShowCityChooser );

Controls.ThemPocketCities:SetVoid1( 0 );
Controls.ThemPocketCities:RegisterCallback( Mouse.eLClick, ShowCityChooser );
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------
-- OtherPlayer leader lists
-----------------------------------------------------------------------------------------------------------------------
function ShowOtherPlayerChooser( isUs, type )

    --print( "ShowOtherPlayerChooser" );
    local SubTableName;
    local iFromPlayer;
    local tradeType;
    local iToPlayer;
    
    if( type == WAR ) then
        tradeType = TradeableItems.TRADE_ITEM_THIRD_PARTY_WAR;
    elseif( type == PEACE ) then
        tradeType = TradeableItems.TRADE_ITEM_THIRD_PARTY_PEACE;
    end
    
    local pocketStack;
    local leaderStack;
    local panel;
    
    -- disable invalid players
    if( isUs == 1 ) then
        g_UsOtherPlayerMode   = type;
        pocketStack = Controls.UsPocketStack;
        leaderStack = Controls.UsPocketLeaderStack;
        panel = Controls.UsPocketPanel;
        SubTableName = "UsPocket";
        iFromPlayer = g_iUs;
        iToPlayer = g_iThem;
    else
        g_ThemOtherPlayerMode = type;
        pocketStack = Controls.ThemPocketStack;
        leaderStack = Controls.ThemPocketLeaderStack;
        panel = Controls.ThemPocketPanel;
        SubTableName = "ThemPocket";
        iFromPlayer = g_iThem;
        iToPlayer = g_iUs;
    end
   
 	for iLoopPlayer = 0, GameDefines.MAX_CIV_PLAYERS-1, 1 do
		pLoopPlayer = Players[ iLoopPlayer ];
		iLoopTeam = pLoopPlayer:GetTeam();

		local otherPlayerButton = g_OtherPlayersButtons[iLoopPlayer];
		
		if(otherPlayerButton ~= nil) then
			-- they're alive, not us, not them, we both know, and we can trade....
			if(pLoopPlayer:IsAlive()) then
			
				local otherPlayerButtonSubTableNameButton = otherPlayerButton[SubTableName].Button;
			
				local strToolTip = "";
				local iFromTeam = Players[iFromPlayer]:GetTeam();
			
     			if( g_iUsTeam == iLoopTeam or g_iThemTeam == iLoopTeam or
    				not g_pUsTeam:IsHasMet( iLoopTeam ) or not g_pThemTeam:IsHasMet( iLoopTeam ) ) then
    		    
    				otherPlayerButtonSubTableNameButton:SetHide( true );

   				elseif( g_Deal:IsPossibleToTradeItem( iFromPlayer, iToPlayer, tradeType, iLoopTeam ) ) then
                
    				otherPlayerButtonSubTableNameButton:SetHide( false );
    				otherPlayerButtonSubTableNameButton:SetDisabled( false );
    				otherPlayerButtonSubTableNameButton:SetAlpha( 1 );
				else
                        
    				otherPlayerButtonSubTableNameButton:SetHide( false );
    				otherPlayerButtonSubTableNameButton:SetDisabled( true );
    				otherPlayerButtonSubTableNameButton:SetAlpha( 0.5 );
    		    
    				-- Why won't they make peace?
    				if (type == PEACE) then
					
						-- Not at war
						if (not Teams[iLoopTeam]:IsAtWar(iFromTeam)) then
							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_NOT_AT_WAR");
    				
    					-- Minor that won't make peace
    					elseif (pLoopPlayer:IsMinorCiv()) then
    					
    						local pMinorTeam = Teams[iLoopTeam];
    						local iAlly = pLoopPlayer:GetAlly();
    					
    						-- Minor in permanent war with this guy
    						if (pLoopPlayer:IsMinorPermanentWar(iFromPlayer)) then
    							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_MINOR_PERMANENT_WAR");
			    			-- Minor allied to a player
	    					elseif (pMinorTeam:IsAtWar(iFromTeam) and iAlly ~= -1 and Teams[Players[iAlly]:GetTeam()]:IsAtWar(iFromTeam)) then
			    				strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_MINOR_ALLY_AT_WAR");
    						end
    					
    					-- Major that won't make peace
    					else
    					
    						-- AI don't want no peace!
    						if (not Players[iFromPlayer]:IsWillAcceptPeaceWithPlayer(iLoopPlayer)) then
    							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_MINOR_THIS_GUY_WANTS_WAR");
    						-- Other AI don't want no peace!
    						elseif (not pLoopPlayer:IsWillAcceptPeaceWithPlayer(iFromPlayer)) then
    							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_MINOR_OTHER_GUY_WANTS_WAR");
    						end
    					
    					end
    			
    				-- Why won't they make war?
    				else
					
						-- Already at war
						if (Teams[iLoopTeam]:IsAtWar(iFromTeam)) then
							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_ALREADY_AT_WAR");
					
						-- Locked in to peace
						elseif (Teams[iFromTeam]:IsForcePeace(iLoopTeam)) then
							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_FORCE_PEACE");
					
						-- City-State ally
						elseif (pLoopPlayer:IsMinorCiv() and pLoopPlayer:GetAlly() == iFromPlayer) then
							strToolTip = Locale.ConvertTextKey("TXT_KEY_DIPLO_NO_WAR_ALLIES");
						end
    				
    				end
    		    
    			end
			
				-- Tooltip
				otherPlayerButtonSubTableNameButton:SetToolTipString(strToolTip);
			else
				-- No longer alive, but they might have been so make sure the button is hidden
				local otherPlayerButtonSubTableNameButton = otherPlayerButton[SubTableName].Button;
				if (otherPlayerButtonSubTableNameButton ~= nil) then
    				otherPlayerButtonSubTableNameButton:SetHide( true );
				end
			end
		end
	end
	
	pocketStack:SetHide( true );
	pocketStack:CalculateSize();
	leaderStack:SetHide( false );
	leaderStack:CalculateSize();
	
	panel:CalculateInternalSize();
    panel:SetScrollValue( 0 );
end

Controls.UsPocketOtherPlayerWar:SetVoids( 1, WAR );
Controls.UsPocketOtherPlayerWar:RegisterCallback( Mouse.eLClick, ShowOtherPlayerChooser );

Controls.ThemPocketOtherPlayerWar:SetVoids( 0, WAR );
Controls.ThemPocketOtherPlayerWar:RegisterCallback( Mouse.eLClick, ShowOtherPlayerChooser );

Controls.UsPocketOtherPlayerPeace:SetVoids( 1, PEACE );
Controls.UsPocketOtherPlayerPeace:RegisterCallback( Mouse.eLClick, ShowOtherPlayerChooser );

Controls.ThemPocketOtherPlayerPeace:SetVoids( 0, PEACE );
Controls.ThemPocketOtherPlayerPeace:RegisterCallback( Mouse.eLClick, ShowOtherPlayerChooser );


----------------------------------------------------
----------------------------------------------------
function LeaderClose( _, isUs )
    if( isUs == 1 ) then
        Controls.UsPocketLeaderStack:SetHide( true );
        Controls.UsPocketLeaderStack:CalculateSize();
        
        Controls.UsPocketStack:SetHide( false );
        Controls.UsPocketStack:CalculateSize();
        
        Controls.UsPocketPanel:CalculateInternalSize();
        Controls.UsPocketPanel:SetScrollValue( 0 );
    else
        Controls.ThemPocketLeaderStack:SetHide( true );
        Controls.ThemPocketLeaderStack:CalculateSize();
        
        Controls.ThemPocketStack:SetHide( false );
        Controls.ThemPocketStack:CalculateSize();
        
        Controls.ThemPocketPanel:CalculateInternalSize();
        Controls.ThemPocketPanel:SetScrollValue( 0 );
    end
end
Controls.UsPocketLeaderClose:RegisterCallback( Mouse.eLClick, LeaderClose );
Controls.UsPocketLeaderClose:SetVoid2( 1 );
Controls.ThemPocketLeaderClose:RegisterCallback( Mouse.eLClick, LeaderClose );
Controls.ThemPocketLeaderClose:SetVoid2( 0 );


----------------------------------------------------
-- handler for when the leader is actually clicked
----------------------------------------------------
function LeaderSelected( iOtherPlayer, isUs )

    local iWho;
    local mode;

    LeaderClose( 0, isUs );
    if( isUs == 1 ) then
        iWho = g_iUs;
        mode = g_UsOtherPlayerMode;
	else
        iWho = g_iThem;
        mode = g_ThemOtherPlayerMode;
    end
    
    local pOtherPlayer = Players[ iOtherPlayer ];
	local iOtherTeam = pOtherPlayer:GetTeam();

	if( mode == WAR ) then
    	g_Deal:AddThirdPartyWar( iWho, iOtherTeam );
	else
    	g_Deal:AddThirdPartyPeace( iWho, iOtherTeam, GameDefines.PEACE_TREATY_LENGTH );
    end
    
    DisplayDeal();
    DoUIDealChangedByHuman();
end


-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
function OnOtherPlayerTablePeace( iOtherPlayer, isUs )
    local firstParty;
    if (isUs == 1) then
        firstParty = g_iUs;
    else
        firstParty = g_iThem;
    end
    
    local bRemoveDeal = true;
    local iOtherTeam = Players[iOtherPlayer]:GetTeam();
    
    --print("iOtherPlayer: " .. iOtherPlayer);
    
    -- if this is a peace negotiation
	if (g_pUsTeam:IsAtWar(g_iThemTeam )) then
		--print("Peace negotiation");
		-- if the player is a minor
		if (Players[iOtherPlayer]:IsMinorCiv()) then
			--print("Other civ is a minor civ");
			local iAlly = Players[iOtherPlayer]:GetAlly();
			--print("iAlly: " .. iAlly);
			--print("g_iUs: " .. g_iUs);
			--print("g_iThem: " .. g_iThem);
			-- if the minor is allied with either us or them
			if (iAlly == g_iUs or iAlly == g_iThem) then
				-- don't allow the third party peace deal to be removed
				--print("Don't allow removal because they are a third-party ally");
				bRemoveDeal = false;
			end
		end
	end
	
	if (not g_OfferIsFixed) then
		if (bRemoveDeal) then
			--print("Removing deal");
			g_Deal:RemoveThirdPartyPeace( firstParty, iOtherTeam );

			DoClearTable();
			DisplayDeal();
			DoUIDealChangedByHuman();    
		end
	end
end


-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
function OnOtherPlayerTableWar( iOtherPlayer, isUs )
	if (not g_OfferIsFixed) then
		local firstParty;
		if( isUs == 1 ) then
			firstParty = g_iUs;
		else
			firstParty = g_iThem;
		end
    
		local pOtherPlayer = Players[ iOtherPlayer ];
		local iOtherTeam = pOtherPlayer:GetTeam();
		g_Deal:RemoveThirdPartyWar( firstParty, iOtherTeam );
   
		DoClearTable();
		DisplayDeal();
		DoUIDealChangedByHuman();
	end
end


-----------------------------------------------------------------------------------------------------------------------
-- Build the THIRD_PARTY lists. These are also know as thirdparty if you're doing a text search
-- the only thing we trade in third party mode is war/peace, so make sure those aren't disabled
-----------------------------------------------------------------------------------------------------------------------
if( Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_WAR ) or
    Game.IsOption( GameOptionTypes.GAMEOPTION_ALWAYS_PEACE ) or
    Game.IsOption( GameOptionTypes.GAMEOPTION_NO_CHANGING_WAR_PEACE ) ) then
    
    Controls.UsPocketOtherPlayer:SetHide( true );
    Controls.UsPocketOtherPlayerStack:SetHide( true );
    Controls.ThemPocketOtherPlayer:SetHide( true );
    Controls.ThemPocketOtherPlayerStack:SetHide( true );
    
    g_bEnableThirdParty = false;
    
else
    g_bEnableThirdParty = true;
    for iLoopPlayer = 0, GameDefines.MAX_CIV_PLAYERS-1, 1 do

    	local pLoopPlayer = Players[ iLoopPlayer ];
    	local iLoopTeam = pLoopPlayer:GetTeam();

    	if( pLoopPlayer:IsEverAlive() ) then

    	    local newButtonsTable = {};
    	    g_OtherPlayersButtons[ iLoopPlayer ] = newButtonsTable;

        	local szName;
            if( pLoopPlayer:IsHuman() ) then
				local MAX_NAME_CHARS= 20;
				szName = TruncateStringByLength(pLoopPlayer:GetNickName(), MAX_NAME_CHARS);
            else
        	    szName = pLoopPlayer:GetName();
        	end
        	szName = szName .. " (" .. Locale.ConvertTextKey(GameInfo.Civilizations[Players[iLoopPlayer]:GetCivilizationType()].ShortDescription) .. ")";

    	    -- Us Pocket
        	local controlTable = {};
            ContextPtr:BuildInstanceForControl( "OtherPlayerEntry", controlTable, Controls.UsPocketLeaderStack );
        	CivIconHookup( iLoopPlayer,  32, controlTable.CivIcon, controlTable.CivIconBG, nil, true, false, controlTable.CivIconHighlight );
        	TruncateString(controlTable.Name, controlTable.Button:GetSizeX() - controlTable.Name:GetOffsetX(), szName);
        	controlTable.Button:SetVoids( iLoopPlayer, 1 );
        	controlTable.Button:RegisterCallback( Mouse.eLClick, LeaderSelected );
            newButtonsTable.UsPocket = controlTable;


    	    -- Them Pocket
        	controlTable = {};
            ContextPtr:BuildInstanceForControl( "OtherPlayerEntry", controlTable, Controls.ThemPocketLeaderStack );
        	CivIconHookup( iLoopPlayer,  32, controlTable.CivIcon, controlTable.CivIconBG, nil, true, false, controlTable.CivIconHighlight );
        	TruncateString(controlTable.Name, controlTable.Button:GetSizeX() - controlTable.Name:GetOffsetX(), szName);
        	controlTable.Button:SetVoids( iLoopPlayer, 0 );
        	controlTable.Button:RegisterCallback( Mouse.eLClick, LeaderSelected );
            newButtonsTable.ThemPocket = controlTable;


    	    -- Us Table Peace
        	controlTable = {};
            ContextPtr:BuildInstanceForControl( "OtherPlayerEntry", controlTable, Controls.UsTableMakePeaceStack );
        	CivIconHookup( iLoopPlayer,  32, controlTable.CivIcon, controlTable.CivIconBG, nil, true, false, controlTable.CivIconHighlight );
        	TruncateString(controlTable.Name, controlTable.Button:GetSizeX() - controlTable.Name:GetOffsetX(), szName);
        	controlTable.Button:SetVoids( iLoopPlayer, 1 );
        	controlTable.Button:RegisterCallback( Mouse.eLClick, OnOtherPlayerTablePeace );
            newButtonsTable.UsTablePeace = controlTable;


    	    -- Us Table War
        	controlTable = {};
            ContextPtr:BuildInstanceForControl( "OtherPlayerEntry", controlTable, Controls.UsTableDeclareWarStack );
        	CivIconHookup( iLoopPlayer,  32, controlTable.CivIcon, controlTable.CivIconBG, nil, true, false, controlTable.CivIconHighlight );
        	TruncateString(controlTable.Name, controlTable.Button:GetSizeX() - controlTable.Name:GetOffsetX(), szName);
        	controlTable.Button:SetVoids( iLoopPlayer, 1 );
        	controlTable.Button:RegisterCallback( Mouse.eLClick, OnOtherPlayerTableWar );
            newButtonsTable.UsTableWar = controlTable;


    	    -- Them Table Peace
        	controlTable = {};
            ContextPtr:BuildInstanceForControl( "OtherPlayerEntry", controlTable, Controls.ThemTableMakePeaceStack );
        	CivIconHookup( iLoopPlayer,  32, controlTable.CivIcon, controlTable.CivIconBG, nil, true, false, controlTable.CivIconHighlight );
        	TruncateString(controlTable.Name, controlTable.Button:GetSizeX() - controlTable.Name:GetOffsetX(), szName);
        	controlTable.Button:SetVoids( iLoopPlayer, 0 );
        	controlTable.Button:RegisterCallback( Mouse.eLClick, OnOtherPlayerTablePeace );
            newButtonsTable.ThemTablePeace = controlTable;


    	    -- Them Table War
        	controlTable = {};
            ContextPtr:BuildInstanceForControl( "OtherPlayerEntry", controlTable, Controls.ThemTableDeclareWarStack );
        	CivIconHookup( iLoopPlayer,  32, controlTable.CivIcon, controlTable.CivIconBG, nil, true, false, controlTable.CivIconHighlight );
        	TruncateString(controlTable.Name, controlTable.Button:GetSizeX() - controlTable.Name:GetOffsetX(), szName);
        	controlTable.Button:SetVoids( iLoopPlayer, 0 );
        	controlTable.Button:RegisterCallback( Mouse.eLClick, OnOtherPlayerTableWar );
            newButtonsTable.ThemTableWar = controlTable;

    	end
    end
end
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

Controls.UsMakePeaceDuration:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", 10 );
Controls.UsDeclareWarDuration:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", 10 );
Controls.ThemMakePeaceDuration:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", 10 );
Controls.ThemDeclareWarDuration:LocalizeAndSetText( "TXT_KEY_DIPLO_TURNS", 10 );

ResetDisplay();
DisplayDeal();
