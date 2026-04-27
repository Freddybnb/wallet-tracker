# ⚡ QUICKSTART — 5 minutes

**Objectif** : Votre bot webhook opérationnel en 5 min.

## 📋 Prérequis

- Clé API Helius (https://dev.helius.xyz → Dashboard → API Keys)
- Python 3.11+ installé
- Terminal (Termux ou Linux)

---

## 🚀 Étapes

### 1 — Clone / copie les fichiers

```bash
cd ~
mkdir -p wallet_tracker && cd wallet_tracker
# Copiez TOUS les fichiers du projet ici (via ADB, scp, ou manuel)
```

### 2 — Installation (1 min)

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

Cela installe : Python venv, dépendances, crée data/, logs/, initialise DB.

### 3 — Configuration (2 min)

```bash
nano .env
```

Modifiez :
```env
HELIUS_API_KEY=helius_sk_votre_cle
WEBHOOK_SECRET=un_secret_hex_32_caracteres_au_choix
PORT=8000
DEFAULT_MIN_AMOUNT=0.1
```

Générez un secret :
```bash
python3 -c "import secrets; print(secrets.token_hex(16))"
```

### 4 — Lancement (30s)

```bash
./scripts/start.sh
```

✓ Vous devez voir :
```
✅ Serveur lancé (PID 12345)
📍 URL : http://localhost:8000
```

Vérifiez :
```bash
curl http://localhost:8000/
# Doit renvoyer {"service":"Solana Wallet Tracker",...}
```

### 5 — Ajouter un wallet (30s)

```bash
curl -X POST http://localhost:8000/wallets \
  -H "Content-Type: application/json" \
  -d '{"address":"7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU","min_amount":0.5}'
```

(Remplacez par l'adresse que vous voulez tracker)

### 6 — Test local (1 min)

Dans un autre terminal :
```bash
./scripts/test.sh
```

Doit afficher :
- Wallet ajouté ✓
- Transfer 5 SOL → ALERTE ✓
- Wallet dest ajouté à `tracked` ✓
- Transfer 0.01 SOL → ignoré ✓

### 7 — Voir les logs

```bash
./scripts/logs.sh
```

Option 1 (tail -f) → regardez en temps réel.

---

## 🔗 Helius Webhook (pour production)

En développement, utilisez `/simulate-webhook`. En production :

```bash
./scripts/ngrok.sh
```

Copiez l'URL `https://xxxx.ngrok.io/webhook` dans Helius Dashboard.

---

## ✅ C'est bon !

Votre bot est maintenant prêt à recevoir des vraies transactions Helius en temps réel.

**Prochaines étapes suggérées** :
1. Ajouter Telegram (` telegram.py ` à créer)
2. Dashboard Streamlit (`streamlit run dashboard.py`)
3. Export CSV (`/export` endpoint)

Questions ? @AshAmg.

---

**Durée réelle** : ~4min après prérequis.
