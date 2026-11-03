targetScope = 'resourceGroup'

@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
param environmentName string

@description('Unique suffix for globally-unique resource names')
param resourceToken string = uniqueString(resourceGroup().id)

@description('Azure SQL admin AAD group object ID')
param sqlAdminGroupObjectId string = ''

@description('Azure SQL admin AAD group name')
param sqlAdminGroupName string = 'dev-team-sql-admins'

// ─── Naming ──────────────────────────────────────────────────────────────────

var prefix = 'azdev'
var suffix = '${environmentName}-${resourceToken}'
var vnetName = '${prefix}-vnet-${suffix}'
var bastionName = '${prefix}-bastion-${suffix}'
var firewallName = '${prefix}-fw-${suffix}'
var acrName = replace('${prefix}acr${suffix}', '-', '')
var kvName = '${prefix}-kv-${suffix}'
var sqlServerName = '${prefix}-sql-${suffix}'
var sqlDbName = '${prefix}-db-${suffix}'
var appPlanName = '${prefix}-plan-${suffix}'
var appName = '${prefix}-app-${suffix}'
var logName = '${prefix}-log-${suffix}'

// ─── Log Analytics (required by App Service diagnostics) ─────────────────────

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ─── Networking (hub-spoke, single VNet for dev simplicity) ──────────────────

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: vnetName
    bastionName: bastionName
    firewallName: firewallName
  }
}

// ─── Azure Container Registry (private endpoint) ────────────────────────────

module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    location: location
    acrName: acrName
    subnetId: network.outputs.servicesSubnetId
    privateDnsZoneId: network.outputs.acrPrivateDnsZoneId
  }
}

// ─── Key Vault (private endpoint) ────────────────────────────────────────────

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    kvName: kvName
    subnetId: network.outputs.servicesSubnetId
    privateDnsZoneId: network.outputs.kvPrivateDnsZoneId
  }
}

// ─── Azure SQL (private endpoint) ────────────────────────────────────────────

module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlDbName: sqlDbName
    subnetId: network.outputs.servicesSubnetId
    privateDnsZoneId: network.outputs.sqlPrivateDnsZoneId
    adminGroupObjectId: sqlAdminGroupObjectId
    adminGroupName: sqlAdminGroupName
  }
}

// ─── App Service (VNet-integrated, private endpoint) ─────────────────────────

module appService 'modules/appservice.bicep' = {
  name: 'appservice'
  params: {
    location: location
    appPlanName: appPlanName
    appName: appName
    subnetId: network.outputs.appSubnetId
    privateEndpointSubnetId: network.outputs.servicesSubnetId
    privateDnsZoneId: network.outputs.appPrivateDnsZoneId
    acrLoginServer: acr.outputs.loginServer
    kvUrl: keyVault.outputs.vaultUri
    sqlServer: sql.outputs.serverFqdn
    sqlDatabase: sqlDbName
    logWorkspaceId: logWorkspace.id
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

output AZURE_ACR_NAME string = acr.outputs.acrName
output AZURE_ACR_LOGIN_SERVER string = acr.outputs.loginServer
output AZURE_KEYVAULT_NAME string = keyVault.outputs.kvName
output AZURE_KEYVAULT_URL string = keyVault.outputs.vaultUri
output AZURE_SQL_SERVER string = sql.outputs.serverFqdn
output AZURE_SQL_DATABASE string = sqlDbName
output APP_URL string = appService.outputs.appUrl
output VNET_NAME string = network.outputs.vnetName
