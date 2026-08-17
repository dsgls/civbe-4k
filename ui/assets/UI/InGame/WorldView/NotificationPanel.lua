-- ===========================================================================
--	Notification Panel
--	Tabs set to 4 spaces retaining tab characater.
-- ===========================================================================
include( "IconSupport" );
include( "InstanceManager" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================


-- ===========================================================================
local LIMIT_BIG_DESCRIPTION_SIZE_Y = 90;
local OFFSET_WITH_SCROLL_BAR	= 32;
local OFFSET_NO_SCROLL_BAR		= 0;
local DIPLO_SIZE_GUESS			= 420;
local _, screenY				= UIManager:GetScreenSizeVal();
local _, g_offsetY				= Controls.ContainerStack:GetOffsetVal();
local g_SmallScrollMax			= screenY - g_offsetY - DIPLO_SIZE_GUESS;



-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local g_ActiveNotifications		= {};
local g_specificCallbackControls= {};	-- keep track of controls that specific handlers set to them.
local g_TBTable					= {};
local g_TBTableIndices			= {};
local g_NotificationInstances	= {};
local g_NotificationIM			= InstanceManager:new( "Item",  "ItemButton", Controls.NotificationStack );
local g_BaseNotificationIndex	= -1;

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-------------------------------------------------
-------------------------------------------------
function GenericLeftClick( Id )
	if (Game.IsTimedEffectPlaying()) then
		return;
	end
	UI.ActivateNotification( Id );
end


-------------------------------------------------
-------------------------------------------------
function GenericRightClick ( Id )
	if (Game.IsTimedEffectPlaying()) then
		return;
	end
	UI.RemoveNotification( Id );
end

-------------------------------------------------
-------------------------------------------------
function OpenTechTree()
	local stealingTechTargetPlayerID = -1;		-- Carry over from Civ5, not used in BE?
	Events.SerialEventGameMessagePopup( { Type = ButtonPopupTypes.BUTTONPOPUP_TECH_TREE, Data2 = stealingTechTargetPlayerID } );
end


-------------------------------------------------
-------------------------------------------------
function OnMouseEnter ( control, anim )
	if ( anim ~= nil) then 
		anim:SetHide( true );
	else
		print("XML is missing 'TimeOutAnim' tag on :"..tostring( control:GetID() ));
	end
end


-------------------------------------------------
-------------------------------------------------
function AddSpecificCallback( id, callbackFunction )
	if Controls[id] == nil then
		print("Cannot find control with id '", id, "' to add callback.");	-- warn and then let it assert...
	end
	Controls[id]:RegisterCallback(Mouse.eLClick, callbackFunction );
	Controls[id]:RegisterCallback(Mouse.eRClick, callbackFunction );
	g_specificCallbackControls[id] = Controls[id];
end


------------------------------------------------------------------------------------
-- build the list of types we can handle
------------------------------------------------------------------------------------
local g_NameTable = {};
g_NameTable[ -1 ]																= "Generic";
g_NameTable[ NotificationTypes.NOTIFICATION_POLICY ]							= "SocialPolicy";
g_NameTable[ NotificationTypes.NOTIFICATION_MET_MINOR ]							= "MetCityState";
g_NameTable[ NotificationTypes.NOTIFICATION_MINOR ]								= "CityState";
g_NameTable[ NotificationTypes.NOTIFICATION_MINOR_QUEST ]						= "CityState";
g_NameTable[ NotificationTypes.NOTIFICATION_INTRUDER_ALERT ]					= "IntruderAlert";
--g_NameTable[ NotificationTypes.NOTIFICATION_REBELS ]							= "IntruderAlert";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_RANGE_ATTACK ]					= "CityCanBombard";
g_NameTable[ NotificationTypes.NOTIFICATION_ALIENS ]							= "Aliens";
g_NameTable[ NotificationTypes.NOTIFICATION_GOODY ]								= "AncientRuins";
g_NameTable[ NotificationTypes.NOTIFICATION_BUY_TILE ]							= "BuyTile";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_GROWTH ]						= "CityGrowth";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_TILE ]							= "CityTile";
g_NameTable[ NotificationTypes.NOTIFICATION_DEMAND_RESOURCE ]					= "BonusResource";
g_NameTable[ NotificationTypes.NOTIFICATION_UNIT_PROMOTION ]					= "UnitPromoted";
--g_NameTable[ NotificationTypes.NOTIFICATION_WONDER_STARTED ]					= "WonderConstructed";
g_NameTable[ NotificationTypes.NOTIFICATION_WONDER_COMPLETED_ACTIVE_PLAYER]     = "WonderConstructed";
g_NameTable[ NotificationTypes.NOTIFICATION_WONDER_COMPLETED ]					= "WonderConstructed";
g_NameTable[ NotificationTypes.NOTIFICATION_WONDER_BEATEN ]						= "WonderConstructed";
g_NameTable[ NotificationTypes.NOTIFICATION_ERA_OF_PROSPERITY_BEGUN_ACTIVE_PLAYER ]	= "EraOfProsperity";
--g_NameTable[ NotificationTypes.NOTIFICATION_ERA_OF_PROSPERITY_BEGUN ]				= "EraOfProsperity";
g_NameTable[ NotificationTypes.NOTIFICATION_ERA_OF_PROSPERITY_ENDED_ACTIVE_PLAYER ]	= "EraOfProsperity";
--g_NameTable[ NotificationTypes.NOTIFICATION_ERA_OF_PROSPERITY_ENDED ]				= "EraOfProsperity";
g_NameTable[ NotificationTypes.NOTIFICATION_GREAT_PERSON_ACTIVE_PLAYER ]		= "GreatPerson";
--g_NameTable[ NotificationTypes.NOTIFICATION_GREAT_PERSON ]					= "GreatPerson";
g_NameTable[ NotificationTypes.NOTIFICATION_STARVING ]							= "Starving";
g_NameTable[ NotificationTypes.NOTIFICATION_WAR_ACTIVE_PLAYER ]                 = "War";
g_NameTable[ NotificationTypes.NOTIFICATION_WAR ]								= "WarOther";
g_NameTable[ NotificationTypes.NOTIFICATION_PEACE_ACTIVE_PLAYER ]				= "Peace";
g_NameTable[ NotificationTypes.NOTIFICATION_PEACE ]								= "PeaceOther";
g_NameTable[ NotificationTypes.NOTIFICATION_VICTORY ]							= "Victory";
g_NameTable[ NotificationTypes.NOTIFICATION_UNIT_DIED ]							= "UnitDied";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_LOST ]							= "CapitalLost";
g_NameTable[ NotificationTypes.NOTIFICATION_CAPITAL_LOST_ACTIVE_PLAYER ]        = "CapitalLost";
g_NameTable[ NotificationTypes.NOTIFICATION_CAPITAL_LOST ]						= "CapitalLost";
g_NameTable[ NotificationTypes.NOTIFICATION_CAPITAL_RECOVERED ]					= "CapitalRecovered";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_KILLED ]						= "CapitalLost";
g_NameTable[ NotificationTypes.NOTIFICATION_DISCOVERED_BASIC_RESOURCE ]			= "BasicResource";
g_NameTable[ NotificationTypes.NOTIFICATION_DISCOVERED_STRATEGIC_RESOURCE ]		= "StrategicResource";
g_NameTable[ NotificationTypes.NOTIFICATION_DISCOVERED_ARTIFACT_RESOURCE ]		= "ArtifactResource";
--g_NameTable[ NotificationTypes.NOTIFICATION_POLICY_ADOPTION ]					= "Generic";

