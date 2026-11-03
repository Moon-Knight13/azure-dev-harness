# Azure Cost Reference

Quick reference for Azure service pricing relevant to the dev harness.
Estimates based on East US, Pay-As-You-Go. Run `scripts/cost-estimate.sh` for full breakdown.

## Deployment Tiers

| Tier | Monthly Est. | What's included |
|------|-------------|-----------------|
| Minimal | ~$160 | No firewall, no Bastion, Basic ACR, B1 App Service |
| Standard | ~$970 | Shared firewall, Standard Bastion, Basic ACR, P1v3 |
| Full | ~$1,882 | Dedicated firewall, Standard Bastion, Premium ACR, P1v3 |

## Key SKU Decisions

### Azure Firewall ($912/mo)
Biggest cost driver. If Microsoft provides a shared/central firewall with FQDN
rules for your VNet, skip deploying one. Ask: "Can we add FQDN allow rules to
the hub firewall for our dev VNet?"

### Azure Container Registry
- **Basic**: $5/mo, no private endpoint, public access only
- **Premium**: $667/mo, private endpoint support, geo-replication

If the security posture requires all traffic stays private, Premium is mandatory.
Otherwise Basic works for dev.

### Azure Bastion
- **Basic**: $27/mo, RDP/SSH only
- **Standard**: $139/mo, tunneling, file copy, shareable links

Standard required for `az network bastion tunnel` (SSH from local machine).

### App Service Plan
- **B1**: $13/mo, 1 core, 1.75 GB RAM — fine for hello-world
- **P1v3**: $117/mo, 2 cores, 8 GB RAM — production workloads, VNet integration

## References
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [App Service Landing Zone Accelerator](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/app-platform/app-services/landing-zone-accelerator)
