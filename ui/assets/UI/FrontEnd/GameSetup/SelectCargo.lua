include("UniqueBonuses");
include("InstanceManager");
include("LoadoutUtils");
include("IconSupport");
include("UIExtras");
include("SeededStartCommon");


-- ===========================================================================
--	Global Variables
-- ===========================================================================
local m_ItemInstanceManager = InstanceManager:new("ItemInstance", "Content", Controls.Stack);


-- ===========================================================================
function ShowHideHandler( bIsHide )
   if(not bIsHide) then

		-- Fixes list item over-run in one rare case of x768 screen going from full screen to windowed.
		local screenWidth, screenHeight = UIManager:GetScreenSizeVal();	
		Controls.ScrollPanel:SetSizeY( screenHeight - 204 );

    	UpdateWindow();
   end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );


-- ===========================================================================
function AddRandomEntry()
	local currentCargo	= PreGame.GetLoadoutCargo(LoadoutUtils.GetPlayerID());
	local instance		= m_ItemInstanceManager:GetInstance();
	SetRandomSeededListItem( currentCargo, instance );

	instance.Button:RegisterCallback(Mouse.eLClick, function() 
		PreGame.SetLoadoutCargo(LoadoutUtils.GetPlayerID(), ID_EXPLICITLY_RANDOM );
		UpdateWindow();
		LuaEvents.CargoSelected();
	end);

	return instance;
end


-- ===========================================================================
function UpdateWindow()

	m_ItemInstanceManager:ResetInstances();
	local uiList = {};

	local randomInstance = AddRandomEntry();
	table.insert( uiList, randomInstance );


	local currentCargo = PreGame.GetLoadoutCargo(LoadoutUtils.GetPlayerID());

	for cargo in GameInfo.Cargo() do
		local available = false;

		-- Unlocked through Firaxis Live?
		if (cargo.FiraxisLiveUnlockKey ~= nil) then
			local value = FiraxisLive.GetKeyValue(cargo.FiraxisLiveUnlockKey);
			available = (value ~= 0);
		else
			available = true;
		end

		if (available) then
			local instance = m_ItemInstanceManager:GetInstance();
			table.insert( uiList, instance );

			instance.Highlight:SetHide(cargo.ID ~= currentCargo);
			instance.CheckMark:SetHide(cargo.ID ~= currentCargo);
			instance.NameLabel:LocalizeAndSetText(cargo.ShortDescription);
			instance.DescriptionLabel:LocalizeAndSetText(cargo.Description);
			IconHookup(cargo.PortraitIndex, 64, cargo.IconAtlas, instance.Portrait);

			local cargoID = cargo.ID;
			instance.Button:RegisterCallback(Mouse.eLClick, function() 
				PreGame.SetLoadoutCargo(LoadoutUtils.GetPlayerID(), cargoID);
				UpdateWindow();
				LuaEvents.CargoSelected();
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


-- ===========================================================================
--	Accept the selected Cargo
-- ===========================================================================
function OnAcceptSelectedCargo()		
	LuaEvents.NextLoadout();
end
Controls.SelectButton:RegisterCallback( Mouse.eLClick, OnAcceptSelectedCargo );

