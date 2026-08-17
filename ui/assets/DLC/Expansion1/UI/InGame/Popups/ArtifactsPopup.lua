-- ===========================================================================
--	Artifacts Popup
-- ===========================================================================
include("IconSupport");
include("InstanceManager");
include("DragSupport");
include("ArtifactUtilities.lua");
include("UIExtras");


-- ===========================================================================
--	CONSTANTS	/ DEFINES
-- ===========================================================================
local DEBUG_CACHE_SCREEN_NAME	:string = "ArtifactsPopup";
local DEBUG_SHOW_INFO			:boolean= false;
local DROP_OVERLAP_REQUIRED		:number = 0.4;
local CATEGORY_ICONS_ATLAS		:string = "ARTIFACT_CATEGORY_ATLAS"
local HEADER_WIDTH_NO_SCROLLBAR :number = 944;
local HEADER_WIDTH_SCROLLBAR	:number = HEADER_WIDTH_NO_SCROLLBAR - 32;

local SelectedType				:table = {};
local WasShown					:boolean = false;

SelectedType.None			= 0;
SelectedType.LibraryCard	= 1;
SelectedType.DragBackCard	= 2;
SelectedType.Slot			= 3;

-- LUA based struct (required copy from DragSupport)
hstructure DropAreaStruct
	x		: number
	y		: number
	width	: number
	height	: number
	control	: table
	id		: number	-- (optional, extra info/ID)
end

hstructure ArtifactDataStruct
	Category		: string
	CategoryInfo	: string
	ExplanationInfo	: string
	Description		: string
	IconAtlas		: string
	PortraitIndex	: number
	Type			: string
	UniqueID		: number	-- while named "index" in engine is actually unique ID
	Condition		: number
	UIPriority		: number
end

hstructure SelectedArtifactStruct
	artifactData	: ArtifactDataStruct
	typeHint		: number
	control			: table
	num				: number	-- If not a control reference, this will be set... pointing at a bunch of controls with this number as a suffix
end


-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_artifactIM					:table	= InstanceManager:new("ArtifactCard",		"Content",	Controls.ArtifactStack);
local m_artifactCategoryIM			:table	= InstanceManager:new("ArtifactCategory",	"Content",	Controls.ArtifactStack);
local m_rewardIM					:table	= InstanceManager:new("Reward",				"Content",	Controls.RewardStack);
local m_popupInfo					:table	= nil;
local m_width						:number = 1024;
local m_height						:number = 768;
local m_hiddenAtShutdown			:boolean = true;	-- debug hotload
local m_player						:table;
local m_artifacts					:table;
local m_artifactInstanceToDataMap	:table = {};
local m_iSelectedArtifact			:number = -1;
local m_currentArtifact				:SelectedArtifactStruct = nil;
local m_isRewardExpected			:boolean = false;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================


-- ===========================================================================
--	Handles Game Event for a popup
-- ===========================================================================
function OnPopup(popupInfo : table)

	-- Is the popup message for this popup (and no tutorial shenanigans)?  If not bail.
	if (popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_ARTIFACTS_LIBRARY) then
		if (not ContextPtr:IsHidden() and 
			popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TUTORIAL and 
			popupInfo.Type ~= ButtonPopupTypes.BUTTONPOPUP_TECH_AWARD)
		then
			HideWindow();
		end
		return;
	end

	-- Sanity checks
	local playerType:number = popupInfo.Data1;	
	m_player = Players[playerType];
	if m_player == nil then
		error("Artifacts attempt to popup for a NIL player.");
	end
	if not m_player:IsTurnActive() then
		return;
	end

	m_popupInfo = popupInfo;

	local isShowRequest : boolean = true;
	
	-- Toggle?
	if (popupInfo.Data1 == 1) and (ContextPtr:IsHidden() == false) then
		isShowRequest = false;		
	end
	
	if isShowRequest then
		if m_popupInfo.Data3 == 1 then
			m_iSelectedArtifact = m_popupInfo.Data2;
		end
		ShowWindow();
	else
		HideWindow();
	end
end


-- ===========================================================================
--	Collect/Update the internal data for showing artifacts.
-- ===========================================================================
function UpdateData()
	data = {};

	-- Early check (when is this happening?)
	if m_player == nil then
		return data;
	end

	-- Obtain data.
	local artifacts : table = m_player:GetArtifactData();
	for _,artifactPlayer:table in ipairs(artifacts) do
		local artifact		: table = GameInfo.Artifacts[artifactPlayer.Type];
		local artifactData	: ArtifactDataStruct = hmake ArtifactDataStruct {
			Category		= artifact.Category,
			CategoryInfo	= GameInfo.ArtifactCategories[artifact.Category].Description,
			Condition		= m_player:GetArtifactValueAtIndex(artifactPlayer.Index),
			ExplanationInfo	= artifact.Explanation,
			Description		= artifact.Description,
			IconAtlas		= artifact.IconAtlas,
			PortraitIndex	= artifact.PortraitIndex,
			Type			= artifact.Type,
			UniqueID		= artifactPlayer.Index,			
			UIPriority		= GameInfo.ArtifactCategories[artifact.Category].UIPriority
		};
		table.insert( data, artifactData);
	end

	-- Sort
	table.sort( data, 
		function(a : ArtifactDataStruct, b : ArtifactDataStruct)
			if(a.UIPriority < b.UIPriority) then
				return true;
			end
		end
	);

	return data;
end



-- ===========================================================================
--	Show an artifact that is dropped in a slot.
-- ===========================================================================
function OnClickDropArea( num:number )
	if Controls["DroppedItem"..tostring(num)] ~= nil then
		local id:string = tostring(num);
		SetCurrentArtifact( Controls["DroppedItem"..id], SelectedType.Slot, num );
	end
