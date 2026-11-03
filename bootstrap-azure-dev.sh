#!/usr/bin/env bash
set -euo pipefail

# Azure Dev Environment Bootstrap
# Validates connectivity, installs tools, runs acceptance test.
# Designed for locked-down Azure VMs with no public internet (or filtered egress).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/bootstrap.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
hr()   { echo "────────────────────────────────────────────────────" | tee -a "$LOG_FILE"; }

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

record_pass() { ((PASS_COUNT++)); pass "$@"; }
record_fail() { ((FAIL_COUNT++)); fail "$@"; }
record_warn() { ((WARN_COUNT++)); warn "$@"; }

# ─── Phase 1: Connectivity checks ────────────────────────────────────────────

check_dns() {
    local host="$1"
    if nslookup "$host" &>/dev/null || host "$host" &>/dev/null; then
        record_pass "DNS resolves: $host"
        return 0
    else
        record_fail "DNS cannot resolve: $host"
        return 1
    fi
}

check_https() {
    local url="$1" label="${2:-$1}"
    if curl -sSf --connect-timeout 10 --max-time 15 -o /dev/null "$url" 2>/dev/null; then
        record_pass "HTTPS reachable: $label"
        return 0
    else
        record_fail "HTTPS blocked: $label — filtered egress or private endpoint missing"
        return 1
    fi
}

check_tcp() {
    local host="$1" port="$2"
    if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        record_pass "TCP $host:$port open"
        return 0
    else
        record_fail "TCP $host:$port blocked"
        return 1
    fi
}

phase_connectivity() {
    hr
    log "Phase 1: Connectivity checks"
    hr

    # Azure IMDS — proves we are on an Azure VM
    if curl -sSf -H "Metadata:true" --connect-timeout 3 \
        "http://169.254.169.254/metadata/instance?api-version=2021-02-01" &>/dev/null; then
        record_pass "Azure IMDS reachable (confirmed Azure VM)"
    else
        record_fail "Azure IMDS unreachable — not on Azure VM or IMDS blocked"
    fi

    # DNS for Azure services
    local -a azure_hosts=(
        "management.azure.com"
        "login.microsoftonline.com"
        "mcr.microsoft.com"
        "azurecr.io"
        "vault.azure.net"
        "database.windows.net"
    )
    for h in "${azure_hosts[@]}"; do
        check_dns "$h"
    done

    # Filtered egress — common FQDN allowlist targets
    check_https "https://management.azure.com/health" "Azure Resource Manager"
    check_https "https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration" "Azure AD / Entra ID"
    check_https "https://mcr.microsoft.com/v2/" "Microsoft Container Registry"

    # Package repos (npm, apt, pip) — needed for dev tooling
    check_https "https://registry.npmjs.org/" "npm registry"
    check_https "https://pypi.org/simple/" "PyPI"
    check_dns "archive.ubuntu.com"

    # Git connectivity
    check_https "https://dev.azure.com" "Azure DevOps"
    check_https "https://github.com" "GitHub (may be blocked)"
}

# ─── Phase 2: Tool availability ──────────────────────────────────────────────

check_tool() {
    local cmd="$1" install_hint="${2:-}"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$("$cmd" --version 2>/dev/null | head -1) || ver="(installed)"
        record_pass "$cmd: $ver"
        return 0
    else
        record_fail "$cmd not found. ${install_hint}"
        return 1
    fi
}

phase_tools() {
    hr
    log "Phase 2: Required tools"
    hr

    check_tool "az"      "Install: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    check_tool "azd"     "Install: curl -fsSL https://aka.ms/install-azd.sh | bash"
    check_tool "docker"  "Install: sudo apt-get install -y docker.io"
    check_tool "node"    "Install: see offline-packages/ or curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash"
    check_tool "npm"     "(bundled with node)"
    check_tool "git"     "Install: sudo apt-get install -y git"
    check_tool "jq"      "Install: sudo apt-get install -y jq"
    check_tool "curl"    "Install: sudo apt-get install -y curl"
    check_tool "sqlcmd"  "Install: see https://learn.microsoft.com/sql/tools/sqlcmd"
}

# ─── Phase 3: Azure authentication ───────────────────────────────────────────

phase_auth() {
    hr
    log "Phase 3: Azure authentication"
    hr

    if az account show &>/dev/null; then
        local sub_name sub_id
        sub_name=$(az account show --query name -o tsv 2>/dev/null)
        sub_id=$(az account show --query id -o tsv 2>/dev/null)
        record_pass "Logged in. Subscription: $sub_name ($sub_id)"
    else
        record_fail "Not logged in to Azure CLI. Run: az login"
        warn "If using managed identity: az login --identity"
        return 1
    fi

    # Check managed identity
    if curl -sSf -H "Metadata:true" --connect-timeout 3 \
        "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" &>/dev/null; then
        record_pass "Managed identity token endpoint responding"
    else
        record_warn "Managed identity not available (may need to be assigned)"
    fi
}

