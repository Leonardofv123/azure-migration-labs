variable "subscription_id" {
  description = "ID da subscription Azure"
  type        = string
}

variable "app_service_sku" {
  description = "SKU do App Service Plan. B1 = Basic, ~USD 13/mes"
  type        = string
  default     = "F1"
}

variable "app_name" {
  description = "Nome do Web App. Precisa ser unico globalmente (vira parte da URL)"
  type        = string
  default     = "contoso-web01-refactor"
}
