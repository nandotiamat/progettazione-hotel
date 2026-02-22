#!/bin/bash

KEY_NAME="hotel-key"
PROJECT_KEY_DIR="./keys"
SSH_DIR="$HOME/.ssh"

# 1. Controllo preventivo in ~/.ssh
if [ -f "$SSH_DIR/$KEY_NAME" ]; then
    echo "⚠️  Attenzione: Una chiave privata '$KEY_NAME' esiste già in $SSH_DIR."
    echo "Operazione annullata per evitare sovrascritture accidental."
    exit 0
fi

# 2. Crea cartella progetto se manca
mkdir -p "$PROJECT_KEY_DIR"

# 3. Generazione (solo se non c'è né la privata né la pubblica nel progetto)
if [ ! -f "$PROJECT_KEY_DIR/$KEY_NAME" ] && [ ! -f "$PROJECT_KEY_DIR/$KEY_NAME.pub" ]; then
    echo "Generazione nuove chiavi '$KEY_NAME'..."
    ssh-keygen -t ed25519 -f "$PROJECT_KEY_DIR/$KEY_NAME" -C "hotel-management-system" -N ""
else
    echo "Trovata chiave esistente nella cartella del progetto."
fi

# 4. Spostamento sicuro
if [ -f "$PROJECT_KEY_DIR/$KEY_NAME" ]; then
    echo "Spostamento chiave privata in $SSH_DIR..."
    mv "$PROJECT_KEY_DIR/$KEY_NAME" "$SSH_DIR/"
    chmod 600 "$SSH_DIR/$KEY_NAME"
    echo "✅ Chiave privata protetta in $SSH_DIR"
else
    echo "ℹ️  Nessuna chiave privata trovata da spostare (probabilmente è già stata spostata)."
fi

# 5. Permessi chiave pubblica
if [ -f "$PROJECT_KEY_DIR/$KEY_NAME.pub" ]; then
    chmod 644 "$PROJECT_KEY_DIR/$KEY_NAME.pub"
    echo "✅ Chiave pubblica pronta in $PROJECT_KEY_DIR"
fi