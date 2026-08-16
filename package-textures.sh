#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash curl gnutar xz coreutils gawk
# Build the phase-2 texture package and upload it to the Forgejo registry.
#
#   ./package-textures.sh <encoded-dds-root> <version> [--no-upload]
#
# <encoded-dds-root> holds one directory per pack (UITextures,
# Expansion1UITextures, MiscTextures) of encoded 2x .dds. The shipped set is
# whatever ui_textures.txt lists, so the package is reproducible from the work
# list rather than from whatever happens to be lying in a staging directory.
#
# Everything lands under assets/DLC/Expansion1/UI/ inside the tarball: the
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
NAME="civbe-4k-textures-v$VERSION.tar.xz"
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

( cd "$STAGE" && XZ_OPT='-9' tar -cJf "$OUT/$NAME" assets )
SHA=$(sha256sum "$OUT/$NAME" | cut -d' ' -f1)

echo >&2
echo "built $NAME ($(du -h "$OUT/$NAME" | cut -f1))" >&2
echo "pin these in install.py:" >&2
echo "    TEXTURE_VERSION = \"$VERSION\""
echo "    TEXTURE_SHA256 = \"$SHA\""
echo >&2

if [ "$UPLOAD" -eq 1 ]; then
    curl --fail-with-body --user "davidlowsec:$(cat ~/.forgejo-package-key)" \
         --upload-file "$OUT/$NAME" \
         "https://git.dsg.is/api/packages/dsg/generic/civbe-4k-textures/$VERSION/$NAME"
    echo "uploaded $NAME" >&2
fi
