# 📋 Changelog — Solana Wallet Tracker

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-04-27

### ✨ Added — Initial release (Webhook Edition — Transfers only)

**Features:**
- Helius webhook receiver (FastAPI) — real-time transaction capture
- Filter by custom minimum SOL amount per wallet
- Auto-discovery & storage of destination wallets receiving funds
- Deduplication via `processed_transactions` table (idempotent)
- REST API for wallet management (add/list/remove)
- SQLite database — zero config, async via SQLAlchemy + aiosqlite
- `/simulate-webhook` endpoint for local testing without Helius
- Termux-optimized scripts (install, start, stop, restart, check, test, logs, ngrok)
- Settings management via Pydantic + .env file
- Mock payload examples for testing

**Documentation:**
- `README.md` — Full installation, Helius setup, API reference
- `QUICKSTART.md` — 5-minute setup guide
- `UTILISATION.md` — 10 common use-cases with examples
- `PROJECT_STRUCTURE.md` — File layout + schema
- `MINDMAP.md` — ASCII architecture diagram

**Database schema (3 tables):**
- `watch_configs` — manually configured wallets + thresholds
- `tracked_wallets` — auto-discovered destination wallets
- `processed_transactions` — deduplication store

**Scripts (Termux/Linux):**
- `install.sh` — venv, pip install, DB init
- `start.sh` — Launch uvicorn in background with logging
- `stop.sh` — Graceful shutdown with PID management
- `restart.sh` — Stop → start cycle
- `check.sh` — Health verification (files, process, port, Python deps)
- `test.sh` — Automated mock webhook tests (3 scenarios)
- `logs.sh` — Interactive log viewer (tail, grep, stats)
- `ngrok.sh` — HTTPS tunnel setup for Helius (optional)

**Security:**
- Webhook secret validation (`X-Webhook-Secret` header)
- Secrets stored in `.env` (not committed)
- SQL parameterized queries via ORM

**Testing:**
- Mock transaction payloads (5 SOL, 0.01 SOL)
- Integration test (`tests/test_integration.py`) — end-to-end pipeline validation

### 🔧 Technical Stack

- **Backend**: FastAPI 0.109, Uvicorn
- **Database**: SQLAlchemy 2.0 + aiosqlite (async)
- **Config**: Pydantic Settings + python-dotenv
- **Compatibility**: Termux Android, Linux x86_64
- **Python**: 3.11+ (no Rust compiled deps — pure Python stack)

### 📦 Dependencies

```
fastapi==0.109.0
uvicorn[standard]==0.27.0
sqlalchemy==2.0.25
aiosqlite==0.19.0
pydantic==2.5.3
pydantic-settings==2.1.0
python-dotenv==1.0.0
httpx==0.26.0
requests==2.31.0
```

---

## [Planned] — v1.1.0

### To-do (Future Enhancements)

- [ ] Telegram notifications (user configurable)
- [ ] CSV export endpoint (`/export?format=csv`)
- [ ] Dashboard UI (Streamlit or Gradio)
- [ ] Multiple threshold types: % change, frequency, whitelist/blacklist
- [ ] Support for token transfer events (SPL Token transfers)
- [ ] Historical re-sync from Helius API (fill missing data)
- [ ] PostgreSQL backend option (asyncpg)
- [ ] Dockerfile for cloud deployment
- [ ] Systemd service template
- [ ] Prometheus metrics endpoint (`/metrics`)
- [ ] Rate limiting middleware
- [ ] API key authentication for management endpoints

---

## [Unreleased] — Dev Branch

- Last dev commit: Initial scaffold

---

**Versioning**: MAJOR.MINOR.PATCH
- MAJOR = breaking changes (DB schema rewrite, API change)
- MINOR = new features (backward-compatible)
- PATCH = bug fixes, docs, no new features
