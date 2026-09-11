# VIDA 0.9.22 (Beta) — Notas de la versión

**Build:** `0.9.22+16`  
**APK:** [`VIDA.apk`](./VIDA.apk)  
**Web:** build Flutter web (GitHub Pages / hosting estático)

---

## En esta versión

- **Versión web** usable: se ocultan solo funciones nativas (widgets, Quiz/Riega WebView, recordatorios locales)
- Mapa con iglesias desde JSON local si Firebase no está disponible
- Crear imagen / compartir sin `dart:io` (compatible web)
- Branding web (título VIDA, colores esmeralda)
- Incluye **0.9.21** (versículos del día, avisos Comunidad, seed iglesias, etc.)

## Oculto solo en web

- Contra pecado / Versículo en inicio (widgets)
- Quiz y Riega (WebView)
- Recordatorios locales

## Para la siguiente beta / 1.0

- Donaciones Stripe con link **live**
- Play / TestFlight + keystore
- Firebase web options (Comunidad/Testimonios cloud en navegador)
- (Opcional) Push remoto FCM + Blaze
