#!/usr/bin/env python3
"""Decode every dictionary/index pair and check it against the converted PNG.

The PNGs in extracted/*_converted are the ground truth, so a byte-exact match
proves the decoder in dds.py, not just the dimensions. Run it after touching
dds.py, or to re-derive the block sizes without trusting the header tag.

With arguments, decodes those textures instead and writes <name>.png into the
current directory; an argument may be a bare texture name or a path.
"""
import os, sys, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import EXTRACTED
import dds

PACKS = [("UITextures.fpk", "UITextures_converted"),
         ("Expansion1UITextures.fpk", "Expansion1UITextures_converted"),
         ("MiscTextures.fpk", "MiscTextures_converted")]


def pairs():
    for pack, converted in PACKS:
        pack_dir = os.path.join(EXTRACTED, pack)
        if not os.path.isdir(pack_dir):
            continue
        for name in sorted(os.listdir(pack_dir)):
            if name.endswith("-index.dds"):
                yield pack, converted, name[:-len("-index.dds")]


def resolve(arg):
    if os.path.exists(arg):
        return arg
    for pack, _ in PACKS:
        cand = os.path.join(EXTRACTED, pack, arg if arg.endswith(".dds") else arg + ".dds")
        if os.path.exists(cand):
            return cand
    sys.exit("no such texture: %s" % arg)


if len(sys.argv) > 1:
    for arg in sys.argv[1:]:
        path = resolve(arg)
        w, h, rgba = dds.decode_pair(path)
        out = os.path.basename(path)[:-len(".dds")] + ".png"
        dds.write_png(out, w, h, rgba)
        print("%s  %dx%d  -> %s" % (os.path.basename(path), w, h, out))
    raise SystemExit

checked = 0
blocks = collections.Counter()
bad = []
for pack, converted, stem in pairs():
    path = os.path.join(EXTRACTED, pack, stem + ".dds")
    reference = os.path.join(EXTRACTED, converted, stem + ".png")
    if not os.path.exists(reference):
        bad.append((stem, "no converted PNG"))
        continue
    w, h, rgba = dds.decode_pair(path)
    gw, gh, nch, truth = dds.read_png(reference)
    if (gw, gh, nch) != (w, h, 4):
        bad.append((stem, "%dx%d/%dch vs png %dx%d/%dch" % (w, h, 4, gw, gh, nch)))
    elif truth != rgba:
        wrong = sum(1 for i in range(0, len(truth), 4) if truth[i:i + 4] != rgba[i:i + 4])
        bad.append((stem, "%d of %d pixels differ" % (wrong, w * h)))
    else:
        blocks[int(dds.header(path)["tag"][2:])] += 1
    checked += 1

print("pairs decoded: %d" % checked)
print("block sizes:   %s" % ", ".join(
    "%dx%d %d" % (n, n, c) for n, c in sorted(blocks.items())))
print("mismatches:    %d" % len(bad))
for stem, why in bad[:20]:
    print("   %-44s %s" % (stem, why))
sys.exit(1 if bad else 0)
