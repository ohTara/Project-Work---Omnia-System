output "vm_public_ips" {
  description = "Indirizzi IP pubblici delle 3 VM"
  value = {
    for k, v in azurerm_public_ip.pip : k => v.ip_address
  }
}