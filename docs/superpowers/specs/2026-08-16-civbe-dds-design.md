# civbe-dds — design

Promote `analysis/dds.py` to a real tool that reads every texture format the
phase-2 work list uses and writes plain RGBA DDS, so stock art can round-trip
its **level-0 image** `.dds` → RGBA `.png` → upscaler → RGBA `.dds`.

Level 0 is the whole claim. Mip chains, cubemap faces past the first, and the
low byte of an `L16` texture are dropped by design — none appear on the work
list.

## Why

Phase 2 rescales 405 UI textures. Their source forms:

| source form | files | pixels |
|-------------|-------|--------|
| dictionary pair (dictionary is RGBA) | 194 | 72.06 Mpx |
| plain `A8R8G8B8` (BGRA bytes) | 98 | 2.15 Mpx |
| plain `A8B8G8R8` (RGBA bytes) | 86 | 2.05 Mpx |
| plain DXT4 | 22 | 0.26 Mpx |
| plain DXT1 | 5 | 0.03 Mpx |

`analysis/dds.py` decodes only the first row. The other four, and the write
half, do not exist. The format itself is documented in the top-level README
under *The texture format*; this spec does not restate it.

## Scope

In: decode every form the three UI packs contain except the `.fic` stubs;
encode plain single-level `A8B8G8R8`; a CLI; tests; migration of the six
`analysis/` consumers.

Out: DXT encoding, mipmap generation, dictionary-pair encoding (the verified
loose-override test showed a plain DDS displaces a stock pair, so nothing needs
to write one), `.fic` payloads, the upscaler itself, and any change to
`civbe-uiscale`.

## Layout

A sibling of `civbe-uiscale/`, same shape.

```
civbe-dds/
  civbe_dds/
    __init__.py   public API re-exports, written once at the end (task 6)
    image.py      the Image dataclass
    header.py     DDS header parse + build, FTXT group/tag, format naming, channel order
    dxt.py        BC1/BC2/BC3 block decode
    pair.py       dictionary + index decode
    decode.py     dispatch: any supported .dds -> Image
    encode.py     Image -> plain single-level A8B8G8R8 .dds
    png.py        PNG reader/writer, ported from analysis/dds.py and extended
    cli.py
    __main__.py
  tests/
  README.md
```

Stdlib only, matching the rest of the project.

## Public API

```python
Image        # width, height, rgba, group
             #   rgba is always R,G,B,A regardless of the source's mask order
             #   group is the FTXT usage name ("Interface", ...), "" when absent

read(path) -> Image
    Any supported .dds. Resolves the -index.dds sibling itself, so callers
    never branch on pair-vs-plain. Level 0 only.

write(path, image, group=None) -> None
    Plain A8B8G8R8, one level. group falls back to image.group, then
    "Interface".

header(path) -> DdsHeader        # dataclass, replacing today's dict
read_png(path) -> Image
write_png(path, image) -> None
```

`read_png` is the one place a file the project did not produce enters the
pipeline — `encode`'s input comes from a third-party upscaler — so its accepted
surface is part of the contract, not an implementation detail. It returns RGBA,
which today's function in `analysis/dds.py` does not: that one returns raw
scanlines and a channel count, and for a palette image it hands back index bytes
that are indistinguishable from pixels. Extending it is a real change, not a
move.

- 8-bit, non-interlaced, colour types 0, 2, 4 and 6: grey replicated to R=G=B,
  missing alpha filled with 255.
- Colour type 3 (palette) is expanded through `PLTE`, with `tRNS` supplying
  alpha where present and 255 elsewhere. Silently emitting palette indices as
  pixels is the one failure mode here that produces plausible-looking garbage.
- 16-bit depth raises a named error. ESRGAN-family upscalers emit it routinely,
  so the message must say what to do (re-save as 8-bit) rather than just
  "unsupported".

