@description('Specifies the location.')
param location string = resourceGroup().location

param appName string = 'containerapp'

param environment string = 'dev'

var logAnalyticsWorkspaceName = 'log-${appName}-cace-${environment}-01'
var applicationInsightsName = 'appi-${appName}-cace-${environment}-01'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    DisableIpMasking: false
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output name string = applicationInsights.name

var userAssignedIdentityName = 'id-${appName}-cace-${environment}-01'
resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: userAssignedIdentityName
  location: location
}

var containerRegistryName = 'cr${appName}cace${environment}01'
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
  properties: {
    adminUserEnabled: true
    networkRuleBypassOptions: 'AzureServices'
  }
}

var environmentName = 'cae-${appName}-cace-${environment}-01'
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: environmentName
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
  }
}

var acrPullRole = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, uai.id, acrPullRole)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRole)
    principalId: uai.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// @description('Specifies the docker container image to deploy.')
// param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// var containerAppsName = 'ca-${appName}-cace-${environment}-01'
// resource containerApps 'Microsoft.App/containerApps@2025-02-02-preview' = {
//   name: containerAppsName
//   location: location
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${uai.id}': {}
//     }
//   }
//   properties: {
//     managedEnvironmentId: containerAppEnvironment.id
//     configuration: {
//       ingress: {
//         external: true
//         targetPort: 80
//         allowInsecure: false
//         traffic: [
//           {
//             latestRevision: true
//             weight: 100
//           }
//         ]
//       }
//       registries: [
//         {
//           identity: uai.id
//           server: containerRegistry.properties.loginServer
//         }
//       ]
//     }
//     template: {
//       revisionSuffix: 'firstrevision'
//       containers: [
//         {
//           name: containerAppsName
//           image: containerImage
//           resources: {
//             cpu: json('.25')
//             memory: '.5Gi'
//           }
//         }
//       ]
//     }
//   }
// }

// output containerAppFQDN string = containerApps.properties.configuration.ingress.fqdn
// output containerImage string = acrImportImage.outputs.importedImages[0].acrHostedImage
