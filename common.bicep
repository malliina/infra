param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'plan-${uniqueId}'
  location: location
  kind: 'linux'
  sku: {
    name: 'P1V2'
    tier: 'PremiumV2'
  }
  properties: {
    reserved: true
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'workspace-${uniqueId}'
  location: location
}

module pics 'java.bicep' = {
  name: 'pics-${uniqueId}'
  params: {
    location: location
  }
}
