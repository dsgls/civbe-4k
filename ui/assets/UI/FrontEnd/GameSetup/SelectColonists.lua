include("UniqueBonuses");
include("InstanceManager");
include("LoadoutUtils");
include("IconSupport");
include("UIExtras");
include("SeededStartCommon");


-- ===========================================================================
--	Global Variables
-- ===========================================================================
g_bIsScenario = false;
g_bWasScenario = true;
g_bRefreshCivs = false;

local m_ItemInstanceManager = InstanceManager:new("ItemInstance", "Content", Controls.Stack);


-- ===========================================================================
function ShowHideHandler( bIsHide )
	if( not bIsHide ) then

		-- Fixes list item over-run in one rare case of x768 screen going from full screen to windowed.
		local screenWidth, screenHeight = UIManager:GetScreenSizeVal();	
		Controls.ScrollPanel:SetSizeY( screenHeight - 204 );

		UpdateWindow();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
function AddRandomEntry()
	local currentColonist	= PreGame.GetLoadoutColonist(LoadoutUtils.GetPlayerID());
	local instance			= m_ItemInstanceManager:GetInstance();
	SetRandomSeededListItem( currentColonist, instance );

	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		PreGame.SetLoadoutColonist(LoadoutUtils.GetPlayerID(), ID_EXPLICITLY_RANDOM );
		UpdateWindow();
		LuaEvents.ColonistsSelected();
	end);

	return instance;
end


-- ===========================================================================
function UpdateWindow()

	m_ItemInstanceManager:ResetInstances();
	local uiList = {};
	
	local randomInstance = AddRandomEntry();
	table.insert( uiList, randomInstance );

	local currentColonist = PreGame.GetLoadoutColonist(LoadoutUtils.GetPlayerID());

	for colonist in GameInfo.Colonists() do
		local available = false;

		-- Unlocked through Firaxis Live?
		if (colonist.FiraxisLiveUnlockKey ~= nil) then
			local value = FiraxisLive.GetKeyValue(colonist.FiraxisLiveUnlockKey);
			available = (value ~= 0);
		else
			available = true;
		end

		if (available) then
			local instance = m_ItemInstanceManager:GetInstance();
			table.insert( uiList, instance );

			instance.Highlight:SetHide(colonist.ID ~= currentColonist);
			instance.CheckMark:SetHide(colonist.ID ~= currentColonist);
			instance.NameLabel:LocalizeAndSetText( colonist.ShortDescription );
			instance.DescriptionLabel:LocalizeAndSetText(colonist.Description);
			IconHookup(colonist.PortraitIndex, 64, colonist.IconAtlas, instance.Portrait);

			local colonistID = colonist.ID;
			instance.Button:RegisterCallback(Mouse.eLClick, function() 
				PreGame.SetLoadoutColonist(LoadoutUtils.GetPlayerID(), colonistID);			
				UpdateWindow();
				LuaEvents.ColonistsSelected();
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
function OnAcceptSelectedColonists()		
	LuaEvents.NextLoadout();
end
Controls.SelectButton:RegisterCallback( Mouse.eLClick, OnAcceptSelectedColonists );

