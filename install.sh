#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

BIN_DIR=${BIN_DIR:-"$HOME/.local/bin"}
DATA_DIR=${DATA_DIR:-"${XDG_DATA_HOME:-$HOME/.local/share}/anki-jp"}

usage() {
    cat <<EOF
Usage:
  ./install.sh

Environment overrides:
  BIN_DIR          Install executable scripts here
  DATA_DIR         Install shared helper files here
  ANKI_JP_DATA_DIR Runtime override for locating shared helper files

Defaults:
  BIN_DIR=$BIN_DIR
  DATA_DIR=$DATA_DIR
EOF
}

case "${1:-}" in
    --help|-h|help)
        usage
        exit 0
        ;;
    '')
        ;;
    *)
        printf 'error: unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
esac

[ -f "$SCRIPT_DIR/bin/anki-jp" ] || {
    printf 'error: expected file not found: %s\n' "$SCRIPT_DIR/bin/anki-jp" >&2
    exit 1
}
[ -f "$SCRIPT_DIR/lib/anki-jp/common.sh" ] || {
    printf 'error: expected file not found: %s\n' "$SCRIPT_DIR/lib/anki-jp/common.sh" >&2
    exit 1
}

mkdir -p "$BIN_DIR" "$DATA_DIR/lib/anki-jp"

install -m 0755 "$SCRIPT_DIR/bin/anki-jp" "$BIN_DIR/anki-jp"
install -m 0644 "$SCRIPT_DIR/lib/anki-jp/common.sh" "$DATA_DIR/lib/anki-jp/common.sh"

cat <<EOF
Installed:
  $BIN_DIR/anki-jp
  $DATA_DIR/lib/anki-jp/common.sh

Make sure $BIN_DIR is on your PATH.
EOF

if ! command -v kakasi >/dev/null 2>&1; then
    cat <<'EOF'

Tip:
  Install `kakasi` to enable automatic Japanese-to-hiragana conversion for
  shorter `anki-jp ww` commands.
EOF
fi

default_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/anki-jp"
if [ "$DATA_DIR" != "$default_data_dir" ]; then
    cat <<EOF

Because DATA_DIR is custom, also export:
  export ANKI_JP_DATA_DIR=$DATA_DIR
EOF
fi
