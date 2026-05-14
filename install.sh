#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${HYPESHELL_REPO_URL:-https://github.com/acarlton5/HypeShell.git}"
BRANCH="${HYPESHELL_BRANCH:-main}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TEMP_DIR=""

cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if [ "$(id -u)" = "0" ]; then
    echo "Error: do not run this installer as root. It will use sudo when needed." >&2
    exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
    echo "Error: HypeShell installer only supports Linux." >&2
    exit 1
fi

if [ -f "$SCRIPT_DIR/scripts/migrate-from-hypeshell.sh" ]; then
    SOURCE_DIR="$SCRIPT_DIR"
else
    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required to clone $REPO_URL." >&2
        exit 1
    fi

    TEMP_DIR="$(mktemp -d)"
    SOURCE_DIR="$TEMP_DIR/HypeShell"
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$SOURCE_DIR"
fi

if [ "$#" -eq 0 ]; then
    set -- --yes --source "$SOURCE_DIR" --install-greeter --clean
fi

exec "$SOURCE_DIR/scripts/migrate-from-hypeshell.sh" "$@"
