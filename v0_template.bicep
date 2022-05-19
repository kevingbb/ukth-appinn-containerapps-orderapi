param containerRegistryName string = 'acrName'
param acrLocation string  = 'northeurope'


resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: containerRegistryName
  location:acrLocation 
  sku: {
    name:  'Standard'
  }
   properties: {
      adminUserEnabled: true
   }
}
