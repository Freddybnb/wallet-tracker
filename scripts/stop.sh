#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  STOP — Arrête proprement le serveur
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/data/server.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}⏹️  Arrêt du serveur...${NC}"

if [ ! -f "$PID_FILE" ]; then
    echo -e "${YELLOW}⚠️  Aucun PID file trouvé${NC}"
    echo "Recherche d'un processus python server.py..."
    pkill -f "uvicorn.*server:app" 2>/dev/null || true
    echo "✅ Aucun processus en cours."
    exit 0
fi

PID=$(cat "$PID_FILE")
echo "  PID trouvé : $PID"

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "  Signal SIGTERM envoyé..."

    # Wait max 5s
    for i in {1..5}; do
        if ! kill -0 "$PID" 2>/dev/null; then
            echo -e "${GREEN}✅ Serveur arrêté.${NC}"
            rm -f "$PID_FILE"
            exit 0
        fi
        sleep 1
    done

    # Force kill
    echo -e "${YELLOW}⚠️  Forçage...${NC}"
    kill -9 "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo -e "${GREEN}✅ Serveur arrêté (forcé).${NC}"
else
    echo -e "${YELLOW}⚠️  Processus $PID non trouvé (déjà arrêté?)${NC}"
    rm -f "$PID_FILE"
fi
