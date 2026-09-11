# Herramientas de datos VIDA

## Regenerar iglesias (México, protestantes/evangélicas)

1. Consulta Overpass (ya en `overpass_raw.json` si existe).
2. Regenera el asset:

```bash
python tool/rebuild_iglesias_json.py
```

El resultado va a `assets/data/iglesias_mexico.json`.
La app lo sube a Firestore la primera vez que abres el mapa (`IglesiaSeedService`).

## Versículos del día

Edita / reemplaza `assets/data/daily_verses.json`:

```json
[
  { "referencia": "Juan 3:16", "versiculo": "…" }
]
```

También acepta claves `reference` / `text`.
