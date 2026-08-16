------------------------------------------------------------------------------
-- Select Spacecraft
------------------------------------------------------------------------------
include("UniqueBonuses");
include("InstanceManager");
include("LoadoutUtils");
include("IconSupport");
include("UIExtras");
include("SeededStartCommon");


------------------------------------------------------------------------------
-- Global Variables
------------------------------------------------------------------------------
local m_ItemInstanceManager = InstanceManager:new("ItemInstance", "Content", Controls.Stack);


-- ===========================================================================
function ShowHideHandler( bIsHide )
	if ( not bIsHide ) then

		-- Fixes list item over-run in one rare case of x768 screen going from full screen to windowed.
		local screenWidth, screenHeight = UIManager:GetScreenSizeVal();	
		Controls.ScrollPanel:SetSizeY( screenHeight - 204 );

		UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
function AddRandomEntry()
	local currentSpacecraft	= PreGame.GetLoadoutSpacecraft(LoadoutUtils.GetPlayerID());
	local instance			= m_ItemInstanceManager:GetInstance();
	SetRandomSeededListItem( currentSpacecraft, instance );

	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		PreGame.SetLoadoutSpacecraft(LoadoutUtils.GetPlayerID(), ID_EXPLICITLY_RANDOM );
		UpdateWindow();
		LuaEvents.SpacecraftSelected();
	end);

	return instance;
end


-- ===========================================================================
function UpdateWindow()

	m_ItemInstanceManager:ResetInstances();
	local uiList = {};
	
	local randomInstance = AddRandomEntry();
	table.insert( uiList, randomInstance );

	local currentSpacecraft = PreGame.GetLoadoutSpacecraft(LoadoutUtils.GetPlayerID());

	for spacecraft in GameInfo.Spacecraft() do
		local available = false;

		-- Unlocked through Firaxis Live?
		if (spacecraft.FiraxisLiveUnlockKey ~= nil) then
			local value = FiraxisLive.GetKeyValue(spacecraft.FiraxisLiveUnlockKey);
			available = (value ~= 0);
		else
			available = true;
		end

		if (available) then
			local instance = m_ItemInstanceManager:GetInstance();
			table.insert( uiList, instance );

			instance.Highlight:SetHide(spacecraft.ID ~= currentSpacecraft);
			instance.CheckMark:SetHide(spacecraft.ID ~= currentSpacecraft);
			instance.NameLabel:LocalizeAndSetText( spacecraft.ShortDescription );
			instance.DescriptionLabel:LocalizeAndSetText(spacecraft.Description);
			IconHookup(spacecraft.PortraitIndex, 64, spacecraft.IconAtlas, instance.Portrait);

			local spacecraftID = spacecraft.ID;
			instance.Button:RegisterCallback(Mouse.eLClick, function() 
				PreGame.SetLoadoutSpacecraft(LoadoutUtils.GetPlayerID(), spacecraftID);			
				UpdateWindow();
				LuaEvents.SpacecraftSelected();
			end);
		end
	end

	Controls.Stack:CalculateSize();
	Controls.Stack:ReprocessAnchoring();
	Controls.ScrollPanel:CalculateInternalSize();


	-- Hack for nice UI with dynamic scrollbars on the inside of art.
	-- Need to set explicitly as ResetInstances() above pools the old LUA instances so
	-- if the width is shrunk based on GetSizeX (from XML) then subsequent calls will keep shriting it.
	local NORMAL_WIDTH		= 395;
	local SCROLLING_WIDTH	= 381;
	local sizeX				= NORMAL_WIDTH;
	if IsScrollbarShowing( Controls.ScrollPanel ) then
		sizeX = SCROLLING_WIDTH;
	end
	for _,uiItem in pairs(uiList) do
		uiItem.Content:SetSizeX( sizeX );
		uiItem.Highlight:SetSizeX( sizeX );
		uiItem.Button:SetSizeX( sizeX );
		uiItem.DescriptionLabel:SetWrapWidth( sizeX - 85 );
	end
	Controls.ScrollPanel:CalculateInternalSize();	-- Once more.

end


------------------------------------------------------------------------------
--	Accept the selected Spacecraft
------------------------------------------------------------------------------
function OnAcceptSelectedSpacecraft()		
	LuaEvents.NextLoadout();
end
Controls.SelectButton:RegisterCallback( Mouse.eLClick, OnAcceptSelectedSpacecraft );