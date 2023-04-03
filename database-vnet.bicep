param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

param adminLogin string
@secure()
param adminPassword string
param subnetId string

resource server 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: 'database8-${uniqueId}'
  location: location
  sku: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  properties: {
    version: '8.0.21'
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    storage: {
      autoGrow: 'Enabled'
      storageSizeGB: 64
      iops: 720
    }
    backup: {
      geoRedundantBackup: 'Disabled'
      backupRetentionDays: 7
    }
    network: {
      delegatedSubnetResourceId: subnetId
    }
  }
}

output serverName string = server.name
