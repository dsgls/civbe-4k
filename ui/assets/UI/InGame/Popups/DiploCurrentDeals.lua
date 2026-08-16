-- ===========================================================================
-- Deals - Current and Historical
-- ===========================================================================
include( "IconSupport" );
include( "TradeLogic" );
--OpenDealReview();


local m_Deal			= UI.GetScratchDeal(); 
local m_bIsMultiplayer	= Game:IsNetworkMultiPlayer();
local m_selectedDealControl	= nil;


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function PopulateDealChooser()

    Controls.CurrentDealsStack:DestroyAllChildren();
    Controls.HistoricDealsStack:DestroyAllChildren();

    local iPlayer = Game:GetActivePlayer();
	
    ----------------------------------------------------------------------------    
    ----------------------------------------------------------------------------    
    local iNumCurrentDeals = UI.GetNumCurrentDeals( iPlayer );    
    if( iNumCurrentDeals > 0 ) then
        Controls.CurrentDealsButton:SetHide( false );
		Controls.CurrentDealsButton:SetText("[ICON_MINUS]" .. Locale.ConvertTextKey( "{TXT_KEY_DO_CURRENT_DEALS:upper}" )  );
        Controls.CurrentDealsStack:SetHide( false );
        for i = 0, iNumCurrentDeals - 1 do
        
            controlTable = {};
            ContextPtr:BuildInstanceForControl( "DealButtonInstance", controlTable, Controls.CurrentDealsStack );
            
			local thisControl = controlTable;	-- Necessary as somewhere else controlTable is defined and if used, callback's lambda poitns to the wrong one!
            controlTable.DealButton:SetVoids( i, 1 );			
			controlTable.DealButton:RegisterCallback( Mouse.eLClick, function() PendingDealButtonHandler(thisControl,i,1) end );
            
            UI.LoadCurrentDeal( iPlayer, i );
            BuildDealButton( iPlayer, controlTable );
            BuildCurrentDealButton( iPlayer, controlTable );
        end
    else
        Controls.CurrentDealsButton:SetHide( true );
        Controls.CurrentDealsStack:SetHide( true );
    end

    ----------------------------------------------------------------------------    
    ----------------------------------------------------------------------------    
    local iNumHistoricDeals = UI.GetNumHistoricDeals( iPlayer );
    if( iNumHistoricDeals > 0 ) then
        Controls.HistoricDealsButton:SetHide( false );
        Controls.HistoricDealsButton:SetText( "[ICON_MINUS]" .. Locale.ConvertTextKey( "{TXT_KEY_DO_COMPLETE_DEALS:upper}" ) );
        
        Controls.HistoricDealsStack:SetHide( false );
        for i = 0, iNumHistoricDeals - 1 do

            controlTable = {};
            ContextPtr:BuildInstanceForControl( "DealButtonInstance", controlTable, Controls.HistoricDealsStack );
            
			local thisControl = controlTable;	-- Necessary as somewhere else controlTable is defined and if used, callback's lambda poitns to the wrong one!
            controlTable.DealButton:SetVoids( i, 0 );			
			controlTable.DealButton:RegisterCallback( Mouse.eLClick, function() CompletedDealButtonHandler(thisControl,i,0) end );
             
            UI.LoadHistoricDeal( iPlayer, i );
            BuildCompletedDealButton( iPlayer, controlTable );
        end
    else
        Controls.HistoricDealsButton:SetHide( true );
        Controls.HistoricDealsStack:SetHide( true );
    end
    
    if( iNumHistoricDeals == 0 and iNumCurrentDeals == 0 ) then
        Controls.NoDealsText:SetHide( false );
    else
        Controls.NoDealsText:SetHide( true );
    end
    
    Controls.CurrentDealsStack:CalculateSize();
    Controls.HistoricDealsStack:CalculateSize();
    Controls.AllDealsStack:CalculateSize();
    Controls.ListScrollPanel:CalculateInternalSize();
    Controls.AllDealsStack:ReprocessAnchoring();
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function BuildDealButton( iPlayer, controlTable )    

    local iOtherPlayer = m_Deal:GetOtherPlayer( iPlayer );
    local pOtherPlayer = Players[ iOtherPlayer ];
    
    controlTable.TurnsLabel:LocalizeAndSetText( "TXT_KEY_DO_ON_TURN", (m_Deal:GetStartTurn() + m_Deal:GetDuration()) );
	CivIconHookup( iOtherPlayer, 45, controlTable.CivIcon, controlTable.CivIconBG, nil, false, false, controlTable.CivIconHighlight );
   
    local civName = Locale.ConvertTextKey( GameInfo.Civilizations[ pOtherPlayer:GetCivilizationType() ].ShortDescription );
    
    --if( m_bIsMulitplayer and pOtherPlayer:IsHuman() ) then
    if( pOtherPlayer:GetNickName() ~= "" and pOtherPlayer:IsHuman() ) then	
		local MAX_NAME_CHARS= 20;
		local strLeaderName = TruncateStringByLength( Locale.ToUpper(pOtherPlayer:GetNickName()), MAX_NAME_CHARS);		
        controlTable.PlayerLabel:SetText( strLeaderName );
        controlTable.CivLabel:SetText( Locale.ToUpper(civName) );
    else
    
        controlTable.PlayerLabel:SetText( Locale.ToUpper(pOtherPlayer:GetName()) );
        controlTable.CivLabel:SetText( Locale.ToUpper(civName) );
	end
    
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function BuildCurrentDealButton( iPlayer, controlTable )    

    local iOtherPlayer = m_Deal:GetOtherPlayer( iPlayer );
    local pOtherPlayer = Players[ iOtherPlayer ];  

    controlTable.TurnsLabel:LocalizeAndSetText( "TXT_KEY_DO_ENDS_ON", (m_Deal:GetStartTurn() + m_Deal:GetDuration()) );
	CivIconHookup( iOtherPlayer, 45, controlTable.CivIcon, controlTable.CivIconBG, nil, false, false, controlTable.CivIconHighlight );
    
   
    local civName = Locale.ConvertTextKey( GameInfo.Civilizations[ pOtherPlayer:GetCivilizationType() ].ShortDescription );
    
    --if( m_bIsMulitplayer and pOtherPlayer:IsHuman() ) then
    if( pOtherPlayer:GetNickName() ~= "" and pOtherPlayer:IsHuman() ) then
		local MAX_NAME_CHARS= 20;
		local strLeaderName = TruncateStringByLength( Locale.ToUpper(pOtherPlayer:GetNickName()), MAX_NAME_CHARS);		
        controlTable.PlayerLabel:SetText( strLeaderName );
        controlTable.CivLabel:SetText( Locale.ToUpper(civName) );
    else
    
        controlTable.PlayerLabel:SetText( Locale.ToUpper(pOtherPlayer:GetName()) );
        controlTable.CivLabel:SetText(  Locale.ToUpper(civName) );
	end
    
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function BuildCompletedDealButton( iPlayer, controlTable )    

    local iOtherPlayer = m_Deal:GetOtherPlayer( iPlayer );
    local pOtherPlayer = Players[ iOtherPlayer ];
    
    controlTable.TurnsLabel:LocalizeAndSetText( "TXT_KEY_DO_ENDED_ON", (m_Deal:GetStartTurn() + m_Deal:GetDuration()) );
	CivIconHookup( iOtherPlayer, 45, controlTable.CivIcon, controlTable.CivIconBG, nil, false, false, controlTable.CivIconHighlight );
    
   
    local civName = Locale.ConvertTextKey( GameInfo.Civilizations[ pOtherPlayer:GetCivilizationType() ].ShortDescription );
    
    --if( m_bIsMulitplayer and pOtherPlayer:IsHuman() ) then
    if( pOtherPlayer:GetNickName() ~= "" and pOtherPlayer:IsHuman() ) then
		local MAX_NAME_CHARS= 20;
		local strLeaderName = TruncateStringByLength( Locale.ToUpper(pOtherPlayer:GetNickName()), MAX_NAME_CHARS);		
        controlTable.PlayerLabel:SetText( strLeaderName );
        controlTable.CivLabel:SetText( Locale.ToUpper(civName) );
    else
    
        controlTable.PlayerLabel:SetText( Locale.ToUpper(pOtherPlayer:GetName()) );
        controlTable.CivLabel:SetText( Locale.ToUpper(civName) );
	end
    
