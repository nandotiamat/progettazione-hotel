# Step 4: Security Groups (`security.tf`)

## Goal

Creare tre Security Groups OpenStack (Load Balancer, Compute, Database) che replicano la catena di fiducia dell'architettura AWS: il LB accetta traffico pubblico, le istanze compute accettano traffico solo dal LB, e il database accetta connessioni solo dalle istanze compute.

## Rationale

- **`delete_default_rules = true`** su tutti i gruppi per avere controllo esplicito. OpenStack crea regole di default (egress permissivo + traffico intra-gruppo) che renderebbero i gruppi meno restrittivi del previsto.
- **`remote_group_id`** anziché `remote_ip_prefix` per le regole inter-gruppo (LB→Compute, Compute→DB). Questo è l'equivalente diretto del parametro `security_groups` di AWS e mantiene le regole dinamiche (funzionano indipendentemente dagli IP delle istanze).
- **Porta 8000 aperta globalmente** nel compute_sg per debug, replicando il comportamento dell'originale AWS dove la porta 8000 era aperta su `0.0.0.0/0` per il mapping LocalStack.
- **Regole di debug sul default SG omesse**: in OpenStack non c'è un equivalente del "VPC default + default SG" di LocalStack. Le funzionalità di debug sono coperte dalle regole già presenti nel compute_sg.
- **Egress esplicito** su tutti i gruppi per chiarezza documentale, anche se OpenStack lo permetterebbe implicitamente.

## Alternatives

1. **Usare regole inline nel security group** (non supportato dal provider OpenStack Terraform — le regole devono essere risorse separate).

2. **Non impostare `delete_default_rules = true`** e lasciare le regole di default. Scartato perché le regole di default OpenStack (in particolare il traffico intra-gruppo) creerebbero percorsi di rete non previsti dal design originale.

3. **Restringere la porta 8000 al solo CIDR interno** (`10.0.0.0/16`). Scartato per mantenere parità con il design AWS dove era aperta globalmente per necessità di LocalStack. In produzione si restringerebbe al security group del LB.
