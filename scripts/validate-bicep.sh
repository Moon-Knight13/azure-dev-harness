#!/usr/bin/env bash
set -euo pipefail

# Validate all Bicep templates without deploying.
# Run locally before visit — no Azure connection needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/../infra"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
FAILURES=0

echo "Validating Bicep templates..."

for f in "$INFRA_DIR"/main.bicep "$INFRA_DIR"/modules/*.bicep; do
    name=$(basename "$f")
    if az bicep build --file "$f" --stdout >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} $name"
    else
        echo -e "${RED}[FAIL]${NC} $name"
        az bicep build --file "$f" 2>&1 | head -5
        ((FAILURES++))
    fi
done

echo ""
if [[ $FAILURES -gt 0 ]]; then
    echo -e "${RED}$FAILURES template(s) failed validation${NC}"
    exit 1
else
    echo -e "${GREEN}All templates valid${NC}"
fi
