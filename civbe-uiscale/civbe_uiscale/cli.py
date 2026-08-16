"""Command line interface."""
import argparse
import collections
from pathlib import Path

from .apply import restore, run

# The tool lives outside the install, so this is a convenience default only.
DEFAULT_GAME_DIR = Path(
    "/mnt/c/Steam/steamapps/common/Sid Meier's Civilization Beyond Earth"
)
DEFAULT_BACKUP_NAME = "backup-ui-pristine"


def _scale(text):
    value = float(text)
    if not 0.5 <= value <= 4.0:
        raise argparse.ArgumentTypeError("scale %s is outside 0.5-4.0" % text)
    return value


def _build_parser():
    parser = argparse.ArgumentParser(
        prog="civbe-uiscale",
        description="Rescale the Civilization: Beyond Earth UI for high-DPI displays.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    apply_cmd = sub.add_parser("apply", help="patch the UI tree")
    apply_cmd.add_argument("--scale", type=_scale, default=2.0,
                           help="screen geometry and font scale (default: 2.0)")
    apply_cmd.add_argument("--texture-scale", type=_scale, default=1.0,
                           help="scale of the .dds art; leave at 1.0 unless the "
                                "textures have actually been rescaled")
    apply_cmd.add_argument("--no-pin-icon-size", action="store_true",
                           help="do not pin runtime atlas icons to one cell")
    apply_cmd.add_argument("--fast-menu", action="store_true",
                           help="drop the main menu's staggered fade-in and the "
                                "legal disclaimer popup")
    apply_cmd.add_argument("--dry-run", action="store_true")
    apply_cmd.add_argument("--report", type=Path, help="write a per-change listing here")

    restore_cmd = sub.add_parser("restore", help="put the stock UI back")

    for cmd in (apply_cmd, restore_cmd):
        cmd.add_argument("--game-dir", type=Path, default=DEFAULT_GAME_DIR)
        cmd.add_argument("--backup", type=Path, default=None)

    return parser


def _write_report(path: Path, report):
    lines = []
    by_file = collections.defaultdict(list)
    for rel, change in report.details:
        by_file[rel].append(change)
    for rel in sorted(by_file):
        lines.append(rel)
        for change in by_file[rel]:
            lines.append("  %5d  %-14s %-22s %-8s %r -> %r" % (
                change.line,
                getattr(change, "element", getattr(change, "call", "")),
                change.attr if hasattr(change, "attr") else "",
                change.space.value,
                change.old,
                change.new,
            ))
    path.write_text("\n".join(lines) + "\n")


def main(argv=None):
    args = _build_parser().parse_args(argv)
    backup = args.backup or (args.game_dir / DEFAULT_BACKUP_NAME)

    if args.command == "restore":
        restore(args.game_dir, backup)
        print("Stock UI restored from %s" % backup)
        return 0

    report = run(
        args.game_dir, backup,
        ui_scale=args.scale,
        texture_scale=args.texture_scale,
        pin_icon_size=not args.no_pin_icon_size,
        fast_menu=args.fast_menu,
        dry_run=args.dry_run,
    )

    print("UI scale %sx, texture scale %sx%s"
          % (args.scale, args.texture_scale, "  (dry run)" if args.dry_run else ""))
    print("  %d file(s) changed" % report.files_changed)
    print("  %d screen-space value(s) scaled" % report.screen_changes)
    print("  %d texture-space value(s) scaled" % report.texture_changes)
    if report.icon_support_edits:
        print("  %d IconSupport.lua edit(s)" % report.icon_support_edits)
    if args.fast_menu:
        print("  %d front-end animation edit(s)" % report.fast_menu_edits)

    if report.foreign_files:
        print()
        print("WARNING: %d UI file(s) are not in the pristine backup, so the sweep"
              % len(report.foreign_files))
        print("never rewrites them. A LanguageSpecific stylesheet here overrides")
        print("Styles.xml and will pin the fonts at whatever scale it was made for:")
        for rel in report.foreign_files:
            print("  %s" % rel)

    if args.report:
        _write_report(args.report, report)
        print("  per-change listing written to %s" % args.report)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
