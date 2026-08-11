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

# Reaproveita o resource group de rede ja existente do Lab 05
data "azurerm_resource_group" "network" {
  name = "rg-network-prod-eus2"
}

# Reaproveita a VNet e a subnet ja existentes
data "azurerm_virtual_network" "contoso" {
  name                = "vnet-contoso-eus2"
  resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "web" {
  name                 = "subnet-web"
  virtual_network_name = data.azurerm_virtual_network.contoso.name
  resource_group_name  = data.azurerm_resource_group.network.name
}

# Resource group proprio para os recursos da VM migrada
resource "azurerm_resource_group" "migrated" {
  name     = "rg-migrated-prod-eus2"
  location = "eastus2"
}

resource "azurerm_public_ip" "web01" {
  name                = "pip-web01-migrated-eus2"
  resource_group_name = azurerm_resource_group.migrated.name
  location            = azurerm_resource_group.migrated.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "web01" {
  name                = "nsg-web01-migrated"
  resource_group_name = azurerm_resource_group.migrated.name
  location            = azurerm_resource_group.migrated.location

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "web01" {
  name                = "nic-web01-migrated-eus2"
  location            = azurerm_resource_group.migrated.location
  resource_group_name = azurerm_resource_group.migrated.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web01.id
  }
}

resource "azurerm_network_interface_security_group_association" "web01" {
  network_interface_id     = azurerm_network_interface.web01.id
  network_security_group_id = azurerm_network_security_group.web01.id
}

resource "azurerm_windows_virtual_machine" "web01" {
  name                = "vm-web01-migrated"
  computer_name       = "web01-mig"
  resource_group_name = azurerm_resource_group.migrated.name
  location            = azurerm_resource_group.migrated.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.web01.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  tags = {
    origem       = "contoso-web01"
    migracao     = "lab-11-rehost"
    ambiente     = "producao"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "web01" {
  virtual_machine_id = azurerm_windows_virtual_machine.web01.id
  location            = azurerm_resource_group.migrated.location
  enabled             = true

  daily_recurrence_time = "2200"
  timezone               = "E. South America Standard Time"

  notification_settings {
    enabled = false
  }
}
