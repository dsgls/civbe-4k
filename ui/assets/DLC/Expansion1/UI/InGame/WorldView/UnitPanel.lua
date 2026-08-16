------------------------------------------------
-- Unit Panel Screen 
-------------------------------------------------
include( "IconSupport" );
include( "InstanceManager" );
include( "InfoTooltipInclude" );

local g_PrimaryIM    		= InstanceManager:new( "UnitAction",  "UnitActionButton", Controls.PrimaryStack );
local g_SecondaryIM  		= InstanceManager:new( "UnitAction",  "UnitActionButton", Controls.SecondaryStack );
local g_BuildIM      		= InstanceManager:new( "UnitAction",  "UnitActionButton", Controls.WorkerActionPanel );
local g_PromotionIM  		= InstanceManager:new( "UnitAction",  "UnitActionButton", Controls.WorkerActionPanel );
local g_EarnedPromotionIM   = InstanceManager:new( "EarnedPromotionInstance", "UnitPromotionImage", Controls.EarnedPromotionStack );

    
local g_CurrentActions			= {};		-- CurrentActions associated with each button
local g_lastUnitID				= -1;		-- Used to determine if a different unit has been selected.
local g_ActionButtons			= {};
local g_SecondaryOpen			= true;
local g_WorkerActionPanelOpen	= false;
local g_bFirstRealizeOnTurn		= true;		-- first time UI activated for this turn

local MaxDamage = GameDefines.MAX_HIT_POINTS;

local g_promotionsTexture	= "Promotions512.dds";

local actionIconSize		= 64;
local g_upgradePerksSize	= 56;

local g_positiveMessageTexture	= "PositiveMessageBackground.dds";
local g_positiveFontColor		= "[COLOR_FONT_GREEN]";
local g_attentionMessageTexture = "AttentionMessageBackground.dds";
local g_attentionFontColor		= "[COLOR_FONT_RED]";
local g_invisibleUnitFontColor	= "[COLOR_FONT_LIGHT_YELLOW]";
local g_spottedUnitFontColor	= "[COLOR_FONT_RED]";


--------------------------------------------------------------------------------
-- this maps from the normal instance names to the build city control names
-- so we can use the same code to set it up
--------------------------------------------------------------------------------
local g_BuildCityControlMap = { 
    UnitActionButton    = Controls.BuildCityButton,
	--UnitActionIcon		= Controls.BuildCityIcon
    --UnitActionMouseover = Controls.BuildCityMouseover,
    --UnitActionText      = Controls.BuildCityText,
    --UnitActionHotKey    = Controls.BuildCityHotKey,
    --UnitActionHelp      = Controls.BuildCityHelp,
};

local direction_types = {
	DirectionTypes.DIRECTION_NORTHEAST,
	DirectionTypes.DIRECTION_EAST,
	DirectionTypes.DIRECTION_SOUTHEAST,
	DirectionTypes.DIRECTION_SOUTHWEST,
	DirectionTypes.DIRECTION_WEST,
	DirectionTypes.DIRECTION_NORTHWEST
};


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GetActionIconIndexAndAtlas = {
	[ActionSubTypes.ACTIONSUBTYPE_PROMOTION] = function(action)
		local thisPromotion = GameInfo.UnitPromotions[action.CommandData];
		return thisPromotion.PortraitIndex, thisPromotion.IconAtlas;
	end,
	
	[ActionSubTypes.ACTIONSUBTYPE_INTERFACEMODE] = function(action)
		local info = GameInfo.InterfaceModes[action.Type];
		return info.IconIndex, info.IconAtlas;
	end,
	
	[ActionSubTypes.ACTIONSUBTYPE_MISSION] = function(action)
		local info = GameInfo.Missions[action.Type];
		return info.IconIndex, info.IconAtlas;
	end,
	
	[ActionSubTypes.ACTIONSUBTYPE_COMMAND] = function(action)
		local info = GameInfo.Commands[action.Type];
		return info.IconIndex, info.IconAtlas;
	end,
	
	[ActionSubTypes.ACTIONSUBTYPE_AUTOMATE] = function(action)
		local info = GameInfo.Automates[action.Type];
		return info.IconIndex, info.IconAtlas;
	end,
	
	[ActionSubTypes.ACTIONSUBTYPE_BUILD] = function(action)
		local info = GameInfo.Builds[action.Type];
		return info.IconIndex, info.IconAtlas;
	end,
	
	[ActionSubTypes.ACTIONSUBTYPE_CONTROL] = function(action)
		local info = GameInfo.Controls[action.Type];
		return info.IconIndex, info.IconAtlas;
	end,
};

function HookupActionIcon(action, actionIconSize, icon)

	local f = GetActionIconIndexAndAtlas[action.SubType];
	if(f ~= nil) then
		local iconIndex, iconAtlas = f(action);
		IconHookup(iconIndex, actionIconSize, iconAtlas, icon);
	else
		print(action.Type);
		print(action.SubType);
		error("Could not find method to obtain action icon.");
	end
