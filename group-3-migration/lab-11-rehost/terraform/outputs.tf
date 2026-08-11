output "vm_web01_public_ip" {
  description = "IP publico da VM migrada"
  value       = azurerm_public_ip.web01.ip_address
}

output "vm_web01_private_ip" {
  description = "IP privado da VM migrada"
  value       = azurerm_network_interface.web01.private_ip_address
}

output "vm_web01_id" {
  description = "Resource ID da VM migrada"
  value       = azurerm_windows_virtual_machine.web01.id
}
