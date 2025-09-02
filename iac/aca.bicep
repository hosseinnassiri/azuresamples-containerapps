
@description('Specifies the location.')
param location string = resourceGroup().location

param containerAppsName string

param managedEnvironmentId string
param userAssignedIdentity string
param registryUrl string
param containerImageName string

resource containerApps 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: containerAppsName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
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
          identity: userAssignedIdentity
          server: registryUrl
        }
      ]
    }
    template: {
      revisionSuffix: 'rev1'
      containers: [
        {
          name: 'azuredocs-helloworld'
          image: '${registryUrl}/${containerImageName}'
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
