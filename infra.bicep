targetScope = 'subscription'

param location string = 'northeurope'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'malliina'
  location: location
}
