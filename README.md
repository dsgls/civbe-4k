# Civilization: Beyond Earth — 4K UI project

Beyond Earth's interface is authored in literal pixels against a ~1080p canvas
and the engine exposes no scaling lever (the exe offers only
`UIManager::GetScreenSizeVal`, a query). At 3840x2160 the whole UI renders at
roughly half its intended physical size.

**Phase 1 is done**: `civbe-uiscale/` rewrites the authored geometry and font
sizes in `Assets/UI`. It is tested and works.

**Phase 2 is the open work**: rescaling the .dds art so that atlas icons,
9-slice frames and font icons can grow too. Everything needed to start is in
this directory. Read *Engine facts* before touching anything — most of the
traps here are non-obvious and cost real time to rediscover.

---

## Layout

```
civbe-uiscale/          the phase-1 tool (Python, 115 tests). See its README.
ui_textures.txt         the phase-2 work list: 405 textures needing conversion.
extracted/              per-archive .fpk extractions + decoded PNGs
  UITextures.fpk/                 1642 .dds  (base game UI)
  UITextures_converted/            595 .png  (decoded dictionary pairs)
  Expansion1UITextures.fpk/        499 .dds  (Rising Tide UI)
  Expansion1UITextures_converted/  129 .png
  MiscTextures.fpk/                252 .dds  (3 files needed from here)
reference/
  assets-ui-stock/      pristine Assets/UI from a clean install
analysis/               scripts that produced and check ui_textures.txt
```

`reference/assets-ui-stock` is the source of truth for the sweep and for
regenerating the texture list. Keep it: it makes the analysis reproducible
without a game install, and it is the baseline every acceptance check compares
against.

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
offset. Scale the key and the lookup misses. The tool therefore rescales only
the arithmetic, at two sites in `IconSupport.lua`, and never touches the
database or any call site. It also pins the control to one cell inside
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

---

## The texture format

Most UI textures ship as a **block dictionary plus an index**, not as plain
images:

- `foo.dds` — a dictionary holding NxN pixel blocks
- `foo-index.dds` — one dictionary entry per block, 8- or 16-bit
- decoded image = `index_dims x N`

Verified against all 724 pairs, with the converted PNGs as ground truth:

| block | textures |     | block | textures |
|-------|----------|-----|-------|----------|
| 1x1   | 313      |     | 8x8   | 22       |
| 2x2   | 195      |     | 10x10 | 9        |
| 4x4   | 183      |     | 20x20 | 2        |

Blocks are always square. **Images usually are not** — 407 of 724 decoded PNGs
are non-square (`actionrowbackground` 433x55, `1920_leftside` 100x1200).
Index dimensions divide the image exactly in every case, and the dictionary is
never too small for the indices used. Note 10 and 20: the sizes are not all
powers of two, which will break a solver that only tries 1/2/4/8/16.

The DDS files carry an `FTXT` + usage tag (`Interface`, `Leader Diffuse`, …) in
the reserved field at offset 32. Whether the engine requires it on an override
is unknown — see *Open questions*.

Decoding is already done: `extracted/*_converted/` holds a PNG per pair. Only
the 211 plain-DDS entries have no PNG, because they need no decode.

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
sub-rect, a 9-slice rect, a flipbook stride, a font-icon cell, or an
`IconTextureAtlases` row. This is derived from the same `classify.py` the tool
uses, so the list and `--texture-scale` cannot drift apart. Textures merely
stretched to fit a control are deliberately absent — the engine scales those
and they only get softer.

Cost, measured:

```
icon-atlas           160 files    73.0 Mpx   1168.3 MB RGBA@2x   292.1 MB DXT5@2x
atlas-subrect         65 files     3.9 Mpx     62.0 MB RGBA@2x    15.5 MB DXT5@2x
9-slice              184 files     2.2 Mpx     34.6 MB RGBA@2x     8.7 MB DXT5@2x
lua-runtime-offset     8 files     0.5 Mpx      7.2 MB RGBA@2x     1.8 MB DXT5@2x
flipbook-sheet         1 files     0.3 Mpx      4.2 MB RGBA@2x     1.0 MB DXT5@2x
TOTAL                405 files    76.5 Mpx   1224.7 MB RGBA@2x   306.2 MB DXT5@2x
```

