param endpointName string
param hostname string
param origin string
param managedIdentityId string

param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

resource cdnProfile 'Microsoft.Cdn/profiles@2020-09-01' existing = {
  name: 'cdn-ms-${uniqueId}'
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = {
  parent: cdnProfile
  name: endpointName
  location: location
  properties: {
    originHostHeader: origin
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'UseQueryString'
    deliveryPolicy: {
      rules: [
        {
          name: 'httpsonly'
          order: 1
          conditions: [
            {
              name: 'RequestScheme'
              parameters: {
                operator: 'Equal'
                matchValues: [
                  'HTTP'
                ]
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleRequestSchemeConditionParameters'
              }
            }
          ]
          actions: [
            { 
              name: 'UrlRedirect'
              parameters: {
                redirectType: 'TemporaryRedirect'
                destinationProtocol: 'Https'
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleUrlRedirectActionParameters'
              }
            }
          ]
        }
        {
          name: 'onlyassets'
          order: 2
          conditions: [
            {
              name: 'UrlPath'
              parameters: {
                matchValues: [
                  '/assets/'
                ]
                operator: 'BeginsWith'
                negateCondition: true
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleUrlPathMatchConditionParameters'
              }
            }
          ]
          actions: [
            {
              name: 'CacheExpiration'
              parameters: {
                cacheBehavior: 'BypassCache'
                cacheType: 'All'
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleCacheExpirationActionParameters'
              }
            }
          ]
        }
      ]
    }
    origins: [
      {
        name: 'server'
        properties: {
          hostName: origin
        }
      }
    ]
  }
}

resource cdnCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = {
  parent: cdnEndpoint
  name: 'custom-domain-${uniqueId}'
  properties: {
    hostName: hostname
  }
}

// didn't find a way to enable custom https for cdn using arm resources, so a script will have to do
resource cdnEnableCustomHttps 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'cdn-https-${uniqueId}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    // forceUpdateTag: utcValue
    azPowerShellVersion: '6.4'
    scriptContent: loadTextContent('./scripts/enable-https.ps1')
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'ProfileName'
        value: cdnProfile.name
      }
      {
        name: 'EndpointName'
        value: cdnEndpoint.name
      }
      {
        name: 'CustomDomainName'
        value: cdnCustomDomain.name
      }
    ]
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT1H'
  }
}
