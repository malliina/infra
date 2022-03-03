// Adapted from https://github.com/Azure/bicep/blob/main/docs/examples/301/function-app-with-custom-domain-managed-certificate/main.bicep

param sitename string
param origin string
param appServicePlanId string

param location string = resourceGroup().location

resource javaCustomDomain 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  name: '${sitename}/${origin}'
  properties: {
    hostNameType: 'Verified'
    sslState: 'Disabled'
    customHostNameDnsRecordType: 'CName'
    siteName: sitename
  }
}

resource certificate 'Microsoft.Web/certificates@2021-02-01' = {
  name: origin
  location: location
  dependsOn: [
    javaCustomDomain
  ]
  properties: {
    canonicalName: origin
    serverFarmId: appServicePlanId
  }
}

module siteEnableSni 'sni-enable.bicep' = {
  name: '${deployment().name}-${origin}-sni-enable'
  params: {
    certificateThumbprint: certificate.properties.thumbprint
    hostname: origin
    siteName: sitename
  }
}
