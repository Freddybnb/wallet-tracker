# 🧠 Architecture — Mind Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SOLANA WALLET TRACKER (Webhook)                 │
│                     Architecture — Version 1.0                     │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  EXTERNE — Helius Network                                            │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  • Solana Mainnet RPC                                             ││
│  │  • Webhook Service (envoie POST when tx detected)                ││
│  │  • Payload format: {"transactions": [{...}]}                     ││
│  └────────────────────────┬─────────────────────────────────────────┘│
│                           │ HTTPS POST (requires valid cert)         │
│                           ↓                                          │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  3 modes d'exposition :                                          ││
│  │    a) Ngrok tunnel (dev local) → https://xyz.ngrok.io/webhook   ││
│  │    b) Cloud (Railway / Fly.io) → https://your-app.web.app       ││
│  │    c) VPS + Nginx + Certbot → https://your-domain.com/webhook   ││
│  └──────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  SERVEUR — FastAPI App (server.py)                                  │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  GET  /                 → Health check                          ││
│  │  GET  /wallets          → Liste watch_configs                   ││
│  │  POST /wallets          → Ajouter wallet + seuil                ││
│  │  DEL  /wallets/{addr}   → Supprimer wallet                      ││
│  │  GET  /tracked          → Wallets dest auto-découverts          ││
│  │  GET  /stats            → Statistiques globales                 ││
│  │  GET  /recent           → Dernières transactions                ││
│  │  POST /webhook          ← Helius POST (secret required)         ││
│  │  POST /simulate-webhook → Tests locaux (pas de secret)          ││
│  └─────────────────────────┬───────────────────────────────────────┘│
│                            │ Depends: get_monitor()                 │
│                            ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Security:                                                     ││
│  │    • X-Webhook-Secret header validation                        ││
│  │    • (Future) API key auth for /wallets                        ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (spawn background task)
┌─────────────────────────────────────────────────────────────────────┐
│  BUSINESS LOGIC — WalletMonitor (monitor.py)                       │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  process_transaction(tx):                                       ││
│  │    1. is_tx_processed(txid)? → skip if duplicate                ││
│  │    2. Parse instructions (HeliusTransactionParser):             ││
│  │       - programId == SOL_TRANSFER_PROGRAM (111...11)           ││
│  │       - type == 'transfer'                                      ││
│  │       - source ∈ watch_configs (set)                            ││
│  │       → extract: to_wallet, lamports, amount_sol                ││
│  │    3. Get threshold for this source wallet                      ││
│  │    4. If amount_sol ≥ threshold:                                ││
│  │         • Log ALERTE                                            ││
│  │         • add_tracked_wallet(dest, source, txid, amount)       ││
│  │    5. mark_tx_processed(txid, ...) — idempotent                 ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  HeliusTransactionParser:                                           │
│    parse(tx, watched_wallets_set) → List[event_dict]              │
│                                                                     │
│  DBCrud (async session wrapper):                                    │
│    • add_watch_config(address, min_amount)                         ││
│    • get_all_watch_configs() → set[str]                            ││
│    • add_tracked_wallet(...) — UNIQUE constraint                   ││
│    • is_tx_processed(txid) → bool                                  ││
│    • mark_tx_processed(...) — INSERT OR IGNORE                     ││
│    • get_stats() → dict                                            │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  DATABASE — SQLite (async) (database.py)                           │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  SQLAlchemy 2.0 async + aiosqlite                               ││
│  │                                                                  ││
│  │  Tables:                                                        ││
│  │    watch_configs       ← Wallets que VOUS suivez               ││
│  │    tracked_wallets     ← Wallets dest auto-découverts           ││
│  │    processed_transactions ← Deduplication (txid PK)             ││
│  │                                                                  ││
│  │  Path: ./data/wallet_tracker.db                                 ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                     │
│  Schemas SQL:                                                      │
│    CREATE TABLE watch_configs (                                    │
│      id INTEGER PRIMARY KEY,                                       │
│      wallet_address TEXT UNIQUE,                                   │
│      min_amount_sol REAL DEFAULT 0.0,                              │
│      enabled BOOLEAN DEFAULT 1,                                    │
│      created_at TIMESTAMP                                          │
│    );                                                              │
│                                                                     │
│    CREATE TABLE tracked_wallets (                                  │
│      id INTEGER PRIMARY KEY,                                       │
│      wallet_address TEXT UNIQUE,                                   │
│      source_wallet TEXT,                                           │
│      source_txid TEXT,                                             │
│      amount_sol REAL,                                              │
│      first_seen_at TIMESTAMP                                       │
│    );                                                              │
│                                                                     │
│    CREATE TABLE processed_transactions (                           │
│      txid TEXT PRIMARY KEY,                                        │
│      wallet_address TEXT,                                          │
│      type TEXT,                                                    │
│      amount_sol REAL,                                              │
│      contract_address TEXT,                                        │
│      raw_data TEXT,                                                │
│      processed_at TIMESTAMP                                        │
│    );                                                              │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CONFIGURATION — Pydantic Settings (config.py)                     │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  Charge .env (dotenv)                                           ││
│  │  Valide avec pydantic:                                          ││
│  │    • HELIUS_API_KEY  (required)                                ││
│  │    • WEBHOOK_SECRET  (32 hex chars)                             ││
│  │    • PORT (1024-65535)                                          ││
│  │    • DATABASE_URL (SQLAlchemy URL)                              ││
│  │    • DEFAULT_MIN_AMOUNT (float)                                 ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  SCRIPTS TERMUX (scripts/)                                         │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  install.sh — pip, venv, init DB                               ││
│  │  start.sh   — uvicorn en bg, logs/                              ││
│  │  stop.sh    — kill propre                                       ││
│  │  restart.sh — stop + start                                      ││
│  │  check.sh   — vérif health (files, processes, port)            ││
│  │  test.sh    — mock webhook via simulate endpoint               ││
│  │  logs.sh    — viewer interactif (tail, grep, stats)            ││
│  │  ngrok.sh   — start HTTPS tunnel (optionnel)                   ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow (Une transaction)

