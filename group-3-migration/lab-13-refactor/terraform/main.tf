terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "refactor" {
  name     = "rg-refactor-prod-eus2"
  location = "brazilsouth"
}

# App Service Plan: define o hardware e o tier
# B1 = Basic, 1 core, 1.75 GB RAM
resource "azurerm_service_plan" "web01" {
  name                = "asp-web01-refactor-eus2"
  resource_group_name = azurerm_resource_group.refactor.name
  location            = azurerm_resource_group.refactor.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
}

# Web App: onde a aplicacao roda
resource "azurerm_linux_web_app" "web01" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.refactor.name
  location            = azurerm_service_plan.web01.location
  service_plan_id     = azurerm_service_plan.web01.id

  https_only = true

  site_config {

    application_stack {
      dotnet_version = "8.0"
    }
  }

  tags = {
    origem    = "contoso-web01"
    migracao  = "lab-13-refactor"
    estrategia = "refactor"
  }
}
