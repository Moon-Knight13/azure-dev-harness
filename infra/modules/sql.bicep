@description('Location')
param location string

@description('SQL Server name')
param sqlServerName string

@description('Database name')
param sqlDbName string

@description('Subnet for private endpoint')
param subnetId string

@description('Private DNS zone for SQL')
param privateDnsZoneId string

@description('AAD admin group object ID')
param adminGroupObjectId string

@description('AAD admin group display name')
param adminGroupName string

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: adminGroupName
      sid: !empty(adminGroupObjectId) ? adminGroupObjectId : '00000000-0000-0000-0000-000000000000'
      tenantId: subscription().tenantId
      principalType: 'Group'
    }
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: 2147483648
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${sqlServerName}-pe'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${sqlServerName}-plsc'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
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
        name: 'sql-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output serverId string = sqlServer.id