A trailing section lists 48 names referenced by shipped data but present in no
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
3. **Place** the results where loose files override the archives.
4. **Run the sweep with matching scale**: `--texture-scale 2`.

### Constraint: `--texture-scale` is global

The tool applies one texture scale to every texture-space coordinate. If only
some art is rescaled, the rest samples wrong. So it is currently **all 405 or
none** — the "convert the cheap 27 MB tier first" idea needs per-texture scale
support in `classify.py`/`xmlpatch.py`, which does not exist. Adding it means
resolving each element's texture reference to a per-file factor; feasible, but
it is new work, not a configuration change.

---

## Open questions — verify these before building the pipeline

Each of these is cheap to test and expensive to get wrong.

1. **Where do loose overrides go?** Never verified. The archives are flat and
   the engine resolves textures by bare filename (the XML mixes
   `Texture="buttonsides.dds"` with `Texture="assets\UI\Art\Icons\MainOpen.dds"`
   and both work), so `Assets/UI/` is the reasonable guess, with
   `Assets/DLC/Expansion1/UI/` for expansion art. **Test with one obviously
   altered texture before converting anything.** Remember the "if the loose
   file is newer" clause.
2. **Will a plain DDS override replace a dictionary+index pair?** Unknown. The
   packed pair may still win, or the engine may look for `foo-index.dds` and
   find the packed one. If a plain override does not work, the pipeline has to
   re-encode into the dictionary format, which is a much larger job.
3. **Does the engine accept DXT for UI textures?** 115 stock textures are DXT
   (mostly cubemaps and globe art) but the UI sprites are uncompressed. If DXT
   is rejected, the memory budget forces a smaller scale or a shorter list.
4. **Does the `FTXT` tag matter?** Preserve it in output until proven optional.
5. **Mipmaps.** Some stock textures carry full chains, most do not. Match the
   original per file unless something proves otherwise.

---

## Commands

```bash
# phase 1: scale a live install (always re-derives from the pristine backup)
cd civbe-uiscale
python3 -m civbe_uiscale apply --game-dir "<install>" --scale 2
python3 -m civbe_uiscale apply --game-dir "<install>" --scale 2 --texture-scale 2
python3 -m civbe_uiscale restore --game-dir "<install>"

# tests (nix-shell wrapper needed on this machine)
nix-shell -p 'python3.withPackages(ps: [ps.pytest])' --run 'python3 -m pytest tests/ -q'

# analysis
cd analysis
python3 verify_conversion_inputs.py    # every listed input exists, dims match
python3 build_texture_list.py          # regenerate ui_textures.txt
python3 derive_block_sizes.py          # block size of every dictionary pair
python3 verify_ui_sweep.py <patched Assets/UI> 2   # acceptance check on a sweep
```

`analysis/paths.py` holds every location; edit `GAME` if the install moves.

The sweep's acceptance check compares a patched tree against
`reference/assets-ui-stock` attribute by attribute, using a value oracle
independent of the tool's own code. Current result: 12,777 screen-space values
scaled correctly, 3,945 texture-space frozen, 31,649 untouched, no change to
line counts, byte-order marks, attribute counts or attribute order.

## Gotchas

- The tool warns about UI files absent from the pristine backup. A
  `LanguageSpecific` stylesheet dropped in by another tool overrides
  `Styles.xml` and will silently pin fonts at whatever scale it was made for.
  Delete such files rather than leaving them.
- Font scaling needs no override file: the sweep scales the `FontSize` values
  in `Styles.xml` and in every `LanguageSpecific/*/LanguageSpecificStyles.xml`
  directly.
- At `--texture-scale 1` the icons and 9-slice borders keep their authored
  pixel size deliberately. They look small and the frames read thin. That is
  correct, not broken, and it is what phase 2 fixes.
- `--no-pin-icon-size` exists if the icon-size pin turns out to fight a screen.
- Large copies out of this directory over WSL/NTFS occasionally fail with
  "Cannot allocate memory"; `tar cf - . | (cd dst && tar xf -)` works.
