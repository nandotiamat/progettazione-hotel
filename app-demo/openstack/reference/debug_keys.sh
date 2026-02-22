#!/bin/bash

KEY_FILE=$1
FRONTEND_IP=$2

if [ -z "$KEY_FILE" ] || [ -z "$FRONTEND_IP" ]; then
    echo "Uso: $0 <path_alla_tua_chiave.pem> <IP_PUBBLICO_FRONTEND>"
    echo "Esempio: $0 ~/.ssh/mykey.pem 172.24.4.15"
    exit 1
fi

echo "🚀 Configurazione del Frontend ($FRONTEND_IP) come Bastion Host..."

# 1. Assicura che la cartella .ssh esista sul frontend con i permessi giusti
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$FRONTEND_IP" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

# 2. Trasferisce la chiave privata rinominandola in id_rsa (il default cercato da ssh)
scp -i "$KEY_FILE" -o StrictHostKeyChecking=no "$KEY_FILE" ubuntu@"$FRONTEND_IP":~/.ssh/id_rsa

# 3. Blinda i permessi della chiave sul frontend
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@"$FRONTEND_IP" "chmod 400 ~/.ssh/id_rsa"

echo "✅ Fatto! Ora entra nel frontend con 'ssh -i $KEY_FILE ubuntu@$FRONTEND_IP'."
echo "Da lì potrai fare 'ssh ubuntu@<IP_BACKEND_O_DB>' senza password."
