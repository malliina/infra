// Java web app with staging (+ production) slot

param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)
param originHostname string = 'pics-java.malliina.com'
param cdnHostname string = 'pics-java-cdn.malliina.com'

@secure()
param appSecret string

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: 'plan-${uniqueId}'
}

resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' existing = {
  name: uniqueId
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: 'vault-${uniqueId}'
}

resource site 'Microsoft.Web/sites@2020-06-01' = {
  name: 'pics-${uniqueId}'
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'APPLICATION_SECRET'
          value: appSecret
        }
      ]
      linuxFxVersion: 'JAVA|11-java11'
    }
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource slots 'slots@2021-03-01' = {
    name: 'staging'
    location: location
    properties: {
      serverFarmId: appServicePlan.id
    }
  }

  resource config 'config' = {
    name: 'azurestorageaccounts'
    properties: {
      'files': {
        type: 'AzureFiles'
        shareName: 'files'
        mountPath: '/files'
        accountName: storage.name      
        accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
      }
    }
  }
}

// Adapted from https://github.com/Azure/bicep/blob/main/docs/examples/301/function-app-with-custom-domain-managed-certificate/main.bicep
// Not used when CDN is used, since CDN manages certificates

resource siteCustomDomain 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  name: '${site.name}/${originHostname}'
  properties: {
    hostNameType: 'Verified'
    sslState: 'Disabled'
    customHostNameDnsRecordType: 'CName'
    siteName: site.name
  }
}

resource certificate 'Microsoft.Web/certificates@2021-02-01' = {
  name: originHostname
  location: location
  dependsOn: [
    siteCustomDomain
  ]
  properties: {
    canonicalName: originHostname
    serverFarmId: appServicePlan.id
  }
}

module siteEnableSni 'sni-enable.bicep' = {
  name: '${deployment().name}-${originHostname}-sni-enable'
  params: {
    certificateThumbprint: certificate.properties.thumbprint
    hostname: originHostname
    siteName: site.name
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: 'workspace-${uniqueId}'
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'pics-diagnostics-${uniqueId}'
  scope: site
  properties: {
    workspaceId: analyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
     
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

module cdn 'cdn.bicep' = {
  name: 'pics-cdn-${uniqueId}'
  params: {
    endpointName: 'pics-endpoint-${uniqueId}'
    hostname: cdnHostname
    origin: site.properties.defaultHostName
    location: location
    managedIdentityId: managedIdentityId
  }
}

output txtDomainVerification string = site.properties.customDomainVerificationId
output sitePrincipalId string = site.identity.principalId
