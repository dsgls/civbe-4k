# Civilization: Beyond Earth — 4K UI project

Beyond Earth's interface is authored in literal pixels against a ~1080p canvas
and the engine exposes no scaling lever (the exe offers only
`UIManager::GetScreenSizeVal`, a query). At 3840x2160 the whole UI renders at
roughly half its intended physical size.

**Phase 1 is done**: `ui/` holds the game's UI XML and Lua with the geometry,
font sizes and Lua layout arithmetic rescaled to 2x. Installing it is a copy.

**Phase 2 is the open work**: rescaling the .dds art so that atlas icons,
9-slice frames and font icons can grow too. Everything needed to start is in
this directory. Read *Engine facts* before touching anything — most of the
traps here are non-obvious and cost real time to rediscover.

---

## Layout

```
ui/                     the patched UI trees, at install-relative paths.
                        See "The vendored UI trees" below.
civbe-dds/              reads/writes UI texture .dds (Python, 115 tests). See its README.
ui_textures.txt         the phase-2 work list: 474 textures needing conversion.
extracted/              per-archive .fpk extractions + decoded PNGs
  UITextures.fpk/                 1642 .dds  (base game UI)
  UITextures_converted/            595 .png  (decoded dictionary pairs)
  Expansion1UITextures.fpk/        499 .dds  (Rising Tide UI)
  Expansion1UITextures_converted/  129 .png
  MiscTextures.fpk/                252 .dds  (3 files needed from here)
reference/
  assets-ui-stock/                    pristine Assets/UI
  assets-dlc-expansion1-ui-stock/     pristine Assets/DLC/Expansion1/UI
analysis/               scripts that produced and check ui_textures.txt
```

The `reference/` trees are the pristine stock baseline: they make the analysis
reproducible without a game install, they regenerate the texture list, and
diffing `ui/` against them shows exactly what the project changes. They keep
the stock CRLF line endings; everything vendored under `ui/` is LF-normalized.
Only XML and Lua are tracked — see `.gitignore`.

---

## The vendored UI trees

`ui/` mirrors the install: `ui/assets/UI` and `ui/assets/DLC/Expansion1/UI`.
It contains every stock `.xml`/`.lua` (546 files), with 2x baked in:

- every screen-space attribute and all-literal Lua layout call at 2x;
- every texture-space coordinate (atlas sub-rects, 9-slice geometry, state
  bands, flipbook strides, font-icon cells) at 2x — **the game's art must be
  at 2x too**, so do not install `ui/` without the phase-2 textures;
- the `IconHookup` offset arithmetic at 2x with the `IconTextureAtlases` keys
  left stock, plus a pin holding each hooked icon to one cell;
- the ~60 computed Lua texture offsets and the Lua-computed tech-web layout
  (`g_radiusScalar` and friends in `TechTree.lua`) at 2x;
- the fast menu: no staged fade-in, no legal popup.

The tree was generated from the stock files by a rule-driven sweep
(`civbe-uiscale`, deleted after use; see history around the "Bake scale 2"
commit) and certified attribute-by-attribute against an independent oracle:
19,771 screen-space and 6,582 texture-space values at exactly 2x, everything
else byte-identical. **From here on, `ui/` is edited directly** — the vendor
commit gives every change full diff context.

Install: copy the two trees over the install (they only replace `.xml`/`.lua`;
everything else in the install is untouched), plus the 2x textures when they
exist:

```bash
cp -r ui/assets "<install>"/
```

Files are LF; if the engine turns out to require CRLF, convert during install.
Restore: copy the same paths from `reference/` (or delete the loose files and
verify integrity through Steam).

---

## Engine facts

These were established by experiment against the shipped data. Several
contradict what you would reasonably assume.

### `.` and `,` are the same separator

The XML parser accepts either as the coordinate delimiter and Firaxis used
both. `AnchorSide="I.O"` appears 23 times against 24 of `AnchorSide="I,O"`;
`Size="300.200"` is a 300x200 sprite. **A dotted pair is not a float.** Reading
`45.45` as one number and doubling it yields `90.9`, which the engine parses as
90x9 — a naive float sweep silently mangles 68 live values this way, mostly
sizing icons and meters down to slivers.

### `Size` is sometimes the texture source rect

