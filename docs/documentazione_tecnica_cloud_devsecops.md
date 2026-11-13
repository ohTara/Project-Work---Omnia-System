# 🌐 Documentazione Tecnica: Infrastruttura Cloud Security & DevSecOps

**Cliente Finale:** AizoOn / ITS Piemonte

**Progetto:** Laboratorio Integrato — Costruisci, Attacca e Difendi una Web App su Azure

**Gruppo di Lavoro:** Omnia System (Team Cloud & DevSecOps)

## 1. Architettura di Rete e Risorse Azure

L'infrastruttura è interamente gestita tramite **Infrastructure as Code (IaC)** con Terraform ed è distribuita all'interno di un unico **Resource Group** su Microsoft Azure (`westeurope`).

### 📐 Schema logico dell'architettura

```
                          [ INTERNET ]
                               │
                       ┌───────┴───────┐
                       │  Public IP    │
                       └───────┬───────┘
                               │
                   ┌───────────┴───────────┐
                   │  Virtual Network     │ 10.0.0.0/16
                   │  (snet-workload)     │ 10.0.1.0/24
                   └───────────┬───────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │ (10.0.1.20)         │ (10.0.1.10)         │ (10.0.1.30)
  ┌──────┴──────┐       ┌──────┴──────┐       ┌──────┴──────┐
  │   vm-waf    │ ────► │  vm-target  │ ────► │   vm-siem   │
  │ ModSecurity │       │ OWASP Juice │       │ Wazuh Stack │
  │   (Proxy)   │       │    Shop     │       │ (Logs/Alert)│
  └─────────────┘       └─────────────┘       └─────────────┘
```

## 2. Descrizione dei Componenti e Ruolo delle VM

| VM | Indirizzo IP Privato | Ruolo | Componenti Software Installate | 
| ----- | ----- | ----- | ----- | 
| **`vm-target`** | `10.0.1.10` | Web Application Target | Ubuntu 22.04 LTS, Docker Engine, OWASP Juice Shop (`bkimminich/juice-shop`) ascolto su porta `3000`. | 
| **`vm-waf`** | `10.0.1.20` | Reverse Proxy & Defense | Ubuntu 22.04 LTS, Docker Engine, Nginx + ModSecurity + OWASP Core Rule Set (CRS) su porta `80`. | 
| **`vm-siem`** | `10.0.1.30` | Centralized Logging & SOC | Ubuntu 22.04 LTS, Docker Compose, Stack Wazuh Single-Node (Wazuh Manager, Indexer, Dashboard) su porta `55000`/`443`. | 

## 3. Guida Passo-Passo al Deploy e alla Configurazione

### Prerequisiti

1. **Azure CLI** installato e autenticato con `az login`.
2. **Terraform** (v1.3+) installato.
3. **Ansible** e **Checkov** installati nell'ambiente di gestione.
4. Una chiave SSH pubblica, da indicare in `terraform/terraform.tfvars` insieme agli IP del team (modello: `terraform.tfvars.example`).

### Step 1: Analisi di Sicurezza Statico IaC (Checkov)

Prima del provisioning, eseguire la scansione del codice per individuare eventuali misconfigurazioni:

```bash
checkov -d terraform/
checkov -d ansible/
```

### Step 2: Provisioning dell'Infrastruttura (Terraform)

1. Spostarsi nella cartella `terraform`:
   ```bash
   cd terraform
   ```
2. Inizializzare i provider e applicare la configurazione:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
3. Prendere nota degli IP pubblici generati in output (`vm_public_ips`).

### Step 3: Configurazione ed Installazione Software (Ansible)

1. Aggiornare il file `ansible/inventory.ini` con gli IP pubblici ottenuti al punto precedente.
2. Eseguire i playbook per l'installazione automatizzata dei ruoli:
   ```bash
   cd ../ansible
   ansible-galaxy collection install -r requirements.yml
   ansible-playbook -i inventory.ini site.yml
   ```

## 4. Report di Compliance SAST & Giustificazione Misconfigurazioni Checkov

Ultima scansione: Checkov 3.4.5, 13/11/2026 (output completo in [`results_cli.txt`](results_cli.txt)).

| Ambito | Passed | Failed |
| ----- | ----- | ----- |
| Terraform | 24 | 7 |
| Ansible | 4 | 0 |

I **7 controlli non superati** riguardano 3 regole, analizzate e accettate in fase di design:

* **`CKV_AZURE_160` (HTTP 80 raggiungibile da Internet) — 1 risorsa:**
  * *Motivazione:* la porta 80 è aperta **solo verso `vm-waf`**. È la superficie che il Red Team deve poter attaccare da postazioni remote: il traffico passa comunque da ModSecurity prima di arrivare al target.
  * *Mitigazione produttiva:* accesso web veicolato da Azure Application Gateway WAF con HTTPS.