```
Helius POST /webhook
    ↓
server.py: verif secret
    ↓ background task
monitor.py: process_transaction(tx)
    ├─→ is_tx_processed? [DB: SELECT * FROM processed_transactions WHERE txid=?]
    │   └─ Yes → return [] (skip)
    │   └─ No  → continue
    │
    ├─→ parse instructions
    │   └─→ Loop instr:
    │       • programId=111...11 && type=transfer?
    │       • source ∈ watch_configs?
    │       → event = {from, to, amount_sol}
    │
    ├─→ threshold check: amount_sol ≥ cfg.min_amount_sol?
    │   └─ No → mark_tx_processed → return []
    │   └─ Yes → continue
    │
    ├─→ mark_tx_processed()
    │   └─→ INSERT INTO processed_transactions (txid, ...) ON CONFLICT DO NOTHING
    │
    ├─→ add_tracked_wallet(dest, source, txid, amount)
    │   └─→ INSERT INTO tracked_wallets UNIQUE(wallet_address) IGNORE
    │
    └─→ return [events] → log "🔔 ALERTE"
```

## 🧩 Core Functions Map

| Function | File | Ligne | Purpose |
|----------|------|-------|---------|
| `init_db()` | database.py | 96 | Create tables |
| `get_session()` | database.py | 112 | AsyncSession factory |
| `DBCrud.add_watch_config()` | database.py | 136 | Insert wallet |
| `DBCrud.add_tracked_wallet()` | database.py | 157 | Insert dest (unique) |
| `DBCrud.is_tx_processed()` | database.py | 172 | Dedup check |
| `DBCrud.mark_tx_processed()` | database.py | 183 | Save tx history |
| `HeliusTransactionParser.parse()` | monitor.py | 37 | Extract events |
| `WalletMonitor.process_transaction()` | monitor.py | 89 | Full pipeline |
| `server.helius_webhook()` | server.py | 123 | Webhook endpoint |
| `server.simulate_webhook()` | server.py | 202 | Test endpoint |

## 📊 SQL Indexes

```sql
-- Performance indexes
CREATE INDEX idx_watch_enabled    ON watch_configs(enabled);
CREATE INDEX idx_tracked_wallet   ON tracked_wallets(wallet_address);
CREATE INDEX idx_processed_wallet ON processed_transactions(wallet_address);
CREATE INDEX idx_processed_time   ON processed_transactions(processed_at DESC);
```

Ces indexes sont créés automatiquement par SQLAlchemy via `Index()` (à ajouter si volumétrie importante).

---

**Legend**: ──│▼→✅
