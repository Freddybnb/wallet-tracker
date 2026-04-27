#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  CHECK — Vérification santé du bot
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

OK=0
FAIL=0

check() {
    local desc="$1"
    local cmd="$2"
    echo -n "  $desc... "
    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((OK++))
    else
        echo -e "${RED}✗${NC}"
        ((FAIL++))
    fi
}

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Vérification santé — Wallet Tracker          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo

# ─── Fichiers ────────────────────────────────────────────────────────────
echo -e "${YELLOW}Fichiers :${NC}"
check ".env présent" "[ -f '$PROJECT_DIR/.env' ]"
check "server.py existe" "[ -f '$PROJECT_DIR/server.py' ]"
check "database.py existe" "[ -f '$PROJECT_DIR/database.py' ]"
check "monitor.py existe" "[ -f '$PROJECT_DIR/monitor.py' ]"
check "requirements.txt" "[ -f '$PROJECT_DIR/requirements.txt' ]"
echo

# ─── Répertoires ─────────────────────────────────────────────────────────
echo -e "${YELLOW}Répertoires :${NC}"
check "data/ présent" "[ -d '$PROJECT_DIR/data' ]"
check "logs/ présent" "[ -d '$PROJECT_DIR/logs' ]"
check "DB SQLite existe" "[ -f '$PROJECT_DIR/data/wallet_tracker.db' ]"
echo

# ─── Python modules ──────────────────────────────────────────────────────
echo -e "${YELLOW}Dépendances Python :${NC}"
source "$PROJECT_DIR/venv/bin/activate" 2>/dev/null || true
check "fastapi importable" "python -c 'import fastapi' 2>/dev/null"
check "sqlalchemy importable" "python -c 'import sqlalchemy' 2>/dev/null"
check "aiosqlite importable" "python -c 'import aiosqlite' 2>/dev/null"
echo

# ─── Processus ───────────────────────────────────────────────────────────
echo -e "${YELLOW}Processus :${NC}"
PID_FILE="$PROJECT_DIR/data/server.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "  Processus en cours : PID $PID ${GREEN}✓${NC}"
        ((OK++))
    else
        echo -e "  PID file orphelin ${RED}✗${NC}"
        ((FAIL++))
    fi
else
    echo "  Aucun PID file (serveur arrêté?)"
fi
echo

# ─── Network ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}Réseau :${NC}"
if lsof -i:8000 &>/dev/null; then
    echo -e "  Port 8000 utilisé ${GREEN}✓ (serveur UP)${NC}"
    ((OK++))
else
    echo -e "  Port 8000 libre ${RED}✗ (serveur DOWN)${NC}"
    ((FAIL++))
fi
echo

# ─── Résumé ──────────────────────────────────────────────────────────────
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Résumé : $OK OK / $FAIL erreurs                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ Tout semble bon !${NC}"
    echo "Dernières logLines :"
    tail -3 "$PROJECT_DIR/logs/server.log" 2>/dev/null || echo "  (pas de logs)"
else
    echo -e "${RED}❌ Problèmes détectés — consultez les points rouges ci-dessus.${NC}"
    exit 1
fi
