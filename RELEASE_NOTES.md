# VIDA 0.9.21 (Beta) — Notas de la versión

**Build:** `0.9.21+15`  
**APK:** [`VIDA.apk`](./VIDA.apk)

---

## En esta versión

- Botón **Reportar un bug** en Perfil (GitHub Issues)
- Comunidad ya no aparece en Perfil (sigue en Inicio)
- Cambiar el nombre en Perfil actualiza Comunidad (Firebase Auth + posts + comentarios)
- Revisión seed iglesias MX: quitar Testigos, nombres genéricos y ciudades capitalizadas
- Avisos de Comunidad **gratis**: bandeja Firestore + notificaciones locales (sin Cloud Functions / Blaze)
- Badge de no leídos en Inicio → Comunidad; se marcan leídos al abrir Comunidad
- Deep link `vida://post/{id}` abre el post en Comunidad
- Versículo del día: lista completa (~149 citas) en `daily_verses.json`
- Donaciones Stripe cableadas pero **deshabilitadas** hasta 1.0
- Incluye el parche **0.9.11** (UI Comunidad, mapa OSM)

## Para la siguiente beta / 1.0

- Donaciones Stripe con link **live**
- Play / TestFlight + keystore de upload
- **Versión web**: despliegue + recorte de funciones
- (Opcional) Push remoto con FCM + Cloud Functions (plan Blaze)