`IconSupport.lua`'s `IconHookup` sets only `SetTexture` and
`SetTextureOffsetVal` — the sampled width and height come from the *control's*
size. So doubling `Size` on an atlas-sampled control makes it read a 2x2 block
of neighbouring icons. Precedence, as implemented in `classify.py`:

1. A 9-sliced control (`SliceCorner`, `SliceTextureSize`, …) stretches its
   texture, so `Size` is screen-space even alongside `StateOffsetIncrement`.
2. Otherwise `TextureOffset` or `StateOffsetIncrement` on the element makes
   `Size` a source rect — texture-space.
3. Otherwise it is screen-space.

### `iconSize` is a database key, not a measurement

`IconHookup(offset, iconSize, atlas, control)` looks `iconSize` up in the
`IconTextureAtlases` table *and* multiplies it by the cell index to get a pixel
offset. Scale the key and the lookup misses. `ui/`'s `IconSupport.lua`
therefore rescales only the arithmetic, at two sites, and touches neither the
database nor any call site. It also pins the control to one cell inside
`IconHookup`, because controls that receive their `TextureOffset` at runtime
carry no static marker in the XML and would otherwise bleed.

### The atlas database over-declares its sheets

`IconsPerRow x IconsPerColumn` is an upper bound, not the image size.
`civsymbolatlas64.dds` is declared 8x8 icons and the art is 8x4;
`leaderportraits_256.dds` is declared 8x8 and is 8x1. Harmless to the engine
(`IconHookup` only bounds-checks and no index reaches the phantom rows) but it
will inflate any size estimate derived from it. **Measure the art, don't trust
the table.**

### The game is a 32-bit process

Both executables are `0x14c` / x86 with `LARGE_ADDRESS_AWARE`, so ~3.5 GB of
address space for everything. Blanket-upscaling all 972 MB of UI textures is
not an option; this is why the work list is selective and why the output must
be block-compressed.

### Loose files can override the archives

`config.ini` has `LooseFilesOverridePAK = 1` (already set). Note the qualifier
in the comment: *"if the loose file is newer"* — timestamps matter.

**Verified in game.** A loose `civilopedia_searchicon.dds` dropped at the root
of a UI tree (`Assets/DLC/Expansion1/UI/`) replaced the icon the Civilopedia
draws. Three things follow, and they decide the shape of phase 2:

- **A loose file in the DLC UI tree beats a texture packed in the base
  archive.** The original lives in `UITextures.fpk`, the override sat in
  `Assets/DLC/Expansion1/UI/`, and the override won — resolved by bare
  filename, with no `Art/` subdirectory needed. That is the same DLC-over-base
  precedence the XML follows, so it says nothing about the other direction:
  whether a loose file in `Assets/UI` overrides a texture the expansion owns is
  **untested**. Phase 2 sidesteps the question by planting everything in the
  DLC UI tree, which wins either way. (On an install without Rising Tide there
  is no such tree, and the base UI root is the only candidate.)
- **A plain DDS replaces a dictionary pair.** The stock texture is a pair —
  a 163x1 `A8B8G8R8` dictionary plus a 30x30 `L8` index. The override was a
  single plain `A8B8G8R8` file with no `-index.dds` sibling, and it won. So the
  encoder never has to emit dictionary pairs: converted art ships as plain DDS.
- The override was 14x6 against a 30x30 original and still drew, so the engine
  does not require the replacement to match the stock dimensions. How it treats
  the mismatch — stretch, clip, or letting the XML `Size` decide — is not
  established, and phase 2 outputs match the source dimensions anyway.

---

## The texture format

Every file is a stock Microsoft DDS: magic `DDS `, `dwSize` 124, no DX10
extension header, pixel data at offset 0x80. Any DDS reader opens them. The
base and expansion packs are identical in layout despite the different packfile
version — only the mix of pixel formats differs. Byte-exact size checks pass on
all 1417 non-index files.

### Firaxis metadata in the reserved fields

| Offset | DDS field | Content |
|--------|-----------|---------|
| 0x20   | `dwReserved1[0]` | `FTXT` magic |
| 0x24   | `dwReserved1[1..10]` | 40-byte NUL-padded usage name: `Interface`, `Interface Scalable`, `Strategic View`, `Stub Texture`, `Leader Diffuse (No Alpha)`, `Irradiance Cube`, … |
| 0x74   | `dwCaps3` + `dwCaps4` | 8-byte ASCII format tag: `COLOR`, `BC0nn`, `FICwwhh`, `COLOR_NA`, `Typeless` |

