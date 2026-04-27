#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════
#  TEST — Envoie des webhooks simulés au serveur local
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BASE_URL="${BASE_URL:-http://localhost:8000}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Test Webhook — Solana Wallet Tracker          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo
echo "URL cible : $BASE_URL"
echo

# ─── Vérif serveur up ──────────────────────────────────────────────────
if ! curl -s "$BASE_URL/" > /dev/null; then
    echo -e "${RED}❌ Serveur non joignable à $BASE_URL${NC}"
    echo "Lancez d'abord : ./start.sh"
    exit 1
fi
echo -e "${GREEN}✓ Serveur joignable${NC}"
echo

# ─── Test 1: Ajout d'un wallet à surveiller ────────────────────────────
echo -e "${BLUE}═══ Test 1 — Ajout wallet surveillé ═══${NC}"
# Ex: wallet known (coinbase ou binance pour test, ou un wallet que vous contrôlez)
TEST_WALLET="7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU"  # Exemple
cat > /tmp/test_payload1.json <<EOF
{
  "address": "$TEST_WALLET",
  "min_amount": 0.5
}
EOF
echo "POST /wallets avec min_amount=0.5 SOL"
curl -s -X POST "$BASE_URL/wallets" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_payload1.json | jq '.' 2>/dev/null || curl -s -X POST "$BASE_URL/wallets" -H "Content-Type: application/json" -d @/tmp/test_payload1.json
echo
echo

# ─── Verify ─────────────────────────────────────────────────────────────
echo -e "${BLUE}═══ Vérification — Liste des wallets surveillés ═══${NC}"
curl -s "$BASE_URL/wallets" | jq '.' 2>/dev/null || curl -s "$BASE_URL/wallets"
echo
echo

# ─── Test 2: Simulate webhook — 5 SOL transfer (should trigger) ─────────
echo -e "${BLUE}═══ Test 2 — Webhook simulé (5 SOL transfer) ═══${NC}"
cat > /tmp/test_webhook.json <<'EOF'
{
  "transactions": [
    {
      "signature": "5mocked_tx_signature_1111111111111111111111111111111111111111111111111111",
      "instructions": [
        {
          "programId": "11111111111111111111111111111111",
          "parsed": {
            "type": "transfer",
            "info": {
              "source": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
              "destination": "DEST_WALLET_NEW_111111111111111111111111111",
              "lamports": 5000000000
            }
          }
        }
      ]
    }
  ]
}
EOF
echo "Envoi payload (5 SOL depuis wallet surveillé vers dest inconnue)..."
curl -s -X POST "$BASE_URL/simulate-webhook" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_webhook.json | jq '.' 2>/dev/null || curl -s -X POST "$BASE_URL/simulate-webhook" -H "Content-Type: application/json" -d @/tmp/test_webhook.json
echo
echo "→ Attendu : ALERTE dans les logs, wallet dest ajouté à tracked"
echo

# ─── Wait + verify tracked ───────────────────────────────────────────────
sleep 1
echo -e "${BLUE}═══ Vérif — Wallets trackés (destinataires) ═══${NC}"
curl -s "$BASE_URL/tracked" | jq '.' 2>/dev/null || curl -s "$BASE_URL/tracked"
echo
echo

# ─── Test 3: Simulate webhook — 0.01 SOL (should be ignored) ────────────
echo -e "${BLUE}═══ Test 3 — Webhook simulé (0.01 SOL < seuil 0.5) ═══${NC}"
cat > /tmp/test_webhook2.json <<'EOF'
{
  "transactions": [
    {
      "signature": "5mocked_tx_signature_2222222222222222222222222222222222222222222222222222",
      "instructions": [
        {
          "programId": "11111111111111111111111111111111",
          "parsed": {
            "type": "transfer",
            "info": {
              "source": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
              "destination": "DEST_WALLET_SMALL_22222222222222222222222222",
              "lamports": 10000000
            }
          }
        }
      ]
    }
  ]
}
EOF
echo "Envoi payload (0.01 SOL < 0.5 seuil)..."
curl -s -X POST "$BASE_URL/simulate-webhook" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_webhook2.json | jq '.' 2>/dev/null || curl -s -X POST "$BASE_URL/simulate-webhook" -H "Content-Type: application/json" -d @/tmp/test_webhook2.json
echo
echo "→ Attendu : Ignoré (pas d'alerte, wallet dest NON ajouté à tracked)"
echo

# ─── Stats finales ───────────────────────────────────────────────────────
echo -e "${BLUE}═══ Stats finales ═══${NC}"
curl -s "$BASE_URL/stats" | jq '.' 2>/dev/null || curl -s "$BASE_URL/stats"
echo
echo

# ─── Recent events ───────────────────────────────────────────────────────
echo -e "${BLUE}═══ Dernières transactions traitées ═══${NC}"
curl -s "$BASE_URL/recent?limit=5" | jq '.' 2>/dev/null || curl -s "$BASE_URL/recent?limit=5"
echo
echo

# ─── Done ────────────────────────────────────────────────────────────────
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Tests terminés                             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo
echo "Résumé :"
echo "  • Test 1 — Ajout wallet config : devrait être OK"
echo "  • Test 2 — Transfer 5 SOL (>0.5) → ALERTE + dest wallet sauvé"
echo "  • Test 3 — Transfer 0.01 SOL (<0.5) → ignoré"
echo
echo "Vérifiez manuellement la DB :"
echo "  sqlite3 data/wallet_tracker.db \"SELECT * FROM tracked_wallets\""
echo "  sqlite3 data/wallet_tracker.db \"SELECT * FROM processed_transactions\""
echo
