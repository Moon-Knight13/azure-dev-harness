---
name: azure-preflight
description: Pre-visit validation — check Microsoft delivered what was agreed. Run before travel. Use when "preflight", "pre-visit check", "are they ready".
---

# Azure Preflight

Run when: before visit, "are they ready", "preflight", "check requirements".

## Requirements checklist

Verify each item. Mark CONFIRMED / MISSING / UNKNOWN.

### Network & Access
- [ ] Filtered egress through Azure Firewall (not zero egress)
- [ ] Azure Bastion Standard SKU (tunneling + file copy)
- [ ] VPN or Bastion credentials provided
- [ ] FQDN allowlist includes: management.azure.com, login.microsoftonline.com, mcr.microsoft.com, registry.npmjs.org, packages.microsoft.com

### Private Endpoints
- [ ] ACR private endpoint + privatelink.azurecr.io DNS zone
- [ ] Key Vault private endpoint + privatelink.vaultcore.azure.net DNS zone
- [ ] Azure SQL private endpoint + privatelink.database.windows.net DNS zone
- [ ] App Service private endpoint + privatelink.azurewebsites.net DNS zone
- [ ] All DNS zones linked to dev VNet

### Identity & RBAC
- [ ] Managed identity on dev VM
- [ ] Team AAD group with Contributor on resource group
- [ ] AcrPush + AcrPull on ACR
- [ ] Key Vault Secrets Officer on Key Vault
- [ ] SQL AAD admin group configured

### Tooling
- [ ] Azure CLI installed (or egress to install)
- [ ] azd installed (or egress to install)
- [ ] Docker installed
- [ ] Node.js 20 installed
- [ ] git installed

## How to verify remotely (if they gave Bastion access early)
```bash
# SSH via Bastion tunnel
az network bastion ssh -n <bastion> -g <rg> --target-resource-id <vm-id> --auth-type AAD

# Then run
./bootstrap-azure-dev.sh
```

## If items missing
1. Log to `docs/engagement/delivery-checklist.md`
2. Send email with specific gaps citing reference architectures
3. Prepare offline-packages USB as fallback
4. Bring this checklist to day-1 meeting — each unchecked box is a blocker

## Minimum viable (6 items — if they push back on everything)
1. Bastion access (we need a shell)
2. Filtered egress (we need packages)
3. Private endpoints + DNS (we need Azure services)
4. Managed identity + RBAC (we need auth)
5. az/azd/docker pre-installed (we need tools)
6. Reader on subscription (Claude MCP needs Resource Graph)
