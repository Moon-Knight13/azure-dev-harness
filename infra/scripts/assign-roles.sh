#!/usr/bin/env bash
set -euo pipefail

# Assign RBAC roles so App Service managed identity can access ACR, Key Vault, SQL.
# Idempotent — safe to re-run. Reads from state file or azd env.

STATE_FILE=".state/environment.json"

usage() {
    echo "Usage: $0 [--resource-group RG]"
    echo "  If --resource-group not given, reads from state file or azd env."
    exit 1
}

RG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --resource-group) RG="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$RG" ]] && [[ -f "$STATE_FILE" ]]; then
    RG=$(jq -r '.environment.resource_group // empty' "$STATE_FILE")
fi

if [[ -z "$RG" ]]; then
    RG=$(azd env get-values 2>/dev/null | grep AZURE_RESOURCE_GROUP | cut -d= -f2 | tr -d '"' || true)
fi

if [[ -z "$RG" ]]; then
    echo "ERROR: Cannot determine resource group. Pass --resource-group or set in state file."
    exit 1
fi

echo "Resource group: $RG"

ACR_NAME="${AZURE_ACR_NAME:-}"
KV_NAME="${AZURE_KEYVAULT_NAME:-}"

if [[ -z "$ACR_NAME" ]] && [[ -f "$STATE_FILE" ]]; then
    ACR_NAME=$(jq -r '.resources.acr.name // empty' "$STATE_FILE")
fi
if [[ -z "$ACR_NAME" ]]; then
    ACR_NAME=$(azd env get-values 2>/dev/null | grep AZURE_ACR_NAME | cut -d= -f2 | tr -d '"' || true)
fi

if [[ -z "$KV_NAME" ]] && [[ -f "$STATE_FILE" ]]; then
    KV_NAME=$(jq -r '.resources.keyvault.name // empty' "$STATE_FILE")
fi
if [[ -z "$KV_NAME" ]]; then
    KV_NAME=$(azd env get-values 2>/dev/null | grep AZURE_KEYVAULT_NAME | cut -d= -f2 | tr -d '"' || true)
fi

APP_NAME=$(az webapp list -g "$RG" --query "[0].name" -o tsv 2>/dev/null || true)
if [[ -z "$APP_NAME" ]]; then
    echo "No App Service found in $RG. Deploy first with 'azd up'."
    exit 1
fi

PRINCIPAL_ID=$(az webapp show -g "$RG" -n "$APP_NAME" --query "identity.principalId" -o tsv)
if [[ -z "$PRINCIPAL_ID" ]]; then
    echo "ERROR: App Service $APP_NAME has no managed identity. Enable it first."
    exit 1
fi

echo "App: $APP_NAME"
echo "Principal: $PRINCIPAL_ID"

assign_role() {
    local role="$1" scope="$2" label="$3"
    existing=$(az role assignment list --assignee "$PRINCIPAL_ID" --role "$role" --scope "$scope" --query "length(@)" -o tsv 2>/dev/null || echo "0")
    if [[ "$existing" -gt 0 ]]; then
        echo "  $label: already assigned"
    else
        echo "  $label: assigning..."
        az role assignment create \
            --assignee-object-id "$PRINCIPAL_ID" \
            --assignee-principal-type ServicePrincipal \
            --role "$role" \
            --scope "$scope" \
            --output none
        echo "  $label: done"
    fi
}

if [[ -n "$ACR_NAME" ]]; then
    ACR_RESOURCE_ID=$(az acr show -n "$ACR_NAME" --query id -o tsv)
    assign_role "AcrPull" "$ACR_RESOURCE_ID" "AcrPull on $ACR_NAME"
else
    echo "  ACR: skipped (no ACR name found)"
fi

if [[ -n "$KV_NAME" ]]; then
    KV_RESOURCE_ID=$(az keyvault show -n "$KV_NAME" --query id -o tsv)
    assign_role "Key Vault Secrets User" "$KV_RESOURCE_ID" "Key Vault Secrets User on $KV_NAME"
else
    echo "  Key Vault: skipped (no KV name found)"
fi

SQL_SERVER="${AZURE_SQL_SERVER:-}"
SQL_DB="${AZURE_SQL_DATABASE:-appdb}"
if [[ -z "$SQL_SERVER" ]] && [[ -f "$STATE_FILE" ]]; then
    SQL_SERVER=$(jq -r '.resources.sql.server // empty' "$STATE_FILE")
fi

echo ""
echo "SQL AAD user setup (requires AAD admin on SQL server):"
if [[ -n "$SQL_SERVER" ]]; then
    echo "  Run manually:"
    echo "    sqlcmd -S $SQL_SERVER -d $SQL_DB -G -Q \\"
    echo "      \"IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='$APP_NAME') BEGIN CREATE USER [$APP_NAME] FROM EXTERNAL PROVIDER; ALTER ROLE db_datareader ADD MEMBER [$APP_NAME]; END\""
else
    echo "  SQL server not configured. Set AZURE_SQL_SERVER or update state file."
fi

echo ""
echo "Role assignment complete."
