# VIDA 0.9.30 (Beta) — Notas de la versión

**Build:** `0.9.30+25`  
**Web:** https://vida-86307.web.app

---

## En esta versión

- **Fix notificaciones**: el icono `@drawable/ic_stat_vida` se eliminaba en release (resource shrinker) → init fallaba y ningún aviso funcionaba
- Keep del drawable + fallback a `@mipmap/ic_launcher`
- Incluye **0.9.29** (versículo en la notificación + diagnóstico)
