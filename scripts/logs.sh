#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  LOGS — Visualisation des logs serveur
# ═════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/server.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MENU='
┌─────────────────────────────────────────────┐
│  📺 Solana Tracker — Logs                   │
├─────────────────────────────────────────────┤
│  1. Afficher les dernières lignes (tail -f) │
│  2. Afficher tout le fichier (less)         │
│  3. Dernières 50 lignes                      │
│  4. Dernières 100 lignes                     │
│  5. Filtrer par "ALERTE"                     │
│  6. Compter les occurrences                  │
│  7. Effacer les logs                         │
│  0. Quitter                                  │
└─────────────────────────────────────────────┘
'

while true; do
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  📺 Visualisation des logs — Wallet Tracker   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo
    echo "Fichier : $LOG_FILE"
    echo "Taille   : $(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo '0')"
    echo
    echo "$MENU"
    read -p "Choix [0-7] > " choice

    case $choice in
        1)
            echo -e "${YELLOW}→ tail -f (Ctrl+C pour quitter)${NC}"
            tail -f "$LOG_FILE"
            ;;
        2)
            echo -e "${YELLOW}→ less (q pour quitter)${NC}"
            less "$LOG_FILE"
            ;;
        3)
            echo -e "${BLUE}── Dernières 50 lignes ──${NC}"
            tail -50 "$LOG_FILE" | sed 's/^/  /' || echo "(vide)"
            read -p "Appuyez sur Entrée..."
            ;;
        4)
            echo -e "${BLUE}── Dernières 100 lignes ──${NC}"
            tail -100 "$LOG_FILE" | sed 's/^/  /' || echo "(vide)"
            read -p "Appuyez sur Entrée..."
            ;;
        5)
            echo -e "${YELLOW}→ Filtrer par '🔔 ALERTE' (texte)${NC}"
            grep -i "ALERTE" "$LOG_FILE" 2>/dev/null | tail -20 | sed 's/^/  /' || echo "(aucune alerte)"
            read -p "Appuyez sur Entrée..."
            ;;
        6)
            TOTAL=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
            ALERTES=$(grep -c "ALERTE" "$LOG_FILE" 2>/dev/null || echo 0)
            echo " === Statistiques ==="
            echo "  Lignes totales    : $TOTAL"
            echo "  Alertes '🔔 ALERTE': $ALERTES"
            echo "  Ratio alerte      : $(awk "BEGIN {printf \"%.2f\", $ALERTES/($TOTAL?$TOTAL:1)*100}")%"
            read -p "Appuyez sur Entrée..."
            ;;
        7)
            echo -e "${RED}⚠️  Effacement des logs...${NC}"
            read -p "Confirmer ? (oui/non) > " confirm
            if [ "$confirm" = "oui" ]; then
                > "$LOG_FILE"
                echo "✅ Logs effacés."
                sleep 1
            else
                echo "Annulé."
                sleep 1
            fi
            ;;
        0)
            echo "Au revoir !"
            exit 0
            ;;
        *)
            echo "Choix invalide."
            sleep 1
            ;;
    esac
done
