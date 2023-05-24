// Java web app with staging (+ production) slot
param prefix string
param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

var originHostnames = [
  'api.malliina.com'
  'mvn.malliina.com'
]
param cdnHostname string = 'api-cdn.malliina.com'
param mvnCdnHostname string = 'mvn-cdn.malliina.com'

param vnetSubnetId string
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

resource site 'Microsoft.Web/sites@2021-03-01' = {
  name: 'api-win-${uniqueId}'
  location: location
  properties: {
    siteConfig: {
      healthCheckPath: '/health'
      javaContainer: 'JAVA'
      javaContainerVersion: 'SE'
      javaVersion: '17'
      alwaysOn: true
      webSocketsEnabled: true
    }
    httpsOnly: true
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: vnetSubnetId
  }
  identity: {
    type: 'SystemAssigned'
  }

  resource settings 'config' = {
    name: 'appsettings'
    properties: {
      WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
      APPLICATION_SECRET: appSecret
      DB_PASS: dbPass
      LOGSTREAMS_USER: 'api'
      LOGSTREAMS_PASS: logstreamsPass
      LOGSTREAMS_ENABLED: 'true'
      JAVA_OPTS: '-Xmx512m'
      ENV_NAME: 'prod'
    }
  }

  resource slotConfig 'config' = {
    name: 'slotConfigNames'
    properties: {
      appSettingNames: [
        'LOGSTREAMS_USER'
      ]
    }
  }

  // Crazy Azure nonsense: Add slots first, then storage mappings

  resource config 'config' = {
    name: 'azurestorageaccounts'
    properties: {
      files: {
        type: 'AzureFiles'
        shareName: fileShareName
        mountPath: '/files'
        accountName: storage.name      
        accessKey: storage.listKeys().keys[0].value
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
        javaVersion: '17'
        alwaysOn: true
        webSocketsEnabled: true
      }
      httpsOnly: true
      serverFarmId: appServicePlan.id
      virtualNetworkSubnetId: vnetSubnetId
    }

    resource settings 'config' = {
      name: 'appsettings'
      properties: {
        WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
        APPLICATION_SECRET: appSecret
        DB_PASS: dbPass
        LOGSTREAMS_USER: 'api-staging'
        LOGSTREAMS_PASS: logstreamsPass
        LOGSTREAMS_ENABLED: 'true'
        JAVA_OPTS: '-Xmx256m'
        ENV_NAME: 'staging'
      }
    }

    resource config 'config' = {
      name: 'azurestorageaccounts'
      properties: {
        files: {
          type: 'AzureFiles'
          shareName: fileShareName
          mountPath: '/files'
          accountName: storage.name      
          accessKey: storage.listKeys().keys[0].value
        }
      }
    }
  }
}

module apiDomain 'appdomain.bicep' = {
  name: '${prefix}-api-domain'
  params: {
    appServicePlanId: appServicePlan.id
    origin: originHostnames[0]
    sitename: site.name
    location: location
  }
}

module mvnDomain 'appdomain.bicep' = {
  name: '${prefix}-mvn-domain'
  dependsOn: [
    apiDomain
  ]
  params: {
    appServicePlanId: appServicePlan.id
    origin: originHostnames[1]
    sitename: site.name
    location: location
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
