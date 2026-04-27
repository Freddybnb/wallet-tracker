# Solana Wallet Tracker — Project Structure

## 📁 Arborescence

```
solana_webhook_tracker/
├── server.py                 # FastAPI app — webhook receiver + API
├── database.py               # SQLAlchemy ORM models + async CRUD
├── monitor.py                # Transaction parser + business logic
├── config.py                 # Pydantic settings (env vars)
├── requirements.txt          # Python dependencies
├── .env.example              # Template config
├── .env                      # YOUR secrets (not committed)
├── README.md                 # Documentation principale
├── QUICKSTART.md             # 5-min setup guide
├── UTILISATION.md            # 10 scénarios pratiques
├── MINDMAP.md                # Architecture ASCII
├── data/
│   ├── wallet_tracker.db     # SQLite database (created)
│   └── server.pid            # PID du serveur (auto)
├── logs/
│   └── server.log            # Rotating logs (créé)
├── scripts/
│   ├── install.sh            # Full setup (venv, pip, init)
│   ├── start.sh              # Start server (bg)
│   ├── stop.sh               # Stop server
│   ├── restart.sh            # Stop + start
│   ├── check.sh              # Health verification
│   ├── test.sh               # Mock webhook tests
│   ├── logs.sh               # Interactive log viewer
│   └── ngrok.sh              # HTTPS tunnel (optional)
└── tests/
    ├── mock_transfer_5sol.json    # Helius payload example
    └── mock_transfer_0.01sol.json # < threshold
```

## 🔗 Dependency Flow

```
server.py (FastAPI)
    ↓ uses
monitor.py (WalletMonitor)
    ↓ uses
database.py (DBCrud, SQLAlchemy models)
    ↓ uses
config.py (Settings)

FastAPI Depends(get_monitor) → injects monitor instance
```

## 🗄️ Database Schema

```sql
-- Wallets you manually configure
watch_configs (
    id INTEGER PRIMARY KEY,
    wallet_address TEXT UNIQUE,
    min_amount_sol REAL DEFAULT 0.0,
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP
)

-- Auto-discovered destination wallets
tracked_wallets (
    id INTEGER PRIMARY KEY,
    wallet_address TEXT UNIQUE,
    source_wallet TEXT,
    source_txid TEXT,
    amount_sol REAL,
    first_seen_at TIMESTAMP
)

-- Processed transactions (deduplication)
processed_transactions (
    txid TEXT PRIMARY KEY,
    wallet_address TEXT,
    type TEXT,
    amount_sol REAL,
    contract_address TEXT,
    raw_data TEXT,
    processed_at TIMESTAMP
)
```

## 🔄 Request Lifecycle

1. **Helius** → POST `https://your-ngrok.io/webhook`
   - Header: `X-Webhook-Secret: <secret>`
   - Body: `{"transactions": [...]}`

2. **server.py** `/webhook` route:
   - Verify secret
   - Spawn background task
   - Return `202 accepted` immediately

3. **monitor.py** `process_transaction()`:
   - Idempotence check (`processed_transactions`)
   - Parse instructions (HeliusTransactionParser)
   - For each transfer FROM a watched wallet:
     - Compare amount to `min_amount_sol`
     - If ≥ threshold: log alert, save dest wallet
   - Mark tx as processed

4. **Response** to user:
   - Console log: `🔔 ALERTE : ...`
   - DB updated
   - Endpoints available: `/wallets`, `/tracked`, `/stats`

## 🧪 Testing Flow

```
scripts/test.sh
    ↓
HTTP POST /simulate-webhook (mock payloads)
    ↓
server.process_transaction()
    ↓
DB updates (check with sqlite3)
    ↓
curl /tracked → verify dest wallet saved
```

## ⚙️ Configuration Layers

| Layer | File | Purpose |
|-------|------|---------|
| Defaults | `config.py` | Hardcoded fallback values |
| Env vars | `.env` | Per-deployment overrides |
| Runtime | CLI args | `python server.py --port 9000` (future) |

Priority: CLI args → Env vars → Defaults

## 📦 Dependencies

```
FastAPI      → Web framework (async)
uvicorn      → ASGI server
SQLAlchemy   → ORM + async engine
aiosqlite    → SQLite async driver
pydantic     → Settings + validation
python-dotenv → .env loader
httpx        → Future: external API calls
requests     → Debug / utils
```

No Rust compiled deps (pure Python stack) → Termux-friendly.

## 🚀 Deployment Options

| Target | Script | Notes |
|--------|--------|-------|
| Termux (Android) | `./scripts/install.sh` + `./scripts/start.sh` | With tmux/screen recommended |
| Linux VPS | `systemd` service file (create) | Auto-restart on crash |
| Railway | `Procfile`: `python -m uvicorn server:app --host 0.0.0.0 --port $PORT` | Git push |
| Fly.io | `fly.toml` + `flyctl deploy` | Global regions |
| Docker | `Dockerfile` (future) | Multi-stage build |

## 🎯 Entry Points

| File | Purpose |
|------|---------|
| `server.py` | Main app (run with `python server.py` or `uvicorn`) |
| `database.py` | `init_db()` — create tables |
| `monitor.py` | `WalletMonitor` class — used by server only |

---

**Version**: 1.0.0 — Production-ready for transfer-only tracking.
