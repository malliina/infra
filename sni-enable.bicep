param siteName string
param hostname string
param certificateThumbprint string

resource enableSni 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
  name: '${siteName}/${hostname}'
  properties: {
    sslState: 'SniEnabled'
    thumbprint: certificateThumbprint
  }
}