Two traps. 21 of the `forgeui_*.dds` carry **uninitialized memory** after the
usage name and in `dwReserved2` — raw pointer values, different in every file.
Read the name up to the first NUL and ignore `dwReserved2` (the only meaningful
value it ever holds is `0x30`, on the 11 `.fic` stubs below). And eight base
textures have no `FTXT` at all (`civbeicon`, `missingtexture`, `toppanelbar`,
`cubelight_ui`, the four `forgeui_toolslider*`); the game draws them anyway.

### Dictionary pairs

Most UI textures ship as **tile deduplication**, not as plain images. Chop the
image into NxN tiles, keep one copy of each distinct tile, and store the image
as a grid of references:

- `foo.dds` — the dictionary. An ordinary RGBA texture whose pixels are the
  distinct tiles, packed row-major into a rectangle.
- `foo-index.dds` — one texel per tile of the output, `L8` or `L16`
  (`DDPF_LUMINANCE`, mask `0xff` or `0xffff`). The texel *value* is a tile
  number, not a brightness.
- decoded image = `index_dims x N`

`civbe-dds/civbe_dds/pair.py` implements this; the whole of it is:

```
N     = int(tag[2:])            # "BC004" -> 4
cols  = dictionary_width // N   # tile slots per dictionary row
for each index texel (bx, by):
    k = index[by][bx]
    copy dictionary[(k // cols)*N …][(k % cols)*N …]  ->  out[by*N …][bx*N …]
```

Every output pixel is a verbatim copy, so decoding is lossless — and encoding
is equally mechanical, which matters for question 2 below. Confirmed by
`analysis/verify_decode.py`: all 724 pairs decode **byte-identical** to
the converted PNGs.

At N=1 a tile is one pixel, the dictionary is a colour table and the index is a
classic paletted image. That is the largest group, 313 of the 724.

**The tile size is in the header.** `BC0nn` at offset 0x74 is N in decimal —
`BC010` is 10, not 16. Nothing has to solve for N or measure a PNG.

| block | textures |     | block | textures |
|-------|----------|-----|-------|----------|
| 1x1   | 313      |     | 8x8   | 22       |
| 2x2   | 195      |     | 10x10 | 9        |
| 4x4   | 183      |     | 20x20 | 2        |

Blocks are always square. **Images usually are not** — 407 of 724 decoded PNGs
are non-square (`actionrowbackground` 433x55, `1920_leftside` 100x1200).
Index dimensions divide the image exactly in every case, and the dictionary is
never too small for the indices used. Note 10 and 20: N is not always a power
of two, so a decoder that guesses from 1/2/4/8/16 gets 11 textures wrong.
Read the tag.

Pairing is exact — 595 pairs in `UITextures.fpk`, 129 in
`Expansion1UITextures.fpk`, no orphan on either side. Every dictionary is
`A8B8G8R8` (RGBA byte order); the BGRA/RGBA split below affects plain textures
only. Index depth follows the distinct-tile count: `L8` where that is 256 or
fewer (292 files), `L16` above (429), with 3 files using `L16` unnecessarily.
533 of the 724 dictionaries are exactly full — capacity equals distinct tiles.

Across all 724, the scheme stores 630 MB of raw RGBA in 255 MB, but the wins
are wildly uneven and two edges are worth knowing:

| texture | N | dictionary | index | image | tiles | distinct |
|---------|---|------------|-------|-------|-------|----------|
| `256x256frame` | 4 | 68x32 | 64x64 L8 | 256x256 | 4096 | 136 |
| `buildingatlas` | 8 | 1472x1368 | 256x256 L16 | 2048x2048 | 65536 | 31462 |
| `be_exp1_traits_atlas_128` | 10 | 16x16 | 64x64 L8 | 640x640 | 4096 | **1** |
| `seededstartcargoselectback` | 20 | 1920x1920 | 80x45 L16 | 1600x900 | 3600 | **3600** |

