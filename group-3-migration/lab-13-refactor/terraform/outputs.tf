output "app_service_url" {
  description = "URL publica do Web App"
  value       = "https://${azurerm_linux_web_app.web01.default_hostname}"
}

output "app_service_name" {
  description = "Nome do Web App criado"
  value       = azurerm_linux_web_app.web01.name
}

output "app_service_plan_sku" {
  description = "SKU do plano, para comparacao de custo com o Lab 11"
  value       = azurerm_service_plan.web01.sku_name
}
