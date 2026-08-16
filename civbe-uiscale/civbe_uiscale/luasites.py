"""Per-site rewrites for Lua the generic patcher cannot reach.

`luapatch` only rescales all-literal setter calls. These rules cover the call
sites whose texture offset or size is computed -- from a constant, an
expression, or a table -- by scaling the computation at its source. Each rule
carries the exact stock text, so a game patch that changes a line makes the
rule inert rather than corrupting it; `analysis/verify_lua_sites.py` asserts
every rule still matches the stock trees and every computed call site is
accounted for.

Rules are keyed by tree-relative path and apply to every tree that has the
file; where base and Rising Tide copies diverge, a rule simply matches in the
tree(s) that carry its text.
"""
from dataclasses import dataclass

from .classify import Space
from .luapatch import LuaChange, _format_scale


@dataclass(frozen=True)
class Rule:
    space: Space
    old: str
    new: str  # replacement; {s} becomes the scale factor


def patch_sites(rel, text, ui_scale, texture_scale, sites=None):
    """Apply the site rules for `rel`. Returns the new text and the changes."""
    rules = (SITES if sites is None else sites).get(rel, ())
    changes = []
    for rule in rules:
        factor = ui_scale if rule.space is Space.SCREEN else texture_scale
        if factor == 1:
            continue
        new = rule.new.replace("{s}", _format_scale(factor))
        cursor = 0
        while True:
            index = text.find(rule.old, cursor)
            if index < 0:
                break
            changes.append(LuaChange(
                line=text.count("\n", 0, index) + 1, call="site",
                space=rule.space, old=rule.old, new=new,
            ))
            text = text[:index] + new + text[index + len(rule.old):]
            cursor = index + len(new)
    changes.sort(key=lambda change: change.line)
    return text, changes


def _t(old, new):
    return Rule(Space.TEXTURE, old, new)


def _u(old, new):
    return Rule(Space.SCREEN, old, new)


