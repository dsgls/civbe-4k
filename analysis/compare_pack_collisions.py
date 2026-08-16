#!/usr/bin/env python3
"""Do the colliding UI texture names really differ between the two packs?

Both sides are now official-tool output: the expansion pack extracted on its
own, and the base-game copy that won the earlier flat extraction.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import GAME, STOCK_UI, EXTRACTED, TEXTURE_LIST, ATLAS_DBS
import os, struct, hashlib, collections

EXP = os.path.join(GAME, "Resource/dx11/Expansion1UITextures.fpk")
BASE = os.path.join(GAME, "Resource.bak/dx11")


def hdr(path):
    d = open(path, "rb").read(128)
    if d[:4] != b"DDS ":
        return None
    h, w = struct.unpack_from("<II", d, 12)
    mips, = struct.unpack_from("<I", d, 28)
    pf, = struct.unpack_from("<I", d, 80)
    bits, = struct.unpack_from("<I", d, 88)
    if pf & 0x4:
        return w, h, bits, None
    total, mw, mh = 0, w, h
    for _ in range(max(mips, 1)):
        total += mw * mh * (bits // 8)
        mw, mh = max(1, mw // 2), max(1, mh // 2)
    return w, h, bits, total + 128


def digest(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


exp_files = sorted(f for f in os.listdir(EXP) if f.lower().endswith(".dds"))
print("expansion pack extracted on its own: %d dds" % len(exp_files))

# integrity of the fresh extraction
bad = []
for f in exp_files:
    p = os.path.join(EXP, f)
    h = hdr(p)
    if h and h[3] and abs(os.path.getsize(p) - h[3]) > 4:
        bad.append((f, os.path.getsize(p), h[3]))
print("  header-inconsistent: %d %s" % (len(bad), bad[:4]))

identical, differ, only_exp = [], [], []
for f in exp_files:
    b = os.path.join(BASE, f)
    if not os.path.exists(b):
        only_exp.append(f)
        continue
    e = os.path.join(EXP, f)
    if digest(e) == digest(b):
        identical.append(f)
    else:
        he, hb = hdr(e), hdr(b)
        differ.append((f,
                       "%dx%d" % (he[0], he[1]) if he else "?", os.path.getsize(e),
                       "%dx%d" % (hb[0], hb[1]) if hb else "?", os.path.getsize(b)))

print("\nnames present in BOTH packs: %d" % (len(identical) + len(differ)))
print("  byte-identical:        %d" % len(identical))
print("  REAL content difference: %d" % len(differ))
print("  only in the expansion:   %d" % len(only_exp))

print("\n%-40s %-12s %-11s %-12s %s" % ("name", "expansion", "bytes", "base", "bytes"))
for row in sorted(differ, key=lambda r: -r[2]):
    print("%-40s %-12s %-11d %-12s %d" % row)
