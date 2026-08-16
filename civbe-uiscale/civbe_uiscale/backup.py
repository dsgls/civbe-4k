"""The pristine backup root.

One directory mirroring the install, so the backup describes itself and
`restore` is a straight copy back to the same install-relative path:

    backup-ui-pristine/assets/UI/...
    backup-ui-pristine/assets/DLC/Expansion1/UI/...

Earlier versions backed up `Assets/UI` alone and put it at the root. That
layout is adopted by renaming it into place, never by re-copying: once a tree
has been patched, its backup is the only stock copy left, so a fall-through
that snapshots a patched tree as "pristine" would destroy the ability to
restore. Hence the layout tests below are positive, and an unrecognised
backup root is an error rather than a fresh start.
"""
import shutil
from pathlib import Path

from .trees import BASE, Tree, resolve

# A copy of Assets/UI always has this at its root; nothing else the tool
# creates does.
_LEGACY_MARKER = "Styles.xml"
_MIGRATING_SUFFIX = ".migrating"
_STOPGAP_SUFFIX = "-dlc"


def is_mirrored(root: Path) -> bool:
    return resolve(root, "assets") is not None


def is_legacy(root: Path) -> bool:
    """A pre-multi-tree backup: the contents of Assets/UI at the root."""
    return (root.exists() and not is_mirrored(root)
            and resolve(root, _LEGACY_MARKER) is not None)


def _staging(root: Path) -> Path:
    return root.with_name(root.name + _MIGRATING_SUFFIX)


def migrate(root: Path, game_dir: Path) -> bool:
    """Bring an existing backup root to the mirrored layout.

    Returns True if anything moved. Raises if the root exists but matches no
    known layout -- better to stop than to treat a patched tree as stock.
    """
    root, game_dir = Path(root), Path(game_dir)
    _absorb_stopgap(root, game_dir)

    staging = _staging(root)
    if staging.exists():
        _finish(staging, root)
        return True
    if not root.exists() or is_mirrored(root):
        return False
    if not any(root.iterdir()):
        return False
    if not is_legacy(root):
        raise ValueError(
            "%s is not a recognisable backup: it has neither an assets/ "
            "directory (current layout) nor a %s (the layout used before DLC "
            "trees were swept). Move it aside and re-run to take a fresh "
            "pristine copy -- but only if the live UI is unpatched."
            % (root, _LEGACY_MARKER))

    root.rename(staging)
    _finish(staging, root)
    return True


def _finish(staging: Path, root: Path):
    """Second half of the migration, also run to completion after a crash."""
    destination = root / "assets" / "UI"
    if destination.exists():
        raise ValueError(
            "both %s and %s hold a base-tree backup; remove whichever is "
            "not pristine" % (staging, destination))
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging.rename(destination)


def _absorb_stopgap(root: Path, game_dir: Path):
    """Undo the private backup an early --fast-menu kept for one DLC file.

    It held the stock copy of the expansion MainMenu.xml. Putting it back over
    the live tree first means the pristine copy taken afterwards is stock.
    """
    stopgap = root.with_name(root.name + _STOPGAP_SUFFIX)
    if not stopgap.exists():
        return
    for source in sorted(stopgap.rglob("*")):
        if not source.is_file():
            continue
        live = resolve(game_dir, "assets", "DLC", *source.relative_to(stopgap).parts)
        if live is not None:
            shutil.copy2(source, live)
    shutil.rmtree(stopgap)


def pristine_dir(tree: Tree, root: Path):
    """Where `tree`'s stock copy is, or None if it has none yet."""
    mirrored = root / tree.backup_rel
    if mirrored.exists():
        return mirrored
    if tree.name == BASE and is_legacy(root):
        return root  # not migrated yet; a dry run never migrates
    return None


def stored_trees(game_dir, root: Path) -> list:
    """Trees that have a pristine copy, in either layout.

    `live_dir` is None when the tree is no longer installed -- a DLC removed
    since the backup was taken. Restoring one would recreate a directory the
    game no longer knows about, so callers skip it.
    """
    game_dir, root = Path(game_dir), Path(root)
    if is_legacy(root):
        return [Tree(BASE, resolve(game_dir, "assets", "UI"), Path("assets/UI"))]

    found = []
    base = resolve(root, "assets", "UI")
    if base is not None:
        found.append(Tree(BASE, resolve(game_dir, "assets", "UI"), Path("assets/UI")))

    dlc = resolve(root, "assets", "DLC")
    for entry in sorted(dlc.iterdir()) if dlc else ():
        if resolve(entry, "UI") is None:
            continue
        found.append(Tree(
            name=entry.name,
            live_dir=resolve(game_dir, "assets", "DLC", entry.name, "UI"),
            backup_rel=Path("assets/DLC") / entry.name / "UI",
        ))
    return found
