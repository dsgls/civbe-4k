# civbe-upscale

2x upscaler for the phase-2 texture work. RGBA PNG in, RGBA PNG out; `civbe-dds`
handles the DDS conversion on both sides. Design and rationale:
`docs/superpowers/specs/2026-08-16-texture-upscaling-design.md`.

## Usage

```bash
cd civbe-upscale

# ML upscalers need the CUDA shell (first entry: builds nothing, store is warm,
# but keep the throttle flags in case a nixpkgs bump reintroduces a build)
nix-shell shell.nix --option max-jobs 1 --cores 4 \
  --run 'python -m civbe_upscale batch <in> <out> --upscaler dat2-gametex'

nix-shell shell.nix --option max-jobs 1 --cores 4 \
  --run 'python -m civbe_upscale compare <in> <out> --upscalers all \
         --crop buildingatlas.png=0,0,128,128'

# lanczos/lanczos-rgba and the tests need only the light shell
nix-shell -p 'python3.withPackages(ps: [ps.pytest ps.numpy ps.pillow ps.scipy])' \
  --run 'python -m pytest tests/ -q'
```

Upscalers: `realesrgan-x4plus`, `realesrgan-x2plus`, `realesr-compact`,
`swinir-x4`, `dat2-gametex`, `animesharp-v4`, `realesrgan-anime6b`, `lanczos`,
`lanczos-rgba`. Checkpoints download to `models/` (gitignored) on first use,
SHA-256-verified; expect a one-time download when running ML entries.

## Operational notes

- The 2048x2048 icon atlases exceed whole-image VRAM even on the 5090, so they
  run through the overlapping-tile path routinely. Seams are unlikely (64 px
  halo) but judge them deliberately: give `compare` `--crop` rows across atlas
  cell boundaries.
- The tile ladder has two rungs (1024, 512). A card that OOMs at 512 px tiles
  gets an error, not a smaller tile; raise `MAX_TILE` or relax the degenerate
  guard in `engine.py` if that ever bites.
- `compare --upscalers all` keeps every model's weights resident (the model
  cache never evicts); fine at 7 entries, revisit before growing the registry.
- `lanczos-rgba` is a diagnostic control, not a candidate: if it ever beats
  `lanczos` on soft alpha edges, the alpha pipeline has a bug.
- CUDA builds on this machine: always pass `--option max-jobs 1 --cores 4`,
  and keep `cudaCapabilities = [ "12.0" ]` (see shell.nix) — an unthrottled
  multi-arch CUDA build has taken the machine down twice.
