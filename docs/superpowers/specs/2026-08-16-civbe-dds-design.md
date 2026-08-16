# civbe-dds — design

Promote `analysis/dds.py` to a real tool that reads every texture format the
phase-2 work list uses and writes plain RGBA DDS, so stock art can round-trip
`.dds` → RGBA `.png` → upscaler → RGBA `.dds`.

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
    __init__.py   public API re-exports
    header.py     DDS header parse + build, FTXT group/tag, format naming, channel order
    dxt.py        BC1/BC2/BC3 block decode
    pair.py       dictionary + index decode
    decode.py     dispatch: any supported .dds -> Image
    encode.py     Image -> plain single-level A8B8G8R8 .dds
    png.py        PNG reader/writer, moved from analysis/dds.py
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

`DdsHeader` carries at least: `width`, `height`, `mips`, `pfflags`, `fourcc`,
`bits`, `rmask`, `caps2`, `group`, `tag` — the fields today's dict has, so the
migration is mechanical.

## Decoding

`decode.py` dispatches on the header and the sibling file:

- **Dictionary pair** — a `-index.dds` sibling exists. Port `decode_pair` from
  `analysis/dds.py` unchanged in behaviour; it already decodes all 724 pairs
  byte-exactly. N comes from the `BC0nn` tag and is decimal.
- **32-bit** — `A8B8G8R8` (R mask `0xff`, bytes R,G,B,A) and `A8R8G8B8` (R mask
  `0xff0000`, bytes B,G,R,A). Read the mask per file; never assume an order.
- **DXT1** — 8-byte blocks, `c0`/`c1` RGB565 plus 4 bytes of 2-bit indices.
  `c0 > c1` is the 4-colour opaque mode; otherwise 3 colours with index 3 as
  transparent black. Both modes ship.
- **DXT3 / DXT5** — 16-byte blocks: an alpha block then a colour block that is
  always in 4-colour mode. DXT3 alpha is 4 bits per texel; DXT5 alpha is two
  endpoints plus 3-bit indices, with the 6-value and 8-value interpolation
  modes selected by `a0 > a1`.
- **DXT2 / DXT4** — decode as DXT3 / DXT5 and **do not divide out alpha**. The
  fourCC claims premultiplied alpha and the data is not premultiplied; honouring
  it washes these textures out.
- **L8 / L16 standalone** — greyscale, replicated to R=G=B with opaque alpha
  (L16 shifted down to 8 bits). This is what reading an `-index.dds` directly
  gives you.
- **Cubemap** (`dwCaps2` `0xFE00`) — decode face 0 and warn on stderr.
- **fourCC 114** (`.fic` stub) — raise a named unsupported-format error, not a
  struct failure.

Block-compressed images are decoded on a 4x4 grid and cropped to the declared
dimensions. Pixel data is tightly packed at offset 0x80 in every shipped file;
`info` reports a mismatch between declared dimensions and file size rather than
silently reading short.

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

The rest of the header is an ordinary conforming DDS: `dwFlags` with caps,
height, width, pitch and pixel-format set, `dwPitchOrLinearSize` = width x 4,
`dwMipMapCount` 1, `dwCaps` = `DDSCAPS_TEXTURE`. Compare against a stock plain
texture while implementing and adopt its values where they differ, but do not
build machinery around matching it.

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
  interpolation modes
- DXT2 and DXT4 decode identically to DXT3 and DXT5 — alpha is not divided out
- a texture whose dimensions are not multiples of 4, cropped correctly
- both 32-bit mask orders decode to the same RGBA
- L8 and L16 greyscale decode
- pair decode with a non-power-of-two N (10 and 20 both ship) and a non-square
  image (407 of 724 are non-square)
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

1. **Package skeleton + `header.py` + `png.py`.** `DdsHeader` dataclass, parse,
   build, format naming, channel order; PNG moved verbatim.
2. **`dxt.py`.** All five fourCCs, with the 2→3 and 4→5 remap.
3. **`pair.py`.** Ported from `analysis/dds.py`.
4. **`encode.py`.**
5. **`decode.py`.** The dispatcher, plus L8/L16, cubemap and `.fic` handling.
6. **`cli.py` + `__main__.py`.**
7. **Migration**: `paths.py`, the six consumers, delete `dds.py`, rewrite
   `verify_pair_decode.py` as `verify_decode.py`.
8. **Docs**: both READMEs.

Dependencies: 1 first. Then 2, 3 and 4 are independent of each other and may run
in parallel. 5 needs 2 and 3. 6 needs 4 and 5. 7 needs 5 and 6 (it runs the CLI
and the encoder against the corpus). 8 last.

Tests belong to the task that adds the code, written first — this is a
TDD project and the suite is the deliverable alongside each module.