`be_exp1_traits_atlas_128` and `be_exp1_foreign_policies_atlas_128` use a
single tile for the whole image — they are blank placeholders, and anything
that assumes an atlas has content will trip over them. At the other end,
photographic art dedupes to nothing: `seededstartcargoselectback` has no
repeated tile at all, so its pair costs 2.6x *more* than the raw image.

Decoding is already done: `extracted/*_converted/` holds a PNG per pair. Only
the 211 plain-DDS entries have no PNG, because they need no decode.

### Plain textures

The 693 files with no `-index` sibling:

| Pixel format | base | expansion |
|--------------|------|-----------|
| `A8B8G8R8` — R mask `0x000000ff`, bytes R,G,B,A | 167 | 86 |
| `A8R8G8B8` — R mask `0x00ff0000`, bytes B,G,R,A | 196 | 118 |
| DXT4 | 48 | 36 |
| DXT2 | 13 | — |
| DXT1 | 14 | 1 |
| DXT3 | 2 | — |
| DXT5 | 1 | — |
| fourCC 114 (`.fic` stub) | 11 | — |

**Both channel orders ship, and the masks tell the truth.** Read the masks per
file; do not hardcode an order. Confirmed by decoding both ways and comparing
against known art — `my2klogo.dds` (mask `0xff`) is the red 2K logo only as
R,G,B,A, `civilizationbe_risingtide_logo.dds` (mask `0xff0000`) is the blue
Rising Tide logo only as B,G,R,A. The split follows neither the usage name nor
the pack, so there is no shortcut.

**DXT2 and DXT4 are mislabelled.** Those fourCCs mean premultiplied alpha and
the data is not premultiplied: `colorred.dds` (DXT2) breaks `max(rgb) <= a` on
100% of its texels, `blue_centeroneturn_tallglow.dds` (DXT4) on 73%. Decode
DXT2 as DXT3 and DXT4 as DXT5, and do **not** divide out alpha — a converter
that honours the fourCC washes these out.

Three files are cubemaps carrying six faces (`dwCaps2` `0xFE00`, so 6x the
data): `cubelight_ui.dds` and the two `atlas_environment_*.dds`.

The 11 fourCC-114 files (`atlas_*`, `globe_*`) each have a `.fic` sidecar
holding the real payload — an opaque compressed blob with no magic — and a
`FICwwhh` tag giving the hex dimensions. Leader-scene art, not UI.

---

## Pack collisions — important

74 filenames exist in both UI packs and **67 differ in content**. The Rising
Tide copies are the ones the game loads: its atlas rows describe different
sheets (`resources2048` is 8x8 icons in the base database and 8x9 in the
expansion, because Rising Tide adds a resource row).

Extract the two packs **separately**. A tool that dumps every archive into one
directory silently resolves these by extraction order — the official SDK
unpacker does exactly this, and the base-game copy wins, which is backwards.
31 rows in `ui_textures.txt` are flagged `USE-EXPANSION-COPY`; their listed
`input_file` already points at the correct copy.

Only three archives matter, and all three are already extracted here:
`UITextures.fpk` (432 files), `Expansion1UITextures.fpk` (164),
`MiscTextures.fpk` (3).

---

## ui_textures.txt

Tab-separated: `pack`, `filename`, `input_file`, `decoded`, `bytes`, `reasons`.
`input_file` is relative to `extracted/` and is the thing to feed an upscaler —
a `.png` for a decoded dictionary pair, a `.dds` for a plain texture.
`decoded` is measured, not inferred.

A texture is listed exactly when a texture-space coordinate reads it: an atlas
sub-rect, a 9-slice rect, a flipbook stride, a font-icon cell, an
`IconTextureAtlases` row, or a Lua `SetTextureOffsetVal`/`SetTextureSizeVal`
call. Both UI trees are scanned, base and Expansion1. The XML side derives
from the same `analysis/classify.py` the 2x bake of `ui/` was verified
against; the Lua side resolves each call's
control to its XML element by ID (same-name XML, then directory, then tree),
which over-approximates on ID collisions — an extra stretched texture is
harmless, a missed sampled one is not. Textures merely stretched to fit a
control are deliberately absent — the engine scales those and they only get
softer.

Cost, measured:

