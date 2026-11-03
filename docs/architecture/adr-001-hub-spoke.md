# ADR-001: Hub-Spoke Network with Filtered Egress

## Status
Proposed

## Context
Microsoft is providing a cloud VM in a private Azure VNet. Default setup has
zero internet egress. We need package managers, container registries, and Azure
service access to do any development work.

## Decision
Request hub-spoke topology (simplified as single VNet for dev):
- Azure Firewall in hub subnet with FQDN allowlists
- Bastion in hub subnet for access
- Dev VMs in spoke subnet, routed through firewall
- Services (private endpoints) in dedicated subnet
- App Service VNet integration in dedicated subnet

This matches Microsoft's App Service Landing Zone Accelerator reference
architecture exactly.

## Consequences
- All egress is logged and auditable (firewall logs)
- No public IPs on dev resources
- Package install works via filtered egress
- Azure services accessed via private endpoints, not public internet
- If Microsoft provides zero egress instead: fall back to offline USB packages

## References
- [App Service Landing Zone Accelerator](https://github.com/Azure/appservice-landing-zone-accelerator)
- [Azure Firewall FQDN filtering](https://learn.microsoft.com/azure/firewall/fqdn-filtering-network-rules)
