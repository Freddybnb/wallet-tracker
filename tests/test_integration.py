#!/usr/bin/env python3
"""
Integration test — vérifie que tout le pipeline fonctionne.
Exécutez après installation : python -m tests.test_integration
"""
import asyncio
import sys
from pathlib import Path

# Add project to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from database import init_db, get_session, DBCrud
from monitor import WalletMonitor
from config import settings


async def main():
    print("🧪 Solana Wallet Tracker — Integration Test\n")
    print(f"   DB: {settings.database_url}")
    print(f"   Default min_amount: {settings.default_min_amount} SOL\n")

    # 1. Init DB
    print("[1/5] Initialisation base...")
    await init_db()
    print("   ✅\n")

    # 2. Create session + monitor
    print("[2/5] Création monitor...")
    session = await get_session().__anext__()
    monitor = WalletMonitor(DBCrud(session))
    print("   ✅\n")

    # 3. Add watch config
    print("[3/5] Ajout wallet de test...")
    TEST_WALLET = "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU"
    await monitor.db.add_watch_config(TEST_WALLET, 0.5)
    print(f"   ✅ {TEST_WALLET} avec seuil 0.5 SOL\n")

    # 4. Simulate a big transfer (should trigger)
    print("[4/5] Test transfer 5 SOL...")
    big_tx = {
        "signature": "5_test_big_transfer_11111111111111111111111111111111111",
        "instructions": [
            {
                "programId": "11111111111111111111111111111111",
                "parsed": {
                    "type": "transfer",
                    "info": {
                        "source": TEST_WALLET,
                        "destination": "DEST_BIG_2222222222222222222222222222222222",
                        "lamports": 5_000_000_000,
                    },
                },
            }
        ],
    }
    events = await monitor.process_transaction(big_tx)
    assert len(events) == 1, f"Expected 1 event, got {len(events)}"
    assert events[0]["amount_sol"] == 5.0
    print("   ✅ 5 SOL → ALERTE + dest wallet sauvé\n")

    # 5. Simulate small transfer (should be ignored)
    print("[5/5] Test transfer 0.01 SOL...")
    small_tx = {
        "signature": "5_test_small_3333333333333333333333333333333333333333",
        "instructions": [
            {
                "programId": "11111111111111111111111111111111",
                "parsed": {
                    "type": "transfer",
                    "info": {
                        "source": TEST_WALLET,
                        "destination": "DEST_SMALL_33333333333333333333333333333",
                        "lamports": 10_000_000,
                    },
                },
            }
        ],
    }
    events = await monitor.process_transaction(small_tx)
    assert len(events) == 0, f"Expected 0 events (ignored), got {len(events)}"
    print("   ✅ 0.01 SOL < seuil → ignoré\n")

    # Stats
    stats = await monitor.db.get_stats()
    print("📊 Statistiques finales :")
    print(f"   • Transactions traitées : {stats['total_transactions']}")
    print(f"   • Wallets surveillés    : {stats['watched_wallets']}")
    print(f"   • Wallets trackés       : {stats['tracked_dest_wallets']}")
    print()

    # Verify tracked wallets
    tracked = await monitor.db.get_all_tracked_wallets()
    print("🎯 Wallets destinataires enregistrés :")
    for t in tracked:
        print(f"   • {t.wallet_address[:20]}... ({t.amount_sol} SOL) depuis {t.source_wallet[:8]}...")

    print()
    print("=" * 50)
    print("✅ Tous les tests sont passés !")
    print("=" * 50)
    print()
    print("Prochaines étapes :")
    print("  1. Lancez le serveur : ./scripts/start.sh")
    print("  2. Configurez Helius webhook (ngrok si besoin)")
    print("  3. Ajoutez vos wallets via API")
    print()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except AssertionError as e:
        print(f"\n❌ TEST ÉCHOUÉ : {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERREUR : {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
