// Java web app with staging (+ production) slot
param prefix string
param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

var originHostnames = [
  { short: 'api', domain: 'api.malliina.com'}
  { short: 'mvn', domain: 'mvn.malliina.com' }
  { short: 'music', domain: 'api.musicpimp.org' }
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
@secure()
param discoGsToken string

param fileShareName string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: 'plan-win-${uniqueId}'
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: uniqueId
}

resource site 'Microsoft.Web/sites@2022-09-01' = {
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
      DISCOGS_TOKEN: discoGsToken
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
        DB_POOL_SIZE: '2'
        LOGSTREAMS_USER: 'api-staging'
        LOGSTREAMS_PASS: logstreamsPass
        LOGSTREAMS_ENABLED: 'true'
        DISCOGS_TOKEN: discoGsToken
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

@batchSize(1)
module domains 'appdomain.bicep' = [for conf in originHostnames: {
  name: '${prefix}-${conf.short}-domain'
  params: {
    appServicePlanId: appServicePlan.id
    origin: conf.domain
    sitename: site.name
    location: location
  }
}]

module diagnostics 'diagnostics.bicep' = {
  name: '${prefix}-diagnostics-${uniqueId}-module'
  params: {
    short: prefix
    siteName: site.name
  }
}

module cdn 'cdn.bicep' = {
  name: '${prefix}-cdn-${uniqueId}'
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
