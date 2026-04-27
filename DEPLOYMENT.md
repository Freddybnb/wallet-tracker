# Déploiement — Options comparées

Ce document compare les différentes façons de déployer le Solana Wallet Tracker.

## 📊 Matrice des options

| Critère | Termux (local) | Railway (cloud) | Docker (any) | VPS (systemd) |
|---------|---------------|----------------|--------------|---------------|
| **HTTPS** | ngrok (temporaire) | ✅ Automatique | ✅ (avec reverse proxy) | ✅ (certbot) |
| **Persistence** | Fichier local | Volume (1GB free) | Volume / bind mount | Disque système |
| **Coût** | Gratuit (juste électricité) | Free 500h ou $5/mois | Gratuit (self-host) | ~$5–10/mois VPS |
| **Setup** | 15 min | 10 min | 20 min | 30 min |
| **Maintenance** | Manuelle | Auto (git push) | Manuelle (docker) | Manuelle (sysadmin) |
| **Uptime** | 24/7 si charger | 99.9% garantis | Dépend hôte | Dépend hôte |
| **Scalability** | 1 device | 1–3 instances | Multi-container | 1–N instances |
| **Sleep** | Non (si branché) | Free tier: oui (30min) | Non | Non |
| **Best for** | Tests/dev, personal | Production simple | Cloud agnostique | Control total |

---

## 🏠 1. Termux / Local

**Utilisez pour** : développement, tests, preuve de concept, surveillance perso.

**HTTPS** : ngrok (gratuit mais URL change à chaque démarrage).

**Commande** :
```bash
./scripts/install.sh
./scripts/start.sh
./scripts/ngrok.sh   # optionnel, pour webhook Helius
```

**Inconvénients** :
- URL ngrok change → doit ré-update Helius
- Si téléphone éteint → bot arrêté
- Pas de backup automatique

**Lien** : Voir `README.md` sections Installation rapide + Configuration Helius.

---

## 🚆 2. Railway (recommandé production)

**Utilisez pour** : déploiement production rapide, 24/7, sans gestion serveur.

**HTTPS** : automatique (`*.railway.app`).

**Commande** :
```bash
./scripts/deploy-railway.sh  # automated (CLI)
# OU manuel:
git push origin main         # Railway rebuild auto
```

**Coût** : Free 500h (→ ~20 jours), Pro $5/mois (illimité + always-on).

**Étapes détaillées** : `RAILWAY_DEPLOY.md`

**Inconvénients** :
- Free tier: sleep après 30 min idle → upgrade Pro ou UptimeRobot ping
- Volume limité 1GB
- Lock-in Railway CLI (mais portable)

---

## 🐳 3. Docker (Fly.io, Render, self-host)

**Utilisez pour** : déploiement multi-cloud, portabilité, équipes.

### Dockerfile (inclus)
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p data logs
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Fly.io (similaire à Railway)

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Launch app
fly launch
# → choisir Dockerfile, region, nom app

# Set secrets
fly secrets set HELIUS_API_KEY=... WEBHOOK_SECRET=...

# Deploy
fly deploy

# HTTPS automatique
fly open
```

**Coût Fly.io** : Free 3 VMs 256MB, Shared CPU 3h/jour, ou $5/mois pour plus.

### Render

```bash
# Connect GitHub repo → New Web Service
# Environment: Python 3.11
# Build Command: pip install -r requirements.txt
# Start Command: python -m uvicorn server:app --host 0.0.0.0 --port $PORT
# Add Environment Variables: HELIUS_API_KEY, WEBHOOK_SECRET
# Add Disk: 1 GB Persistent
```

**Coût Render** : Free 750h/mois (≈ 31 jours), $7/mois pour always-on + disk.

---

## 🖥️ 4. VPS (Linux) — systemd

**Utilisez pour** : contrôle total, compliance, custom network.

### Setup (Ubuntu/Debian)

```bash
# Sur votre VPS (DigitalOcean, Linode, AWS EC2, etc.)
sudo apt update && sudo apt install -y python3 python3-pip python3-venv git

# Clone repo
git clone https://github.com/VOTRE/wallet-tracker.git
cd wallet-tracker

# Venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Config
cp .env.example .env
nano .env  # set HELIUS_API_KEY, WEBHOOK_SECRET, DATABASE_URL=sqlite+aiosqlite:///data/wallet_tracker.db

# Init DB
python -c "from database import init_db; import asyncio; asyncio.run(init_db())"

# Systemd service
sudo nano /etc/systemd/system/wallet-tracker.service
```

**Contenu `wallet-tracker.service`** :
```ini
[Unit]
Description=Solana Wallet Tracker
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/wallet-tracker
Environment="PATH=/home/$(whoami)/wallet-tracker/venv/bin"
EnvironmentFile=/home/$(whoami)/wallet-tracker/.env
ExecStart=/home/$(whoami)/wallet-tracker/venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Enable & start
sudo systemctl daemon-reload
sudo systemctl enable wallet-tracker
sudo systemctl start wallet-tracker

# Status
sudo systemctl status wallet-tracker

# Logs
sudo journalctl -u wallet-tracker -f
```

**HTTPS** : Nginx + Certbot (Let's Encrypt)

```bash
sudo apt install -y nginx certbot python3-certbot-nginx

# Nginx config
sudo nano /etc/nginx/sites-available/wallet-tracker
```

```nginx
server {
    listen 80;
    server_name tracker.votredomaine.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/wallet-tracker /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# SSL cert
sudo certbot --nginx -d tracker.votredomaine.com
# Done! HTTPS automatique renouvelé
```

**Coût VPS** : $5–10/mois (DigitalOcean droplet, Linode 1GB, Vultr).

**Avantages** :
- Full control
- Always on
- Volume illimité
- Cron jobs faciles

**Inconvénients** :
- Maintenance manuelle (updates, security)
- SetupSSL + firewall

---

## 🆚 Comparaison rapide

| Besoin | Recommandé |
|--------|------------|
| Test rapide sur téléphone | Termux + ngrok |
| Production perso (24/7) | Railway Pro $5/mois |
| Production équipe | Railway ou Fly.io |
| Data sovereignty / compliance | VPS own |
| Multi-cloud portability | Docker + Railway/Fly.io/Render |
| Pas de dépendance cloud | VPS self-host |

---

## 🔄 Migration entre plateformes

**De Railway → VPS** :
1. `railway run "sqlite3 /data/wallet_tracker.db .dump > backup.sql"`
2. Download backup.sql
3. Sur VPS: `sqlite3 data/wallet_tracker.db < backup.sql`
4. Copie code, reinstalle venv, set env vars
5. Systemd service

**De Termux → Railway** :
1. `git init` dans dossier Termux
2. Push GitHub
3. Railway deploy from GitHub
4. Copiez `data/wallet_tracker.db` si vous voulez conserver l'historique (scp → volume Railway)

**De Docker → Railway** :
Railway supporte Dockerfile aussi ! Juste push → Railway détecte et build.

---

## 🎯 Ma recommandation

**Pour 99% des users** :

1. **Development** : Termux local (`./scripts/install.sh` + `./scripts/test.sh`)
2. **Production** : Railway (Pro plan $5/mois)
   - Push code → auto-deploy
   - HTTPS included
   - 24/7 without sleep
   - Volume 1GB (suffisant pour des mois de logs)
   - Backup facile avec CLI

**Skip** :
- ngrok en production (coûteux, URL instable)
- Self-host VPS sauf si vous êtes sysadmin
- Docker local sauf besoin spécifique

---

**Ready to deploy ?** See `RAILWAY_DEPLOY.md` for step-by-step.
