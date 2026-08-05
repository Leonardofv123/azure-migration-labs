// Lab 05 - Mesma rede do Terraform, declarada em Bicep.
// Validado com "az bicep build", sem deployment, para comparar
// sintaxe sem duplicar recursos e custo.
//
// Atencao: Bicep usa ASPAS SIMPLES. Aspas duplas geram BCP103/BCP007.

param location string = 'eastus2'

param tags object = {
  Environment: 'Prod'
  Owner: 'Leo'
  Project: 'Migration'
  CostCenter: 'TI'
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-contoso-eus2-bicep'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: '10.10.1.0/24'
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.10.2.0/24'
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: '10.10.3.0/24'
        }
      }
    ]
  }
}

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-web'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Web'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output nsgId string = nsgWeb.id
