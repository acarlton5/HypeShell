#!/usr/bin/env bash

set -euo pipefail

DEFAULT_REPO_URL="https://github.com/acarlton5/HypeShell.git"
DEFAULT_BRANCH="main"

REPO_URL="$DEFAULT_REPO_URL"
BRANCH="$DEFAULT_BRANCH"
SOURCE_DIR=""
ARGS=("$@")

usage() {
    cat <<EOF
Usage: install.sh [options]

Clean-install HypeShell from source. This works on a fresh Arch install and can
also repair or replace existing HypeShell installs when --clean is supplied.

Common options:
  --yes                 Actually make changes. Without this, dry-run only.
  --install-greeter     Install/configure greetd and the HypeShell greeter.
  --clean               Remove legacy upstream packages and remove sddm after
                        greeter setup succeeds.
  --repo URL            HypeShell git repository to install from.
                        Default: $DEFAULT_REPO_URL
  --branch NAME         Branch to clone. Default: $DEFAULT_BRANCH
  --source DIR          Install from an existing local HypeShell checkout.
  --prefix DIR          Install prefix. Default: /usr/local.
  -h, --help            Show this help.

Examples:
  install.sh --yes
  install.sh --yes --install-greeter --clean
  curl -fsSL https://raw.githubusercontent.com/acarlton5/HypeShell/main/install.sh | bash -s -- --yes --install-greeter --clean
EOF
}

has_arg() {
    local wanted="$1"
    for arg in "${ARGS[@]}"; do
        if [ "$arg" = "$wanted" ]; then
            return 0
        fi
    done
    return 1
}

for ((i = 0; i < $#; i++)); do
    case "${ARGS[$i]}" in
        --repo)
            REPO_URL="${ARGS[$((i + 1))]:-}"
            ;;
        --branch)
            BRANCH="${ARGS[$((i + 1))]:-}"
            ;;
        --source)
            SOURCE_DIR="${ARGS[$((i + 1))]:-}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
    esac
done

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd -P || true)"
if [ -z "$SOURCE_DIR" ] && [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/scripts/install-hypeshell.sh" ]; then
    SOURCE_DIR="$SCRIPT_DIR"
fi

if [ -z "$SOURCE_DIR" ]; then
    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required to install HypeShell from source." >&2
        exit 1
    fi

    WORK_DIR="${TMPDIR:-/tmp}/hypeshell-install-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$WORK_DIR"
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORK_DIR/HypeShell"
    SOURCE_DIR="$WORK_DIR/HypeShell"
fi

if [ ! -f "$SOURCE_DIR/scripts/install-hypeshell.sh" ]; then
    echo "Error: $SOURCE_DIR is not a HypeShell checkout." >&2
    exit 1
fi

if has_arg "--source"; then
    exec "$SOURCE_DIR/scripts/install-hypeshell.sh" "${ARGS[@]}"
fi

exec "$SOURCE_DIR/scripts/install-hypeshell.sh" --source "$SOURCE_DIR" "${ARGS[@]}"
