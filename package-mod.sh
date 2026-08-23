#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash zip coreutils perl findutils
# Build the mod zip: the ui/ tree with CRLF baked in, rooted at assets/ so it
# extracts straight into the game directory. CI runs this with plain bash
# (`bash package-mod.sh`), which bypasses the nix-shell shebang.
#
#   ./package-mod.sh <version> [outdir]
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: package-mod.sh <version> [outdir]" >&2
    exit 2
fi
VERSION=$1
OUTDIR=$(cd "${2:-.}" && pwd)

STAMP_DATE="2099-01-01T00:00:00"

HERE=$(cd "$(dirname "$0")" && pwd)
NAME="civbe-4k-v$VERSION.zip"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -r "$HERE/ui/assets" "$STAGE/assets"

# The repo is LF-normalized; the game's stock files are CRLF, and whether the
# engine tolerates LF is unproven, so the shipped files get CRLF baked in.
# Must stay byte-identical to install.py's to_crlf: idempotent, and a final
# line with no newline stays unterminated (sed's s/$/\r/ would grow it).
find "$STAGE" -type f \( -name '*.xml' -o -name '*.lua' \) \
    -exec perl -pi -e 's/\r?\n/\r\n/' {} +

# The engine honours a loose file over a PAK only if the loose file is newer
# (config.ini's LooseFilesOverridePAK), and the archive's stored mtimes are
# what the user's extractor writes. Stamping them far into the future keeps
# the installed files newer than the game's archives no matter when the game
# itself was installed.
find "$STAGE" -exec touch -d "$STAMP_DATE" {} +

n=$(find "$STAGE" -type f | wc -l)
rm -f "$OUTDIR/$NAME"
( cd "$STAGE" && zip -q -r -9 "$OUTDIR/$NAME" assets )
echo "built $NAME ($n files, $(du -h "$OUTDIR/$NAME" | cut -f1))" >&2
