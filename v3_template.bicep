param Location string
param StorageAccount_prefix string
param LogAnalytics_Workspace_Name string
param AppInsights_Name string
param ContainerApps_Environment_Name string
param ContainerApps_HttpApi_CurrentRevisionName string
param ContainerApps_HttpApi_NewRevisionName string

var StorageAccount_ApiVersion = '2018-07-01'
var StorageAccount_Queue_Name = 'demoqueue'
var Workspace_Resource_Id = LogAnalytics_Workspace_Name_resource.id

resource StorageAccount_Name_resource 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  //name: StorageAccount_Name
  name: '${StorageAccount_prefix}${uniqueString(resourceGroup().id)}'
  location: Location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource StorageAccount_Name_default_StorageAccount_Queue_Name 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-01-01' = {
  name: '${StorageAccount_Name_resource.name}/default/${StorageAccount_Queue_Name}'
  properties: {
    metadata: {}
  }
  dependsOn: [
  ]
}

resource LogAnalytics_Workspace_Name_resource 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: LogAnalytics_Workspace_Name
  location: Location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource AppInsights_Name_resource 'Microsoft.Insights/components@2020-02-02' = {
  name: AppInsights_Name
  location: Location
  properties: {
    ApplicationId: AppInsights_Name
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'CustomDeployment'
  }
}

resource ContainerApps_Environment_Name_resource 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: ContainerApps_Environment_Name
  location: Location
  tags: {}
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: LogAnalytics_Workspace_Name_resource.properties.customerId
        sharedKey: listKeys(Workspace_Resource_Id, '2015-03-20').primarySharedKey
      }
    }
   
    daprAIInstrumentationKey: AppInsights_Name_resource.properties.InstrumentationKey
    daprAIConnectionString: AppInsights_Name_resource.properties.ConnectionString
    
  }
  dependsOn: [
    StorageAccount_Name_resource
  ]
}

resource queuereader 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'queuereader'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Name_resource.id
    configuration: {
      activeRevisionsMode: 'single'
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name_resource.name};AccountKey=${listKeys(StorageAccount_Name_resource.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: true
        appId: 'queuereader'
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/queuereader:v2'
          name: 'queuereader'
          env: [
            {
              name: 'QueueName'
              value: 'demoqueue'
            }
            {
              name: 'QueueConnectionString'
              secretRef: 'queueconnection'
            }
            {
              name: 'TargetApp'
              value: 'storeapp'
            } 
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
        rules: [
          {
            name: 'myqueuerule'
            azureQueue: {
              queueName: 'demoqueue'
              queueLength: 10
              auth: [
                {
                  secretRef: 'queueconnection'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource storeapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'storeapp'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Name_resource.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
      }
      dapr: {
        enabled: true
        appId: 'storeapp'
        appProtocol: 'http'
        appPort: 3000
      }
    }
    template: {
      containers: [
        {
          image: 'kevingbb/storeapp:v1'
          name: 'storeapp'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: []
      }
    }
  }
  dependsOn: [
  ]
}

resource httpapi 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'httpapi'
  location: Location
  properties: {
    managedEnvironmentId: ContainerApps_Environment_Name_resource.id
    configuration: {
      activeRevisionsMode: 'multiple'
      ingress: {
        external: true
        targetPort: 80
        traffic: [
          {
            revisionName: 'httpapi--${ContainerApps_HttpApi_CurrentRevisionName}'
            weight: 80
          }
          {
            latestRevision: true
            weight: 20
          }
        ]
      }
      secrets: [
        {
          name: 'queueconnection'
          value: 'DefaultEndpointsProtocol=https;AccountName=${StorageAccount_Name_resource.name};AccountKey=${listKeys(StorageAccount_Name_resource.id, StorageAccount_ApiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
      dapr: {
        enabled: true        
        appProtocol: 'http' 
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
        maxReplicas: 2
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
