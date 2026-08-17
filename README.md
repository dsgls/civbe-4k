# Civilization: Beyond Earth — 4K UI

Beyond Earth's interface is authored in pixels against a ~1080p canvas and the
engine has no UI scaling option, so at 3840x2160 everything renders at half
size. This project rescales the whole interface to 2x: every screen layout,
font size and piece of Lua layout arithmetic, plus all 950 UI textures were
upscaled so icons, frames and font icons stay sharp.

Rising Tide is required — the expansion's UI tree is part of the patch and the
texture overrides are installed through it.

## Installing

Requirements: the game installed through Steam on Windows, and a Linux
environment with Python 3 that can see the Windows drives (WSL works; this is
what the project is developed on).

1. Clone this repository.
2. If your paths differ from the defaults, edit `GAME` (the game directory)
   and `CONFIG` (the engine's `config.ini` under `Documents\My Games`) in
   `analysis/paths.py`.
3. Run the game once if you never have — that creates `config.ini`.
4. Run:

   ```bash
   python3 install.py
   ```

The installer copies the patched UI files over the install, downloads the 2x
texture package (~480 MB, one-time, SHA-256 verified) and unpacks it into the
game directory, and adjusts `config.ini`: the minimap grows to 2x (only when
it is still at the engine default, so a hand-tuned size survives) and
`LooseFilesOverridePAK` is switched on, without which the game ignores the
installed textures.

Nothing is deleted; saves and settings are otherwise untouched.

## Notes

- The texture scale is all-or-nothing: do not install the UI files without the
  texture package or vice versa — coordinates and art must both be 2x.

## Uninstalling

Delete the loose `.dds` files under `Assets/DLC/Expansion1/UI/` in the game
directory, then verify game file integrity through Steam (or copy the stock
files back from this repository's `reference/` trees). Revert the `[MiniMap]`
values in `config.ini` if you want the stock minimap back.

## Development

Engine behavior notes, the texture pipeline, and everything needed to modify
or rebuild the patch are in [DEVELOPMENT.md](DEVELOPMENT.md).