# ─── Phase 4: Private endpoint validation ────────────────────────────────────

phase_private_endpoints() {
    hr
    log "Phase 4: Private endpoint DNS (should resolve to 10.x private IPs)"
    hr

    local -a pe_hosts=()

    # Detect resource group from tags or env
    local rg="${AZURE_RESOURCE_GROUP:-}"
    if [[ -z "$rg" ]]; then
        warn "Set AZURE_RESOURCE_GROUP to check private endpoints. Skipping."
        return
    fi

    # List private endpoints in RG
    local endpoints
    endpoints=$(az network private-endpoint list -g "$rg" --query "[].{name:name, fqdns:customDnsConfigurations[].fqdn}" -o json 2>/dev/null) || {
        record_fail "Cannot list private endpoints in $rg"
        return
    }

    local fqdn_count
    fqdn_count=$(echo "$endpoints" | jq '[.[].fqdns[]?] | length' 2>/dev/null) || fqdn_count=0

    if [[ "$fqdn_count" -eq 0 ]]; then
        record_warn "No private endpoint FQDNs found in $rg"
        return
    fi

    # Check each FQDN resolves to private IP
    for fqdn in $(echo "$endpoints" | jq -r '.[].fqdns[]?' 2>/dev/null); do
        local resolved
        resolved=$(nslookup "$fqdn" 2>/dev/null | grep -oP 'Address:\s+\K10\.\S+' | head -1) || true
        if [[ -n "$resolved" ]]; then
            record_pass "$fqdn → $resolved (private)"
        else
            record_fail "$fqdn does NOT resolve to private IP — Private DNS zone missing?"
        fi
    done
}

# ─── Phase 5: Install tools (if egress available) ────────────────────────────

install_tools() {
    hr
    log "Phase 5: Tool installation (requires sudo)"
    hr

    if [[ "${1:-}" != "--install" ]]; then
        log "Skipping install phase. Re-run with --install to attempt installation."
        return
    fi

    # Azure CLI
    if ! command -v az &>/dev/null; then
        log "Installing Azure CLI..."
        if curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 2>>"$LOG_FILE"; then
            record_pass "Azure CLI installed"
        else
            record_fail "Azure CLI install failed — check egress to aka.ms"
        fi
    fi

    # Azure Developer CLI
    if ! command -v azd &>/dev/null; then
        log "Installing azd..."
        if curl -fsSL https://aka.ms/install-azd.sh | bash 2>>"$LOG_FILE"; then
            record_pass "azd installed"
        else
            record_fail "azd install failed — check egress to aka.ms"
        fi
    fi

    # Docker
    if ! command -v docker &>/dev/null; then
        log "Installing Docker..."
        if sudo apt-get update -qq && sudo apt-get install -y -qq docker.io 2>>"$LOG_FILE"; then
            sudo usermod -aG docker "$USER" 2>/dev/null || true
            record_pass "Docker installed (re-login for group membership)"
        else
            record_fail "Docker install failed — check egress to archive.ubuntu.com"
        fi
    fi

    # Node.js 20 LTS
    if ! command -v node &>/dev/null; then
        log "Installing Node.js 20..."
        local offline_node="${SCRIPT_DIR}/offline-packages/node-v20-linux-x64.tar.xz"
        if [[ -f "$offline_node" ]]; then
            sudo tar -xJf "$offline_node" -C /usr/local --strip-components=1
            record_pass "Node.js installed from offline package"
        elif curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - 2>>"$LOG_FILE"; then
            sudo apt-get install -y -qq nodejs 2>>"$LOG_FILE"
            record_pass "Node.js installed from nodesource"
        else
            record_fail "Node.js install failed — place node tarball in offline-packages/"
        fi
    fi
}

# ─── Phase 6: Offline package check ──────────────────────────────────────────