end

-- ===========================================================================
--	Remove an item in the slot.
-- ===========================================================================
function OnClickRightDropArea( num:number )	
	SetCurrentArtifact(nil);
	m_artifacts = UpdateData();
	Controls["DroppedItem"..tostring(num)] = nil;
	RealizeDropArea(num);
	ViewArtifacts();	
	Events.AudioPlay2DSound("AS2D_INTERFACE_UNLOAD_ARTIFACT");	
end


-- ===========================================================================
--	Player has started to drag an artifact OUT OF a drop area.
-- ===========================================================================
function OnDragbackDown( dragInstance:table, artifactData:ArtifactDataStruct, num:number )

	local id:string = tostring(num);	
	Controls["Condition"..id]:SetHide(true);
	Controls["Portrait"..id]:SetHide(true);
	Controls["Info"..id]:SetHide(true);

	dragInstance.Draggable:SetAlpha(1);

	IconHookup(artifactData.PortraitIndex, 80, artifactData.IconAtlas, dragInstance.Portrait);
	SetHPBar( dragInstance.Condition, artifactData.Condition, false );	

	SetCurrentArtifact( artifactData, SelectedType.DragBackCard, dragInstance );
end


-- ===========================================================================
--	Player has stopped draggin an artifact OUT OF a drop area.
-- ===========================================================================
function OnDragbackDrop( dragStruct:table, dragInstance:table, artifactData:ArtifactDataStruct, num:number )

	Events.AudioPlay2DSound("AS2D_INTERFACE_UNLOAD_ARTIFACT");	
	local id:string = tostring(num);	
	Controls["Condition"..id]:SetHide(false);
	Controls["Portrait"..id]:SetHide(false);
	Controls["Info"..id]:SetHide(false);

	local dragControl:table			= dragStruct:GetControl();
	local x:number,y:number			= dragControl:GetScreenOffset();
	local width:number,height:number= dragControl:GetSizeVal();
	local dropArea:DropAreaStruct	= GetDropArea(x,y,width,height);
	if dropArea == nil or dropArea.id ~= num then
		Controls["Type"..id]:SetHide(true);
		Controls["Empty"..id]:SetHide(false);
		SetCurrentArtifact(nil);
		Controls["DroppedItem"..id] = nil;
		ViewArtifacts();
	else
		Controls["Type"..id]:SetHide(false);
		Controls["Empty"..id]:SetHide(true);
		Controls["DroppedItem"..id] = artifactData;
	end	
	RealizeDropArea(num);
	dragInstance.Draggable:SetAlpha(0);	-- Alpha instead of hide 
end


-- ===========================================================================
--	Setup general drop area properties and then add extras that are specific
--	to this screen's drop area.
--	control	button control that handles the drop.
-- ===========================================================================
function AddArtifactDropArea( control:table, num:number, dropAreaTable:table )
	AddDropArea( control, num, dropAreaTable );
	--control:SetVoid1( num );
	control:RegisterCallback( Mouse.eLClick, OnClickDropArea );
	--control:RegisterCallback( Mouse.eRClick, OnClickRightDropArea );

	-- Add instance for dropping an item back out.
	local dragInstance:table = {};
	ContextPtr:BuildInstanceForControl( "ArtifactCard", dragInstance, control );
	dragInstance.Content:SetSize( control:GetSize() );
	dragInstance.Button:SetVoid1( num );
	dragInstance.Button:RegisterCallback( Mouse.eLClick, OnClickDropArea );
	dragInstance.Button:RegisterCallback( Mouse.eRClick, OnClickRightDropArea );
	dragInstance.StackSpacer:SetHide(true);	-- Don't need this visual as this is not showing up in a stack.
	dragInstance.Draggable:SetAlpha(0);		-- Not hide, but using 0 alpha will continue to get input events (e.g., drag)
		
	control["dragInstance"] = dragInstance;
end


-- ===========================================================================
--	Sets the texture on an HP bar.
-- ===========================================================================
function SetHPBar( textureControl:table, conditionNum:number, isLarge:boolean )	
	if isLarge == nil then isLarge = false; end
	local textureName:string;
	if conditionNum == 0 then
		textureName = "ArtifactsConditionBattered";
	elseif conditionNum == 1 then
		textureName = "ArtifactsConditionWorn";
	else
		textureName = "ArtifactsConditionPristine";
	end
	if isLarge then textureName = textureName .. "Lg"; end
	textureName = textureName .. ".dds";
	textureControl:SetTexture( textureName );
end


-- ===========================================================================
--	Obtain text string with condition of artifact; string is colorized.
-- ===========================================================================
function GetConditionText( conditionNum:number )
	if conditionNum == 0 then
		return "[COLOR:Artifact_Condition_Battered]"..Locale.Lookup("TXT_KEY_ARTIFACT_VALUE_LOW_DESCRIPTION").."[ENDCOLOR]";
	elseif conditionNum == 1 then
		return "[COLOR:Artifact_Condition_Worn]"..Locale.Lookup("TXT_KEY_ARTIFACT_VALUE_MEDIUM_DESCRIPTION").."[ENDCOLOR]";
	else
		return "[COLOR:Artifact_Condition_Pristine]"..Locale.Lookup("TXT_KEY_ARTIFACT_VALUE_HIGH_DESCRIPTION").."[ENDCOLOR]";
	end    
end


