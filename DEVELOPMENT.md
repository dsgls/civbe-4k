# Development reference

How the patch works and how to rebuild any part of it. Read *Engine facts*
before touching anything — most of the traps are non-obvious and cost real
time to rediscover.

## Layout

```
ui/                     the patched UI trees, at install-relative paths
civbe-dds/              reads/writes UI texture .dds (Python, 115 tests). See its README.
civbe-upscale/          2x upscaler (PNG in, PNG out). See its README.
ui_textures.txt         the texture work list: 950 textures, generated
extracted/              per-archive .fpk extractions + decoded PNGs
  UITextures.fpk/                 1642 .dds  (base game UI)
  UITextures_converted/            595 .png  (decoded dictionary pairs)
  Expansion1UITextures.fpk/        499 .dds  (Rising Tide UI)
  Expansion1UITextures_converted/  129 .png
  MiscTextures.fpk/                252 .dds  (3 files needed from here)
  decoded/                         every non-index texture as PNG, per pack
reference/
  assets-ui-stock/                    pristine Assets/UI
  assets-dlc-expansion1-ui-stock/     pristine Assets/DLC/Expansion1/UI
analysis/               scripts that produce and check ui_textures.txt
install.py              installs ui/ + the texture package, patches config.ini
package-textures.sh     builds and uploads a texture package
```

The `reference/` trees are the pristine stock baseline: they regenerate the
texture list, and diffing `ui/` against them shows exactly what the project
changes. They keep stock CRLF; everything under `ui/` is LF-normalized. Only
XML and Lua are tracked — see `.gitignore`.

## The vendored UI trees

`ui/` mirrors the install: `ui/assets/UI` and `ui/assets/DLC/Expansion1/UI`,
every stock `.xml`/`.lua` (546 files) with 2x baked in:

- every screen-space attribute and Lua layout value at 2x — literals in layout
  calls, file-level layout constants, and the pixel terms of mixed
  expressions (`GetSizeX() + padding`);
- every texture-space coordinate (atlas sub-rects, 9-slice geometry, state
  bands, flipbook strides, font-icon cells) at 2x;
- the `IconHookup` offset arithmetic at 2x with the `IconTextureAtlases` keys
  left stock, plus a pin holding each hooked icon to one cell;
- the fast menu: no staged fade-in, no legal popup.

The initial tree came from a rule-driven sweep (`civbe-uiscale`, deleted after
use; see history around the "Bake scale 2" commit); everything since is edited
directly. The XML side is verifiable at any time: every attribute
`analysis/classify.py` calls pixel-space must be exactly 2x its `reference/`
counterpart, with the intentional fast-menu changes the only exceptions.

`ui/` and the texture package must match: coordinates and art are both 2x, so
installing one without the other samples wrong everywhere. It is all 950
textures or none — "convert the cheap tier first" would need per-texture
coordinate edits.

## The texture package

Textures ship as a generic package on git.dsg.is because they are far too
large to vendor. `install.py` pins `TEXTURE_VERSION`/`TEXTURE_SHA256`,
downloads once into `~/.cache/civbe-4k`, verifies, and extracts into the game
directory. All overrides land flat in `Assets/DLC/Expansion1/UI/` — the engine
resolves loose overrides by bare filename, and the DLC tree beats both
archives.

Rebuilding after a list change:

```bash
# 1. stage 1x PNGs for the new entries: pairs from extracted/*_converted/,
#    plain textures from extracted/decoded/<pack>/
# 2. upscale (CUDA shell; resumable, output files are the progress state)
cd civbe-upscale
nix-shell shell.nix --option max-jobs 1 --cores 4 \
  --run 'python -m civbe_upscale batch <in-1x> <out-2x> --upscaler animesharp-v4'
# 3. encode each output against its stock header
cd ../civbe-dds
python3 -m civbe_dds encode <png> --like ../extracted/<pack>/<name>.dds -o <dest>
# 4. package (writes into install.py's cache, uploads, prints the new pins)
./package-textures.sh <encoded-root> <version>
# 5. update TEXTURE_VERSION / TEXTURE_SHA256 in install.py
```

