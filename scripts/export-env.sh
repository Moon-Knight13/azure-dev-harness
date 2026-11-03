#!/usr/bin/env bash
set -euo pipefail

# Export azd environment values as shell variables.
# Source this after azd up: source scripts/export-env.sh

if ! command -v azd &>/dev/null; then
    echo "azd not installed" >&2
    exit 1
fi

eval "$(azd env get-values 2>/dev/null | grep -E '^[A-Z_]+=' | sed 's/^/export /')"

echo "Exported environment variables:"
env | grep -E '^AZURE_' | sort