-- ===========================================================================
--	Returns font icon string for a given category
-- ===========================================================================
function GetCategoryIconString( categoryType:string )
	if categoryType == "ARTIFACT_CATEGORY_OLD_EARTH"		then return "[ICON_ARTIFACT_OLDEARTH]";
	elseif categoryType == "ARTIFACT_CATEGORY_ALIEN"		then return "[ICON_ARTIFACT_ALIEN]";
	elseif categoryType == "ARTIFACT_CATEGORY_PROGENITOR"	then return "[ICON_ARTIFACT_PROGENITOR]";
	else return "[ICON_ARTIFACT_MIXED]";
	end
end

-- ===========================================================================
--	Returns standard icon atlas index value for a given category
-- ===========================================================================
function GetCategoryIconIndex( categoryType:string )
	if categoryType == "ARTIFACT_CATEGORY_OLD_EARTH"		then return 1;
	elseif categoryType == "ARTIFACT_CATEGORY_PROGENITOR"	then return 2;
	elseif categoryType == "ARTIFACT_CATEGORY_ALIEN"		then return 3;	
	end
	return 0;
end

-- ===========================================================================
--	Set the current artifact
-- ===========================================================================
function SetCurrentArtifact( artifactData:ArtifactDataStruct, typeHint:number, controlOrNumber  )

	-- Deselect any existing cards.
	if m_currentArtifact ~= nil then

		-- Copy out the previous selected data so the "current" data member can
		-- immediately be set to NIL; which will affect how some Realize()
		-- functions behave.
		local prevData:SelectedArtifactStruct = m_currentArtifact;
		m_currentArtifact = nil;

		if prevData.typeHint == SelectedType.LibraryCard then
			prevData.control.Background:SetTextureOffsetVal(0,0);
		elseif prevData.typeHint == SelectedType.Slot then
			RealizeDropArea(prevData.num);
		elseif prevData.typeHint == SelectedType.DragBackCard then
			RealizeDropArea(1);
			RealizeDropArea(2);
			RealizeDropArea(3);
		end			
	end

	-- Select new item if one is passed in.
	if artifactData ~= nil then
		if m_currentArtifact == nil then
			m_currentArtifact = hmake SelectedArtifactStruct {};
		end

		m_currentArtifact.artifactData	= artifactData;
		m_currentArtifact.typeHint		= typeHint;
		if typeHint == SelectedType.Slot then
			m_currentArtifact.num = controlOrNumber;
			m_currentArtifact.control = nil;
		else
			m_currentArtifact.num = -1;
			m_currentArtifact.control = controlOrNumber;
		end


		if typeHint == SelectedType.LibraryCard then
			m_currentArtifact.control.Background:SetTextureOffsetVal(0,128);
		elseif m_currentArtifact.typeHint == SelectedType.Slot then
			Controls["DroppedItem"..tostring(m_currentArtifact.num)] = artifactData;
			RealizeDropArea(m_currentArtifact.num);
		elseif m_currentArtifact.typeHint == SelectedType.DragBackCard then
			RealizeDropArea(1);
			RealizeDropArea(2);
			RealizeDropArea(3);
		end		
	else
		m_currentArtifact = nil;
	end

	RealizeArtifactDetails();	
end

-- ===========================================================================
--	Return table of artifacts (in slots) that are ready to be combined.
-- ===========================================================================
function GetArtifactsToCombineIDs()
	local artifactsToCombine:table = {};
	if Controls["DroppedItem1"] ~= nil then table.insert(artifactsToCombine, Controls["DroppedItem1"].UniqueID ); end
	if Controls["DroppedItem2"] ~= nil then table.insert(artifactsToCombine, Controls["DroppedItem2"].UniqueID ); end
	if Controls["DroppedItem3"] ~= nil then table.insert(artifactsToCombine, Controls["DroppedItem3"].UniqueID ); end
	return artifactsToCombine;
end

-- ===========================================================================
--	Add a UI line showing a reward when items are combined.
--	rewardText	The string to add.
--	width		Size of the area to work with
-- ===========================================================================
function AddReward( rewardText:string, width:number )
	local X_PADDING	:number = -20;
	local Y_PADDING	:number = 20;
	local instance	:table = m_rewardIM:GetInstance();
	instance.Description:SetWrapWidth( width + X_PADDING);
	instance.Description:SetText( rewardText );
	instance.Content:SetSizeX( width );
	instance.Content:SetSizeY( instance.Description:GetSizeY() + Y_PADDING );
end

