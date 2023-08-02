// Java web app with staging (+ production) slot
param prefix string
param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)
param originHostname string = 'logs.malliina.com'
param cdnHostname string = 'logs-cdn.malliina.com'

param vnetSubnetId string
@secure()
param appSecret string
@secure()
param dbPass string
@secure()
param googleSecret string
@secure()
param logstreamsPass string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: 'plan-win-${uniqueId}'
}

resource site 'Microsoft.Web/sites@2022-09-01' = {
  name: 'logs-win-${uniqueId}'
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
      GOOGLE_CLIENT_SECRET: googleSecret
      LOGSTREAMS_USER: 'logstreams'
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
        'LOGSTREAMS_PASS'
        'DB_USER'
        'DB_POOL_SIZE'
        'ENV_NAME'
        'JAVA_OPTS'
      ]
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
        DB_POOL_SIZE: '2'
        GOOGLE_CLIENT_SECRET: googleSecret
        LOGSTREAMS_USER: 'logstreams-staging'
        LOGSTREAMS_PASS: logstreamsPass
        LOGSTREAMS_ENABLED: 'true'
        JAVA_OPTS: '-Xmx256m'
        ENV_NAME: 'staging'
      }
    }

    resource logSettings 'config' = {
      name: 'logs'
      properties: {
         applicationLogs: {
            fileSystem: {
              level: 'Information'
            }
         }
         httpLogs: {
            fileSystem: {
               enabled: true
            }
         }
         detailedErrorMessages: {
            enabled: true
         }
      }
    }
  }
}

// Adapted from https://github.com/Azure/bicep/blob/main/docs/examples/301/function-app-with-custom-domain-managed-certificate/main.bicep
// Not used when CDN is used, since CDN manages certificates

module appDomain 'appdomain.bicep' = {
  name: '${prefix}-domain'
  params: {
    appServicePlanId: appServicePlan.id
    origin: originHostname
    sitename: site.name
    location: location
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: 'workspace-${uniqueId}'
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'logs-diagnostics-${uniqueId}'
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
  name: 'logs-cdn-${uniqueId}'
  params: {
    endpointName: 'logs-endpoint-${uniqueId}'
    hostnames: [
      cdnHostname
    ]
    origin: site.properties.defaultHostName
    location: location
    managedIdentityId: managedIdentityId
  }
}

output txtDomainVerification string = site.properties.customDomainVerificationId
output sitePrincipalId string = site.identity.principalId
