# VIDA 0.8.1 (Beta) — Notas de la versión

**Build:** `0.8.1+10`  
**APK:** [`VIDA.apk`](./VIDA.apk)

Parche de estabilidad sobre 0.8. Sin cambios notables de diseño ni flujo.

---

## Correcciones

- Arranque más resistente: si Firebase o notificaciones fallan, la app igual abre.
- Prefs corruptas (estudios, racha, señales VIDA, guardados) ya no tumban pantallas.
- Menos crashes por `setState` / `context` tras cerrar pantalla (estudio, racha, favorito, mapa, comunidad).
- Menos dobles toques: guardar estudio, compartir imagen, testimonios.
- Mapa: búsqueda con timer seguro; descripción y listas de Firestore más tolerantes; Nominatim sin `parse` frágil.
- Widget Favorito: bitmaps en `RGB_565` para reducir `TransactionTooLargeException`.
- Riega: restauración de progreso con escape JSON seguro.
- Actualizaciones y enlace de Perfil apuntan a `WDG-Technologies/VIDA`.

---

## Incluye lo de 0.8

Mazo del inicio, oración guiada, Evangelízate ampliado, Mini Arcade (8 juegos), Perfil mejorado, etc. Ver historial de 0.8 si necesitas el detalle de features.
