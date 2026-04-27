#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  RAILWAY DEPLOY — Script de déploiement automatisé vers Railway
#  Usage : ./scripts/deploy-railway.sh
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🚆 Déploiement Railway — Solana Wallet Tracker ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo

# ─── Vérifications préalables ───────────────────────────────────────────
echo -e "${YELLOW}→ Vérifications...${NC}"

# Git
if ! command -v git &>/dev/null; then
    echo -e "${RED}❌ git non installé${NC}"
    exit 1
fi

# Railway CLI
if ! command -v railway &>/dev/null; then
    echo -e "${YELLOW}⚠️  Railway CLI non trouvé${NC}"
    read -p "Installer maintenant ? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        if ! command -v npm &>/dev/null; then
            echo -e "${RED}❌ npm requis pour installer Railway CLI${NC}"
            echo "Installez Node.js puis réessayez."
            exit 1
        fi
        npm install -g @railway/cli
    else
        echo "Annulé. Installez avec : npm i -g @railway/cli"
        exit 1
    fi
fi

# Login Railway
if ! railway whoami &>/dev/null; then
    echo -e "${YELLOW}→ Connexion Railway...${NC}"
    railway login
fi

# ─── Génération secret si pas dans .env ──────────────────────────────────
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env" 2>/dev/null || true
fi

if [ -z "$WEBHOOK_SECRET" ]; then
    echo -e "${YELLOW}→ Génération WEBHOOK_SECRET...${NC}"
    NEW_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(16))")
    echo "WEBHOOK_SECRET=$NEW_SECRET" >> "$PROJECT_DIR/.env"
    echo -e "${GREEN}✅ Secret généré et ajouté à .env${NC}"
    echo "   N'oubliez pas de le copier dans Railway Variables."
fi

# ─── Commit si modifications ────────────────────────────────────────────
cd "$PROJECT_DIR"
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}→ Commit des modifications...${NC}"
    git add .
    git commit -m "chore: prepare Railway deployment"
fi

# ─── Initialiser projet Railway (si pas encore fait) ────────────────────
if [ ! -f "railway.json" ]; then
    echo -e "${YELLOW}→ Initialisation Railway...${NC}"
    railway init
fi

# ─── Variables à vérifier ───────────────────────────────────────────────
echo
echo -e "${BLUE}═══ Variables Railway recommandées ═══${NC}"
echo "Assurez-vous que ces variables sont définies dans Railway Dashboard → Variables"
echo "  • HELIUS_API_KEY = votre clé Helius"
echo "  • WEBHOOK_SECRET = $(grep WEBHOOK_SECRET .env | cut -d= -f2 | head -1)"
echo "  • DATABASE_URL = sqlite+aiosqlite:///data/wallet_tracker.db"
echo "  • DEFAULT_MIN_AMOUNT = 0.1"
echo
read -p "Toutes les variables sont-elles set ? (O/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}Définissez-les d'abord :${NC}"
    echo "  railway variables set HELIUS_API_KEY <val>"
    echo "  railway variables set WEBHOOK_SECRET <val>"
    exit 1
fi

# ─── Volume (persistence) ───────────────────────────────────────────────
echo
echo -e "${BLUE}═══ Vérification Volume Railway ═══${NC}"
if railway volume list 2>/dev/null | grep -q "data"; then
    echo -e "${GREEN}✅ Volume 'data' existe déjà${NC}"
else
    echo -e "${YELLOW}→ Création volume 'data' (1GB)...${NC}"
    railway volume create --name data --path /data --size 1GB
    echo -e "${GREEN}✅ Volume créé${NC}"
    echo "  Assurez-vous que DATABASE_URL pointe vers /data/wallet_tracker.db"
fi

# ─── Deploy ──────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Déploiement en cours...                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo

# Push vers GitHub (déclenche Railway)
echo -e "${YELLOW}→ Push GitHub (déclenche Railway rebuild)...${NC}"
git push origin main 2>/dev/null || {
    echo -e "${YELLOW}→ Pas de remote GitHub configuré${NC}"
    echo "   On utilise 'railway up' à la place."
    railway up
    exit 0
}

echo
echo -e "${GREEN}✅ Push effectué. Railway rebuild en cours...${NC}"
echo
echo "Commandes utiles :"
echo "  railway status              # état du projet"
echo "  railway logs --follow        # logs temps réel"
echo "  railway variables            # liste variables"
echo "  railway shell                # accès container (debug)"
echo
echo "URL attendue : https://<nom-projet>.up.railway.app"
echo "Webhook: https://<nom-projet>.up.railway.app/webhook"
echo
echo -e "${YELLOW}⏳ Attendez 2–3 min que le déploiement se termine, puis testez :${NC}"
echo "  curl https://<votre-app>.railway.app/stats"
