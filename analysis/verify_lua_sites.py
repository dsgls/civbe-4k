#!/usr/bin/env python3
"""Acceptance check: every Lua texture-offset call site is accounted for.

Three assertions over the stock reference trees:

1. Every rule in civbe_uiscale.luasites matches the stock text somewhere, so a
   typo or a diverging game patch cannot leave a rule silently inert.
2. Every live `SetTextureOffsetVal`/`SetTextureSizeVal` call site is either
   all-literal (the generic luapatch rescales it), textually rewritten by a
   site rule, or on the COVERED map below naming the constant rule or reason
   that handles it. An unaccounted site fails the check.
3. Every texture those files sample resolves to a ui_textures.txt entry, so
   nothing the Lua offsets into is missing from the 2x work list.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import STOCK_TREES, TEXTURE_LIST, TOOL

sys.path.insert(0, TOOL)
import lua_textures
from civbe_uiscale.luapatch import _TEXTURE_CALLS, _comment_spans, _inside
from civbe_uiscale.luasites import SITES

CALL = re.compile(r"(?:SetTextureOffsetVal|SetTextureSizeVal)\s*\(")

# Call sites no rule rewrites textually, keyed by a marker that must appear in
# the site's source. kind "constant": the value is fed by a scaled definition,
# and `detail` must appear in one of the file's rule.old strings. kind
# "handled": scaled elsewhere or inherently scale-free, `detail` says why.
COVERED = [
    ("IconSupport.lua", "(offset % numCols) * iconSize",
     "handled", "rescaled by patch_icon_support"),
    ("FrontEnd/Multiplayer/StagingRoom.lua", "TEXTURE_OFFSET_CHECK_OFF",
     "constant", "TEXTURE_OFFSET_CHECK_OFF"),
    ("FrontEnd/Multiplayer/StagingRoom.lua", "TEXTURE_OFFSET_CHECK_ON",
     "handled", "offset is zero at any scale"),
    ("InGame/TaskList.lua", "SetTextureOffsetVal(0, iOffset)",
     "constant", "iOffset = 96;"),
    ("InGame/CityView/CityView.lua", "TEXOFFSET_BACKING_NOSHADOW_EMPTY",
     "constant", "TEXOFFSET_BACKING_NOSHADOW_EMPTY"),
    ("InGame/CityView/CityView.lua", "CITIZEN_ICON_SIZE",
     "constant", "CITIZEN_ICON_SIZE"),
    ("InGame/Popups/CovertOpsPanel.lua", "ICON_RANK_HEIGHT",
     "constant", "ICON_RANK_HEIGHT"),
    ("InGame/Popups/CovertOpsPanel.lua", "SetTextureOffsetVal(barNext",
     "constant", "ART_PROGRESS_BAR_WIDTH"),
    ("InGame/Popups/CovertOpsPanel.lua", "SetTextureOffsetVal( barNext",
     "constant", "ART_PROGRESS_BAR_WIDTH"),
    ("InGame/Popups/CovertOpsPanel.lua", "SetTextureOffsetVal(barCurrent",
     "constant", "ART_PROGRESS_BAR_WIDTH"),
    ("InGame/Popups/CovertOpsPanel.lua", "SetTextureOffsetVal( barCurrent",
     "constant", "ART_PROGRESS_BAR_WIDTH"),
    ("InGame/Popups/QuestLogPopup.lua", "BANNER_IMAGE_HEIGHT",
     "constant", "BANNER_IMAGE_HEIGHT"),
    ("InGame/YieldIconManager.lua", "GetNumberOffset",
     "constant", "y = 640;"),
    ("InGame/TechTree/TechTree.lua", "m_textureBgLeaf",
     "constant", "g_textureTearLeaf"),
    ("InGame/TechTree/TechTree.lua", "m_textureBgFull",
     "constant", "g_textureTearFull"),
    ("InGame/TechTree/TechTree.lua", "m_affinityRingUVIndex",
     "constant", "AFFINITY_RING_SIZE"),
    ("InGame/TechTree/TechTree.lua", ", nextHeight",
     "handled", "derived from the control's GetSizeY; follows the 2x art"),
    ("InGame/TechTree/TechTree.lua", ", thisHeight",
     "handled", "derived from the control's GetSizeY; follows the 2x art"),
    ("InGame/UnitFlagManager.lua", "texOffsetX, texOffsetY",
     "constant", "texOffsetX"),
    ("InGame/Diplomacy/DiplomacyOverview.lua",
     "SetTextureOffsetVal(0,relationshipOffset)",
     "constant", "75*relationshipInfo.ID"),
    ("InGame/Diplomacy/DiplomacyOverview.lua",
     "SetTextureOffsetVal(0, relationshipToOthersOffset)",
     "constant", "relationshipLevelToSelected * 30"),
    ("InGame/Diplomacy/WarSpoilsBuilder.lua", "SetTextureOffsetVal(barCurrent",
     "constant", "PROGRESS_BAR_WIDTH"),
    ("InGame/Diplomacy/WarSpoilsBuilder.lua", "m_affinityRingUVIndex",
     "constant", "AFFINITY_RING_SIZE"),
    ("InGame/Diplomacy/States/DiplomacyState_Agreements.lua",
     "SetTextureOffsetVal(0, relationshipToOthersOffset)",
     "constant", "relationshipLevelToSelected * 30"),
    ("InGame/Diplomacy/States/DiplomacyState_Relationship.lua",
     "SetTextureOffsetVal(0,reqImageOffsetY);",
     "constant", "offsetIncrementY"),
    ("InGame/Diplomacy/States/DiplomacyState_Traits.lua",
     "SetTextureOffsetVal(selectTraitOffsetX,0)",
     "constant", "selectTraitOffsetX = 64;"),
    ("InGame/Diplomacy/States/DiplomacyState_Traits.lua",
     "SetTextureOffsetVal(levelXOffset, levelYOffset)",
     "constant", "levelXOffset"),
]

failures = []


def check(ok, message):
    if not ok:
        failures.append(message)


def read(path):
    # The stock reference trees are CRLF but the rules run against the
    # LF-normalized vendored trees, so the normalizing read is the right model.
    return open(path, encoding="utf-8", errors="replace").read()


def lua_files():
    """(tree name, rel posix path, absolute path, text) for every stock Lua
    with a texture-setter call."""
    for name, (pristine, _rel) in sorted(STOCK_TREES.items()):
        for dp, dn, fn in os.walk(pristine):
            for f in sorted(fn):
                if not f.lower().endswith(".lua"):
                    continue
                path = os.path.join(dp, f)
                text = read(path)
                if CALL.search(text):
                    rel = os.path.relpath(path, pristine).replace(os.sep, "/")
                    yield name, rel, path, text


def rules_match_stock(files):
    """Assertion 1: no rule is inert against the stock trees."""
    texts = {}
    for _name, rel, _path, text in files:
        texts.setdefault(rel, []).append(text)
    for rel, rules in sorted(SITES.items()):
        for rule in rules:
            hits = sum(text.count(rule.old) for text in texts.get(rel, []))
            check(hits > 0, "inert rule for %s: %r" % (rel, rule.old[:60]))


def site_snippet(text, match):
    start = text.rfind("\n", 0, match.start()) + 1
    return text[start:start + 200]


def sites_accounted_for(files):
    """Assertion 2: literal, rewritten by a rule, or on the coverage map."""
    checked = 0
    for name, rel, _path, text in files:
        spans = _comment_spans(text)
        literal = {m.start("name") for m in _TEXTURE_CALLS.finditer(text)}
        rules = SITES.get(rel, ())
        for m in CALL.finditer(text):
            if _inside(spans, m.start()) or m.start() in literal:
                continue
            snippet = site_snippet(text, m)
            checked += 1
            if any(rule.old in snippet for rule in rules):
                continue
            entry = next((c for c in COVERED
                          if c[0] == rel and c[1] in snippet), None)
            if entry is None:
                failures.append("unaccounted call site %s %s: %s"
                                % (name, rel, snippet.strip()[:80]))
            elif entry[2] == "constant":
                check(any(entry[3] in rule.old for rule in rules),
                      "coverage entry names no rule: %s %r" % (rel, entry[3]))
    return checked


def coverage_map_is_live(files):
    """Every COVERED entry matches some site, so the map cannot rot."""
    texts = {}
    for _name, rel, _path, text in files:
        texts.setdefault(rel, []).append(text)
    for rel, marker, _kind, _detail in COVERED:
        hits = sum(text.count(marker) for text in texts.get(rel, []))
        check(hits > 0, "dead coverage entry: %s %r" % (rel, marker))


def textures_are_listed(files):
    """Assertion 3: everything the Lua samples is on the work list."""
    known = set()
    for line in open(TEXTURE_LIST, encoding="utf-8"):
        if line.startswith("# dead\t"):
            known.add(line.split("\t")[1].strip().lower())
        elif not line.startswith("#") and line.strip():
            known.add(line.split("\t")[1].strip().lower())

    resolved = 0
    for name, rel, path, text in files:
        pristine = STOCK_TREES[name][0]
        for ref in lua_textures.resolve(pristine, path, text):
            base = ref.strip().replace("\\", "/").rsplit("/", 1)[-1].lower()
            if not base.endswith(".dds"):
                continue
            resolved += 1
            check(base in known,
                  "texture not on ui_textures.txt: %s (from %s %s)"
                  % (base, name, rel))
    return resolved


def main():
    files = list(lua_files())
    rules_match_stock(files)
    checked = sites_accounted_for(files)
    coverage_map_is_live(files)
    resolved = textures_are_listed(files)

    rule_count = sum(len(rules) for rules in SITES.values())
    print("checked %d Lua files, %d site rules, %d computed call sites, "
          "%d texture refs" % (len(files), rule_count, checked, resolved))
    if failures:
        print("FAILURES (%d):" % len(failures))
        for f in failures:
            print("  -", f)
        return 1
    print("ALL LUA SITE CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
