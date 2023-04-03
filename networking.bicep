param location string = resourceGroup().location
param uniqueId string = uniqueString(resourceGroup().id)

var databaseSubnetName = 'database-subnet-${uniqueId}'
var vmSubnetName = 'vm-subnet-${uniqueId}'
var appSubnetName = 'app-subnet-${uniqueId}'

// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-virtual-networks
resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'demo-vnet-${uniqueId}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: databaseSubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
              name: 'delegation-mysql-${uniqueId}'
              properties: {
                serviceName: 'Microsoft.DBforMySQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: vmSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            {
              name: 'delegation-apps-${uniqueId}'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }

  resource databaseSubnet 'subnets' existing = {
    name: databaseSubnetName
  }

  resource vmSubnet 'subnets' existing = {
    name: vmSubnetName
  }

  resource appSubnet 'subnets' existing = {
    name: appSubnetName
  }
}

output databaseSubnetId string = vnet::databaseSubnet.id
output vmSubnetId string = vnet::vmSubnet.id
output appSubnetId string = vnet::appSubnet.id
output vnetName string = vnet.name
