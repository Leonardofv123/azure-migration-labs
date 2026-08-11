output "resource_group_name" {
  description = "Nome do Resource Group criado"
  value       = azurerm_resource_group.network.name
}

output "vnet_id" {
  description = "ID da VNet criada"
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "IDs das tres sub-redes"
  value = {
    web  = azurerm_subnet.web.id
    app  = azurerm_subnet.app.id
    data = azurerm_subnet.data.id
  }
}
