#!/usr/bin/env bash
set -euo pipefail

# Azure cost estimator for the dev harness infrastructure.
# Static SKU price table — estimates only, actual costs vary by region and discounts.

cat <<'TABLE'
Azure Dev Harness — Monthly Cost Estimate (East US, Pay-As-You-Go)
═══════════════════════════════════════════════════════════════════

Service                          SKU              Est. Monthly
──────────────────────────────── ──────────────── ────────────
Azure Firewall                   Standard         $  912.50
Azure Bastion                    Standard         $  139.44
Azure Container Registry         Premium          $  667.00
Azure SQL Database               Basic (5 DTU)    $    4.90
App Service Plan                 P1v3 (Linux)     $  116.80
Log Analytics                    Per-GB (1 GB)    $    2.76
Key Vault                        Standard         $    0.03
VNet + Subnets                   (no charge)      $    0.00
Private Endpoints (4x)           (per-hour)       $   29.20
Private DNS Zones (4x)           (per-zone)       $    2.00
Public IPs (2x: FW + Bastion)   Standard         $    7.30
                                                  ────────────
TOTAL                                             $1,881.93/mo

TABLE

echo "Notes:"
echo "  - Azure Firewall is ~49% of total cost. If Microsoft provides"
echo "    a shared firewall, cost drops to ~\$970/mo."
echo "  - ACR Premium required for private endpoint. If public ACR is"
echo "    acceptable, Basic SKU is \$5/mo (saves \$662)."
echo "  - Bastion Standard required for tunneling. Basic is \$27/mo"
echo "    but lacks tunneling and file copy."
echo "  - App Service B1 is \$13/mo vs P1v3 \$117/mo. Use B1 for"
echo "    hello-world testing, P1v3 for real workloads."
echo ""
echo "Optimization options:"
echo "  Minimal (no FW, no Bastion, Basic ACR): ~\$160/mo"
echo "  Standard (shared FW, Standard Bastion):  ~\$970/mo"
echo "  Full (as deployed):                      ~\$1,882/mo"
