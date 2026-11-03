# Runbook: ACR Push Troubleshooting

## Symptom
`docker push` to ACR fails. Timeout, 403, or DNS error.

## Quick check
```bash
az acr login -n $AZURE_ACR_NAME 2>&1
```

## Decision tree

### Login fails with DNS error
Private endpoint DNS not resolving.
```bash
nslookup $AZURE_ACR_NAME.azurecr.io
```
Expected: 10.x.x.x private IP.
If public IP or no resolution: see `private-endpoint-debug.md`.

### Login fails with 403
RBAC issue. Check role assignments:
```bash
az role assignment list --scope $(az acr show -n $AZURE_ACR_NAME --query id -o tsv) -o table
```
Need: `AcrPush` for your identity, `AcrPull` for App Service managed identity.

### Push times out
Network path blocked. Check:
1. Route table forces traffic through firewall
2. Firewall FQDN rule includes `*.azurecr.io`
3. Private endpoint is in correct subnet

### Push succeeds but App Service can't pull
1. Check `acrUseManagedIdentityCreds` in app config:
   ```bash
   az webapp config show -g $AZURE_RESOURCE_GROUP -n <app> --query "acrUseManagedIdentityCreds"
   ```
2. Check App Service managed identity has `AcrPull`:
   ```bash
   az role assignment list --scope $(az acr show -n $AZURE_ACR_NAME --query id -o tsv) \
     --assignee $(az webapp show -g $AZURE_RESOURCE_GROUP -n <app> --query identity.principalId -o tsv) -o table
   ```

## Fix
```bash
./infra/scripts/assign-roles.sh --resource-group $AZURE_RESOURCE_GROUP
```
