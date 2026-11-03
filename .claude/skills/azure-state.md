---
name: azure-state
description: Manage persistent Azure environment state between sessions
---

# Azure State Management

## When to use
At session start, after deployments, when debugging, or when environment changes.

## State file
`.state/environment.json` — tracks resources, connectivity, blockers.

## Commands

### Initialize state
```bash
scripts/update-state.sh init
```

### Read current state
```bash
scripts/update-state.sh show
```

### Update resource status
```bash
scripts/update-state.sh set resources.acr.status "deployed"
scripts/update-state.sh set resources.acr.endpoint "myacr.azurecr.io"
scripts/update-state.sh set resources.acr.private_endpoint true
```

### Track connectivity
```bash
scripts/update-state.sh set-json connectivity '{"imds":true,"dns":true,"https":true,"acr":true,"keyvault":true,"sql":false}'
```

### Log blockers
```bash
scripts/update-state.sh append-blocker "SQL private endpoint DNS not resolving"
scripts/update-state.sh clear-blockers
```

### View history
```bash
scripts/update-state.sh history
```

## Session workflow
1. `scripts/update-state.sh show` — read current state
2. Run bootstrap or deploy
3. Update resource statuses based on results
4. Log any blockers found
5. State persists for next session
