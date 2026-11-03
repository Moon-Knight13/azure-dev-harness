#!/usr/bin/env bash
set -euo pipefail

echo "project-setup.sh: Azure Dev Harness initialization"

STATE_FILE=".state/environment.json"
STATE_TEMPLATE=".state/environment.json.template"

if [[ ! -f "$STATE_FILE" ]] && [[ -f "$STATE_TEMPLATE" ]]; then
    cp "$STATE_TEMPLATE" "$STATE_FILE"
    echo "  Initialized state file from template"
fi

if command -v az &>/dev/null; then
    az bicep install --only-show-errors 2>/dev/null || true
    echo "  Bicep CLI ready"
else
    echo "  WARN: Azure CLI not installed. Run devcontainer rebuild."
fi

if [[ -f src/app/package.json ]]; then
    (cd src/app && npm install --silent 2>/dev/null) || true
    echo "  Node dependencies installed"
fi

echo "project-setup.sh: done"