g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_RACE ]						= "Generic";
g_NameTable[ NotificationTypes.NOTIFICATION_DIPLOMACY_DECLARATION ]				= "Diplomacy";
g_NameTable[ NotificationTypes.NOTIFICATION_DEAL_EXPIRED_GPT ]					= "DiplomacyX";
g_NameTable[ NotificationTypes.NOTIFICATION_DEAL_EXPIRED_RESOURCE ]				= "DiplomacyX";
g_NameTable[ NotificationTypes.NOTIFICATION_DEAL_EXPIRED_OPEN_BORDERS ]			= "DiplomacyX";
g_NameTable[ NotificationTypes.NOTIFICATION_DEAL_EXPIRED_ALLIANCE ]				= "DiplomacyX";
g_NameTable[ NotificationTypes.NOTIFICATION_DEAL_EXPIRED_RESEARCH_AGREEMENT ]	= "DiplomacyX";
g_NameTable[ NotificationTypes.NOTIFICATION_DEAL_EXPIRED_TRADE_AGREEMENT ]		= "DiplomacyX";
g_NameTable[ NotificationTypes.NOTIFICATION_TECH_AWARD ]						= "TechAward";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_DEAL ]						= "Diplomacy";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_DEAL_RECEIVED ]				= "Diplomacy";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_DEAL_RESOLVED ]				= "Diplomacy";
g_NameTable[ NotificationTypes.NOTIFICATION_PROJECT_COMPLETED ]					= "ProjectConstructed";


g_NameTable[ NotificationTypes.NOTIFICATION_TECH ]										= "Tech";
g_NameTable[ NotificationTypes.NOTIFICATION_PRODUCTION ]								= "Production";
g_NameTable[ NotificationTypes.NOTIFICATION_FREE_TECH ]									= "FreeTech";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_STOLE_TECH ] 							= "StealTech";
g_NameTable[ NotificationTypes.NOTIFICATION_FREE_POLICY ]								= "FreePolicy";
g_NameTable[ NotificationTypes.NOTIFICATION_FREE_GREAT_PERSON ]							= "FreeGreatPerson";

g_NameTable[ NotificationTypes.NOTIFICATION_DENUNCIATION_EXPIRED ]						= "Diplomacy";
g_NameTable[ NotificationTypes.NOTIFICATION_FRIENDSHIP_EXPIRED ] 						= "Diplomacy";

g_NameTable[ NotificationTypes.NOTIFICATION_FOUND_PANTHEON] 							= "FoundPantheon";
g_NameTable[ NotificationTypes.NOTIFICATION_FOUND_RELIGION] 							= "FoundReligion";
g_NameTable[ NotificationTypes.NOTIFICATION_PANTHEON_FOUNDED_ACTIVE_PLAYER ] 			= "PantheonFounded";
g_NameTable[ NotificationTypes.NOTIFICATION_PANTHEON_FOUNDED ] 							= "PantheonFounded";
g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_FOUNDED_ACTIVE_PLAYER ] 			= "ReligionFounded";
g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_FOUNDED ] 							= "ReligionFounded";
g_NameTable[ NotificationTypes.NOTIFICATION_ENHANCE_RELIGION] 							= "EnhanceReligion";
g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_ENHANCED_ACTIVE_PLAYER ] 			= "ReligionEnhanced";
g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_ENHANCED ] 						= "ReligionEnhanced";
g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_SPREAD ] 							= "ReligionSpread";

