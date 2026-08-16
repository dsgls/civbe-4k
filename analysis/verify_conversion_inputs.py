#!/usr/bin/env python3
"""Check ui_textures.txt against the material on disk.

Every row must name an input file that exists and whose real dimensions match
the `decoded` column. Run this after re-extracting or re-converting anything.
"""
import os, sys, struct, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import EXTRACTED, TEXTURE_LIST


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    return struct.unpack(">II", head[16:24]) if head[:8] == b"\x89PNG\r\n\x1a\n" else None


def dds_size(path):
    with open(path, "rb") as fh:
        d = fh.read(128)
    if d[:4] != b"DDS ":
        return None
    h, w = struct.unpack_from("<II", d, 12)
    return w, h


rows = []
for line in open(TEXTURE_LIST, encoding="utf-8", errors="replace"):
    if line.startswith("#") or not line.strip():
        continue
    p = line.rstrip("\n").split("\t")
    if len(p) < 6:
        continue
    rows.append(dict(pack=p[0], name=p[1], rel=p[2], dims=p[3],
                     bytes=int(p[4]), reasons=p[5]))

missing, wrong, ok, pixels = [], [], 0, 0
for r in rows:
    path = os.path.join(EXTRACTED, r["rel"])
    if not os.path.exists(path):
        missing.append(r["name"])
        continue
    size = png_size(path) if path.lower().endswith(".png") else dds_size(path)
    if not size:
        missing.append(r["name"] + " (unreadable header)")
        continue
    if "%dx%d" % size != r["dims"]:
        wrong.append((r["name"], r["dims"], "%dx%d" % size))
        continue
    ok += 1
    pixels += size[0] * size[1]

print("rows: %d" % len(rows))
print("input present with correct dimensions: %d" % ok)
print("missing input files: %d" % len(missing))
for m in missing[:10]:
    print("   ", m)
print("dimension mismatches: %d" % len(wrong))
for w in wrong[:10]:
    print("    %-44s listed=%-12s actual=%s" % w)

print("\nby source pack:", dict(collections.Counter(r["pack"] for r in rows)))
print("by input form:", dict(collections.Counter(
    "png" if r["rel"].lower().endswith(".png") else "dds" for r in rows)))
print("\nmeasured decoded total: %.1f Mpx -> %.1f MB RGBA@2x, %.1f MB DXT5@2x"
      % (pixels / 1e6, pixels * 16 / 1e6, pixels * 4 / 1e6))

sys.exit(1 if (missing or wrong) else 0)
