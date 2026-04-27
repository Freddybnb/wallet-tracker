# Solana Wallet Tracker — Version Webhook (Transfers Uniquement)

Bot de surveillance temps réel pour wallet Solana via Helius webhooks.
 Surveille les transferts SOL, sauvegarde automatiquement les wallets destinataires,
 et enregistre l'historique. Déployable sur Termux (Android) ou tout serveur Linux.

## 🎯 Fonctionnalités

- ✅ **Webhook Helius** : Réception en temps réel (< 1s)
- ✅ **Filtre par amount** : Seuil minimum configurable (ex: 0.1 SOL)
- ✅ **Auto-track dest wallets** : Nouveau wallet reçoit des fonds → automatiquement ajouté
- ✅ **Deduplication** : Pas de doublons même si Helius renvoie le webhook
- ✅ **API REST** : Endpoints pour gérer les wallets suivis
- ✅ **SQLite** : Base de données locale, zéro config
- ✅ **Termux-ready** : Scripts d'installation/démarrage spécifiques
- 📈 **Extensible** : Prêt pour ajouter Telegram, dashboard, auto-buy

## 📁 Structure du projet

```
solana_webhook_tracker/
├── server.py                 # FastAPI app (webhook receiver)
├── database.py               # Gestion SQLite (3 tables)
├── monitor.py                # Logique métier (parsing Helius)
├── config.py                 # Configuration & env vars
├── requirements.txt          # Dépendances Python
├── .env                     # Variables d'environnement (à créer)
├── .env.example             # Template
├── Procfile                 # Railway deployment
├── railway.yml              # Railway config (avancé)
├── README.md                # Ce fichier
├── RAILWAY_DEPLOY.md        # Guide déploiement Railway
├── data/
│   └── wallet_tracker.db    # Base SQLite (créée auto)
└── scripts/
    ├── install.sh           # Installation Termux / Linux
    ├── start.sh             # Lancement serveur
    ├── stop.sh              # Arrêt serveur
    ├── restart.sh           # Redémarrage
    ├── check.sh             # Vérification santé
    ├── test.sh              # Tests mock webhook
    ├── logs.sh              # Visualisation logs
    ├── deploy-railway.sh    # Déploiement automatisé Railway
    └── ngrok.sh             # Tunnel HTTPS (optionnel)
```

## 🚀 Installation rapide

