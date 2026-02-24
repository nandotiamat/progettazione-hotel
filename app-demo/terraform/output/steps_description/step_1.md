# Step 1: Variables (`variables.tf`)

## Goal

Definire tutte le variabili di input necessarie per l'infrastruttura OpenStack, sostituendo le variabili AWS-specifiche (`aws_region`) con equivalenti OpenStack e aggiungendo le nuove variabili richieste dal provider OpenStack (autenticazione Keystone, immagini Glance, flavor Nova, rete esterna).

## Rationale

Le variabili sono state centralizzate in un unico file seguendo la convenzione del progetto originale. Ogni variabile ha un valore di default compatibile con un ambiente DevStack `stable/2025.1`, così che `terraform apply` possa funzionare senza passare un file `.tfvars` (stessa logica usata con LocalStack).

Le variabili sono state organizzate per dominio (autenticazione, compute, database, rete, applicazione) per mantenere leggibilità. Sono state aggiunte variabili non presenti nell'originale AWS ma necessarie per OpenStack:
- `os_auth_url`, `os_user_name`, `os_password`, `os_tenant_name` — credenziali Keystone
- `image_name`, `flavor_name`, `db_flavor_name`, `debug_flavor_name` — risorse Glance/Nova
- `external_network_name` — riferimento alla rete esterna DevStack
- `dns_nameservers` — necessari esplicitamente nelle subnet OpenStack
- `instance_count` — sostituisce la `desired_capacity` dell'ASG (valore fisso, nessun autoscaling)
- `db_name`, `db_user` — estratti come variabili (nell'originale erano hardcoded nel provisioner)

## Alternatives

1. **Usare variabili di ambiente (`OS_AUTH_URL`, `OS_USERNAME`, etc.)** anziché variabili Terraform per l'autenticazione. Scartato perché la convenzione del progetto richiede che tutto sia esplicito e auto-contenuto nei file `.tf`, con default funzionanti.

2. **Usare `type = map` per raggruppare le credenziali** in un unico oggetto. Scartato per coerenza con il progetto originale che usa solo tipi `string` semplici.

3. **Omettere `dns_nameservers` e lasciare il default DHCP**. Scartato perché DevStack con OVN potrebbe non fornire DNS automaticamente alle subnet, causando problemi di risoluzione nelle VM.
