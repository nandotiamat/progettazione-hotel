# Step 2: Provider & Skeleton (`main.tf`)

## Goal

Configurare il blocco `terraform` e il provider OpenStack per DevStack, sostituendo il provider AWS/LocalStack. La generazione del file dotenv è rimandata allo step finale quando tutti gli output saranno disponibili.

## Rationale

- Il provider `terraform-provider-openstack/openstack` versione `~> 3.0` è la versione stabile più recente compatibile con DevStack 2025.1.
- Tutte le credenziali sono parametrizzate tramite variabili (definite in `variables.tf`) anziché hardcoded, permettendo di cambiare ambiente senza modificare il file.
- Non è necessario un blocco `endpoints` come nel caso LocalStack: il provider OpenStack utilizza il catalogo servizi di Keystone per scoprire automaticamente gli endpoint di tutti i servizi (Nova, Neutron, Swift, Octavia, etc.).
- Il `required_version >= 1.5.0` garantisce compatibilità con le funzionalità Terraform moderne senza vincolare a una versione specifica.

## Alternatives

1. **Usare variabili d'ambiente OpenStack (`OS_AUTH_URL`, etc.) senza parametri nel provider block.** Scartato per coerenza con il progetto originale che esplicita tutto nel codice Terraform.

2. **Includere `clouds.yaml` come metodo di autenticazione.** Scartato perché aggiunge un file esterno e complessità non necessaria per un ambiente DevStack locale con credenziali fisse.

3. **Specificare `endpoint_overrides` nel provider.** Non necessario: DevStack registra correttamente tutti gli endpoint nel catalogo Keystone, a differenza di LocalStack che richiede endpoint manuali.
