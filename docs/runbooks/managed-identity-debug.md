# Runbook: Managed Identity Debugging

## Symptom
Application or script can't authenticate to Azure services. DefaultAzureCredential fails.

## Quick check
```bash
# On Azure VM — test IMDS token endpoint
curl -sf -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" \
  | jq '.access_token[:20]'
```

## Decision tree

### IMDS not responding (curl fails)
1. Not on Azure VM, or IMDS blocked.
2. Check VM has system-assigned identity:
   ```bash
   az vm show -g $AZURE_RESOURCE_GROUP -n <vm> --query identity -o json
   ```
3. If null: identity not assigned. Tell Microsoft.

### Token returns but 403 on service
Identity exists but lacks RBAC role.

| Service | Required Role |
|---------|--------------|
| ACR pull | AcrPull |
| ACR push | AcrPush |
| Key Vault read | Key Vault Secrets User |
| Key Vault write | Key Vault Secrets Officer |
| SQL | db_datareader (set in SQL, not ARM) |
| Resource Group | Contributor or Reader |

Check:
```bash
PRINCIPAL_ID=$(az vm show -g $AZURE_RESOURCE_GROUP -n <vm> --query identity.principalId -o tsv)
az role assignment list --assignee $PRINCIPAL_ID -o table
```

### App Service managed identity
```bash
PRINCIPAL_ID=$(az webapp show -g $AZURE_RESOURCE_GROUP -n <app> --query identity.principalId -o tsv)
az role assignment list --assignee $PRINCIPAL_ID -o table
```

### DefaultAzureCredential order
The SDK tries these in order:
1. Environment variables (AZURE_CLIENT_ID, etc.)
2. Workload Identity
3. Managed Identity
4. Azure CLI (`az login`)
5. Azure PowerShell
6. Azure Developer CLI (`azd auth login`)

If managed identity is not available, `az login` is the fallback.

## Fix
```bash
# Assign role
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "<role-name>" \
  --scope "<resource-id>"
```
