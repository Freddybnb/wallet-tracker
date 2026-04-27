"""
Database module — SQLite async via SQLAlchemy 2.0 + aiosqlite.
3 tables: watch_configs, tracked_wallets, processed_transactions.
"""
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, Text,
    UniqueConstraint, PrimaryKeyConstraint, create_engine, select, func
)
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base

from config import settings

# ─── Ensure data directory exists ────────────────────────────────────
DB_PATH = Path("data")
DB_PATH.mkdir(exist_ok=True)

# ─── Async engine & session factory ─────────────────────────────────
# DATABASE_URL format: sqlite+aiosqlite:///./data/wallet_tracker.db
engine = create_async_engine(
    settings.database_url,
    echo=False,  # True = log SQL queries (debug)
    future=True,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)

Base = declarative_base()


# ─── SQLAlchemy Models ────────────────────────────────────────────────
class WatchConfig(Base):
    """Wallets that you manually watch with a threshold."""
    __tablename__ = "watch_configs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    wallet_address = Column(String, unique=True, nullable=False, index=True)
    min_amount_sol = Column(Float, default=0.0, nullable=False)
    enabled = Column(Boolean, default=True, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class TrackedWallet(Base):
    """Wallets that received funds from a watched wallet — auto-discovered."""
    __tablename__ = "tracked_wallets"

    id = Column(Integer, primary_key=True, autoincrement=True)
    wallet_address = Column(String, unique=True, nullable=False, index=True)
    source_wallet = Column(String, nullable=False)          # who sent
    source_txid = Column(String, nullable=False)            # proof tx
    amount_sol = Column(Float, nullable=False)              # amount received
    first_seen_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ProcessedTransaction(Base):
    """Deduplication store — each txid only once."""
    __tablename__ = "processed_transactions"

    txid = Column(String, primary_key=True, nullable=False)
    wallet_address = Column(String, nullable=False, index=True)
    type = Column(String, nullable=False)                   # 'transfer'
    amount_sol = Column(Float, nullable=False)
    contract_address = Column(String, nullable=True)        # null for transfers
    raw_data = Column(Text, nullable=True)                  # JSON payload
    processed_at = Column(DateTime, default=datetime.utcnow, nullable=False)


# ─── Init / Migration ─────────────────────────────────────────────────
async def init_db() -> None:
    """Create all tables if they don't exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print(f"✅ Database initialised at {settings.database_url}")


async def drop_all() -> None:
    """DANGER — drop all tables."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    print("⚠️  All tables dropped.")


# ─── Session context manager ───────────────────────────────────────────
async def get_session() -> AsyncSession:
    """Dependency for FastAPI routes."""
    async with AsyncSessionLocal() as session:
        yield session


# ─── CRUD Helpers ─────────────────────────────────────────────────────
class DBCrud:
    """Encapsulated DB operations (for use in monitor.py)."""

    def __init__(self, session: AsyncSession):
        self.session = session

    # --- watch_configs ---
    async def add_watch_config(self, address: str, min_amount: float) -> WatchConfig:
        cfg = WatchConfig(wallet_address=address, min_amount_sol=min_amount)
        self.session.add(cfg)
        await self.session.commit()
        await self.session.refresh(cfg)
        return cfg

    async def get_all_watch_configs(self) -> list[WatchConfig]:
        result = await self.session.execute(select(WatchConfig).where(WatchConfig.enabled == True))
        return result.scalars().all()

    async def remove_watch_config(self, address: str) -> bool:
        result = await self.session.execute(
            select(WatchConfig).where(WatchConfig.wallet_address == address)
        )
        cfg = result.scalar_one_or_none()
        if cfg:
            await self.session.delete(cfg)
            await self.session.commit()
            return True
        return False

    # --- tracked_wallets ---
    async def add_tracked_wallet(
        self,
        wallet_address: str,
        source_wallet: str,
        source_txid: str,
        amount_sol: float
    ) -> Optional[TrackedWallet]:
        """Insert if not exists (unique constraint on wallet_address)."""
        existing = await self.session.execute(
            select(TrackedWallet).where(TrackedWallet.wallet_address == wallet_address)
        )
        if existing.scalar_one_or_none():
            return None  # Already tracked

        tw = TrackedWallet(
            wallet_address=wallet_address,
            source_wallet=source_wallet,
            source_txid=source_txid,
            amount_sol=amount_sol,
        )
        self.session.add(tw)
        await self.session.commit()
        await self.session.refresh(tw)
        return tw

    async def get_all_tracked_wallets(self) -> list[TrackedWallet]:
        result = await self.session.execute(select(TrackedWallet))
        return result.scalars().all()

    # --- processed_transactions ---
    async def is_tx_processed(self, txid: str) -> bool:
        result = await self.session.execute(
            select(ProcessedTransaction).where(ProcessedTransaction.txid == txid)
        )
        return result.scalar_one_or_none() is not None

    async def mark_tx_processed(
        self,
        txid: str,
        wallet_address: str,
        tx_type: str,
        amount_sol: float,
        contract_address: Optional[str] = None,
        raw_data: Optional[str] = None
    ) -> None:
        """Insert txid — ignore if duplicate (PRIMARY KEY)."""
        pt = ProcessedTransaction(
            txid=txid,
            wallet_address=wallet_address,
            type=tx_type,
            amount_sol=amount_sol,
            contract_address=contract_address,
            raw_data=raw_data,
        )
        self.session.add(pt)
        # Use try/except for race condition (rare)
        try:
            await self.session.commit()
        except Exception:
            # Already exists — silently ignore (idempotent)
            await self.session.rollback()

    async def get_stats(self) -> dict:
        """Quick stats for /stats endpoint."""
        tx_count = await self.session.execute(select(func.count(ProcessedTransaction.txid)))
        watch_count = await self.session.execute(select(func.count(WatchConfig.id)).where(WatchConfig.enabled == True))
        tracked_count = await self.session.execute(select(func.count(TrackedWallet.id)))
        return {
            "total_transactions": tx_count.scalar() or 0,
            "watched_wallets": watch_count.scalar() or 0,
            "tracked_dest_wallets": tracked_count.scalar() or 0,
        }