### Prérequis
- Python 3.11+ (Termux : `pkg install python`)
- pip
- Clé API Helius (gratuite sur https://helius.dev)

### 1. Clone / copie des fichiers
```bash
cd ~
mkdir -p wallet_tracker
cd wallet_tracker
# Copiez tous les fichiers ici
```

### 2. Installation des dépendances
```bash
pip install -r requirements.txt
```

### 3. Configuration
```bash
cp .env.example .env
nano .env   # Éditez avec vos valeurs
```

Variables obligatoires :
```env
HELIUS_API_KEY=votre_clé_helius
WEBHOOK_SECRET=un_secret_hex_aleatoire_32_caracteres
PORT=8000
DATABASE_URL=sqlite+aiosqlite:///./data/wallet_tracker.db
```

### 4. Initialiser la base
```bash
python -c "from database import init_db; init_db()"
```

### 5. Lancer le serveur
```bash
./scripts/start.sh
```

### 6. Vérifier
```bash
curl http://localhost:8000/
```

## 🔗 Configuration Helius Webhook

1. Allez sur https://dev.helius.xyz/dashboard/webhooks
2. Créez un nouveau webhook :
   - URL : `https://<VOTRE_HTTPS_URL>/webhook` (voir ngrok ci-dessous)
   - Accounts : ajoutez les wallets à surveiller (ex: `7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU`)
   - Types : `TRANSFER` (uniquement)
   - Webhook secret : copiez le `WEBHOOK_SECRET` de votre `.env`
3. Sauvegarder

### HTTPS en local (ngrok)

Helius exige HTTPS. En développement local :

```bash
# Installer ngrok (Termux)
pkg install curl
curl -s https://ngrok.com/download | tar xz
./ngrok http 8000

# Vous obtenez une URL comme : https://abc123.ngrok.io
# Utilisez : https://abc123.ngrok.io/webhook
```

**Production** : Déployez sur Railway/Fly.io (HTTPS fourni).

## 📡 API REST

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/wallets` | GET | Liste des wallets suivis |
| `/wallets` | POST | Ajouter un wallet `{"address":"...", "min_amount":0.5}` |
| `/wallets/{address}` | DELETE | Supprimer un wallet suivi |
| `/webhook` | POST | **Helius webhook** (ne pas appeler manuellement) |
| `/tracked` | GET | Wallets destinataires enregistrés |
| `/stats` | GET | Statistiques (nb tx, nb dest wallets) |

Exemples :
```bash
# Lister wallets suivis
curl http://localhost:8000/wallets

# Ajouter wallet avec seuil 2.5 SOL
curl -X POST http://localhost:8000/wallets \
  -H "Content-Type: application/json" \
  -d '{"address":"7xKX...","min_amount":2.5}'

# Voir wallets détectés automatiquement
curl http://localhost:8000/tracked
```

## 🗄️ Base de données (SQLite)

### Tables

**watch_configs** — Wallets que vous suivez manuellement
```sql
id | wallet_address | min_amount_sol | enabled | created_at
```

**tracked_wallets** — Wallets destinataires auto-découverts
```sql
id | wallet_address | source_wallet | source_txid | amount_sol | first_seen_at
```

**processed_transactions** — Déduplication (empêche les doubles traitements)
```sql
txid (PRIMARY KEY) | wallet_address | type | amount_sol | raw_data | processed_at
```

### Requêtes utiles
```bash
sqlite3 data/wallet_tracker.db "SELECT * FROM watch_configs"
sqlite3 data/wallet_tracker.db "SELECT wallet_address, amount_sol FROM tracked_wallets ORDER BY amount_sol DESC LIMIT 10"
sqlite3 data/wallet_tracker.db "SELECT COUNT(*) FROM processed_transactions"
```

## 🧪 Tests

Script de test qui envoie un webhook simulé :
```bash
./scripts/test.sh
```

Payload mock :
- Transfert 5 SOL (déclenche alerte)
- Transfert 0.01 SOL (ignoré, sous le seuil)
- Transfert 1.2 SOL (déclenche alerte)

Vérifiez la sortie console et la DB :
```bash
sqlite3 data/wallet_tracker.db "SELECT * FROM processed_transactions ORDER BY processed_at DESC LIMIT 3"
```

## 📺 Logs

```bash
# logs en temps réel
./scripts/logs.sh

# Ou directement
tail -f logs/server.log
```

## 🔧 Scripts Termux

| Script | Usage |
|--------|-------|
| `install.sh` | Installe dépendances, crée venv, structure |
| `start.sh`   | Lance le serveur (background tmux) |
| `stop.sh`    | Arrête le serveur |
| `restart.sh` | Redémarre après mise à jour code |
| `check.sh`   | Vérifie santé : DB, port, process |
| `test.sh`    | Envoie 3 transactions mock |
| `logs.sh`    | Menu interactif de logs |
| `deploy-railway.sh` | Déploiement automatisé Railway (CLI) |

## 🚀 Déploiement Cloud

Voir le guide complet :
- **[Railway (recommandé)](RAILWAY_DEPLOY.md)** — 10 min, HTTPS auto
- Dockerfile inclus pour Fly.io / Render
- VPS systemd template (optionnel)

### Filtres par wallet
Chaque wallet peut avoir un `min_amount` différent. Ajout via API :

```bash
# Wallet A : alerte si > 1 SOL
curl -X POST http://localhost:8000/wallets -d '{"address":"WALLET_A","min_amount":1.0}'

# Wallet B : alerte si > 10 SOL
curl -X POST http://localhost:8000/wallets -d '{"address":"WALLET_B","min_amount":10.0}'
```

### Rate limiting
Le webhook Helius peut envoyer plusieurs tx simultanément. FastAPI + SQLite gère la concurrence (serialization automatique des writes).

### Backup
```bash
# Backup DB
cp data/wallet_tracker.db "backups/wallet_tracker_$(date +%Y%m%d_%H%M%S).db"
```

## 🐛 Dépannage

| Problème | Solution |
|----------|----------|
| `ModuleNotFoundError` | `pip install -r requirements.txt` |
| Port 8000 occupé | Changez `PORT` dans `.env` ou `lsof -ti:8000 | xargs kill` |
| Webhook non reçu | Vérifiez ngrok + URL Helius + secret matching |
| Duplicate tx | `processed_transactions` gère idempotence |
| DB corrompue | Supprimez `data/wallet_tracker.db` et relancez `init_db()` |

## 🚆 Déploiement sur Railway (recommandé)

Railway est la façon la plus simple de déployer en production avec HTTPS automatique. Aucun serveur à gérer.

### Avantages
- ✅ **HTTPS inclus** : URL `https://<app>.railway.app` dès la première minute
- ✅ **GitHub集成** : Déploiement automatique à chaque `git push`
- ✅ **Free tier généreux** : 500h/mois (≈ 20 jours) + $5 crédit = 600h
- ✅ **Persistance** : Volumes disque pour SQLite (ou Postgres intégré)
- ✅ **Logs centralisés** : `railway logs --follow`
- ✅ **Scaling** : Passer de 1 à plusieurs instances en 1 clic

### Étape 1 — Préparation du repo

```bash
cd solana_webhook_tracker

# Assurez-vous que ces fichiers sont présents :
ls -1 Procfile railway.yml  # doivent exister

# Commit et push vers GitHub
git init
git add .
git commit -m "Initial commit — Solana Wallet Tracker"
git branch -M main
git remote add origin https://github.com/VOTRE_USER/ wallet-tracker.git
git push -u origin main
```

### Étape 2 — Créer le projet Railway

1. Allez sur https://railway.app
2. **Login** avec GitHub
3. **New Project** → **Deploy from GitHub repo**
4. Sélectionnez votre repo `wallet-tracker`
5. Railway détecte automatiquement le `Procfile` et configure l'environnement Python

### Étape 3 — Variables d'environnement

Railway Dashboard → Votre projet → **Variables** (onglet)

Ajoutez :

| Clé | Valeur | Note |
|-----|--------|------|
| `HELIUS_API_KEY` | `helius_sk_xxxxx` | Votre clé Helius |
| `WEBHOOK_SECRET` | `0123456789abcdef0123456789abcdef` | 32 caractères hex (générez avec `python -c "import secrets; print(secrets.token_hex(16))"`) |
| `DEFAULT_MIN_AMOUNT` | `0.1` | (optionnel) |
| `LOG_LEVEL` | `INFO` | (optionnel) |

**⚠️ Ne jamais commit `.env`** — Railway stocke les secrets dans son dashboard.

### Étape 4 — Activer le stockage persistant (important !)

Par défaut, Railway utilise un filesystem **éphémère** (reset à chaque deploy). Pour garder votre DB :

1. Railway Dashboard → Votre projet → **Storage** (onglet)
2. **Add Volume**
   - **Name**: `data`
   - **Mount path**: `/data`
   - **Size**: 1 GB (gratuit)
3. Cliquez **Create**

Ensuite, modifiez la variable `DATABASE_URL` :

```
DATABASE_URL = sqlite+aiosqlite:///data/wallet_tracker.db
```

Mettez à jour `config.py` ou utilisez la variable Railway :
```env
DATABASE_URL=sqlite+aiosqlite:///data/wallet_tracker.db
```

### Étape 5 — Premier déploiement

Railway déploie automatiquement après le `git push`. Attendez ~2 minutes.

Vérifiez :
- Statut : **Deployment succeeded** (✅ vert)
- URL du service : https://wallet-tracker-production.up.railway.app (varie)

Testez :
```bash
curl https://votre-app.up.railway.app/stats
```

### Étape 6 — Configurer Helius

Webhook URL :
```
https://votre-app.up.railway.app/webhook
```

1. Helius Dashboard → Webhooks
2. Créer / éditer :
   - **URL** : `https://votre-app.up.railway.app/webhook`
   - **Accounts** : vos wallets à surveiller
   - **Types** : `TRANSFER`
   - **Webhook Secret** : exactement le même que `WEBHOOK_SECRET` Railway
3. Save

**Test Helius** : Dans le dashboard, bouton "Send Test" → doit renvoyer 200.

### Étape 7 — Gestion du service

**Logs en temps réel** :
```bash
# Installer Railway CLI
npm i -g @railway/cli

# Login
railway login

# Lier au projet (depuis le dossier local)
railway link

# Voir les logs
railway logs --follow
```

**Variables** :
```bash
railway variables          # list
railway variables set HELIUS_API_KEY votre_cle
```

**Redéployer manuellement** :
```bash
railway up
```

**SSH / shell debug** :
```bash
railway shell
# À l'intérieur du container :
ls -la data/
sqlite3 data/wallet_tracker.db "SELECT COUNT(*) FROM processed_transactions;"
```

### Étape 8 — Ajouter un wallet

```bash
curl -X POST https://votre-app.up.railway.app/wallets \
  -H "Content-Type: application/json" \
  -d '{"address":"VOTRE_WALLET","min_amount":0.5}'
```

### Étape 9 — Monitoring

| Outil | Usage |
|-------|-------|
| Dashboard Railway | Graphiques CPU/RAM, logs, erreurs |
| `railway logs` | Logs temps réel en CLI |
| `/stats` endpoint | `curl https://.../stats` → JSON |
| SQLite DB | `railway shell` → `sqlite3 data/wallet_tracker.db` |

### 🔧 Configuration avancée Railway

**Sticky plan (pour éviter le cold start)** :
- Free tier : l'endort après 30 min sans traffic
- Solution : Upgrade vers plan **Pro** ($5/mois) ou utiliser UptimeRobot (ping toutes les 25 min)
- Créez un compte UptimeRobot → ajoutez monitoring HTTP → https://votre-app/health

**Scale à N instances** :
- Free: 1 instance
- Pro ($20/mo): jusqu'à 3 instances
- Augmente disponibilité, pas utile pour ce workload léger

**Postgres au lieu de SQLite** (meilleure pour scale) :
1. Railway Dashboard → Add Service → Postgres
2. `DATABASE_URL` injecté automatiquement
3. Modifiez `config.py` pour utiliser Postgres (SQLAlchemy supporte les deux)

**Custom domain** (optionnel) :
1. Railway Dashboard → Settings → Domains → Add Domain
2. Entrez `tracker.votredomaine.com`
3. Railway donne des nameservers / records DNS
4. Ajoutez CNAME chez votre registrar
5. HTTPS automatique (Let's Encrypt)

### 💰 Coût estimé

| Ressource | Free tier | Pro ($5/mo) |
|-----------|-----------|-------------|
| Heures/mois | 500h | Illimité |
| Sleep after idle | Oui (30min) | Non (always on) |
| Instances | 1 | 1 |
| RAM/CPU | 512 MB / 1 vCPU | Idem |
| Stockage | 1 GB | 1 GB |
| Domains custom | Non | Oui |

**Notre cas** : Un wallet tracker tourne 24/7 → 720h/mois → dépasse free tier.
**Recommandation** : Plan **Pro** à $5/mois pour éviter le sleep.

### 🐛 Dépannage Railway

| Problème | Diagnostic | Fix |
|----------|------------|-----|
| Build failed | `railway logs` | Missing `Procfile`, syntax error, pip install timeout |
| 502 Bad Gateway | Vérifiez les logs | Port wrong, app crashed, missing env var |
| DB reset à chaque deploy | Volume non monté | Ajoutez Volume + DATABASE_URL vers `/data/` |
| Webhook non reçu | `railway logs` + Helius | Vérifiez URL, secret, que l'app répond 200 |
| Cold start lent (free tier) | UptimeRobot ping | Ajoutez monitoring externe toutes les 25 min |
| Out of memory | `railway metrics` | Optimisez SQLite, réduisez données en RAM |

**Commandes utiles** :
```bash
railway status              # État du projet
railway variables           # Liste variables
railway run "python -c '...'"  # Exécute commande dans container
railway down                # Stop service (gratuit quand même)
railway rm                  # Supprime projet (⚠️ supprime DB si pas volume !)
```

### 📦 Alternative : Railway CLI sans GitHub

```bash
railway login
railway init                # Crée railway.yml
railway link                # Lie au projet Railway existant
railway up                  # Déploie
```

### 🎯 Best Practices

1. **Backup DB quotidien** :
   ```bash
   railway run "cp /data/wallet_tracker.db /backups/$(date +%Y%m%d).db"
   ```
   (Configurez un volume `/backups` ou download via Railway)

2. **Monitoring externe** :
   - UptimeRobot → ping `/` toutes les 20 min → évite sleep
   - Healthcheck : `/` renvoie 200 si DB OK

3. **Variables sensibles** :
   - Helius API key → mettez-la en Railway Variables (password-protected)
   - Webhook secret → générez un secret fort

4. **Secrets rotation** :
   - Changez `WEBHOOK_SECRET` tous les 3 mois
   - Mettez à jour Helius Dashboard + Railway Variables simultanément

5. **Logs retention** :
   - Railway garde logs 7 jours par défaut
   - Exportez logs importants vers un fichier si besoin

---

**Résumé** : Push → Railway → Variables → Volume → Helius → Done. ~10 minutes chrono.

## 📊 Comparaison des plateformes

| Plateforme | Coût | HTTPS | Sleep (free) | DB persistence | Setup |
|------------|------|-------|--------------|----------------|-------|
| **Railway** | Free 500h / $5 illimité | ✅ Auto | Oui (30min) | ✅ Volume 1GB | ⭐⭐⭐⭐⭐ |
| **Fly.io** | Free 3VM / $5+ | ✅ Auto | Non | ✅ Volume | ⭐⭐⭐⭐ |
| **Render** | Free 750h / $7+ | ✅ Auto | Non | ✅ Disk 1GB | ⭐⭐⭐⭐ |
| **VPS** | $5–10/mois | ✅ (certbot) | Non | ✅ Disque | ⭐⭐⭐ |

**Notre top** : Railway (simplicité + gratuité suffisante pour tests).

Pour un comparatif détaillé : voir `DEPLOYMENT.md`.
## 🐳 Déploiement Docker (optionnel)

Si vous préférez Docker (pour Fly.io, Render, ou local) :

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create data dir
RUN mkdir -p data logs

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build & run :
```bash
docker build -t solana-tracker .
docker run -p 8000:8000 --env-file .env solana-tracker
```

---

## 📄 Licence

MIT — Utilisez librement.

- [ ] Notifications Telegram/Slack
- [ ] Dashboard Streamlit/Gradio
- [ ] Export CSV/Excel
- [ ] Alertes prix (si transfert > X SOL)
- [ ] Multi-chain (Ethereum via Moralis)
- [ ] Auto-buy Jupiter après détection
- [ ] Scoring wallets (analyse historique)

## 📄 Licence

MIT — Utilisez librement.

## 🙋 Support

Ouvrez une issue ou contactez @AshAmg.

---

**Statut** : Production-ready v1.0 — Testé sur Termux Android 14, Python 3.11, FastAPI 0.104.
