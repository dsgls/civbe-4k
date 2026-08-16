include("IconSupport")
include("InstanceManager")

local g_LoadComplete;
local g_LoadoutContext;

local g_ItemInstanceManager = InstanceManager:new("ItemInstance", "Button", Controls.ItemStack);

g_Colonists = -1;
g_Spacecraft = -1;
g_Cargo = -1;

function ShowHide (isHide, isInit)
	if (not isInit) then
		if (isHide == true) then
		else
			OnInitScreen();
		end
	end
end
ContextPtr:SetShowHideHandler(ShowHide)

function OnInitScreen ()
	Controls.LaunchButton:SetDisabled(not CanLaunch());
	Controls.LaunchButton:SetHide(not CanLaunch());
	g_LoadComplete = true;
end

function OnColonistsClick ()
	local items = {};

	if (ToggleLoadoutContext("Colonists")) then

		Controls.LoadOutSubheader:SetText("Colonists");

		for colonist in GameInfo.Colonists() do
			table.insert(items, 
			{
				ID = colonist.ID,
				Name = Locale.Lookup(colonist.ShortDescription),
				Description = Locale.Lookup(colonist.Description),
			});
		end

		table.sort(items, function(a,b) return Locale.Compare(a.Name, b.Name) < 0; end);

		SelectFromLoadoutItems(items, function(item)
			Controls.LoadoutColonistsName:SetText(item.Name);
			Controls.LoadoutColonistsDescription:SetText(item.Description);
			g_Colonists = item.ID;
		end);
	end
end
Controls.ColonistsButton:RegisterCallback(Mouse.eLClick, OnColonistsClick);

function OnSpacecraftClick ()
	local items = {};

	if (ToggleLoadoutContext("Spacecraft")) then

		Controls.LoadOutSubheader:SetText("Spacecraft");

		for spacecraft in GameInfo.Spacecraft() do
			table.insert(items,
			{
				ID = spacecraft.ID,
				Name = Locale.Lookup(spacecraft.ShortDescription),
				Description = Locale.Lookup(spacecraft.Description),
			});
		end

		table.sort(items, function(a,b) return Locale.Compare(a.Name, b.Name) < 0; end);

		SelectFromLoadoutItems(items, function(item)
			Controls.LoadoutSpacecraftName:SetText(item.Name);
			Controls.LoadoutSpacecraftDescription:SetText(item.Description);
			g_Spacecraft = item.ID;
		end);
	end
end
Controls.SpacecraftButton:RegisterCallback(Mouse.eLClick, OnSpacecraftClick);

function OnCargoClick ()
	local items = {};

	if (ToggleLoadoutContext("Cargo")) then

		Controls.LoadOutSubheader:SetText("Cargo");

		for cargo in GameInfo.Cargo() do
			table.insert(items,
			{
				ID = cargo.ID,
				Name = Locale.Lookup(cargo.ShortDescription),
				Description = Locale.Lookup(cargo.Description),
			});
		end

		table.sort(items, function(a,b) return Locale.Compare(a.Name, b.Name) < 0; end);

		SelectFromLoadoutItems(items, function(item)
			Controls.LoadoutCargoName:SetText(item.Name);
			Controls.LoadoutCargoDescription:SetText(item.Description);
			g_Cargo = item.ID;
		end);
	end
end
Controls.CargoButton:RegisterCallback(Mouse.eLClick, OnCargoClick);

function SelectFromLoadoutItems (items, selectFn)
	g_ItemInstanceManager:ResetInstances();

	for i,v in ipairs(items) do
		local itemInstance = g_ItemInstanceManager:GetInstance();
		itemInstance.Name:SetText(v.Name);
		itemInstance.Description:SetText(v.Description);

--		local gw,gh = itemInstance.AnimGrid:GetSizeVal();
		local dw,dh = itemInstance.Description:GetSizeVal();
		local bw,bh = itemInstance.Button:GetSizeVal();
		
		local newHeight = dh + 45;
		
		itemInstance.Button:SetSizeVal(bw, newHeight);
--		itemInstance.AnimGrid:SetSizeVal(gw, newHeight + 5);

		itemInstance.Button:RegisterCallback(Mouse.eLClick, function()
			selectFn(v);
			ToggleLoadoutContext(nil);
		end);
	end

	Controls.ItemStack:CalculateSize();
	Controls.ItemStack:ReprocessAnchoring();
	Controls.ItemScrollPanel:CalculateInternalSize();
	Controls.ItemScrollPanel:SetScrollValue(0);
end

function ToggleLoadoutContext (contextName)
	Controls.LaunchButton:SetDisabled(not CanLaunch());
	Controls.LaunchButton:SetHide(not CanLaunch());
--	Controls.SelectionHighlight:SetHide(not CanLaunch());

	if (g_LoadoutContext == contextName or contextName == nil) then
		Controls.CargoPanel:SetHide(true);
		Controls.LoadOutSubheader:SetText("");
		g_LoadoutContext = nil;

		return false;
	else
		Controls.CargoPanel:SetHide(false);
		g_LoadoutContext = contextName;

		return true;
	end
end

function CanLaunch ()
	return g_Colonists ~= -1 and g_Spacecraft ~= -1 and g_Cargo ~= -1;
end

function OnLaunchButtonClicked ()
	local playerID = Game.GetActivePlayer();
	PreGame.SetLoadoutCargo(playerID, g_Cargo);
	PreGame.SetLoadoutColonist(playerID, g_Colonists);
	PreGame.SetLoadoutSpacecraft(playerID, g_Spacecraft);
end
Controls.LaunchButton:RegisterCallback(Mouse.eLClick, OnLaunchButtonClicked);

-- For Debug purposes: just rolls random choices for the loadout
function OnAutoButtonClicked ()
	-- Build lists of each type of loadout option, filtering by those
	-- we haven't unlocked yet.
	local colonistInfos = {};
	for _,colonistInfo in GameInfo.Colonists() do
		if (colonistInfo.FiraxisLiveUnlockKey == nil or FiraxisLive.GetKeyValue(colonistInfo.FiraxisLiveUnlockKey) ~= 0) then
			table.insert(colonistInfos, colonistInfo);
		end
	end

	local spacecraftInfos = {}
	for _,spacecraftInfo in GameInfo.Spacecraft() do
		if (spacecraftInfo.FiraxisLiveUnlockKey == nil or FiraxisLive.GetKeyValue(spacecraftInfo.FiraxisLiveUnlockKey) ~= 0) then
			table.insert(spacecraftInfos, spacecraftInfo);
		end
	end

	local cargoInfos = {}
	for _,cargoInfo in GameInfo.Cargo() do
		if (cargoInfo.FiraxisLiveUnlockKey == nil or FiraxisLive.GetKeyValue(cargoInfo.FiraxisLiveUnlockKey) ~= 0) then
			table.insert(cargoInfos, cargoInfo);
		end
	end

	g_Colonists = colonistInfos[Game.Rand(#colonistInfos, "Choosing random colonists") + 1].ID;
	g_Spacecraft = spacecraftInfos[Game.Rand(#spacecraftInfos, "Choosing random spacecraft") + 1].ID;
	g_Cargo = cargoInfos[Game.Rand(#cargoInfos, "Choosing random cargo") + 1].ID;

	OnLaunchButtonClicked();
end
Controls.AutoButton:RegisterCallback(Mouse.eLClick, OnAutoButtonClicked);
