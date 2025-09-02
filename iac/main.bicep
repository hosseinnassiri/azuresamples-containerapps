@description('Specifies the location.')
param location string = resourceGroup().location

param appName string = 'containerapp'

param environment string = 'dev'

// 'azuredocs/containerapps-helloworld:latest'
// 'nginxdemos/hello:0.4'
// 'library/hello-world:latest'
param containerImageName string = 'azuredocs/containerapps-helloworld:latest'

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

var containerAppsName = 'ca-${appName}-cace-${environment}-01'
resource containerApps 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: containerAppsName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          identity: uai.id
          server: acr.properties.loginServer
        }
      ]
    }
    template: {
      revisionSuffix: 'rev1'
      containers: [
        {
          name: 'azuredocs-helloworld'
          image: '${acr.properties.loginServer}/${containerImageName}'
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
        {
          name: 'docker-helloworld'
          image: '${acr.properties.loginServer}/library/hello-world:latest'
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
      ]
    }
  }
}

output containerAppFQDN string = containerApps.properties.configuration.ingress.fqdn
