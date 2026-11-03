# Azure Dev Harness — Project Instructions

## What This Is

A portable, Claude-native platform for bootstrapping and operating Azure dev
environments. Built for teams with locked-down Azure setups (private VNet, no
egress, Bastion-only access) where environment provisioning is incomplete or
misconfigured.

Claude operates as an Azure DevOps expert here — with skills for bootstrap
validation, deployment, health checks, troubleshooting, cost estimation, and
persistent environment state tracking.

## Key Workflows

### First time on a new Azure environment
```bash
./bootstrap-azure-dev.sh       # 7-phase validation
scripts/update-state.sh init   # Initialize state tracking
azd up                         # Deploy infrastructure + app
```

### Daily development
```bash
scripts/update-state.sh show   # Check current state
azd deploy                     # Deploy code changes
# Claude: /azure-health        # Verify deployment
```

### Debugging
```bash
# Claude: /azure-troubleshoot  # Guided troubleshooting
# Runbooks: docs/runbooks/     # Manual procedures
```

## File Layout

```
bootstrap-azure-dev.sh    7-phase environment validator (the crown jewel)
azure.yaml                azd project definition
infra/                    Bicep modules (VNet, ACR, Key Vault, SQL, App Service)
infra/scripts/            Role assignment and infra helpers
src/app/                  Express hello-world with Key Vault + SQL integration
scripts/                  State management, cost estimation, CI helpers
.state/                   Per-environment state (gitignored)
.claude/skills/           7 Azure-specific Claude skills
docs/architecture/        ADRs
docs/runbooks/            Troubleshooting procedures
docs/engagement/          Microsoft visit tracking (contacts, timeline, blockers)
docs/COST_REFERENCE.md    Azure SKU pricing reference
```

## Security Model

All Azure auth uses managed identity and `DefaultAzureCredential`. No passwords,
no connection strings, no client secrets in code or config. Key Vault stores
application secrets with RBAC authorization. All services use private endpoints —
no public network access.

## MCP Servers

Two MCP servers provide live Azure access:
- `@azure/mcp` — ARM operations, Resource Graph queries
- `azops-mcp` — 90+ community Azure tools

Config in `.mcp.json`. Claude reads state from `.state/environment.json` before
any Azure operation.
