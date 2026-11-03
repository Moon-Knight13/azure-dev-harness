# Runbook: Private Endpoint DNS Debugging

## Symptom
Service unreachable from dev VM. Connection timeout or public IP returned.

## Quick check
```bash
./scripts/check-private-endpoints.sh
```

## Manual steps

### 1. Check DNS resolution
```bash
nslookup <service>.privatelink.<zone>
```
Expected: 10.x.x.x (private IP)

### 2. If public IP returned
Private DNS zone not linked to VNet, or VM using wrong DNS server.
```bash
cat /etc/resolv.conf
# Should show 168.63.129.16 (Azure DNS)
```

### 3. If no resolution
Private DNS zone doesn't exist or A record missing.
```bash
az network private-dns zone list -g $AZURE_RESOURCE_GROUP -o table
az network private-dns record-set a list -g $AZURE_RESOURCE_GROUP -z <zone> -o table
```

### 4. If A record exists but wrong IP
Private endpoint was recreated. DNS record is stale.
```bash
az network private-endpoint show -n <pe-name> -g $AZURE_RESOURCE_GROUP \
  --query 'customDnsConfigurations[].{fqdn:fqdn, ip:ipAddresses[0]}' -o table
```

## Zone reference

| Service | Private DNS Zone |
|---------|-----------------|
| ACR | privatelink.azurecr.io |
| Key Vault | privatelink.vaultcore.azure.net |
| SQL | privatelink.database.windows.net |
| App Service | privatelink.azurewebsites.net |
| Storage | privatelink.blob.core.windows.net |

## Escalation
If DNS zone or VNet link missing: Microsoft must create it. This is infra, not
app-layer. File with networking/security contact.