-- ===========================================================================
--	Obtiain yields for a given set of artifacts to combine.
-- ===========================================================================
function GetRewardYields()
	local yieldsString			: string = "";
	local artifactResearchList	: table = GetArtifactsToCombineIDs();
	local breakDownYieldData	: table = {};

	for _,artifactIndex	: number in ipairs(artifactResearchList) do
		local artifactType	: number = m_player:GetArtifactTypeAtIndex(artifactIndex);
		if artifactType == nil then
			error("ArtifactsPopup: GetRewardYields artifactType was nil");
			return;
		end
		
		local baseRewardModifier: number = ArtifactUtilities.DefaultReward;
		local artifactValueType	: number = m_player:GetArtifactValueAtIndex(artifactIndex);
		if artifactValueType == nil or artifactValueType == -1 then
			error("ArtifactsPopup: GetRewardYields artifactValueType type could not be found.");
			return;
		end

		local yieldModifier : number = GameInfo.ArtifactValues[artifactValueType].YieldModifier;
		if yieldModifier == nil then
			error("ArtifactsPopup: GetRewardYields yieldModifier type could not be found.");
			return;
		end

		baseRewardModifier = baseRewardModifier * (yieldModifier / 100);

		-- More bonus goodness if all 3 slots are filled:
		if table.count(artifactResearchList) == 3 then
			local additionalRewardModifier:number = GameInfo.ArtifactValues[artifactValueType].AdditionalRewardModifier;
			if additionalRewardModifier == nil then
				error("additionalRewardModifier was nil");
				return;
			end
			baseRewardModifier = baseRewardModifier * (additionalRewardModifier / 100);
		end

		local breakDownYields : table = ArtifactUtilities.GetBreakDownYields(artifactType, baseRewardModifier);
		if breakDownYields == nil then
			error("ArtifactsPopup: GetRewardYields breakDownYields was nil.");
			return;
		end

		table.insert(breakDownYieldData, breakDownYields);
	end

	local masterBreakDownYields : table = {};
	masterBreakDownYields.FoodReward = 0;
	masterBreakDownYields.ProductionReward = 0;
	masterBreakDownYields.EnergyReward = 0;
	masterBreakDownYields.ScienceReward = 0;
	masterBreakDownYields.CultureReward = 0;

	for _,breakDownYields : table in ipairs(breakDownYieldData) do
		masterBreakDownYields.FoodReward = masterBreakDownYields.FoodReward + breakDownYields.FoodReward;
		masterBreakDownYields.ProductionReward = masterBreakDownYields.ProductionReward + breakDownYields.ProductionReward;
		masterBreakDownYields.EnergyReward = masterBreakDownYields.EnergyReward + breakDownYields.EnergyReward;
		masterBreakDownYields.ScienceReward = masterBreakDownYields.ScienceReward + breakDownYields.ScienceReward;
		masterBreakDownYields.CultureReward = masterBreakDownYields.CultureReward + breakDownYields.CultureReward;
	end

	local breakdownYieldStrings : table = {};
	if(masterBreakDownYields.FoodReward > 0) then
		table.insert(breakdownYieldStrings, "+" .. masterBreakDownYields.FoodReward .. " [ICON_FOOD]" .. Locale.Lookup("TXT_KEY_ARTIFACTS_POPUP_YIELD_FOOD"));
	end
	if(masterBreakDownYields.ProductionReward > 0) then
		table.insert(breakdownYieldStrings, "+" .. masterBreakDownYields.ProductionReward .. " [ICON_PRODUCTION]" .. Locale.Lookup("TXT_KEY_ARTIFACTS_POPUP_YIELD_PRODUCTION"));
	end
	if(masterBreakDownYields.EnergyReward > 0) then
		table.insert(breakdownYieldStrings, "+" .. masterBreakDownYields.EnergyReward .. " [ICON_ENERGY]" .. Locale.Lookup("TXT_KEY_ARTIFACTS_POPUP_YIELD_ENERGY"));
	end
	if(masterBreakDownYields.ScienceReward > 0) then
		table.insert(breakdownYieldStrings, "+" .. masterBreakDownYields.ScienceReward .. " [ICON_RESEARCH]" .. Locale.Lookup("TXT_KEY_ARTIFACTS_POPUP_YIELD_SCIENCE"));
	end
	if(masterBreakDownYields.CultureReward > 0) then
		table.insert(breakdownYieldStrings, "+" .. masterBreakDownYields.CultureReward .. " [ICON_CULTURE]" .. Locale.Lookup("TXT_KEY_ARTIFACTS_POPUP_YIELD_CULTURE"));
	end

	return breakdownYieldStrings;
end

-- ===========================================================================
--	Set an artifact reward image on a control
-- ===========================================================================
function SetArtifactReward( artifactReward : table, control : table, isBig : boolean )
	
	local size : number = isBig and 128 or 96;
	--size = 128;
	control:SetSizeVal(size,size);
	control:ReprocessAnchoring();

	control:SetTextureOffsetVal(0, 0);

	if artifactReward.BuildingReward ~= nil then
		local building:table = GameInfo.Buildings[artifactReward.BuildingReward];
		if building == nil then
			error("Artifact reward points to a building/wonder which doesn't exist (yet) in the game database '" ..tostring(artifactReward.BuildingReward) .."'");
		else
			IconHookup( building.PortraitIndex, size, building.IconAtlas, control );
		end
	elseif artifactReward.IconAtlas ~= nil and artifactReward.PortraitIndex ~= -1 then
		-- Generic icon hook up?
		IconHookup( artifactReward.PortraitIndex, size, artifactReward.IconAtlas, control );
	elseif artifactReward.PlayerPerkReward ~= nil then
		control:SetTexture( "ArtifactRewardFunctionality"..tostring(size)..".dds" );
	elseif artifactReward.PromotionReward ~= nil then
		control:SetTexture( "ArtifactRewardPromotion"..tostring(size)..".dds" );
	else
		error("No (known) artifact reward type image for '" .. artifactReward.Type .. "'.");
		control:SetHide( true );
	end
end

-- ===========================================================================
--	Show specific details on an artifact
-- ===========================================================================
function RealizeArtifactDetails()	
	
	Controls.CurrentHeader:SetHide( m_currentArtifact == nil );
	Controls.CurrentSubHeader:SetHide( m_currentArtifact == nil );
	Controls.CurrentDescription:SetHide( m_currentArtifact == nil );
	Controls.CurrentPortrait:SetHide( m_currentArtifact == nil );
	Controls.CurrentCondition:SetHide( m_currentArtifact == nil );
	Controls.CurrentInstructions:SetHide( m_currentArtifact ~= nil );

	if m_currentArtifact ~= nil then		
		local artifactData:ArtifactDataStruct = m_currentArtifact.artifactData;
		
		Controls.CurrentHeader:SetText( GetConditionText(artifactData.Condition) .. " " .. Locale.Lookup(artifactData.Description) );
		local subHeaderText:string = GetCategoryIconString(artifactData.Category) .. " " .. Locale.Lookup(artifactData.CategoryInfo);
		Controls.CurrentSubHeader:SetText( subHeaderText );	
		Controls.CurrentDescription:SetText( Locale.Lookup(artifactData.ExplanationInfo) );
		SetHPBar( Controls.CurrentCondition, artifactData.Condition, true );	
		IconHookup(artifactData.PortraitIndex, 300, artifactData.IconAtlas, Controls.CurrentPortrait);
	end

	Controls.CurrentStack:CalculateSize();
	Controls.CurrentInfo:CalculateInternalSize();
