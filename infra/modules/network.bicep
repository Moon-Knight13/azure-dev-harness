@description('Location')
param location string

@description('VNet name')
param vnetName string

@description('Bastion name')
param bastionName string

@description('Firewall name')
param firewallName string

// ─── VNet: hub-spoke simplified as single VNet with subnets ──────────────────
// Production: split into hub VNet (fw+bastion) peered to spoke VNet (dev).
// For dev harness: single VNet is simpler and validates the same private endpoints.

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.0.0/26'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.64/26'
        }
      }
      {
        name: 'snet-devvms'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsgDevVms.id }
        }
      }
      {
        name: 'snet-services'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'appServiceDelegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

// ─── NSG for dev VMs ─────────────────────────────────────────────────────────

resource nsgDevVms 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${vnetName}-nsg-devvms'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowBastionInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.0.64/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.0.1.0/24'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ─── Azure Firewall (filtered egress) ────────────────────────────────────────

resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${firewallName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: firewallName
  location: location
  properties: {
    sku: { name: 'AZFW_VNet', tier: 'Standard' }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          publicIPAddress: { id: firewallPip.id }
        }
      }
    ]
    firewallPolicy: { id: firewallPolicy.id }
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: '${firewallName}-policy'
  location: location
  properties: {
    sku: { tier: 'Standard' }
  }
}

resource fqdnRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'dev-egress-rules'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'allow-dev-fqdns'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'azure-services'
            protocols: [{ protocolType: 'Https', port: 443 }]
            sourceAddresses: ['10.0.1.0/24', '10.0.3.0/24']
            targetFqdns: [
              'management.azure.com'
              'login.microsoftonline.com'
              'graph.microsoft.com'
              '*.blob.core.windows.net'
              '*.table.core.windows.net'
              '*.queue.core.windows.net'
              '*.azurecr.io'
              'mcr.microsoft.com'
              '*.data.mcr.microsoft.com'
              '*.vault.azure.net'
              '*.database.windows.net'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'dev-package-repos'
            protocols: [{ protocolType: 'Https', port: 443 }]
            sourceAddresses: ['10.0.1.0/24']
            targetFqdns: [
              'registry.npmjs.org'
              'pypi.org'
              'files.pythonhosted.org'
              'deb.nodesource.com'
              'archive.ubuntu.com'
              'security.ubuntu.com'
              'aka.ms'
              'packages.microsoft.com'
              'azurecliprod.blob.core.windows.net'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'git-repos'
            protocols: [{ protocolType: 'Https', port: 443 }]
            sourceAddresses: ['10.0.1.0/24']
            targetFqdns: [
              'dev.azure.com'
              '*.visualstudio.com'
              'github.com'
              '*.githubusercontent.com'
            ]
          }
        ]
      }
    ]
  }
}

// ─── Route table: force dev VM egress through firewall ───────────────────────

resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: '${vnetName}-rt-devvms'
  location: location
  properties: {
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

// ─── Bastion ─────────────────────────────────────────────────────────────────

resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${bastionName}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  sku: { name: 'Standard' }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: { id: vnet.properties.subnets[1].id }
          publicIPAddress: { id: bastionPip.id }
        }
      }
    ]
    enableTunneling: true
    enableFileCopy: true
  }
}

// ─── Private DNS Zones ───────────────────────────────────────────────────────

var privateDnsZones = [
  'privatelink.azurecr.io'
  'privatelink.vaultcore.azure.net'
  'privatelink.database.windows.net'
  'privatelink.azurewebsites.net'
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zone in privateDnsZones: {
  name: zone
  location: 'global'
}]

resource dnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zone, i) in privateDnsZones: {
  parent: dnsZones[i]
  name: '${replace(zone, '.', '-')}-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}]

// ─── Outputs ─────────────────────────────────────────────────────────────────

output vnetName string = vnet.name
output vnetId string = vnet.id
output devVmsSubnetId string = vnet.properties.subnets[2].id
output servicesSubnetId string = vnet.properties.subnets[3].id
output appSubnetId string = vnet.properties.subnets[4].id
output acrPrivateDnsZoneId string = dnsZones[0].id
output kvPrivateDnsZoneId string = dnsZones[1].id
output sqlPrivateDnsZoneId string = dnsZones[2].id
output appPrivateDnsZoneId string = dnsZones[3].id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
