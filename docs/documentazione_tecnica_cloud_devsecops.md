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
| **`vm-waf`** | `10.0.1.20` | Reverse Proxy & Defense | Ubuntu 22.04 LTS, Docker Engine, Nginx + ModSecurity + OWASP Core Rule Set (CRS) su porta `80`/`443`. | 
| **`vm-siem`** | `10.0.1.30` | Centralized Logging & SOC | Ubuntu 22.04 LTS, Docker Compose, Stack Wazuh Single-Node (Wazuh Manager, Indexer, Dashboard) su porta `55000`/`443`. | 

## 3. Guida Passo-Passo al Deploy e alla Configurazione

### Prerequisiti

1. **Azure CLI** installato e autenticato con `az login`.
2. **Terraform** (v1.3+) installato.
3. **Ansible** e **Checkov** installati nell'ambiente di gestione.
4. Chiave SSH pubblica presente in `~/.ssh/id_rsa.pub`.

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
   terraform apply -auto-approve
   ```
3. Prendere nota degli IP pubblici generati in output (`vm_public_ips`).

### Step 3: Configurazione ed Installazione Software (Ansible)

1. Aggiornare il file `ansible/inventory.ini` con gli IP pubblici ottenuti al punto precedente.
2. Eseguire i playbook per l'installazione automatizzata dei ruoli:
   ```bash
   cd ../ansible
   ansible-playbook -i inventory.ini site.yml
   ```

## 4. Report di Compliance SAST & Giustificazione Misconfigurazioni Checkov

L'analisi statica della sicurezza (SAST) effettuata con Checkov ha restituito la piena conformità per i playbook Ansible (**0 fallimenti su 4 controlli**) e l'esito **22 Passed / 9 Failed** sull'infrastruttura Terraform.

I **9 controlli non superati (Failed)** sono stati analizzati ed espressamente accettati in fase di design con le seguenti motivazioni tecniche legate alla natura del laboratorio:

* **`CKV_AZURE_10` / `CKV_AZURE_160` (Porte SSH 22 e HTTP 80 aperte a `0.0.0.0/0`):**
  * *Motivazione:* L'accesso da qualsiasi IP è una **scelta didattica intenzionale** per consentire l'esecuzione delle simulazioni d'attacco da parte del team Red Team/SOC da postazioni remote dislocate.
  * *Mitigazione Produttiva:* In un ambiente enterprise reale, l'accesso SSH verrebbe segregato tramite Azure Bastion/VPN aziendale e l'accesso web veicolato esclusivamente da Azure Application Gateway WAF.
* **`CKV_AZURE_119` (Assegnazione di IP Pubblici sulle NIC di tutte le VM):**
  * *Motivazione:* Requisito del laboratorio per garantire il raggiungimento diretto di ogni nodo durante le fasi di testing, configurazione Ansible ed estrazione log.
  * *Mitigazione Produttiva:* Le VM interne (Target e SIEM) opererebbero in subnet private senza IP pubblico nativo.
* **`CKV_AZURE_50` (Virtual Machine Extensions non utilizzate):**
  * *Motivazione:* È stato privilegiato un approccio **agentless nativo basato su Ansible**, eliminando l'overhead e i costi di gestione delle estensioni proprietarie Azure.
* **`CKV2_AZURE_31` (Mancata associazione diretta dell'NSG alla Subnet):**
  * *Motivazione:* L'Network Security Group (`nsg-lab-sec`) è stato volutamente legato alle **Interfacce di Rete (NIC)** delle singole VM per consentire un controllo granulare delle regole per ciascun ruolo (`target`, `waf`, `siem`) all'interno della stessa subnet.

## 5. Verifica e Collaudo dell'Infrastruttura (WBS 2.4)

È stato sviluppato uno script di collaudo automatizzato in Bash (`scripts/validate_network.sh`) per verificare l'infrastruttura:

1. **Reachability ICMP/SSH:** Verifica dello stato UP dei nodi.
2. **Web App Target:** Verificare il raggiungimento diretto su `http://<IP-VM-TARGET>:3000`.
3. **Protezione WAF:** Verificare che il traffico inviato a `http://<IP-VM-WAF>` venga proxato a Juice Shop e che le chiamate malevole (SQL Injection) restituiscano l'errore `HTTP 403 Access Denied`.
4. **Dashboard SIEM:** Verificare la raggiungibilità della Dashboard Wazuh su `https://<IP-VM-SIEM>`.

## 6. Analisi dei Costi (Azure & Manutenzione)

### Costi Infrastrutturali Azure (Stima Mensile)

| Risorsa Azure | Configurazione / Size | Qtà | Costo Totale/Mese | 
| ----- | ----- | ----- | ----- | 
| **VM Ubuntu (`Standard_B2s`)** | 2 vCPU, 4 GiB RAM | 3 | ~$91.98 | 
| **Managed Disk (Standard SSD)** | 30 GB per VM | 3 | ~$7.20 | 
| **Public IP (Dynamic)** | IP Pubblico Azure | 3 | ~$8.70 | 
| **Data Egress & Networking** | VNet + Data Transfer | 1 | ~$5.00 | 
| **TOTALE STIMATO** |  |  | **~$112.88** | 

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
