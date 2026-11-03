# Claude Workflow Contract — Azure Dev Harness

## Mission
Get productive on any Azure environment fast. Bootstrap, validate, deploy, and
troubleshoot Azure infrastructure with Claude as an Azure DevOps expert.

## Priority Order
1. Connectivity — can we reach Azure services?
2. Deployment — can we ship code to Azure?
3. Observability — can we see what's happening?
4. Developer experience — is the workflow smooth?

## Truth Hierarchy
When information conflicts, trust in this order:
1. Azure Resource Graph (live state via `@azure/mcp`)
2. `azd env` output (deployed environment)
3. `.state/environment.json` (local session state)
4. GitHub issues / board
5. `docs/` (runbooks, ADRs, engagement notes)

## State Contract
**Read `.state/environment.json` before any Azure operation.** Update it after
deployments, health checks, or blocker changes. Use `scripts/update-state.sh`
for safe JSON updates. See `.claude/skills/azure-state.md`.

## MCP Servers
Two Azure MCP servers provide live ARM/Resource Graph access:
- `@azure/mcp` — official Microsoft MCP (ARM operations, Resource Graph queries)
- `azops-mcp` — community MCP (90+ Azure operations tools)

Config in `.mcp.json`. No other MCP servers needed for this repo.

## Skills
Seven Azure-specific skills in `.claude/skills/`:
| Skill | Purpose |
|-------|---------|
| `azure-bootstrap` | Validate environment connectivity and tools |
| `azd-deploy` | Deploy infrastructure and app via azd |
| `azure-health` | Health check deployed resources |
| `azure-troubleshoot` | Debug common Azure issues |
| `azure-preflight` | Pre-deployment validation |
| `azure-cost` | Cost estimation and optimization |
| `azure-state` | Environment state management |

## Kanban / Board
*Applies only when `SUBSYSTEM_BOARD=true` in `template.conf`. If it is off, use
plain GitHub issues and ignore this section.*

Work is tracked on a per-repo GitHub Project board (see `docs/KANBAN_WORKFLOW.md`).
- Agents pick up work with `/next-issue`, which claims a card collision-safely
  (`scripts/board.sh claim`: self-assign + `wip` + In Progress + re-check).
- Golden rule: never touch a card that is already assigned or In Progress. One
  branch and one PR (`Closes #<n>`) per story. Orchestrate epics with `/run-epic`.
- All board writes go through `scripts/board.sh` (gh-CLI, no secrets).

## Security
- **No passwords anywhere.** All auth via managed identity + AAD.
- **No connection strings.** Use `DefaultAzureCredential` everywhere.
- **Key Vault for secrets.** RBAC authorization, not access policies.
- **All services via private endpoints.** No public network access.
- **Never place credentials or tokens in repository files.**

## Guardrails
- Keep Claude auth in mounted user config outside workspace files.
- Run quality checks before merge: pre-commit, semgrep, gitleaks, CI checks.
- Respect repository protections and required checks.

## Reference Architectures
When Microsoft pushes back on requirements, cite their own published guidance:
- [App Service Landing Zone Accelerator](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/app-platform/app-services/landing-zone-accelerator)
- [Azure Verified Modules](https://aka.ms/avm)
- [DORA 2025](https://dora.dev) — elite performers deploy on demand with <1hr lead time
- [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
- Azure Dev Box / GitHub Codespaces — Microsoft's own dev environment products

## Style
Default response style should be concise and precise.

## Project Instructions
Repository-specific instructions live in `docs/PROJECT.md` when a project has
them. Read that file as well as this one; this contract governs security
and quality gates, while the project file covers what the repository
actually is and how to operate it.

This repository is detached from the template it was created from
(2026-10-16; see `docs/TEMPLATE_GUIDE.md`, "Template Updates — detached"), so
nothing upstream overwrites this file. Keep it to the workflow contract;
project-specific content still belongs in `docs/PROJECT.md`.
