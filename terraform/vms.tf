# Lista dei ruoli VM: target (Juice Shop), waf, siem (Wazuh)
locals {
  vms = {
    "vm-target" = "10.0.1.10"
    "vm-waf"    = "10.0.1.20"
    "vm-siem"   = "10.0.1.30"
  }
}

# Public IP per l'accesso remoto
resource "azurerm_public_ip" "pip" {
  for_each            = local.vms
  name                = "pip-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Network Interfaces (NIC)
resource "azurerm_network_interface" "nic" {
  for_each            = local.vms
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value
    public_ip_address_id          = azurerm_public_ip.pip[each.key].id
  }
}

# Associazione NSG alla NIC
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  for_each                  = local.vms
  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# VM Ubuntu 22.04 LTS
resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = local.vms
  name                = each.key
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s" # Adatto per testing
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id,
  ]

  admin_ssh_key {
    username = "azureuser"
    # PRIMA:
    # public_key = file("~/.ssh/id_rsa.pub")

    # DOPO:
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
variable "ssh_public_key" {
  type        = string
  description = "Chiave pubblica SSH per le VM"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC3... dummy_key_for_ci_cd"
}
