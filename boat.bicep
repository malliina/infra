// Java web app with staging (+ production) slot

param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)
param originHostname string = 'www.boat-tracker.com'
param cdnHostname string = 'cdn.boat-tracker.com'

@secure()
param appSecret string
@secure()
param dbPass string
@secure()
param googleSecret string
@secure()
param logstreamsPass string
@secure()
param mapboxToken string
@secure()
param microsoftSecret string
@secure()
param fcmApiKey string

param fileShareName string

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: 'plan-${uniqueId}'
}

resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' existing = {
  name: uniqueId
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: 'vault-${uniqueId}'
}

resource site 'Microsoft.Web/sites@2021-03-01' = {
  name: 'api-${uniqueId}'
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: 'JAVA|11-java11'
    }
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource settings 'config' = {
    name: 'appsettings'
    properties: {
      'WEBSITES_ENABLE_APP_SERVICE_STORAGE': 'false'
      'APPLICATION_SECRET': appSecret
      'DB_PASS': dbPass
      'GOOGLE_CLIENT_SECRET': googleSecret
      'LOGSTREAMS_PASS': logstreamsPass
      'MAPBOX_TOKEN': mapboxToken
      'MICROSOFT_WEB_CLIENT_SECRET': microsoftSecret
      'FCM_API_KEY': fcmApiKey
    }
  }

  // Crazy Azure nonsense: Add slots first, then storage mappings

  // resource config 'config' = {
  //   name: 'azurestorageaccounts'
  //   properties: {
  //     'files': {
  //       type: 'AzureFiles'
  //       shareName: fileShareName
  //       mountPath: '/files'
  //       accountName: storage.name      
  //       accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
  //     }
  //   }
  // }

  resource slots 'slots' = {
    name: 'staging'
    location: location
    properties: {
      serverFarmId: appServicePlan.id
    }

    resource settings 'config' = {
      name: 'appsettings'
      properties: {
        'WEBSITES_ENABLE_APP_SERVICE_STORAGE': 'false'
        'APPLICATION_SECRET': appSecret
        'DB_PASS': dbPass
        'GOOGLE_CLIENT_SECRET': googleSecret
        'LOGSTREAMS_PASS': logstreamsPass
        'MAPBOX_TOKEN': mapboxToken
        'MICROSOFT_WEB_CLIENT_SECRET': microsoftSecret
        'FCM_API_KEY': fcmApiKey
      }
    }

    // resource config 'config' = {
    //   name: 'azurestorageaccounts'
    //   properties: {
    //     'files': {
    //       type: 'AzureFiles'
    //       shareName: fileShareName
    //       mountPath: '/files'
    //       accountName: storage.name      
    //       accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
    //     }
    //   }
    // }
  }
}

// Adapted from https://github.com/Azure/bicep/blob/main/docs/examples/301/function-app-with-custom-domain-managed-certificate/main.bicep
// Not used when CDN is used, since CDN manages certificates

resource javaCustomDomain 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
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
    javaCustomDomain
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
  name: 'api-diagnostics-${uniqueId}'
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
  name: 'api-cdn-${uniqueId}'
  params: {
    endpointName: 'api-endpoint-${uniqueId}'
    hostname: cdnHostname
    origin: site.properties.defaultHostName
    location: location
    managedIdentityId: managedIdentityId
  }
}

output txtDomainVerification string = site.properties.customDomainVerificationId
output sitePrincipalId string = site.identity.principalId