g_NameTable[ NotificationTypes.NOTIFICATION_SPY_CREATED_ACTIVE_PLAYER ]					= "NewSpy";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_CANT_STEAL_TECH ]						= "SpyCannotSteal";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_EVICTED ]								= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_TECH_STOLEN_SPY_DETECTED ]					= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_TECH_STOLEN_SPY_IDENTIFIED ]				= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_KILLED_A_SPY ]							= "SpyKilledASpy";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_WAS_KILLED ]							= "SpyWasKilled";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_REPLACEMENT ]							= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_PROMOTION ]								= "Spy";

g_NameTable[ NotificationTypes.NOTIFICATION_SPY_YOU_STAGE_COUP_SUCCESS ]				= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_YOU_STAGE_COUP_FAILURE ]				= "SpyWasKilled";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_STAGE_COUP_SUCCESS ]					= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_SPY_STAGE_COUP_FAILURE ]					= "Spy";
g_NameTable[ NotificationTypes.NOTIFICATION_DIPLOMAT_EJECTED ]							= "Diplomat";

g_NameTable[ NotificationTypes.NOTIFICATION_CAN_BUILD_MISSIONARY ] 						= "EnoughFaith";
g_NameTable[ NotificationTypes.NOTIFICATION_AUTOMATIC_FAITH_PURCHASE_STOPPED] 			= "AutomaticFaithStop";
g_NameTable[ NotificationTypes.NOTIFICATION_OTHER_PLAYER_NEW_ERA ] 						= "OtherPlayerNewEra";

g_NameTable[ NotificationTypes.NOTIFICATION_MAYA_LONG_COUNT ]							= "FreeGreatPerson";
g_NameTable[ NotificationTypes.NOTIFICATION_FAITH_GREAT_PERSON ]						= "FreeGreatPerson";

g_NameTable[ NotificationTypes.NOTIFICATION_EXPANSION_PROMISE_EXPIRED ]					= "Diplomacy";
g_NameTable[ NotificationTypes.NOTIFICATION_BORDER_PROMISE_EXPIRED ] 					= "Diplomacy";

g_NameTable[ NotificationTypes.NOTIFICATION_TRADE_ROUTE ] 								= "TradeRoute";
g_NameTable[ NotificationTypes.NOTIFICATION_TRADE_ROUTE_BROKEN ] 						= "TradeRouteBroken";

g_NameTable[ NotificationTypes.NOTIFICATION_RELIGION_SPREAD_NATURAL ] 					= "ReligionNaturalSpread";

g_NameTable[ NotificationTypes.NOTIFICATION_MINOR_BUYOUT ] 								= "CityStateBuyout";
g_NameTable[ NotificationTypes.NOTIFICATION_REQUEST_RESOURCE ] 							= "BonusResource";

g_NameTable[ NotificationTypes.NOTIFICATION_ADD_REFORMATION_BELIEF] 					= "AddReformationBelief";
g_NameTable[ NotificationTypes.NOTIFICATION_LEAGUE_CALL_FOR_PROPOSALS ] 				= "LeagueCallForProposals";

g_NameTable[ NotificationTypes.NOTIFICATION_CHOOSE_ARCHAEOLOGY ] 						= "ChooseArchaeology";
g_NameTable[ NotificationTypes.NOTIFICATION_LEAGUE_CALL_FOR_VOTES ] 					= "LeagueCallForVotes";

g_NameTable[ NotificationTypes.NOTIFICATION_REFORMATION_BELIEF_ADDED_ACTIVE_PLAYER ] 	= "ReformationBeliefAdded";
g_NameTable[ NotificationTypes.NOTIFICATION_REFORMATION_BELIEF_ADDED ] 					= "ReformationBeliefAdded";

g_NameTable[ NotificationTypes.NOTIFICATION_GREAT_WORK_COMPLETED_ACTIVE_PLAYER ] 		= "GreatWork";

g_NameTable[ NotificationTypes.NOTIFICATION_CULTURE_VICTORY_SOMEONE_INFLUENTIAL ] 		= "CultureVictoryPositive";
g_NameTable[ NotificationTypes.NOTIFICATION_CULTURE_VICTORY_WITHIN_TWO ] 				= "CultureVictoryNegative";
g_NameTable[ NotificationTypes.NOTIFICATION_CULTURE_VICTORY_WITHIN_TWO_ACTIVE_PLAYER ] 	= "CultureVictoryPositive";
g_NameTable[ NotificationTypes.NOTIFICATION_CULTURE_VICTORY_WITHIN_ONE ] 				= "CultureVictoryNegative";
g_NameTable[ NotificationTypes.NOTIFICATION_CULTURE_VICTORY_WITHIN_ONE_ACTIVE_PLAYER ] 	= "CultureVictoryPositive";
g_NameTable[ NotificationTypes.NOTIFICATION_CULTURE_VICTORY_NO_LONGER_INFLUENTIAL ] 	= "CultureVictoryNegative";

g_NameTable[ NotificationTypes.NOTIFICATION_CHOOSE_IDEOLOGY ] 							= "ChooseIdeology";
g_NameTable[ NotificationTypes.NOTIFICATION_IDEOLOGY_CHOSEN ] 							= "IdeologyChosen";