`DdsHeader` carries at least: `width`, `height`, `mips`, `pfflags`, `fourcc`,
`bits`, `rmask`, `caps2`, `group`, `tag` — the fields today's dict has, so the
migration is mechanical.

## Decoding

`decode.py` dispatches on the header and the sibling file:

- **Dictionary pair** — a `-index.dds` sibling exists. Port `decode_pair` from
  `analysis/dds.py`; it already decodes all 724 pairs byte-exactly, so any
  rewrite of the arithmetic must reproduce it. N comes from the `BC0nn` tag and
  is decimal. `cols = dictionary_width // N` is **floor** division and the
  dictionary may be padded on the right and the bottom: 7 of the 9 N=10
  dictionaries have a width that is not a multiple of N (`buttonsides` is 16
  wide at N=10), and `be_exp1_traits_atlas_128` is 16x16 holding one tile row.
  Asserting divisibility, or rounding up, breaks those files.
- **32-bit** — `A8B8G8R8` (R mask `0xff`, bytes R,G,B,A) and `A8R8G8B8` (R mask
  `0xff0000`, bytes B,G,R,A). Read the mask per file; never assume an order. A
  32-bit file whose masks match neither raises a named error — do not fall
  through to one order and guess.
- **DXT1** — 8-byte blocks: `c0`, `c1` as little-endian RGB565, then a 32-bit
  little-endian field of 2-bit indices with texel 0 in the low 2 bits.
  Endpoints expand to 8 bits by **high-bit replication** — `(v << 3) | (v >> 2)`
  for a 5-bit channel, `(v << 2) | (v >> 4)` for 6-bit — and the 1/3 and 2/3
  interpolants are computed on the **expanded 8-bit** values. A naive `v << 3`
  turns white into (248, 252, 248) and darkens every DXT texel in the project by
  ~3%. `c0 > c1` is the 4-colour opaque mode; otherwise 3 colours with index 3
  as transparent black. The punch-through mode is the *majority* path in the
  work-list art (`forgeui_scrollbar` is 220 of 256 blocks), not a corner case.
- **DXT3 / DXT5** — 16-byte blocks: an alpha block then a colour block laid out
  exactly as DXT1's but **always** in 4-colour mode, whatever `c0` and `c1`
  compare as.
  - DXT3 alpha: 4 bits per texel, texel `i` in nibble `i` of the 8-byte block,
    low nibble of byte 0 first — `(alpha[i >> 1] >> (4 * (i & 1))) & 0xf` —
    expanded to 8 bits by replication, `a * 17`. `a << 4` leaves an opaque texel
    at 240 and washes every sprite.
  - DXT5 alpha: `a[0] = a0`, `a[1] = a1` from the first two bytes, then 3-bit
    indices as a 48-bit little-endian field in bytes 2..7 with texel 0 in the
    low 3 bits. If `a0 > a1`: `a[2+i] = ((6-i)*a0 + (1+i)*a1) // 7` for i in
    0..5. Otherwise: `a[2+i] = ((4-i)*a0 + (1+i)*a1) // 5` for i in 0..3, and
    `a[6] = 0`, `a[7] = 255`. The second mode differs twice over — denominator
    5, and two literal entries — and it is not the rare one: 29.8% of stock DXT4
    blocks are in it, `forgeui_glass` entirely so, and applying the 8-value
    formula to it puts wrong alpha on 42% of `forgeui_pulldown_corner`.
- **DXT2 / DXT4** — decode as DXT3 / DXT5 and **do not divide out alpha**. The
  fourCC claims premultiplied alpha and the data is not premultiplied; honouring
  it washes these textures out.
- **L8 / L16 standalone** — greyscale, replicated to R=G=B with opaque alpha.
  L16 reduces by `v >> 8`, which is lossy and deliberate. This is what reading
  an `-index.dds` directly gives you.
- **Cubemap** — `dwCaps2 & 0x200` (`DDSCAPS2_CUBEMAP`), not an equality test
  against `0xFE00`. Decode face 0, which starts at 0x80 like any other texture,
  and warn on stderr.
