"""Applying the sweep across a game tree.

Patched output is always derived from the pristine backup, never from the live
files, so re-running at a different scale replaces the previous result instead
of compounding on top of it.
"""
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from . import fastmenu
from .classify import Space
from .luapatch import patch_icon_support, patch_lua
from .xmlpatch import patch_xml

_BOM = b"\xef\xbb\xbf"
ICON_SUPPORT = "IconSupport.lua"

# Rising Tide ships its own front end, and a DLC file wins over the base tree,
# so the menu the player sees comes from here whenever the expansion is
# installed. It sits outside Assets/UI and so outside the pristine backup; the
# --fast-menu pass gives it a backup of its own.
EXPANSION_MAIN_MENU = ("assets", "DLC", "Expansion1", "UI", "FrontEnd", "MainMenu.xml")
EXPANSION_BACKUP_REL = Path("Expansion1/UI/FrontEnd/MainMenu.xml")


@dataclass
class Report:
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


def _child(path: Path, name: str) -> Path:
    """Case-insensitive child lookup; installs vary in casing."""
    if (path / name).exists():
        return path / name
    lowered = name.lower()
    for entry in path.iterdir():
        if entry.name.lower() == lowered:
            return entry
    raise FileNotFoundError("%s not found under %s" % (name, path))


def find_ui_dir(game_dir) -> Path:
    return _child(_child(Path(game_dir), "assets"), "UI")


def expansion_main_menu(game_dir) -> Path:
    """The Rising Tide MainMenu.xml, or None when the expansion is absent."""
    path = Path(game_dir)
    for name in EXPANSION_MAIN_MENU:
        try:
            path = _child(path, name)
        except FileNotFoundError:
            return None
    return path


def expansion_backup_dir(backup_dir) -> Path:
    backup_dir = Path(backup_dir)
    return backup_dir.with_name(backup_dir.name + "-dlc")


def _read(path: Path):
    data = path.read_bytes()
    if data.startswith(_BOM):
        return data[len(_BOM):].decode("utf-8", "surrogateescape"), True
    return data.decode("utf-8", "surrogateescape"), False


def _write(path: Path, text: str, had_bom: bool):
    data = text.encode("utf-8", "surrogateescape")
    path.write_bytes(_BOM + data if had_bom else data)


def run(game_dir, backup_dir, ui_scale, texture_scale,
        pin_icon_size=True, fast_menu=False, dry_run=False) -> Report:
    """Patch the UI tree from the pristine backup. Returns what changed."""
    game_dir, backup_dir = Path(game_dir), Path(backup_dir)
    ui_dir = find_ui_dir(game_dir)

    if not backup_dir.exists() and not dry_run:
        shutil.copytree(ui_dir, backup_dir)

    source_dir = backup_dir if backup_dir.exists() else ui_dir
    report = Report()

    for source in sorted(source_dir.rglob("*")):
        if not source.is_file():
            continue
        suffix = source.suffix.lower()
        if suffix not in (".xml", ".lua"):
            continue

        rel = source.relative_to(source_dir)
        text, had_bom = _read(source)

        if suffix == ".xml":
            patched, changes = patch_xml(text, ui_scale, texture_scale)
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
            destination = ui_dir / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            _write(destination, patched, had_bom)

    _run_expansion(game_dir, backup_dir, fast_menu, dry_run, report)
    report.foreign_files = _foreign_files(ui_dir, source_dir)
    return report


def _run_expansion(game_dir, backup_dir, fast_menu, dry_run, report):
    """Rewrite the Rising Tide MainMenu.xml from its own pristine copy.

    Only --fast-menu touches this file, but once a backup exists every later
    run re-derives from it, so dropping the flag puts the stock menu back.
    """
    live = expansion_main_menu(game_dir)
    if live is None:
        return
    backup = expansion_backup_dir(backup_dir) / EXPANSION_BACKUP_REL
    if not backup.exists():
        if not fast_menu:
            return
        if not dry_run:
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(live, backup)

    text, had_bom = _read(backup if backup.exists() else live)
    patched, changes = text, []
    if fast_menu:
        patched, changes = fastmenu.patch_main_menu(text)
        report.fast_menu_edits += len(changes)

    if patched == _read(live)[0]:
        return
    report.files_changed += 1
    report.record(EXPANSION_BACKUP_REL, changes)
    if not dry_run:
        _write(live, patched, had_bom)


def _foreign_files(ui_dir: Path, source_dir: Path):
    """UI files with no counterpart in the pristine backup.

    Anything another tool dropped in is never rewritten by the sweep, and a
    LanguageSpecific stylesheet overrides Styles.xml, so a stale one silently
    pins the fonts at whatever scale it was generated for.
    """
    if source_dir == ui_dir:
        return []
    found = []
    for live in sorted(ui_dir.rglob("*")):
        if not live.is_file() or live.suffix.lower() not in (".xml", ".lua"):
            continue
        rel = live.relative_to(ui_dir)
        if not (source_dir / rel).exists():
            found.append(rel)
    return found


def restore(game_dir, backup_dir):
    """Copy the pristine backup back over the live UI tree."""
    backup_dir = Path(backup_dir)
    if not backup_dir.exists():
        raise FileNotFoundError("no backup at %s" % backup_dir)
    ui_dir = find_ui_dir(game_dir)
    for source in sorted(backup_dir.rglob("*")):
        if source.is_file():
            destination = ui_dir / source.relative_to(backup_dir)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

    expansion_backup = expansion_backup_dir(backup_dir) / EXPANSION_BACKUP_REL
    live = expansion_main_menu(game_dir)
    if expansion_backup.exists() and live is not None:
        shutil.copy2(expansion_backup, live)