g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_RECONNECTED ] 						= "PlayerReconnected";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_DISCONNECTED ] 						= "PlayerDisconnected";
g_NameTable[ NotificationTypes.NOTIFICATION_TURN_MODE_SEQUENTIAL ] 						= "SequentialTurns";
g_NameTable[ NotificationTypes.NOTIFICATION_TURN_MODE_SIMULTANEOUS ] 					= "SimultaneousTurns";
g_NameTable[ NotificationTypes.NOTIFICATION_HOST_MIGRATION ] 							= "HostMigration";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_CONNECTING ] 						= "PlayerConnecting";
g_NameTable[ NotificationTypes.NOTIFICATION_PLAYER_KICKED ] 							= "PlayerKicked";

g_NameTable[ NotificationTypes.NOTIFICATION_CITY_REVOLT_POSSIBLE ]						= "Generic";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_REVOLT ] 								= "Generic";

g_NameTable[ NotificationTypes.NOTIFICATION_UNIT_UPGRADE_UNLOCKED] 						= "UnitUpgrade";

g_NameTable[ NotificationTypes.NOTIFICATION_QUEST_PROMPT ] 								= "QuestPrompt";
g_NameTable[ NotificationTypes.NOTIFICATION_QUEST_COMPLETE ] 							= "QuestComplete";
g_NameTable[ NotificationTypes.NOTIFICATION_QUEST_FAIL ] 								= "QuestFail";
g_NameTable[ NotificationTypes.NOTIFICATION_QUEST_UPDATED ]								= "QuestUpdated";
g_NameTable[ NotificationTypes.NOTIFICATION_VICTORY_UPDATED ]							= "VictoryUpdated";
g_NameTable[ NotificationTypes.NOTIFICATION_OTHER_PLAYER_VICTORY_UPDATED ]				= "OtherPlayerVictoryUpdated";
g_NameTable[ NotificationTypes.NOTIFICATION_CONTRACT_EXPIRING ] 						= "ContractExpiring";

g_NameTable[ NotificationTypes.NOTIFICATION_UNIT_UPGRADES_AVAILABLE ]					= "UnitUpgradesAvailable";
g_NameTable[ NotificationTypes.NOTIFICATION_PLOT_BONUS ]								= "PlotBonus";
g_NameTable[ NotificationTypes.NOTIFICATION_BELIEF_AVAILABLE ]							= "BeliefAvailable";
g_NameTable[ NotificationTypes.NOTIFICATION_FREE_AFFINITY_LEVEL ]						= "FreeAffinityLevel";
g_NameTable[ NotificationTypes.NOTIFICATION_PLANETFALL ]								= "Planetfall";
g_NameTable[ NotificationTypes.NOTIFICATION_GROUND_CAN_ATTACK_ORBITAL ]					= "GroundCanAttackOrbital";
g_NameTable[ NotificationTypes.NOTIFICATION_ORBITAL_CAN_ATTACK_GROUND ]					= "OrbitalCanAttackGround";
g_NameTable[ NotificationTypes.NOTIFICATION_CLOSE_TO_DEORBIT ]							= "CloseToDeorbit";
g_NameTable[ NotificationTypes.NOTIFICATION_STATION_GREETING ]							= "StationGreeting";
g_NameTable[ NotificationTypes.NOTIFICATION_AFFINITY_LEVEL_UP ]							= "AffinityLevelUp";

g_NameTable[ NotificationTypes.NOTIFICATION_COVERT_AGENT_RECRUITED ]					= "CovertAgentRecruited";
g_NameTable[ NotificationTypes.NOTIFICATION_COVERT_AGENT_ARRIVED_IN_CITY ]				= "CovertAgentArrivedInCity";
g_NameTable[ NotificationTypes.NOTIFICATION_COVERT_AGENT_COMPLETED_OPERATION ]			= "CovertAgentCompletedOperation";
g_NameTable[ NotificationTypes.NOTIFICATION_COVERT_AGENT_FAILED_OPERATION ]				= "CovertAgentFailedOperation";
g_NameTable[ NotificationTypes.NOTIFICATION_COVERT_AGENT_ABORTED_OPERATION ]			= "CovertAgentAbortedOperation";
g_NameTable[ NotificationTypes.NOTIFICATION_COVERT_AGENT_PROMOTED]						= "CovertAgentPromoted";
g_NameTable[ NotificationTypes.NOTIFICATION_KILLED_COVERT_AGENT ]						= "KilledCovertAgent";
g_NameTable[ NotificationTypes.NOTIFICATION_DETECTED_COVERT_AGENT ]						= "DetectedCovertAgent";
g_NameTable[ NotificationTypes.NOTIFICATION_IDENTIFIED_COVERT_AGENT ]					= "IdentifiedCovertAgent";
g_NameTable[ NotificationTypes.NOTIFICATION_NATIONAL_SECURITY_PROJECT_ACTIVATED ]		= "NationalSecurityProjectActivated";
g_NameTable[ NotificationTypes.NOTIFICATION_SELECT_NATIONAL_SECURITY_PROJECT ]			= "SelectNationalSecurityProject";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_INTRIGUE_INCREASED ]					= "CityIntrigueIncreased";
g_NameTable[ NotificationTypes.NOTIFICATION_CITY_INTRIGUE_DECREASED ]					= "CityIntrigueDecreased";


-- ===========================================================================
--	Returns true if instead of many notifications, just one single one should
--	be used.
-- ===========================================================================
function isSingleLargeNotification( type )
	return (type == NotificationTypes.NOTIFICATION_UNIT_UPGRADES_AVAILABLE);
end