end
--------------------------------------------------------------------------------
-- Refresh unit actions
--------------------------------------------------------------------------------
function UpdateUnitActions( unit : table )

	local bWasWorkerPanelOpen = g_WorkerActionPanelOpen;

    g_PrimaryIM:ResetInstances();
    g_SecondaryIM:ResetInstances();
    g_BuildIM:ResetInstances();
    g_PromotionIM:ResetInstances();
    Controls.BuildCityButton:SetHide( true );
    Controls.BuildPanel:SetHide(true);
	Controls.BuildHeader:SetHide(true);

    local pActivePlayer = Players[Game.GetActivePlayer()];
	local pPlot = unit:GetPlot();
    
    local bShowActionButton;
    local bUnitHasMovesLeft = unit:MovesLeft() > 0;
	local bUnitIsAutomated = unit:IsAutomated();
    
    local hasPromotion 	= false;
	local bBuild 		= false;
	local bPromotion 	= false;
	local iBuildID;

  --  Controls.BackgroundCivFrame:SetHide( false );
   
	local numBuildActions 		= 0;
	local numPromotions 		= 0;
	local numPrimaryActions 	= 0;
	local numSecondaryActions 	= 0;
	
	local numberOfButtonsPerRow = 8;
	local buttonSize 			= 55;
	local buttonPadding 		= 8;
	local buttonOffsetX 		= 16;
	local buttonOffsetY 		= 40;
	local workerPanelSizeOffsetY= 104;

    local buildCityButtonActive = false;
   
       -- loop over all the game actions
    for iAction = 0, #GameInfoActions, 1 do
        local action = GameInfoActions[iAction];
        
		-- test CanHandleAction w/ visible flag (ie COULD train if ... )
		if(action.Visible and Game.CanHandleAction( iAction, 0, 1 ) ) then
           	if( action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION ) then
				hasPromotion = true;
				break;          
			end
		end
    end

	-- Get the current build action
	local iCurrentBuildID = unit:GetBuildType();

    -- loop over all the game actions
    for iAction = 0, #GameInfoActions, 1 
    do
        local action 	= GameInfoActions[iAction];        
        local bBuild 	= false;
        local bPromotion= false;
        
		local void1 : number = iAction;
		local void2 : number = -1;
        
        -- We hide the Action buttons when Units are out of moves or is automated so new players aren't confused
        if ((bUnitHasMovesLeft and not bUnitIsAutomated) or action.Type == "COMMAND_CANCEL" or action.Type == "COMMAND_STOP_AUTOMATION" or action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION) then
			bShowActionButton = true;

			-- Special case: don't show cancel actions that are just added to the queue if
			-- the game pops up with an advisor allowing the player to cancel.
			if ( action.Type == "COMMAND_CANCEL" ) then
				local advisorModal = ContextPtr:LookUpControl("/InGame/AdvisorModal");
				if (advisorModal ~= nil and not advisorModal:IsHidden() ) then
					bShowActionButton = false;
				end
			end

		else
			bShowActionButton = false;
        end

		-- test CanHandleAction w/ visible flag (ie COULD train if ... )
		if( bShowActionButton and action.Visible and Game.CanHandleAction( iAction, 0, 1 ) ) 
		then
			local instance;
			local extraXOffset = 0;

			if (UI.IsTouchScreenEnabled()) then
				extraXOffset = 44;
			end

			if( action.Type == "MISSION_FOUND" ) then
				instance = g_BuildCityControlMap;
				Controls.BuildCityButton:SetHide( false );
				buildCityButtonActive = true;
                
			elseif( action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION ) then
				bPromotion = true;
				instance = g_PromotionIM:GetInstance();
				numBuildActions = numBuildActions + 1;
                
			elseif( (action.SubType == ActionSubTypes.ACTIONSUBTYPE_BUILD or action.Type == "INTERFACEMODE_ROUTE_TO") and hasPromotion == false) then
				bBuild = true;
				iBuildID = action.MissionData;
				local pBuild = GameInfo.Builds[iBuildID];
				local bShowThisBuild = true;
				
				if (pBuild ~= nil) then				
					if (pBuild.HiddenUntilUnlocked == true and pActivePlayer:IsActionUnlocked(iAction) ~= true) then
						bShowThisBuild = false;
					end
				end

				if (bShowThisBuild) then
					instance = g_BuildIM:GetInstance();
					numBuildActions = numBuildActions + 1;
				end
	           
			elseif( action.OrderPriority > 100 ) then
				instance = g_PrimaryIM:GetInstance();
				numPrimaryActions = numPrimaryActions + 1;
                
			else
				instance = g_SecondaryIM:GetInstance();
				numSecondaryActions = numSecondaryActions + 1;
			end
            
			-- test w/o visible flag (ie can train right now)
			if (instance ~= nil) then

				local isValid = Game.CanHandleAction( iAction );

				if not isValid then
					--bDisabled = true;
					instance.UnitActionButton:SetAlpha( 0.8 );   
					--instance.UnitActionIcon:SetColor( 0xF9707070 ); 
					instance.UnitActionButton:SetDisabled( true );                
				else
					instance.UnitActionButton:SetAlpha( 1.0 );
					--instance.UnitActionIcon:SetColor( 0xFFFFFFFF );             
					instance.UnitActionButton:SetDisabled( false );                
				end
			
				if(instance.UnitActionIcon ~= nil) then
					HookupActionIcon(action, actionIconSize, instance.UnitActionIcon);
				end
				instance.UnitActionButton:RegisterCallback( Mouse.eLClick, OnUnitActionClicked );
				instance.UnitActionButton:SetVoid1( void1 );
				instance.UnitActionButton:SetVoid2( void2 );
				instance.UnitActionButton:SetToolTipCallback( TipHandler )
           end
		end
	end

	-- Add any Deploy Passive actions
	if (bUnitHasMovesLeft and not bUnitIsAutomated) then
		local unitInfo : table = GameInfo.Units[unit:GetUnitType()];
		for row in GameInfo.Unit_PassiveAbilities{ UnitType = unitInfo.Type } do
			local passiveAbility = GameInfo.UnitPassiveAbilities[row.UnitPassiveAbilityType];
			if (passiveAbility.Deploy) then
				if (unit:CanDeployPassiveAbility(passiveAbility.ID)) then
					local instance = g_PrimaryIM:GetInstance();
					numSecondaryActions = numSecondaryActions + 1;
					IconHookup(passiveAbility.IconIndex, actionIconSize, passiveAbility.IconAtlas, instance.UnitActionIcon);
					instance.UnitActionButton:RegisterCallback(Mouse.eLClick, OnDeployPassiveAbilityClicked);
					instance.UnitActionButton:SetVoid1(passiveAbility.ID);
					instance.UnitActionButton:SetToolTipCallback(PassiveAbilityTipHandler);
					if (unit:CanDeployPassiveAbilityNow(passiveAbility.ID)) then
						instance.UnitActionButton:SetDisabled(false);
					else
						instance.UnitActionButton:SetDisabled(true);
					end
				end
			end
		end
	end

	-- Add any Landmark Actions for improvements this unit may be standing on
	if (not unit:IsInOrbit()) then
		local eImprovement = pPlot:GetImprovementType();
		if (eImprovement ~= nil and eImprovement ~= -1) then
			for landmarkAction in GameInfo.LandmarkActions() do
				if (pActivePlayer:CanHandleLandmarkAction(landmarkAction.ID, pPlot)) then
					local landmarkActionDesc = landmarkAction.Description;

					local instance = g_SecondaryIM:GetInstance();
					numSecondaryActions = numSecondaryActions + 1;

					local iconIndex = landmarkAction.IconIndex;
					local iconAtlas = landmarkAction.IconAtlas;

					IconHookup(iconIndex, actionIconSize, iconAtlas, instance.UnitActionIcon);
					instance.UnitActionButton:RegisterCallback(Mouse.eLClick, OnLandmarkActionClicked);
					instance.UnitActionButton:SetVoid1(landmarkAction.ID);
					instance.UnitActionButton:SetToolTipCallback( LandmarkActionTipHandler )
					instance.UnitActionButton:SetDisabled( false );
				end
			end
		end
	end
    
    Controls.PrimaryStack:CalculateSize();
    Controls.PrimaryStack:ReprocessAnchoring();
    
    local stackSize = Controls.PrimaryStack:GetSize();
    local buildCityButtonSize = 0;
    if buildCityButtonActive then
		buildCityButtonSize = 60;
		
    end

	Controls.PrimaryStack:SetHide( numPrimaryActions == 0 );
	Controls.SecondaryStack:SetHide( numSecondaryActions == 0 );
    
    Controls.SecondaryStack:CalculateSize();
    Controls.SecondaryStack:ReprocessAnchoring();
    
    stackSize = Controls.SecondaryStack:GetSize();

    if numBuildActions > 0 or hasPromotion then
		Controls.BuildPanel:SetHide( false );
		Controls.BuildHeader:SetHide( false );
		g_WorkerActionPanelOpen = true;
		stackSize = Controls.WorkerActionPanel:GetSize();
		local rbOffset = 0;

		Controls.RecommendedActionButton:SetHide( true );

		-- If this is a promotion, change text to "Pick a bonus".
		-- otherwise, use standard worker text.
		local buildLabelKey = "{TXT_KEY_WORKERACTION_TEXT : upper}";
		if hasPromotion then
			buildLabelKey = "TXT_KEY_UPANEL_UNIT_PROMOTED";
		end

		Controls.BuildLabel:LocalizeAndSetText(buildLabelKey);
    else
		Controls.BuildPanel:SetHide( true );
		Controls.BuildHeader:SetHide( true );
		g_WorkerActionPanelOpen = false;
    end
    
    local buildType = unit:GetBuildType();
    if (buildType ~= -1) then -- this is a worker who is actively building something
		local thisBuild = GameInfo.Builds[buildType];
		--print("thisBuild.Type:"..tostring(thisBuild.Type));
		local civilianUnitStr = Locale.ConvertTextKey(thisBuild.Description);
		local civilianUnitTT;
		local iTurnsLeft = unit:GetPlot():GetBuildTurnsLeft(buildType, Game.GetActivePlayer(),  0, 0) + 1;	
		local iTurnsTotal = unit:GetPlot():GetBuildTurnsTotal(buildType);	
		if (iTurnsLeft < 4000 and iTurnsLeft > 0) then
			local turnsTxt = Locale.ConvertTextKey("TXT_KEY_DIPLO_TURNS", iTurnsLeft);
			civilianUnitTT = civilianUnitStr .." (" .. turnsTxt .. ")";
			civilianUnitStr = civilianUnitStr.." ("..tostring(iTurnsLeft)..")";
		end
		IconHookup( thisBuild.IconIndex, 45, thisBuild.IconAtlas, Controls.WorkerProgressIcon ); 		
		Controls.WorkerProgressLabel:SetText( civilianUnitStr );
		Controls.WorkerProgressLabel:SetToolTipString(civilianUnitTT);
		local percent = (iTurnsTotal - (iTurnsLeft - 1)) / iTurnsTotal;
		Controls.WorkerProgressBar:SetPercent( percent );
		Controls.WorkerProgressIconFrame:SetHide( false );
		Controls.WorkerProgressFrame:SetHide( false );
		Controls.WorkerProgressLabel:SetHide( false );

		--hide the build icon if it's an expedition (so as not to overlap the combat strength icon of the explorer)
		local expeditionBuild = GameInfo.Builds["BUILD_EXPEDITION"];
		if ( expeditionBuild and expeditionBuild.ID == thisBuild.ID ) then
			Controls.WorkerProgressIconFrame:SetHide( true );
			Controls.WorkerProgressFrame:SetHide( true );
			Controls.WorkerProgressLabel:SetHide( false );
		end
		
	else
		Controls.WorkerProgressIconFrame:SetHide( true );
		Controls.WorkerProgressFrame:SetHide( true );
		Controls.WorkerProgressLabel:SetHide( true );
	end
    
	Controls.WorkerActionPanel:CalculateSize();
	Controls.WorkerActionPanel:ReprocessAnchoring();
	local width,height = Controls.WorkerActionPanel:GetSizeVal();
	local lwidth,lheight = 0,0; --TRON Controls.WorkerText:GetSizeVal();
	Controls.BuildPanel:SetSizeVal(math.max(width+1,(Controls.BuildLabel:GetSizeX())+10),height+lheight+10);
	Controls.BuildPanel:ReprocessAnchoring();
	Controls.BuildHeader:SetSizeX(math.max(width+1,(Controls.BuildLabel:GetSizeX())+10));
	Controls.BuildHeader:ReprocessAnchoring();
	
    Controls.ContainerStack:CalculateSize();
    Controls.ContainerStack:ReprocessAnchoring();

	-- Slide open/close worker panel if in a different state
	if not g_WorkerActionPanelOpen == bWasWorkerPanelOpen or (g_bFirstRealizeOnTurn == true) then
		local workerBarOffset = 0;
		if (numBuildActions > 0) then
			local workerBarLevels =  math.floor((numBuildActions - 1) / numberOfButtonsPerRow);
			workerBarOffset = workerBarLevels * buttonSize;
		end
		RealizeActionBars(workerBarOffset);
		g_bFirstRealizeOnTurn = false;
	end

	local numActions = numSecondaryActions + numPrimaryActions;
	local panelAdjust = 0;
	if (numActions > 8) then
		panelAdjust = numActions - 8;
	end
	Controls.HealthBar:SetOffsetX(432 + (55*panelAdjust));
	Controls.UnitPanelBackground:SetSizeX(492 + (55*panelAdjust));
end

--------------------------------------------------------------------------------
-- Refresh improvement actions
--------------------------------------------------------------------------------
function UpdateImprovementActions (improvementInfo, improvementPlot)

	g_PrimaryIM:ResetInstances();
    g_SecondaryIM:ResetInstances();
    g_BuildIM:ResetInstances();
    g_PromotionIM:ResetInstances();
    Controls.BuildCityButton:SetHide(true);
    Controls.BuildPanel:SetHide(true);
	Controls.BuildHeader:SetHide(true);

	Controls.SecondaryStack:SetHide(true);

    local pActivePlayer = Players[Game.GetActivePlayer()];
	local numActions = 0;

	    -- loop over all the game actions
    for landmarkAction in GameInfo.LandmarkActions() do
		
		-- Test with visible flag
		if (pActivePlayer:CanHandleLandmarkAction(landmarkAction.ID, improvementPlot, true)) then

			local landmarkActionDesc = landmarkAction.Description;

			local instance = g_PrimaryIM:GetInstance();
			local iconIndex = landmarkAction.IconIndex;
			local iconAtlas = landmarkAction.IconAtlas;

			IconHookup(iconIndex, actionIconSize, iconAtlas, instance.UnitActionIcon);
			instance.UnitActionButton:RegisterCallback(Mouse.eLClick, OnLandmarkActionClicked);
			instance.UnitActionButton:SetVoid1(landmarkAction.ID);
			instance.UnitActionButton:SetVoid2(improvementPlot:GetPlotIndex());
			instance.UnitActionButton:SetToolTipCallback( LandmarkActionTipHandler )
			instance.UnitActionButton:SetDisabled( false );

			-- test w/o visible flag (ie can do right now)
			if (instance ~= nil) then
				if (not pActivePlayer:CanHandleLandmarkAction(landmarkAction.ID, improvementPlot, false)) then
					instance.UnitActionButton:SetAlpha( 0.8 );   
					instance.UnitActionButton:SetDisabled( true );                
				else
					instance.UnitActionButton:SetAlpha( 1.0 );
					instance.UnitActionButton:SetDisabled( false );                
				end
           end

			numActions = numActions + 1;
		end
	end

	if (numActions > 0) then
		Controls.PrimaryStack:CalculateSize();
		Controls.PrimaryStack:ReprocessAnchoring();
		Controls.PrimaryStack:SetHide(false);

		Controls.ContainerStack:CalculateSize();
		Controls.ContainerStack:ReprocessAnchoring();
	else
		Controls.PrimaryStack:SetHide(true);
	end
end

function RealizeActionBars(offset)
	--if g_WorkerActionPanelOpen then
		--Controls.AllActions:SetOffsetVal( 0, 0 );
	--else
		--Controls.AllActions:SetOffsetVal( 0, -55 );
	--end	
	Controls.ActionRowSlider:SetToBeginning();
	Controls.ActionRowSlider:Play();
end


local defaultErrorTextureSheet = "TechAtlasSmall.dds";
local nullOffset = Vector2( 0, 0 );

