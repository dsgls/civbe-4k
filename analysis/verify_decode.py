#!/usr/bin/env python3
"""Acceptance run for civbe_dds against the full texture corpus.

Two checks:

- every dictionary/index pair decodes byte-exact against the converted PNG
  in extracted/*_converted -- ground truth for the pair decoder, not just
  the dimensions.
- every plain texture in the three packs round-trips through the encoder:
  decode, write, decode again, and compare RGBA. That exercises every pixel
  format the corpus contains (DXT1/2/3/4/5, L8, L16, both 32-bit channel
  orders), which the unit tests can only cover with synthetic fixtures.

Run after touching civbe-dds, or to re-derive the block sizes without
trusting the header tag.

With arguments, decodes those textures instead and writes <name>.png into the
current directory; an argument may be a bare texture name or a path.
"""
import collections
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paths import DDS_TOOL, EXTRACTED

sys.path.insert(0, DDS_TOOL)
import civbe_dds
from civbe_dds.decode import UnsupportedFormatError
from civbe_dds.pair import is_pair

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


def plain_textures():
    """Every .dds in the packs that is neither an index file nor a
    dictionary half of a pair -- what civbe_dds.read decodes without going
    through pair.decode_pair."""
    for pack, _ in PACKS:
        pack_dir = os.path.join(EXTRACTED, pack)
        if not os.path.isdir(pack_dir):
            continue
        for name in sorted(os.listdir(pack_dir)):
            if not name.endswith(".dds") or name.endswith("-index.dds"):
                continue
            path = os.path.join(pack_dir, name)
            if not is_pair(path):
                yield pack, name, path


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
        image = civbe_dds.read(path)
        out = os.path.basename(path)[:-len(".dds")] + ".png"
        civbe_dds.write_png(out, image)
        print("%s  %dx%d  -> %s" % (os.path.basename(path), image.width, image.height, out))
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
    image = civbe_dds.read(path)
    truth = civbe_dds.read_png(reference)
    if (truth.width, truth.height) != (image.width, image.height):
        bad.append((stem, "%dx%d vs png %dx%d" %
                    (image.width, image.height, truth.width, truth.height)))
    elif truth.rgba != image.rgba:
        wrong = sum(1 for i in range(0, len(truth.rgba), 4)
                    if truth.rgba[i:i + 4] != image.rgba[i:i + 4])
        bad.append((stem, "%d of %d pixels differ" % (wrong, image.width * image.height)))
    else:
        blocks[int(civbe_dds.header(path).tag[2:])] += 1
    checked += 1

print("pairs decoded: %d" % checked)
print("block sizes:   %s" % ", ".join(
    "%dx%d %d" % (n, n, c) for n, c in sorted(blocks.items())))
print("pair mismatches: %d" % len(bad))
for stem, why in bad[:20]:
    print("   %-44s %s" % (stem, why))

roundtripped = 0
skipped = 0
rt_bad = []
with tempfile.TemporaryDirectory() as tmp:
    scratch = os.path.join(tmp, "roundtrip.dds")
    for pack, name, path in plain_textures():
        try:
            image = civbe_dds.read(path)
        except UnsupportedFormatError:
            skipped += 1
            continue
        civbe_dds.write(scratch, image)
        back = civbe_dds.read(scratch)
        if (back.width, back.height) != (image.width, image.height) or back.rgba != image.rgba:
            rt_bad.append("%s/%s" % (pack, name))
        else:
            roundtripped += 1

print()
print("plain textures round-tripped: %d" % roundtripped)
print("skipped (unsupported format, e.g. .fic stubs): %d" % skipped)
print("round-trip mismatches: %d" % len(rt_bad))
for name in rt_bad[:20]:
    print("   %s" % name)

sys.exit(1 if bad or rt_bad else 0)
