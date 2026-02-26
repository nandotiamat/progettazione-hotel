# Review

## Step 1

Viene creato `main.tf` e `variables.tf`. Viene scelta come versione di openstack > v3.0

Viene posto `insecure = true` (vengono ignorati eventuali errori di validazione del certificato SSL) siccome siamo in un ambiente di sviluppo locale.

Già nota che, in step futuri, dovrà ritoccare `variables.tf` con l'aggiunta di nuove variabili che verranno scoperte durante l'implementazione.

Nota che avrebbe potuto utilizzare un `clouds.yaml` per salvare le credenziali degli utenti. Ha scelto di non usarlo per semplicità.

## Step 2

L'obiettivo qui è quello di tradurre i componenti di networking di AWS in componenti Openstack. I componenti di AWS che menziona sono:

* VPC
* subnets
* internet gateway
* route tables

I componenti OpenStack che propone sono:

* una rete `openstack_networking_network_v2` (isolated L2 Network)
* 4 subnets attaccate a questa rete di cui 2 pubbliche e 2 private (cidr che vanno da 10.0.1.0/24 a 10.0.4.0/24)
* 1 router, che rimpiazza il bisogno di un internet gateway e della route table.
  * il router viene collegato alla rete `public` di devstack
  * crea una interfaccia per ogni subnet PUBBLICA

NON viene creata una interfaccia per le subnet private (in aws non avevano un nat gateway configurato), quindi dall'esterno non possiamo raggiungerle.


```text
availability_zone_hints - (Optional) An availability zone is used to make network resources highly available. Used for resources with high availability so that they are scheduled on different availability zones. Changing this creates a new network.
```

La scelta di creare 4 subnet di cui due pubbliche e due private ignora completamente il fatto che l'ambiente target è DevStack, che è singolo nodo e crea già una `public` e `private` network. Si potrebbe, quindi, creare una sola network con una sola subnet (privata), le quali saranno poi collegate da un router alla public network.

Chiaramente, qui si aprirebbe un discorso da fare in termini di come AWS gestisce le reti e di come lo fa Openstack (parlando anche di a che layer si fermano), parlando anche di High availability, availability zones, e di come questo in Devstack seppur testabile in parte, è comunque controverso per via della natura locale e singolo nodo dell'applicativo (possiamo testare se lo script di provisioning / deploy terraform e ansible funziona e crea le risorse).

Chiaramente si rende conto che per Route53 servirebbe `Designate`, e che NON è attivo nell'ambiente openstack target.

Sceglie di NON attaccare le subnet private al router perchè non veniva fatto nello script terraform per aws (no nat gateway).

## Step 3

