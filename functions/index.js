const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'une nouvelle
 * demande d'adhésion (join_requests) est créée.
 */
exports.onJoinRequestCreated = functions.firestore
  .document("join_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const requestId = context.params.requestId;
    const data = snap.data();

    console.log("onJoinRequestCreated: déclenché, requestId=", requestId);

    const clubId = data.clubId;
    const clubName = String(data.clubName || "");
    const userId = String(data.userId || "");
    const roleRequested = String(data.roleRequested || "player");
    const firstName = String(data.firstName || "").trim();
    const lastName = String(data.lastName || "").trim();
    const message = String(data.message || "").trim();

    // Libellé du rôle pour la notif
    const roleLabels = {
      player: "Membre",
      coach: "Coach",
      admin_fondateur: "Admin fondateur",
    };
    const roleLabel = roleLabels[roleRequested] || roleRequested;

    if (!clubId) {
      console.warn(
        "onJoinRequestCreated: clubId manquant, requestId=",
        requestId,
      );
      return null;
    }

    const clubDoc = await db.collection("clubs").doc(clubId).get();
    if (!clubDoc.exists) {
      console.warn("onJoinRequestCreated: club introuvable, clubId=", clubId);
      return null;
    }

    const clubData = clubDoc.data();
    const admins = Array.isArray(clubData.admins) ? clubData.admins : [];
    const coaches = Array.isArray(clubData.coaches) ? clubData.coaches : [];
    // Fallback: certains clubs n'ont que adminId (singulier)
    const adminId = clubData.adminId;
    const recipientIdsSet = new Set([...admins, ...coaches]);
    if (adminId) recipientIdsSet.add(adminId);
    const recipientIds = [...recipientIdsSet];

    console.log(
      "onJoinRequestCreated: clubId=",
      clubId,
      "recipientIds=",
      recipientIds,
    );

    if (recipientIds.length === 0) {
      console.warn(
        "onJoinRequestCreated: aucun admin/coach pour clubId=",
        clubId,
      );
      return null;
    }

    const tokens = [];
    for (const uid of recipientIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      const token = userDoc.exists && userDoc.data().fcmToken;
      if (token) {
        tokens.push(token);
      } else {
        console.log(
          "onJoinRequestCreated: pas de fcmToken pour uid=",
          uid,
          "(l'admin doit ouvrir l'app au moins une fois)",
        );
      }
    }

    if (tokens.length === 0) {
      console.warn(
        "onJoinRequestCreated: aucun token FCM. Vérifiez que l'admin a ouvert l'app (connecté) au moins une fois. recipientIds=",
        recipientIds,
      );
      return null;
    }

    const notifTitle = "Demande d'adhésion - " + roleLabel;
    const notifBody =
      (firstName || lastName
        ? (firstName + " " + lastName).trim() + " - "
        : "") + (message || "Nouvelle demande");

    // FCM exige que toutes les valeurs de "data" soient des strings
    const payload = {
      notification: {
        title: notifTitle,
        body: notifBody,
      },
      data: {
        type: "join_request",
        requestId: String(requestId),
        userId,
        clubId: String(clubId),
        clubName,
        roleRequested,
        firstName,
        lastName,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const messaging = admin.messaging();
    try {
      const result = await messaging.sendEachForMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onJoinRequestCreated: notif envoyée à",
        result.successCount,
        "/",
        tokens.length,
        "destinataire(s), requestId=",
        requestId,
      );
      return result;
    } catch (err) {
      console.error("onJoinRequestCreated: erreur FCM", err);
      throw err;
    }
  });