- **fourCC 114** (`.fic` stub) — raise a named unsupported-format error, not a
  struct failure.

Blocks are laid out row-major, left to right then top to bottom, as are the
texels within a block; DDS rows run top to bottom, matching PNG, so nothing is
flipped. Block-compressed images are decoded on a 4x4 grid and cropped to the
declared dimensions — no stock file needs the crop, so only a synthetic fixture
can test it.

Pixel data is tightly packed from offset 0x80: summing every declared mip level
across every face accounts for the file size exactly, on all 2382 non-stub
files. `info` therefore compares against **that** sum, or else reports only "the
file is shorter than level 0" — comparing the file size against level 0 alone
false-positives on the 702 files that carry chains or faces.

## Encoding

Fixed output, because that combination is what 314 stock plain UI textures
already are and what the verified loose override was:

- `A8B8G8R8`: `DDPF_RGB | DDPF_ALPHAPIXELS`, 32 bits, R `0x000000ff`, G
  `0x0000ff00`, B `0x00ff0000`, A `0xff000000` — bytes R,G,B,A.
- One level, no mipmap chain, no cubemap.
- FTXT written: `FTXT` at 0x20, the NUL-padded usage name at 0x24, tag `COLOR`
  at 0x74. `dwReserved2` zeroed. This is a few bytes at fixed offsets, so write
  it — but it is not load-bearing. Eight stock textures ship with no `FTXT` and
  the game draws them, so a plain conforming DDS is sufficient and no test
  pins these fields.

The rest of the header is an ordinary conforming DDS: `dwFlags` = caps | height
| width | pitch | pixelformat | mipmapcount (`0x2100F`), `dwPitchOrLinearSize` =
width x 4, `dwMipMapCount` 1, `dwCaps` = `DDSCAPS_TEXTURE` (`0x1000`). Every
one of these has stock precedent. Set `DDSD_MIPMAPCOUNT` because
`dwMipMapCount` is written; stock files that carry a count always set the flag.
Compare against a stock plain texture while implementing and adopt its values
where they differ, but do not build machinery around matching it.

## CLI

```
python3 -m civbe_dds info   <path>...             # dims, format, tag, group, mips, pair/plain
python3 -m civbe_dds decode <dds>...  [-o DIR]    # -> RGBA .png
python3 -m civbe_dds encode <png>...  [-o DIR] [--like STOCK.dds | --group NAME]
```

All three take many paths; `-o` defaults to alongside each input. A per-file
failure prints to stderr and processing continues; the exit status is 1 if any
file failed.

`--like` exists because the FTXT usage name does not survive the PNG hop. The
pipeline is `decode` → external upscaler → `encode --like <the stock file>`,
which carries `Interface` or `Interface Scalable` across. `--group NAME` sets it
literally; the two are mutually exclusive and the default is `Interface`.

## Tests

Pytest under `civbe-dds/tests/`, run the same way as the sweeper's suite:

```
nix-shell -p 'python3.withPackages(ps: [ps.pytest])' --run 'python3 -m pytest tests/ -q'
```

Fixtures are constructed in code — no committed binaries, and `extracted/` is
not tracked, so nothing in the suite may depend on it.

- header parse/build round-trip, including the 21-file case where junk trails
  the usage name (read to the first NUL) and the eight-file case with no `FTXT`
- one hand-built block per codec with hand-computed expected RGBA: DXT1 in both
  the opaque and the punch-through mode, DXT3, DXT5 in both alpha
  interpolation modes. The hand-computed values must come from the formulas in
  *Decoding* above — a test written from a plausible-sounding paraphrase
  enshrines the wrong numbers, which is exactly how the 6-value alpha mode and
  the 565 expansion get lost.
