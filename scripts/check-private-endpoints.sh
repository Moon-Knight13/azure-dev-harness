#!/usr/bin/env bash
set -euo pipefail

# Quick checker: do all private endpoints resolve to private IPs?
# Run from inside the Azure VNet.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
FAILURES=0

check_pe() {
    local fqdn="$1" service="$2"
    local ip
    ip=$(nslookup "$fqdn" 2>/dev/null | grep -oP 'Address:\s+\K10\.\S+' | head -1) || true

    if [[ -n "$ip" ]]; then
        echo -e "${GREEN}[PE OK]${NC} $service: $fqdn → $ip"
    else
        local any_ip
        any_ip=$(nslookup "$fqdn" 2>/dev/null | grep -oP 'Address:\s+\K\d+\.\S+' | tail -1) || true
        if [[ -n "$any_ip" ]]; then
            echo -e "${RED}[PUBLIC]${NC} $service: $fqdn → $any_ip (should be 10.x private)"
        else
            echo -e "${RED}[NO DNS]${NC} $service: $fqdn — cannot resolve"
        fi
        ((FAILURES++))
    fi
}

echo "Checking private endpoint DNS resolution..."
echo "Each should resolve to a 10.x.x.x private IP."
echo ""

# ACR
if [[ -n "${AZURE_ACR_NAME:-}" ]]; then
    check_pe "${AZURE_ACR_NAME}.azurecr.io" "ACR"
else
    echo -e "${YELLOW}[SKIP]${NC} ACR: set AZURE_ACR_NAME"
fi

# Key Vault
if [[ -n "${AZURE_KEYVAULT_NAME:-}" ]]; then
    check_pe "${AZURE_KEYVAULT_NAME}.vault.azure.net" "Key Vault"
else
    echo -e "${YELLOW}[SKIP]${NC} Key Vault: set AZURE_KEYVAULT_NAME"
fi

# SQL
if [[ -n "${AZURE_SQL_SERVER:-}" ]]; then
    check_pe "$AZURE_SQL_SERVER" "Azure SQL"
else
    echo -e "${YELLOW}[SKIP]${NC} SQL: set AZURE_SQL_SERVER"
fi

# App Service
if [[ -n "${AZURE_APP_NAME:-}" ]]; then
    check_pe "${AZURE_APP_NAME}.azurewebsites.net" "App Service"
else
    echo -e "${YELLOW}[SKIP]${NC} App Service: set AZURE_APP_NAME"
fi

echo ""
if [[ $FAILURES -gt 0 ]]; then
    echo -e "${RED}$FAILURES service(s) not resolving to private IPs.${NC}"
    echo "Fix: Private DNS zone missing or not linked to VNet."
    exit 1
else
    echo -e "${GREEN}All private endpoints resolve correctly.${NC}"
fi
