"""Command line interface: info, decode, encode.

Every command accepts many paths and keeps going past a per-file failure --
a batch over the full 405-texture work list must not stop at the first bad
file. A failure prints "<path>: <error>" to stderr; the exit status is 1 if
any file failed, 0 otherwise.
"""
import argparse
import sys
from pathlib import Path

from . import decode as decode_mod
from . import encode as encode_mod
from . import pair
from .dxt import BLOCK_BYTES
from .header import DDPF_FOURCC, DDPF_LUMINANCE, HEADER_LEN, header, pixel_format
from .png import read_png, write_png


def _out_path(in_path, out_dir, suffix):
    stem = Path(in_path).stem
    directory = Path(out_dir) if out_dir else Path(in_path).parent
    return directory / (stem + suffix)


def _level0_bytes(hdr):
    """Byte size of level 0's pixel data, or None if the format can't be
    sized here (unsupported fourCC). `info`'s truncation check compares
    against this -- and only checks "shorter than", never "equal to" -- so a
    file that legitimately carries more data (a mip chain, cubemap faces) is
    never a false positive. See the design spec's *Decoding* size-check rule.
    """
    if hdr.pfflags & DDPF_FOURCC:
        if hdr.fourcc not in BLOCK_BYTES:
            return None
        blocks_wide, blocks_high = -(-hdr.width // 4), -(-hdr.height // 4)
        return blocks_wide * blocks_high * BLOCK_BYTES[hdr.fourcc]
    if hdr.pfflags & DDPF_LUMINANCE:
        return hdr.width * hdr.height * (hdr.bits // 8)
    if hdr.bits == 32:
        return hdr.width * hdr.height * 4
    return None


def _cmd_info(paths):
    failed = False
    for path in paths:
        try:
            hdr = header(path)
            if hdr is None:
                raise ValueError("not a DDS")
            size = Path(path).stat().st_size
            kind = "pair" if pair.is_pair(path) else "plain"
            print("%s: %dx%d %s tag=%s group=%s mips=%d %s" % (
                path, hdr.width, hdr.height, pixel_format(hdr),
                hdr.tag or "-", hdr.group or "-", hdr.mips, kind))
            level0 = _level0_bytes(hdr)
            if level0 is not None and size - HEADER_LEN < level0:
                print("%s: file is shorter than its level-0 data "
                      "(%d bytes present, %d needed)"
                      % (path, size - HEADER_LEN, level0), file=sys.stderr)
                failed = True
        except Exception as exc:
            print("%s: %s" % (path, exc), file=sys.stderr)
            failed = True
    return failed


def _cmd_decode(paths, out_dir):
    failed = False
    for path in paths:
        try:
            img = decode_mod.read(path)
            out = _out_path(path, out_dir, ".png")
            out.parent.mkdir(parents=True, exist_ok=True)
            write_png(str(out), img)
            print("%s -> %s" % (path, out))
        except Exception as exc:
            print("%s: %s" % (path, exc), file=sys.stderr)
            failed = True
    return failed


def _cmd_encode(paths, out_dir, like, group):
    # Resolved once, up front: it applies uniformly to every input file, and
    # a bad --like target isn't a per-file failure to skip past.
    fixed_group = group
    if like:
        stock_hdr = header(like)
        if stock_hdr is None:
            print("%s: not a DDS" % like, file=sys.stderr)
            return True
        fixed_group = stock_hdr.group

    failed = False
    for path in paths:
        try:
            img = read_png(path)
            out = _out_path(path, out_dir, ".dds")
            out.parent.mkdir(parents=True, exist_ok=True)
            encode_mod.write(str(out), img, group=fixed_group)
            print("%s -> %s" % (path, out))
        except Exception as exc:
            print("%s: %s" % (path, exc), file=sys.stderr)
            failed = True
    return failed


def _build_parser():
    parser = argparse.ArgumentParser(
        prog="civbe_dds",
        description="Decode and encode Civilization: Beyond Earth UI textures.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    info_cmd = sub.add_parser(
        "info", help="print dims, format, tag, group, mips, pair/plain")
    info_cmd.add_argument("paths", nargs="+", metavar="path")

    decode_cmd = sub.add_parser("decode", help="decode .dds to RGBA .png")
    decode_cmd.add_argument("paths", nargs="+", metavar="dds")
    decode_cmd.add_argument("-o", dest="out_dir", metavar="DIR")

    encode_cmd = sub.add_parser("encode", help="encode RGBA .png to plain .dds")
    encode_cmd.add_argument("paths", nargs="+", metavar="png")
    encode_cmd.add_argument("-o", dest="out_dir", metavar="DIR")
    usage_group = encode_cmd.add_mutually_exclusive_group()
    usage_group.add_argument(
        "--like", metavar="STOCK.dds",
        help="carry the FTXT usage name from a stock .dds (default: Interface)")
    usage_group.add_argument("--group", metavar="NAME", help="set the usage name literally")

    return parser


def main(argv=None):
    args = _build_parser().parse_args(argv)
    if args.command == "info":
        failed = _cmd_info(args.paths)
    elif args.command == "decode":
        failed = _cmd_decode(args.paths, args.out_dir)
    else:
        failed = _cmd_encode(args.paths, args.out_dir, args.like, args.group)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