Shipped packages are plain RGBA (`A8B8G8R8`), single level, `tag=COLOR`, usage
group copied from the stock file, upscaled with `animesharp-v4`. The 32-bit
game process (~3.5 GB, `LARGE_ADDRESS_AWARE`) holds ~3 GB of decoded texture
so far; if it stops holding, the icon atlases are the first candidates for
DXT.

## Engine facts

Established by experiment. Several contradict what you would assume.

### `.` and `,` are the same separator

The XML parser accepts either as the coordinate delimiter and Firaxis used
both: `Size="300.200"` is a 300x200 sprite. **A dotted pair is not a float** —
reading `45.45` as one number and doubling it yields `90.9`, which parses as
90x9. Space also appears as a separator (`Size="256 30"`), as do stray
trailing commas (`Size="32,32,"`).

### `Size` is sometimes the texture source rect

`IconHookup` sets only `SetTexture` and `SetTextureOffsetVal` — the sampled
width and height come from the *control's* size. Precedence, as implemented in
`analysis/classify.py`:

1. A 9-sliced control (`SliceCorner`, `SliceTextureSize`, …) stretches its
   texture, so `Size` is screen-space even alongside `StateOffsetIncrement`.
2. Otherwise `TextureOffset` or `StateOffsetIncrement` on the element makes
   `Size` a source rect — texture-space.
3. Otherwise it is screen-space.

### Plain images are drawn 1:1, never stretched

A non-9-slice control samples a source rect equal to its screen-space `Size`
from the texture's top-left and draws it texel-per-pixel; a control with no
`Size` draws the texture at its natural size. Nothing stretches art to fit a
control unless a `StretchMode` attribute says so (45 uses in the whole UI).
A Button also indexes its state bands by the control height. Consequence:
**every referenced texture needs 2x art** — there is no "merely stretched, the
engine rescales it" category.

### `iconSize` is a database key, not a measurement

`IconHookup(offset, iconSize, atlas, control)` looks `iconSize` up in the
`IconTextureAtlases` table *and* multiplies it by the cell index. Scale the
key and the lookup misses. `ui/`'s `IconSupport.lua` rescales only the
arithmetic and pins each hooked control to one cell; every call site keeps the
stock key. When a Lua variable serves both as a hookup key and a pixel stride,
it is split in two.

### The atlas database over-declares its sheets

`IconsPerRow x IconsPerColumn` is an upper bound, not the image size
(`civsymbolatlas64.dds` is declared 8x8 and the art is 8x4). Harmless to the
engine but it inflates size estimates. **Measure the art, don't trust the
table.**

### Loose files override the archives

`config.ini` needs `LooseFilesOverridePAK = 1` (install.py sets it). The
comment's qualifier is real: the loose file must be *newer* than the archive.
Verified in game:

- A loose file at the DLC UI tree root beats a texture packed in the base
  archive, resolved by bare filename — so everything installs flat into
  `Assets/DLC/Expansion1/UI/`.
- A plain single-file DDS displaces a packed dictionary/index pair, so
  converted art ships as plain DDS and no pair encoder exists.
- The replacement need not match stock dimensions to draw.

### Texture names come from four places

The work list must cover all of them: XML texture attributes, Lua `.dds`
string literals, the `IconTextureAtlases` database, and **other gameplay
database fields** (`PolicyBranchTypes.BackgroundImage` and friends) that Lua
passes to `SetTexture`. The font-icon atlases are a fifth wrinkle: the
`FontIcons` XMLs put the texture on an `<Atlas File=…>` element and the cell
coordinates on sibling `<Icon>` elements.

## The texture format

Every file is a stock Microsoft DDS: magic `DDS `, no DX10 header, data at
0x80. Firaxis metadata sits in the reserved fields: `FTXT` magic at 0x20, a
40-byte usage name (`Interface`, `Interface Scalable`, …), and an 8-byte
format tag at 0x74 (`COLOR`, `BC0nn`, `FICwwhh`, …). A few files carry
uninitialized memory after the usage name, and eight ship with no `FTXT` at
all; the game draws them anyway.

