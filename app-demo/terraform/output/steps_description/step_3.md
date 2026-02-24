# Step 3: Networking (`network.tf`)

## Goal

Creare la topologia di rete OpenStack equivalente alla VPC AWS: una rete interna con 4 subnet (2 pubbliche, 2 private), un router connesso alla rete esterna DevStack per fornire accesso internet alle subnet pubbliche, e mantenere le subnet private isolate.

## Rationale

- **Una singola rete L2** (`openstack_networking_network_v2.main`) sostituisce la VPC AWS. In OpenStack non esiste un costrutto VPC; l'isolamento è dato dalla rete stessa.
- **Stessi blocchi CIDR** del progetto originale (`10.0.1.0/24` - `10.0.4.0/24`) per mantenere coerenza nella documentazione e nelle regole di sicurezza.
- **Il router Neutron** combina le funzioni di Internet Gateway e Route Table pubblica di AWS. Collegando solo le subnet pubbliche al router, le subnet private restano naturalmente isolate senza necessità di configurare route table separate.
- **DNS nameservers espliciti** (`8.8.8.8`, `8.8.4.4`) su ogni subnet perché OVN in DevStack potrebbe non fornire DNS via DHCP automaticamente.
- **Data source per la rete esterna**: usiamo `data.openstack_networking_network_v2.external` per riferirci alla rete `public` preesistente in DevStack, anziché crearla (è gestita da DevStack stesso).
- **Route53 omessa**: senza Designate, non possiamo creare zone DNS interne. Questo è accettabile in un ambiente di sviluppo locale.

## Alternatives

1. **Creare reti L2 separate per subnet pubbliche e private.** Scartato perché aggiunge complessità senza beneficio reale — in OpenStack l'isolamento è gestito dal router (o dall'assenza di interfacce router), non da reti separate.

2. **Collegare anche le subnet private al router** per dare accesso internet alle VM backend. Scartato per mantenere parità architetturale con il design AWS originale che non usa NAT Gateway. In produzione si aggiungerebbe un SNAT o un router separato.

3. **Usare `allocation_pools` per limitare il range di IP assegnabili.** Scartato per semplicità; il DHCP di Neutron gestisce l'intero CIDR, che è sufficiente per un ambiente DevStack con poche istanze.