end
        

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ToggleStack( isHistoric )
    if( isHistoric == 1 ) then
        if( Controls.HistoricDealsStack:IsHidden() ) then
            Controls.HistoricDealsStack:SetHide( false );
            Controls.HistoricDealsButton:SetText( "[ICON_MINUS]" .. Locale.ConvertTextKey( "{TXT_KEY_DO_COMPLETE_DEALS:upper}" ) );
        else
            Controls.HistoricDealsStack:SetHide( true );
            Controls.HistoricDealsButton:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( "{TXT_KEY_DO_COMPLETE_DEALS:upper}" ) );
        end
    else
        if( Controls.CurrentDealsStack:IsHidden() ) then
            Controls.CurrentDealsStack:SetHide( false );
            Controls.CurrentDealsButton:SetText( "[ICON_MINUS]" .. Locale.ConvertTextKey( "{TXT_KEY_DO_CURRENT_DEALS:upper}" ) );
        else
            Controls.CurrentDealsStack:SetHide( true );
            Controls.CurrentDealsButton:SetText( "[ICON_PLUS]" .. Locale.ConvertTextKey( "{TXT_KEY_DO_CURRENT_DEALS:upper}" ) );
        end
    end
	Controls.CurrentDealsStack:CalculateSize();
	Controls.CurrentDealsStack:ReprocessAnchoring();
