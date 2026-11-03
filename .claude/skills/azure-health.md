---
name: azure-health
description: Check all Azure service spokes are reachable via private endpoints. Quick status of entire environment.
---

# Azure Health Check

Run when: "health check", "is everything up", "check services", "spoke status".

## Checks (run all)

### 1. Azure auth
```bash
az account show -o table
```

### 2. Private endpoint DNS resolution
Each must resolve to 10.x (private IP):
```bash
nslookup $AZURE_ACR_NAME.azurecr.io
nslookup $AZURE_KEYVAULT_NAME.vault.azure.net
nslookup $AZURE_SQL_SERVER
```

### 3. ACR reachable
```bash
az acr login -n $AZURE_ACR_NAME
az acr repository list -n $AZURE_ACR_NAME -o table
```

### 4. Key Vault reachable
```bash
az keyvault secret show --vault-name $AZURE_KEYVAULT_NAME --name hello-secret --query value -o tsv
```

### 5. SQL reachable
```bash
sqlcmd -S $AZURE_SQL_SERVER -d $AZURE_SQL_DATABASE -Q "SELECT 1" -G
```

### 6. App Service running
```bash
curl -sf https://<app-url>/health | jq .
```

### 7. MCP servers (if configured)
Use `@azure/mcp` to query Resource Graph:
- List resources in resource group
- Check private endpoint status

## Report format
```
Azure Health — <date>
  Auth:     OK (subscription: <name>)
  ACR:      OK (resolves to 10.x.x.x)
  KV:       OK (secret readable)
  SQL:      OK (query returns)
  App:      OK (health endpoint 200)
  MCPs:     OK / NOT CONFIGURED
```

Update state: `scripts/update-state.sh set-timestamp last_health_check`
Log blockers: `scripts/update-state.sh append-blocker "<issue>"`