- an endpoint of `0xFFFF` expands to (255, 255, 255), not (248, 252, 248)
- a DXT3 nibble of 15 expands to alpha 255, not 240
- DXT2 and DXT4 decode identically to DXT3 and DXT5 — alpha is not divided out
- a texture whose dimensions are not multiples of 4, cropped correctly (no
  stock file exercises this, so the fixture is the only coverage)
- both 32-bit mask orders decode to the same RGBA; an unrecognised 32-bit mask
  raises rather than guessing an order
- L8 and L16 greyscale decode
- pair decode with a non-power-of-two N (10 and 20 both ship), a non-square
  image (407 of 724 are non-square), and a dictionary whose width is not a
  multiple of N
- a synthetic `A8R8G8B8` dictionary, since all 724 stock dictionaries are
  `A8B8G8R8` and the pair decoder's channel swap is otherwise dead code
- each accepted PNG colour type expands to RGBA; a palette PNG resolves through
  `PLTE`/`tRNS` rather than returning indices; a 16-bit PNG raises
- cubemap decodes face 0; a fourCC-114 file raises the named error
- `decode(encode(img)) == img`
- `encode(read(dds))` re-read equals the original RGBA, for a 32-bit source and
  for a pair source

## Migration

- `analysis/paths.py` gains `DDS_TOOL = os.path.join(PROJECT, "civbe-dds")`.
- The six consumers (`build_texture_list.py`, `compare_pack_collisions.py`,
  `dead_reference_report.py`, `derive_block_sizes.py`,
  `verify_conversion_inputs.py`, `verify_pair_decode.py`) switch from
  `import dds` to `sys.path.insert(0, DDS_TOOL)` then `from civbe_dds import …`,
  the convention those scripts already use for `civbe_uiscale`.
- `analysis/dds.py` is deleted. No shim.
- `verify_pair_decode.py` becomes `verify_decode.py`: it still diffs all 724
  pairs against the converted PNGs byte-exactly, and additionally decodes every
  plain texture in the three packs and round-trips each through `encode`. That
  turns the corpus into an acceptance run for the new formats, which the unit
  tests deliberately cannot cover.

## Docs

- `civbe-dds/README.md`: usage, the CLI, what it will not do (no DXT out, no
  mipmaps, no pair encoding) and why.
- Top-level README: re-point every `analysis/dds.py` reference, add the new
  commands to *Commands*, and note under open question 2 that the plain-RGBA
  encoder now exists. The format knowledge itself stays where it is.

## Task split

1. **Package skeleton + `image.py` + `header.py` + `png.py`.** The `Image`
   dataclass (`width`, `height`, `rgba`, `group`) that every other module
   imports; `DdsHeader` parse, build, format naming, channel order; the PNG
   reader extended to the surface above. `__init__.py` stays empty.
2. **`dxt.py`.** All five fourCCs, with the 2→3 and 4→5 remap.
3. **`pair.py`.** Ported from `analysis/dds.py`. Owns `index_path` and
   `is_pair`, which `decode.py` imports.
4. **`encode.py`.** Its tests assert that the output parses back through
   `header()` with the expected fields and that the pixel bytes are R,G,B,A.
   The round-trip tests belong to task 5, the first point where both halves
   exist.
5. **`decode.py`.** The dispatcher, plus L8/L16, cubemap and `.fic` handling,
   and the two round-trip tests.
6. **`cli.py` + `__main__.py` + the `__init__.py` re-export block.** Tasks 2-5
   and their tests import submodules directly, so only this task writes the
   public API and no two tasks contend for one file.
7. **Migration**: `paths.py`, the six consumers, delete `dds.py`, rewrite
   `verify_pair_decode.py` as `verify_decode.py`.
8. **Docs**: both READMEs.

Dependencies: 1 first. Then 2, 3 and 4 are independent of each other and may run
in parallel. 5 needs 2 and 3. 6 needs 4 and 5. 7 needs 5 and 6 (it runs the CLI
and the encoder against the corpus). 8 last.

Tests belong to the task that adds the code, written first — this is a
TDD project and the suite is the deliverable alongside each module.
