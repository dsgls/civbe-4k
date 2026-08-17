#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash p7zip github-cli coreutils
# Build the phase-2 texture package and publish it as a GitHub release.
#
#   ./package-textures.sh <encoded-dds-root> <version> [--no-upload]
#
# <encoded-dds-root> holds one directory per pack (UITextures,
# Expansion1UITextures, MiscTextures) of encoded 2x .dds. The shipped set is
# whatever ui_textures.txt lists, so the package is reproducible from the work
# list rather than from whatever happens to be lying in a staging directory.
#
# Everything lands under assets/DLC/Expansion1/UI/ inside the archive: the
# engine resolves a loose override by bare filename from a UI tree root, and
# the DLC tree wins over a texture packed in the base archive. So the archive
# extracts straight into the game directory.
#
# Prints the version and SHA-256 to pin in install.py.
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n '3,20p' "$0" >&2
    exit 2
fi

SRC=$1
VERSION=$2
UPLOAD=1
[ "${3:-}" = "--no-upload" ] && UPLOAD=0

HERE=$(cd "$(dirname "$0")" && pwd)
LIST="$HERE/ui_textures.txt"
REPO="dsgls/civbe-4k"
NAME="civbe-4k-textures-v$VERSION.7z"
# Built straight into install.py's cache: the archive must not land in the
# repo, and a local build then needs no download to install.
OUT="${XDG_CACHE_HOME:-$HOME/.cache}/civbe-4k"
mkdir -p "$OUT"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
DEST="$STAGE/assets/DLC/Expansion1/UI"
mkdir -p "$DEST"

n=0
while IFS=$'\t' read -r pack file _rest; do
    case "$pack" in \#*|"") continue ;; esac
    src="$SRC/${pack%.fpk}/$file"
    if [ ! -f "$src" ]; then
        echo "missing: $src" >&2
        exit 1
    fi
    cp "$src" "$DEST/$file"
    n=$((n + 1))
done < "$LIST"
echo "staged $n textures" >&2

rm -f "$OUT/$NAME"
( cd "$STAGE" && 7z a -t7z -m0=lzma2 -mx=9 "$OUT/$NAME" assets >/dev/null )
SHA=$(sha256sum "$OUT/$NAME" | cut -d' ' -f1)

echo >&2
echo "built $NAME ($(du -h "$OUT/$NAME" | cut -f1))" >&2
echo "pin these in install.py:" >&2
echo "    TEXTURE_VERSION = \"$VERSION\""
echo "    TEXTURE_SHA256 = \"$SHA\""
echo >&2

if [ "$UPLOAD" -eq 1 ]; then
    gh release create "textures-v$VERSION" --repo "$REPO" \
       --title "Texture pack v$VERSION" \
       --notes "2x UI texture package. Extract into the game directory alongside the mod zip; see the README for the full install procedure." \
       "$OUT/$NAME"
    echo "published release textures-v$VERSION" >&2
fi
