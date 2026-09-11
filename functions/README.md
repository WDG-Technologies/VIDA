# Cloud Functions — push Comunidad

## Una sola vez

```bash
firebase login
cd functions
npm install
cd ..
firebase deploy --only functions
```

Proyecto: `vida-86307` (ver `.firebaserc`).

## Qué hace

- `dispatchCommunityPush`: al crear docs en `fcm_dispatch`, envía FCM al `toUid`.
- `onCommunityComment` / `onCommunityLike`: respaldo si el cliente no encoló.

## Firestore (reglas sugeridas)

Permitir que un usuario autenticado cree inbox para otro y `fcm_dispatch` (o restringe a Cloud Functions solo y quita la escritura cliente de `fcm_dispatch` si prefieres máxima seguridad).
