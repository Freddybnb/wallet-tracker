# 🚆 Guide de déploiement Railway — Solana Wallet Tracker

**Durée** : 10–15 minutes
**Coût** : Free tier (500h) ou Pro ($5/mois pour 24/7)
**Difficulté** : Facile

---

## 📋 Table des matières

1. [Prérequis](#prérequis)
2. [Préparation du code](#préparation-du-code)
3. [Création projet Railway](#création-projet-railway)
4. [Configuration variables](#configuration-variables)
5. [Persistance SQLite](#persistance-sqlite)
6. [Déploiement & test](#déploiement--test)
7. [Configuration Helius](#configuration-helius)
8. [Gestion & logs](#gestion--logs)
9. [Dépannage](#dépannage)
10. [Backup & maintenance](#backup--maintenance)

---

## 1. Prérequis

- Compte GitHub (gratuit)
- Compte Railway (gratuit, connecte via GitHub)
- Clé API Helius (https://dev.helius.xyz)
- 10 minutes de temps

### Installation Railway CLI (optionnel mais pratique)

```bash
# Nécessite Node.js
npm install -g @railway/cli

# Vérification
railway --version
# Doit afficher : @railway/cli/X.Y.Z
```

---

## 2. Préparation du code

Votre projet `solana_webhook_tracker/` doit contenir :

```
solana_webhook_tracker/
├── Procfile              # ← obligatoire
├── railway.yml           # ← optionnel (déjà créé)
├── server.py
├── database.py
├── monitor.py
├── config.py
├── requirements.txt
├── .env.example          # ← ne pas commit .env !
└── ...
```

**Le `Procfile` déjà créé** :
```
web: python -m uvicorn server:app --host 0.0.0.0 --port $PORT
```

**Ne commit pas** :
- `.env` (vos secrets)
- `data/wallet_tracker.db` (généré)
- `logs/` (généré)
- `venv/` (généré)

**Commit** :
```bash
cd solana_webhook_tracker
git init
git add .
git commit -m "feat: initial webhook tracker — Railway ready"
```

---

## 3. Création projet Railway

### Via Interface Web (recommandé pour premier déploiement)

1. Allez sur https://railway.app
2. Cliquez **"New Project"** → **"Deploy from GitHub repo"**
3. Autorisez Railway à accéder à vos GitHub repos
4. Sélectionnez le repo `wallet-tracker`
5. Railway clone, installe les dépendances, detecte le `Procfile`

**Phase de build** (1–2 min) :
```
✓ Cloned repository
✓ Installed Python 3.11
✓ pip install -r requirements.txt
✓ Detected Procfile → web process
✓ Build successful
```

**Phase de déploiement** (~30s) :
```
✓ Deploying
✓ Service is healthy
✓ Deployed to https://wallet-tracker-production.up.railway.app
```

Copiez l'URL !

### Via CLI (pour déploiements ultérieurs)

```bash
# Login
railway login

# Initialise
railway init
# → Sélectionnez "Empty Project" ou "Existing"
# → Choisissez le dossier solana_webhook_tracker
# → Railway crée railway.json metadata

# Premier déploiement
railway up

# Déploiements suivants (après git push)
git add .
git commit -m "update"
git push
# Railway rebuild automatiquement
```

---

## 4. Configuration variables

### Via Dashboard (première fois)

Railway Dashboard → Votre projet → **Variables** :

| Variable | Valeur | Comment obtenir |
|----------|--------|----------------|
| `HELIUS_API_KEY` | `helius_sk_xxx...` | Helius Dashboard → API Keys |
| `WEBHOOK_SECRET` | `ab12cd...` (32 hex) | `python3 -c "import secrets; print(secrets.token_hex(16))"` |
| `DEFAULT_MIN_AMOUNT` | `0.1` | Optionnel |
| `LOG_LEVEL` | `INFO` | Optionnel |
| `DATABASE_URL` | `sqlite+aiosqlite:///data/wallet_tracker.db` | Si volume activé (recommandé) |

**⚠️ Important** : After adding variables, **redeploy** :
- Soit push a new commit (même ""), railway rebuild
- Soit `railway up` (CLI)

### Via CLI

```bash
railway variables set HELIUS_API_KEY votre_cle
railway variables set WEBHOOK_SECRET $(python3 -c "import secrets; print(secrets.token_hex(16))")
railway variables set DEFAULT_MIN_AMOUNT 0.1
railway variables set DATABASE_URL "sqlite+aiosqlite:///data/wallet_tracker.db"
railway variables set LOG_LEVEL INFO
```

---

## 5. Persistance SQLite (VOLUME)

**Problème** : Railway filesystem est **éphémère** — redémarrage = DB perdue.

**Solution** : Activer un volume Railway ($1 GB gratuit).

### Via Dashboard

1. Railway Dashboard → Votre projet → **Storage** (ou **Volumes**)
2. **Add Volume**
   - **Name**: `data`
   - **Mount path**: `/data`
   - **Size**: 1 GB (free)
3. Click **Create**

### Via CLI

```bash
railway volume create --name data --path /data --size 1GB
```

### Vérifiez le mount

Après déploiement :

```bash
railway shell
# Inside container:
ls -la /data
# Doit lister wallet_tracker.db (après 1ère init)
exit
```

**IMPORTANT** : Le chemin dans `DATABASE_URL` doit pointer vers `/data` :

```python
# config.py
DATABASE_URL = Field(
    "sqlite+aiosqlite:///data/wallet_tracker.db",
    alias="DATABASE_URL"
)
```

Railway injecte automatiquement la variable d'environnement.

---

## 6. Déploiement & test

### Premier déploiement (après config vars + volume)

```bash
# Push vers GitHub (déclenche Railway automatiquement)
git add .
git commit -m "Ready for Railway deploy"
git push origin main
```

Ou via CLI :

```bash
railway up
```

### Surveiller le déploiement

```bash
railway status               # Statut actuel
railway logs --follow        # Logs temps réel
```

**Logs attendus** :
```
INFO:     Started server process [...]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Tester l'app déployée

```bash
# Remplacez <APP> par votre URL railway.app
APP_URL="https://wallet-tracker-production.up.railway.app"

curl $APP_URL/
# Expected: {"service":"Solana Wallet Tracker","status":"online",...}

curl $APP_URL/stats
# Expected: {"total_transactions":0,"watched_wallets":0,"tracked_dest_wallets":0,...}
```

### Initialiser la base (premier run seulement)

La DB est créée automatiquement au premier contact. Mais pour être sûr :

```bash
railway run "python -c 'from database import init_db; import asyncio; asyncio.run(init_db())'"
```

Cela crée les 3 tables dans `/data/wallet_tracker.db` (sur le volume).

### Test complet

```bash
# 1. Ajouter un wallet test
curl -X POST $APP_URL/wallets \
  -H "Content-Type: application/json" \
  -d '{"address":"7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU","min_amount":0.5}'

# 2. Simuler un transfert
curl -X POST $APP_URL/simulate-webhook \
  -H "Content-Type: application/json" \
  -d @tests/mock_transfer_5sol.json

# 3. Vérifier tracked
curl $APP_URL/tracked | jq
```

---

## 7. Configuration Helius

### Créer le webhook

1. https://dev.helius.xyz/dashboard/webhooks → **Create Webhook**
2. Remplir :

| Champ | Valeur |
|-------|--------|
| **Webhook URL** | `https://<VOTRE_APP>.railway.app/webhook` |
| **Accounts** | Vos wallets (ex: `7xKX...`) |
| **Transaction Types** | `TRANSFER` (uniquement) |
| **Webhook Secret** | Même valeur que `WEBHOOK_SECRET` dans Railway Variables |

3. Click **Create Webhook**

### Tester depuis Helius Dashboard

Dans la liste des webhooks, à droite : bouton ⋮ → **Send Test**

Résultat attendu :
- Helius envoie une transaction simulée
- Votre app répond `200 OK`
- Logs Railway montrent : `📥 Webhook reçu — 1 transaction(s)`

Si erreur 401 : `WEBHOOK_SECRET` mismatch → vérifiez la variable Railway.

### Ajouter des wallets à Helius

Dans le webhook config, section **Accounts** :
- Ajoutez les adresses des wallets que vous voulez tracker
- Maximum 1000 accounts par webhook (Free Helius tier)
- Supporte wildcards ? Non — liste explicite

---

## 8. Gestion & logs

### Railway CLI (recommandé)

```bash
# Statut projet
railway status

# Logs temps réel
railway logs --follow

# Voir les 100 dernières lignes
railway logs --lines 100

# Filtre par niveau
railway logs --lines 100 --filter "ERROR"

# Run one-off command (dans le container)
railway run "python -c 'import sqlite3; print(sqlite3.connect(\"/data/wallet_tracker.db\").execute(\"SELECT COUNT(*) FROM processed_transactions\").fetchone())'"

# Variables list
railway variables

# Set variable
railway variables set HELIUS_API_KEY nouvelle_cle

# Déploiement manuel
railway up

# Down (stop) — gratuit
railway down

# Destroy (⚠️ supprime DB si pas de volume)
railway rm
```

### Dashboard Web

Railway Dashboard → Votre Projet :

- **Deployments** : historique, logs, rollback
- **Metrics** : CPU, RAM, network sur 24h
- **Variables** : gestion secrets
- **Settings** : Domains, moniteurs (healthchecks)
- **Shell** : bouton "Console" pour SSH dans container

### Monitoring externe (optionnel mais utile)

Cold start free tier (30min sleep) → pour éviter :

1. **UptimeRobot** (gratuit)
   - Create account → Add new monitor → HTTP(s)
   - URL : `https://<votre-app>.railway.app/`
   - Interval : 5 min (gratuit)
   - Keeps app awake (UptimeRobot ping = traffic)

2. **Healthchecks.io**
   - Similaire, plus avancé (notifications si down)

---

## 9. Dépannage

### Build failed

**Symptôme** : Railway logs: `ModuleNotFoundError: No module named 'server'`

**Cause** : `Procfile` manquant ou mal placé.

**Fix** :
- `Procfile` doit être à la **racine du repo** (pas dans `scripts/`)
- Pas d'extension (pas `Procfile.txt`)
- Contenu exact : `web: python -m uvicorn server:app --host 0.0.0.0 --port $PORT`

### 502 Bad Gateway

**Symptôme** : `curl https://... → 502`

**Diagnostic** :
```bash
railway logs --lines 50
```

**Causes possibles** :
1. `PORT` pas bind à `0.0.0.0` → **Fix**: `server:app --host 0.0.0.0 --port $PORT`
2. Missing env var (HELIUS_API_KEY) → app crash au startup → **Fix**: set vars
3. Python syntax error → **Fix**: `railway run "python -m py_compile server.py"`
4. DB path error (volume non mounté) → **Fix**: check `/data` exists

### Database not persisting

**Symptôme** : DB reset after each deploy

**Cause** : Pas de volume Railway configuré.

**Fix** :
1. Dashboard → Storage → Add Volume (`/data`)
2. Set `DATABASE_URL=sqlite+aiosqlite:///data/wallet_tracker.db`
3. Redeploy

### Webhook not received / 401

**Symptôme** : Helius dit "webhook failed" → 401

**Cause** : `WEBHOOK_SECRET` mismatch

**Fix** :
```bash
# Vérifiez Railway variable
railway variables get WEBHOOK_SECRET

# Comparez avec Helius Dashboard → Webhook Settings → Secret
# Doivent être identiques (case-sensitive, no spaces)

# Pour changer :
railway variables set WEBHOOK_SECRET $(python3 -c "import secrets; print(secrets.token_hex(16))")
# Puis update Helius Dashboard avec la même valeur
```

### Cold start (free tier sleep)

**Symptôme** : First request après 30min idle → lent (5–10s)

**Cause** : Free tier éteint le container après inactivité.

**Solutions** :
1. **Upgrade Pro** ($5/mois) — always on
2. **UptimeRobot** ping toutes les 20 min (gratuit)
   - Créez监测 HTTP → `https://.../` toutes les 20 min
   - Cela compte comme "activity" → ne dort pas

### Out of memory

**Symptôme** : `MemoryError` dans logs

**Cause** : Trop de transactions en RAM (SQLite charge tout)

**Fix** : Limitez la croissance DB :
```bash
# Nettoyage automatique (optionnel script)
railway run "sqlite3 /data/wallet_tracker.db 'DELETE FROM processed_transactions WHERE processed_at < date(\"now\", \"-90 day\");'"
```

---

## 10. Backup & maintenance

### Backup manuel

```bash
# Download DB depuis Railway
railway run "cat /data/wallet_tracker.db" > backup_$(date +%Y%m%d).db

# Avec volume backup (si configuré)
railway volume backup data backup_$(date +%Y%m%d).tar.gz
```

**Automation** (cron Railway — via `railway run` dans GitHub Actions) :

```yaml
# .github/workflows/backup.yml
name: Daily Backup
on:
  schedule:
    - cron: '0 2 * * *'  # 2h UTC daily
jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - uses: railwayapp/cli-action@v1
        with:
          command: run "cp /data/wallet_tracker.db /backups/$(date +\%Y\%m\%d).db"
```

### Nettoyage DB (garder taille raisonnable)

```bash
# Supprime transactions > 90 jours
railway run "sqlite3 /data/wallet_tracker.db 'DELETE FROM processed_transactions WHERE processed_at < datetime(\"now\", \"-90 days\");'"

# Supprime tracked_wallets jamais vus récemment
railway run "sqlite3 /data/wallet_tracker.db 'DELETE FROM tracked_wallets WHERE first_seen_at < datetime(\"now\", \"-180 days\");'"
```

### Update code

```bash
git add .
git commit -m "feat: add telegram alerts"
git push
# Railway rebuild automatiquement
```

### Rollback

Dashboard → Deployments → Click sur ancien commit → **Redeploy**

CLI : `railway rollback <deployment-id>`

---

## 🎯 Checklist complet (avant de partir)

- [ ] Code pushé sur GitHub
- [ ] Railway projet créé
- [ ] Variables: `HELIUS_API_KEY`, `WEBHOOK_SECRET` set
- [ ] Volume `/data` créé + `DATABASE_URL` pointe vers `/data/...`
- [ ] Deploy succeeded
- [ ] `curl https://.../stats` → 200 JSON
- [ ] Ajouté 1 wallet test via API
- [ ] Test simulate-webhook fonctionne
- [ ] Helius webhook créé avec URL Railway + même secret
- [ ] Helius "Send Test" → 200 sur votre app
- [ ] UptimeRobot configuré (si free tier) pour éviter sleep
- [ ] Backup automatique activé (optionnel)

---

## 📞 Support

- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
- Helius Docs: https://docs.helius.dev/

---

**Template terminé** — Déploiement Railway ~10 min. Bonne chasse ! 🚀