end
Controls.HistoricDealsButton:SetVoid1( 1 );
Controls.HistoricDealsButton:RegisterCallback( Mouse.eLClick, ToggleStack );
Controls.CurrentDealsButton:SetVoid1( 0 );
Controls.CurrentDealsButton:RegisterCallback( Mouse.eLClick, ToggleStack );


function SetHighlight( controlWithHighlight )
	-- Turn off highlight on other control, turn on this 
	if ( m_selectedDealControl ~= nil ) then 
		m_selectedDealControl.Highlight:SetHide(true);		
	end
	m_selectedDealControl = controlWithHighlight;
	if (controlWithHighlight ~= nil ) then
		controlWithHighlight.Highlight:SetHide(false);
	end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function PendingDealButtonHandler( thisControl, index, iIsCurrent )
    local iPlayer = Game.GetActivePlayer();

	SetHighlight(thisControl);

    if( iIsCurrent == 1 ) then
        UI.LoadCurrentDeal( iPlayer, index );
    else
        UI.LoadHistoricDeal( iPlayer, index );
    end
    
    local iBeginTurn = m_Deal:GetStartTurn();
    local iDuration  = m_Deal:GetDuration();
    if( iDuration ~= 0 ) then
        Controls.TurnStart:SetText( Locale.ConvertTextKey( "TXT_KEY_DO_DEAL_BEGAN", iBeginTurn ) );
        Controls.TurnEnd:SetHide( false );
        Controls.TurnEnd:SetText( Locale.ConvertTextKey( "TXT_KEY_DO_DEAL_DURATION", iDuration ) );
    else
        Controls.TurnStart:SetText( Locale.ConvertTextKey( "TXT_KEY_DO_ON_TURN", iBeginTurn ) );
        Controls.TurnEnd:SetHide( true );
    end
    
    OpenDealReview();
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function CompletedDealButtonHandler( thisControl, index, iIsCurrent )
    local iPlayer = Game.GetActivePlayer();

	SetHighlight( thisControl );

    if( iIsCurrent == 1 ) then
        UI.LoadCurrentDeal( iPlayer, index );
    else
        UI.LoadHistoricDeal( iPlayer, index );
    end
    
    local iBeginTurn = m_Deal:GetStartTurn();
    local iDuration  = m_Deal:GetDuration();
    if( iDuration ~= 0 ) then
        Controls.TurnStart:SetText( Locale.ConvertTextKey( "TXT_KEY_DO_DEAL_BEGAN", iBeginTurn ) );
        Controls.TurnEnd:SetHide( false );
        Controls.TurnEnd:SetText( Locale.ConvertTextKey( "TXT_KEY_DO_DEAL_LASTED", iDuration ) );
    else
        Controls.TurnStart:SetText( Locale.ConvertTextKey( "TXT_KEY_DO_ENDED_ON", iBeginTurn ) );
        Controls.TurnEnd:SetHide( true );
    end
    
    OpenDealReview();
end



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler( bIsHide, bInitState )

    if( not bInitState ) then
		
        if( not bIsHide ) then
			
			-- Do not call this on hiding... otherwise a player spamming 
			-- open/close diplo deals can result in a deal popping up during 
			-- AI's turn and it immediately being cleared out here.
			m_Deal:ClearItems();	

            DoClearTable();
            DisplayDeal();
            PopulateDealChooser();
            
            Controls.TradeDetails:SetHide( true );
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );
