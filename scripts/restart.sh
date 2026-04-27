#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  RESTART — Redémarrage propre du serveur
# ═════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n${GREEN}🔄 Redémarrage...${NC}\n"

# Stop
"$SCRIPT_DIR/stop.sh"

# Petite pause
sleep 2

# Start
"$SCRIPT_DIR/start.sh"
