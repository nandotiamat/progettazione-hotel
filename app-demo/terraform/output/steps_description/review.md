# Review

## Step 1

Crea le directories `output`, `cloud-init` e crea i symlink per il contenuto di `seed_media`.

## Step 2

Crea le variabili in un file `variables.tf`. Nota che per l'autenticazione si prevede l'utilizzo di un file `clouds.yaml`, di fatto crea una varabile il cui contenuto indica il nome del campo da cui recuperare le informazioni di autenticazione dal file in questione. Viene respinto un approccio in cui si sceglie di localizzare le variabili nei singoli file di dominio interessati, piuttosto vengono centralizzate in un unico file (questa cosa non gliela dico nè nel prompt iniziale nè nel prompt con i requisiti, è una cosa che osserva e capisce guardando il codice terraform per AWS).

## Step 3

Inizia a creare il `main.tf` che conterrà i 4 provider in questione:

1. openstack (v3.4.0)
2. tls (per generazione di keypairs per SSH) (v4.2.1)
3. local (per generare file in locale) (v2.7.0)
4. random (per generare password) (v3.8.1)

## Step 4

Qui vengono creati i files cloud config che verranno usati durante il cloud init.

Create three cloud-init configuration files (`cloud-config` format) that will be injected as `user_data` into the Nova instances at boot time:
1. **`frontend-init-node.yaml`** — Installs Nginx and deploys a static HTML page identifying the node index.
2. **`backend-init-node.yaml`** — Installs Python3, creates a FastAPI application, and runs it with Uvicorn on port 80.
3. **`cloud-init-db.yaml`** — Installs PostgreSQL, creates the application user/database, configures remote access from the private subnet, and restarts the service.

TODO: verificare l'implementazione.

## Step 5

Viene creata una rete privata con un'unica subnetwork (10.0.1.0/24), un router connesso alla rete public creata da devstack e dei floating IP uno per il bastion host e l'altro per il load balancer.

Riconosce che non c'è bisogno del Multi A-Z pattern per DevStack
Riconosce di **DOVER ABILITARE IL DHCP nel caso in cui si sceglie di non assegnare manualmente gli IP, magari con la funzione `cidrhost`)

## Step 6

Security groups & rules!
Ha seguito in modo ferreo quanto specificato nei requisiti.

## Step 7

Crea una resource che permette di aggiungere l'immagine Ubuntu specificata a Glance (usando il field `image_source_url`).
Usa una regex per recuperare l'immagine `cirros` più recente presente nell'ambiente DevStack.
Crea anche il flavor `hotel_flavor`.
Crea anche la coppia di chiavi SSH, specificando che non c'è bisogno di gestirle manualmente ma che va a salvare quella privata da se in ~/.ssh (come richiesto da specifiche)
Qui probabilmente si rende conto che è cambiata l'interfaccia per l'assegnazione del floating IP al load balancer, sembra che lo abbia aggiustato.

## Step 8

Creazione del LOAD BALANCER!

Ha capito che bisogna usare TCP per tutto! Segue l'algoritmo `SOURCE_IP_PORT` come specificato da requisiti.
TODO: verificare l'implementazione

## Step 9

Swift e Keystone.
Crea il container con i media (con access control ACL based), due utenti Keystone (`media_reader` e `media_uploader`) con i ruoli custom.

Capisce che i secrets potrebbero essere salvati in Barbican, ma vede che siccome non c'è nell'ambiente target una soluzione con password generate e salvate in un dotenv è molto pragmatico per un ambiente di sviluppo locale.

## Step 10

Completamento `main.tf`.

Qui viene gestita la parte di creazione del dotenv, siccome adesso abbiamo tutte le risorse a disposizione.

## Step 11

Viene lanciato `terraform fmt` e `terraform validate` finali per verificare la correttezza dell'output.