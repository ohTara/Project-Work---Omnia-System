# 🛡️ Omnia System — Cloud Security & DevSecOps Infrastructure

[![DevSecOps IaC & Security Pipeline](https://github.com/ohTara/Project-Work---Omnia-System/actions/workflows/devsecops.yml/badge.svg)](https://github.com/ohTara/Project-Work---Omnia-System/actions/workflows/devsecops.yml)

Infrastruttura Cloud automatizzata distribuita su Microsoft Azure per l'ambiente di laboratorio "Costruisci, Attacca e Difendi una Web App". Il progetto gestisce l'infrastruttura tramite **Terraform**, la configurazione software tramite **Ansible**, la verifica SAST tramite **Checkov** ed integra una pipeline **CI/CD con GitHub Actions**.

---

## 📐 Architettura di Rete

* **Subnet Unica Workload:** `10.0.1.0/24` (VNet `10.0.0.0/16`)
* **`vm-target` (`10.0.1.10`):** Target Web App — OWASP Juice Shop (`:3000`)
* **`vm-waf` (`10.0.1.20`):** Reverse Proxy & Protection — Nginx + ModSecurity CRS (`:80`)
* **`vm-siem` (`10.0.1.30`):** Centralized SIEM — Wazuh Stack Single-Node (`:55000` / Dashboard `:443`)

---

## 🚀 Guida al Deployment

### 1. Prerequisiti
* Azure CLI autenticato (`az login`)
* Terraform (>= 1.3)
* Ansible & Checkov installati nel nodo di gestione
* Chiave SSH pubblica in `~/.ssh/id_rsa.pub`

### 2. Provisioning Infrastruttura (Terraform)
```bash
cd terraform
terraform init
terraform apply -auto-approve