--------------------------------------------------------------------------------
-- Refresh unit portrait and name
--------------------------------------------------------------------------------
function UpdateUnitPortrait( unit : table )
  
	local name;
	if(unit:IsGreatPerson()) then
		name = unit:GetNameNoDesc();
		if(name == nil or #name == 0) then
			name = unit:GetName();			
		end
	else
		name = unit:GetName();
	end
	
	name = Locale.ToUpper(name);
  
    --local name = unit:GetNameKey();
    local convertedKey = Locale.ConvertTextKey(name);
    convertedKey = Locale.ToUpper(convertedKey);

	Controls.UnitName:SetFontSize( 48 );
	TruncateString(Controls.UnitName, 520, convertedKey);

	-- Help text
	local unitInfo = GameInfo.Units[unit:GetUnitType()];
	local helpText = "";
	if (unitInfo.Help ~= nil) then
		helpText = Locale.ConvertTextKey(unitInfo.Help);
	end
	local effectsText = GetHelpTextForSpecificUnit(unit);
	if (effectsText ~= "") then
		helpText = helpText .. "[NEWLINE][NEWLINE]" .. effectsText;
	end
	Controls.UnitName:SetToolTipString(helpText)
	Controls.RenderedUnitPortrait:SetToolTipString(helpText);
	Controls.ImageUnitPortrait:SetHide(true);
    
    local name_length = Controls.UnitName:GetSizeVal();
    local box_length = Controls.UnitNameButton:GetSizeVal();
    
    if (name_length > (box_length - 50)) then
		Controls.UnitName:SetFontSize( 40 );
	end
	
	name_length = Controls.UnitName:GetSizeVal();
	
	if(name_length > (box_length - 50)) then
		Controls.UnitName:SetFontSize( 28 );
	end
    
    -- Tool tip
    local strToolTip = Locale.ConvertTextKey("TXT_KEY_CURRENTLY_SELECTED_UNIT");
    if (unit:CanEarnExperience()) then

		local iExperience = unit:GetExperience();
		local iLevel = unit:GetLevel();
		local iPercent = 0;
		local sTooltip = "";

		if (unit:CanAcquireNextLevel()) then
			local iExperienceNeeded = unit:ExperienceNeeded();
			iPercent = iExperience / iExperienceNeeded;
			sTooltip = Locale.ConvertTextKey("TXT_KEY_UNIT_EXPERIENCE_INFO", iLevel, iExperience, iExperienceNeeded);
		else
			iPercent = 1.0;
			sTooltip = Locale.ConvertTextKey("TXT_KEY_UNIT_EXPERIENCE_INFO_MAX_LEVEL", iLevel, iExperience);
		end

		Controls.XPMeter:SetPercent( math.min(iPercent, 1.0) );
		Controls.XPMeter:SetToolTipString( sTooltip );
			
		if (iExperience > 0) then
			strToolTip = strToolTip .. "[NEWLINE][NEWLINE]" .. sTooltip;
		end
		Controls.XPFrame:SetHide( false );
	else
 		Controls.XPFrame:SetHide( true );
   end
	
-- Before render teture: 	Controls.UnitPortrait:SetToolTipString(strToolTip);
    
    local thisUnitInfo = GameInfo.Units[unit:GetUnitType()];

	local flagOffset, flagAtlas, flagHeightOffset = UI.GetUnitFlagIcon(unit);	    
    local textureOffset, textureAtlas = IconLookup( flagOffset, 32, flagAtlas );
    --[[ Unit flag support?
	Controls.UnitIcon:SetTexture(textureAtlas);
    Controls.UnitIconShadow:SetTexture(textureAtlas);
    Controls.UnitIcon:SetTextureOffset(textureOffset);
    Controls.UnitIconShadow:SetTextureOffset(textureOffset);
    
    local pPlayer = Players[ unit:GetOwner() ];
    if (pPlayer ~= nil) then
		local iconColor, flagColor = pPlayer:GetPlayerColors();
	        
		if( pPlayer:IsMinorCiv() ) then
			flagColor, iconColor = flagColor, iconColor;
		end

		Controls.UnitIcon:SetColor( iconColor );
		Controls.UnitIconBackground:SetColor( flagColor );
	end    
	]]
--[[ Unit Portraits, before using render texture    
	local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(unit);
    textureOffset, textureAtlas = IconLookup( portraitOffset, unitPortraitSize, portraitAtlas );
    if textureOffset == nil then
		textureOffset = nullOffset;
		textureAtlas = defaultErrorTextureSheet;
    end

    Controls.UnitPortrait:SetTexture(textureAtlas);
	Controls.UnitPortrait:SetTextureOffset(textureOffset);

    --These controls are potentially hidden if the previous selection was a city.
	Controls.UnitTypeFrame:SetHide(false);
]]    
	Controls.CycleLeft				:SetHide( false );
	Controls.CycleRight				:SetHide( false );
    Controls.UnitMovementBox		:SetHide( false );
	Controls.RenderedUnitPortrait	:SetHide( false );
	Controls.ImageUnitPortrait		:SetHide( true );
  
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function UpdateCityPortrait(city : table)
    local name = city:GetName();
    name = Locale.ToUpper(name);
    --local name = unit:GetNameKey();
    local convertedKey = Locale.ConvertTextKey(name);
    convertedKey = Locale.ToUpper(convertedKey);

    Controls.UnitName:SetText(convertedKey);    
	Controls.UnitName:SetFontSize( 48 );   
    
    local name_length = Controls.UnitName:GetSizeVal();
    local box_length = Controls.UnitNameButton:GetSizeVal();
    
    if (name_length > (box_length - 50)) then
		Controls.UnitName:SetFontSize( 40 );   
	end
	
	name_length = Controls.UnitName:GetSizeVal();
	
	if(name_length > (box_length - 50)) then
		Controls.UnitName:SetFontSize( 28 );   
	end

    --Hide various aspects of Unit Panel since they don't apply to the city.
    --Clear promotions
    g_EarnedPromotionIM:ResetInstances();
    
    --Controls.UnitTypeFrame:SetHide(true);
    Controls.CycleLeft				:SetHide( true );
    Controls.CycleRight				:SetHide( true );
    Controls.XPFrame				:SetHide( true );
    Controls.UnitMovementBox		:SetHide( true );
    Controls.UnitStrengthBox		:SetHide( true );
    Controls.UnitRangedStrengthBox	:SetHide( true );
	Controls.UnitStatusBox			:SetHide( true );
    Controls.BuildPanel				:SetHide( true );
	Controls.BuildHeader			:SetHide( true );
	Controls.PrimaryStack			:SetHide( true );
	Controls.SecondaryStack			:SetHide( true );
	Controls.WorkerProgressIconFrame:SetHide( true );
	Controls.WorkerProgressFrame	:SetHide( true );
	Controls.WorkerProgressLabel	:SetHide( true );
	Controls.RenderedUnitPortrait	:SetHide( true );
	Controls.ImageUnitPortrait		:SetHide( true );

	g_WorkerActionPanelOpen = false;
	g_SecondaryOpen			= false;

	UpdateUnitHealthBar( city );

end


--------------------------------------------------------------------------------
--	Not a Unit, maybe it's an Improvement
--------------------------------------------------------------------------------
function UpdateImprovementPortrait( improvementDBRow : table )
    
	local id			= improvementDBRow.ID;
	local type			= improvementDBRow.Type;
	local description	= improvementDBRow.Description;
	local civilopedia	= improvementDBRow.Civilopedia;
	local artDefineTag  = improvementDBRow.ArtDefineTag;
	local portraitIndex = improvementDBRow.PortraitIndex;
	local iconAtlas		= improvementDBRow.IconAtlas;

    name				= Locale.ToUpper(description);
    local convertedKey	= Locale.ConvertTextKey(name);
    convertedKey		= Locale.ToUpper(convertedKey);

    Controls.UnitName:SetText( convertedKey );
	if (improvementDBRow.Help ~= nil) then
		Controls.UnitName:SetToolTipString( Locale.ConvertTextKey(improvementDBRow.Help) );
	else
		Controls.UnitName:SetToolTipType( nil );	-- no tooltip
	end
	Controls.UnitName:SetFontSize( 48 );
    
	-- Shrink font down if name is too big at current size.

    local name_length	= Controls.UnitName:GetSizeVal();
    local box_length	= Controls.UnitNameButton:GetSizeVal();
    
    if (name_length > (box_length - 50)) then
		Controls.UnitName:SetFontSize( 40 );
	end
	
	name_length = Controls.UnitName:GetSizeVal();
	
	if(name_length > (box_length - 50)) then
		Controls.UnitName:SetFontSize( 28 );
	end  

    -- Hide various aspects of Unit Panel since they don't apply to improvements.

    g_EarnedPromotionIM:ResetInstances();
    
    Controls.CycleLeft				:SetHide( true );
    Controls.CycleRight				:SetHide( true );
    Controls.XPFrame				:SetHide( true );
    Controls.UnitMovementBox		:SetHide( true );
    Controls.UnitStrengthBox		:SetHide( true );
    Controls.UnitRangedStrengthBox	:SetHide( true );
	Controls.UnitStatusBox			:SetHide( true );
    Controls.BuildPanel				:SetHide( true );
	Controls.BuildHeader			:SetHide( true );
	Controls.PrimaryStack			:SetHide( true );
	Controls.SecondaryStack			:SetHide( true );
	Controls.WorkerProgressIconFrame:SetHide( true );
	Controls.WorkerProgressFrame	:SetHide( true );
	Controls.WorkerProgressLabel	:SetHide( true );
	Controls.HealthBar				:SetHide( true );
	Controls.RenderedUnitPortrait	:SetHide( true );

	if (improvementDBRow.PreviewIconAtlas ~= nil and improvementDBRow.PreviewIconAtlasIndex ~= -1) then
		Controls.ImageUnitPortrait:SetHide(false);
		IconHookup(improvementDBRow.PreviewIconAtlasIndex, 128, improvementDBRow.PreviewIconAtlas, Controls.ImageUnitPortrait);
	else
		Controls.ImageUnitPortrait:SetHide(true);
	end

	g_WorkerActionPanelOpen	= false;
	g_SecondaryOpen			= false;
end


--------------------------------------------------------------------------------
-- Refresh unit promotions
--------------------------------------------------------------------------------
function UpdateUnitPromotions(unit : table)
    
    g_EarnedPromotionIM:ResetInstances();
    local controlTable;
    
    --For each avail promotion, display the icon
    for unitPromotion in GameInfo.UnitPromotions() do
        local unitPromotionID = unitPromotion.ID;
        
        if (unit:IsHasPromotion(unitPromotionID) and not unit:IsTrade()) then
            
            controlTable = g_EarnedPromotionIM:GetInstance();
			IconHookup( unitPromotion.PortraitIndex, 32, unitPromotion.IconAtlas, controlTable.UnitPromotionImage );

            -- Tooltip
            local strToolTip = Locale.ConvertTextKey(unitPromotion.Description);
            strToolTip = strToolTip .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey(unitPromotion.Help)
            controlTable.UnitPromotionImage:SetToolTipString(strToolTip);
            
        end
    end
end

---------------------------------------------------
---- Promotion Help
---------------------------------------------------
--function PromotionHelpOpen(iPromotionID)
    --local pPromotionInfo = GameInfo.UnitPromotions[iPromotionID];
    --local promotionHelp = Locale.ConvertTextKey(pPromotionInfo.Description);
    --Controls.HelpText:SetText(promotionHelp);
--end

--------------------------------------------------------------------------------
-- Refresh unit stats
--------------------------------------------------------------------------------
function UpdateUnitStats(unit : table)
    
    -- update the background image (update this if we get icons for the minors)
    local civType = unit:GetCivilizationType();
	local civInfo = GameInfo.Civilizations[civType];
	local civPortraitIndex = civInfo.PortraitIndex;
    if civPortraitIndex < 0 or civPortraitIndex > 21 then
        civPortraitIndex = 22;
    end
    
    --IconHookup( civPortraitIndex, 128, civInfo.IconAtlas, Controls.BackgroundCivSymbol );
       
    -- Movement
	local szStatus = nil;
	local statusColor = nil;
	local statusTexture = nil;
	local bUnitHasMovesLeft = unit:MovesLeft() > 0;
	if (not bUnitHasMovesLeft and not unit:IsTrade()) then
		szStatus = Locale.ConvertTextKey("TXT_KEY_UPANEL_UNIT_NO_MOVES");
		statusColor = g_attentionFontColor;
		statusTexture = g_attentionMessageTexture;
	end
	local szMoveStat = nil;
	local szMoveTooltip = nil;
	if unit:GetDomainType() == DomainTypes.DOMAIN_AIR then
		local iRange = unit:Range();
		szMoveStat = iRange .. " [ICON_MOVES]";	    
		local rebaseRange = iRange * GameDefines.AIR_UNIT_REBASE_RANGE_MULTIPLIER;
		rebaseRange = rebaseRange / 100;
		szMoveTooltip = Locale.ConvertTextKey( "TXT_KEY_UPANEL_UNIT_MAY_STRIKE_REBASE", iRange, rebaseRange );
	elseif unit:IsInOrbit() then
		-- Units in orbit cannot move, so show their remaining duration instead
		local totalTurns = unit:GetTurnsAllowedInOrbit();
		local elapsedTurns = unit:GetTurnsInOrbit();
		local remainingTurns = totalTurns - elapsedTurns;
		szMoveStat = elapsedTurns .. "/" .. totalTurns .. " [ICON_ORBITAL_DURATION]";
		szMoveTooltip = Locale.ConvertTextKey("TXT_KEY_UPANEL_UNIT_ORBITAL_DURATION_TT", totalTurns, remainingTurns);
	elseif unit:IsImmobile() then
		if unit:IsOrbitalUnit() and unit:CanLaunchIntoOrbit() then
			szStatus = Locale.ConvertTextKey("{TXT_KEY_UPANEL_UNIT_IMMOBILE_ORBITAL:upper}");
			statusColor = g_positiveFontColor;
			statusTexture = g_positiveMessageTexture;
		elseif unit:IsTrade() then
			--Show nothing since "READY TO TRADE" is very misleading.
			--if unit:CanMakeTradeRoute(unit:GetPlot()) then
				--szStatus = Locale.ConvertTextKey("{TXT_KEY_UPANEL_UNIT_IMMOBILE_TRADE:upper}");
				--statusColor = g_positiveFontColor;
				--statusTexture = g_positiveMessageTexture;
			--end
		else
			szStatus = Locale.ConvertTextKey("{TXT_KEY_UPANEL_UNIT_IMMOBILE:upper}");
			statusColor = g_attentionFontColor;
			statusTexture = g_attentionMessageTexture;
		end
    else
		local move_denominator = GameDefines["MOVE_DENOMINATOR"];
		local moves_left = unit:MovesLeft() / move_denominator;
		local max_moves = unit:MaxMoves() / move_denominator;
		szMoveStat = math.floor(moves_left) .. "/" .. math.floor(max_moves) .. " [ICON_MOVES]";
		szMoveTooltip = Locale.ConvertTextKey( "TXT_KEY_UPANEL_UNIT_MAY_MOVE", moves_left );
    end

	if (szMoveStat ~= nil) then
		Controls.UnitStatMovement:SetHide(false);
		Controls.UnitStatMovement:SetText(szMoveStat);
		if (szMoveTooltip ~= nil) then
			Controls.UnitStatMovement:SetToolTipString(szMoveTooltip);
		end
	else
		Controls.UnitStatMovement:SetHide(true);
		Controls.UnitStatMovement:SetText("");
		Controls.UnitStatMovement:SetToolTipString("");
	end

	if (szStatus ~= nil) then
		Controls.UnitStatusInfoImage:SetHide(false);
		if (statusColor ~= nil) then
			szStatus = statusColor .. szStatus .. "[ENDCOLOR]";
		end
		if (statusTexture ~= nil) then
			Controls.UnitStatusInfoImage:SetTexture(statusTexture);
		end
		Controls.UnitStatusInfo:SetText(szStatus);
	else
		Controls.UnitStatusInfoImage:SetHide(true);
		Controls.UnitStatusInfo:SetText("");
	end
    
    -- Strength
    local strength = 0;
    if(unit:GetDomainType() == DomainTypes.DOMAIN_AIR) then
        strength = unit:GetRangedCombatStrength();
    else
        strength = unit:GetCombatStrength();
    end
    if(strength > 0) then
        strength = strength .. " [ICON_STRENGTH]";
        Controls.UnitStrengthBox:SetHide(false);
        Controls.UnitStatStrength:SetText(strength);
        local strengthTT = Locale.ConvertTextKey( "TXT_KEY_UPANEL_STRENGTH_TT" );
        Controls.UnitStatStrength:SetToolTipString(strengthTT);
    else
        Controls.UnitStrengthBox:SetHide(true);
        Controls.UnitStatStrength:SetText("");
        Controls.UnitStatStrength:SetToolTipString("");
    end        
    
    -- Ranged Strength
    local unitInfo = GameInfo.Units[unit:GetUnitType()];
    local iRangedStrength = 0;	
    if(unit:IsRanged() and unit:GetDomainType() ~= DomainTypes.DOMAIN_AIR) then
        iRangedStrength = unit:GetRangedCombatStrength();
    else
        iRangedStrength = 0;
    end
    if(iRangedStrength > 0) then
		iRangedStrength = iRangedStrength .. " [ICON_RANGE_STRENGTH]";
        Controls.UnitRangedStrengthBox:SetHide(false);
        Controls.UnitStatRangedStrength:SetText(iRangedStrength);
        local strengthTT = Locale.ConvertTextKey( "TXT_KEY_UPANEL_STRENGTH_TT" );
        --Controls.UnitStatRangedStrength:SetToolTipString(strengthTT);
	else
		Controls.UnitRangedStrengthBox:SetHide(true);
		Controls.UnitStatRangedStrength:SetText("");
		--Controls.UnitStatRangedStrength:SetToolTipString("");
	end

	-- Explorer Expeditions
	local isExpeditionCapable = (unitInfo.NumExpeditionCharges > 0); -- Does our unit type have any expedition charges built in?
    if (unitInfo ~= nil and isExpeditionCapable) then
		Controls.UnitStatusBox:SetHide(false);
		local expeditionString = "";
		if (unit:GetNumExpeditionCharges() < 1) then
			expeditionString = g_attentionFontColor;
		else
			expeditionString = "[COLOR_WHITE]";
		end
		expeditionString = expeditionString .. Locale.ConvertTextKey("TXT_KEY_UPANEL_EXPEDITION_CHARGES") .. ":" .. " " .. unit:GetNumExpeditionCharges().."[ENDCOLOR]";
        Controls.UnitStatusLabel:SetText(expeditionString);
        local tooltip = Locale.ConvertTextKey("TXT_KEY_UPANEL_EXPEDITION_CHARGES_TT");
        Controls.UnitStatusLabel:SetToolTipString(tooltip);

	-- Invisibility
	elseif (unitInfo ~= nil and unitInfo.Invisibility) then
		Controls.UnitStatusBox:SetHide(false);
		local abilityStr : string = "";
		local tooltip : string = "";
		if (unit:IsInvisibleToAllEnemyTeams()) then
			abilityStr = g_invisibleUnitFontColor..Locale.Lookup("TXT_KEY_UNITPANEL_INVISIBLE").."[ENDCOLOR]"
			tooltip = Locale.Lookup("TXT_KEY_UNITPANEL_INVISIBLE_TT");
		else
			abilityStr = g_spottedUnitFontColor..Locale.Lookup("TXT_KEY_UNITPANEL_REVEALED").."[ENDCOLOR]"
			tooltip = Locale.Lookup("TXT_KEY_UNITPANEL_REVEALED_TT");
		end

		Controls.UnitStatusLabel:SetText(abilityStr);
        Controls.UnitStatusLabel:SetToolTipString(tooltip);
	
	-- Alien Colossus
	elseif (unitInfo ~= nil and unitInfo.AlienColossus) then
		Controls.UnitStatusBox:SetHide(false);
		Controls.UnitStatusLabel:SetText( g_invisibleUnitFontColor..Locale.Lookup("TXT_KEY_UNITPANEL_COLOSSAL_ALIEN").."[ENDCOLOR]" );
        Controls.UnitStatusLabel:SetToolTipString( Locale.Lookup("TXT_KEY_UNITPANEL_COLOSSAL_ALIEN_TT") );

	else
		Controls.UnitStatusBox:SetHide(true);
		Controls.UnitStatusLabel:SetText("");
        Controls.UnitStatusLabel:SetToolTipString("");
	end

	Controls.StatStack:CalculateSize();
	Controls.StatStack:ReprocessAnchoring();
end

--------------------------------------------------------------------------------
-- Refresh unit health bar
--------------------------------------------------------------------------------
function UpdateUnitHealthBar(unit : table)
	-- note that this doesn't use the bar type
	local damage = unit:GetDamage();
	if damage == 0 then
		Controls.HealthBar:SetHide(true);	
	else	
		local healthPercent = 1.0 - (damage / MaxDamage);
		local healthTimes100 =  math.floor(100 * healthPercent + 0.5);
		local barSize = { x = 10, y = math.min(math.floor(115 * healthPercent),115) };
		if healthTimes100 <= 33 then
			Controls.RedBar:Resize(barSize.x,barSize.y);
			Controls.GreenBar:SetHide(true);
			Controls.YellowBar:SetHide(true);
			Controls.RedBar:SetHide(false);
		elseif healthTimes100 <= 66 then
			Controls.YellowBar:Resize(barSize.x,barSize.y);
			Controls.GreenBar:SetHide(true);
			Controls.YellowBar:SetHide(false);
			Controls.RedBar:SetHide(true);
		else
			Controls.GreenBar:Resize(barSize.x,barSize.y);
			Controls.GreenBar:SetHide(false);
			Controls.YellowBar:SetHide(true);
			Controls.RedBar:SetHide(true);
		end
		
		Controls.HealthBar:SetToolTipString( Locale.ConvertTextKey( "TXT_KEY_UPANEL_SET_HITPOINTS_TT",(MaxDamage-damage), MaxDamage ) );
		--Controls.HealthBar:SetToolTipString(healthPercent.." Hit Points");
		
		Controls.HealthBar:SetHide(false);
	end
end

--------------------------------------------------------------------------------
-- Refresh improvement status information (damage, health, other info)
--------------------------------------------------------------------------------
function UpdateImprovementStatus(improvementInfo : table, plot)

	if (plot == nil) then
		error("Could not retrieve plot for improvement");
	end
	
	local player = Players[plot:GetOwner()];
	local siteData = plot:GetPlotStrategicSiteData();

	-- note that this doesn't use the bar type
	if siteData.Damage == 0 then
		Controls.HealthBar:SetHide(true);	
	else	
		local healthPercent = 1.0 - (siteData.Damage / siteData.MaxHitPoints);
		local healthTimes100 =  math.floor(100 * healthPercent + 0.5);
		local barSize = { x = 10, y = math.floor(111 * healthPercent) };
		if healthTimes100 <= 33 then
			Controls.RedBar:Resize(barSize.x,barSize.y);
			Controls.GreenBar:SetHide(true);
			Controls.YellowBar:SetHide(true);
			Controls.RedBar:SetHide(false);
		elseif healthTimes100 <= 66 then
			Controls.YellowBar:Resize(barSize.x,barSize.y);
			Controls.GreenBar:SetHide(true);
			Controls.YellowBar:SetHide(false);
			Controls.RedBar:SetHide(true);
		else
			Controls.GreenBar:Resize(barSize.x,barSize.y);
			Controls.GreenBar:SetHide(false);
			Controls.YellowBar:SetHide(true);
			Controls.RedBar:SetHide(true);
		end
		
		Controls.HealthBar:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_UPANEL_SET_HITPOINTS_TT", (siteData.MaxHitPoints - siteData.Damage), siteData.MaxHitPoints));
		--Controls.HealthBar:SetToolTipString(healthPercent.." Hit Points");		
		Controls.HealthBar:SetHide(false);
	end

	-- Special info for planetary wonders
	local wonderStatusStr = nil;
	local wonderStatusToolTip = nil;
	
	if (improvementInfo.ID == GameInfo.Improvements["IMPROVEMENT_SUPREMACY_GATE"].ID) then
		local strengthCommitted = player:GetEmancipationCommittedStrength();
		local strengthNeeded = GameDefines["EMANCIPATION_VICTORY_STRENGTH_REQUIREMENT"];
		wonderStatusStr = Locale.ConvertTextKey("TXT_KEY_STATUS_SUPREMACY_GATE_STRENGTH", strengthCommitted, strengthNeeded);

	elseif (improvementInfo.ID == GameInfo.Improvements["IMPROVEMENT_PURITY_GATE"].ID) then
		local earthlingsSettled = player:GetNumEarthlingsSettled();
		local earthlingsNeeded = GameDefines["PROMISED_LAND_EARTHLINGS_SETTLED_REQUIREMENT"];
		wonderStatusStr = Locale.ConvertTextKey("TXT_KEY_STATUS_PURITY_GATE_EARTHLINGS_SETTLED", earthlingsSettled, earthlingsNeeded);

	elseif (improvementInfo.ID == GameInfo.Improvements["IMPROVEMENT_MIND_FLOWER"].ID) then
		local turnsRemaining = player:GetTranscendenceTurnsRemaining();
		wonderStatusStr = Locale.ConvertTextKey("TXT_KEY_STATUS_MIND_FLOWER_TURNS_LEFT", turnsRemaining);
	end

	-- TODO
	--if wonderStatusStr ~= nil then
		--Controls.UnitRangedAttackBox:SetHide(false);
		--Controls.UnitStatNameRangedAttack:SetText(Locale.ToUpper(wonderStatusStr));
		--
		--Controls.UnitStatRangedAttack:SetText("");
		--Controls.UnitStatRangedAttack:SetToolTipType( nil );
--
		--if wonderStatusToolTip ~= nil then			
			--Controls.UnitStatNameRangedAttack:SetOffsetY(1);
			--Controls.UnitStatNameRangedAttack:SetToolTipString(wonderStatusToolTip);
		--else
			--Controls.UnitStatNameRangedAttack:SetOffsetY(8);
			--Controls.UnitStatNameRangedAttack:SetToolTipType( nil );
		--end
	--else
		--Controls.UnitRangedAttackBox:SetHide(true);
	--end   

	Controls.StatStack:CalculateSize();
	Controls.StatStack:ReprocessAnchoring();
end


-- ===========================================================================
--	Display the unit perks (upgrades) for a given unit
--	unit	The unit to show, or nil to hide all
-- ===========================================================================
function UpdatePerkIcons(unit : table)

	Controls.UpgradePerkIcon1:SetHide( true );
	Controls.UpgradePerkIcon2:SetHide( true );
	Controls.UpgradePerkIcon3:SetHide( true );

	if ( unit ~= nil ) then
		local player	= Players[unit:GetOwner()];
		local unitType	= unit:GetUnitType();

		local perks = player:GetPerksForUnit( unitType );
		for i,perkId in ipairs(perks) do
			local buffEntryInstance = {};
			local perk = GameInfo.UnitPerks[perkId];
			local iconControl = Controls["UpgradePerkIcon"..tostring(i)];
			iconControl:SetHide( false );
			IconHookup( perk.PortraitIndex, g_upgradePerksSize, perk.IconAtlas, iconControl );

			local strToolTip = GetHelpTextForUnitPerk(perkId);
			iconControl:SetToolTipString(strToolTip);
		end
	end
end



--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CycleLeft clicked event handler
--------------------------------------------------------------------------------
function OnCycleLeftClicked()
    -- Cycle to next selection.
    Game.CycleUnits(true, true, false);
end
Controls.CycleLeft:RegisterCallback( Mouse.eLClick, OnCycleLeftClicked );


--------------------------------------------------------------------------------
-- CycleRight clicked event handler
--------------------------------------------------------------------------------
function OnCycleRightClicked()
    -- Cycle to previous selection.
    Game.CycleUnits(true, false, false);
end
Controls.CycleRight:RegisterCallback( Mouse.eLClick, OnCycleRightClicked );

--------------------------------------------------------------------------------
-- Unit Name clicked event handler
--------------------------------------------------------------------------------
function OnUnitNameClicked()
    -- go to this unit
    UI.LookAtSelectionPlot();
end
Controls.UnitNameButton:RegisterCallback( Mouse.eLClick, OnUnitNameClicked );

--------------------------------------------------------------------------------
-- Unit Portrait clicked event handler
--------------------------------------------------------------------------------
function OnUnitPortraitClicked()
	UI.LookAtSelectionPlot();
end
Controls.RenderedUnitPortrait:RegisterCallback( Mouse.eLClick, OnUnitPortraitClicked );
Controls.ImageUnitPortrait:RegisterCallback( Mouse.eLClick, OnUnitPortraitClicked );

function OnUnitRClicked()
	local unit = UI.GetHeadSelectedUnit();
	if unit then
	
		-- search by name
		local searchString = Locale.ConvertTextKey( unit:GetNameKey() );
		Events.SearchForPediaEntry( searchString );
	end
end
Controls.RenderedUnitPortrait:RegisterCallback( Mouse.eRClick, OnUnitRClicked );
Controls.ImageUnitPortrait:RegisterCallback( Mouse.eRClick, OnUnitRClicked );

--------------------------------------------------------------------------------
-- InfoPanel is now dirty.
--------------------------------------------------------------------------------
function OnInfoPaneDirty()    
    -- Retrieve the currently selected object --

	local bDeselectedAll = true;

	-- Selected a UNIT
    local unit = UI.GetHeadSelectedUnit();
	if (unit ~= nil) then
		local unitID = unit:GetID();
		local name = unit:GetNameKey();
		local convertedKey = Locale.ConvertTextKey(name);

		-- Unit is different than last unit.
		if(unitID ~= g_lastUnitID) then
			local playerID = Game.GetActivePlayer();
			local unitPosition = {
				x = unit and unit:GetX() or 0,
				y = unit and unit:GetY() or 0,
			};
			local hexPosition = ToHexFromGrid(unitPosition);
        
			if(g_lastUnitID ~= -1) then
				Events.UnitSelectionChanged(playerID, g_lastUnitID, 0, 0, 0, false, false);
			end
        
			Events.UnitSelectionChanged(playerID, unitID, hexPosition.x, hexPosition.y, 0, true, false);

			g_SecondaryOpen = true;
			Controls.PrimaryStack:SetHide( true );
			Controls.SecondaryStack:SetHide( false );
		end
		g_lastUnitID = unitID;

		UpdateUnitActions(unit);
        UpdateUnitPortrait(unit);
        UpdateUnitPromotions(unit);
        UpdateUnitStats(unit);
        UpdateUnitHealthBar(unit);
		UpdatePerkIcons(unit);
        ContextPtr:SetHide(false);

		bDeselectedAll = false;

		return;
	else
		if (g_lastUnitID ~= -1) then
			local playerID = Game.GetActivePlayer();
            Events.UnitSelectionChanged(playerID, g_lastUnitID, 0, 0, 0, false, false);
		end
		g_lastUnitID = -1;
	end
    
	-- Selected an IMPROVEMENT (including Planetary Wonders)
	local eImprovement = UI.GetSelectedImprovementType();
	if (eImprovement ~= nil and eImprovement ~= -1) then
		local improvement  = GameInfo.Improvements[eImprovement];
		local improvementPosition = {
			x = UI.GetSelectedImprovementPlotX();
			y = UI.GetSelectedImprovementPlotY();
		};		

		hexPosition = ToHexFromGrid(improvementPosition);
		-- Debug Print
		if (hexPosition ~= nil) then
			print("Improvement: " .. hexPosition.x .. ", " .. hexPosition.y );
		end
		
		local improvementPlot			= Map.GetPlot(improvementPosition.x, improvementPosition.y);
		local fowStatus					= improvementPlot:GetActiveFogOfWarMode();		
		local FOGOFWARMODE_OFF			= 0;	-- value from CvEnums
		
		-- Only show improvement if not in the fog of war (CivBE: alien nests will show)
		if fowStatus == FOGOFWARMODE_OFF then
			Events.ImprovementSelection(playerID, eImprovement, hexPosition.x, hexPosition.y );

			g_SecondaryOpen = true;
			Controls.PrimaryStack:SetHide( true );
			Controls.SecondaryStack:SetHide( false );

			UpdateImprovementPortrait(improvement);
			UpdateImprovementActions(improvement, improvementPlot);
			UpdateImprovementStatus(improvement, improvementPlot);
			UpdatePerkIcons(nil);
			ContextPtr:SetHide(false);

			bDeselectedAll = false;
		else
			-- Want to leave because FOG was clicked, and don't want selection of existing
			-- item to disappear, thus giving away *something* is at that hex.
			return;
		end
	end
	
	-- Selected an OUTPOST
	-- TBD

	-- Selected a CITY
	local city = UI.GetHeadSelectedCity();
	if(city ~= nil) then	
		UpdateCityPortrait(city);				
		UpdatePerkIcons(nil);
		ContextPtr:SetHide(false);

		bDeselectedAll = false;
    end

	-- DESELECTING all types of things
	if (bDeselectedAll) then
		ContextPtr:SetHide(true);
	end

end
Events.SerialEventUnitInfoDirty.Add(OnInfoPaneDirty);


local g_iPortraitSize = 256;
local bOkayToProcess = true;

--------------------------------------------------------------------------------
-- UnitAction<idx> was clicked.
--------------------------------------------------------------------------------
function OnUnitActionClicked( action )
	if bOkayToProcess then
		local actionInfo : object = GameInfoActions[action];

		if (actionInfo.SubType == ActionSubTypes.ACTIONSUBTYPE_MISSION) then
			local missionInfo = GameInfo.Missions[actionInfo.OriginalIndex];
			if (missionInfo ~= nil and missionInfo.InterfaceMode ~= nil) then

				-- TODO
				-- Reroute to interface mode here

				if (missionInfo.InterfaceMode == "INTERFACEMODE_SUPPORT_ACTION") then
					UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SUPPORT_ACTION);
					UI.SetInterfaceModeValue(actionInfo.OriginalIndex);
				end
				return;
			end
		end

		if (actionInfo.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION) then
			Events.AudioPlay2DSound("AS2D_INTERFACE_UNIT_UPGRADE_CONFIRM");	
		end
		Game.HandleAction( action );
    end
