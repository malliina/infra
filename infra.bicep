targetScope = 'subscription'

param location string = 'northeurope'
// https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-string#uniquestring
param uniqueId string = uniqueString(subscription().subscriptionId)

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${uniqueId}'
  location: location
}
