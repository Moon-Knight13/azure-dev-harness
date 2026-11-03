---
name: azure-cost
description: Estimate and optimize Azure resource costs for the dev harness
---

# Azure Cost Estimation

## When to use
When deploying infrastructure or adding Azure resources.

## Steps

1. Run `scripts/cost-estimate.sh` for baseline estimate
2. Check current deployment tier against docs/COST_REFERENCE.md
3. Identify optimization opportunities:
   - Shared firewall vs dedicated
   - ACR Basic vs Premium (public vs private endpoint)
   - Bastion Basic vs Standard (tunneling requirement)
   - App Service B1 vs P1v3 (workload size)
4. Update state file with cost tier:
   ```bash
   scripts/update-state.sh set environment.cost_tier "minimal|standard|full"
   ```
5. Document cost decisions in blockers.md if Microsoft pushback on spend

## SKU decision tree

- Need private endpoints? ACR Premium required ($667/mo)
- Need tunneling/file copy? Bastion Standard required ($139/mo)
- Need FQDN filtering? Azure Firewall required ($912/mo)
- Production workload? App Service P1v3 ($117/mo)
- Hello-world only? App Service B1 ($13/mo)