end

--------------------------------------------------------------------------------
-- LandmarkAction<idx> was clicked.
--------------------------------------------------------------------------------
function OnLandmarkActionClicked( action )
	if bOkayToProcess then
		local iActivePlayer = Game.GetActivePlayer();
		local pActivePlayer = Players[iActivePlayer];

		local plot = UI.GetSelectionPlot();
		local plotIndex = plot:GetPlotIndex();

		pActivePlayer:HandleLandmarkAction(action, plotIndex);
    end
end

--------------------------------------------------------------------------------
-- Deploy Passive<idx> was clicked
--------------------------------------------------------------------------------
function OnDeployPassiveAbilityClicked( action )
	if bOkayToProcess then
		local iActivePlayer = Game.GetActivePlayer();
		local pActivePlayer = Players[iActivePlayer];

		local plot = UI.GetSelectionPlot();
		local plotIndex = plot:GetPlotIndex();

		local unit = UI.GetHeadSelectedUnit();
		unit:DeployPassiveAbility(action, true);
    end
end

function OnActivePlayerTurnEnd()
	bOkayToProcess = false;
end
Events.ActivePlayerTurnEnd.Add( OnActivePlayerTurnEnd );

function OnActivePlayerTurnStart()
	bOkayToProcess = true;
	g_bFirstRealizeOnTurn = true;
