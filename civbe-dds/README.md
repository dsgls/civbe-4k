# civbe-dds

Reads every texture format the game's three UI packs contain and writes plain
RGBA `.dds`, so stock art can round-trip its **level-0 image**:
`.dds` → RGBA `.png` → upscaler → RGBA `.dds`.

```
python3 -m civbe_dds info   <path>...
python3 -m civbe_dds decode <dds>...  [-o DIR]
python3 -m civbe_dds encode <png>...  [-o DIR] [--like STOCK.dds | --group NAME]
```

All three take many paths and keep going past a per-file failure — a batch
over the full work list must not stop at the first bad file. A failure prints
`<path>: <error>` to stderr; the exit status is 1 if any file failed, 0
otherwise. `-o` defaults to alongside each input.

Run from `civbe-dds/`, against files under the top-level `extracted/`:

```
$ python3 -m civbe_dds info ../extracted/UITextures.fpk/actioncorner.dds ../extracted/UITextures.fpk/1920_leftside.dds ../extracted/UITextures.fpk/atlas_environment_diffuse.dds
../extracted/UITextures.fpk/actioncorner.dds: 451x133 A8B8G8R8 tag=- group=- mips=9 plain
../extracted/UITextures.fpk/1920_leftside.dds: 106x68 A8B8G8R8 tag=BC002 group=Interface mips=1 pair
../extracted/UITextures.fpk/atlas_environment_diffuse.dds: 128x128 DXT1 tag=COLOR_NA group=Irradiance Cube mips=8 plain

$ python3 -m civbe_dds decode ../extracted/UITextures.fpk/gameoverbannercontact.dds -o /tmp/out
../extracted/UITextures.fpk/gameoverbannercontact.dds -> /tmp/out/gameoverbannercontact.png

$ python3 -m civbe_dds encode /tmp/out/gameoverbannercontact.png --like ../extracted/UITextures.fpk/gameoverbannercontact.dds -o /tmp/out
/tmp/out/gameoverbannercontact.png -> /tmp/out/gameoverbannercontact.dds
```

`info` reads a `-index.dds` sibling to report `pair` vs `plain` and prints
`group`/`tag` as `-` when the file carries no `FTXT` block. It also flags a
file that is shorter than its level-0 data on stderr — never a false positive
against a file that legitimately carries more (a mip chain, cubemap faces),
since the check only ever compares "shorter than", never "equal to".

`decode` resolves a dictionary/index pair itself; point it at the dictionary
half and it decodes the full tiled image. Pointing it at the `-index.dds`
half instead decodes that file on its own, as a plain L8/L16 texture — a
greyscale map of tile numbers, not the picture — since `is_pair` only
recognises the dictionary half. `encode` only ever writes a plain,
single-level texture — see *What this does not do*.

`--like` exists because the FTXT usage name (`Interface`, `Interface
Scalable`, ...) does not survive the PNG hop. Point it at the stock `.dds`
being replaced and the group carries across; `--group NAME` sets the name
literally instead. The two are mutually exclusive and the default is
`Interface`.

## Public API

```python
from civbe_dds import Image, read, write, header, read_png, write_png

Image        # width, height, rgba, group
             #   rgba is always R,G,B,A regardless of the source's mask order
             #   group is the FTXT usage name ("Interface", ...), "" when absent

read(path) -> Image        # any supported .dds, level 0 only
write(path, image, group=None) -> None    # plain A8B8G8R8, one level
header(path) -> DdsHeader  # width, height, mips, pfflags, fourcc, bits, rmask,
                            # caps2, group, tag; None if path is not a DDS
read_png(path) -> Image
write_png(path, image) -> None
```

`read` dispatches on the header and, for a dictionary's dictionary half, on
the `-index.dds` sibling — callers never branch on pair vs. plain themselves.

`read_png` is the one place a file this project did not produce enters the
pipeline (`encode`'s input comes from a third-party upscaler), so its
accepted surface is part of the contract: 8-bit, non-interlaced colour types
0, 2, 3, 4 and 6. A palette image (type 3) is resolved through `PLTE`, with
`tRNS` supplying alpha where present and 255 elsewhere — returning raw
indices as pixels would be silently-plausible garbage. A 16-bit PNG raises
`UnsupportedPngError` naming the fix (re-save as 8-bit), since ESRGAN-family
upscalers emit 16-bit routinely.

## What this does not do

- **No DXT encoding.** `encode` writes only plain `A8B8G8R8`. Nothing on the
  rescale pipeline needs a compressed writer.
- **No mipmap generation.** `encode` always writes one level; it never builds
  a chain from the level-0 image.
- **No dictionary-pair encoding.** A verified in-game loose-texture override
  showed a plain single-file `.dds` displaces a packed dictionary/index pair,
  so nothing on the pipeline needs to write one — `read` still decodes every
  stock pair losslessly, which is what the pipeline reads.
- **No `.fic` payloads.** FourCC 114 is a Firaxis stub format; `read` raises
  a named `UnsupportedFormatError` rather than misreading it as pixel data.

## Level 0 is the whole claim

Only the first mip level, the first cubemap face, and (for `L16`) the high
byte of each sample survive decoding. None of these are bugs to fix later:

- **Mip levels past 0** are dropped. A source texture with a chain still
  round-trips its base image; the chain is not reconstructed.
- **Cubemap faces past 0** are dropped. `read` decodes face 0 — which starts
  at the same offset as any other texture — and warns on stderr.
- **`L16`'s low byte** is dropped. Each little-endian sample keeps only its
  high byte; this is lossy and deliberate, not a truncation bug.

## The encoder matches Firaxis' exporter, not the DDS spec

`build_header` sets `dwCaps` to `DDSCAPS_TEXTURE | DDSCAPS_COMPLEX |
DDSCAPS_MIPMAP` and omits `DDSD_PITCH` from `dwFlags`, even though the file
it writes has exactly one level. That looks wrong against the DDS
documentation, which reserves `COMPLEX | MIPMAP` for files that actually
carry extra surfaces. It is right for this project: every one of the 756
stock single-level plain `A8B8G8R8` textures in the UI packs sets exactly
this combination. Matching stock output, not the format documentation, is
the goal — see
*The texture format* in the top-level README for the format itself, and
*Encoding* in the design spec for the byte-for-byte header layout.

## Tests

```
nix-shell -p 'python3.withPackages(ps: [ps.pytest])' --run 'python3 -m pytest tests/ -q'
```

106 tests, constructed fixtures only — no committed binaries, and
`extracted/` (read from by the analysis scripts, not by these tests) is not
tracked.
