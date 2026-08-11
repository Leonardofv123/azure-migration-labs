variable "subscription_id" {
  description = "ID da subscription Azure"
  type        = string
}

variable "vm_size" {
  description = "SKU da VM, definido pelo assessment do Lab 10 (Standard_A2_v2)"
  type        = string
  default     = "Standard_D2s_v7"
}

variable "admin_username" {
  description = "Usuario administrador da VM"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Senha do administrador, nunca versionada em texto puro"
  type        = string
  sensitive   = true
}
