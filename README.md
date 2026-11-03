# Azure Dev Harness

[![ci](https://github.com/Moon-Knight13/azure-dev-harness/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Moon-Knight13/azure-dev-harness/actions/workflows/ci.yml)
[![semgrep](https://github.com/Moon-Knight13/azure-dev-harness/actions/workflows/semgrep.yml/badge.svg?branch=main)](https://github.com/Moon-Knight13/azure-dev-harness/actions/workflows/semgrep.yml)

A portable, Claude-native platform for bootstrapping and operating Azure dev environments. Built for teams stuck fighting access issues instead of shipping code — especially in locked-down private VNet setups with no internet egress.

## What It Does

- **7-phase bootstrap validator** — connectivity, DNS, tools, auth, private endpoints, offline fallback, E2E acceptance
- **Bicep IaC modules** — VNet, ACR, Key Vault, SQL, App Service — all with private endpoints, managed identity, zero passwords
- **Azure Developer CLI (`azd`) integration** — one-command deploy
- **Claude as Azure expert** — 7 skills, 2 MCP servers (`@azure/mcp` + `azops-mcp`), persistent state tracking
- **Environment state** — `.state/environment.json` persists resource status, blockers, and connectivity between sessions
- **Cost estimation** — SKU pricing reference and optimization tiers ($160–$1,882/mo)
- **Runbooks** — private endpoint debugging, ACR push troubleshooting, managed identity debugging, firewall FQDN management
- **Security gates** — gitleaks, semgrep, pre-commit hooks, CI enforcement

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Azure Private VNet (10.0.0.0/16)               │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ App Svc  │  │   ACR    │  │ Key Vault│      │
│  │ (P.E.)   │  │ (P.E.)  │  │ (P.E.)   │      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘      │
│       │              │              │            │
│  ┌────┴──────────────┴──────────────┴─────┐     │
│  │         Private DNS Zones              │     │
│  └────────────────┬───────────────────────┘     │
│                   │                             │
│  ┌────────────────┴───────────────────────┐     │
│  │  Dev VM / Bastion  ←  Claude + azd     │     │
│  └────────────────────────────────────────┘     │
│                                                 │
│  ┌──────────┐  ┌──────────┐                     │
│  │ SQL (PE) │  │ Firewall │ ← FQDN allowlist   │
│  └──────────┘  └──────────┘                     │
└─────────────────────────────────────────────────┘
```

P.E. = Private Endpoint. All services accessible only via private IP. Firewall provides filtered egress (FQDN allowlist), not zero egress.

## Quick Start

### 1. Open in devcontainer
```bash
git clone https://github.com/Moon-Knight13/azure-dev-harness.git
cd azure-dev-harness
# Open in VS Code → "Reopen in Container"
```

### 2. Authenticate
```bash
az login
azd auth login
```

### 3. Bootstrap and validate
```bash
./bootstrap-azure-dev.sh
```
Runs 7 phases: IMDS, DNS, HTTPS egress, tool versions, Azure auth, private endpoint DNS, and E2E acceptance.

### 4. Deploy
```bash
azd up
```

### 5. Check health
```bash
# Claude skill: /azure-health
# Or manually:
curl -sf https://<app-name>.azurewebsites.net/health
```

## State Tracking

Claude maintains environment state between sessions:
```bash
scripts/update-state.sh show          # Current state
scripts/update-state.sh init          # Initialize from template
scripts/update-state.sh set resources.acr.status "deployed"
scripts/update-state.sh append-blocker "DNS not resolving for ACR"
```

State file: `.state/environment.json` (gitignored, per-environment).

## Cost Tiers

| Tier | Monthly | Notes |
|------|---------|-------|
| Minimal | ~$160 | No firewall, no Bastion, Basic ACR |
| Standard | ~$970 | Shared firewall, Standard Bastion |
| Full | ~$1,882 | Dedicated firewall, Premium ACR, P1v3 |

Run `scripts/cost-estimate.sh` for detailed breakdown. See `docs/COST_REFERENCE.md`.

## Claude Skills

| Skill | Trigger |
|-------|---------|
| `/azure-bootstrap` | Validate environment connectivity and tools |
| `/azd-deploy` | Deploy infrastructure and app |
| `/azure-health` | Health check deployed resources |
| `/azure-troubleshoot` | Debug common Azure issues |
| `/azure-preflight` | Pre-deployment validation |
| `/azure-cost` | Cost estimation and optimization |
| `/azure-state` | Environment state management |

## MCP Servers

- **`@azure/mcp`** — official Microsoft MCP for ARM operations and Resource Graph queries
- **`azops-mcp`** — community MCP with 90+ Azure operations tools

## References

- [App Service Landing Zone Accelerator](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/app-platform/app-services/landing-zone-accelerator)
- [Azure Verified Modules](https://aka.ms/avm)
- [DORA 2025 Report](https://dora.dev)
- [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)

## License

Apache 2.0 — see [LICENSE](LICENSE).
