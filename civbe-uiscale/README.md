# civbe-uiscale

Rescales the Civilization: Beyond Earth UI for high-DPI displays. The game's
interface is authored in literal pixels against a ~1080p canvas and exposes no
scaling lever, so at 3840x2160 it renders at roughly half its intended size.

```
python3 -m civbe_uiscale apply --scale 2 --fast-menu
python3 -m civbe_uiscale apply --scale 1.75 --dry-run --report changes.txt
python3 -m civbe_uiscale restore
```

`--game-dir` defaults to the standard Steam install path; pass it for anywhere
else. The first run copies
`Assets/UI` to `backup-ui-pristine/`; every later run re-derives from that
backup, so changing `--scale` replaces the previous result instead of
compounding on it.

## Two coordinate spaces

The whole design turns on one distinction. **Screen-space** values are pixels
on the display and scale with `--scale`. **Texture-space** values are
coordinates into a `.dds` and are meaningless to scale unless the art is
rescaled too, so they follow `--texture-scale` (default `1.0`, i.e. frozen).

Anything not explicitly classified in `classify.py` is left alone.

### `Size` is context-dependent

`Size` is normally the drawn size of a control, but it is also the **source
rect** when the control samples a sub-rect of an atlas — `IconSupport.lua`
sets only `SetTexture` and `SetTextureOffsetVal`, so the sampled width and
height come from the control's size. Doubling `Size` on such a control makes
it read a 2x2 block of neighbouring icons.

The rule, in precedence order:

1. A 9-sliced control (`SliceCorner`, `SliceTextureSize`, …) stretches its
   texture, so `Size` is screen-space even alongside `StateOffsetIncrement`.
2. Otherwise, `TextureOffset` or `StateOffsetIncrement` on the element makes
   `Size` a source rect — texture-space.
3. Otherwise it is screen-space.

### `.` and `,` are both separators

The engine accepts either as the coordinate delimiter, and the stock files use
both — `AnchorSide="I.O"` appears 23 times against 24 of `AnchorSide="I,O"`,
and `Size="300.200"` is a 300x200 sprite. A dotted pair is **not** a float.
Reading `45.45` as one number and doubling it yields `90.9`, which the engine
parses as 90x9.

Every component is scaled independently and the original separators, spacing
and component count are preserved. A value whose shape is not recognised is
returned untouched.

## Atlas icons

`IconHookup(offset, iconSize, atlas, control)` looks `iconSize` up as a **key**
into the `IconTextureAtlases` database, then multiplies it by the cell index to
get a pixel offset. So the key must keep its stock value while the arithmetic
is rescaled. `--texture-scale` patches exactly that multiplication in
`IconLookup` and `IconHookup`, and leaves the database alone.

Those controls receive their `TextureOffset` at runtime, so nothing in the XML
marks them as atlas-sampled. To stop their authored `Size` from bleeding into
neighbouring icons, `IconHookup` also pins the control to one cell. Disable
with `--no-pin-icon-size` if a screen looks wrong.

## Faster front end

`--fast-menu` is unrelated to scaling and off by default. It makes the main
menu appear at once instead of staging each entry behind a slide and a fade on
a growing `Pause`, and comments out the legal disclaimer popup in
`FrontEnd.lua`. Entries open at `AlphaStart="1"` and every `SlideAnim` starts
at its end position, so the change is scale-independent — it runs on top of the
scaled output, after `Start="60,0"` has already become `Start="120,0"`.

Rising Tide ships its own `MainMenu.xml`, and a DLC file wins over the base
tree, so with the expansion installed that is the menu you actually see. It
lives outside `Assets/UI`, so this pass gives it a pristine copy of its own
next to the main backup, in `backup-ui-pristine-dlc/`. Only `--fast-menu`
creates it; once it exists, later runs re-derive from it like everything else,
so dropping the flag puts the stock animation back. `restore` covers it too.

## What it does not do

- Rescale the `.dds` art. Until that exists, run with the default
  `--texture-scale 1.0`.
- Touch anything outside `Assets/UI` — the `IconTextureAtlases` rows in
  `Assets/Gameplay/XML`, or the DLC UI trees. The one exception is the Rising
  Tide `MainMenu.xml` under `--fast-menu`, which is *not* rescaled, only
  de-animated.
- Edit commented-out markup, or reformat files. Only the bytes inside a matched
  attribute's quotes change; byte-order marks and line endings survive.

## Known limitations at `--texture-scale 1.0`

Atlas icons and 9-slice frame borders keep their authored pixel size, so icons
read small next to scaled text and panel frames look thin. Both are correct
rather than corrupt, and both resolve when the textures are rescaled and
`--texture-scale` is raised to match. Panel background textures are stretched
by the engine and will be correspondingly soft.

If another tool has added files to `Assets/UI`, the sweep reports them: it
never rewrites them, and a `LanguageSpecific` stylesheet overrides `Styles.xml`
and will pin fonts at whatever scale it was generated for.

## Tests

```
nix-shell -p 'python3.withPackages(ps: [ps.pytest])' --run 'python3 -m pytest tests/ -q'
```
