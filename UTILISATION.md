# 📖 UTILISATION — Scénarios pratiques

Ce document montre 8 cas d'usage courants du bot webhook.

## 1️⃣ Ajouter un wallet à surveiller

```bash
# Par API (recommandé)
curl -X POST http://localhost:8000/wallets \
  -H "Content-Type: application/json" \
  -d '{"address":"WALLET_ADDRESS","min_amount":1.0}'

# Réponse
{
  "status": "ok",
  "wallet": "WALLET_ADDRESS",
  "min_amount_sol": 1.0
}
```

**Seuil** : Si le wallet envoie ≥ 1.0 SOL → alerte + dest wallet sauvé.

---

## 2️⃣ Lister les wallets surveillés

```bash
curl http://localhost:8000/wallets | jq

# Sortie :
[
  {
    "address": "WALLET_A",
    "min_amount_sol": 1.0,
    "enabled": true,
    "created_at": "2025-01-15T10:30:00"
  }
]
```

---

## 3️⃣ Supprimer un wallet

```bash
curl -X DELETE http://localhost:8000/wallets/WALLET_A
```

---

## 4️⃣ Voir les wallets destinataires détectés automatiquement

```bash
curl http://localhost:8000/tracked | jq '.[] | {wallet, amount: .amount_sol, from: .source_wallet}'
```

**Utilité** : Vous voyez tous les nouveaux wallets qui ont reçu des fonds depuis un wallet surveillé.

---

## 5️⃣ Forcer une vérification manuelle d'une transaction

Si vous avez une signature de transaction Helius et voulez tester son traitement :

```bash
# Obtenez la transaction complète via Helius API d'abord :
# curl "https://api.helius.xyz/v0/addresses/WALLET/transactions?api-key=..." > tx.json

# Envoyez à votre endpoint simulate :
curl -X POST http://localhost:8000/simulate-webhook \
  -H "Content-Type: application/json" \
  -d '{"transactions": [ tx_json_ici ]}'
```

---

## 6️⃣ Stats globales

```bash
curl http://localhost:8000/stats | jq

# Exemple sortie :
{
  "total_transactions": 1423,
  "watched_wallets": 5,
  "tracked_dest_wallets": 37,
  "uptime": "2025-01-15T14:22:10"
}
```

---

## 7️⃣ Filtrer les logs par alerte

```bash
./scripts/logs.sh
# Choix 5 → grep "ALERTE"
```

OU en CLI directe :
```bash
grep "🔔 ALERTE" logs/server.log | tail -20
```

Format log alerte :
```
2025-01-15 14:23:01,456 [INFO] server — 🔔 ALERTE : 7xKX... → Ds8E... | 2.5241 SOL
```

---

## 8️⃣ Changer le seuil d'un wallet existant

Supprimez puis recréez (pour l'instant) :

```bash
curl -X DELETE http://localhost:8000/wallets/WALLET_A
curl -X POST http://localhost:8000/wallets \
  -H "Content-Type: application/json" \
  -d '{"address":"WALLET_A","min_amount":5.0}'
```

**Note** : Une modification directe en SQLite est possible :
```bash
sqlite3 data/wallet_tracker.db \
  "UPDATE watch_configs SET min_amount_sol=5.0 WHERE wallet_address='WALLET_A';"
```

---

## 9️⃣ Vérifier la DB manuellement

```bash
# Wallets config
sqlite3 data/wallet_tracker.db "SELECT * FROM watch_configs;"

# Destinataires auto-trackés (top 10 par amount)
sqlite3 data/wallet_tracker.db \
  "SELECT wallet_address, amount_sol, source_wallet FROM tracked_wallets ORDER BY amount_sol DESC LIMIT 10;"

# Dernières transactions
sqlite3 data/wallet_tracker.db \
  "SELECT txid, wallet_address, amount_sol, processed_at FROM processed_transactions ORDER BY processed_at DESC LIMIT 5;"

# Compter
sqlite3 data/wallet_tracker.db "SELECT COUNT(*) FROM processed_transactions;"
```

---

## 🔟 Debug rapide

```bash
# 1. Vérifier statut
./scripts/check.sh

# 2. Relire logs
tail -50 logs/server.log

# 3. Redémarrer
./scripts/restart.sh

# 4. Vider logs
./scripts/logs.sh  # option 7

# 5. Test complet
./scripts/test.sh
```

---

## 📊 Interprétation des alertes

Exemple de log :
```
2025-01-15 16:45:12,123 [INFO] monitor — 🔔 ALERTE : 7xKX... → Ds8E... | 2.5241 SOL
```

**Analyse** :
- `7xKX...` = wallet source (configuré dans watch_configs)
- `Ds8E...` = wallet destination (nouveau, sauvé dans tracked_wallets)
- `2.5241 SOL` = montant transféré (supérieur au seuil)

**Action** :
- Le wallet dest `Ds8E...` est maintenant connu
- Vous pouvez l'ajouter à votre watchlist si pertinent :
  ```bash
  curl -X POST http://localhost:8000/wallets -d '{"address":"Ds8E...","min_amount":0.1}'
  ```

---

## 🎯 Bonnes pratiques

| Pratique | Commande |
|----------|----------|
| Backup DB | `cp data/wallet_tracker.db backup/$(date +%Y%m%d).db` |
| Nettoyage dest wallets anciens | `sqlite3 data/wallet_tracker.db "DELETE FROM tracked_wallets WHERE first_seen_at < date('now','-30 day');"` |
| Export CSV | `sqlite3 -header -csv data/wallet_tracker.db "SELECT * FROM tracked_wallets" > tracked.csv` |
| Surveillance CPU | `top -p $(cat data/server.pid)` |
| Rotations logs | `logrotate` config (ou script maison) |

---

**Besoin d'un autre scénario ?** Demandez à @AshAmg.
