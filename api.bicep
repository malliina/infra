// Java web app with staging (+ production) slot

param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

var originHostnames = [
  'api.malliina.com'
  'mvn.malliina.com'
]
param cdnHostname string = 'api-cdn.malliina.com'
param mvnCdnHostname string = 'mvn-cdn.malliina.com'

@secure()
param appSecret string
@secure()
param dbPass string
@secure()
param logstreamsPass string

param fileShareName string

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: 'plan-win-${uniqueId}'
}

resource storage 'Microsoft.Storage/storageAccounts@2021-02-01' existing = {
  name: uniqueId
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: 'vault-${uniqueId}'
}

resource site 'Microsoft.Web/sites@2021-03-01' = {
  name: 'api-win-${uniqueId}'
  location: location
  properties: {
    siteConfig: {
      healthCheckPath: '/health'
      javaContainer: 'JAVA'
      javaContainerVersion: 'SE'
      javaVersion: '11'
      alwaysOn: true
      webSocketsEnabled: true
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
      'LOGSTREAMS_PASS': logstreamsPass
      'LOGSTREAMS_ENABLED': 'true'
      'JAVA_OPTS': '-Xmx512m'
    }
  }

  // Crazy Azure nonsense: Add slots first, then storage mappings

  resource config 'config' = {
    name: 'azurestorageaccounts'
    properties: {
      'files': {
        type: 'AzureFiles'
        shareName: fileShareName
        mountPath: '/files'
        accountName: storage.name      
        accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
      }
    }
  }

  resource slots 'slots' = {
    name: 'staging'
    location: location
    properties: {
      siteConfig: {
        healthCheckPath: '/health'
        autoSwapSlotName: 'production'
        javaContainer: 'JAVA'
        javaContainerVersion: 'SE'
        javaVersion: '11'
        alwaysOn: true
        webSocketsEnabled: true
      }
      httpsOnly: true
      serverFarmId: appServicePlan.id
    }

    resource settings 'config' = {
      name: 'appsettings'
      properties: {
        'WEBSITES_ENABLE_APP_SERVICE_STORAGE': 'false'
        'APPLICATION_SECRET': appSecret
        'DB_PASS': dbPass
        'LOGSTREAMS_PASS': logstreamsPass
        'LOGSTREAMS_ENABLED': 'true'
        'JAVA_OPTS': '-Xmx256m'
      }
    }

    resource config 'config' = {
      name: 'azurestorageaccounts'
      properties: {
        'files': {
          type: 'AzureFiles'
          shareName: fileShareName
          mountPath: '/files'
          accountName: storage.name      
          accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
        }
      }
    }
  }
}

// Adapted from https://github.com/Azure/bicep/blob/main/docs/examples/301/function-app-with-custom-domain-managed-certificate/main.bicep
// Not used when CDN is used, since CDN manages certificates

@batchSize(1)
resource javaCustomDomains 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = [for hostname in originHostnames: {
  name: '${site.name}/${hostname}'
  properties: {
    hostNameType: 'Verified'
    sslState: 'Disabled'
    customHostNameDnsRecordType: 'CName'
    siteName: site.name
  }
}]

@batchSize(1)
resource certificates 'Microsoft.Web/certificates@2021-02-01' = [for i in range(0, length(originHostnames)): {
  name: originHostnames[i]
  location: location
  dependsOn: [
    javaCustomDomains[i]
  ]
  properties: {
    canonicalName: originHostnames[i]
    serverFarmId: appServicePlan.id
  }
}]

@batchSize(1)
module siteEnableSni 'sni-enable.bicep' = [for i in range(0 ,length(originHostnames)): {
  name: '${deployment().name}-${originHostnames[i]}-sni-enable'
  params: {
    certificateThumbprint: certificates[i].properties.thumbprint
    hostname: originHostnames[i]
    siteName: site.name
  }
}]

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
    hostnames: [
      cdnHostname
      mvnCdnHostname
    ]
    origin: site.properties.defaultHostName
    location: location
    managedIdentityId: managedIdentityId
  }
}

output txtDomainVerification string = site.properties.customDomainVerificationId
output sitePrincipalId string = site.identity.principalId
output siteOrigin string = site.properties.defaultHostName