end


-- ===========================================================================
--	Update a single drop site.
--	num				Artifact drop site number
-- ===========================================================================
function RealizeDropArea( num:number )

	local id			:string = tostring(num);
	local artifactData	:ArtifactDataStruct = Controls["DroppedItem"..id];	-- may be NIL for no artifact in drop area
	
	Controls["Pipe"..id]:SetHide( artifactData == nil );
	Controls["Portrait"..id]:SetHide( artifactData == nil );
	Controls["Condition"..id]:SetHide( artifactData == nil );
	Controls["Type"..id]:SetHide( artifactData == nil );
	Controls["Info"..id]:SetHide( artifactData == nil );
	Controls["Empty"..id]:SetHide( artifactData ~= nil );

	-- Save the associated artifaceData data on the UI object itself for easy referencing in the rest of the system.
	Controls["DroppedItem"..id] = artifactData;

	-- Grab the drop-specific drag-out control.
	local dragInstance:table = Controls["Drop"..id]["dragInstance"];

	if artifactData ~= nil then
		Controls["Info"..id]:SetText( GetConditionText(artifactData.Condition).." "..Locale.Lookup(artifactData.Description));
		SetHPBar( Controls["Condition"..id], artifactData.Condition, false );	
		IconHookup(artifactData.PortraitIndex, 128, artifactData.IconAtlas, Controls["Portrait"..id]);	
	
		local categoryIconIndex :number = GetCategoryIconIndex(artifactData.Category);
		IconHookup(categoryIconIndex, 32, CATEGORY_ICONS_ATLAS, Controls["Type"..id]);		

		if m_currentArtifact ~= nil and m_currentArtifact.artifactData == artifactData then
			Controls["Drop"..id]:SetTextureOffsetVal(0,512);
		else
			Controls["Drop"..id]:SetTextureOffsetVal(0,0);
		end


		-- Data is there, setup a callback handler if player attempts to drag an item OUT of the drop slot.
		dragInstance.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDragbackDown(dragInstance,artifactData,num); end );
		dragInstance.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDragbackDrop(dragStruct,dragInstance,artifactData,num); end );
	else
		Controls["Drop"..id]:SetTextureOffsetVal( 64,0);

		dragInstance.Draggable:ClearCallback( Drag.eDown );
		dragInstance.Draggable:ClearCallback( Drag.eDrop );
	end	
end


