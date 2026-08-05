variable "location" {
  description = "Regiao do Azure onde os recursos serao criados"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Nome do Resource Group. Isolado do ambiente manual para evitar conflito."
  type        = string
  default     = "rg-network-prod-eus2-tf"
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Environment = "Prod"
    Owner       = "Leo"
    Project     = "Migration"
    CostCenter  = "TI"
  }
}
