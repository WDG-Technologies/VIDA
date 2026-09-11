# Ficha de tienda (borrador) — VIDA

Usar al publicar en Google Play / App Store. Ajustar screenshots reales.

## Nombre corto
VIDA

## Título
VIDA — Compañero espiritual diario

## Descripción corta (≤80)
Biblia offline, oración, racha, Evangelízate y comunidad. Gratis, sin anuncios.

## Descripción completa

VIDA es tu compañero espiritual diario en español.

• Biblia Reina-Valera 1909 sin conexión  
• Versículo VIDA personalizado y versículo del día  
• Oración guiada, racha y estudio bíblico  
• Evangelízate: guías para compartir la fe  
• Mapa de iglesias y comunidad  
• Widgets Android (Contra pecado y versículo favorito)  
• Mini Arcade con juegos bíblicos  

Gratis · Sin publicidad · WDG Technologies  

## Categoría
Estilo de vida / Educación

## Contacto / privacidad
https://github.com/WDG-Technologies/VIDA/blob/main/PRIVACY.md

## Notas de firma (Android)
El release actual puede firmarse con la keystore de debug en desarrollo.
Para Play Store: crea `android/key.properties` + keystore de upload y cablea
`signingConfigs` en `android/app/build.gradle.kts`, luego:

```bash
flutter build appbundle --release
```
