variable "ssh_public_key" {
  type        = string
  description = "Chiave pubblica SSH (contenuto del file .pub) installata su azureuser in tutte le VM."
}

variable "admin_source_address_prefixes" {
  type        = list(string)
  description = "CIDR da cui il team amministra il lab: SSH, accesso diretto a Juice Shop (3000) e a Wazuh (443, 55000). Esempio: [\"203.0.113.10/32\"]."

  validation {
    condition     = length(var.admin_source_address_prefixes) > 0
    error_message = "Indicare almeno un CIDR di amministrazione (il proprio IP pubblico in formato x.x.x.x/32)."
  }
}
