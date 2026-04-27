#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  NGROK — Démarrage tunnel HTTPS (pour Helius webhook)
#  NÉCESSAIRE en dev — Helius exige HTTPS
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PORT="${PORT:-8000}"
NGROK_API="http://localhost:4040/api/tunnels"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🚇 Ngrok Tunnel — Helius Webhook              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo
echo "Port local : $PORT"
echo

# ─── Check if ngrok is installed ─────────────────────────────────────────
if ! command -v ngrok &>/dev/null; then
    echo -e "${RED}❌ ngrok n'est pas installé${NC}"
    echo "Téléchargement automatique..."
    curl -s https://ngrok.com/download | tar xz -C ~/bin 2>/dev/null || {
        echo "Veuillez installer manuellement :"
        echo "  wget https://bin.equinox.io/c/bNyj1Y4nzQY/ngrok-v3-stable-linux-arm64.zip"
        echo "  unzip ngrok-v3-stable-linux-arm64.zip -d ~/bin"
        exit 1
    }
    chmod +x ~/bin/ngrok
    echo "✅ ngrok installé"
fi

# ─── Check authtoken ──────────────────────────────────────────────────────
if [ ! -f ~/.ngrok2/ngrok.yml ] || ! grep -q "authtoken:" ~/.ngrok2/ngrok.yml 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Aucun authtoken ngrok configuré${NC}"
    echo "1. Inscrivez-vous sur https://ngrok.com"
    echo "2. Récupérez votre authtoken dans le dashboard"
    read -p "Collez votre authtoken (ou Enter pour sauter) : " TOKEN
    if [ -n "$TOKEN" ]; then
        ngrok config add-authtoken "$TOKEN"
        echo "✅ Authtoken enregistré"
    else
        echo "⚠️  Sans authtoken : URL aléatoire par restart, rate limits plus bas"
    fi
fi

# ─── Start ngrok ──────────────────────────────────────────────────────────
echo
echo -e "${BLUE}→ Démarrage tunnel ngrok sur le port $PORT...${NC}"
echo "Appuyez sur Ctrl+C pour arrêter le tunnel (le serveur continue)"
echo

# Kill old ngrok if running
pkill -f "ngrok http $PORT" 2>/dev/null || true

# Start ngrok in background
ngrok http "$PORT" --log=stdout > /dev/null &
NGROK_PID=$!
sleep 2

# ─── Fetch public URL ─────────────────────────────────────────────────────
for i in {1..10}; do
    PUBLIC_URL=$(curl -s "$NGROK_API" | grep -o '"public_url":"[^"]*' | cut -d'"' -f4 | head -1)
    if [ -n "$PUBLIC_URL" ]; then
        break
    fi
    echo "  Attente tunnel... ($i/10)"
    sleep 1
done

if [ -z "$PUBLIC_URL" ]; then
    echo -e "${RED}❌ Impossible de récupérer l'URL ngrok${NC}"
    echo "Vérifiez : curl $NGROK_API"
    kill $NGROK_PID 2>/dev/null || true
    exit 1
fi

WEBHOOK_URL="${PUBLIC_URL}/webhook"

echo
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Tunnel ngrok actif                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo
echo "  🌐 URL HTTPS publique : $PUBLIC_URL"
echo "  📡 Webhook URL        : $WEBHOOK_URL"
echo
echo " ═════════════════════════════════════════════════"
echo " 📋 CONFIGURATION HELIUS"
echo " ═════════════════════════════════════════════════"
echo
echo "  1. Allez sur https://dev.helius.xyz/dashboard/webhooks"
echo "  2. Créez un nouveau webhook ou éditez un existant"
echo "  3. Collez cette URL : $WEBHOOK_URL"
echo "  4. Sélectionnez :"
echo "       • Accounts : vos wallets à surveiller"
echo "       • Types    : TRANSFER (uniquement)"
echo "  5. Copiez le Webhook Secret dans votre .env :"
echo "       WEBHOOK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(16))")"
echo "  6. Sauvegardez"
echo
echo " ⚠️  NOTE : L'URL ngrok change à chaque redémarrage."
echo "   Mettez à jour Helius à chaque fois, ou achetez un"
echo "   domaine réservé ngrok pour une URL fixe."
echo
echo "Pour arrêter le tunnel :"
echo "  kill $NGROK_PID"
echo "  ou pkill -f 'ngrok http $PORT'"
echo

# Wait (soit l'utilisateur Ctrl+C, soit on peut mettre en mode service)
wait $NGROK_PID