------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
--- Actual new notification entry point
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
function OnNotificationAdded( Id, type, toolTip, strSummary, iGameValue, iExtraGameData, ePlayer )
	
	if(g_ActiveNotifications[ Id ] ~= nil) then
        return;
    end       

    local name = g_NameTable[ type ];  
    local button;
    local text;
    local bg;
    local root;

	function GetTypeName(type)
		for k, v in pairs(NotificationTypes) do
			if(v == type) then
				return k;
			end
		end
	end

	function GetNotification(typeName)
		for row in GameInfo.Notifications() do
			if(row.NotificationType == typeName) then
				return row;
			end
		end
	end


	-- If "tooltip" (now the description text) and summary are the same; remove
	-- content so the same sentence isn't given twice.
	if toolTip == strSummary then
		toolTip	= "";
	end
	
	local typeName = GetTypeName(type);
	if(typeName == nil) then
        typeName = "NOTIFICATION_GENERIC";
    end

	-- Support for notifications that only use one instance and increment a #
	if ( isSingleLargeNotification(type) ) then
		local upgradeInstance			= nil;
		local numThisTypeOfNotification	= 0;		
		
		-- # of other unit upgrade notifications	
		for i,v in pairs(g_ActiveNotifications) do
			if ( v == type ) then									
				upgradeInstance = g_NotificationInstances[i];		-- Get UI from first matching notification and break out.
				break;
			end
		end		

		-- So if a notification of this type already exists, just add this notification
		-- to the dependencies and update the # on the UI.
		if ( upgradeInstance ~= nil ) then						
			table.insert( upgradeInstance.DependentNotificationsTable, Id );	-- in the UI mark this notification is dependent
			upgradeInstance.Multiplier:SetText( tostring( table.count(upgradeInstance.DependentNotificationsTable) ) );
			g_ActiveNotifications[ Id ] = type;
			-- Multiplier updated, leave...
			return;
		end
	end


	local notification = GetNotification(typeName);
	local instance = {};
	if(notification ~= nil) then
		local iconAtlas 	= notification.IconAtlas;
		local iconIndex 	= notification.IconIndex;
		local isTurnBlocking= notification.TurnBlocking;

		-- TurnBlocking == 2 means that this will only block if "autoendturn" is enabled.
		if (isTurnBlocking == 2) then
			isTurnBlocking = 0;
			if (Game.IsGameMultiPlayer() == true) then
				if( OptionsManager.GetMultiplayerAutoEndTurnEnabled() == true ) then
					isTurnBlocking = 1;
					iconAtlas = "NOTIFICATION_TB_ATLAS";
				end
			else
				if( OptionsManager.GetSinglePlayerAutoEndTurnEnabled() == true ) then
					isTurnBlocking = 1;
					iconAtlas = "NOTIFICATION_TB_ATLAS";
				end
			end
		end

		if(isTurnBlocking == 1) then

			-- While starting PLANETFALL, do not display the notifcation.
			if( typeName == "NOTIFICATION_PLANETFALL" ) then
				-- If we don't return here, all sorts of fun happens because instance isn't defined.
				return;
			end

			ContextPtr:BuildInstanceForControl( "BigItem", instance, Controls.TBNotificationStack );

			table.insert(g_TBTable, instance);
			g_TBTableIndices[ tostring(instance.BigItemContainer) ] = Id;


			g_NotificationInstances[Id] = instance;
			IconHookup(iconIndex, 128, iconAtlas, instance.BigItemIcon);
			instance.FingerTitle		:SetText( strSummary );
			instance.FingerTitleOver	:SetText( strSummary );
			instance.FingerTitleOut		:SetText( strSummary );
			instance.DescriptionOver	:SetText( toolTip );
			instance.DescriptionOut		:SetText( toolTip );
			button = instance.BigItemButton;
			root   = instance.BigItemContainer;
				
			instance.Blocking = true;	
			instance.ID = Id;

			instance.DependentNotificationsTable = {};					-- For multiple notifications represented by this one.
			table.insert( instance.DependentNotificationsTable, Id );	-- Needs to mark that it represents itself (cleanup will check if this collection is empty before destroying UI, etc...)
			instance.Multiplier:SetText("");							-- Notification just created, clear out any (recycle instance) multiplier text...

		else
			ContextPtr:BuildInstanceForControl( "Item", instance, Controls.NotificationStack );
			g_NotificationInstances[Id] = instance;
			IconHookup(iconIndex, 64, iconAtlas, instance.ItemIcon);
			instance.FingerTitle		:SetText( strSummary );
			IconHookup(63, 64, iconAtlas, instance.ItemAnimIconBacking);			--Hook up blank icon as backing element for flashing icon

			instance.Blocking = false;

			--we need to put extra long notification strings inside a tooltip instead of the notification itself
			--BPF: decided to use the height of the text string instead of char length to determine if a tooltip is used
			instance.FingerTitleOver	:SetText( strSummary );
			instance.DescriptionOver	:SetText( toolTip );
			local PADDING		= 40;
			local MAX_HEIGHT	= 140;
			local notificationHeight = instance.FingerTitle:GetSizeY() + instance.DescriptionOver:GetSizeY() + PADDING;

			if ( notificationHeight > MAX_HEIGHT) then
				instance.ItemButton:SetToolTipString( toolTip );
				instance.FingerTitleOver	:SetText( "" );
				instance.FingerTitleOut		:SetText( "" );
				instance.DescriptionOver	:SetText( "" );
				instance.DescriptionOut		:SetText( "" );
				instance.BackingOver		:SetHide( true );
				instance.BackingOut			:SetHide( true );
			else
				instance.FingerTitleOver	:SetText( strSummary );
				instance.FingerTitleOut		:SetText( strSummary );
				instance.DescriptionOver	:SetText( toolTip );
				instance.DescriptionOut		:SetText( toolTip );
				instance.BackingOver		:SetHide( false );
				instance.BackingOut			:SetHide( false );
			end

			button = instance.ItemButton;
			root   = instance.ItemContainer;
			
		end
	end

	-- Resize notification
	--local PADDING		= 20;
	--local MIN_HEIGHT	= 60;
	--local notificationHeight = instance.FingerTitle:GetSizeY() + instance.DescriptionOver:GetSizeY() + PADDING;
	--notificationHeight = math.max( MIN_HEIGHT, notificationHeight );
	--instance.BackingOver:SetSizeY( notificationHeight );
	--instance.BackingOut:SetSizeY( notificationHeight );

	-- Do any special control adjustments based on notification type (coloring, etc)
	OnNotificationControlCreated(instance, type, toolTip, strSummary, iGameValue, iExtraGameData, ePlayer);
	
	g_NotificationIM:ResetInstances();
	isTurnBlocking=false;

	-- More PLANETFALL hackery <eyeroll>
	if( root ~= nil ) then
		root:BranchResetAnimation();
		root:RegisterMouseEnterCallback( function( control ) OnMouseEnter(control, instance.TimeOutAnim); end );
		button:SetHide( false );
		button:SetVoid1( Id );
	
		button:RegisterCallback( Mouse.eLClick, GenericLeftClick );
		button:RegisterCallback( Mouse.eRClick, GenericRightClick );
	
		if (UI.IsTouchScreenEnabled()) then
			button:RegisterCallback( Mouse.eLDblClick, GenericRightClick );
		end
	end


