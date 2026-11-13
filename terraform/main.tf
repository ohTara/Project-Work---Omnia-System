terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-lab-cloudsec-devsecops"
  location = "westeurope"
}

# Virtual Network & Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-lab-sec"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group (NSG)
# - Amministrazione (SSH, Juice Shop diretto, Wazuh): solo dai CIDR del team.
# - HTTP verso il WAF: aperto a Internet, perché il WAF è la superficie
#   esposta che il Red Team deve poter attaccare (rischio accettato, vedi docs).
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-lab-sec"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.admin_source_address_prefixes
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP-WAF"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = local.vms["vm-waf"]
  }

  security_rule {
    name                       = "Allow-JuiceShop-Admin"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefixes    = var.admin_source_address_prefixes
    destination_address_prefix = local.vms["vm-target"]
  }

  security_rule {
    name                       = "Allow-Wazuh-Admin"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "55000"]
    source_address_prefixes    = var.admin_source_address_prefixes
    destination_address_prefix = local.vms["vm-siem"]
  }
}

# Associazione esplicita Subnet <-> NSG (CKV2_AZURE_31)
resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
