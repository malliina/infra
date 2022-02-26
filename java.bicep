// Java web app with staging (+ production) slot

param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

// param resourceGroup string = 'rg-fnxr3ec3ms6mu'
// param location string = 'northeurope'
// param resourceGroupName string = resourceGroup().name
// param hostname string = 'java.malliina.site'
// param uniqueId string = uniqueString(resourceGroup)

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: 'plan-${uniqueId}'
}

resource site 'Microsoft.Web/sites@2020-06-01' = {
  name: 'site-${uniqueId}'
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
      linuxFxVersion: 'JAVA|11-java11'
    }
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }

  resource slots 'slots@2021-03-01' = {
    name: 'staging'
    location: location
    properties: {
      serverFarmId: appServicePlan.id
    }
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: 'workspace-${uniqueId}'
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diagnostics-${uniqueId}'
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

output txtDomainVerification string = site.properties.customDomainVerificationId