### Dictionary pairs

Most UI textures ship as tile deduplication: `foo.dds` is a dictionary of
distinct NxN tiles, `foo-index.dds` (`L8`/`L16`) maps each output tile to a
dictionary slot; decoded image = index dims x N. N is in the `BC0nn` tag —
read it, it is not always a power of two (10 and 20 occur). Decoding is
lossless; `civbe-dds` implements it and `extracted/*_converted/` holds a PNG
per pair. Two blank placeholder atlases (`be_exp1_traits_atlas_128`,
`be_exp1_foreign_policies_atlas_128`) are a single tile repeated — anything
assuming an atlas has content trips over them.

### Plain textures

Both `A8B8G8R8` (RGBA bytes) and `A8R8G8B8` (BGRA bytes) ship — **read the
masks per file**, the split follows no rule. DXT2/DXT4 files are mislabelled:
the data is not premultiplied, so decode them as DXT3/DXT5 and do not divide
out alpha. Three cubemaps and eleven fourCC-114 `.fic` stubs exist; none are
on the work list.

## Pack collisions

74 filenames exist in both UI packs and 67 differ in content; the Rising Tide
copy is the one the game loads. Extract the packs **separately** — a tool that
dumps every archive into one directory resolves collisions by extraction
order, and the official SDK unpacker gets it backwards. Rows flagged
`USE-EXPANSION-COPY` in `ui_textures.txt` already point at the right copy.

## ui_textures.txt

Tab-separated: `pack`, `filename`, `input_file`, `decoded`, `bytes`,
`reasons`. Generated by `analysis/build_texture_list.py`; every texture any of
the four reference sources names is listed (see *Texture names come from four
places*). `input_file` is the thing to feed the upscaler — a `.png` for a
decoded pair, a `.dds` for a plain texture — and `decoded` is measured. A
trailing section lists dead references; there is nothing to convert for them.

## Commands

```bash
python3 install.py                     # install everything (see README.md)
python3 install.py --no-textures       # ui/ only - fast loop for Lua/XML fixes

cd analysis
python3 build_texture_list.py          # regenerate ui_textures.txt
python3 verify_conversion_inputs.py    # every listed input exists, dims match
python3 verify_decode.py               # decode all pairs, diff against PNGs

cd civbe-dds
python3 -m civbe_dds info   <path>...
python3 -m civbe_dds decode <dds>...  [-o DIR]
python3 -m civbe_dds encode <png>...  [-o DIR] [--like STOCK.dds | --group NAME]
```

`analysis/paths.py` holds every location; edit `GAME` and `CONFIG` if the
install moves.

## Debugging a scaling artifact

Symptoms map to causes reliably:

| Symptom | Cause |
|---|---|
| Art at half size in the top-left of its slot / frame too small | Texture missing from the work list, still 1x in game |
| A 2x2 block of four wrong icons in one icon's space, or nothing | 2x coordinates sampling a 1x texture (atlas or font-icon sheet) |
| A button showing two stacked states; hover shows garbage | 1x button texture under a 2x control (state bands index by control height) |
| Correct icons, wrong positions: overlapping, cramped, or half-width layouts | Unscaled Lua layout — a file-level constant or the pixel term of a mixed expression |
| Text ellipsized with room to spare | Unscaled Lua truncate width |
| Icon shows a quarter of the right image | Texture-space coordinate doubled twice, or a hookup key scaled (never scale `IconHookup`/`IconLookup` size arguments) |

For Lua suspects, diff the file against its `reference/` copy: a pixel
numeral identical to stock is the bug. Fix both tree copies — the DLC file
shadows the base one, and any edit to a shadowed base file must be mirrored or
it never takes effect.

## Gotchas

- A `LanguageSpecific` stylesheet dropped in by another tool overrides
  `Styles.xml` and silently pins fonts at whatever scale it was made for.
  Delete such files; `ui/` carries all scaled font sizes itself.
- If a screen's icons look wrong, the one-cell pin in `IconSupport.lua` is the
  first suspect; it can be removed per control.
