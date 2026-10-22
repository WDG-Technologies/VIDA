# Patches de terceros (VIDA)

## `firebase_auth_web` (5.15.3)

Safari iOS:

1. `getAuthInstance` — localStorage + session; fallback `getAuth`.
2. `onWaitInitState` — no espera Auth/IndexedDB.
3. Streams — null-safe (`?.add`).
4. **Constructor**: crear `userStateChange` **antes** de `idTokenChange` (Safari emite idToken en sync → Null check en `_userChangesListeners[…]!`).
5. `ensurePluginInitialized` — try/catch.

## `firebase_core_web` (2.24.1)

1. Carga `firebase-app.js` primero ([#18443](https://github.com/firebase/flutterfire/pull/18443)).
2. Fallos de plugin no tumban `initializeApp`.
