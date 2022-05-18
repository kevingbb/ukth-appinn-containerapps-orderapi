param Location string  = 'northeurope'

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: 'acr${uniqueString(resourceGroup().id)}'
  location:Location 
  sku: {
    name:  'Standard'
  }
   properties: {
      adminUserEnabled: true
   }
}
