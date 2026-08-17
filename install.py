#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Install the vendored ui/ trees and the phase-2 textures into the game.

The repo standardizes on LF; the stock files are CRLF. Whether the engine
tolerates LF everywhere is unproven, so the default converts each .xml/.lua to
CRLF on the way. `--keep-lf` installs the bytes as they are in the repo, which
is the switch for A/B-testing line-ending sensitivity in game.

The 2x textures are far too large to vendor, so they ship as a generic package
on git.dsg.is. `TEXTURE_VERSION` below pins which one this checkout expects: the
package is downloaded once into ~/.cache/civbe-4k, SHA-256 verified, and
extracted into the game directory. Bumping the pin is what makes an install
fetch a new package; `package-textures.sh` builds and uploads one and prints
the two lines to update.

    install.py                    # default install path from analysis/paths.py
    install.py "<game dir>"       # elsewhere
    install.py --keep-lf          # no line-ending conversion
    install.py --no-textures      # ui/ only, skip the texture package
    install.py --force-textures   # re-extract even if already up to date

Only the files under ui/ and the package are written; nothing is deleted.
Restore by copying the same paths back from reference/ (stock, CRLF).
"""
import hashlib
import os
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis"))
from paths import GAME, PROJECT

SOURCE = os.path.join(PROJECT, "ui")

# Only these are line-ending converted; every other suffix is binary. Running
# the conversion over a .dds would rewrite every 0x0A that falls in pixel data.
TEXT_SUFFIXES = (".xml", ".lua")

TEXTURE_VERSION = "0.0.3"
TEXTURE_SHA256 = "3c01dfd9b3d98ff8ae018afa9e5b8c6ab57a65e17464d1848617f7360c09747d"
TEXTURE_URL = (
    "https://git.dsg.is/api/packages/dsg/generic/civbe-4k-textures/"
    "{v}/civbe-4k-textures-v{v}.tar.xz"
)
CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "civbe-4k")
# Records which package this game directory already has, so a re-run does not
# re-extract a gigabyte over a slow mount.
STAMP = os.path.join("assets", "DLC", "Expansion1", "UI", ".civbe-4k-textures")


def to_crlf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_package() -> str:
    """Return the path to the verified package, downloading it if needed."""
    name = "civbe-4k-textures-v%s.tar.xz" % TEXTURE_VERSION
    cached = os.path.join(CACHE_DIR, name)
    if os.path.exists(cached):
        got = sha256(cached)
        if got == TEXTURE_SHA256:
            return cached
        print("cached %s is sha256 %s, expected %s - refetching"
              % (name, got[:12], TEXTURE_SHA256[:12]))
        os.remove(cached)

    url = TEXTURE_URL.format(v=TEXTURE_VERSION)
    os.makedirs(CACHE_DIR, exist_ok=True)
    print("downloading %s" % url)
    fd, tmp = tempfile.mkstemp(dir=CACHE_DIR, suffix=".part")
    os.close(fd)
    try:
        with urllib.request.urlopen(url, timeout=60) as r, open(tmp, "wb") as fh:
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                fh.write(chunk)
    except (urllib.error.URLError, OSError) as exc:
        os.remove(tmp)
        raise SystemExit("could not download %s: %s" % (url, exc))

    got = sha256(tmp)
    if got != TEXTURE_SHA256:
        os.remove(tmp)
        raise SystemExit(
            "downloaded %s has sha256 %s, expected %s" % (name, got, TEXTURE_SHA256))
    os.replace(tmp, cached)
    return cached


def install_textures(game: str, force: bool) -> None:
    want = "%s %s\n" % (TEXTURE_VERSION, TEXTURE_SHA256)
    stamp = os.path.join(game, STAMP)
    if not force and os.path.exists(stamp):
        with open(stamp) as fh:
            if fh.read() == want:
                print("textures: v%s already installed" % TEXTURE_VERSION)
                return

    pkg = fetch_package()
    print("extracting %s" % os.path.basename(pkg))
    with tarfile.open(pkg, "r:xz") as tf:
        # filter="data" refuses absolute paths and traversal out of the target.
        tf.extractall(game, filter="data")
    os.makedirs(os.path.dirname(stamp), exist_ok=True)
    with open(stamp, "w") as fh:
        fh.write(want)
    print("textures: v%s installed" % TEXTURE_VERSION)


def install_ui(game: str, keep_lf: bool) -> None:
    wrote_text = wrote_binary = unchanged = 0
    for dp, dn, fn in os.walk(SOURCE):
        for f in sorted(fn):
            src = os.path.join(dp, f)
            rel = os.path.relpath(src, SOURCE)
            dst = os.path.join(game, rel)
            data = open(src, "rb").read()
            is_text = f.lower().endswith(TEXT_SUFFIXES)
            if is_text and not keep_lf:
                data = to_crlf(data)
            if os.path.exists(dst) and open(dst, "rb").read() == data:
                unchanged += 1
                continue
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as fh:
                fh.write(data)
            if is_text:
                wrote_text += 1
            else:
                wrote_binary += 1

    print("%s -> %s" % (SOURCE, game))
    extra = " + %d binary verbatim" % wrote_binary if wrote_binary else ""
    print("wrote %d text (%s)%s, %d already up to date"
          % (wrote_text, "LF kept" if keep_lf else "converted to CRLF",
             extra, unchanged))


def main(argv):
    flags = {a for a in argv if a.startswith("--")}
    unknown = flags - {"--keep-lf", "--no-textures", "--force-textures"}
    if unknown:
        print("unknown option(s): %s" % ", ".join(sorted(unknown)))
        return 2
    argv = [a for a in argv if not a.startswith("--")]
    game = argv[1] if len(argv) > 1 else GAME
    if not os.path.isdir(os.path.join(game, "assets")):
        print("no assets/ under %s - not a game install?" % game)
        return 1

    install_ui(game, "--keep-lf" in flags)
    if "--no-textures" in flags:
        print("textures: skipped")
    else:
        install_textures(game, "--force-textures" in flags)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
