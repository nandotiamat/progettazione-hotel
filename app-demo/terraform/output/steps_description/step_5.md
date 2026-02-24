# Step 5: Storage (`storage.tf`)

## Goal

Creare i container Swift (equivalenti dei bucket S3) per frontend e media, popolare i media con le immagini seed, e creare una VM Nova con PostgreSQL come sostituto del servizio RDS gestito.

## Rationale

- **Swift container con `metadata.Read = ".r:*,.rlistings"`** replica la bucket policy pubblica di S3. Questa è la sintassi ACL nativa di Swift per permettere lettura anonima.
- **Metadati `Web-Index` e `Web-Error`** abilitano il middleware staticweb di Swift, che fornisce la stessa funzionalità dell'S3 Website Configuration (serve `index.html` come documento predefinito e gestisce gli errori per SPA).
- **VM PostgreSQL via `user_data`** anziché un servizio gestito: senza Trove, l'unica opzione è self-managed PostgreSQL. Lo script cloud-init configura `listen_addresses = '*'` e aggiunge una regola `pg_hba.conf` per accettare connessioni dal CIDR della rete interna.
- **`sleep 30`** nel provisioner: la VM deve avviarsi, installare PostgreSQL via apt, e configurarlo prima che psql possa connettersi. È significativamente più lento del `sleep 5` usato con RDS LocalStack.
- **Stessa struttura `for_each`** per il seeding dei media, con la stessa logica di content_type detection.
- **Path `../terraform_content/`**: i file sorgente (schema.sql, seed_media/) sono nella directory sibling, come nel progetto originale.

## Alternatives

1. **Usare un container Docker PostgreSQL** invece di una VM Nova. Scartato perché il provisioner `local-exec` richiederebbe Docker installato sull'host DevStack e non replica l'architettura di rete (la VM è sulla subnet privata come era RDS).

2. **Usare Trove (DBaaS)** per un equivalente diretto di RDS. Scartato perché non è abilitato nell'ambiente DevStack corrente (da `local.conf`).

3. **Costruire l'URL Swift programmaticamente** dal catalogo Keystone invece di interpolarlo dalle variabili. Scartato per semplicità; in un ambiente DevStack l'URL del service è prevedibile. In produzione si userebbe un data source per recuperare l'endpoint dal catalogo.

4. **Usare `openstack_objectstorage_tempurl_key`** per accesso sicuro temporaneo al media container. Non implementato in questo step ma menzionato come miglioramento futuro per parità con i presigned URLs di S3.
