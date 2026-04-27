#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  INSTALLATION — Solana Wallet Tracker (Termux / Linux)
# ═════════════════════════════════════════════════════════════════════════

set -e  # Exit on error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Solana Wallet Tracker — Installation          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo

# ─── 1. Vérif OS / Termux ───────────────────────────────────────────────
if [ -n "$TERMUX_VERSION" ]; then
    echo -e "${YELLOW}→ Termux détecté${NC}"
    PKG="pkg"
    PYTHON="python"
else
    echo -e "${YELLOW}→ Linux standard${NC}"
    PKG="apt-get"
    PYTHON="python3"
fi

# ─── 2. Mise à jour des paquets ─────────────────────────────────────────
echo -e "\n${GREEN}[1/5]${NC} Mise à jour des paquets..."
if [ -n "$TERMUX_VERSION" ]; then
    pkg update -y
else
    sudo apt-get update -y
fi

# ─── 3. Install Python + pip ────────────────────────────────────────────
echo -e "${GREEN}[2/5]${NC} Vérification Python..."
if ! command -v $PYTHON &> /dev/null; then
    echo "  Install python..."
    if [ -n "$TERMUX_VERSION" ]; then
        pkg install -y python git
    else
        sudo apt-get install -y python3 python3-pip python3-venv git
    fi
fi
$PYTHON --version

# ─── 4. Virtual environment ─────────────────────────────────────────────
echo -e "${GREEN}[3/5]${NC} Création venv..."
if [ ! -d "$PROJECT_DIR/venv" ]; then
    $PYTHON -m venv "$PROJECT_DIR/venv"
    echo "  ✅ venv créé"
else
    echo "  ℹ️ venv existe déjà"
fi

# Activate venv for current script subshell
source "$PROJECT_DIR/venv/bin/activate"

# ─── 5. Install dependencies ─────────────────────────────────────────────
echo -e "${GREEN}[4/5]${NC} Installation dépendances..."
pip install --upgrade pip
pip install -r "$PROJECT_DIR/requirements.txt"
echo "  ✅ Dépendances installées"

# ─── 6. Create .env if missing ──────────────────────────────────────────
echo -e "${GREEN}[5/5]${NC} Configuration..."
if [ ! -f "$PROJECT_DIR/.env" ]; then
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    echo "  ✅ .env créé depuis .env.example"
    echo -e "${YELLOW}   ⚠️  Éditez .env avec votre clé HELIUS_API_KEY${NC}"
else
    echo "  ℹ️ .env existe déjà"
fi

# ─── 7. Create data dir ─────────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/data"
mkdir -p "$PROJECT_DIR/logs"
echo "  ✅ Répertoires data/ et logs/ prêts"

# ─── 8. Initialise DB ────────────────────────────────────────────────────
echo -e "\n${GREEN}Initialisation base de données...${NC}"
source "$PROJECT_DIR/venv/bin/activate"
python -c "from database import init_db; import asyncio; asyncio.run(init_db())"
echo "  ✅ Base initialisée"

# ─── Done ────────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Installation terminée !                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo
echo "Prochaines étapes :"
echo "  1. Éditez .env : nano $PROJECT_DIR/.env"
echo "  2. Démarrez : $PROJECT_DIR/scripts/start.sh"
echo "  3. Vérifiez : curl http://localhost:8000/"
echo
echo "Pour lire les logs : $PROJECT_DIR/scripts/logs.sh"
echo