```
icon-atlas           160 files    73.0 Mpx   1168.3 MB RGBA@2x   292.1 MB DXT5@2x
atlas-subrect         73 files     4.0 Mpx     63.2 MB RGBA@2x    15.8 MB DXT5@2x
lua-runtime-offset    36 files     2.5 Mpx     40.1 MB RGBA@2x    10.0 MB DXT5@2x
9-slice              225 files     2.5 Mpx     39.4 MB RGBA@2x     9.8 MB DXT5@2x
flipbook-sheet         3 files     0.3 Mpx      4.3 MB RGBA@2x     1.1 MB DXT5@2x
TOTAL                474 files    77.9 Mpx   1246.8 MB RGBA@2x   311.7 MB DXT5@2x
```

Only four source forms appear across the 474, and one carries almost all the
pixels:

| source form | files | pixels |
|-------------|-------|--------|
| dictionary pair (dictionary is RGBA) | 200 | 72.10 Mpx |
| plain `A8R8G8B8` (BGRA bytes) | 123 | 2.86 Mpx |
| plain `A8B8G8R8` (RGBA bytes) | 124 | 2.69 Mpx |
| plain DXT4 | 22 | 0.26 Mpx |
| plain DXT1 | 5 | 0.03 Mpx |

No DXT2/3/5, no cubemaps, no `.fic` stubs, none of the `FTXT`-less files — the
awkward corners of the packs all fall outside the list. The `forgeui_*`
reserved-field junk does not: 26 of the 27 DXT entries are `forgeui_*` and 20
of those carry it.

The tiers split by form. `icon-atlas` is 144 of 160 dictionary pairs and holds
93% of the pixels (72 of 77.9 Mpx) — that tier alone is the memory problem.
`9-slice` is 225 files, all but one of them small plain textures, and holds
every DXT entry. Mip chains follow the same split: all 200 pair sources are
single-level, while 233 of the 274 plain ones carry chains.

A trailing section lists 51 names referenced by shipped data but present in no
archive and not loose on disk — dead references (mostly unused `grid9*` style
definitions and screens inherited from Civ5). They draw nothing at 1x either.
Ignore them; there is nothing to convert.

---

## What phase 2 has to do

1. **Upscale** each `input_file` 2x. The inputs are already decoded, so an
   off-the-shelf model works; nothing needs to understand the block format to
   *read* it.
2. **Re-encode** to something the engine loads. Plain RGBA (`RAW32`) is what
   933 stock textures already use, so it is the safe target format — but see
   the memory ceiling: at 1.2 GB uncompressed for the full list, the icon
   atlases almost certainly need DXT.
3. **Place** the results loose at the DLC UI tree root
   (`Assets/DLC/Expansion1/UI/`) — one flat directory of plain DDS, no pairs,
   no `Art/` hierarchy to reproduce. Base-tree art goes there too; the DLC tree
   wins over both archives.
4. **Install the vendored `ui/` trees** alongside — their texture-space
   coordinates are already at 2x.

### Constraint: the texture scale is global

`ui/` bakes 2x into every texture-space coordinate. If only some art is
rescaled, the rest samples wrong. So it is **all 474 or none** — the "convert
the cheap tier first" idea would need per-texture coordinate edits in `ui/`,
which is real work, not a shortcut.

The engine reads texture coordinates from more places than the XML: about 40
Lua call sites compute a `SetTextureOffsetVal`/`SetTextureSizeVal` argument
from constants or expressions, and the tech-web layout is Lua arithmetic
(`GridRadius * g_radiusScalar` in `TechTree.lua`). All of these are already at
2x in `ui/`; when editing near a texture offset in the Lua, keep them
consistent — the wrong cell is drawn silently, not flagged.

Mouse-wheel zoom on the tech web is broken at 2x; the zoom code is not in the
UI Lua/XML and the cause is unestablished. This is the one known open UI bug.

---

## Open questions — verify these before building the pipeline

Each of these is cheap to test and expensive to get wrong.

1. ~~Where do loose overrides go?~~ **Answered** — the DLC UI tree root, by
   bare filename, for base-archive and expansion art alike. See *Loose files
   can override the archives*. Remember the "if the loose file is newer"
   clause.
