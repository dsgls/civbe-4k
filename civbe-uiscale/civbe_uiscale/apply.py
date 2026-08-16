"""Applying the sweep across the game's UI trees.

Patched output is always derived from the pristine backup, never from the live
files, so re-running at a different scale replaces the previous result instead
of compounding on top of it.

Every tree the game can load is swept -- see `trees.py` for why the DLC ones
matter -- and each gets its own pristine copy inside the one backup root.
"""
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from . import backup, fastmenu, styles, trees
from .classify import Space
from .luapatch import patch_icon_support, patch_lua
from .trees import find_ui_dir  # noqa: F401  (re-exported)
from .xmlpatch import patch_xml

_BOM = b"\xef\xbb\xbf"
ICON_SUPPORT = "IconSupport.lua"


@dataclass
class TreeReport:
    """What one tree's sweep changed."""
    name: str
    files_changed: int = 0
    screen_changes: int = 0
    texture_changes: int = 0
    icon_support_edits: int = 0
    fast_menu_edits: int = 0
    details: list = field(default_factory=list)
    foreign_files: list = field(default_factory=list)

    def record(self, rel, changes):
        for change in changes:
            if change.space is Space.SCREEN:
                self.screen_changes += 1
            elif change.space is Space.TEXTURE:
                self.texture_changes += 1
            self.details.append((str(rel), change))


@dataclass
class Report:
    """Every tree's sweep. The totals are what the summary line quotes; the
    per-tree entries are what tells you the DLC tree was actually reached."""
    trees: list = field(default_factory=list)

    def _total(self, attr):
        return sum(getattr(tree, attr) for tree in self.trees)

    @property
    def files_changed(self):
        return self._total("files_changed")

    @property
    def screen_changes(self):
        return self._total("screen_changes")

    @property
    def texture_changes(self):
        return self._total("texture_changes")

    @property
    def icon_support_edits(self):
        return self._total("icon_support_edits")

    @property
    def fast_menu_edits(self):
        return self._total("fast_menu_edits")

    @property
    def details(self):
        """(tree name, file, change) -- the tree name is load-bearing: 102 DLC
        files sit at the same relative path as a base file."""
        return [(tree.name, rel, change)
                for tree in self.trees for rel, change in tree.details]

    @property
    def foreign_files(self):
        return [(tree.name, rel)
                for tree in self.trees for rel in tree.foreign_files]


def _read(path: Path):
    data = path.read_bytes()
    if data.startswith(_BOM):
        return data[len(_BOM):].decode("utf-8", "surrogateescape"), True
    return data.decode("utf-8", "surrogateescape"), False


def _write(path: Path, text: str, had_bom: bool):
    data = text.encode("utf-8", "surrogateescape")
    path.write_bytes(_BOM + data if had_bom else data)


def run(game_dir, backup_dir, ui_scale, texture_scale, pin_icon_size=True,
        fast_menu=False, dry_run=False, skip_trees=()) -> Report:
    """Patch every UI tree from its pristine copy. Returns what changed."""
    game_dir, backup_root = Path(game_dir), Path(backup_dir)
    if not dry_run:
        backup.migrate(backup_root, game_dir)

    found = trees.discover(game_dir)
    base_styles = _base_styles(found, backup_root)

    report = Report()
    for tree in found:
        if tree.name in skip_trees:
            continue
        report.trees.append(_run_tree(
            tree, backup_root, ui_scale, texture_scale, base_styles,
            pin_icon_size=pin_icon_size, fast_menu=fast_menu, dry_run=dry_run,
        ))
    return report


def _base_styles(found, backup_root) -> dict:
    """The base tree's raw style definitions.

    A DLC control can name a style the expansion never redefines, so its tree's
    stylesheets are read over these rather than instead of them. Collected even
    when the base tree is skipped, since the DLC trees still need it.
    """
    for tree in found:
        if tree.name == trees.BASE:
            source_dir = backup.pristine_dir(tree, backup_root) or tree.live_dir
            return styles.collect(source_dir)
    return {}


def _run_tree(tree, backup_root, ui_scale, texture_scale, base_styles,
              pin_icon_size, fast_menu, dry_run) -> TreeReport:
    report = TreeReport(tree.name)
    source_dir = backup.pristine_dir(tree, backup_root)
    if source_dir is None:
        if dry_run:
            source_dir = tree.live_dir  # nothing to derive from yet
        else:
            source_dir = backup_root / tree.backup_rel
            source_dir.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(tree.live_dir, source_dir)

    own_styles = base_styles if tree.name == trees.BASE else {
        **base_styles, **styles.collect(source_dir)}
    style_table = styles.flatten(own_styles)

    for source in sorted(source_dir.rglob("*")):
        if not source.is_file():
            continue
        suffix = source.suffix.lower()
        if suffix not in (".xml", ".lua"):
            continue

        rel = source.relative_to(source_dir)
        text, had_bom = _read(source)

        if suffix == ".xml":
            patched, changes = patch_xml(text, ui_scale, texture_scale, style_table)
        else:
            patched, changes = patch_lua(text, ui_scale, texture_scale)
            if source.name == ICON_SUPPORT and (texture_scale != 1.0 or pin_icon_size):
                patched, edits = patch_icon_support(patched, texture_scale, pin_icon_size)
                report.icon_support_edits += edits

        if fast_menu:
            patched, menu_changes = fastmenu.patch(rel.as_posix(), patched)
            report.fast_menu_edits += len(menu_changes)
            changes = list(changes) + menu_changes

        if patched == text:
            continue

        report.files_changed += 1
        report.record(rel, changes)
        if not dry_run:
            destination = tree.live_dir / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            _write(destination, patched, had_bom)

    report.foreign_files = _foreign_files(tree.live_dir, source_dir)
    return report


def _foreign_files(live_dir: Path, source_dir: Path):
    """UI files with no counterpart in the pristine copy.

    Anything another tool dropped in is never rewritten by the sweep, and a
    LanguageSpecific stylesheet overrides Styles.xml, so a stale one silently
    pins the fonts at whatever scale it was generated for.
    """
    if source_dir == live_dir:
        return []
    found = []
    for live in sorted(live_dir.rglob("*")):
        if not live.is_file() or live.suffix.lower() not in (".xml", ".lua"):
            continue
        rel = live.relative_to(live_dir)
        if not (source_dir / rel).exists():
            found.append(rel)
    return found


def restore(game_dir, backup_dir):
    """Copy the pristine backup back over every tree it covers.

    Returns the (tree, file count) pairs restored and the names of trees whose
    backup outlived the install -- a DLC removed since the copy was taken.
    """
    backup_root = Path(backup_dir)
    if not backup_root.exists():
        raise FileNotFoundError("no backup at %s" % backup_root)
    backup.migrate(backup_root, game_dir)

    restored, orphaned = [], []
    for tree in backup.stored_trees(game_dir, backup_root):
        source_dir = backup.pristine_dir(tree, backup_root)
        if tree.live_dir is None or source_dir is None:
            orphaned.append(tree.name)
            continue
        count = 0
        for source in sorted(source_dir.rglob("*")):
            if not source.is_file():
                continue
            destination = tree.live_dir / source.relative_to(source_dir)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            count += 1
        restored.append((tree.name, count))
    return restored, orphaned