SITES = {
    # The tab strip: textureSizeY is the cell height callers pass to
    # CreateTabs, used only to pick the unselected band.
    "TabSupport.lua": (
        _t("tabControl:SetTextureOffsetVal( 0, tabs.textureSizeY * 2 );",
           "tabControl:SetTextureOffsetVal( 0, tabs.textureSizeY * 2 * {s} );"),
    ),

    "FrontEnd/Multiplayer/StagingRoom.lua": (
        _t("local TEXTURE_OFFSET_CHECK_OFF\t= 64;",
           "local TEXTURE_OFFSET_CHECK_OFF\t= 64 * {s};"),
    ),

    "InGame/TaskList.lua": (
        _t("iOffset = 96;", "iOffset = 96 * {s};"),
        _t("iOffset = 32;", "iOffset = 32 * {s};"),
    ),

    "InGame/YieldIconManager.lua": (
        _t("SetTextureOffsetVal( yieldType * 128, 512 );",
           "SetTextureOffsetVal( yieldType * 128 * {s}, 512 * {s} );"),
        _t("SetTextureOffsetVal( yieldType * 128, 128 * ( amount - 1 ) );",
           "SetTextureOffsetVal( yieldType * 128 * {s}, 128 * {s} * ( amount - 1 ) );"),
        _t("SetTextureOffsetVal( 0 * 128, 512 );",
           "SetTextureOffsetVal( 0 * 128, 512 * {s} );"),
        _t("SetTextureOffsetVal( 0 * 128, 128 * ( amount - 1 ) );",
           "SetTextureOffsetVal( 0 * 128, 128 * {s} * ( amount - 1 ) );"),
        _t("local x = 128 * ((number - 6) % 4);",
           "local x = 128 * {s} * ((number - 6) % 4);"),
        # This line has no semicolon, so the LF ending is the terminator to
        # anchor on; rules run against the LF-normalized vendored trees.
        _t("        y = 768\n", "        y = 768 * {s}\n"),
        _t("y = 640;", "y = 640 * {s};"),
    ),

    "InGame/CityView/CityView.lua": (
        _t("local TEXOFFSET_BACKING_NOSHADOW_EMPTY\t= 128;",
           "local TEXOFFSET_BACKING_NOSHADOW_EMPTY\t= 128 * {s};"),
        _t("local TEXOFFSET_BACKING_NOSHADOW_FILLED = 192;",
           "local TEXOFFSET_BACKING_NOSHADOW_FILLED = 192 * {s};"),
        _t("local CITIZEN_ICON_SIZE = 64;",
           "local CITIZEN_ICON_SIZE = 64 * {s};"),
        _t("SetTextureOffsetVal( 0, 96+(48-(48 * percentComplete)));",
           "SetTextureOffsetVal( 0, (96+(48-(48 * percentComplete))) * {s});"),
    ),

    "InGame/Popups/CovertOpsPanel.lua": (
        _t("local ART_PROGRESS_BAR_WIDTH\t\t\t\t= 155;",
           "local ART_PROGRESS_BAR_WIDTH\t\t\t\t= 155 * {s};"),
        _t("local ICON_RANK_HEIGHT \t\t\t\t\t\t= 32;",
           "local ICON_RANK_HEIGHT \t\t\t\t\t\t= 32 * {s};"),
        _t("SetTextureOffsetVal(2+(operation.RequiredIntrigueLevel*20), 0);",
           "SetTextureOffsetVal((2+(operation.RequiredIntrigueLevel*20)) * {s}, 0);"),
        _t("SetTextureOffsetVal(2+(operation.RequiredIntrigueLevel*20)-20, 24);",
           "SetTextureOffsetVal((2+(operation.RequiredIntrigueLevel*20)-20) * {s}, 24 * {s});"),
    ),

    "InGame/Popups/QuestLogPopup.lua": (
        _t("local BANNER_IMAGE_HEIGHT\t= 46;",
           "local BANNER_IMAGE_HEIGHT\t= 46 * {s};"),
    ),

    "InGame/Popups/UnitUpgradePopup.lua": (
        _t("SetTextureOffsetVal( ((n-1)*32), (isActive and (isHighlight and 64 or 32) or 0) );",
           "SetTextureOffsetVal( ((n-1)*32) * {s}, (isActive and (isHighlight and 64 or 32) or 0) * {s} );"),
    ),

    # Tear-background u/v tables and the affinity-ring cell size. The meter
    # offsets (Amount*/NewAmount*) derive from the control's own GetSizeY and
    # follow the art on their own.
    "InGame/TechTree/TechTree.lua": (
        _t("g_textureTearFullNotResearched\t= { u=1,\tv=1 };",
           "g_textureTearFullNotResearched\t= { u=1 * {s},\tv=1 * {s} };"),
        _t("g_textureTearFullResearched\t\t= { u=69,\tv=1 };",
           "g_textureTearFullResearched\t\t= { u=69 * {s},\tv=1 * {s} };"),
        _t("g_textureTearFullSelected\t\t\t= { u=137,\tv=1 };",
           "g_textureTearFullSelected\t\t\t= { u=137 * {s},\tv=1 * {s} };"),
        _t("g_textureTearFullAvailable\t\t= { u=205,\tv=1 };",
           "g_textureTearFullAvailable\t\t= { u=205 * {s},\tv=1 * {s} };"),
        _t("g_textureTearLeafNotResearched\t= { u=1,\tv=70 };",
           "g_textureTearLeafNotResearched\t= { u=1 * {s},\tv=70 * {s} };"),
        _t("g_textureTearLeafResearched\t\t= { u=54,\tv=70 };",
           "g_textureTearLeafResearched\t\t= { u=54 * {s},\tv=70 * {s} };"),
        _t("g_textureTearLeafSelected\t\t\t= { u=107,\tv=70 };",
           "g_textureTearLeafSelected\t\t\t= { u=107 * {s},\tv=70 * {s} };"),
        _t("g_textureTearLeafAvailable\t\t= { u=160,\tv=70 };",
           "g_textureTearLeafAvailable\t\t= { u=160 * {s},\tv=70 * {s} };"),
        _t("local AFFINITY_RING_SIZE\t:number\t\t\t\t= 46;",
           "local AFFINITY_RING_SIZE\t:number\t\t\t\t= 46 * {s};"),
    ),

    # g_curIconSize.mainSize.x doubles as the IconTextureAtlases key in
    # CivIconHookup, so the tables stay stock and the calls are scaled.
    "InGame/WorldView/MPTurnPanel.lua": (
        _t("SetTextureSizeVal(g_curIconSize.mainSize.x, g_curIconSize.mainSize.y);",
           "SetTextureSizeVal(g_curIconSize.mainSize.x * {s}, g_curIconSize.mainSize.y * {s});"),
        _t("SetTextureSizeVal(g_curIconSize.iconSize.x, g_curIconSize.iconSize.y);",
           "SetTextureSizeVal(g_curIconSize.iconSize.x * {s}, g_curIconSize.iconSize.y * {s});"),
    ),

    "InGame/UnitFlagManager.lua": (
        _t("local texOffsetX : number = 192;",
           "local texOffsetX : number = 192 * {s};"),
        _t("texOffsetY = 64;", "texOffsetY = 64 * {s};"),
    ),

    "InGame/Diplomacy/DiplomacyOverview.lua": (
        _t("local relationshipOffset : number = 75*relationshipInfo.ID;",
           "local relationshipOffset : number = (75*relationshipInfo.ID) * {s};"),
        _t("local relationshipToOthersOffset : number = relationshipLevelToSelected * 30;",
           "local relationshipToOthersOffset : number = relationshipLevelToSelected * 30 * {s};"),
    ),

    "InGame/Diplomacy/WarSpoilsBuilder.lua": (
        _t("local PROGRESS_BAR_WIDTH : number = 155;",
           "local PROGRESS_BAR_WIDTH : number = 155 * {s};"),
        _t("local AFFINITY_RING_SIZE\t:number\t\t\t\t= 46;",
           "local AFFINITY_RING_SIZE\t:number\t\t\t\t= 46 * {s};"),
    ),

    "InGame/Diplomacy/States/DiplomacyState_Agreements.lua": (
        _t("local relationshipOffset : number = 75*relationshipInfo.ID;",
           "local relationshipOffset : number = (75*relationshipInfo.ID) * {s};"),
        _t("SetTextureOffsetVal(50,relationshipOffset);",
           "SetTextureOffsetVal(50 * {s},relationshipOffset);"),
        _t("local relationshipToOthersOffset : number = relationshipLevelToSelected * 30;",
           "local relationshipToOthersOffset : number = relationshipLevelToSelected * 30 * {s};"),
        _t("SetTextureOffsetVal(0, 56*(i-1));",
           "SetTextureOffsetVal(0, 56*(i-1) * {s});"),
    ),

    "InGame/Diplomacy/States/DiplomacyState_Relationship.lua": (
        _t("local offsetIncrementY : number = 67;",
           "local offsetIncrementY : number = 67 * {s};"),
        _t("SetTextureOffsetVal(0,reqImageOffsetY+34);",
           "SetTextureOffsetVal(0,reqImageOffsetY+(34 * {s}));"),
        _t("SetTextureOffsetVal(0,30*relationshipLevel.ID);",
           "SetTextureOffsetVal(0,(30*relationshipLevel.ID) * {s});"),
    ),

    "InGame/Diplomacy/States/DiplomacyState_Traits.lua": (
        _t("selectTraitOffsetX = 64;", "selectTraitOffsetX = 64 * {s};"),
        _t("selectTraitOffsetX = 32;", "selectTraitOffsetX = 32 * {s};"),
        _t("levelYOffset = 45;", "levelYOffset = 45 * {s};"),
        _t("local levelXOffset = (level-1)*66;",
           "local levelXOffset = (level-1)*66 * {s};"),
    ),

    "InGame/Popups/DiplomacySummaryPopup.lua": (
        _t("local relationshipOffset : number = 75*relationshipInfo.ID;",
           "local relationshipOffset : number = (75*relationshipInfo.ID) * {s};"),
        _t("SetTextureOffsetVal(50,relationshipOffset);",
           "SetTextureOffsetVal(50 * {s},relationshipOffset);"),
        _t("SetTextureOffsetVal(0,(i-1)*56);",
           "SetTextureOffsetVal(0,(i-1)*56 * {s});"),
    ),
}
