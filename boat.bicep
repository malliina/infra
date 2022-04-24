// Java web app with staging (+ production) slot

param prefix string
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
@secure()
param awsAccessKeyId string
@secure()
param awsSecretAccessKey string

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
  name: '${prefix}-win-${uniqueId}'
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
      'GOOGLE_WEB_CLIENT_SECRET': googleSecret
      'LOGSTREAMS_PASS': logstreamsPass
      'LOGSTREAMS_ENABLED': 'true'
      'MAPBOX_TOKEN': mapboxToken
      'MICROSOFT_WEB_CLIENT_SECRET': microsoftSecret
      'FCM_API_KEY': fcmApiKey
      'JAVA_OPTS': '-Xmx512m'
      'AWS_ACCESS_KEY_ID': awsAccessKeyId
      'AWS_SECRET_ACCESS_KEY': awsSecretAccessKey
    }
  }

  // Crazy Azure nonsense: Add slots first, then storage mappings

  resource config 'config' = {
    name: 'azurestorageaccounts'
    properties: {
      'files': {
        type: 'AzureFiles'
        shareName: fileShareName
        mountPath: '\\mounts\\files'
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
        'GOOGLE_WEB_CLIENT_SECRET': googleSecret
        'LOGSTREAMS_PASS': logstreamsPass
        'LOGSTREAMS_ENABLED': 'true'
        'MAPBOX_TOKEN': mapboxToken
        'MICROSOFT_WEB_CLIENT_SECRET': microsoftSecret
        'FCM_API_KEY': fcmApiKey
        'JAVA_OPTS': '-Xmx256m'
        'AWS_ACCESS_KEY_ID': awsAccessKeyId
        'AWS_SECRET_ACCESS_KEY': awsSecretAccessKey
      }
    }

    resource config 'config' = {
      name: 'azurestorageaccounts'
      properties: {
        'files': {
          type: 'AzureFiles'
          shareName: fileShareName
          mountPath: '\\mounts\\files'
          accountName: storage.name      
          accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
        }
      }
    }
  }
}

module wwwDomain 'appdomain.bicep' = {
  name: '${prefix}-www-domain'
  params: {
    appServicePlanId: appServicePlan.id
    origin: originHostname
    sitename: site.name
    location: location
  }
}

module apiDomain 'appdomain.bicep' = {
  name: '${prefix}-api-domain'
  dependsOn: [
    wwwDomain
  ]
  params: {
    appServicePlanId: appServicePlan.id
    origin: 'api.boat-tracker.com'
    sitename: site.name
    location: location
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: 'workspace-${uniqueId}'
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${prefix}-diagnostics-${uniqueId}'
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
