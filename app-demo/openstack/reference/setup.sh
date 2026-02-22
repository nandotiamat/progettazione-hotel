#!/bin/bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

openstack image create "ubuntu-22.04" \
  --file jammy-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform


# PER QUANDO RIAVVII LA VM

sudo ip link set br-ex up
sudo ip addr add 172.24.4.1/24 dev br-ex
echo "DevStack bridge br-ex is now UP with IP 172.24.4.1"
sudo iptables -t nat -A POSTROUTING -s 172.24.4.0/24 -o enp0s3 -j MASQUERADE
sudo mkdir -p /var/run/octavia
sudo chown -R stack:stack /var/run/octavia
sudo systemctl restart devstack@o-da.service
sudo systemctl daemon-reload


#!/bin/bash

echo "==================================================="
echo "🚀 DevStack Lab: Setup & Recovery Script 🚀"
echo "==================================================="

# =========================================================
# PARTE 1: SETUP INIZIALE (Tool e Immagini)
# =========================================================

echo -e "\n---> Controllo immagine Ubuntu in OpenStack Glance..."
# Controlla se l'immagine esiste già per evitare errori o duplicati
if ! openstack image show "ubuntu-22.04" > /dev/null 2>&1; then
    echo "Scaricamento immagine Ubuntu 22.04..."
    wget -nc https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
    
    echo "Caricamento immagine in corso..."
    openstack image create "ubuntu-22.04" \
      --file jammy-server-cloudimg-amd64.img \
      --disk-format qcow2 \
      --container-format bare \
      --public
    echo "✅ Immagine caricata con successo!"
else
    echo "✅ Immagine 'ubuntu-22.04' già presente in Glance."
fi

echo -e "\n---> Controllo installazione Terraform..."
if ! command -v terraform &> /dev/null; then
    echo "Installazione di Terraform in corso..."
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
    echo "✅ Terraform installato!"
else
    echo "✅ Terraform è già installato."
fi

# =========================================================
# PARTE 2: FIX POST-RIAVVIO (Rete e Octavia)
# =========================================================

echo -e "\n---> Configurazione Rete Esterna (br-ex)..."
sudo ip link set br-ex up

# Aggiunge l'IP solo se non è già assegnato all'interfaccia
if ! ip addr show br-ex | grep -q "172.24.4.1"; then
    sudo ip addr add 172.24.4.1/24 dev br-ex
    echo "✅ IP 172.24.4.1 assegnato a br-ex."
else
    echo "✅ L'interfaccia br-ex ha già l'IP configurato."
fi

# Applica il NAT solo se la regola non esiste già in iptables
if ! sudo iptables -t nat -C POSTROUTING -s 172.24.4.0/24 -o enp0s3 -j MASQUERADE 2>/dev/null; then
    sudo iptables -t nat -A POSTROUTING -s 172.24.4.0/24 -o enp0s3 -j MASQUERADE
    echo "✅ Regola NAT (Masquerade) applicata."
else
    echo "✅ Regola NAT già presente."
fi

echo -e "\n---> Risoluzione Bug Octavia (Provider OVN)..."
# Ricrea la cartella sparita dalla RAM e sistema i permessi
sudo mkdir -p /var/run/octavia
sudo chown -R stack:stack /var/run/octavia

# Aggiorna systemd e riavvia l'agente
sudo systemctl daemon-reload
sudo systemctl restart devstack@o-da.service
echo "✅ Agente Octavia sbloccato e riavviato."

echo -e "\n==================================================="
echo "🎉 Ambiente DevStack sbloccato e pronto all'uso! 🎉"
echo "==================================================="

# =========================================================
# PARTE 3: ALIAS TERRAFORM PERSONALIZZATI
# =========================================================

echo -e "\n---> Configurazione Alias Terraform in .bashrc..."

# Lista dei tuoi alias personalizzati
# Formato: "nome_alias=comando"
MY_ALIASES=(
    "ta=terraform apply -auto-approve"
    "td=terraform destroy -auto-approve"
    "ti=terraform init"
    "tv=terraform validate"
    "tp=terraform plan"
)

# Aggiunge il commento separatore se non esiste
if ! grep -q "# --- Terraform Aliases ---" ~/.bashrc; then
    echo -e "\n# --- Terraform Aliases ---" >> ~/.bashrc
fi

# Ciclo per aggiungere ogni alias solo se manca
for ALIAS_ENTRY in "${MY_ALIASES[@]}"; do
    ALIAS_NAME="${ALIAS_ENTRY%%=*}"
    ALIAS_CMD="${ALIAS_ENTRY#*=}"
    
    if ! grep -q "alias ${ALIAS_NAME}=" ~/.bashrc; then
        echo "alias ${ALIAS_NAME}='${ALIAS_CMD}'" >> ~/.bashrc
        echo "✅ Alias '${ALIAS_NAME}' aggiunto."
    else
        echo "✅ Alias '${ALIAS_NAME}' già presente."
    fi
done

echo "⚠️ Esegui 'source ~/.bashrc' per attivare gli alias immediatamente."

