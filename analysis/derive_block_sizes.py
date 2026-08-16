#!/usr/bin/env python3
"""Derive the true block size of every dictionary-coded texture from the
converted PNG, and check the dictionary is big enough to hold that many blocks."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import GAME, STOCK_UI, EXTRACTED, TOOL, TEXTURE_LIST, ATLAS_DBS
import os, struct, collections

ROOT = EXTRACTED
PAIRS = [
    ("UITextures.fpk", os.path.join(ROOT, "UITextures.fpk"), os.path.join(ROOT, "UITextures_converted")),
    ("Expansion1UITextures.fpk", os.path.join(ROOT, "Expansion1UITextures.fpk"),
     os.path.join(ROOT, "Expansion1UITextures_converted")),
]


def dds_hdr(path):
    d = open(path, "rb").read(128)
    if d[:4] != b"DDS ":
        return None
    h, w = struct.unpack_from("<II", d, 12)
    pf, = struct.unpack_from("<I", d, 80)
    bits, = struct.unpack_from("<I", d, 88)
    return w, h, (0 if pf & 0x4 else bits)


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    return struct.unpack(">II", head[16:24]) if head[:8] == b"\x89PNG\r\n\x1a\n" else None


sizes = collections.Counter()
nonsquare, badcover, odd = [], [], []
for pack, ddsdir, pngdir in PAIRS:
    names = set(os.listdir(ddsdir))
    for f in sorted(names):
        if not f.lower().endswith("-index.dds"):
            continue
        stem = f[:-len("-index.dds")]
        base = stem + ".dds"
        png = os.path.join(pngdir, stem + ".png")
        if base not in names or not os.path.exists(png):
            continue
        i = dds_hdr(os.path.join(ddsdir, f))
        d = dds_hdr(os.path.join(ddsdir, base))
        p = png_size(png)
        if not (i and d and p):
            continue
        if p[0] % i[0] or p[1] % i[1]:
            odd.append((stem, "index %dx%d" % (i[0], i[1]), "png %dx%d" % p))
            continue
        bw, bh = p[0] // i[0], p[1] // i[1]
        if bw != bh:
            nonsquare.append((stem, "%dx%d" % (bw, bh)))
        sizes[(bw, bh)] += 1
        # can the dictionary hold the indices actually used?
        data = open(os.path.join(ddsdir, f), "rb").read()[128:]
        vals = set(data) if i[2] == 8 else set(
            struct.unpack("<%dH" % (len(data) // 2), data[:len(data) // 2 * 2]))
        capacity = (d[0] // bw) * (d[1] // bh)
        if vals and max(vals) + 1 > capacity:
            badcover.append((stem, max(vals) + 1, capacity))

print("block sizes derived from ground truth:")
for (bw, bh), n in sorted(sizes.items()):
    print("   %2dx%-2d  %4d textures" % (bw, bh, n))
print("\nnon-square blocks: %d %s" % (len(nonsquare), nonsquare[:6]))
print("index dims do not divide png dims: %d %s" % (len(odd), odd[:6]))
print("dictionary too small for indices used: %d %s" % (len(badcover), badcover[:6]))
