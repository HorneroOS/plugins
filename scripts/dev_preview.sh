#!/usr/bin/env bash
# Lightweight local plugin preview and hot-reload helper for HorneroOS plugins.
#
# Usage:
#   scripts/dev_preview.sh <plugin-dir> [--watch]
#
# Validates the plugin payload, installs it locally via horneroctl (if available),
# and triggers `qs ipc call plugins reload` on every file change when `--watch`
# is passed.
set -euo pipefail

usage() {
    echo "Usage: $0 <plugin-dir> [--watch]" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage

PLUGIN_DIR="$(cd "$1" && pwd)"
shift
WATCH=0
if [[ "${1:-}" == "--watch" ]]; then
    WATCH=1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ID="$(basename "$PLUGIN_DIR")"

if [[ ! -f "$PLUGIN_DIR/manifest.json" ]]; then
    echo "error: $PLUGIN_DIR/manifest.json not found" >&2
    exit 1
fi

validate_and_reload() {
    echo "==> Validating $PLUGIN_ID..."
    python3 "$REPO_ROOT/scripts/validate_plugins.py" >/dev/null && echo "    validator: OK"
    if command -v horneroctl >/dev/null 2>&1; then
        horneroctl plugin validate "$PLUGIN_DIR"
        horneroctl plugin install-local "$PLUGIN_DIR" --yes
        horneroctl plugin trust "$PLUGIN_ID" --yes || true
        horneroctl plugin enable "$PLUGIN_ID" --yes || true
    else
        echo "    note: horneroctl not found in PATH; skipping install-local"
    fi
    if command -v qs >/dev/null 2>&1; then
        qs ipc call plugins reload || true
        qs ipc call plugins status || true
    else
        echo "    note: qs not found in PATH; skipping live shell reload"
    fi
}

validate_and_reload

if [[ "$WATCH" -eq 1 ]]; then
    echo "==> Watching $PLUGIN_DIR for changes (Ctrl+C to stop)..."
    if command -v inotifywait >/dev/null 2>&1; then
        while inotifywait -qq -r -e modify,create,delete,move "$PLUGIN_DIR"; do
            validate_and_reload || true
        done
    else
        LAST_HASH=""
        while true; do
            CUR_HASH="$(find "$PLUGIN_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | sort | sha256sum)"
            if [[ -n "$LAST_HASH" && "$CUR_HASH" != "$LAST_HASH" ]]; then
                validate_and_reload || true
            fi
            LAST_HASH="$CUR_HASH"
            sleep 1
        done
    fi
fi
