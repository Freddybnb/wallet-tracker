#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  START — Lance le serveur FastAPI en arrière-plan
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/server.log"
PID_FILE="$PROJECT_DIR/data/server.pid"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─── Vérifications ───────────────────────────────────────────────────────
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${RED}ERREUR : .env manquant${NC}"
    echo "Copiez .env.example vers .env et configurez-le."
    exit 1
fi

# Vérif pas déjà running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Serveur déjà en cours (PID $OLD_PID)${NC}"
        echo "Utilisez ./stop.sh d'abord."
        exit 1
    else
        echo "  (PID file orphelin — suppression)"
        rm -f "$PID_FILE"
    fi
fi

# ─── Création logs dir ───────────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

# ─── Activation venv ─────────────────────────────────────────────────────
source "$PROJECT_DIR/venv/bin/activate"

# ─── Export env vars ─────────────────────────────────────────────────────
export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)

# ─── Lancement ───────────────────────────────────────────────────────────
echo -e "${GREEN}🚀 Démarrage du serveur...${NC}"
echo "  Port    : ${PORT:-8000}"
echo "  Logs    : $LOG_FILE"
echo "  DB      : $PROJECT_DIR/data/wallet_tracker.db"
echo

# Uvicorn en arrière-plan
cd "$PROJECT_DIR"
nohup python -m uvicorn server:app \
    --host "${HOST:-0.0.0.0}" \
    --port "${PORT:-8000}" \
    --log-level "${LOG_LEVEL:-info}" \
    >> "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Sauvegarde PID
echo $SERVER_PID > "$PID_FILE"

# Petite pause pour vérif démarrage
sleep 2
if kill -0 $SERVER_PID 2>/dev/null; then
    echo -e "${GREEN}✅ Serveur lancé (PID $SERVER_PID)${NC}"
    echo "  📍 URL : http://localhost:${PORT:-8000}"
    echo "  📋 Swagger : http://localhost:${PORT:-8000}/docs"
    echo
    echo "Pour suivre les logs :"
    echo "  tail -f $LOG_FILE"
    echo "  ou : $SCRIPT_DIR/logs.sh"
else
    echo -e "${RED}❌ Échec démarrage — vérifiez $LOG_FILE${NC}"
    exit 1
fi
