# 🌐 Documentazione Tecnica: Infrastruttura Cloud Security & DevSecOps

**Cliente Finale:** AizoOn / ITS Piemonte  
**Progetto:** Laboratorio Integrato — Costruisci, Attacca e Difendi una Web App su Azure  
**Gruppo di Lavoro:** Omnia System (Team Cloud & DevSecOps)  

---

## 1. Architettura di Rete e Risorse Azure

L'infrastruttura è interamente gestita tramite **Infrastructure as Code (IaC)** con Terraform ed è distribuita all'interno di un unico **Resource Group** su Microsoft Azure (`westeurope`).

### 📐 Schema logico dell'architettura

```text
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

---

## 2. Descrizione dei Componenti e Ruolo delle VM

| VM | Indirizzo IP Privato | Ruolo | Componenti Software Installate |
| :--- | :--- | :--- | :--- |
| **`vm-target`** | `10.0.1.10` | Web Application Target | Ubuntu 22.04 LTS, Docker Engine, OWASP Juice Shop (`bkimminich/juice-shop`) ascolto su porta `3000`. |
| **`vm-waf`** | `10.0.1.20` | Reverse Proxy & Defense | Ubuntu 22.04 LTS, Docker Engine, Nginx + ModSecurity + OWASP Core Rule Set (CRS) su porta `80`/`443`. |
| **`vm-siem`** | `10.0.1.30` | Centralized Logging & SOC | Ubuntu 22.04 LTS, Docker Compose, Stack Wazuh Single-Node (Wazuh Manager, Indexer, Dashboard) su porta `55000`/`443`. |

---

## 3. Guida Passo-Passo al Deploy e alla Configurazione

### Prerequisiti

1. **Azure CLI** installato e autenticato con `az login`.
2. **Terraform** (v1.3+) installato.
3. **Ansible** e **Checkov** installati nell'ambiente di gestione.
4. Chiave SSH pubblica presente in `~/.ssh/id_rsa.pub`.

---

### Step 1: Analisi di Sicurezza Statica IaC (Checkov)

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

---

## 4. Analisi dei Costi e Manutenzione

### Stima Risorse Hardware & Costi Azure (Mensili)

| Risorsa Azure | Configurazione / Size | Qtà | Costo Unitario/Mese | Costo Totale/Mese |
| :--- | :--- | :---: | :---: | :---: |
| **VM Ubuntu (`Standard_B2s`)** | 2 vCPU, 4 GiB RAM | 3 | ~$30.66 | ~$91.98 |
| **Managed Disk (Standard SSD)** | 30 GB per VM | 3 | ~$2.40 | ~$7.20 |
| **Public IP (Dynamic)** | IP Pubblico Azure | 3 | ~$2.90 | ~$8.70 |
| **Network & Outbound Data** | VNet + Data Egress | 1 | ~$5.00 | ~$5.00 |
| **TOTALE MENSILE STIMATO** | | | | **~$112.88** |

### Stima Ore/Uomo e Manutenzione Annuale

| Voce di Costo | Descrizione | Quantità | Costo Orario / Anno | Totale |
| :--- | :--- | :---: | :---: | :---: |
| **Sviluppo IaC & Automation** | Scrittura Terraform, Ansible e scansioni Checkov | 35 ore | €35,00 / ora | € 1.225,00 |
| **Configurazione Security** | Tuning WAF (ModSecurity) e Dashboard SIEM (Wazuh) | 25 ore | €35,00 / ora | € 875,00 |
| **Manutenzione Annuale** | Patching OS, backup e gestione aggiornamenti WAF/SIEM | 12 mesi | €150,00 / mese | € 1.800,00 |

### Confronto Economico: Azure Cloud vs Sandbox On-Premise

| Indicatore | Cloud (Microsoft Azure) | Sandbox On-Premise (Proxmox/ESXi) |
| :--- | :--- | :--- |
| **Costo Iniziale (CAPEX)** | **€ 0,00** (Pay-as-you-go) | High (~€ 2.500 per hardware dedicato) |
| **Tempi di Deploy** | **< 10 minuti** via Terraform | Ore/Giorni (Setup hardware + Hypervisor) |
| **Flessibilità & Scalabilità** | Distruzione e ricreazione istantanea | Limitata alle risorse fisiche dell'host |
| **Consumo Energetico & Manutenzione** | Gestiti dal Cloud Provider | A carico del laboratorio locale |

---

## 5. Verifica e Collaudo dell'Infrastruttura

1. **Web App Target:** Verificare il raggiungimento diretto su `http://<IP-VM-TARGET>:3000`.
2. **Protezione WAF:** Verificare che il traffico passato da `http://<IP-VM-WAF>` venga inoltrato alla web app e che gli attacchi sul form di login restituiscano un errore `HTTP 403 Access Denied`.
3. **Dashboard SIEM:** Accedere alla dashboard Wazuh tramite `https://<IP-VM-SIEM>` ed accertarsi che i log del WAF e gli alert di ModSecurity siano visibili in tempo reale.
