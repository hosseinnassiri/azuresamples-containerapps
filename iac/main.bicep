@description('Specifies the location.')
param location string = resourceGroup().location

param appName string = 'containerapp'

param environment string = 'dev'

var coreResourceGroup = 'rg-core-cace-${environment}-01'

var logAnalyticsWorkspaceName = 'log-core-cace-${environment}-01'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(coreResourceGroup)
}

var userAssignedIdentityName = 'id-core-cace-${environment}-01'
resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup(coreResourceGroup)
}

var containerRegistryName = 'crcorecace${environment}01'
resource acr 'Microsoft.ContainerRegistry/registries@2025-05-01-preview' existing = {
  name: containerRegistryName
  scope: resourceGroup(coreResourceGroup)
}

var containerAppEnvironmentName string = 'cae-${appName}-cace-${environment}-01'
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: containerAppEnvironmentName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }
}

module mshelloworld './aca.bicep' = {
  name: 'ms-helloworld'
  params: {
    containerAppsName: 'ca-${appName}-cace-${environment}-01'
    managedEnvironmentId: containerAppEnvironment.id
    userAssignedIdentity: uai.id
    registryUrl: acr.properties.loginServer
    containerImageName: 'azuredocs/containerapps-helloworld:latest'
  }
}

module dockerhelloworld './aca.bicep' = {
  name: 'docker-helloworld'
  params: {
    containerAppsName: 'ca-${appName}-cace-${environment}-02'
    managedEnvironmentId: containerAppEnvironment.id
    userAssignedIdentity: uai.id
    registryUrl: acr.properties.loginServer
    containerImageName: 'nginxdemos/hello:0.4'
  }
}

// 'azuredocs/containerapps-helloworld:latest'
// 'nginxdemos/hello:0.4'
// 'library/hello-world:latest'
