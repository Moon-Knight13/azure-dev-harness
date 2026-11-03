---
name: azd-deploy
description: Deploy infrastructure and app via azd with pre-flight validation and acceptance test. Use after bootstrap passes.
---

# azd Deploy

Run when: "deploy", "azd up", "ship it", "stand up environment".

## Pre-flight (do NOT skip)

1. **Verify bootstrap passed:**
   ```bash
   ./bootstrap-azure-dev.sh 2>&1 | tail -5
   ```
   If failures exist, fix those first. Do not deploy into broken environment.

2. **Check auth:**
   ```bash
   az account show --query '{sub:name, id:id, tenant:tenantId}' -o table
   ```
   Confirm correct subscription.

3. **Check azd env:**
   ```bash
   azd env list
   ```
   Create if needed: `azd env new <name>`

## Deploy

```bash
azd up
```

This deploys:
- VNet + subnets + Azure Firewall + Bastion
- ACR (Premium, private endpoint)
- Key Vault (RBAC auth, private endpoint, seeded with hello-secret)
- Azure SQL (AAD-only, private endpoint)
- App Service (Linux container, VNet integrated, managed identity, private endpoint)
- Private DNS zones for all services
- Log Analytics workspace

## Post-deploy

1. **Assign RBAC roles:**
   ```bash
   ./infra/scripts/assign-roles.sh
   ```

2. **Build and push container:**
   ```bash
   az acr login -n $AZURE_ACR_NAME
   docker build -t $AZURE_ACR_NAME.azurecr.io/hello-world:latest src/app/
   docker push $AZURE_ACR_NAME.azurecr.io/hello-world:latest
   ```

3. **Seed database:**
   ```bash
   sqlcmd -S $AZURE_SQL_SERVER -d $AZURE_SQL_DATABASE -i src/db/init.sql -G
   ```

4. **Run acceptance test:**
   ```bash
   curl https://<app-url>/health
   curl https://<app-url>/secret
   curl https://<app-url>/sql
   ```
   All three must return 200 with valid data.

5. **Update state:**
   ```bash
   scripts/update-state.sh set resources.appservice.status "deployed"
   scripts/update-state.sh set-timestamp last_deploy
   ```

## If deploy fails
- ARM deployment error → check `az deployment group show` for details
- Private endpoint DNS → `nslookup <service>.privatelink.<zone>` must return 10.x
- ACR push denied → check AcrPush role assignment
- App won't start → check `az webapp log tail` and container config
