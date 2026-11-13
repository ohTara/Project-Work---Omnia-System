# 🛡️ Omnia System — Laboratorio Cloud Security & DevSecOps

**Costruisci, Attacca e Difendi una Web App su Azure.** Project Work per AizoOn / ITS ICT Piemonte.

Deployment automatizzato con Terraform e Ansible, attacco a OWASP Juice Shop (Red Team), difesa e monitoraggio con WAF ModSecurity e SIEM Wazuh (Blue Team).

- 📐 [Architettura](docs/architettura.md)
- 📄 [Documentazione tecnica](docs/documentazione_tecnica_cloud_devsecops.md) (deploy, sicurezza, costi)
- 🔎 [Esito scansione Checkov](docs/results_cli.txt)

---

## 🏛️ Architettura

Un Resource Group in `westeurope`, una VNet `10.0.0.0/16` con una subnet `10.0.1.0/24`, un Network Security Group e 3 VM Ubuntu 22.04 (`Standard_B2s`), ognuna con IP pubblico.

| VM | IP privato | Ruolo | Software |
| :--- | :--- | :--- | :--- |
| **`vm-target`** | `10.0.1.10` | Web app vulnerabile | OWASP Juice Shop (Docker `bkimminich/juice-shop`, porta 3000) |
| **`vm-waf`** | `10.0.1.20` | Reverse proxy / protezione | Nginx + ModSecurity + OWASP CRS (`owasp/modsecurity-crs:nginx`, porta 80) |
| **`vm-siem`** | `10.0.1.30` | Log management e detection | Wazuh single-node (Manager, Indexer, Dashboard) |

**Chi può raggiungere cosa (NSG):**

| Porta | Destinazione | Origine |
| :--- | :--- | :--- |
| 22 (SSH) | tutte le VM | solo IP del team (`admin_source_address_prefixes`) |
| 80 (HTTP) | `vm-waf` | Internet: è la superficie che il Red Team attacca |
| 3000 | `vm-target` | solo IP del team (per il collaudo diretto) |
| 443, 55000 | `vm-siem` | solo IP del team |

---

## 🔄 Fasi del progetto

1. **Cloud & DevOps** — Terraform per rete e VM, Checkov per la scansione statica dell'IaC, Ansible per installare Docker, Juice Shop, ModSecurity e Wazuh.
2. **Offensive (Red Team)** — ricognizione degli endpoint di Juice Shop e SQL Injection sul form di login per ottenere l'accesso `admin`.
3. **Defense & Monitoring (Blue Team)** — il WAF blocca l'exploit; Wazuh raccoglie log e alert con regole di detection dedicate.

---

## 🚀 Come eseguire il progetto

### Prerequisiti

- Azure CLI autenticata (`az login`)
- Terraform ≥ 1.3, Ansible, Checkov
- Una coppia di chiavi SSH

### 1. Scansione di sicurezza dell'IaC

```bash
checkov -d terraform/
checkov -d ansible/
```

### 2. Provisioning (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # inserire chiave pubblica e proprio IP
terraform init
terraform plan
terraform apply
terraform output vm_public_ips
```

### 3. Configurazione (Ansible)

Inserire in `ansible/inventory.ini` gli IP pubblici ottenuti al passo precedente, poi:

```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini site.yml
```

### 4. Collaudo

```bash
TARGET_IP=<ip-target> WAF_IP=<ip-waf> SIEM_IP=<ip-siem> ./scripts/validate_network.sh
```

Lo script verifica raggiungibilità, Juice Shop (HTTP 200), proxy del WAF (HTTP 200) e blocco di una SQL Injection (HTTP 403).

### 5. Spegnere tutto

```bash
cd terraform && terraform destroy
```

---

## 🖥️ Accesso SSH alle VM

Utente `azureuser`, autenticazione con chiave privata.

```bash
ssh -i <chiave-privata> azureuser@<IP_PUBBLICO_VM>
az vm list-ip-addresses -d -o table      # per ricavare gli IP pubblici
chmod 600 <chiave-privata>               # SSH rifiuta chiavi con permessi troppo ampi
```

Le VM dell'ambiente di gruppo usano una chiave per macchina (`vmOffensive_key992.pem` per `vm-target`, `vmModSecurity_key903.pem` per `vm-waf`, `vm-Wazuh_key.pem` per `vm-siem`). Le chiavi vanno tenute nella cartella locale `chiavi/`, **esclusa da Git**: si distribuiscono tra i membri del team con un canale privato, mai nella repo.

Un deploy da zero con Terraform installa invece su tutte le VM la chiave indicata in `ssh_public_key`.

---

## ⚙️ Pipeline CI

`.github/workflows/devsecops.yml`, a ogni push e pull request su `main`: `terraform init -backend=false`, `terraform validate`, Checkov su `terraform/` e `ansible/` (in `--soft-fail`: segnala senza bloccare).

---

## 🚧 Limiti noti e lavoro da completare

- **Inoltro dei log a Wazuh**: i ruoli Ansible non installano ancora l'agente Wazuh su `vm-waf` e `vm-target`. Finché manca, il SIEM non riceve i log di ModSecurity e Juice Shop.
- **Regole custom**: `custom_rules.xml` viene copiato sulla VM ma non è ancora montato nel container del Wazuh Manager. La regola `100002` non ha una regola padre (`if_sid`) e va rivista.
- **Risorse del SIEM**: Wazuh single-node su `Standard_B2s` (4 GiB) è al limite; in caso di instabilità passare a una taglia con 8 GiB.
- **HTTPS**: il WAF espone solo la porta 80.
- **Stato Terraform**: locale, non condiviso tra i membri del team.

---

## 🛠️ Tecnologie

Microsoft Azure · Terraform · Checkov · Ansible · Docker · OWASP Juice Shop · ModSecurity + OWASP CRS · Wazuh · GitHub Actions