end
Events.ActivePlayerTurnStart.Add( OnActivePlayerTurnStart );

------------------------------------------------------
------------------------------------------------------
local tipControlTable = {};
TTManager:GetTypeControlTable( "TypeUnitAction", tipControlTable );
function TipHandler( control )
	
	local unit = UI.GetHeadSelectedUnit();
	if not unit then
		return
	end
	
	local unitInfo : table = GameInfo.Units[unit:GetUnitType()];
	local iAction : number = control:GetVoid1();
    local action : table = GameInfoActions[iAction];
    
    local iActivePlayer : number = Game.GetActivePlayer();
    local pActivePlayer : object = Players[iActivePlayer];
    local iActiveTeam : number = Game.GetActiveTeam();
    local pActiveTeam : object = Teams[iActiveTeam];
    
    local pPlot : object = unit:GetPlot();
    
    local bBuild : boolean = false;

    local bDisabled : boolean = false;
	
	-- Build data
	local iBuildID = action.MissionData;
	local pBuild = GameInfo.Builds[iBuildID];
	local strBuildType= "";
	if (pBuild) then
		strBuildType = pBuild.Type;
	end
	
	-- Improvement data
	local iImprovement = -1;
	local pImprovement;
	
	if (pBuild) then
		iImprovement = pBuild.ImprovementType;
		
		if (iImprovement and iImprovement ~= "NONE") then
			pImprovement = GameInfo.Improvements[iImprovement];
			iImprovement = pImprovement.ID;
		end
	end
    
    -- Feature data
	local iFeature = unit:GetPlot():GetFeatureType();
	local pFeature = GameInfo.Features[iFeature];
	local strFeatureType;
	if (pFeature) then
		strFeatureType = pFeature.Type;
	end
	
	-- Route data
	local iRoute = -1;
	local pRoute;
	
	if (pBuild) then
		iRoute = pBuild.RouteType
		
		if (iRoute and iRoute ~= "NONE") then
			pRoute = GameInfo.Routes[iRoute];
			iRoute = pRoute.ID;
		end
	end
	
	local strBuildTurnsString = "";
	local strBuildResourceConnectionString = "";
	local strClearFeatureString = "";
	local strBuildYieldString = "";
	
	local bFirstEntry = true;
	
	local strToolTip : string = "";
	
    local strDisabledString : string = "";
    
    local strActionHelp : string = "";
    
    -- Not able to perform action
    if not Game.CanHandleAction( iAction ) then
		bDisabled = true;
	end
    
	-- Title
    local text = action.TextKey or action.Type or "Action"..(buttonIndex - 1);
    local strTitleString = Locale.ConvertTextKey(text);

    -- Upgrade has special help text
    if (action.Type == "COMMAND_UPGRADE") then
		
		-- Add spacing for all entries after the first
		if (bFirstEntry) then
			bFirstEntry = false;
		elseif (not bFirstEntry) then
			strActionHelp = strActionHelp .. "[NEWLINE]";
		end
		
		strActionHelp = strActionHelp .. "[NEWLINE]";
		
		local iUnitType = unit:GetUpgradeUnitType();
		local iGoldToUpgrade = unit:UpgradePrice(iUnitType);
		strActionHelp = strActionHelp .. Locale.ConvertTextKey("TXT_KEY_UPGRADE_HELP", GameInfo.Units[iUnitType].Description, iGoldToUpgrade);
		
        strToolTip = strToolTip .. strActionHelp;
        
		if bDisabled then
			
			local pActivePlayer = Players[Game.GetActivePlayer()];
			
			-- Can't upgrade because we're outside our territory
			if (pPlot:GetOwner() ~= unit:GetOwner()) then
				
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_UPGRADE_HELP_DISABLED_TERRITORY");
			end
			
			-- Can't upgrade because we're outside of a city
			if (unit:GetDomainType() == DomainTypes.DOMAIN_AIR and not pPlot:IsCity()) then
				
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_UPGRADE_HELP_DISABLED_CITY");
			end
			
			-- Can't upgrade because we lack the Energy
			if (iGoldToUpgrade > pActivePlayer:GetEnergy()) then
				
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_UPGRADE_HELP_DISABLED_GOLD");
			end
			
			-- Can't upgrade because we lack the Resources
			local strResourcesNeeded = "";
			
			local iNumResourceNeededToUpgrade;
			local iResourceLoop;
			
			-- Loop through all resources to see how many we need. If it's > 0 then add to the string
			for pResource in GameInfo.Resources() do
				iResourceLoop = pResource.ID;
				
				iNumResourceNeededToUpgrade = unit:GetNumResourceNeededToUpgrade(iResourceLoop);
				
				if (iNumResourceNeededToUpgrade > 0 and iNumResourceNeededToUpgrade > pActivePlayer:GetNumResourceAvailable(iResourceLoop)) then
					-- Add separator for non-initial entries
					if (strResourcesNeeded ~= "") then
						strResourcesNeeded = strResourcesNeeded .. ", ";
					end
					
					strResourcesNeeded = strResourcesNeeded .. iNumResourceNeededToUpgrade .. " " .. pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description);
				end
			end
			
			-- Build resources required string
			if (strResourcesNeeded ~= "") then
				
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_UPGRADE_HELP_DISABLED_RESOURCES", strResourcesNeeded);
			end
    
    	        -- if we can't upgrade due to stacking
	        if (pPlot:GetNumFriendlyUnitsOfType(unit) > 1) then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_UPGRADE_HELP_DISABLED_STACKING");

	        end
    
	        strDisabledString = "[COLOR_WARNING_TEXT]" .. strDisabledString .. "[ENDCOLOR]";	        
		end
    end
    
    if (action.Type == "MISSION_ALERT" and not unit:IsEverFortifyable()) then
		-- Add spacing for all entries after the first
		if (bFirstEntry) then
			bFirstEntry = false;
		elseif (not bFirstEntry) then
			strActionHelp = strActionHelp .. "[NEWLINE]";
		end

		strActionHelp = "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_MISSION_ALERT_NO_FORTIFY_HELP");
		strToolTip = strToolTip .. strActionHelp;
	
	-- Paradrop
	elseif (action.Type == "INTERFACEMODE_PARADROP") then
		
		strActionHelp = "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_INTERFACEMODE_PARADROP_HELP");
		strToolTip = strToolTip .. strActionHelp;

	-- Heal (Land or Sea)
	elseif (action.Type == "MISSION_HEAL") then
		-- Add spacing for all entries after the first
		if (bFirstEntry) then
			bFirstEntry = false;
		elseif (not bFirstEntry) then
			strActionHelp = strActionHelp .. "[NEWLINE]";
		end
		
		-- Use different terminology to describe different forms of wait-until-healed
		if (unit:CanFortify(pPlot)) then
			strActionHelp = "[NEWLINE]" .. Locale.Lookup(action.Help);
		elseif (unit:GetDomainType() == DomainTypes.DOMAIN_SEA and not unit:IsAlienLifeform()) then
			-- Naval units call it "Anchor" until healed
			strTitleString = Locale.Lookup("TXT_KEY_MISSION_HEAL_SEA");
			strActionHelp = "[NEWLINE]" .. Locale.Lookup("TXT_KEY_MISSION_HEAL_SEA_HELP");					
		else
			-- Aliens and Civvies call it "Sleep" until healed
			strTitleString = Locale.Lookup("TXT_KEY_MISSION_HEAL_SLEEP");
			strActionHelp = "[NEWLINE]" .. Locale.Lookup("TXT_KEY_MISSION_HEAL_SLEEP_HELP");
		end
		strToolTip = strToolTip .. strActionHelp;

	-- Pillage
	elseif (action.Type == "MISSION_PILLAGE") then
		-- Add spacing for all entries after the first
		if (bFirstEntry) then
			bFirstEntry = false;
		elseif (not bFirstEntry) then
			strActionHelp = strActionHelp .. "[NEWLINE]";
		end

		-- Show different help text for pillaging alien nests than player improvements		
		if (pPlot:HasAlienNest()) then
			strActionHelp = "[NEWLINE]" .. Locale.Lookup("TXT_KEY_MISSION_PILLAGE_ALIEN_NEST_HELP");
		else
			strActionHelp = "[NEWLINE]" .. Locale.Lookup( action.Help );
		end		
		strToolTip = strToolTip .. strActionHelp;

	-- Missions	
	elseif (action.SubType == ActionSubTypes.ACTIONSUBTYPE_MISSION) then

		local missionInfo : table = GameInfo.Missions[action.OriginalIndex];
		if (missionInfo ~= nil) then

			-- Support Mission, inject strength value into Help text	
			if (missionInfo.InterfaceMode ~= nil) then
				local filter : string = "UnitType = '" .. unitInfo.Type .. "' and MissionType = '" .. missionInfo.Type .. "'";
				for row : table in GameInfo.Unit_SupportMissions(filter) do
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					elseif (not bFirstEntry) then
						strActionHelp = strActionHelp .. "[NEWLINE]";
					end

					-- Support Mission Strength
					local strength = row.Strength;
					local strengthMod = unit:GetSupportMissionStrengthMod();
					if (strengthMod ~= 0) then
						strength = strength * ((100 + strengthMod) / 100);
					end
					strActionHelp = "[NEWLINE]" .. Locale.ConvertTextKey(action.Help, tostring(math.abs(strength)));

					-- Support Mission Secondary Effects
					local secondaryDamage = unit:GetExtraSupportMissionDamage();
					if (secondaryDamage ~= 0 and row.TargetEnemy) then
						strActionHelp = strActionHelp .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_MISSION_SUPPORT_SECONDARY_EFFECT_DAMAGE_CHANGE_HELP", secondaryDamage);
					end
					local secondaryHeal = unit:GetExtraSupportMissionHeal();
					if (secondaryHeal ~= 0 and row.TargetFriendly) then
						strActionHelp = strActionHelp .. "[NEWLINE][NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_MISSION_SUPPORT_SECONDARY_EFFECT_HEAL_CHANGE_HELP", secondaryHeal);
					end

					-- Additional text for special support mission cases
					if (row.MissionType == "MISSION_ALIEN_LEASH") then
						strActionHelp = strActionHelp .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("TXT_KEY_ALIEN_LEASH_NO_COLOSSAL_ALIENS");
					end

					strToolTip = strToolTip .. strActionHelp;
					break;					
				end
			else
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strActionHelp = strActionHelp .. "[NEWLINE]";
				end
		
				strActionHelp = "[NEWLINE]" .. Locale.ConvertTextKey( action.Help );
				strToolTip = strToolTip .. strActionHelp;
			end
		end

    -- Help text
    elseif (action.Help and action.Help ~= "") then
		
		-- Add spacing for all entries after the first
		if (bFirstEntry) then
			bFirstEntry = false;
		elseif (not bFirstEntry) then
			strActionHelp = strActionHelp .. "[NEWLINE]";
		end
		
		strActionHelp = "[NEWLINE]" .. Locale.ConvertTextKey( action.Help );
        strToolTip = strToolTip .. strActionHelp;
	end
    
    -- Delete has special help text
    if (action.Type == "COMMAND_DELETE") then
		
		strActionHelp = "";
		
		-- Add spacing for all entries after the first
		if (bFirstEntry) then
			bFirstEntry = false;
		elseif (not bFirstEntry) then
			strActionHelp = strActionHelp .. "[NEWLINE]";
		end
		
		strActionHelp = strActionHelp .. "[NEWLINE]";
		
		local iGoldToScrap = unit:GetScrapGold();
		
		strActionHelp = strActionHelp .. Locale.ConvertTextKey("TXT_KEY_SCRAP_HELP", iGoldToScrap);
		
        strToolTip = strToolTip .. strActionHelp;
	end
	
	-- Build?
    if (action.SubType == ActionSubTypes.ACTIONSUBTYPE_BUILD) then
		bBuild = true;
	end
	
    -- Not able to perform action
    if (bDisabled) then
		
		-- Worker build
		if (bBuild) then
			
			-- Figure out what the name of the thing is that we're looking at
			local strImpRouteKey = "";
			if (pImprovement) then
				strImpRouteKey = pImprovement.Description;
			elseif (pRoute) then
				strImpRouteKey = pRoute.Description;
			end
			
			-- Don't have Tech for Build?
			if (pBuild.PrereqTech ~= nil) then
				local pPrereqTech = GameInfo.Technologies[pBuild.PrereqTech];
				local iPrereqTech = pPrereqTech.ID;
				if (iPrereqTech ~= -1 and not pActiveTeam:GetTeamTechs():HasTech(iPrereqTech)) then
					
					-- Must not be a build which constructs something
					if (pImprovement or pRoute) then
						
						-- Add spacing for all entries after the first
						if (bFirstEntry) then
							bFirstEntry = false;
						elseif (not bFirstEntry) then
							strDisabledString = strDisabledString .. "[NEWLINE]";
						end
						
						strDisabledString = strDisabledString .. "[NEWLINE]";
						strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_PREREQ_TECH", pPrereqTech.Description, strImpRouteKey);
					elseif (pBuild.Type == "TERRAFORM_CLEAR_MIASMA") then
						-- Special case the Miasma
						strDisabledString = strDisabledString .. "[NEWLINE]";
						strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_BY_FEATURE", pPrereqTech.Description, GameInfo.Features["FEATURE_MIASMA"].Description );
					end
				end
			end

			-- Trying to do work (without improving something) outside of our territory?
			if (pBuild.InsideBorders) then
				if (pPlot:GetTeam() ~= unit:GetTeam()) then
				
					
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					elseif (not bFirstEntry) then
						strDisabledString = strDisabledString .. "[NEWLINE]";
					end
					
					strDisabledString = strDisabledString .. "[NEWLINE]";
					-- TODO: Refactor this to use Locale.ConvertTextKey
					strDisabledString = strDisabledString .. "You cannot do this outside your territory";
				end
			end
			
			-- Trying to build something and are not adjacent to our territory?
			if (pImprovement and pImprovement.InAdjacentFriendly) then
				if (pPlot:GetTeam() ~= unit:GetTeam()) then
					if (not pPlot:IsAdjacentTeam(unit:GetTeam(), true)) then

					
						-- Add spacing for all entries after the first
						if (bFirstEntry) then
							bFirstEntry = false;
						elseif (not bFirstEntry) then
							strDisabledString = strDisabledString .. "[NEWLINE]";
						end
					
						strDisabledString = strDisabledString .. "[NEWLINE]";
						strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_NOT_IN_ADJACENT_TERRITORY", strImpRouteKey);
					end
				end
				
			-- Trying to build something in a City-State's territory?
			elseif (pImprovement and pImprovement.OnlyCityStateTerritory) then
				local bCityStateTerritory = false;
				if (pPlot:IsOwned()) then
					local pPlotOwner = Players[pPlot:GetOwner()];
					if (pPlotOwner and pPlotOwner:IsMinorCiv()) then
						bCityStateTerritory = true;
					end
				end
				
				if (not bCityStateTerritory) then
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					elseif (not bFirstEntry) then
						strDisabledString = strDisabledString .. "[NEWLINE]";
					end
					
					strDisabledString = strDisabledString .. "[NEWLINE]";
					strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_NOT_IN_CITY_STATE_TERRITORY", strImpRouteKey);
				end	

			-- Trying to build something outside of our territory?
			elseif (pImprovement and not pImprovement.OutsideBorders) then
				if (pPlot:GetTeam() ~= unit:GetTeam()) then
				
					
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					elseif (not bFirstEntry) then
						strDisabledString = strDisabledString .. "[NEWLINE]";
					end
					
					strDisabledString = strDisabledString .. "[NEWLINE]";
					strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_OUTSIDE_TERRITORY", strImpRouteKey);
				end
			end
			
			-- Trying to build something that requires an adjacent luxury?
			if (pImprovement and pImprovement.AdjacentLuxury) then
				local bAdjacentLuxury = false;

				for loop, direction in ipairs(direction_types) do
					local adjacentPlot = Map.PlotDirection(pPlot:GetX(), pPlot:GetY(), direction);
					if (adjacentPlot ~= nil) then
						local eResourceType = adjacentPlot:GetResourceType();
						if (eResourceType ~= -1) then
							if (Game.GetResourceUsageType(eResourceType) == ResourceUsageTypes.RESOURCEUSAGE_LUXURY) then
								bAdjacentLuxury = true;
							end
						end
					end
				end
				
				if (not bAdjacentLuxury) then
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					elseif (not bFirstEntry) then
						strDisabledString = strDisabledString .. "[NEWLINE]";
					end
					
					strDisabledString = strDisabledString .. "[NEWLINE]";
					strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_NO_ADJACENT_LUXURY", strImpRouteKey);
				end
			end
			
			-- Trying to build something where we can't have two adjacent?
			if (pImprovement and pImprovement.NoTwoAdjacent) then
				local bTwoAdjacent = false;

				 for loop, direction in ipairs(direction_types) do
					local adjacentPlot = Map.PlotDirection(pPlot:GetX(), pPlot:GetY(), direction);
					if (adjacentPlot ~= nil) then
						local eImprovementType = adjacentPlot:GetImprovementType();
						if (eImprovementType ~= -1) then
							if (eImprovementType == iImprovement) then
								bTwoAdjacent = true;
							end
						end
						local iBuildProgress = adjacentPlot:GetBuildProgress(iBuildID);
						if (iBuildProgress > 0) then
							bTwoAdjacent = true;
						end
					end
				end
				
				if (bTwoAdjacent) then
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					elseif (not bFirstEntry) then
						strDisabledString = strDisabledString .. "[NEWLINE]";
					end
					
					strDisabledString = strDisabledString .. "[NEWLINE]";
					strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_CANNOT_BE_ADJACENT", strImpRouteKey);
				end
			end
			
			-- Build blocked by a feature here?
			if (pActivePlayer:IsBuildBlockedByFeature(iBuildID, iFeature)) then
				local iFeatureTech;
				
				local filter = "BuildType = '" .. strBuildType .. "' and FeatureType = '" .. strFeatureType .. "'";
				for row in GameInfo.BuildsOnFeatures(filter) do
					iFeatureTech = GameInfo.Technologies[row.PrereqTech].ID;
				end
				
				local pFeatureTech = GameInfo.Technologies[iFeatureTech];
				
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. "[NEWLINE]";
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_BUILD_BLOCKED_BY_FEATURE", pFeatureTech.Description, pFeature.Description);
			end
			
		-- Not a Worker build, use normal disabled help from XML
		else
			
            if (action.Type == "MISSION_CULTURE_BOMB" and pActivePlayer:GetCultureBombTimer() > 0) then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_MISSION_CULTURE_BOMB_DISABLED_COOLDOWN", pActivePlayer:GetCultureBombTimer());
				
			elseif (action.Type == "MISSION_ESTABLISH_TRADE_ROUTE") then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end

				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_TRADE_BLOCKED_NO_ROUTES", pPlot:GetSiteName());

			elseif (action.Type == "INTERFACEMODE_ORBITAL_ATTACK") then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end

				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_ORBITAL_ATTACK_NONE_IN_RANGE", unit:OrbitalAttackRange());
			
			elseif (action.Type == "INTERFACEMODE_SUPPORT_ACTION") then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end

				strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_ORBITAL_ATTACK_NONE_IN_RANGE", unit:OrbitalAttackRange());

			elseif (action.Type == "MISSION_FOUND_EARTHLING_SETTLEMENT") then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end

				-- Test if there is a settlement at this plot that is full
				local earthlingPop = Game.GetEarthlingSettlementPopulation(pPlot);
				if (earthlingPop >= GameDefines.EARTHLING_SETTLEMENT_MAX_POPULATION) then
					strDisabledString = strDisabledString .. Locale.ConvertTextKey("TXT_KEY_MISSION_FOUND_EARTHLING_SETTLEMENT_DISABLED_CAPACITY");
				else
					strDisabledString = strDisabledString .. Locale.ConvertTextKey(action.DisabledHelp);
				end				

			elseif (action.DisabledHelp and action.DisabledHelp ~= "") then
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strDisabledString = strDisabledString .. "[NEWLINE][NEWLINE]";
				end
				
				strDisabledString = strDisabledString .. Locale.ConvertTextKey(action.DisabledHelp);
			end
		end
		
        strDisabledString = "[COLOR_WARNING_TEXT]" .. strDisabledString .. "[ENDCOLOR]";
        strToolTip = strToolTip .. strDisabledString;
        
    end
    
	-- Is this a Worker build?
	if (bBuild) then
		
		local iExtraBuildRate = 0;
		
		-- Are we building anything right now?
		local iCurrentBuildID = unit:GetBuildType();
		if (iCurrentBuildID == -1 or iBuildID ~= iCurrentBuildID) then
			iExtraBuildRate = unit:WorkRate(true, iBuildID);
		end
		
		local iBuildTurns = pPlot:GetBuildTurnsLeft(iBuildID, Game.GetActivePlayer(), iExtraBuildRate, iExtraBuildRate);
		if(iBuildID == iCurrentBuildID) then
			iBuildTurns = iBuildTurns + 1;
		end

		--print("iBuildTurns: " .. iBuildTurns);
		if (iBuildTurns > 1) then
			strBuildTurnsString = " ... " .. Locale.ConvertTextKey("TXT_KEY_BUILD_NUM_TURNS", iBuildTurns);
		end

		-- Yield Changes
		local yieldLines = {};
		yieldLines.Pos = {};
		yieldLines.Neg = {};
		
		for yieldInfo in GameInfo.Yields() do
			local eYield = yieldInfo.ID; 
			local iYieldChange = pPlot:GetYieldWithBuild(iBuildID, eYield, false, iActivePlayer);
			iYieldChange = iYieldChange - pPlot:CalculateYield(eYield);
			
			if (iYieldChange ~= 0) then
				-- Positive or negative change?
				if (iYieldChange > -1) then
					table.insert(yieldLines.Pos, Locale.ConvertTextKey("TXT_KEY_STAT_POSITIVE_YIELD", yieldInfo.IconString, iYieldChange));
				else
					table.insert(yieldLines.Neg, Locale.ConvertTextKey("TXT_KEY_STAT_NEGATIVE_YIELD", yieldInfo.IconString, iYieldChange));
				end
				
			end
		end

		if (#yieldLines.Pos > 0 or #yieldLines.Neg > 0) then
			strBuildYieldString = strBuildYieldString .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_BUILD_CHANGES_YIELDS") .. " ";
			if (#yieldLines.Pos > 0) then
				strBuildYieldString = strBuildYieldString .. "[COLOR_POSITIVE_TEXT]" .. table.concat(yieldLines.Pos, " ") .. "[ENDCOLOR] ";
			end
			if (#yieldLines.Neg > 0) then
				strBuildYieldString = strBuildYieldString .. "[COLOR_NEGATIVE_TEXT]" .. table.concat(yieldLines.Neg, " ") .. "[ENDCOLOR] ";
			end

			strBuildYieldString = strBuildYieldString .. "[NEWLINE]";
		end	

		-- Text for any Improvement made by this build
		if (pImprovement) then

			-- Maintenance
			if (pImprovement) then
				local items = {};
				if (pImprovement.EnergyMaintenance > 0) then
					table.insert(items, "[ICON_ENERGY] " .. pImprovement.EnergyMaintenance);
				end

				if (pImprovement.Unhealth > 0) then
					table.insert(items, "[ICON_HEALTH_4] " .. pImprovement.Unhealth);
				end

				if (#items > 0) then
					local strMaintenance = "[COLOR_NEGATIVE_TEXT]" .. Locale.ConvertTextKey("TXT_KEY_CITYVIEW_MAINTENANCE") .. "[ENDCOLOR]" .. " : ";
					strMaintenance = strMaintenance .. table.concat(items, " ");

					strBuildYieldString = strBuildYieldString .. "[NEWLINE]" .. strMaintenance .. "[NEWLINE]";
				end
			end

			-- Pre-written help
			if (pImprovement.Help ~= nil) then
				local strWrittenHelpText = Locale.ConvertTextKey( pImprovement.Help );
				if (strWrittenHelpText ~= nil and strWrittenHelpText ~= "") then
					-- Add spacing for all entries after the first
					if (bFirstEntry) then
						bFirstEntry = false;
					else
						strBuildYieldString = strBuildYieldString .. "[NEWLINE]";
					end
					strBuildYieldString = strBuildYieldString .. "[NEWLINE]" .. strWrittenHelpText;
				end
			end		
		end
		
        strToolTip = strToolTip .. strBuildYieldString;
		
		-- Resource connection
		if (pImprovement) then 
			local iResourceID = pPlot:GetResourceType(iActiveTeam);
			if (iResourceID ~= -1) then
				if (pPlot:IsResourceConnectedByImprovement(iImprovement)) then
					if (Game.GetResourceUsageType(iResourceID) ~= ResourceUsageTypes.RESOURCEUSAGE_BONUS) then
						local pResource = GameInfo.Resources[pPlot:GetResourceType(iActiveTeam)];
						local strResourceString = pResource.Description;
						
						-- Add spacing for all entries after the first
						if (bFirstEntry) then
							bFirstEntry = false;
						elseif (not bFirstEntry) then
							strBuildResourceConnectionString = strBuildResourceConnectionString .. "[NEWLINE]";
						end
						
						-- DEPRECATED: Luxury resources no longer need to refer to "trade connections"
						--strBuildResourceConnectionString = strBuildResourceConnectionString .. "[NEWLINE]";
						--strBuildResourceConnectionString = strBuildResourceConnectionString .. Locale.ConvertTextKey("TXT_KEY_BUILD_CONNECTS_RESOURCE", pResource.IconString, strResourceString);

						strToolTip = strToolTip .. strBuildResourceConnectionString;
					end
				end
			end
		end
		
		-- Production for clearing a feature
		if (pFeature) then
			local bFeatureRemoved = pPlot:IsBuildRemovesFeature(iBuildID);
			if (bFeatureRemoved) then
				
				-- Add spacing for all entries after the first
				if (bFirstEntry) then
					bFirstEntry = false;
				elseif (not bFirstEntry) then
					strClearFeatureString = strClearFeatureString .. "[NEWLINE]";
				end
				
				strClearFeatureString = strClearFeatureString .. "[NEWLINE]";
				strClearFeatureString = strClearFeatureString .. Locale.ConvertTextKey("TXT_KEY_BUILD_FEATURE_CLEARED", pFeature.Description);
			end
			
			local iFeatureProduction = pPlot:GetFeatureProduction(iBuildID, iActiveTeam);
			if (iFeatureProduction > 0) then
				strClearFeatureString = strClearFeatureString .. Locale.ConvertTextKey("TXT_KEY_BUILD_FEATURE_PRODUCTION", iFeatureProduction);
				
			-- Add period to end if we're not going to append info about feature production
			elseif (bFeatureRemoved) then
				strClearFeatureString = strClearFeatureString .. ".";
			end
			
			strToolTip = strToolTip .. strClearFeatureString;
		end
	end
    
    -- Tooltip
    if (strToolTip and strToolTip ~= "") then
        tipControlTable.UnitActionHelp:SetText( strToolTip );
    end
    
	-- Title
	strTitleString = "[COLOR_POSITIVE_TEXT]" .. strTitleString  .. "[ENDCOLOR]" .. strBuildTurnsString;
	tipControlTable.UnitActionText:SetText( strTitleString );

    -- HotKey
    if action.SubType == ActionSubTypes.ACTIONSUBTYPE_PROMOTION then
        tipControlTable.UnitActionHotKey:SetText( "" );
    elseif action.HotKey and action.HotKey ~= "" then
        tipControlTable.UnitActionHotKey:SetText( "("..tostring(action.HotKey)..")" );
    else
        tipControlTable.UnitActionHotKey:SetText( "" );
    end
    
    -- Autosize tooltip
    tipControlTable.UnitActionMouseover:DoAutoSize();
    local mouseoverSize = tipControlTable.UnitActionMouseover:GetSize();
    if mouseoverSize.x < 350 then
		tipControlTable.UnitActionMouseover:SetSizeVal( 350, mouseoverSize.y );
    end

end

function LandmarkActionTipHandler(control : table)
	
	local landmarkActionID = control:GetVoid1();
	local landmarkAction = GameInfo.LandmarkActions[landmarkActionID];

	local iActivePlayer = Game.GetActivePlayer();
    local pActivePlayer = Players[iActivePlayer];

	-- Title
    local text = landmarkAction.Description or landmarkAction.Type or "LandmarkAction"..(buttonIndex - 1);
    local strTitleString = "[COLOR_POSITIVE_TEXT]" .. Locale.ConvertTextKey( text ) .. "[ENDCOLOR]";
    tipControlTable.UnitActionText:SetText( strTitleString );

	-- Summary (Tooltip)
	local strSummaryString = nil;

	if landmarkAction.Type == "LANDMARK_ACTION_USE_BEACON" then

		if pActivePlayer:IsBeaconActive() then
			strSummaryString = Locale.Lookup("TXT_KEY_LANDMARK_ACTION_USE_BEACON_ACTIVATED");
		else
			local energyCost = pActivePlayer:GetBeaconActivationCost();
			strSummaryString = Locale.ConvertTextKey(landmarkAction.Summary, energyCost);

			if pActivePlayer:GetEnergy() < energyCost then
				strSummaryString = strSummaryString .. "[NEWLINE][NEWLINE]" .. Locale.Lookup("TXT_KEY_WARNING_NOT_ENOUGH_ENERGY");
			end
		end
	else
		strSummaryString = Locale.Lookup(landmarkAction.Summary);
	end

	if strSummaryString ~= nil then
		tipControlTable.UnitActionHelp:SetText( strSummaryString );
	end

	-- No Hot Keys.
	tipControlTable.UnitActionHotKey:SetText( "" );

	-- Autosize tooltip
    tipControlTable.UnitActionMouseover:DoAutoSize();
    local mouseoverSize = tipControlTable.UnitActionMouseover:GetSize();
    if mouseoverSize.x < 350 then
		tipControlTable.UnitActionMouseover:SetSizeVal( 350, mouseoverSize.y );
    end
end


function PassiveAbilityTipHandler(control : table)
	local passiveAbilityID = control:GetVoid1();
	local passiveAbility = GameInfo.UnitPassiveAbilities[passiveAbilityID];

	-- Title
    local text : string = Locale.ConvertTextKey("TXT_KEY_UPANEL_DEPLOY_PASSIVE_ABILITY", passiveAbility.Description);
	local strTitleString = "[COLOR_POSITIVE_TEXT]" .. text .. "[ENDCOLOR]";
    tipControlTable.UnitActionText:SetText(strTitleString);

	-- Summary
	-- help string requires Range value injection
	local strSummaryString : string = "[NEWLINE]"..Locale.ConvertTextKey(passiveAbility.Help, passiveAbility.Range);
	tipControlTable.UnitActionHelp:SetText(strSummaryString);

	-- No Hot Keys.
	tipControlTable.UnitActionHotKey:SetText( "" );

	-- Autosize tooltip
    tipControlTable.UnitActionMouseover:DoAutoSize();
    local mouseoverSize = tipControlTable.UnitActionMouseover:GetSize();
    if mouseoverSize.x < 350 then
		tipControlTable.UnitActionMouseover:SetSizeVal( 350, mouseoverSize.y );
    end
end


function ShowHideHandler( bIshide, bIsInit )
    if( bIshide ) then
        local EnemyUnitPanel = ContextPtr:LookUpControl( "/InGame/WorldView/EnemyUnitPanel" );
        if( EnemyUnitPanel ~= nil ) then
            EnemyUnitPanel:SetHide( true );
        end
    end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged(iActivePlayer, iPrevActivePlayer)
	g_lastUnitID = -1;
	OnInfoPaneDirty();
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);

function OnEnemyPanelHide( bIsEnemyPanelHide )
    if( g_WorkerActionPanelOpen ) then
		-- No other actions are disappearing when enemy unit panel is raised...
        --Controls.BuildPanel:SetHide( not bIsEnemyPanelHide );
    end
end
LuaEvents.EnemyPanelHide.Add( OnEnemyPanelHide );

OnInfoPaneDirty();
