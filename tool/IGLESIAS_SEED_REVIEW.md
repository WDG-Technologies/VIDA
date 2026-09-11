# Revisión seed iglesias (0.9.21)

**Fuente:** `assets/data/iglesias_mexico.json` (OSM)  
**Tras limpieza:** ~412 lugares (antes 414)

## Hallazgos

| Check | Resultado |
|-------|-----------|
| Total / schema | Completo (`osm_id`, nombre, ciudad, coords, descripción) |
| `osm_id` duplicados | 0 |
| Coords duplicadas | 0 |
| Fuera de México (bbox) | 0 |
| Ciudad genérica «México» | ~308 (OSM sin ciudad clara; limitación de datos) |
| Posible católica «Catedral de Vida» | Pentecostal (OK, se deja) |

## Correcciones aplicadas

- Eliminados **Testigos de Jehová** (2)
- «Templo» / «Iglesia» genéricos → nombre según denominación OSM
- Ciudades en minúsculas → capitalizadas (p. ej. Comalcalco)
- Seed flag `iglesias_mexico_seed_v2` + borrado en Firestore de los OSM retirados

## Limitaciones que quedan

- Muchas entradas con ciudad «México» (haría falta geocoding inverso)
- Calidad OSM variable (nombres y etiquetas)
- No se hace moderación teológica exhaustiva de las ~400
