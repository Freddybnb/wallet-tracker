# ─── Railway Procfile ────────────────────────────────────────────────────
# Command: what to run
# Format: <process_type>: <command>

web: python -m uvicorn server:app --host 0.0.0.0 --port $PORT

# ─── Notes ───────────────────────────────────────────────────────────────
# Railway injecte automatiquement la variable d'environnement $PORT.
# Notre config.py lit PORT depuis .env ou env var, donc c'est bon.
# Uvicorn bind à 0.0.0.0 (requis par Railway).
#
# Pour un worker pool (plus de performance), vous pourriez utiliser :
# web: gunicorn -k uvicorn.workers.UvicornWorker server:app --bind 0.0.0.0:$PORT
# Mais uvicorn seul suffit pour ce workload léger.
#
# Le nom "web" est requis par Railway pour détecter le service web.
# Vous pouvez ajouter d'autres processus (worker, clock) si besoin.
