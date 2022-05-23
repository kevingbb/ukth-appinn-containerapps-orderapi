var apiManagementName = ''
var managedEnvironmentName = ''
var apiGatewayContainerAppName = 'httpapi-apim'

@secure()
var selfHostedGatewayToken string
var gatewayTokenSecretName = 'gateway-token'


resource apim 'Mi'



resource apiGatewayContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: apiGatewayContainerAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: true
      }
      dapr: {
        enabled: false
      }
      secrets: [
        {
          name: gatewayTokenSecretName
          value: selfHostedGatewayToken
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azure-api-management/gateway:2.0.2'
          name: 'apim-gateway'
          resources: {
            cpu: '0.5'
            memory: '1.0Gi'
          }
          env: [
            { 
              name: 'config.service.endpoint'
              value: '${apiManagementName}.configuration.azure-api.net'
            }
            { 
              name: 'config.service.auth'
              secretRef: gatewayTokenSecretName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
        rules:[
          {
            name: 'http'
            http:{
              metadata:{
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}


resource httpapi 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'httpapi-internal'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Name_resource.id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: false
        targetPort: 80
       
      }
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name_resource.name};AccountKey=${listKeys(StorageAccount_Name_resource.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: true
        appId: 'httpapi'
        appProtocol: 'http'
        appPort: 80
      }
    }
    template: {
      revisionSuffix: ContainerApps_HttpApi_NewRevisionName
      containers: [
        {
          image: 'kevingbb/httpapiapp:v2'
          name: 'httpapi'
          env: [
            {
              name: 'QueueName'
              value: 'demoqueue'
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'httpscalingrule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}
