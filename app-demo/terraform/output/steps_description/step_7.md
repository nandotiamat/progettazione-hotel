# Step 7: Compute — Istanze + LB Members + Debug (`compute.tf`, parte 2)

## Goal

Creare le istanze Nova di backend (sostituzione dell'ASG), registrarle come membri del pool Octavia, e creare l'istanza di debug con Floating IP per accesso esterno diretto.

## Rationale

- **`count = var.instance_count`** anziché ASG: OpenStack non ha un equivalente nativo dell'Auto Scaling Group senza Heat/Ceilometer/Aodh. Il numero di istanze è fisso e controllato dalla variabile `instance_count` (default: 2, come il `desired_capacity` originale).
- **`openstack_lb_member_v2`** registra esplicitamente ogni istanza nel pool del LB, equivalente del collegamento automatico `target_group_arns` dell'ASG AWS. In AWS l'ASG gestisce automaticamente la registrazione/deregistrazione; qui è statica.
- **Floating IP per debug e LB**: in OpenStack i servizi interni non sono raggiungibili dall'esterno senza Floating IP. L'istanza di debug AWS era sul VPC default di LocalStack con port mapping automatico; in OpenStack usiamo una Floating IP dalla pool "public".
- **Floating IP associata al `vip_port_id` del LB**: questa è la tecnica standard OpenStack per esporre un load balancer Octavia all'esterno.
- **CloudWatch alarm e scaling policy omessi**: documentati come commento nel file. Senza Ceilometer e Aodh, non è possibile creare allarmi su metriche o policy di scaling automatico.

## Alternatives

1. **Usare `for_each` con una mappa** anziché `count`. Scartato per semplicità — `count` è più diretto per un semplice elenco numerato di istanze identiche, e il progetto originale AWS usava un ASG con un numero, non una mappa.

2. **Distribuire le istanze su subnet diverse** (round-robin tra `private_1` e `private_2` usando `count.index % 2`). Scartato per semplicità; tutte le subnet sono sulla stessa rete L2, quindi la distribuzione non offre reale ridondanza in un ambiente DevStack single-host.

3. **Non creare l'istanza di debug** poiché è specifica per LocalStack. Mantenuta per parità funzionale e perché è utile anche in DevStack per testare la connettività di rete dall'interno.

4. **Usare Heat `OS::Heat::AutoScalingGroup`** per replicare l'ASG. Scartato perché Heat non è abilitato nell'ambiente DevStack corrente (il PLAN.md base non lo include tra i servizi disponibili).
