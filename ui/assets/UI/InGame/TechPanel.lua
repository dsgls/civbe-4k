-------------------------------------------------
-- TECH PANEL
-------------------------------------------------
include( "InstanceManager" );
include( "TechButtonInclude" );
include( "TechHelpInclude" );

local maxSmallButtons = 5;

local eRecentTech = -1;
local eCurrentTech= -1;

local techPortraitSize = Controls.TechIcon:GetSize().x;
local stealingTechTargetPlayerID = -1;

local helpTT = Locale.ConvertTextKey( "TXT_KEY_NOTIFICATION_SUMMARY_NEW_RESEARCH" );

-------------------------------------------------
function OpenTechTree()	
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, Data2 = stealingTechTargetPlayerID } );
end
Controls.ActiveStyle:RegisterCallback( Mouse.eLClick, OpenTechTree);
Controls.BigTechButton:RegisterCallback( Mouse.eLClick, OpenTechTree );

function OnTechnologyButtonRClicked()

	local tech = eCurrentTech;
	if tech == -1 then
		tech = eRecentTech;
	end
	
	if tech ~= -1 then
		local pTechInfo = GameInfo.Technologies[tech];
		if pTechInfo then
		
			-- search by name
			local searchString = Locale.ConvertTextKey( pTechInfo.Description );
			Events.SearchForPediaEntry( searchString );			
		end
	end
	
end
Controls.BigTechButton:RegisterCallback( Mouse.eRClick, OnTechnologyButtonRClicked );

function HideSmallIconBacking( thisTechButtonInstance, maxSmallButtons, numButtonsAdded )
	-- Small button backings are named "B1_back", "B2_back", "B3_back"
	for buttonNum = 1, maxSmallButtons, 1 do
		local buttonName = "B"..tostring(buttonNum).."_back";
		thisTechButtonInstance[buttonName]:SetHide(true);
	end
	for buttonNum = 1, numButtonsAdded, 1 do
		local buttonName = "B"..tostring(buttonNum).."_back";
		thisTechButtonInstance[buttonName]:SetHide(false);
	end
end

function ResizeTechPanel(numButtonsAdded)
	local minPanelSize = 764;
	local TechPanelSize = 140;
	local PanelFadeoutSpace=180
	local smallButtonStackSize = 0;
	-- Buttons are 64x64 with a padding of -8
	if(numButtonsAdded > 3) then
		smallButtonStackSize =  114*numButtonsAdded;
	end;
	-- Figure out which is bigger - the labels or the stack, and add that number of pixels to the TechPanelSize
	TechPanelSize = TechPanelSize + math.max(smallButtonStackSize, Controls.TechText:GetSizeX(), Controls.FinishedTechText:GetSizeX());
	
	Controls.ActiveStyle:SetSizeVal(math.max(TechPanelSize+PanelFadeoutSpace,minPanelSize),142);
end

