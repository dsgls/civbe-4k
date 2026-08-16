------------------------------------------------------
-- UnitUpgradeHelper.lua
------------------------------------------------------

-- WM: If you change any of the TXT_KEY_UPGRADE_..._HELP text keys, this table must be updated
--     if new the parameters in the string have changed.
local m_UpgradeHelpTextFuncs = 
{
	["TXT_KEY_UNITUPGRADE_FORMATION_HELP"]		= function (upgrade) return Locale.Lookup(upgrade.Help, upgrade.OpenAttack); end,
	["TXT_KEY_UNITUPGRADE_GUERILLA_HELP"]		= function (upgrade) return Locale.Lookup(upgrade.Help, upgrade.RoughAttack); end,
	["TXT_KEY_UNITUPGRADE_TARGETING_HELP"]		= function (upgrade) return Locale.Lookup(upgrade.Help, upgrade.ExtraCombatStrength, upgrade.ExtraRangedCombatStrength); end,
	["TXT_KEY_UNITUPGRADE_COVER_HELP"]			= function (upgrade) return Locale.Lookup(upgrade.Help, upgrade.RangedDefenseMod); end,
	["TXT_KEY_UNITUPGRADE_MEDIC_HELP"]			= function (upgrade) return Locale.Lookup(upgrade.Help, upgrade.FriendlyHealChange); end,
	["TXT_KEY_UNITUPGRADE_NIMBLE_HELP"]			= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_SENTRY_HELP"]			= function (upgrade) return Locale.Lookup(upgrade.Help, upgrade.VisibilityChange); end,
	["TXT_KEY_UNITUPGRADE_SENTINEL_HELP"]		= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_COORDINATED_HELP"]	= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_SEASONED_HELP"]		= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_ALLY_HELP"]			= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_XENOCIDAL_HELP"]		= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_DEATH_RITUAL_HELP"]	= function (upgrade) return Locale.Lookup(upgrade.Help); end,
	["TXT_KEY_UNITUPGRADE_ALIEN_AUTOPSY_HELP"]	= function (upgrade) return Locale.Lookup(upgrade.Help); end,
};

-- WM: Add varification to the table above here.

function GetUpgradeHelpText (upgrade)
	if (upgrade == nil or m_UpgradeHelpTextFuncs[upgrade.Help] == nil) then return "NO UPGRADE DESCRIPTION"; end;

	return m_UpgradeHelpTextFuncs[upgrade.Help](upgrade);
end