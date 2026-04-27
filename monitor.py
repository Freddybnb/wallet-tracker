"""
Monitor — Traitement métier des transactions Helius.
Parse les instructions, détecte les transfers SOL, applique les filtres,
notifie, et met à jour la base.
"""
import json
import logging
from datetime import datetime
from typing import List, Optional

from sqlalchemy import select

from database import DBCrud, TrackedWallet, WatchConfig
from config import settings

logger = logging.getLogger(__name__)

# Program IDs Solana constants
SOL_TRANSFER_PROGRAM = "11111111111111111111111111111111"
SPL_TOKEN_PROGRAM = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"


class HeliusTransactionParser:
    """Parse les transactions Helius pour extraire les transferts SOL."""

    @staticmethod
    def parse(transaction: dict, watched_wallets: set[str]) -> List[dict]:
        """
        Extract SOL transfers FROM a watched wallet.

        Returns list of events:
            {
                "type": "sol_transfer",
                "txid": "...",
                "from_wallet": "...",
                "to_wallet": "...",
                "amount_sol": 123.45
            }
        """
        events = []
        signature = transaction.get("signature", "")
        instructions = transaction.get("instructions", [])

        for instr in instructions:
            parsed = instr.get("parsed", {})
            if not parsed:
                continue  # Skip raw/unparsed instructions

            program_id = instr.get("programId", "")
            instr_type = parsed.get("type", "")
            info = parsed.get("info", {})

            # Détection transfert SOL
            if program_id == SOL_TRANSFER_PROGRAM and instr_type == "transfer":
                source = info.get("source", "")
                destination = info.get("destination", "")
                lamports = info.get("lamports", 0)

                if source in watched_wallets:
                    amount_sol = lamports / 1_000_000_000
                    events.append({
                        "type": "sol_transfer",
                        "txid": signature,
                        "from_wallet": source,
                        "to_wallet": destination,
                        "amount_sol": amount_sol,
                    })

        return events


class WalletMonitor:
    """Orchestre la réception, filtrage et persistance des transactions."""

    def __init__(self, db_crud: DBCrud):
        self.db = db_crud

    async def reload_watchlist(self) -> set[str]:
        """Return the current set of watched wallet addresses."""
        configs = await self.db.session.execute(select(WatchConfig).where(WatchConfig.enabled == True))
        return {cfg.wallet_address for cfg in configs.scalars().all()}

    async def process_transaction(self, tx: dict) -> List[dict]:
        """
        Traite une transaction Helius complète.

        Returns list of triggered events (filtrage amount appliqué).
        """
        txid = tx.get("signature", "")
        if not txid:
            logger.warning("Transaction sans signature — ignorée")
            return []

        # 1. Idempotence check
        if await self.db.is_tx_processed(txid):
            logger.debug(f"Tx {txid[:8]}... déjà traitée — skip")
            return []

        # 2. Parse (besoin de la watchlist pour savoir quels wallets intéresse)
        watched = await self.reload_watchlist()
        parser = HeliusTransactionParser()
        events = parser.parse(tx, watched)

        if not events:
            # Still mark as processed to avoid re-parsing useless tx
            await self.db.mark_tx_processed(
                txid=txid,
                wallet_address="unknown",
                tx_type="unknown",
                amount_sol=0.0,
                raw_data=json.dumps(tx),
            )
            return []

        # 3. Process each event — check thresholds, save dest wallet, notify
        triggered = []
        for ev in events:
            from_wallet = ev["from_wallet"]
            to_wallet = ev["to_wallet"]
            amount_sol = ev["amount_sol"]

            # Get threshold for this source wallet
            cfg = await self.db.session.execute(
                select(WatchConfig).where(WatchConfig.wallet_address == from_wallet)
            )
            watch_cfg = cfg.scalar_one_or_none()
            threshold = watch_cfg.min_amount_sol if watch_cfg else settings.default_min_amount

            # Store transaction in DB (deduplication)
            await self.db.mark_tx_processed(
                txid=txid,
                wallet_address=from_wallet,
                tx_type="sol_transfer",
                amount_sol=amount_sol,
                raw_data=json.dumps(tx),
            )

            # Check threshold
            if amount_sol < threshold:
                logger.info(f"Tx {txid[:8]}... {amount_sol:.4f} SOL < seuil {threshold} → ignorée")
                continue

            # SUCCESS — event triggered
            triggered.append(ev)
            logger.info(f"🔔 ALERTE : {from_wallet[:8]}... → {to_wallet[:8]}... | {amount_sol:.4f} SOL")

            # Auto-save destination wallet (si nouveau)
            saved_tw = await self.db.add_tracked_wallet(
                wallet_address=to_wallet,
                source_wallet=from_wallet,
                source_txid=txid,
                amount_sol=amount_sol,
            )
            if saved_tw:
                logger.info(f"   🆕 Wallet dest ajouté à la DB : {to_wallet[:8]}...")

        return triggered

    async def get_recent_events(self, limit: int = 20) -> List[dict]:
        """Fetch recent processed transactions for UI / logs."""
        result = await self.db.session.execute(
            select(ProcessedTransaction)
            .where(ProcessedTransaction.type == "sol_transfer")
            .order_by(ProcessedTransaction.processed_at.desc())
            .limit(limit)
        )
        return [{
            "txid": p.txid,
            "wallet": p.wallet_address,
            "amount_sol": p.amount_sol,
            "time": p.processed_at.isoformat() if p.processed_at else None,
        } for p in result.scalars().all()]