Crea il `security.tf`.
Lo fa anche abbastanza bene, ma implicitamente non tiene conto del fatto che il load balancer (per via dei constraint sul `local.conf` e quindi sull'ambiente devstack) usa come provider OVN, che si ferma a layer 4. Probabilmente, sono da rivedere le regole ingress su porta 80 delle compute di frontend che hanno come remote_group_id quello del load balancer.

**TODO:** debuggare se il loadbalancer invia traffico alle compute.

Si accorge correttamente del fatto che OpenStack già crea le egress rule 0.0.0.0/0 su tutte le porte, perciò NON le crea.

Si rende conto che i SG non sono associati alla rete, bensì vengono creati a livello di progetto e possono essere applicate a porte / istanze.

## Step 4

Load balancer.

Qui iniziamo a vedere come opus non ha capito cosa volesse dire realmente avere a che fare con un provider OVN.

Crea un loadbalancer, un listener, una pool e un health monitor, il che va benissimo.

Si rende conto che con OVN provider Octavia opera a L4 (a differenza di AWS ALB che opera a L7 e quindi potrebbe leggere gli header HTTP), tuttavia siccome si nota che l'alb non ha alcuna logica particolare (inoltra i pacchetti e basta), Octavia con provider OVN (L4) va benissimo.

Qui però casca l'asino: crea i listener su protocollo HTTP anzichè TCP. Eppure, sapeva che Octavia con provider OVN opera fino a layer 4, lo dice stesso lui.

Inoltre, come algoritmo per fare il load balancing sceglie round robin, che però NON è supportato quando ovn è provider (SOURCE_IP_PORT va bene)

Chiaramente ciò si riflette anche nell'health monitor, che usa delle HTTP GET come mezzo per effettuare gli health check.

Propone di usare HAProxy / Nginx VM al posto di octavia (però comunque octavia quando non usa ovn come provider ma amphora le usa le haproxy..)

Si rende conto INFINIE che avrebbe potuto usare TCP invece di HTTP, ma dice che nonostante sia più semplice si priva della possibilità di fare HTTP-level health checks... eggià. È come se sapesse, ma non si rendesse conto di ciò. Sono abbastanza sicuro che basterebbe un prompt dove dici "ehi, ricordati che stai usando OVN come provider... non puoi fare ciò".

## Step 5

Si rende conto del fatto che, per implementare l'autoscaling pattern servirebbe Heat, Ceilometer, Aodh che NON sono abilitati in DevStack. La scelta di usare quei componenti per quel pattern è azzeccata. Quello che fa quindi è creare un certo numero di VM e le assegna alla pool a cui ha accesso il load balancer. I flavor e le immagini vengono ricavate usando la keyword data ( si suppone siano già presenti quindi in devstack prima di lanciare lo script terraform)

## Step 6

Swift, Object storage!

**TODO:** debuggare le acl usate per il container (field container_read).

Crea un container (s3 Bucket) e itera il contenuto di seed_media per popolare il container, creando gli object (s3 object)
Tecnicamente la policy scelta dovrebbe permettere la lettura pubblica da chiunque (non so se è quello che vorremmo, onestamente, ma magari è quello che ha fatto Paolo).

Si rende conto della possibilità di usare S3 per servire **staticamente** il sito statico, ma dice che swift non ha `native static website hosting in a basic devstack setup`.

https://docs.openstack.org/swift/latest/api/static-website.html

Io, credo che comunque sia possibile farlo con l'attuale configurazione, ma è da provare.

**TODO:** Verificare che sia possibile usare l'attuale configurazione di Swift per servire staticamente un sito web statico.

Usa come container_read la stessa che compare nella documentazione appena fornita, tuttavia non sarebbe ideale creare due container diversi, uno per il sito ed uno per le immagini?

## Step 7

Database! torniamo in `storage.tf`

Si rende conto che `Trove` NON è disponibile in DevStack, per cui sceglie di creare una VM con postgres.

Good practice: usa la funzione cidrhost per calcolare un indirizzo IP fixed da assegnare alla VM, dato il cidr della subnet di cui fa parte.

Viene configurata tramite il field `user_data` (in cui io caricavo il cloud-init.yaml)

Non ha fatto nulla per far partire le migrations definite in `schema.sql`, dice che sarebbe stato un passaggio separato di provisioning.

Notiamo qui che il volume è ephemeral (non viene creato un volume block storage con Cinder per conservare i dati del DB, per motivi di sviluppo dice che il disco ephemeral va benissimo).

## Step 8

Crea un progetto, un ruolo (OWNERS), un utente e assegna il ruolo all'utente. All'atto pratico, bisogna verificare bene cosa facciano le cose che sono definite qui.

**TODO:** fai un debug su horizon.

Si rende conto del fatto che Keystone non è un sostituto per AWS Cognito. Sta cercando di fare un mapping quanto più vicino possibile a quello che faceva lo script terraform per AWS in cognito, tuttavia potrebbe essere anche totalmente inutile.

Come alternativa ha proposto di usare Keystone in una VM come componente funzionalmente più vicino ad AWS Cognito, quindi ne è al corrente.

## Step 9

Non crea files terraform, descrive solamente l'assenza di un equivalente API Gateway.

Tutto ciò che avrebbe dovuto fare l'API Gateway (HTTP API CORS, JWT Auth, Routing...) andrebbe risolto a livello applicativo con soluzioni come con un reverse proxy Nginx (che quindi richiederebbe una VM dedicata, con costi quindi ulteriori in termini di risorse e di configurazione di nginx) o soluzioni ancora più complesse come l'utilizzo di Kong (api gateway usato in supabase).

## Step 10

Descrive l'assenza di un equivalente di cloudfront (CDN)

Ha perfettamente senso perchè openstack non fornisce un servizio equivalente a cloudfront. Inoltre, il motivo per cui originariamente cloudfront veniva usato è per servire un sito statico usando una S3 origin (quindi il l'html/css/js erano oggetti s3, ospitati in un rispettivo bucket). La strada che si poteva seguire era quella di sfruttare swift per ottenere un container che ospitava gli swift object del sito statico e configurare quindi swift per servire staticamente il sito (come nella documentazione precedentemente riportata). Tuttavia, il motivo principale per cui si usa cloudfront è per la distribuzione ed il caching a livello di distribuzione sui nodi EDGE!
**TODO:** verificare se openstack in qualche modo può fare ciò.

## Step 11

Banalmente crea un ruolo e lo assegna ad un utente già creato, utilizzato principalmente per dare privilegi di lettura swift (**TODO:** verifica)

Nomina Barbarican per la gestione dei secrets.

## Step 12

Genera automaticamente un file dotenv contenente variabili di ambiente contenente informazioni utili che avremmo potuto anche ricavare lanciando `terraform output`, così facendo magari non esplicitiamo direttamente i secrets.

## Step 13

Ritocco al `variables.tf`.

