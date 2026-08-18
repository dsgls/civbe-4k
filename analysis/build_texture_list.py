#!/usr/bin/env python3
"""Final ui_textures.txt: every texture needing 2x conversion, with the exact
input file to feed the upscaler and its measured decoded size."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import GAME, STOCK_TREES, EXTRACTED, TEXTURE_LIST, ATLAS_DBS
import os, re, struct, sys, hashlib, collections

import lua_textures
from classify import Space, classify
from uixml import ATTR, iter_tags

ROOT = EXTRACTED
OUT = TEXTURE_LIST
DBS = ATLAS_DBS

# Base first, expansion second: where a name is in both, the expansion copy is
# the one the game loads.
SOURCES = [
    ("UITextures.fpk", "UITextures.fpk", "UITextures_converted"),
    ("MiscTextures.fpk", "MiscTextures.fpk", None),
    ("Expansion1UITextures.fpk", "Expansion1UITextures.fpk", "Expansion1UITextures_converted"),
]

TEXTURE_REFS = ("Texture", "MaskTexture", "ButtonTexture", "CheckTexture")
# Any .dds literal in Lua: SetTexture() and friends draw 1:1 like the XML refs.
LUA_DDS = re.compile(r'["\']([\w\-\. /\\]+?\.dds)["\']', re.I)
reasons = collections.defaultdict(set)
first_site = {}


def note(ref, reason, site=None):
    name = ref.strip().replace("\\", "/").rsplit("/", 1)[-1].lower()
    if name.endswith(".dds"):
        reasons[name].add(reason)
        if site and name not in first_site:
            first_site[name] = site


for tree_name, (pristine, _rel) in sorted(STOCK_TREES.items()):
    for dp, dn, fn in os.walk(pristine):
        for f in fn:
            path = os.path.join(dp, f)
            site = tree_name + ":" + os.path.relpath(path, pristine).replace("\\", "/")
            if f.lower().endswith(".xml"):
                text = open(path, encoding="utf-8", errors="replace").read()
                for element, s, e, _depth in iter_tags(text):
                    found = list(ATTR.finditer(text, s, e))
                    attrs = {m.group(1): m.group(2) for m in found}
                    # The font-icon atlas: <Atlas File=.../> carries the ref,
                    # the sibling <Icon> elements carry the cell coordinates.
                    if element == "Atlas" and "File" in attrs:
                        note(attrs["File"], "font-icon-cell", site)
                        continue
                    spaces = {a: classify(element, a, attrs) for a in attrs}
                    why = [a for a, sp in spaces.items() if sp is Space.TEXTURE]
                    if element == "Icon" and why:
                        reason = "font-icon-cell"
                    elif element in ("FlipAnim", "AIAnim") and why:
                        reason = "flipbook-sheet"
                    elif any(a.endswith("TexStart") or a.startswith("Slice") for a in why):
                        reason = "9-slice"
                    elif why:
                        reason = "atlas-subrect"
                    else:
                        # No texture-space coordinate, but the engine draws a
                        # plain image 1:1 from the texture's top-left (it never
                        # stretches to the control), so 1x art still breaks.
                        reason = "drawn-1to1"
                    for key in TEXTURE_REFS:
                        if key in attrs:
                            note(attrs[key], reason, site)
            elif f.lower().endswith(".lua"):
                text = open(path, encoding="utf-8", errors="replace").read()
                for m in LUA_DDS.finditer(text):
                    note(m.group(1), "drawn-1to1", site)
                if "SetTextureOffsetVal" not in text and "SetTextureSizeVal" not in text:
                    continue
                for ref in lua_textures.resolve(pristine, path, text):
                    note(ref, "lua-runtime-offset", site)

ROW = re.compile(r"<Row>(.*?)</Row>", re.S)
FIELD = re.compile(r"<(Filename)>(.*?)</\1>", re.S)
for path in DBS:
    if os.path.exists(path):
        for row in ROW.finditer(open(path, encoding="utf-8", errors="replace").read()):
            for m in FIELD.finditer(row.group(1)):
                note(m.group(2).strip(), "icon-atlas", "IconTextureAtlases database")

# Any .dds named anywhere else in the gameplay database: Lua reads such fields
# (e.g. PolicyBranchTypes.BackgroundImage) and hands them to SetTexture, which
# draws 1:1 like every other plain reference.
DB_DDS = re.compile(r"[\w\-. ]+?\.dds", re.I)
for root in [os.path.join(GAME, "assets", "Gameplay", "XML"),
             os.path.join(GAME, "assets", "DLC", "Expansion1", "Gameplay", "XML")]:
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if not f.lower().endswith(".xml"):
                continue
            path = os.path.join(dp, f)
            for m in DB_DDS.finditer(open(path, encoding="utf-8", errors="replace").read()):
                note(m.group(0), "database-ref", "gameplay database: " + f)


def dds_size(path):
    d = open(path, "rb").read(128)
    if d[:4] != b"DDS ":
        return None
    h, w = struct.unpack_from("<II", d, 12)
    return w, h


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    return struct.unpack(">II", head[16:24]) if head[:8] == b"\x89PNG\r\n\x1a\n" else None


def digest(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


# available material; later sources win
dds, png, owner = {}, {}, {}
for pack, ddsdir, pngdir in SOURCES:
    d = os.path.join(ROOT, ddsdir)
    if os.path.isdir(d):
        for f in os.listdir(d):
            dds[f.lower()] = os.path.join(d, f)
            owner[f.lower()] = pack
    if pngdir and os.path.isdir(os.path.join(ROOT, pngdir)):
        for f in os.listdir(os.path.join(ROOT, pngdir)):
            png[f.lower()] = os.path.join(ROOT, pngdir, f)

base_dir = os.path.join(ROOT, "UITextures.fpk")
exp_dir = os.path.join(ROOT, "Expansion1UITextures.fpk")


def expansion_differs(name):
    a, b = os.path.join(exp_dir, name), os.path.join(base_dir, name)
    return os.path.exists(a) and os.path.exists(b) and digest(a) != digest(b)


rows, missing = [], []
for name in sorted(reasons):
    stem = name[:-4]
    flags = []
    if expansion_differs(name) or expansion_differs(stem + "-index.dds"):
        flags.append("USE-EXPANSION-COPY")

    if stem + ".png" in png:
        path = png[stem + ".png"]
        form, size = "png", png_size(path)
    elif name in dds:
        path = dds[name]
        form, size = "dds", dds_size(path)
    else:
        missing.append(name)
        continue
    if not size:
        missing.append(name)
        continue

    rows.append(dict(
        pack=owner.get(name, "?"), name=name, form=form,
        rel=os.path.relpath(path, ROOT).replace("\\", "/"),
        dims="%dx%d" % size, pixels=size[0] * size[1],
        bytes=os.path.getsize(path),
        reasons=",".join(sorted(reasons[name])) + ((" " + " ".join(flags)) if flags else ""),
    ))

with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("# UI textures requiring 2x conversion to match the vendored ui/ trees\n#\n")
    fh.write("# Every texture the UI trees reference is listed: the engine draws a plain\n")
    fh.write("# image 1:1 from the texture's top-left and never stretches it to the\n")
    fh.write("# control (verified in game - 1x art renders quarter-size in its corner),\n")
    fh.write("# so 2x layout needs 2x art everywhere. The reason column records what\n")
    fh.write("# reads the texture: a texture-space coordinate (atlas sub-rect, 9-slice\n")
    fh.write("# rect, flipbook stride, font-icon cell, IconTextureAtlases row, Lua\n")
    fh.write("# SetTextureOffsetVal/SetTextureSizeVal), or drawn-1to1 for a plain ref.\n")
    fh.write("# Both UI trees are swept, base and Expansion1.\n#\n")
    fh.write("# input_file is the thing to upscale, relative to the extraction root, and\n")
    fh.write("# decoded is its MEASURED size. A .png input was a dictionary-coded pair\n")
    fh.write("# (<name>.dds blocks + <name>-index.dds); a .dds input is a plain texture.\n#\n")
    fh.write("# USE-EXPANSION-COPY: the name is in both UI packs with different content;\n")
    fh.write("# the Rising Tide copy is the one the game loads and the one listed here.\n#\n")
    fh.write("# pack\tfilename\tinput_file\tdecoded\tbytes\treasons\n\n")
    for r in sorted(rows, key=lambda r: (r["pack"], r["name"])):
        fh.write("%s\t%s\t%s\t%s\t%d\t%s\n"
                 % (r["pack"], r["name"], r["rel"], r["dims"], r["bytes"], r["reasons"]))

    if missing:
        fh.write("\n\n# Referenced by shipped data but absent from the whole install (%d):\n" % len(missing))
        fh.write("# in none of the install's .fpk archives and not loose on disk. There is nothing\n")
        fh.write("# to convert - these draw no art at 1x either. Mostly style definitions no\n")
        fh.write("# control uses, and screens inherited from Civ5, plus atlas rows for size\n")
        fh.write("# variants that were cut.\n#\n")
        fh.write("# dead\tfilename\treferenced_from\treasons\n\n")
        for n in missing:
            fh.write("# dead\t%s\t%s\t%s\n"
                     % (n, first_site.get(n, "?"), ",".join(sorted(reasons[n]))))

    per = collections.defaultdict(lambda: [0, 0])
    for r in rows:
        for reason in r["reasons"].split()[0].split(","):
            per[reason][0] += 1
            per[reason][1] += r["pixels"]
    fh.write("\n\n# Cost by reason (measured pixels at 1x; 2x output = pixels * 4):\n#\n")
    for reason, (count, px) in sorted(per.items(), key=lambda kv: -kv[1][1]):
        fh.write("#   %-20s %3d files  %6.1f Mpx  %7.1f MB RGBA@2x  %6.1f MB DXT5@2x\n"
                 % (reason, count, px / 1e6, px * 16 / 1e6, px * 4 / 1e6))
    px = sum(r["pixels"] for r in rows)
    fh.write("#   %-20s %3d files  %6.1f Mpx  %7.1f MB RGBA@2x  %6.1f MB DXT5@2x\n"
             % ("TOTAL", len(rows), px / 1e6, px * 16 / 1e6, px * 4 / 1e6))
    fh.write("#\n# The game is a 32-bit process (~3.5GB ceiling). The shipped packages are\n")
    fh.write("# raw RGBA so far and the game holds; switch the atlases to DXT if memory\n")
    fh.write("# becomes a problem.\n")

print("entries: %d  (png inputs %d, dds inputs %d)"
      % (len(rows), sum(1 for r in rows if r["form"] == "png"),
         sum(1 for r in rows if r["form"] == "dds")))
print("dead references: %d" % len(missing))
print("flagged USE-EXPANSION-COPY: %d" % sum(1 for r in rows if "USE-EXPANSION" in r["reasons"]))
print("measured: %.1f Mpx -> %.1f MB RGBA@2x, %.1f MB DXT5@2x" % (px / 1e6, px * 16 / 1e6, px * 4 / 1e6))
print("by pack:", dict(collections.Counter(r["pack"] for r in rows)))
print("written to", OUT)