-- ===========================================================================
--	Realize the combined area, including the research and rewards
-- ===========================================================================
function RealizeComboArea()
	
	-- Obtain information about the category slots.
	local index1:number = Controls.DroppedItem1 ~= nil and GetCategoryIconIndex(Controls.DroppedItem1.Category) or 0;
	local index2:number = Controls.DroppedItem2 ~= nil and GetCategoryIconIndex(Controls.DroppedItem2.Category) or 0;
	local index3:number = Controls.DroppedItem3 ~= nil and GetCategoryIconIndex(Controls.DroppedItem3.Category) or 0;		
	Controls.CombinedType:SetHide(false);
	Controls.CombinedArea:SetHide(false);

	-- Determine which combined category symbol is used.
	if index1==0 and index2==0 and index3==0 then		-- Nothing
		Controls.CombinedType:SetHide(true);	
		Controls.CombinedArea:SetHide(true);
	elseif index1~=0 and index2==0 and index3==0 then	IconHookup(index1, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);	-- 1 set
	elseif index1==0 and index2~=0 and index3==0 then	IconHookup(index2, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);	-- 1 set
	elseif index1==0 and index2==0 and index3~=0 then	IconHookup(index3, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);	-- 1 set
	elseif index1==index2 and index2==index3 then		IconHookup(index1, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);	-- all 3 match
	elseif (index1==index2 and index3==0) then			IconHookup(index1, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);
	elseif (index1==index3 and index2==0) then			IconHookup(index1, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);	-- 2 match
	elseif (index2==index3 and index1==0)  then			IconHookup(index2, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);	-- 2 match (one more case, but need to use index2)		
	else												IconHookup(0, 32, CATEGORY_ICONS_ATLAS, Controls.CombinedType);			-- 3 Mix
	end

	local filledSlots:string = "";
	filledSlots = Controls.DroppedItem1 ~= nil and "1" or "";
	filledSlots = filledSlots .. (Controls.DroppedItem2 ~= nil and "2" or "");
	filledSlots = filledSlots .. (Controls.DroppedItem3 ~= nil and "3" or "");
	if filledSlots == "" then
		Controls.ArrowHead:SetHide(true);
	else
		Controls.ArrowHead:SetHide(false);
		Controls.ArrowHead:SetTexture("ArtifactsResearchArrowResult"..filledSlots..".dds");	
	end

	-- Fill the rewards area.

	local REWARD_WIDTH_NO_SCROLL	:number = 996;
	local REWARD_WIDTH_WITH_SCROLL	:number = 962;
	local artifactsToResearch		:table	= GetArtifactsToCombineIDs();
	local rewardRowWidth			:number = REWARD_WIDTH_NO_SCROLL;
	local rewardID					:number = -1;
	local artifactReward			:table;

	m_rewardIM:ResetInstances();

	-- Is this area going to show a portrait because 3 items are there? (e.g., eligable for a reward.)
	if table.count(artifactsToResearch) > 2 then
		rewardRowWidth	= REWARD_WIDTH_NO_SCROLL - Controls.RewardGrid:GetSizeX();		
		rewardID		= ArtifactUtilities.GetArtifactReward(m_player:GetID(), artifactsToResearch);
		artifactReward	= GameInfo.ArtifactRewards[rewardID];
		SetArtifactReward( artifactReward, Controls.RewardPortrait, false );
	end	
	Controls.RewardGrid:SetHide( table.count(artifactsToResearch) < 3 );
	

	local yields:table = GetRewardYields();
	for _,yield in pairs(yields) do
		AddReward( yield, rewardRowWidth );
	end	
	if table.count(artifactsToResearch) > 2 then		
		local rewardDescription : string = Locale.ConvertTextKey(artifactReward.Description);
		local rewardEffectsSummary : string = "";
		if (artifactReward.BuildingReward ~= nil) then
			local rewardBuildingInfo = GameInfo.Buildings[artifactReward.BuildingReward];
			local buildingClassInfo = GameInfo.BuildingClasses[rewardBuildingInfo.BuildingClass];
			if buildingClassInfo.MaxGlobalInstances > 0 or buildingClassInfo.MaxPlayerInstances == 1 or buildingClassInfo.MaxTeamInstances > 0 then
				rewardEffectsSummary = "("..Locale.Lookup("TXT_KEY_TERM_WONDER_UNLOCKED")..") ";
			else
				rewardEffectsSummary = "("..Locale.Lookup("TXT_KEY_TERM_BUILDING_UNLOCKED")..") ";
			end
		end
		rewardEffectsSummary = rewardEffectsSummary .. Locale.Lookup(artifactReward.EffectsSummary);
		if(rewardEffectsSummary == nil) then
			error("ArtifactsPopup: rewardEffectsSummary was nil");
		else
			AddReward( "[COLOR_ARTIFACT_REWARD_NAME]" .. rewardDescription .. "[ENDCOLOR]" .. ": " .. rewardEffectsSummary, rewardRowWidth );
		end		
	end
	Controls.RewardScroll:SetSizeX( rewardRowWidth );
	Controls.RewardStack:CalculateSize();
	Controls.RewardScroll:CalculateInternalSize();

	-- Check if a second pass is needed... to resize everything based on the scrollbar.
	if not Controls.RewardScroll:GetScrollBar():IsHidden() then
		m_rewardIM:ResetInstances();

		rewardRowWidth = REWARD_WIDTH_WITH_SCROLL;
		if table.count(artifactsToResearch) > 2 then
			rewardRowWidth = rewardRowWidth - Controls.RewardGrid:GetSizeX();
		end

		for _,yield in pairs(yields) do
			AddReward( yield, rewardRowWidth );
		end
		local artifactsToResearch:table = GetArtifactsToCombineIDs();		
		if table.count(artifactsToResearch) > 2 then
			local rewardID : number = ArtifactUtilities.GetArtifactReward(m_player:GetID(), artifactsToResearch);
			local rewardDescription : string = Locale.ConvertTextKey(artifactReward.Description);
			local rewardEffectsSummary : string = Locale.ConvertTextKey(artifactReward.EffectsSummary);
			if(rewardEffectsSummary == nil) then
				error("ArtifactsPopup: rewardEffectsSummary was nil");
			else
				AddReward( "[COLOR_ARTIFACT_REWARD_NAME]" .. rewardDescription .. "[ENDCOLOR]" .. ": " .. rewardEffectsSummary, rewardRowWidth );
			end		
		end
		local SCROLL_BAR_WIDTH :number = 40;
		Controls.RewardScroll:SetSizeX( rewardRowWidth + SCROLL_BAR_WIDTH );
		Controls.RewardStack:CalculateSize();
		Controls.RewardScroll:CalculateInternalSize();
	end
end

-- ===========================================================================
--	Drag started or button picked up first click
-- ===========================================================================
function OnDown( artifactData:ArtifactDataStruct, cardInstance:table)
	SetCurrentArtifact( artifactData, SelectedType.LibraryCard, cardInstance );
end

-- ===========================================================================
function OnDrop( dragStruct:table, cardInstance:table )	

	local dragControl:table			= dragStruct:GetControl();
	local x:number,y:number			= dragControl:GetScreenOffset();
	local width:number,height:number= dragControl:GetSizeVal();
	local dropArea:DropAreaStruct	= GetDropArea(x,y,width,height);

	if dropArea ~= nil then		
		local data:ArtifactDataStruct = m_artifactInstanceToDataMap[ cardInstance ];
		if not IsInSlot(data) then		
			Events.AudioPlay2DSound("AS2D_INTERFACE_LOAD_ARTIFACT");
			dragControl:StopSnapBack();
			Controls["DroppedItem"..tostring(dropArea.id)] = data;
			--SetCurrentArtifact( data, SelectedType.Slot, dropArea.id );
			SetCurrentArtifact(nil);
			RealizeDropArea(1);
			RealizeDropArea(2);
			RealizeDropArea(3);
			ViewArtifacts();			
		else
			Events.AudioPlay2DSound("AS2D_INTERFACE_UNLOAD_ARTIFACT");	-- ??TRON: Use a snapback/reject sound?
		end
	end
end


