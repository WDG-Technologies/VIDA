# Cloud Functions — push remoto (opcional)

La app **ya no depende** de estas Functions. Los avisos de Comunidad usan bandeja Firestore + notificaciones locales (plan Spark / gratis).

Este código queda por si algún día se activa plan **Blaze** y se quiere push remoto con FCM.

## Deploy (solo con Blaze)

```bash
firebase login
cd functions
npm install
cd ..
firebase deploy --only functions
```

Proyecto: `vida-86307` (ver `.firebaserc`).

Sin Blaze, el deploy falla al habilitar Artifact Registry / Cloud Build.

## Qué haría

- `dispatchCommunityPush`: al crear docs en `fcm_dispatch`, envía FCM al `toUid`.

Hoy el cliente **no escribe** en `fcm_dispatch`; solo en `users/{uid}/inbox`.
