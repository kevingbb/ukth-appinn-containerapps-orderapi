
// Params 
param location string = resourceGroup().location
param apiManagementName string 
param containerAppsEnvName string 
param storageAccountName string 
@secure()
param selfHostedGatewayToken string


// variables
var apiGatewayContainerAppName = 'apim'
var selfHostedGatewayName = 'gw-01'
var gatewayTokenSecretName = 'gateway-token'


// ContainerAppsEnvironment
resource containerAppsEnv 'Microsoft.App/managedEnvironments@2022-03-01' existing = { 
  name: containerAppsEnvName
}

// Api Management
resource apim 'Microsoft.ApiManagement/service@2021-08-01' existing =  { 
  name: apiManagementName
}

// StorageAccount
resource stg 'Microsoft.Storage/storageAccounts@2021-01-01' existing =  { 
  name: storageAccountName
}

// APIM Self hosted gateway (SHGW) 
resource apiGatewayContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: apiGatewayContainerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnv.id
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
        minReplicas: 1
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


// Internal httpapi  
resource httpapi 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'httpapi2'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: false
        targetPort: 80
        allowInsecure: true
      }
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${stg.name};AccountKey=${listKeys(stg.id, '2018-07-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
    }
    template: {
      revisionSuffix: 'red'
      containers: [
        {
          image: 'kevingbb/httpapiapp:v2'
          name: 'httpapi2'
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



// Api in APIM 
resource apimApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  name: '${apiManagementName}/httpapi2'
  properties: {
    path: '/api'
    apiType: 'http'
    displayName: 'httpapi2'
    subscriptionRequired: true
    serviceUrl: 'http://${httpapi.properties.configuration.ingress.fqdn}'
    subscriptionKeyParameterNames: {
      header: 'X-API-Key'
      query: 'apiKey'
    }
    protocols: [
      'http'
      'https'
    ]
  }
  dependsOn:[
    httpapi
  ]
}

// Operation for API in APIM
resource apiOperation 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  name: 'AddItems'
  parent: apimApi
  properties: {
    displayName: 'AddItems'
    method: 'POST'
    urlTemplate: '/data'
    description: 'POST items to queue'
    request:{
      queryParameters: [
        {
          type: 'string'
          name: 'message'
        }
      ]
    }    
  }

}

// Expose API in SHGW
resource exposeApiOnGateway 'Microsoft.ApiManagement/service/gateways/apis@2021-08-01' = {
  name: '${apiManagementName}/${selfHostedGatewayName}/httpapi2'
  properties: {}
  dependsOn: [
    apimApi
  ]
}



