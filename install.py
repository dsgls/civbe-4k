#!/usr/bin/env python3
"""Install the vendored ui/ trees into the game install.

The repo standardizes on LF; the stock files are CRLF. Whether the engine
tolerates LF everywhere is unproven, so the default converts each file to CRLF
on the way. `--keep-lf` installs the bytes as they are in the repo, which is
the switch for A/B-testing line-ending sensitivity in game.

    install.py                    # default install path from analysis/paths.py
    install.py "<game dir>"       # elsewhere
    install.py --keep-lf          # no conversion

Only the files under ui/ are written; nothing is deleted. Restore by copying
the same paths back from reference/ (stock, CRLF).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis"))
from paths import GAME, PROJECT

SOURCE = os.path.join(PROJECT, "ui")


def to_crlf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")


def main(argv):
    keep_lf = "--keep-lf" in argv
    argv = [a for a in argv if a != "--keep-lf"]
    game = argv[1] if len(argv) > 1 else GAME
    if not os.path.isdir(os.path.join(game, "assets")):
        print("no assets/ under %s - not a game install?" % game)
        return 1

    written = unchanged = 0
    for dp, dn, fn in os.walk(SOURCE):
        for f in sorted(fn):
            src = os.path.join(dp, f)
            rel = os.path.relpath(src, SOURCE)
            dst = os.path.join(game, rel)
            data = open(src, "rb").read()
            if not keep_lf:
                data = to_crlf(data)
            if os.path.exists(dst) and open(dst, "rb").read() == data:
                unchanged += 1
                continue
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as fh:
                fh.write(data)
            written += 1

    print("%s -> %s" % (SOURCE, game))
    print("wrote %d files (%s), %d already up to date"
          % (written, "LF kept" if keep_lf else "converted to CRLF", unchanged))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
