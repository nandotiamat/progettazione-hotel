# Step 9: Dotenv File Generation (`main.tf`, aggiornamento finale)

## Goal

Aggiornare `main.tf` con la risorsa `local_file.dotenv` che genera un file di configurazione ambiente (`/config/openstack.env`) contenente tutti gli output dell'infrastruttura OpenStack, sostituendo il file `localstack.env` originale con valori e variabili adattati.

## Rationale

- **Stesso pattern `local_file`** dell'originale AWS per mantenere coerenza nella pipeline di configurazione. Il backend e il frontend leggono le variabili d'ambiente da questo file.
- **File rinominato** da `localstack.env` a `openstack.env` per riflettere l'ambiente target.
- **Variabili sostituite:**
  - `PUBLIC_COGNITO_*` → `OS_AUTH_URL`, `OS_PROJECT_ID`, `APP_CREDENTIAL_ID/SECRET` (Keystone)
  - `PUBLIC_API_GATEWAY_ENDPOINT` → `LB_FLOATING_IP` (accesso diretto, nessun API Gateway)
  - `ALB_DNS_NAME` → `LB_VIP_ADDRESS` + `LB_FLOATING_IP`
  - `S3_*` → `SWIFT_*` (container Swift)
  - `DB_ENDPOINT` (RDS) → `DB_HOST` (IP della VM PostgreSQL) + `DB_PORT` fisso a 5432
  - `CLOUDFRONT_*` → Rimossi (documentato come nota nel file)
- **Commenti esplicativi** nel file generato per documentare i servizi mancanti (CloudFront, API Gateway, Cognito completo) — utile per chi dovrà adattare il codice applicativo.
- **Application credential secret esposto** nel dotenv: necessario per l'autenticazione delle VM con Swift. In produzione si userebbe un vault (Barbican) o config drive cifrato.

## Alternatives

1. **Generare un file `clouds.yaml`** anziché un `.env`. Scartato perché il backend dell'applicazione è progettato per leggere variabili d'ambiente, non file di configurazione OpenStack nativi.

2. **Omettere i servizi mancanti** dal file. Scartato per mantenere visibilità sui gap — i commenti nel file aiutano gli sviluppatori a capire cosa deve cambiare nel codice applicativo.

3. **Usare `templatefile()` per generare il dotenv** da un template esterno. Scartato per semplicità e per mantenere il pattern heredoc dell'originale AWS. Con più variabili, un template separato sarebbe preferibile.

4. **Non esporre il credential secret nel dotenv** e usare un meccanismo più sicuro. Accettabile per DevStack locale; in produzione si userebbe Barbican o un inject via metadata service.
