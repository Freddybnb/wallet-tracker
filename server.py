"""
Server — FastAPI application.
Endpoints webhook Helius + API de gestion.
"""
import asyncio
import json
import logging
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, Depends, HTTPException, Header, Request, BackgroundTasks
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from database import (
    init_db, get_session, WatchConfig, TrackedWallet,
    ProcessedTransaction, DBCrud
)
from monitor import WalletMonitor

# ─── Logging config ────────────────────────────────────────────────────
logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("server")

# ─── FastAPI app ───────────────────────────────────────────────────────
app = FastAPI(
    title="Solana Wallet Tracker — Webhook Edition",
    description="Surveillance temps réel des transferts SOL via Helius webhooks.",
    version="1.0.0",
)

# Global monitor instance (initialisé au startup)
monitor: Optional[WalletMonitor] = None


# ─── Startup / Shutdown ───────────────────────────────────────────────
@app.on_event("startup")
async def startup_event():
    """Initialise DB + monitor au démarrage."""
    global monitor
    await init_db()
    # Créer une session partagée (simple — pour le MVP)
    session = await get_session().__anext__()
    monitor = WalletMonitor(DBCrud(session))
    logger.info("🚀 Server started — webhook ready")


@app.on_event("shutdown")
async def shutdown_event():
    """Ferme la DB proprement."""
    pass


# ─── Helpers ───────────────────────────────────────────────────────────
async def get_monitor() -> WalletMonitor:
    """Dependency injection du monitor."""
    if monitor is None:
        raise HTTPException(500, "Monitor not initialised")
    return monitor


def verify_webhook_secret(x_webhook_secret: Optional[str] = Header(None)) -> bool:
    """Valide le secret Helius (X-Webhook-Secret header)."""
    if not x_webhook_secret:
        raise HTTPException(401, "Missing X-Webhook-Secret header")
    if x_webhook_secret != settings.webhook_secret:
        raise HTTPException(401, "Invalid webhook secret")
    return True


# ─── Routes: Health / Info ────────────────────────────────────────────
@app.get("/")
async def root():
    """Health check."""
    return {
        "service": "Solana Wallet Tracker",
        "status": "online",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.get("/stats")
async def stats(monitor: WalletMonitor = Depends(get_monitor)):
    """Statistiques globales."""
    s = await monitor.db.get_stats()
    s["uptime"] = datetime.utcnow().isoformat()
    return s


# ─── Routes: Wallets management ────────────────────────────────────────
@app.get("/wallets")
async def list_wallets(monitor: WalletMonitor = Depends(get_monitor)):
    """Liste des wallets configurés (watch_configs)."""
    configs = await monitor.db.session.execute(select(WatchConfig))
    return [{
        "address": c.wallet_address,
        "min_amount_sol": c.min_amount_sol,
        "enabled": c.enabled,
        "created_at": c.created_at.isoformat() if c.created_at else None,
    } for c in configs.scalars().all()]


@app.post("/wallets")
async def add_wallet(
    payload: dict,
    monitor: WalletMonitor = Depends(get_monitor)
):
    """Ajoute un wallet à surveiller.

    Body: {"address": "wallet_address", "min_amount": 0.5}
    """
    address = payload.get("address")
    min_amount = payload.get("min_amount", settings.default_min_amount)

    if not address:
        raise HTTPException(400, "address required")

    # Basic validation (Solana address ~ 44 chars base58)
    if len(address) < 32:
        raise HTTPException(400, "Invalid wallet address length")

    try:
        cfg = await monitor.db.add_watch_config(address, float(min_amount))
        return {
            "status": "ok",
            "wallet": cfg.wallet_address,
            "min_amount_sol": cfg.min_amount_sol,
        }
    except Exception as e:
        raise HTTPException(500, f"DB error: {e}")


@app.delete("/wallets/{address}")
async def remove_wallet(
    address: str,
    monitor: WalletMonitor = Depends(get_monitor)
):
    """Supprime un wallet de la watchlist."""
    ok = await monitor.db.remove_watch_config(address)
    if not ok:
        raise HTTPException(404, "Wallet not found")
    return {"status": "removed", "address": address}


# ─── Routes: Tracked wallets (destinataires auto-découverts) ───────────
@app.get("/tracked")
async def list_tracked(monitor: WalletMonitor = Depends(get_monitor)):
    """Wallets destinataires enregistrés automatiquement."""
    tracked = await monitor.db.get_all_tracked_wallets()
    return [{
        "wallet_address": t.wallet_address,
        "source_wallet": t.source_wallet,
        "source_txid": t.source_txid,
        "amount_sol": t.amount_sol,
        "first_seen_at": t.first_seen_at.isoformat() if t.first_seen_at else None,
    } for t in tracked]


# ─── Routes: Webhook Helius ────────────────────────────────────────────
@app.post("/webhook")
async def helius_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    monitor: WalletMonitor = Depends(get_monitor),
    verified: bool = Depends(verify_webhook_secret),
):
    """
    Endpoint webhook Helius.

    Helius envoie un payload JSON:
    {
      "transactions": [ {...}, ... ]
    }

    Traitement asynchrone dans une tâche background.
    """
    try:
        body = await request.json()
    except json.JSONDecodeError:
        raise HTTPException(400, "Invalid JSON")

    transactions = body.get("transactions", [])
    if not transactions:
        return {"status": "no_transactions"}

    # Log rapide
    logger.info(f"📥 Webhook reçu — {len(transactions)} transaction(s)")

    # Lancement traitement async (fire-and-forget avec réponse immédiate)
    background_tasks.add_task(process_webhook_batch, transactions, monitor)

    return {
        "status": "accepted",
        "received": len(transactions),
        "timestamp": datetime.utcnow().isoformat(),
    }


async def process_webhook_batch(transactions: list, monitor: WalletMonitor):
    """Tâche background — traite chaque tx."""
    for tx in transactions:
        try:
            events = await monitor.process_transaction(tx)
            if events:
                # Ici, pourrait ajouter : Telegram, email, etc.
                pass
        except Exception as e:
            logger.error(f"Erreur traitement tx {tx.get('signature','?')[:8]}... : {e}")


# ─── Routes: Simulation (tests locaux sans Helius) ─────────────────────
@app.post("/simulate-webhook")
async def simulate_webhook(
    payload: dict,
    monitor: WalletMonitor = Depends(get_monitor),
):
    """
    Endpoint de test — simule un webhook Helius en local.
    Utile pour tester sans HTTPS (pas besoin d'ngrok).

    Body: {"transactions": [tx_object_helius, ...]}
    """
    transactions = payload.get("transactions", [])
    results = []

    for tx in transactions:
        events = await monitor.process_transaction(tx)
        results.append({
            "signature": tx.get("signature", "unknown"),
            "events_count": len(events),
        })

    return {
        "status": "simulated",
        "total": len(transactions),
        "results": results,
    }


# ─── Routes: Recent events (pour UI/dev) ───────────────────────────────
@app.get("/recent")
async def recent_events(limit: int = 20, monitor: WalletMonitor = Depends(get_monitor)):
    """Récupère les X dernières transactions traitées."""
    return await monitor.get_recent_events(limit)


# ─── Error handlers ────────────────────────────────────────────────────
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.detail, "path": request.url.path},
    )


# ─── CLI entrypoint ─────────────────────────────────────────────────────
def cli():
    """Lancement direct : python server.py"""
    import uvicorn
    uvicorn.run(
        "server:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level=settings.log_level.lower(),
    )


if __name__ == "__main__":
    cli()
