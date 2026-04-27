# Polling vs Webhook — Alternatives

Votre script original utilise le **polling** (boucle while + `time.sleep`). Voici une comparaison avec la version webhook.

## 📊 Comparatif

| Critère | Polling (votre script) | Webhook (cette implémentation) |
|---------|------------------------|--------------------------------|
| Latence | 10–30s (selon intervalle) | < 1s (instantané) |
| Rate limits Helius | 1 req/10s = 8640/jour → 260k/mois (dépassement risque) | 0 req polling → uniquement webhooks reçus (gratuit illimité) |
| Complexité | Simple, pas de serveur | Requiert HTTPS (ngrok en dev) |
| Coût | API calls = facturation rapidité | Webhook = inclus dans forfait Helius |
| Évolutivité | 1 wallet à la fois | 1000+ wallets simultanés |
| Fiabilité | Peut manquer tx si rate limit | Livraison garantie (retry Helius) |
| Persistance | JSON fichier, pas de dédup | SQLite + PK = idempotent |

## 🎯 Pourquoi choisir Webhook ?

- **Temps réel** pas de latence polling
- **Économie de rate limits** Helius
- **Multi-wallet** — surveillez 10, 100, 1000 wallets d'un coup
- **Robustesse** — pas de boucle while à gérer
- **Production-ready** — scalable et fiable

## ⚠️ Inconvénients du webhook

- Nécessite **HTTPS** (ngrok en dev, coût $ pour URL fixe)
- Un peu plus de setup initial
- Dépend d'un serveur toujours up

## 🔄 Hybrid approach (futur)

Vous pourriez combiner les deux :

```python
async def hybrid_monitor():
    # Primaires: webhook (temps réel)
    # Fallback: polling si webhook down depuis > 5min
    if webhook_healthy():
        await webhook_receiver()
    else:
        await polling_fallback()
```

---

**Recommandation** : Utilisez la version webhook pour toute surveillance sérieuse.