-- ===========================================================================
--	***Kaabow***, how you like me now... 
--	Kick off combining the artifacts for the reward(s).
-- ===========================================================================
function OnClickCombine()
	Events.AudioPlay2DSound("AS2D_INTERFACE_RESEARCH_ARTIFACT");

	local artifactsToResearch:table = GetArtifactsToCombineIDs();	
	local opCode :number = ArtifactUtilities.OpCodes.BreakDown;	-- <=2
	if table.count(artifactsToResearch) > 2 then
		opCode = ArtifactUtilities.OpCodes.CashIn;		-- ==3		
	end

	-- Set to inspect on the callback from the netmessage.
	m_isRewardExpected = table.count(artifactsToResearch) > 2;
	
	-- Tell game engine to combine artifacts...	
	Network.SendProcessArtifacts(m_player:GetID(), opCode, artifactsToResearch);

	Controls["DroppedItem1"] = nil;
	Controls["DroppedItem2"] = nil;
	Controls["DroppedItem3"] = nil;

	SetCurrentArtifact(nil);	
end
Controls.CombineButton:RegisterCallback( Mouse.eLClick, OnClickCombine );


-- ===========================================================================
function CreateArtifactCategory( category:table )
	local name		:string = Locale.Lookup(category.Description);
	local textIcon	:string = GetCategoryIconString( category.Type );
	local instance:table = m_artifactCategoryIM:GetInstance();	
	instance.Description:SetText(textIcon .. " " .. name);

	return instance;
end

-- ===========================================================================
function CreateArtifactCard( artifactData:ArtifactDataStruct )
	local cardInstance:table					= m_artifactIM:GetInstance();	
	m_artifactInstanceToDataMap[ cardInstance ] = artifactData;	

	-- Set card callbacks:
	cardInstance.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDown(artifactData,cardInstance); end );
	cardInstance.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDrop(dragStruct,cardInstance); end );

	-- Since drag doesn't happen until a slight mouse movement, also have a button
	-- instance that can check for clicks to just update info.
	cardInstance.Button:RegisterCallback( Mouse.eLClick, function() OnDown(artifactData,cardInstance); end );

	if DEBUG_SHOW_INFO then
		cardInstance.Info:SetText( Locale.Lookup(artifactData.Description) );
	end
	--cardInstance.Content:SetToolTipString( Locale.Lookup(artifactData.Description) );
	IconHookup(artifactData.PortraitIndex, 80, artifactData.IconAtlas, cardInstance.Portrait);
	SetHPBar( cardInstance.Condition, artifactData.Condition, false );	

	-- Is this card meant to be immediately selected?
	if artifactData.UniqueID == m_iSelectedArtifact then
		SetCurrentArtifact( artifactData, SelectedType.LibraryCard, cardInstance );
		m_iSelectedArtifact = -1;
	else
		cardInstance.Background:SetTextureOffsetVal(0,0);
	end
end

-- ===========================================================================
function IsInSlot( artifactData:ArtifactDataStruct )
	if Controls["DroppedItem1"] ~= nil and Controls["DroppedItem1"].UniqueID == artifactData.UniqueID then return true; end
	if Controls["DroppedItem2"] ~= nil and Controls["DroppedItem2"].UniqueID == artifactData.UniqueID then return true; end
	if Controls["DroppedItem3"] ~= nil and Controls["DroppedItem3"].UniqueID == artifactData.UniqueID then return true; end
	return false;
end

-- ===========================================================================
function ViewArtifacts()
	
	-- Even though stacks are rebuilt; only calling reset on IM's is having cached
	-- data for where artifacts exist in groups... requiring instances to be
	-- destroyed and rebuilt upon a view.  Functional, but not optimal.
	m_artifactIM:DestroyInstances();
	m_artifactCategoryIM:DestroyInstances();
	m_artifactInstanceToDataMap = {};

	m_currentArtifact = nil;

	-- Obtain and sort categories.
	local categories:table = {};
	for category in GameInfo.ArtifactCategories() do
		table.insert(categories, category);
	end
	table.sort( categories, 
		function(a : table, b : table)
			if(a.UIPriority < b.UIPriority) then
				return true;
			end
		end 
	);

	-- Build library, placing appropriate artifacts in their category section.	
	local headerInstances : table = {};
	for _,category in ipairs(categories) do
		table.insert(headerInstances, CreateArtifactCategory( category ));
		for _,artifact in pairs(m_artifacts) do
			if not IsInSlot( artifact ) and artifact.Category == category.Type then
				CreateArtifactCard( artifact );
			end
		end
	end

	Controls.ArtifactStack:CalculateSize();
	Controls.ArtifactLibrary:CalculateInternalSize();

	local headerSize : number = 0;
	if (IsScrollbarShowing(Controls.ArtifactLibrary)) then
		headerSize = HEADER_WIDTH_SCROLLBAR;
	else
		headerSize = HEADER_WIDTH_NO_SCROLLBAR;
	end

	for i : number, instance : table in ipairs(headerInstances) do
		instance.Content:SetSizeX(headerSize);
	end

	RealizeArtifactDetails();	
	RealizeComboArea();
end


-- ===========================================================================
function ShowWindow()
	if( not WasShown ) then
		Events.BlurStateChange(0);
		print("ArtifactsPopup, Blur On");
		WasShown = true;
	end

	Events.SerialEventGameMessagePopupShown( m_popupInfo );

	-- Clears out any in-progress UI state (like range attack/bombard)
	UI.SetInterfaceMode(InterfaceModeTypes.INTERFACEMODE_SELECTION);
	UI.ClearSelectedCities();

	--ContextPtr:SetHide(false);
	UIManager:QueuePopup(ContextPtr, PopupPriority.ArtifactsPopup);

	LuaEvents.ArtifactsPopup_SubDiploPanelOpen(self);

	m_artifacts = UpdateData();

	RealizeDropArea(1);
	RealizeDropArea(2);
	RealizeDropArea(3);
	ViewArtifacts();
end