-------------------------------------------------
-- FIN
-------------------------------------------------

-- DO NOT DELETE!  
-- Keeping these special cases as to display these with icon assets to go with them.
        
	if type == NotificationTypes.NOTIFICATION_WONDER_COMPLETED_ACTIVE_PLAYER
	or type == NotificationTypes.NOTIFICATION_WONDER_COMPLETED
	or type == NotificationTypes.NOTIFICATION_WONDER_BEATEN then
		if iGameValue ~= -1 then
			local portraitIndex = GameInfo.Buildings[iGameValue].PortraitIndex;
			if portraitIndex ~= -1 then
				IconHookup( portraitIndex, 64, GameInfo.Buildings[iGameValue].IconAtlas, instance.ItemAnimIcon );	
				instance.IconBounce:SetHide(false);			
			end
		end
		if iExtraGameData ~= -1 then
			CivIconHookup( iExtraGameData, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
			instance.CivIconBounce:SetHide(false);				
		else
			CivIconHookup( 22, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
			instance.CivIconBounce:SetHide(false);				
		end
	elseif type == NotificationTypes.NOTIFICATION_PROJECT_COMPLETED then
		if iGameValue ~= -1 then
			local portraitIndex = GameInfo.Projects[iGameValue].PortraitIndex;
			if portraitIndex ~= -1 then
				IconHookup( portraitIndex, 64, GameInfo.Projects[iGameValue].IconAtlas, instance.ItemAnimIcon );	
				instance.IconBounce:SetHide(false);
			end
		end
		if iExtraGameData ~= -1 then
			CivIconHookup( iExtraGameData, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
			instance.CivIconBounce:SetHide(false);				
		else
			CivIconHookup( 22, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
			instance.CivIconBounce:SetHide(false);				
		end
	elseif type == NotificationTypes.NOTIFICATION_DISCOVERED_BASIC_RESOURCE 
	or type == NotificationTypes.NOTIFICATION_DISCOVERED_STRATEGIC_RESOURCE 
	or type == NotificationTypes.NOTIFICATION_DISCOVERED_ARTIFACT_RESOURCE 
	or type == NotificationTypes.NOTIFICATION_DEMAND_RESOURCE
	or type == NotificationTypes.NOTIFICATION_REQUEST_RESOURCE then
		local thisResourceInfo = GameInfo.Resources[iGameValue];
		local portraitIndex = thisResourceInfo.PortraitIndex;
		if portraitIndex ~= -1 then
			IconHookup( portraitIndex, 64, thisResourceInfo.IconAtlas, instance.ItemAnimIcon );	
			instance.IconBounce:SetHide(false);
		end
	elseif type == NotificationTypes.NOTIFICATION_TECH_AWARD then
		local thisTechInfo = GameInfo.Technologies[iExtraGameData];
		local portraitIndex = thisTechInfo.PortraitIndex;
		if portraitIndex ~= -1 then
			IconHookup( portraitIndex, 64, thisTechInfo.IconAtlas, instance.ItemAnimIcon );	
			instance.IconBounce:SetHide(false);
		end
	elseif type == NotificationTypes.NOTIFICATION_UNIT_DIED 
	or type == NotificationTypes.NOTIFICATION_GREAT_PERSON_ACTIVE_PLAYER 					
	or type == NotificationTypes.NOTIFICATION_REBELS then
		local thisUnitType = iGameValue;
		local thisUnitInfo = GameInfo.Units[thisUnitType];
		if(thisUnitInfo ~= nil) then
			local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(thisUnitType, ePlayer);
			if portraitOffset ~= -1 then
				IconHookup( portraitOffset, 64, portraitAtlas, instance.ItemAnimIcon );	
				instance.ItemAnimIcon:SetColor(0xff748db2,0);
				instance.IconBounce:SetHide(false);
			end
		else
			--print("Notification thisUnitInfo was nil.  ePlayer: " .. tostring(ePlayer) .. " Notification type: " .. tostring(type) .. " iGameValue: " 
			--				.. tostring(iGameValue) .. " summary: " .. tostring(strSummary));
		end
	elseif type == NotificationTypes.NOTIFICATION_WAR_ACTIVE_PLAYER then
		local index = iGameValue;
		CivIconHookup( index, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
		instance.CivIconBounce:SetHide(false);				
	elseif type == NotificationTypes.NOTIFICATION_WAR then
		local index = iGameValue;
		CivIconHookup( index, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
		instance.CivIconBounce:SetHide(false);				
		local teamID = iExtraGameData;
		local team = Teams[teamID];
		index = team:GetLeaderID();
		CivIconHookup( index, 57, instance.CivIcon2, instance.CivIcon2BG, nil, false, false, instance.CivIcon2Highlight );
		instance.CivIcon2Frame:SetHide(false);
	elseif type == NotificationTypes.NOTIFICATION_PEACE_ACTIVE_PLAYER then
		local index = iGameValue;
		CivIconHookup( index, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
		instance.CivIconBounce:SetHide(false);	
	elseif type == NotificationTypes.NOTIFICATION_PEACE then
		local index = iGameValue;
		CivIconHookup( index, 57, instance.CivIcon, instance.CivIconBG, nil, false, false, instance.CivIconHighlight );
		instance.CivIconBounce:SetHide(false);	
		local teamID = iExtraGameData;
		local team = Teams[teamID];
		index = team:GetLeaderID();
		CivIconHookup( index, 57, instance.CivIcon2, instance.CivIcon2BG, nil, false, false, instance.CivIcon2Highlight );
		instance.CivIcon2Frame:SetHide(false);
	end

    g_ActiveNotifications[ Id ] = type; 
    ProcessStackSizes();
end
Events.NotificationAdded.Add( OnNotificationAdded );


-------------------------------------------------
-------------------------------------------------
function RemoveNotificationID( Id )

    if( g_ActiveNotifications[ Id ] == nil ) then
        print( "Attempt to remove unknown Notification " .. tostring( Id ) );
        return;
    end

	-- Gets the UI corresponding to this ID
	-- Returns: the UI piece (or NIL... but really this if there is an error)
	--			the Id from which the UI exists against
	--			position of the ID in the list
	function GetNotificationUIInstance( Id )
		local instance = g_NotificationInstances[ Id ];	
		if ( instance ~= nil ) then
			return instance, Id, 1;		-- Id in it's own list is always in the first position
		end

		-- If here, then the UI is likely held by another If, for
		-- which this Id is written in it's dependent list.
		for hostId,v in pairs(g_NotificationInstances) do
			if (v.DependentNotificationsTable ~= nil) then							-- not all notifications have a dependency table
				for i,dependentId in ipairs(v.DependentNotificationsTable) do
					if Id == dependentId then
						instance = g_NotificationInstances[ hostId ];
						return instance, hostId, i;	-- return match
					end
				end
			end
		end

		-- No UI found with this ID.  (Error!)
		return nil;
	end

    local name = g_NameTable[ g_ActiveNotifications[ Id ] ];

	-- Grab UI element, owner's notification ID, and position of ID in owners's list
	local instance, notificationID, idPosition = GetNotificationUIInstance( Id );

	-- If it's a blocking notification, we'll get that from the instance itself.
	local isBlockingNotification = false;
	if( instance ~= nil and instance.Blocking ~= nil ) then
		isBlockingNotification = instance.Blocking;
	end

	if isBlockingNotification == true then

		if( instance ~= nil ) then

			g_ActiveNotifications[ Id ] = nil; 

			-- Remove ID from dependency table and mark as not being active.
			if ( instance.DependentNotificationsTable ~= nil ) then
				table.remove( instance.DependentNotificationsTable, idPosition );				

				-- If any dependencies are left, update the text and bail.
				local numOfDependencies = table.count(instance.DependentNotificationsTable);
				if ( numOfDependencies > 0 ) then
					instance.Multiplier:SetText( tostring( numOfDependencies ) );
					return;
				end
			end
			
			-- Reset the ID to the actual notification Id (which holds the UI instance, etc...)
			Id = notificationID;

			g_NotificationInstances[ Id ] = nil;
			g_TBTableIndices[ tostring(instance.BigItemContainer) ] = nil;

			local pos = nil;
			for i,v in ipairs(g_TBTable) do
				if (v== instance) then
					pos=i;	
					break;
				end;
			end;
			if(pos ~= nil) then
				table.remove(g_TBTable, pos);
			end;

			Controls.TBNotificationStack:ReleaseChild( instance["BigItemContainer"] );

		end

    else
		-- Non-blocking notification...
	 
        if( name == nil ) then
            name = "Generic";
        end
        
		local instance = g_NotificationInstances[ Id ];
		if( instance ~= nil ) then
			Controls.NotificationStack:ReleaseChild( instance["ItemContainer"] );
			g_NotificationInstances[ Id ] = nil;
		end
        
    end 
end

-------------------------------------------------
-------------------------------------------------
function NotificationRemoved( Id )
    --print( "removing Notification " .. Id .. " " .. tostring( g_ActiveNotifications[ Id ] ) .. " " .. tostring( g_NameTable[ g_ActiveNotifications[ Id ] ] ) );        
	RemoveNotificationID( Id );	
    ProcessStackSizes();

end
Events.NotificationRemoved.Add( NotificationRemoved );


----------------------------------------------------------------
--	Local human player has started a turn
--	NOTE: May be more than 1 local human if in hotseat mode.
----------------------------------------------------------------
function OnActivePlayerTurnStart()
	UI.RebroadcastNotifications();
	ProcessStackSizes();
end
Events.ActivePlayerTurnStart.Add(OnActivePlayerTurnStart);


----------------------------------------------------------------
--	Local human player has started a turn
----------------------------------------------------------------
function OnActivePlayerTurnEnd()
	-- Remove all the UI notifications.  The new player will rebroadcast any persistent ones from their last turn	
	for thisID, thisType in pairs(g_ActiveNotifications) do
		RemoveNotificationID(thisID);
	end
	g_ActiveNotifications = {};
end
Events.ActivePlayerTurnEnd.Add(OnActivePlayerTurnEnd);

-------------------------------------------------
-------------------------------------------------
function SortFunction( a, b )

	local entryA = g_TBTableIndices[ tostring( a ) ];
	local entryB = g_TBTableIndices[ tostring( b ) ];
	
	if (entryA == nil) or (entryB == nil) then 
		if entryA and (entryB == nil) then
			return false;
		elseif (entryA == nil) and entryB then
			return true;
		else
			return tostring(a) < tostring(b); -- gotta do something deterministic
		end
	else
		if(entryA >= g_BaseNotificationIndex and entryB >= g_BaseNotificationIndex) then
			return entryA < entryB;
		elseif (entryA < g_BaseNotificationIndex and entryB < g_BaseNotificationIndex) then
			return entryA < entryB;
		else
			return entryA >= g_BaseNotificationIndex;
		end
	end
end


-------------------------------------------------
-------------------------------------------------
function SortLargeIcons()

	-- Sort TBNotificationStack based on the current player's end turn blocking notification index.
	g_BaseNotificationIndex = Players[Game.GetActivePlayer()]:GetEndTurnBlockingNotificationIndex();
	Controls.TBNotificationStack:SortChildren( SortFunction );

	-- Sort g_TBTable the same way
	table.sort(g_TBTable, function(a,b) 
		if( a.ID >= g_BaseNotificationIndex and b.ID >= g_BaseNotificationIndex ) then
			return a.ID < b.ID;
		elseif (a.ID < g_BaseNotificationIndex and b.ID < g_BaseNotificationIndex ) then
			return a.ID < b.ID;
		else
			return a.ID >= g_BaseNotificationIndex;
		end
	end )

end

-------------------------------------------------
-------------------------------------------------
function ProcessStackSizes()

	SortLargeIcons();

	Controls.TBNotificationStack:CalculateSize();
    local tbStackHeight = Controls.TBNotificationStack:GetSizeY();
    Controls.NotificationScrollPanel:SetSizeY( g_SmallScrollMax - tbStackHeight );

    Controls.NotificationStack:CalculateSize();
    Controls.NotificationStack:ReprocessAnchoring();

	Controls.NotificationScrollPanel:CalculateInternalSize();
	Controls.NotificationScrollPanel:ReprocessAnchoring();

    if( Controls.NotificationScrollPanel:GetRatio() ~= 1 ) then
		Controls.ScrollBarBacking:SetSizeX(128);
		Controls.ScrollBarBacking:SetSizeY(Controls.NotificationScrollPanel:GetSizeY());
		Controls.ScrollBarBacking:SetHide( false );
        Controls.NotificationScrollPanel:SetOffsetX( -20 );	-- scroll bar
    else
        Controls.NotificationScrollPanel:SetOffsetX( 0 );		-- no scroll bar
		Controls.ScrollBarBacking:SetHide( true );
    end

	if(Controls.TBNotificationStack:GetNumChildren() == 0) then
		Controls.ContainerStack:SetOffsetY( 160 );
	else
		Controls.ContainerStack:SetOffsetY( 60 );
	end
    Controls.ContainerStack:CalculateSize();
    Controls.ContainerStack:ReprocessAnchoring();

	local instance = g_TBTable[1];

	if (instance~= nil) then
		instance.FingerTitle:SetHide( true );
		instance.FingerTitleOver:SetHide( true );
		instance.FingerTitleOut:SetHide( true );
		instance.DescriptionOut:SetHide ( true );
		instance.DescriptionOver:SetHide( true );
		instance.TimeOutAnim:SetHide( true );
		instance.OverAnim:SetHide( true );
		instance.OutAnim:SetHide( true );
		instance.Background:SetHide( true );
	end
end

----------------------------------------------------------------
-- Advanced Notification Methods
----------------------------------------------------------------
function OnNotificationControlCreated(instance, type, toolTip, strSummary, iGameValue, iExtraGameData, ePlayer)
	
	if type == NotificationTypes.NOTIFICATION_ALIEN then

		-- recolor the notification based on active player hostility
		local alienOpinion = Aliens.GetOpinionForPlayer(ePlayer);

		if (alienOpinion == AIAlienOpinionTypes.ALIEN_OPINION_NEUTRAL) then
			--instance.ItemIcon:SetColor(0xff00ff00);  -- Green
		elseif (alienOpinion == AIAlienOpinionTypes.ALIEN_OPINION_FRIENDLY) then

		elseif (alienOpinion == AIAlienOpinionTypes.ALIEN_OPINION_HOSTILE) then

		elseif (alienOpinion == AIAlienOpinionTypes.ALIEN_OPINION_VERY_HOSTILE) then

		end
	end
end


UI.RebroadcastNotifications();
ProcessStackSizes();
