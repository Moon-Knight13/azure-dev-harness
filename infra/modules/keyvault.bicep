@description('Location')
param location string

@description('Key Vault name')
param kvName string

@description('Subnet for private endpoint')
param subnetId string

@description('Private DNS zone for Key Vault')
param privateDnsZoneId string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource helloSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: 'hello-secret'
  properties: {
    value: 'hello-from-keyvault'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${kvName}-pe'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${kvName}-plsc'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource privateDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output kvName string = kv.name
output vaultUri string = kv.properties.vaultUri
output kvId string = kv.id
