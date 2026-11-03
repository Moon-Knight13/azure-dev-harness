---
name: azure-bootstrap
description: Validate Azure dev environment connectivity, tools, auth, and private endpoints. Run first on any new environment.
---

# Azure Bootstrap

Run when: first login to Azure VM, new environment setup, "check environment", "bootstrap", "am I connected".

## Steps

1. **Run bootstrap script:**
   ```bash
   ./bootstrap-azure-dev.sh
   ```

2. **Read output carefully.** Each phase reports PASS/FAIL/WARN.

3. **If failures exist**, categorize:
   - DNS failures → Private DNS zones not linked to VNet. Tell Microsoft.
   - HTTPS blocked → Azure Firewall FQDN rule missing. Tell Microsoft.
   - Tool missing → Run `./bootstrap-azure-dev.sh --install` or use offline-packages/.
   - Auth failed → Run `az login` or check managed identity assignment.
   - Private endpoint wrong IP → PE not provisioned or DNS zone missing.

4. **Log blockers:**
   ```bash
   scripts/update-state.sh append-blocker "FAIL: <what failed>"
   ```
   Also add to `docs/engagement/blockers.md` with owner and requirement reference.

5. **If all pass**, proceed to `azd-deploy` skill.

## Environment variables needed
Set before running if testing specific resources:
- `AZURE_RESOURCE_GROUP` — for private endpoint validation
- `AZURE_ACR_NAME` — for ACR push test
- `AZURE_KEYVAULT_NAME` — for KV read test
- `AZURE_SQL_SERVER` / `AZURE_SQL_DATABASE` — for SQL test

## Offline fallback
If zero egress, check `offline-packages/README.md` for USB bootstrap path.
