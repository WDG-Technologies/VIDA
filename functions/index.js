/**
 * VIDA — push de Comunidad.
 *
 * Despliegue:
 *   cd functions && npm install
 *   firebase deploy --only functions
 *
 * La app escribe en `fcm_dispatch`; esta función envía FCM.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function tokensFor(uid) {
  const snap = await db.collection("users").doc(uid).collection("fcmTokens").get();
  return snap.docs
    .map((d) => (d.data() || {}).token)
    .filter((t) => typeof t === "string" && t.length > 10);
}

async function pushEnabled(uid) {
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) return true;
  const v = doc.data().communityPushEnabled;
  return v !== false;
}

async function sendToUser(uid, title, body, data) {
  if (!(await pushEnabled(uid))) return { skipped: true };
  const tokens = await tokensFor(uid);
  if (!tokens.length) return { skipped: true, reason: "no-tokens" };

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v ?? "")])
    ),
    android: {
      priority: "high",
      notification: {
        channelId: "vida_community",
        icon: "ic_stat_vida",
        color: "#059669",
      },
    },
  });

  const stale = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[i]);
      }
    }
  });
  if (stale.length) {
    const col = db.collection("users").doc(uid).collection("fcmTokens");
    const all = await col.get();
    const batch = db.batch();
    all.docs.forEach((d) => {
      if (stale.includes((d.data() || {}).token)) batch.delete(d.ref);
    });
    await batch.commit();
  }
  return { successCount: res.successCount, failureCount: res.failureCount };
}

exports.dispatchCommunityPush = functions.firestore
  .document("fcm_dispatch/{id}")
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const toUid = data.toUid;
    const title = data.title || "Comunidad VIDA";
    const body = data.body || "";
    if (!toUid || !body) {
      await snap.ref.update({ processed: true, error: "invalid" });
      return null;
    }
    try {
      const result = await sendToUser(toUid, title, body, data.data || {});
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        result,
      });
    } catch (e) {
      await snap.ref.update({
        processed: true,
        error: String(e && e.message ? e.message : e),
      });
    }
    return null;
  });
