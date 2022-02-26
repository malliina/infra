param endpointName string
param hostName string

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
    originHostHeader: hostName
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
          hostName: hostName
        }
      }
    ]
  }
}
