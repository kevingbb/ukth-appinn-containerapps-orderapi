
param apiManagementName string 
param location string = resourceGroup().location

var selfHostedGatewayName = 'gw-01'

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apiManagementName
  location: location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherName: 'Contoso'
    publisherEmail: 'john.doe@nomail.com'
  }
}

resource selfHostedGateway 'Microsoft.ApiManagement/service/gateways@2021-08-01' = {
  name: selfHostedGatewayName
  parent: apim
  properties:{
    description: 'Self-hosted API Gateway on Azure Container Apps'
    locationData: {
      name: 'Azure Container Apps'
      countryOrRegion: 'Cloud'
    }
  }
}

