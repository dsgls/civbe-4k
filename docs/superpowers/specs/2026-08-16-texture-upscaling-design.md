# civbe-upscale — texture upscaling tool

Phase-2 middle stage: upscale decoded UI textures 2x with a choice of ML and
classical upscalers, and produce a side-by-side comparison for picking one.
Sits between the two halves of `civbe-dds` (all-format `.dds` → RGBA PNG →
RGBA `.dds`): this tool is **RGBA PNG in, RGBA PNG out** and has no DDS
knowledge.

Quality is the only selection criterion. Performance is explicitly not a
factor; the machine has an RTX 5090 (32 GiB) with working CUDA under WSL2, and
CPU fallback is acceptable.

## Layout

New sibling tool `civbe-upscale/`, Python package `civbe_upscale`, matching
the `civbe-uiscale` / `civbe-dds` pattern. `shell.nix` provides python3 with
`torch` (CUDA), `pillow`, `numpy`, `spandrel` — all from nixpkgs-unstable
(`spandrel` is packaged there).

## CLI

```
python3 -m civbe_upscale batch   <input_dir> <output_dir> --upscaler <name>
python3 -m civbe_upscale compare <input_dir> <output_dir> --upscalers <name>[,<name>...]
```

- **batch**: every `*.png` in the input dir → same-name PNG in the output
  dir, at exactly 2x the source dimensions.
- **compare**: every input × every upscaler → `<inputname>-<upscaler>.png`
  in the output dir, plus `index.html` showing each input's variants side by
  side at in-game size. `--upscalers all` runs the whole registry.

Both modes are flat and non-recursive. Nothing is skipped silently: a
non-PNG file, an unreadable file, or a non-RGBA PNG is an error. Output
dimensions are exactly 2x input in both modes, always.

## Upscaler registry

One module holding a dict: name → entry. Two entry kinds:

- **ML model**: checkpoint URL, SHA-256, native scale (2 or 4). Checkpoints
  auto-download on first use into a gitignored `civbe-upscale/models/`
  cache and are hash-verified. Loaded via `spandrel.ModelLoader`, which
  auto-detects the architecture — so any OpenModelDB / community `.pth` /
  `.safetensors` checkpoint is one registry line.
- **Builtin classical scaler**: a function, no download.

Names must be unique and filename-safe (they appear in
`<inputname>-<upscaler>.png`). Native-1x (restoration-only) models are not
admitted.

Initial candidate set, curated for a spread of styles; the implementer picks
the concrete checkpoints from OpenModelDB and records URL + hash in the
registry:

- 2–3 general Real-ESRGAN-family models (e.g. RealESRGAN x4plus, a
  Compact/SPAN variant)
- 1–2 transformer models (SwinIR / HAT / DAT)
- 1–2 community game-texture or anime models (e.g. HDcube-style)
- `lanczos` — Pillow LANCZOS through the standard two-plane alpha path
- `lanczos-rgba` — single-pass RGBA Pillow LANCZOS, **bypassing** the alpha
  pipeline entirely (see below)
- `xbr` if a clean pure-Python implementation is available; otherwise drop
  it rather than pull in a heavy dependency

## Engine

For an ML upscaler: load with spandrel, run on CUDA at fp32; if CUDA init
fails, fall back to CPU with a warning. Multi-GPU is out of scope.

Scale normalization to exactly 2x:

- native 2x model → use directly
- native 4x model → run at 4x, then downscale to 2x with Pillow LANCZOS

Whole-image inference by default (best quality, no tiling artifacts
possible). On CUDA OOM only, retry with overlapping tiles, halving from
1024 px until it fits, and log that tiling engaged. Tile overlap regions are
discarded (crop to tile interior), not blended, so seams cannot average two
predictions.

Inference is wrapped with deterministic flags/seeding so reruns reproduce.

## Alpha handling

Every image goes through a two-plane path, regardless of upscaler (except
`lanczos-rgba`):

1. **RGB plane.** Before upscaling, pixels with alpha == 0 get their RGB
   replaced by color extrapolation from the nearest opaque pixels
   (iterative dilation / inpaint-by-neighbor). This stops models from
   sharpening the boundary between real art and the junk colors stored
   under fully transparent pixels — the halo that otherwise appears on
   recomposite. Pixels with 0 < alpha < 255 keep their RGB.
2. **Alpha plane.** Extracted, replicated to 3-channel grayscale, run
   through the same upscaler, one channel taken back. Soft gradients get
   real model upscaling, not a resize.

Recombine into RGBA. All-alpha textures need no special casing: the alpha
plane always gets the full treatment.

`lanczos-rgba` is the diagnostic control: a plain one-pass RGBA resize with
no plane split and no extrapolation. If it ever beats `lanczos` on soft
edges, the alpha pipeline has a bug or a design flaw.

## Comparison HTML

`compare` writes one self-contained `index.html` into the output dir,
referencing the output PNGs by relative path (no inlining).

- One row per input texture; header gives filename and source dimensions.
- One cell per upscaler: label above, image below, rendered at exactly 2x
  the source dimensions via explicit `width`/`height` attributes,
  `image-rendering: auto` — in-game size.
- First cell of every row: the original at 2x **nearest-neighbor**
  (browser-scaled, no file written) — the "what the game shows today"
  reference.
- Background under the images is switchable via a fixed toolbar
  (vanilla JS toggling a CSS class): checkerboard / black / white /
  dark-blue approximating the game's UI backdrop. Default dark-blue.
  This is the tool for judging soft alpha edges.
- Wide atlases scroll horizontally within their row; variants never wrap,
  so they stay side by side and vertically aligned.

## Testing

Deliberately light — this code will not churn once working, and model
output quality is judged by eye via compare mode. Keep only tests whose
failures would masquerade as "the upscaler is mediocre" in game:

- Alpha plumbing, driven by a fake nearest-neighbor upscaler injected
  through the normal upscaler interface: split/recombine round-trip,
  alpha=0 RGB is extrapolated before the model sees it, partial-alpha RGB
  untouched, all-alpha image survives.
- Color extrapolation on synthetic images with known nearest-opaque
  answers.
- One tiling test: fake upscaler, forced small tile size, tiled output
  byte-identical to untiled.

No CLI, HTML, registry, or download tests. No GPU or network in tests.

## Task split

1. **Core engine** — registry, checkpoint download/cache, spandrel wrapper,
   2x normalization, OOM-fallback tiling, classical scalers. No
   dependencies.
2. **Alpha pipeline** — extrapolation, two-plane wrapper around the
   upscaler interface (a one-function protocol), `lanczos-rgba` bypass.
   Parallel with task 1, developed against the fake upscaler.
3. **CLI + batch mode** — depends on 1 + 2.
4. **Compare mode + HTML** — depends on 1 + 2, independent of 3.

Run 1 ∥ 2, then 3 ∥ 4. No requirement that each task leaves the tree fully
working; tests land with tasks 1 and 2.
