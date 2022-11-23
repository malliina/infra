param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

param adminLogin string
@secure()
param adminPassword string

resource database 'Microsoft.DBforMySQL/flexibleServers@2021-05-01' = {
  name: 'database-${uniqueId}'
  location: location
  sku: {
    name: 'Standard_B2s'
    tier: 'Burstable'
  }
  properties: {
    version: '5.7'
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
  }
}
