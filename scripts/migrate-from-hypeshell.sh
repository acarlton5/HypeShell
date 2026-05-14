#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd -P)"

echo "migrate-from-hypeshell.sh is deprecated; use install.sh or scripts/install-hypeshell.sh." >&2
exec "$SCRIPT_DIR/install-hypeshell.sh" "$@"
