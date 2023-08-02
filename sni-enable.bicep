param siteName string
param hostname string
param certificateThumbprint string

resource enableSni 'Microsoft.Web/sites/hostNameBindings@2022-09-01' = {
  name: '${siteName}/${hostname}'
  properties: {
    sslState: 'SniEnabled'
    thumbprint: certificateThumbprint
  }
}