phase_offline() {
    hr
    log "Phase 6: Offline package inventory"
    hr

    local pkg_dir="${SCRIPT_DIR}/offline-packages"
    if [[ ! -d "$pkg_dir" ]] || [[ -z "$(ls -A "$pkg_dir" 2>/dev/null)" ]]; then
        record_warn "offline-packages/ empty — prepare USB fallback with:"
        log "  npm pack (from a connected machine) → offline-packages/"
        log "  docker save mcr.microsoft.com/azure-cli > offline-packages/az-cli.tar"
        log "  Download node-v20-linux-x64.tar.xz → offline-packages/"
        return
    fi

    for f in "$pkg_dir"/*; do
        log "  Found: $(basename "$f") ($(du -h "$f" | cut -f1))"
    done
    record_pass "Offline packages present"
}

# ─── Phase 7: E2E acceptance test ────────────────────────────────────────────

phase_acceptance() {
    hr
    log "Phase 7: E2E acceptance test (hello-world deploy)"
    hr

    local app_dir="${SCRIPT_DIR}/src/app"

    log "Step 1/7: Bastion/SSH connectivity (manual — you are here)"
    record_pass "Bastion SSH: confirmed (you are running this script)"

    log "Step 2/7: git clone"
    if git --version &>/dev/null; then
        record_pass "git available for clone operations"
    else
        record_fail "git not available"
        return
    fi

    log "Step 3/7: npm install"
    if [[ -f "$app_dir/package.json" ]]; then
        if (cd "$app_dir" && npm install --prefer-offline 2>>"$LOG_FILE"); then
            record_pass "npm install succeeded"
        else
            record_fail "npm install failed — check egress to registry.npmjs.org"
        fi
    else
        record_fail "No package.json in src/app/"
    fi

    log "Step 4/7: Docker build + push to ACR"
    local acr_name="${AZURE_ACR_NAME:-}"
    if [[ -z "$acr_name" ]]; then
        record_warn "Set AZURE_ACR_NAME to test ACR push. Skipping."
    elif [[ -f "$app_dir/Dockerfile" ]]; then
        local image_tag="${acr_name}.azurecr.io/hello-world:test"
        if docker build -t "$image_tag" "$app_dir" 2>>"$LOG_FILE" && \
           az acr login -n "$acr_name" 2>>"$LOG_FILE" && \
           docker push "$image_tag" 2>>"$LOG_FILE"; then
            record_pass "Docker build + ACR push succeeded"
        else
            record_fail "Docker build or ACR push failed — check ACR private endpoint"
        fi
    else
        record_fail "No Dockerfile in src/app/"
    fi

    log "Step 5/7: Deploy to App Service (via azd)"
    if command -v azd &>/dev/null; then
        log "Run 'azd up' manually to test full deploy. Checking azd readiness only."
        if [[ -f "${SCRIPT_DIR}/azure.yaml" ]]; then
            record_pass "azure.yaml present — ready for azd up"
        else
            record_fail "azure.yaml missing"
        fi
    else
        record_fail "azd not installed"
    fi

    log "Step 6/7: Key Vault secret read"
    local kv_name="${AZURE_KEYVAULT_NAME:-}"
    if [[ -z "$kv_name" ]]; then
        record_warn "Set AZURE_KEYVAULT_NAME to test. Skipping."
    else
        if az keyvault secret show --vault-name "$kv_name" --name "hello-secret" --query value -o tsv 2>/dev/null; then
            record_pass "Key Vault secret read succeeded"
        else
            record_fail "Key Vault read failed — check private endpoint + access policy"
        fi
    fi

    log "Step 7/7: Azure SQL connectivity"
    local sql_server="${AZURE_SQL_SERVER:-}"
    local sql_db="${AZURE_SQL_DATABASE:-}"
    if [[ -z "$sql_server" || -z "$sql_db" ]]; then
        record_warn "Set AZURE_SQL_SERVER and AZURE_SQL_DATABASE to test. Skipping."
    else
        if check_tcp "$sql_server" 1433; then
            record_pass "SQL Server TCP reachable"
            if command -v sqlcmd &>/dev/null; then
                if sqlcmd -S "$sql_server" -d "$sql_db" -Q "SELECT 1" -G 2>/dev/null; then
                    record_pass "Azure SQL query succeeded (AAD auth)"
                else
                    record_fail "Azure SQL query failed — check firewall rules + AAD auth"
                fi
            else
                record_warn "sqlcmd not installed — TCP reachable but cannot test query"
            fi
        fi
    fi
}

# ─── Summary ─────────────────────────────────────────────────────────────────

summary() {
    hr
    log "SUMMARY"
    hr
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}  ${RED}Failed: $FAIL_COUNT${NC}  ${YELLOW}Warnings: $WARN_COUNT${NC}" | tee -a "$LOG_FILE"
    hr

    if [[ $FAIL_COUNT -gt 0 ]]; then
        log "ACTION: Fix failures above. First failure = first thing Microsoft needs to fix."
        log "Common fixes:"
        log "  - DNS not resolving → Private DNS zones not linked to VNet"
        log "  - HTTPS blocked → Azure Firewall FQDN rule missing"
        log "  - Private IP not resolving → Private endpoint not provisioned"
        log "  - ACR push fails → ACR private endpoint + DNS zone needed"
        log "  - Key Vault fails → access policy or private endpoint"
        log "  - SQL blocked → private endpoint + VNet service endpoint"
        exit 1
    else
        log "All checks passed. Environment ready for development."
        exit 0
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    log "Azure Dev Environment Bootstrap — $(date '+%Y-%m-%d %H:%M:%S')"
    log "Machine: $(hostname) / $(whoami)"
    hr

    phase_connectivity
    phase_tools
    phase_auth
    phase_private_endpoints
    install_tools "$@"
    phase_offline
    phase_acceptance
    summary
}

main "$@"