function OnTechPanelUpdated()
	
	local pPlayer		:table = Players[Game.GetActivePlayer()];
	local pTeam			:table = Teams[pPlayer:GetTeam()];
	local pTeamTechs	:table = pTeam:GetTeamTechs();
	
	eCurrentTech = pPlayer:GetCurrentResearch();
	eRecentTech = pTeamTechs:GetLastTechAcquired();
	
	local fResearchProgressPercent = 0;
	local fResearchProgressPlusThisTurnPercent = 0;
	
	local researchStatus = "";
	local szText = "";
	local numButtonsAdded = 0;
		
	techPediaSearchStrings = {};
	
	-- Are we researching something right now?
	if (eCurrentTech ~= -1) then
		
		local iResearchTurnsLeft = pPlayer:GetResearchTurnsLeft(eCurrentTech, true);
		local iCurrentResearchProgress = pPlayer:GetResearchProgress(eCurrentTech);
		local iResearchNeeded = pPlayer:GetResearchCost(eCurrentTech);
		local iResearchPerTurn = pPlayer:GetScience();
		local iCurrentResearchPlusThisTurn = iCurrentResearchProgress + iResearchPerTurn;
		
		fResearchProgressPercent = iCurrentResearchProgress / iResearchNeeded;
		fResearchProgressPlusThisTurnPercent = iCurrentResearchPlusThisTurn / iResearchNeeded;
		
		if (fResearchProgressPlusThisTurnPercent > 1) then
			fResearchProgressPlusThisTurnPercent = 1
		end
		
		local progressPercentTimes100 =  math.floor(100 * fResearchProgressPercent + 0.5);
		local progressBarSize = { x = math.floor(213 * fResearchProgressPercent), y = 7 };
		local progressPlusThisTurnPercentTimes100 =  math.floor(100 * fResearchProgressPlusThisTurnPercent + 0.5);
		local progressPlusThusTurnBarSize = { x = math.floor(213 * fResearchProgressPlusThisTurnPercent), y = 7 };
		Controls.TechProgress:Resize(progressBarSize.x,progressBarSize.y);
		Controls.TechProgressThisTurn:Resize(progressPlusThusTurnBarSize.x,progressPlusThusTurnBarSize.y);
				
		local pTechInfo = GameInfo.Technologies[eCurrentTech];
		if pTechInfo then
			szText = Locale.ConvertTextKey( "{" .. pTechInfo.Description .. ":upper}" );
			if iResearchPerTurn > 0 then
				szText = szText .. " (" .. tostring(iResearchTurnsLeft) .. ")";
			end		
			local customHelpString = GetHelpTextForTech(eCurrentTech);
			Controls.ActiveStyle:SetToolTipString( customHelpString );
			Controls.BigTechButton:SetToolTipString( customHelpString );
			-- if we have one, update the tech picture
			if IconHookup( pTechInfo.PortraitIndex, techPortraitSize, pTechInfo.IconAtlas, Controls.TechIcon ) then
				Controls.TechIcon:SetHide( false );
			else
				Controls.TechIcon:SetHide( true );
			end
			-- Update the little icons
			numButtonsAdded = AddSmallButtonsToTechButton( Controls, pTechInfo, maxSmallButtons, 64 );
			numButtonsAdded = math.max( 0, numButtonsAdded );
			AddCallbackToSmallButtons( Controls, maxSmallButtons, -1, -1, Mouse.eLClick, OpenTechTree );
			HideSmallIconBacking( Controls, maxSmallButtons, numButtonsAdded );
		end
	elseif (eRecentTech ~= -1) then -- maybe we just finished something
				
		local pTechInfo = GameInfo.Technologies[eRecentTech];
		if pTechInfo then
			szText = Locale.ConvertTextKey( "{" .. pTechInfo.Description .. ":upper}" );
			-- if we have one, update the tech picture
			if IconHookup( pTechInfo.PortraitIndex, techPortraitSize, pTechInfo.IconAtlas, Controls.TechIcon ) then
				Controls.TechIcon:SetHide( false );
			else
				Controls.TechIcon:SetHide( true );
			end
			-- Update the little icons
			numButtonsAdded = AddSmallButtonsToTechButton( Controls, pTechInfo, maxSmallButtons, 64 );
			numButtonsAdded = math.max( 0, numButtonsAdded );		
			HideSmallIconBacking( Controls, maxSmallButtons, numButtonsAdded );
			AddCallbackToSmallButtons( Controls, maxSmallButtons, -1, -1, Mouse.eLClick, OpenTechTree );
			
			
		end
		researchStatus = Locale.ConvertTextKey("TXT_KEY_RESEARCH_FINISHED");
		Controls.ActiveStyle:SetToolTipString( helpTT );
		Controls.BigTechButton:SetToolTipString( helpTT );
	else
		researchStatus = Locale.ConvertTextKey("TXT_KEY_NOTIFICATION_SUMMARY_NEW_RESEARCH");
		Controls.ActiveStyle:SetToolTipString( helpTT );
		Controls.BigTechButton:SetToolTipString( helpTT );
	end

	-- Tech Text
	Controls.TechText:SetText(researchStatus .. " " .. szText);
	Controls.FinishedTechText:SetText(researchStatus .. " " .. szText);
	ResizeTechPanel(numButtonsAdded);
end
Events.SerialEventGameDataDirty.Add(OnTechPanelUpdated);
	
	
-------------------------------------------------
-------------------------------------------------
function OnOpenInfoCorner( iInfoType )
    -- show if it's our id and we're not already visible
    if( iInfoType == InfoCornerID.Tech ) then
        ContextPtr:SetHide( false );
    else
        ContextPtr:SetHide( true );
    end
end
Events.OpenInfoCorner.Add( OnOpenInfoCorner );


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnPopup( popupInfo )	
    if( (popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_CHOOSETECH or popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_CHOOSE_TECH_TO_STEAL) and
        ContextPtr:IsHidden() == true ) then
        Events.OpenInfoCorner( InfoCornerID.Tech );
    end
end
Events.SerialEventGameMessagePopup.Add( OnPopup );

----------------------------------------------------------------
----------------------------------------------------------------
function UpdatePlayerData()
	local playerID = Game.GetActivePlayer();	
	local player = Players[playerID];
	local civType = GameInfo.Civilizations[player:GetCivilizationType()].Type;
	GatherInfoAboutUniqueStuff( civType );
end

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnTechPanelActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	UpdatePlayerData();    
	OnTechPanelUpdated();
end
Events.GameplaySetActivePlayer.Add(OnTechPanelActivePlayerChanged);

UpdatePlayerData();    
OnTechPanelUpdated();
