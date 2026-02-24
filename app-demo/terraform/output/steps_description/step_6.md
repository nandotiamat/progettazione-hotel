# Step 6: Compute — Load Balancer (`compute.tf`, parte 1)

## Goal

Creare il Load Balancer Octavia con listener HTTP, pool di backend e health monitor, equivalente dell'ALB AWS con target group e health check.

## Rationale

- **Octavia con provider OVN** è l'unica opzione di load balancing disponibile nell'ambiente DevStack. Opera a livello L4 ma è sufficiente perché il design originale AWS non usa path-based routing — solo un listener HTTP porta 80 con azione forward-all.
- **`vip_subnet_id` sulla subnet pubblica**: il VIP del LB deve essere sulla subnet connessa al router per essere raggiungibile. A differenza di AWS dove l'ALB è direttamente pubblico, in OpenStack serve poi una Floating IP per esporre il VIP all'esterno.
- **`expected_codes = "200-499"`** nel health monitor replica il matcher rilassato dell'originale (`matcher = "200-499"`), necessario perché le istanze partono con un server HTTP minimale che potrebbe rispondere con codici non-200.
- **`security_group_ids` sul LB**: Octavia supporta l'assegnazione diretta di security groups al load balancer, equivalente del `security_groups` sull'ALB AWS.
- **Floating IP per il LB**: necessaria perché il VIP di Octavia è un IP interno alla subnet. Senza Floating IP, il LB sarebbe raggiungibile solo dalla rete interna OpenStack.

## Alternatives

1. **Usare un listener TCP anziché HTTP.** Scartato perché HTTP permette health check a livello applicativo (URL path, expected codes) che sono più informativi dei semplici check TCP.

2. **Creare il LB su entrambe le subnet pubbliche** per ridondanza. Non supportato da Octavia OVN (il VIP è su una singola subnet). La ridondanza del LB è gestita internamente da OVN a livello di rete.

3. **Usare HAProxy via VM** anziché Octavia. Scartato perché Octavia è il servizio nativo OpenStack per il load balancing e offre integrazione diretta con Neutron/Terraform.
