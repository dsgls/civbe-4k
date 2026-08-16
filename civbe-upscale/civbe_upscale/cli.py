"""Command-line interface: `batch` and `compare` subcommands.

Both modes are flat and non-recursive over `input_dir`; nothing is skipped
silently -- a non-PNG file, an unreadable file, or a non-RGBA-mode PNG stops
the run with an error before anything is written.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from .apply import apply_upscaler
from .registry import REGISTRY


def _list_dir_files(input_dir: Path) -> list[Path]:
    """Every non-directory entry directly under `input_dir`, sorted by name."""
    return sorted(p for p in input_dir.iterdir() if not p.is_dir())


def _validate_rgba_png(p: Path) -> str | None:
    """Return an error string for `p`, or None if it is a readable RGBA PNG."""
    if p.suffix.lower() != ".png":
        return f"{p}: not a .png file"
    try:
        with Image.open(p) as img:
            img.load()
            mode = img.mode
    except (UnidentifiedImageError, OSError) as exc:
        return f"{p}: unreadable ({exc})"
    if mode != "RGBA":
        return f"{p}: mode {mode!r}, expected RGBA"
    return None


def _list_rgba_pngs(input_dir: Path) -> list[Path]:
    """Validate every file in `input_dir` up front; error out on the first bad batch.

    Validating before writing anything means a bad file aborts the whole run
    instead of leaving a partial output directory behind.
    """
    files = _list_dir_files(input_dir)
    problems = [msg for p in files if (msg := _validate_rgba_png(p)) is not None]
    if problems:
        raise SystemExit("\n".join(["invalid input, nothing written:", *problems]))
    return files


def _parse_crop(spec: str) -> tuple[str, tuple[int, int, int, int]]:
    name, _, rect = spec.partition("=")
    try:
        if not name or not rect:
            raise ValueError
        x, y, w, h = (int(v) for v in rect.split(","))
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"--crop must be <file>=<x,y,w,h>, got {spec!r}"
        ) from None
    return name, (x, y, w, h)


def cmd_batch(args: argparse.Namespace) -> int:
    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    if args.upscaler not in REGISTRY:
        raise SystemExit(
            f"unknown upscaler {args.upscaler!r}; known: {', '.join(sorted(REGISTRY))}"
        )

    files = _list_rgba_pngs(input_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for p in files:
        with Image.open(p) as img:
            img.load()
            out = apply_upscaler(args.upscaler, img)
        out.save(output_dir / p.name)
    return 0


def cmd_compare(args: argparse.Namespace) -> int:
    from . import compare  # lazy: keeps `batch` usable before task 4 lands

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)

    if args.upscalers.strip() == "all":
        names = sorted(REGISTRY)
    else:
        names = [n.strip() for n in args.upscalers.split(",") if n.strip()]
    unknown = [n for n in names if n not in REGISTRY]
    if unknown:
        raise SystemExit(
            f"unknown upscaler(s) {', '.join(unknown)}; known: {', '.join(sorted(REGISTRY))}"
        )

    crops: dict[str, list[tuple[int, int, int, int]]] = {}
    for name, rect in args.crops:
        crops.setdefault(name, []).append(rect)

    return compare.run_compare(input_dir, output_dir, names, crops)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="civbe_upscale", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_batch = sub.add_parser("batch", help="upscale every PNG in a directory 2x")
    p_batch.add_argument("input_dir")
    p_batch.add_argument("output_dir")
    p_batch.add_argument("--upscaler", required=True, metavar="NAME", help="registry name")
    p_batch.set_defaults(func=cmd_batch)

    p_compare = sub.add_parser(
        "compare", help="upscale with multiple upscalers and write a comparison index.html"
    )
    p_compare.add_argument("input_dir")
    p_compare.add_argument("output_dir")
    p_compare.add_argument(
        "--upscalers",
        required=True,
        metavar="NAME[,NAME...]",
        help="comma-separated registry names, or 'all' for the whole registry",
    )
    p_compare.add_argument(
        "--crop",
        action="append",
        dest="crops",
        type=_parse_crop,
        default=[],
        metavar="<file>=<x,y,w,h>",
        help="add a comparison row cropped to this pixel rect of <file> (repeatable)",
    )
    p_compare.set_defaults(func=cmd_compare)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)
