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
python3 -m civbe_upscale compare <input_dir> <output_dir> --upscalers <name>[,<name>...] \
                                 [--crop <file>=<x,y,w,h>]...
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

**Value range.** Plane data is float in [0,1] through the whole pipeline and
is clamped to [0,1] after every model invocation and every resize, before any
quantization to uint8. Never cast unclamped floats — wraparound turns alpha
overshoot at hard edges into punched-out transparent rings.

**Padding.** Every input is replicate-padded (not reflect — small images
can't reflect-pad past their own size, and replicate keeps 9-slice border
rows clean) to at least 32 px per side, rounded up to a multiple of 16,
before inference; the 2x region corresponding to the original rect is cropped
back out. This is an engine-level contract, not per-model: the work list
bottoms out at 8x5 and 4x32, below the minimum-input constraints of
window-attention models.

Scale normalization to exactly 2x:

- native 2x model → use directly
- native 4x model → run at 4x, then downscale to 2x. RGB planes use Pillow
  LANCZOS; **alpha planes use a non-negative kernel** (Pillow `BOX`/area) —
  Lanczos negative lobes on a model-sharpened binary mask ring alpha a few
  levels above zero just outside every hard edge, compositing a faint colored
  outline in game.

Whole-image inference by default (best quality, no seams possible). On CUDA
OOM only, retry with overlapping tiles, halving the tile size from 1024 px
until it fits, and log that tiling engaged. Overlap is 64 px in input space,
constant while tiles halve; each interior tile side discards overlap/2 of
output (crop, not blend). If halving would bring the tile size to ≤ 2x the
overlap, error out instead of degenerating. Seams are not blended and the
overlap is chosen to exceed typical effective receptive fields, but tiled
output is not guaranteed identical to whole-image output.

Determinism: `torch.backends.cudnn.benchmark = False` (inference is
feed-forward; there is nothing to seed). Reruns reproduce given the same
device and the same whole-vs-tiled path; the tiling log line records which
path ran.

## Alpha handling

Every image goes through a two-plane path, regardless of upscaler (except
`lanczos-rgba`):

1. **RGB plane.** Before upscaling, transparent pixels get their RGB
   replaced by color extrapolation (iterative dilation / inpaint-by-
   neighbor). The seed set is every pixel with **alpha > 0**, weighted by
   alpha — not alpha == 255, or glow/shadow sprites with no fully opaque
   pixel would have no seed. Pixels with alpha below a small threshold
   (8) get extrapolated color blended in by `1 - a/threshold`, hardening
   against junk RGB authored into near-transparent boundary pixels. This
   stops models from sharpening the boundary between real art and the junk
   colors stored under transparent pixels — the halo that otherwise appears
   on recomposite. If an image has **no** pixel with alpha > 0 (two
   work-list files: `be_exp1_traits_atlas_128`,
   `be_exp1_foreign_policies_atlas_128`), extrapolation has no seed:
   short-circuit and pass the RGB plane through unchanged.
2. **Alpha plane.** Extracted, replicated to 3-channel grayscale, run
   through the same upscaler, then the three output channels averaged back
   to one (models can hallucinate slight channel imbalance from a gray
   input; averaging is free noise reduction). Soft gradients get real model
   upscaling, not a resize.

Recombine into RGBA.

**Constant-plane passthrough:** a plane that is globally one value (fully
opaque alpha, blank placeholder RGB) skips the model and is filled at 2x
directly — GAN-family models speckle flat regions (alpha 250–255 shimmer
across solid panels), and a constant plane has nothing to upscale.

`lanczos-rgba` is the diagnostic control: a plain one-pass RGBA resize with
no plane split and no extrapolation. If it ever beats `lanczos` on soft
edges, the alpha pipeline has a bug or a design flaw.

## Comparison HTML

`compare` writes one self-contained `index.html` into the output dir,
referencing the output PNGs by relative path (no inlining).

- One row per input texture; header gives filename and source dimensions.
- One cell per upscaler: label above, image below, rendered at in-game size:
  **1 image pixel = 1 device pixel**. A few lines of JS set each image's CSS
  size to `2*w / devicePixelRatio` x `2*h / devicePixelRatio` (re-run on
  `resize`) — without this, Windows display scaling makes the browser
  resample every variant with smooth filtering and the judge compares
  browser artifacts, not model output. In game the 2x texture maps 1:1 to
  device pixels at 4K.
- Two reference cells lead every row, from the source PNG with no extra
  files: "original, 2x nearest" (`image-rendering: pixelated`) and
  "original, 2x smooth" (browser default) — the latter approximates the
  cheap GPU-stretch alternative and is the honest baseline; nearest alone
  exaggerates blockiness and flatters every upscaler.
- Optional repeatable `--crop <file>=<x,y,w,h>`: adds an extra row rendering
  that sub-rect of every variant of `<file>`, via CSS cropping of the same
  PNGs. Use this to judge icon-atlas **cell boundaries** the way the engine
  samples them — full-atlas rows systematically hide cross-cell
  contamination (see Known limitations).
- Background under the images is switchable via a fixed toolbar
  (vanilla JS toggling a CSS class): checkerboard / black / white /
  dark-blue approximating the game's UI backdrop. Default dark-blue.
  This is the tool for judging soft alpha edges.
- All images get `loading="lazy"` — a 2048x2048 atlas row holds ~470 MB of
  decoded bitmap across 7 variants, enough to push the browser into blurry
  raster-cache redraws that misjudge sharpness.
- Wide atlases scroll horizontally within their row; variants never wrap,
  so they stay side by side and vertically aligned.

## Known limitations

Whole-image upscaling contaminates icon-atlas cells near their boundaries:
model receptive fields span cell edges, so a bright neighbor can fringe the
adjacent icon's border pixels, and alpha bleed can raise a sliver of alpha
on a transparent cell margin. The icon-atlas tier is 93% of the pixels, so
this is worth watching via `--crop` rows. The real fix — per-cell upscaling
(split on the cell grid, pad, upscale, reassemble) — needs cell geometry the
tool does not take, and is deferred until comparison output shows the bleed
matters in practice.

## Testing

Deliberately light — this code will not churn once working, and model
output quality is judged by eye via compare mode. Keep only tests whose
failures would masquerade as "the upscaler is mediocre" in game:

- Alpha plumbing, driven by a fake nearest-neighbor upscaler injected
  through the normal upscaler interface: split/recombine round-trip,
  alpha=0 RGB is extrapolated before the model sees it, partial-alpha RGB
  untouched (above the blend threshold), all-alpha and zero-seed images
  survive, constant planes pass through.
- Color extrapolation on synthetic images with known nearest-seed answers.
- Pad-run-crop round-trip: a tiny input (e.g. 8x5) through the fake
  upscaler comes back exactly 16x10 with untouched content.
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
