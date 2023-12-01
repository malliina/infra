// Java web app with staging (+ production) slot
param prefix string
param managedIdentityId string
param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)
param originHostname string = 'pics.malliina.com'
param cdnHostname string = 'pics-cdn.malliina.com'

param vnetSubnetId string
@secure()
param appSecret string
@secure()
param dbPass string
@secure()
param twitterSecret string
@secure()
param microsoftSecret string
@secure()
param googleSecret string
@secure()
param githubSecret string
@secure()
param facebookSecret string
@secure()
param awsAccessKeyId string
@secure()
param awsSecretAccessKey string
@secure()
param logstreamsPass string

param fileShareName string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' existing = {
  name: 'plan-win-${uniqueId}'
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: uniqueId
}

resource site 'Microsoft.Web/sites@2022-09-01' = {
  name: 'pics-win-${uniqueId}'
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
      MICROSOFT_CLIENT_SECRET: microsoftSecret
      GOOGLE_CLIENT_SECRET: googleSecret
      GITHUB_CLIENT_SECRET: githubSecret
      FACEBOOK_CLIENT_SECRET: facebookSecret
      TWITTER_CLIENT_SECRET: twitterSecret
      DB_PASS: dbPass
      AWS_ACCESS_KEY_ID: awsAccessKeyId
      AWS_SECRET_ACCESS_KEY: awsSecretAccessKey
      LOGSTREAMS_USER: 'pics'
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

  resource slots 'slots@2022-09-01' = {
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
        MICROSOFT_CLIENT_SECRET: microsoftSecret
        GOOGLE_CLIENT_SECRET: googleSecret
        GITHUB_CLIENT_SECRET: githubSecret
        FACEBOOK_CLIENT_SECRET: facebookSecret
        TWITTER_CLIENT_SECRET: twitterSecret
        DB_PASS: dbPass
        DB_POOL_SIZE: '2'
        AWS_ACCESS_KEY_ID: awsAccessKeyId
        AWS_SECRET_ACCESS_KEY: awsSecretAccessKey
        LOGSTREAMS_USER: 'pics-staging'
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
          mountPath: '\\mounts\\files'
          accountName: storage.name      
          accessKey: storage.listKeys().keys[0].value
        }
      }
    }
  }
}

module appDomain 'appdomain.bicep' = {
  name: '${prefix}-domain'
  params: {
    appServicePlanId: appServicePlan.id
    origin: originHostname
    sitename: site.name
    location: location
  }
}

module diagnostics 'diagnostics.bicep' = {
  name: '${prefix}-diagnostics-${uniqueId}-module'
  params: {
    short: prefix
    siteName: site.name
  }
}

module cdn 'cdn.bicep' = {
  name: 'pics-cdn-${uniqueId}'
  params: {
    endpointName: 'pics-endpoint-${uniqueId}'
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
