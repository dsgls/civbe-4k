# Civilization: Beyond Earth — 4K UI

Beyond Earth's interface is authored in pixels against a ~1080p canvas and the
engine has no UI scaling option, so at 3840x2160 everything renders at half
size. This project rescales the whole interface to 2x: every screen layout,
font size and piece of Lua layout arithmetic, plus all 950 UI textures were
upscaled so icons, frames and font icons stay sharp.

Rising Tide is required — the expansion's UI tree is part of the patch and the
texture overrides are installed through it.

## Installing

1. From [Releases](https://github.com/dsgls/civbe-4k/releases), download the
   newest texture pack (`civbe-4k-textures-v*.7z`, ~470 MB) and the newest
   mod zip (`civbe-4k-v*.zip`).
2. Extract both archives into the game directory, for example
   `C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization Beyond Earth`.
   Both archives contain the `assets` tree directly — extract them so their
   contents merge into the existing `assets` folder, not into a new subfolder
   named after the archive.
3. Run the game once if you never have — that creates `config.ini`. Then open
   `%USERPROFILE%\Documents\My Games\Sid Meier's Civilization Beyond Earth\config.ini`
   in a text editor and change three values:

   - under `[MiniMap]`: `Width = 490` and `Height = 280`
   - under `[Debugging]`: `LooseFilesOverridePAK = 1`

   If you skip this step the minimap stays at its tiny stock size.

Nothing is deleted; saves and settings are otherwise untouched.

## Notes

- The texture scale is all-or-nothing: do not install the UI files without the
  texture package or vice versa — coordinates and art must both be 2x.

## Uninstalling

Delete the loose `.dds` files under `Assets/DLC/Expansion1/UI/` in the game
directory, then restore the overwritten UI files — verify game file integrity
through Steam, or uninstall and reinstall the game. Revert the `[MiniMap]`
values in `config.ini` if you want the stock minimap back.

## Development

Engine behavior notes, the texture pipeline, and everything needed to modify
or rebuild the patch are in [DEVELOPMENT.md](DEVELOPMENT.md).
