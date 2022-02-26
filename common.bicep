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


resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: uniqueId
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource cdnProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: 'cdn-ms-${uniqueId}'
  location: location
  sku: {
    name: 'Standard_Microsoft'
  }
}

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

// resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
// }

// https://github.com/Azure/azure-quickstart-templates/blob/e6e50ae57a2613858b37af1c3e95dfe93733bd4c/quickstarts/microsoft.storage/storage-static-website/main.bicep#L47
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'DeploymentScript'
  location: location
}

// https://github.com/Azure/azure-docs-bicep-samples/blob/main/samples/deployment-script/deploymentscript-keyvault-mi.bicep
resource managedIdentityRole 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(resourceGroup().id, managedIdentity.id, contributorRoleDefinition.id, uniqueId)
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: contributorRoleDefinition.id
    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}

module pics 'java.bicep' = {
  name: 'pics-${uniqueId}'
  params: {
    location: location
    managedIdentityId: managedIdentity.id
  }
}