-- ===========================================================================
function HideWindow()
	if( WasShown ) then
		Events.BlurStateChange(1);
		print("ArtifactsPopup, Blur Off");
		WasShown = false;
	end

	Events.SerialEventGameMessagePopupProcessed.CallImmediate( ButtonPopupTypes.BUTTONPOPUP_ARTIFACTS_LIBRARY, 0 );

	Controls["DroppedItem1"] = nil;
	Controls["DroppedItem2"] = nil;
	Controls["DroppedItem3"] = nil;
	Controls.RewardsSummary:SetHide(true);

	--ContextPtr:SetHide(true);
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
function Close()
	if not Controls.RewardsSummary:IsHidden() then
		OnCloseRewardsSummary();
	else
		HideWindow();
		LuaEvents.ArtifactsPopup_SubDiploPanelClosed();
	end
end

-- ===========================================================================
--	Callback from clicking
function OnClose()
	Close();	
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);

-- ===========================================================================
-- 'Active' (local human) player has changed
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )
	if (not ContextPtr:IsHidden()) then
		Close();
	end
end

-- ===========================================================================
function ShowRewardsSummary(rewardType : number)

	local rewardInfo : table = GameInfo.ArtifactRewards[rewardType];

	Controls.RewardsSummary:SetHide(false);
	Events.AudioPlay2DSound("AS2D_INTERFACE_TECH_WINDOW");

	SetArtifactReward( rewardInfo, Controls.RewardsSummaryPortrait, true );

	Controls.RewardsDescriptionLabel:LocalizeAndSetText(rewardInfo.Description);
	Controls.RewardsExplanationLabel:LocalizeAndSetText(rewardInfo.Explanation);
	Controls.RewardsEffectsSummaryLabel:LocalizeAndSetText(rewardInfo.EffectsSummary);

	Controls.ArtifactRewardsPanelStack:CalculateSize();
	Controls.ArtifactRewardsPanelStack:ReprocessAnchoring();
end

-- ===========================================================================
function OnCloseRewardsSummary()
	Controls.RewardsSummary:SetHide(true);
	m_player:HasRecievedArtifactReward();
	m_isRewardExpected = false;
end
Controls.RewardsButton:RegisterCallback(Mouse.eLClick, OnCloseRewardsSummary);


-- ===========================================================================
--	EVENT
--	Callback from engine; usually after processing combined artifacts
-- ===========================================================================
function OnSerialEventArtifactsScreenDirty()

	m_artifacts = UpdateData();

	RealizeDropArea(1);
	RealizeDropArea(2);
	RealizeDropArea(3);
	ViewArtifacts();

	-- Workaround: Engine currently crashing (sometimes) when requesting a
	-- reward when one isn't given; track on the screen if this should even
	-- attempt to ask for a reward.	 - ??TRON
	if m_isRewardExpected and not OptionsManager.IsNoRewardPopups() then
		local rewardType : number = m_player:GetLastArtifactReward();
		if rewardType ~= nil then
			ShowRewardsSummary(rewardType);
		end
	end
end

-- ===========================================================================
--	LUA Event
--	Debug only, reload cached values across reload for this context.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == DEBUG_CACHE_SCREEN_NAME and contextTable ~= nil then
		m_hiddenAtShutdown		= contextTable["m_hiddenAtShutdown"];
		m_player				= contextTable["m_player"];
		m_artifacts				= contextTable["m_artifacts"];
		Controls["DroppedItem1"]= contextTable["DroppedItem1"];
		Controls["DroppedItem2"]= contextTable["DroppedItem2"];
		Controls["DroppedItem3"]= contextTable["DroppedItem3"];
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnHide()
	if( WasShown ) then
		Events.BlurStateChange(1);
		print("ArtifactsPopup, Blur Off");
		WasShown = false;
	end

	Events.SerialEventGameMessagePopupProcessed.CallImmediate( ButtonPopupTypes.BUTTONPOPUP_ARTIFACTS_LIBRARY, 0 );
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit( isHotload:boolean )	
	if isHotload then		
		LuaEvents.GameDebug_GetValues(DEBUG_CACHE_SCREEN_NAME);
		if not m_hiddenAtShutdown then
			ShowWindow();
		end
		return;
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInput( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then
			Close();
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()	
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_hiddenAtShutdown",	ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_player",				m_player );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "m_artifacts",			m_artifacts );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "DroppedItem1",			Controls["DroppedItem1"] );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "DroppedItem2",			Controls["DroppedItem2"] );
	LuaEvents.GameDebug_AddValue( DEBUG_CACHE_SCREEN_NAME, "DroppedItem3",			Controls["DroppedItem3"] );
	LuaEvents.GameDebug_Return.Remove( OnGameDebugReturn );
	HideWindow();
end


-- ===========================================================================
--	
-- ===========================================================================
function Initialize()

	-- One time sizing:
	m_width, m_height = UIManager:GetScreenSizeVal();

	Controls["DroppedItem1"] = nil;
	Controls["DroppedItem2"] = nil;
	Controls["DroppedItem3"] = nil;

	-- Setup drag and drop
	SetDropOverlap( DROP_OVERLAP_REQUIRED );	
	AddArtifactDropArea( Controls.Drop1, 1, m_dropAreas);
	AddArtifactDropArea( Controls.Drop2, 2, m_dropAreas);
	AddArtifactDropArea( Controls.Drop3, 3, m_dropAreas);
	
	-- Native UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInput );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetShutdown( OnShutdown );
	
	-- Game Events
	Events.SerialEventGameMessagePopup.Add(OnPopup);
	Events.SerialEventArtifactsScreenDirty.Add(OnSerialEventArtifactsScreenDirty);
	Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);
	
	-- LUA Events
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );		-- hotloading help	
end
Initialize();
