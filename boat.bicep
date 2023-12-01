// Java web app with staging (+ production) slot

param prefix string
param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

var originHostnames = [
  { short: 'www', domain: 'www.boat-tracker.com'}
  { short: 'api', domain: 'api.boat-tracker.com' }
  { short: 'car-www', domain: 'www.car-map.com' }
  { short: 'car-api', domain: 'api.car-map.com' }
]

param cdnHostname string = 'cdn.boat-tracker.com'

param vnetSubnetId string
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
param microsoftBoatSecret string
@secure()
param microsoftCarSecret string
@secure()
param fcmApiKey string
@secure()
param awsAccessKeyId string
@secure()
param awsSecretAccessKey string

param fileShareName string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: 'plan-win-${uniqueId}'
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: uniqueId
}

resource site 'Microsoft.Web/sites@2022-09-01' = {
  name: '${prefix}-win-${uniqueId}'
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
      GOOGLE_WEB_CLIENT_SECRET: googleSecret
      LOGSTREAMS_USER: 'boat'
      LOGSTREAMS_PASS: logstreamsPass
      LOGSTREAMS_ENABLED: 'true'
      MAPBOX_TOKEN: mapboxToken
      MICROSOFT_WEB_CLIENT_SECRET: microsoftBoatSecret
      MICROSOFT_CAR_WEB_CLIENT_SECRET: microsoftCarSecret
      FCM_API_KEY: fcmApiKey
      JAVA_OPTS: '-Xmx512m'
      AWS_ACCESS_KEY_ID: awsAccessKeyId
      AWS_SECRET_ACCESS_KEY: awsSecretAccessKey
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
        mountPath: '\\mounts\\files'
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
        GOOGLE_WEB_CLIENT_SECRET: googleSecret
        LOGSTREAMS_USER: 'boat-staging'
        LOGSTREAMS_PASS: logstreamsPass
        LOGSTREAMS_ENABLED: 'true'
        MAPBOX_TOKEN: mapboxToken
        MICROSOFT_WEB_CLIENT_SECRET: microsoftBoatSecret
        MICROSOFT_CAR_WEB_CLIENT_SECRET: microsoftCarSecret
        FCM_API_KEY: fcmApiKey
        JAVA_OPTS: '-Xmx256m'
        AWS_ACCESS_KEY_ID: awsAccessKeyId
        AWS_SECRET_ACCESS_KEY: awsSecretAccessKey
        ENV_NAME: 'staging'
      }
    }

    resource config 'config' = {
      name: 'azurestorageaccounts'
      properties: {
        files: {
          type: 'AzureFiles'
          shareName: fileShareName
          mountPath: '\\mounts\\files'
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
    endpointName: '${prefix}-endpoint-${uniqueId}'
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
