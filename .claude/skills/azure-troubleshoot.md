---
name: azure-troubleshoot
description: Debug Azure connectivity failures — private endpoint DNS, firewall FQDN rules, RBAC, managed identity. Use when bootstrap or health check reports failures.
---

# Azure Troubleshoot

Run when: bootstrap fails, health check fails, "why can't I reach X", "debug", "troubleshoot".

## Decision tree

### DNS not resolving (nslookup fails)
1. Check private DNS zone exists:
   ```bash
   az network private-dns zone list -g $AZURE_RESOURCE_GROUP -o table
   ```
2. Check zone is linked to VNet:
   ```bash
   az network private-dns link vnet list -g $AZURE_RESOURCE_GROUP -z <zone-name> -o table
   ```
3. Check private endpoint has DNS config:
   ```bash
   az network private-endpoint dns-zone-group list --endpoint-name <pe-name> -g $AZURE_RESOURCE_GROUP -o table
   ```
4. **Fix:** Create zone, link to VNet, add DNS zone group to PE. Or tell Microsoft — this is their infra.

### DNS resolves to public IP (not 10.x)
- Private DNS zone exists but not linked to VNet, OR
- VM using external DNS instead of Azure DNS (168.63.129.16)
- Check: `cat /etc/resolv.conf` — should point to 168.63.129.16

### HTTPS blocked (curl timeout)
1. Check if Azure Firewall exists:
   ```bash
   az network firewall list -g $AZURE_RESOURCE_GROUP -o table
   ```
2. Check FQDN rules:
   ```bash
   az network firewall policy rule-collection-group list --policy-name <policy> -g $AZURE_RESOURCE_GROUP -o json | jq '.[] .ruleCollections[].rules[].targetFqdns'
   ```
3. Check route table forces traffic through firewall:
   ```bash
   az network route-table list -g $AZURE_RESOURCE_GROUP -o table
   ```
4. **Fix:** Add missing FQDN to firewall allowlist. Tell Microsoft exact FQDN needed.

### RBAC denied (403)
1. Check current identity:
   ```bash
   az ad signed-in-user show -o table
   ```
2. Check role assignments:
   ```bash
   az role assignment list --scope /subscriptions/<sub>/resourceGroups/$AZURE_RESOURCE_GROUP -o table
   ```
3. **Common missing roles:**
   - ACR: AcrPull, AcrPush
   - Key Vault: Key Vault Secrets User
   - SQL: db_datareader (set in SQL, not ARM)
   - Resource Group: Contributor

### Managed identity not working
1. Check VM has identity:
   ```bash
   curl -sf -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" | jq .access_token[:20]
   ```
2. If no token: identity not assigned. Tell Microsoft.
3. If token but 403: identity lacks role assignment.

### App Service can't pull from ACR
1. Check managed identity on app:
   ```bash
   az webapp show -g $AZURE_RESOURCE_GROUP -n <app> --query identity -o json
   ```
2. Check AcrPull role:
   ```bash
   az role assignment list --scope <acr-id> --assignee <principal-id> -o table
   ```
3. Check acrUseManagedIdentityCreds is true in site config.

## Escalation template
When filing with Microsoft:
```
Issue: <service> unreachable from dev VM
Expected: <what should work>
Actual: <error or timeout>
DNS resolution: <nslookup output>
Private endpoint: <exists/missing>
Firewall FQDN: <listed/missing>
RBAC: <role assignment status>
```
