param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

var fileShareName = 'fs-${uniqueId}'

resource appServicePlanWin 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-win-${uniqueId}'
  location: location
  kind: 'windows'
  sku: {
    name: 'P1V2'
    tier: 'PremiumV2'
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'workspace-${uniqueId}'
  location: location
}

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: uniqueId
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource fileServices 'fileServices' = {
    name: 'default'

    resource share 'shares' = {
      name: fileShareName
      properties: {
        shareQuota: 5
      }
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'vault-${uniqueId}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enabledForTemplateDeployment: true
    accessPolicies: [
      {
        objectId: '7e8068fc-2746-4bff-999c-6e2cee755050' // Me
        permissions: {
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
        }
        tenantId: tenant().tenantId
      }
    ]
  }
}

module networking 'networking.bicep' = {
  name: 'networking-${uniqueId}'
  params: {
    location: location
  }
}

module datalake8 'database-vnet.bicep' = {
  name: 'datalake8-${uniqueId}'
  params: {
    location: location
    adminLogin: 'malliina'
    adminPassword: keyVault.getSecret('ADMIN-DB-PASS')
    subnetId: networking.outputs.databaseSubnetId
  }
}

module vm 'vm.bicep' = {
  name: 'vm-${uniqueId}'
  params: {
    location: location
    adminPublicKey: keyVault.getSecret('SSH-PUBLIC-KEY')
    adminUsername: 'mle'
    subnetId: networking.outputs.vmSubnetId
  }
}


resource cdnProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: 'cdn-ms-${uniqueId}'
  location: location
  sku: {
    name: 'Standard_Microsoft'
  }
}

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

// resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
//   name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
// }

// https://github.com/Azure/azure-quickstart-templates/blob/e6e50ae57a2613858b37af1c3e95dfe93733bd4c/quickstarts/microsoft.storage/storage-static-website/main.bicep#L47
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'DeploymentScript'
  location: location
}

// https://github.com/Azure/azure-docs-bicep-samples/blob/main/samples/deployment-script/deploymentscript-keyvault-mi.bicep
resource managedIdentityRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, contributorRoleDefinition.id, uniqueId)
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: contributorRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

module pics 'pics.bicep' = {
  name: 'pics-${uniqueId}'
  params: {
    prefix: 'pics'
    location: location
    managedIdentityId: managedIdentity.id
    vnetSubnetId: networking.outputs.appSubnetId
    appSecret: keyVault.getSecret('PICS-APPLICATION-SECRET')
    dbPass: keyVault.getSecret('PICS-DB-PASS')
    twitterSecret: keyVault.getSecret('PICS-TWITTER-CLIENT-SECRET')
    microsoftSecret: keyVault.getSecret('PICS-MICROSOFT-CLIENT-SECRET')
    googleSecret: keyVault.getSecret('PICS-GOOGLE-CLIENT-SECRET')
    githubSecret: keyVault.getSecret('PICS-GITHUB-CLIENT-SECRET')
    facebookSecret: keyVault.getSecret('PICS-FACEBOOK-CLIENT-SECRET')
    awsAccessKeyId: keyVault.getSecret('AWS-ACCESS-KEY-ID')
    awsSecretAccessKey: keyVault.getSecret('AWS-SECRET-ACCESS-KEY')
    fileShareName: fileShareName
    logstreamsPass: keyVault.getSecret('PICS-LOGSTREAMS-PASS')
  }
}

module api 'api.bicep' = {
  name: 'api-win-${uniqueId}'
  params: {
    prefix: 'api'
    location: location
    managedIdentityId: managedIdentity.id
    vnetSubnetId: networking.outputs.appSubnetId
    appSecret: keyVault.getSecret('API-APPLICATION-SECRET')
    dbPass: keyVault.getSecret('API-DB-PASS')
    fileShareName: fileShareName
    logstreamsPass: keyVault.getSecret('API-LOGSTREAMS-PASS')
    discoGsToken: keyVault.getSecret('API-DISCOGS-TOKEN')
  }
}

module logs 'logs.bicep' = {
  name: 'logs-${uniqueId}'
  params: {
    prefix: 'logs'
    location: location
    managedIdentityId: managedIdentity.id
    vnetSubnetId: networking.outputs.appSubnetId
    appSecret: keyVault.getSecret('LOGS-APPLICATION-SECRET')
    dbPass: keyVault.getSecret('LOGS-DB-PASS')
    googleSecret: keyVault.getSecret('LOGS-GOOGLE-CLIENT-SECRET')
    logstreamsPass: keyVault.getSecret('LOGS-LOGSTREAMS-PASS')
  }
}

module boat 'boat.bicep' = {
  name: 'boat-${uniqueId}'
  params: {
    location: location
    prefix: 'boat'
    managedIdentityId: managedIdentity.id
    vnetSubnetId: networking.outputs.appSubnetId
    appSecret: keyVault.getSecret('BOAT-APPLICATION-SECRET')
    dbPass: keyVault.getSecret('BOAT-DB-PASS')
    googleSecret: keyVault.getSecret('BOAT-GOOGLE-CLIENT-SECRET')
    logstreamsPass: keyVault.getSecret('BOAT-LOGSTREAMS-PASS')
    mapboxToken: keyVault.getSecret('BOAT-MAPBOX-TOKEN', '187ed8174c9c4909a0b78e4c34d4c26c')
    microsoftBoatSecret: keyVault.getSecret('BOAT-MICROSOFT-CLIENT-SECRET', '51d82acf0632476d97052e96e0331906')
    microsoftCarSecret: keyVault.getSecret('BOAT-MICROSOFT-CAR-CLIENT-SECRET')
    fcmApiKey: keyVault.getSecret('BOAT-FCM-API-KEY')
    awsAccessKeyId: keyVault.getSecret('BOAT-AWS-ACCESS-KEY-ID', '0d8c632ec8ec41d5bb8fba6f5242c495')
    awsSecretAccessKey: keyVault.getSecret('BOAT-AWS-SECRET-ACCESS-KEY', 'bfe9cb1847d6472ebaf455d7d4ad5bf8')
    fileShareName: fileShareName
  }
}

resource keyVaultPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = {
  parent: keyVault
  name: 'add'
  properties: {
    accessPolicies: [
      {
        objectId: pics.outputs.sitePrincipalId
        permissions: {
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
        }
        tenantId: tenant().tenantId
      }
    ]
  }
}
