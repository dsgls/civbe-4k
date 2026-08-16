"""The UI trees the sweep covers.

A DLC ships its own copy of a UI file at the same relative path as the base
one, and the engine loads the DLC copy in preference: with Rising Tide
installed the main menu comes from `Assets/DLC/Expansion1/UI`, not from
`Assets/UI`. Patching only the base tree therefore leaves everything the
expansion replaces at stock size, which is most of the interface.

So every tree is swept. Whether a DLC is enabled is player configuration and
is not readable from the install directory, so an installed-but-disabled DLC
is patched too: the engine simply never loads it, and the pristine copy makes
it reversible either way.
"""
from dataclasses import dataclass
from pathlib import Path

BASE = "base"
_ASSETS = "assets"
_DLC = "DLC"
_UI = "UI"


@dataclass(frozen=True)
class Tree:
    """One UI tree: where the game loads it from, and where its pristine copy
    lives inside the backup root (as an install-relative path, so the backup
    mirrors the install and needs no manifest to describe itself)."""
    name: str
    live_dir: Path
    backup_rel: Path


def child(path: Path, name: str) -> Path:
    """Case-insensitive child lookup; installs vary in casing."""
    if (path / name).exists():
        return path / name
    lowered = name.lower()
    for entry in path.iterdir():
        if entry.name.lower() == lowered:
            return entry
    raise FileNotFoundError("%s not found under %s" % (name, path))


def resolve(root, *names):
    """Walk `names` case-insensitively. None if any segment is missing."""
    path = Path(root)
    for name in names:
        try:
            path = child(path, name)
        except (FileNotFoundError, NotADirectoryError):
            return None
    return path


def find_ui_dir(game_dir) -> Path:
    return child(child(Path(game_dir), _ASSETS), _UI)


def discover(game_dir) -> list:
    """Every UI tree present in the install, base tree first."""
    game_dir = Path(game_dir)
    found = [Tree(BASE, find_ui_dir(game_dir), Path(_ASSETS) / _UI)]

    dlc_dir = resolve(game_dir, _ASSETS, _DLC)
    for entry in sorted(dlc_dir.iterdir()) if dlc_dir else ():
        if not entry.is_dir():
            continue
        ui_dir = resolve(entry, _UI)
        if ui_dir is None:
            continue
        found.append(Tree(
            name=entry.name,
            live_dir=ui_dir,
            backup_rel=Path(_ASSETS) / _DLC / entry.name / _UI,
        ))
    return found