* **`CKV_AZURE_119` (IP pubblico sulle NIC) — 3 risorse:**
  * *Motivazione:* requisito del laboratorio per configurare ogni nodo con Ansible ed estrarre i log senza un bastion.
  * *Mitigazione produttiva:* VM interne (Target e SIEM) in subnet private senza IP pubblico, accesso tramite Azure Bastion o VPN.
* **`CKV_AZURE_50` (Virtual Machine Extensions) — 3 risorse:**
  * *Motivazione:* approccio agentless basato su Ansible, senza estensioni Azure da gestire.

**Controlli risolti rispetto alla prima versione:**

* `CKV_AZURE_10` (SSH aperto a `0.0.0.0/0`): la porta 22 è ora consentita solo dai CIDR in `admin_source_address_prefixes`. Lo stesso vale per la porta 3000 del target e per le porte 443 e 55000 del SIEM.
* `CKV2_AZURE_31` (NSG non associato alla subnet): aggiunta l'associazione esplicita subnet ↔ NSG, oltre a quella sulle NIC.

## 5. Verifica e Collaudo dell'Infrastruttura (WBS 2.4)

È stato sviluppato uno script di collaudo automatizzato in Bash (`scripts/validate_network.sh`) per verificare l'infrastruttura:

1. **Reachability ICMP:** Verifica dello stato UP dei nodi (da dentro la VNet: l'NSG non ammette ICMP dall'esterno).
2. **Web App Target:** Verificare il raggiungimento diretto su `http://<IP-VM-TARGET>:3000`.
3. **Protezione WAF:** Verificare che il traffico inviato a `http://<IP-VM-WAF>` venga proxato a Juice Shop e che le chiamate malevole (SQL Injection) restituiscano l'errore `HTTP 403 Access Denied`.
4. **Dashboard SIEM:** Verificare a mano la raggiungibilità della Dashboard Wazuh su `https://<IP-VM-SIEM>` (lo script non la controlla).

Esecuzione da una postazione del team: `TARGET_IP=<ip> WAF_IP=<ip> SIEM_IP=<ip> ./scripts/validate_network.sh`.

## 6. Analisi dei Costi (Azure & Manutenzione)

### Costi Infrastrutturali Azure (Stima Mensile)

| Risorsa Azure | Configurazione / Size | Qtà | Costo Totale/Mese | 
| ----- | ----- | ----- | ----- | 
| **VM Ubuntu (`Standard_B2s`)** | 2 vCPU, 4 GiB RAM | 3 | ~$91.98 | 
| **Managed Disk (Standard SSD)** | 30 GB per VM | 3 | ~$7.20 | 
| **Public IP (Standard, statico)** | IP Pubblico Azure | 3 | ~$8.70 | 
| **Data Egress & Networking** | VNet + Data Transfer | 1 | ~$5.00 | 
| **TOTALE STIMATO** |  |  | **~$112.88** | 

> Le cifre sono stime di progetto: gli IP pubblici sono passati allo SKU Standard (lo SKU Basic non è più creabile su Azure), quindi la voce relativa va ricontrollata con il [calcolatore prezzi Azure](https://azure.microsoft.com/pricing/calculator/).

### Stima Ore/Uomo e Manutenzione

* **Sviluppo IaC & DevOps:** 35 ore (€ 1.225,00 una tantum a € 35/h)
* **Tuning WAF & SIEM:** 25 ore (€ 875,00 una tantum a € 35/h)
* **Manutenzione Annuale:** € 1.800,00/anno (€ 150,00/mese per patch, backup e monitoraggio)

### Confronto Economico con Alternative

| Soluzione | Costo Setup (Una Tantum) | Costo Mensile / Gestione | Vantaggi | Svantaggi |
| :--- | :--- | :--- | :--- | :--- |
| **Azure Cloud (Attuale)** | € 2.100,00 | ~$112.88 / mese | Provisioning IaC nativo, scalabilità istantanea, zero gestione hardware. | Costi di traffico di rete e allocazione IP pubblici dinamici. |
| **Sandbox On-Premises (Proxmox/ESXi)** | € 2.100,00 + ~€ 1.500,00 (Server HW) | ~€ 25.00 / mese (Energia/UPS) | Controllo fisico completo, nessun costo cloud ricorrente su lunga durata. | Alto CAPEX iniziale, manutenzione hardware e continuità elettrica a carico dell'utente. |
| **Alternative Cloud (AWS / GCP)** | € 2.100,00 | ~$118.00 / mese | Piena compatibilità con tool Open Source (Docker, Ansible). | Riscrittura dei moduli HCL Terraform per adattamento al provider specifico. |
