# Project-Work---Omnia-System
🚀 Laboratorio integrato Cloud Security &amp; DevSecOps: deployment automatizzato con Terraform e Ansible su Azure, simulazione di attacco su OWASP Juice Shop (Red Team) e difesa/monitoraggio con WAF ModSecurity e SIEM Wazuh (Blue Team).
# 🛡️ Laboratorio Cloud Security & DevSecOps — Costruisci, Attacca e Difendi

> 📄 **Documentazione per il Cliente:** [Consulta lo schema e l'architettura di dettaglio](docs/architettura.md)

Progetto didattico per la realizzazione di un ambiente completo di **Cloud Security & DevSecOps** su Microsoft Azure. 

Il progetto copre l'intero ciclo operativo DevSecOps: dall'Infrastructure as Code (IaC) e la scansione di sicurezza prima del deploy, fino alle attività pratiche di **Red Team** (vulnerability assessment) e **Blue Team** (WAF + SIEM).

---

## 🏛️ Architettura dell'Infrastruttura

L'infrastruttura è distribuita su Microsoft Azure tramite **Terraform** ed è composta da una Virtual Network (VNet, Subnet, NAT Gateway, Internet Gateway) e 3 Macchine Virtuali Ubuntu:

| VM | Ruolo | Software & Componenti |
| :--- | :--- | :--- |
| **`vm-target`** | Web Application vulnerabile | OWASP Juice Shop (Docker `bkimminich/juice-shop`) |
| **`vm-waf`** | Reverse Proxy / Protezione | Nginx + ModSecurity + OWASP Core Rule Set (CRS) |
| **`vm-siem`** | Log Management & Detection | Wazuh Server & Dashboard |

---

## 🔄 Fasi del Progetto

### 1️⃣ Fase 1 — Cloud & DevOps (Infrastructure as Code)
- **Terraform:** Provisioning automatizzato e riproducibile delle risorse di rete e delle 3 VM su Azure.
- **Checkov:** Scansione statica di sicurezza (SAST) sui file Terraform e Ansible per identificare misconfigurazioni prima dell'apply.
- **Ansible:** Automazione della configurazione software e installazione di Docker, ModSecurity e Wazuh senza interventi manuali.

### 2️⃣ Fase 2 — Offensive (Red Team)
- **Vulnerability Assessment:** Ricognizione ed analisi degli endpoint di OWASP Juice Shop.
- **Exploit:** Attacco condotto sul form di autenticazione (SQL Injection) con l'obiettivo di effettuare il login con privilegi amministrativi (`admin`).

### 3️⃣ Fase 3 — Defense & Monitoring (Blue Team)
- **WAF (ModSecurity):** Configurazione del reverse proxy per intercettare il traffico e bloccare i tentativi di exploit sul login.
- **SIEM (Wazuh):** Inoltro centralizzato dei log di sistema, di Juice Shop e degli alert del WAF su Wazuh con creazione di regole di detection personalizzate e dashboard dedicate.

---

## 🛠️ Tecnologie Utilizzate

- **Cloud Provider:** Microsoft Azure
- **Infrastructure as Code:** Terraform
- **IaC Security Scanner:** Checkov
- **Configuration Management:** Ansible
- **Containerization:** Docker
- **Target Web App:** OWASP Juice Shop
- **Web Application Firewall:** ModSecurity + OWASP CRS
- **SIEM / SOC:** Wazuh

---

## 🚀 Come Eseguire il Progetto

### Prerequisiti
- Azure CLI configurato (`az login`)
- Terraform (v1.3+)
- Ansible
- Checkov

### Step 1: Scansione di Sicurezza IaC
```bash
checkov -d ./terraform