2. ~~Will a plain DDS override replace a dictionary+index pair?~~ **Answered:
   yes.** A plain single-file override displaced a packed pair, so phase 2
   emits plain DDS and needs no pair encoder. `civbe-dds` still decodes
   every pair byte-exactly, which is what phase 2 *reads*; the encoder half is
   simply not needed. (`seededstartcargoselectback` remains the reminder that
   the pair format can inflate art that does not dedupe — an argument against
   ever writing pairs, not for it.) `civbe-dds` provides the plain-RGBA
   encoder this calls for.
3. **Does the engine accept DXT for UI textures?** Largely answered: of the 115
   stock DXT textures, 96 sit in the `Interface Scalable` and `Strategic View`
   usage groups and 26 are on the phase-2 work list (`forgeui_*` 9-slice frames
   and scrollbars). Only two are cubemaps. So the engine does draw DXT UI
   sprites. What is untested is DXT arriving as a *loose override* — fold it
   into the test for question 1.
4. **Does the `FTXT` tag matter?** Probably not required: eight stock textures
   ship without it (see *The texture format*) and draw fine. Still cheap to
   preserve, so preserve it until an override test says otherwise.
5. **Mipmaps.** Split cleanly by kind: all 724 dictionary textures are
   single-level, while 480 of the 693 plain ones carry chains (361 full to
   1x1, 119 stopping early). Match the original per file unless something
   proves otherwise.

---

## Commands

```bash
# install the patched UI (requires the 2x textures; see The vendored UI trees)
cp -r ui/assets "<install>"/

# civbe-dds: decode/encode UI textures for the upscale pipeline. See its README.
cd civbe-dds
python3 -m civbe_dds info   <path>...
python3 -m civbe_dds decode <dds>...  [-o DIR]
python3 -m civbe_dds encode <png>...  [-o DIR] [--like STOCK.dds | --group NAME]

# analysis
cd analysis
python3 verify_conversion_inputs.py    # every listed input exists, dims match
python3 build_texture_list.py          # regenerate ui_textures.txt
python3 derive_block_sizes.py          # block size of every dictionary pair
python3 verify_decode.py               # decode all 724 pairs, diff against the PNGs;
                                        # round-trip every plain texture through civbe_dds
python3 verify_decode.py 256x256frame  # decode one, write a PNG beside it
```

`civbe-dds` backs `verify_decode.py` and is the piece phase 2 needs: DDS
header parsing (including the `FTXT` fields), pixel-format naming, every
codec the packs contain, and PNG read/write. See `civbe-dds/README.md`.

`analysis/paths.py` holds every location; edit `GAME` if the install moves.

When `ui/` was generated, an oracle independent of the generator verified
every attribute against `reference/`: 12,795 + 6,976 screen-space and
3,927 + 2,655 texture-space values (base + Expansion1) at exactly 2x, with no
change to line counts, byte-order marks, attribute counts or order, and every
computed Lua texture-offset site accounted for. The generator and its checks
(`civbe-uiscale`, `verify_ui_sweep.py`, `verify_lua_sites.py`) live in the
history around the "Bake scale 2" commit.

## Gotchas

- A `LanguageSpecific` stylesheet dropped in by another tool overrides
  `Styles.xml` and silently pins fonts at whatever scale it was made for.
  Delete such files rather than leaving them. Font scaling needs no override
  file: `ui/` carries the scaled `FontSize` values in `Styles.xml` and in
  every `LanguageSpecific/*/LanguageSpecificStyles.xml`.
- A DLC UI file wins over the base file at the same relative path — confirmed
  in game: the Rising Tide main menu rendered stock-sized while the base
  `Assets/UI/FrontEnd/MainMenu.xml` was patched to 2x. Rising Tide's tree is
  150 XML/Lua files, 102 of them shadowing a base file, including a full
  `Styles.xml` that carries the font sizes. Any edit to a shadowed base file
  must be mirrored in the Expansion1 copy or it never takes effect.
- `IconSupport.lua` pins every runtime-hooked icon to one atlas cell
  (`SetSizeVal(iconSize * 2, ...)` next to the hookup). If a screen's icons
  look wrong, that pin is the first thing to suspect — it can be removed per
  control by editing `ui/`.
- Large copies out of this directory over WSL/NTFS occasionally fail with
  "Cannot allocate memory"; `tar cf - . | (cd dst && tar xf -)` works.
