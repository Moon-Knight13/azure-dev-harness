@description('Location')
param location string

@description('App Service Plan name')
param appPlanName string

@description('App name')
param appName string

@description('Subnet for VNet integration (outbound)')
param subnetId string

@description('Subnet for private endpoint (inbound)')
param privateEndpointSubnetId string

@description('Private DNS zone for App Service')
param privateDnsZoneId string

@description('ACR login server')
param acrLoginServer string

@description('Key Vault URL')
param kvUrl string

@description('SQL Server FQDN')
param sqlServer string

@description('SQL Database name')
param sqlDatabase string

@description('Log Analytics workspace ID')
param logWorkspaceId string

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appPlanName
  location: location
  kind: 'linux'
  sku: { name: 'P1v3', tier: 'PremiumV3' }
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux,container'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    virtualNetworkSubnetId: subnetId
    vnetRouteAllEnabled: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/hello-world:latest'
      acrUseManagedIdentityCreds: true
      alwaysOn: true
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'AZURE_KEYVAULT_URL', value: kvUrl }
        { name: 'AZURE_SQL_SERVER', value: sqlServer }
        { name: 'AZURE_SQL_DATABASE', value: sqlDatabase }
        { name: 'WEBSITES_PORT', value: '8080' }
        { name: 'DOCKER_REGISTRY_SERVER_URL', value: 'https://${acrLoginServer}' }
      ]
    }
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: app
  name: 'app-diagnostics'
  properties: {
    workspaceId: logWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: '${appName}-pe'
  location: location
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: '${appName}-plsc'
        properties: {
          privateLinkServiceId: app.id
          groupIds: ['sites']
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
        name: 'app-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output appUrl string = 'https://${app.properties.defaultHostName}'
output principalId string = app.identity.principalId
