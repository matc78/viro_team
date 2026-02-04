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

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'une nouvelle
 * demande de prêt (equipment_loan_requests) est créée.
 */
exports.onLoanRequestCreated = functions.firestore
  .document("clubs/{clubId}/equipment_loan_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const { clubId, requestId } = context.params;
    const data = snap.data();

    console.log("onLoanRequestCreated: déclenché, clubId=", clubId, "requestId=", requestId);

    const playerId = String(data.playerId || "");
    const playerName = String(data.playerName || "").trim();
    const equipmentName = String(data.equipmentName || "").trim();
    const quantity = data.quantity != null ? Number(data.quantity) : 1;
    const status = String(data.status || "pending");

    if (!clubId) {
      console.warn("onLoanRequestCreated: clubId manquant");
      return null;
    }

    const clubDoc = await db.collection("clubs").doc(clubId).get();
    if (!clubDoc.exists) {
      console.warn("onLoanRequestCreated: club introuvable, clubId=", clubId);
      return null;
    }

    const clubData = clubDoc.data();
    const clubName = String(clubData?.name || "");
    const admins = Array.isArray(clubData?.admins) ? clubData.admins : [];
    const coaches = Array.isArray(clubData?.coaches) ? clubData.coaches : [];
    const adminId = clubData?.adminId;
    const recipientIdsSet = new Set([...admins, ...coaches]);
    if (adminId) recipientIdsSet.add(adminId);
    const recipientIds = [...recipientIdsSet];

    if (recipientIds.length === 0) {
      console.warn("onLoanRequestCreated: aucun admin/coach pour clubId=", clubId);
      return null;
    }

    const tokens = [];
    for (const uid of recipientIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      const token = userDoc.exists && userDoc.data()?.fcmToken;
      if (token) {
        tokens.push(token);
      }
    }

    if (tokens.length === 0) {
      console.warn(
        "onLoanRequestCreated: aucun token FCM. recipientIds=",
        recipientIds,
      );
      return null;
    }

    const qtyLabel = quantity > 1 ? ` (x${quantity})` : "";
    const notifTitle = "Demande de prêt";
    const notifBody =
      (playerName ? playerName + " - " : "") +
      (equipmentName ? equipmentName + qtyLabel : "Nouvelle demande");

    const payload = {
      notification: {
        title: notifTitle,
        body: notifBody,
      },
      data: {
        type: "loan_request",
        requestId: String(requestId),
        clubId: String(clubId),
        clubName,
        playerId,
        playerName,
        equipmentName,
      },
      android: { priority: "high" },
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
        "onLoanRequestCreated: notif envoyée à",
        result.successCount,
        "/",
        tokens.length,
        "destinataire(s), requestId=",
        requestId,
      );
      return result;
    } catch (err) {
      console.error("onLoanRequestCreated: erreur FCM", err);
      throw err;
    }
  });

/**
 * Envoie une notification FCM à l'utilisateur lorsqu'une demande d'adhésion
 * est acceptée ou refusée (mise à jour du champ status).
 */
exports.onJoinRequestUpdated = functions.firestore
  .document("join_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const requestId = context.params.requestId;
    const before = change.before.data();
    const after = change.after.data();

    const newStatus = String(after?.status || "");
    if (newStatus !== "accepted" && newStatus !== "refused") {
      return null;
    }
    const oldStatus = String(before?.status || "");
    if (oldStatus === "accepted" || oldStatus === "refused") {
      return null;
    }

    const userId = String(after?.userId || "");
    const clubId = String(after?.clubId || "");
    const clubName = String(after?.clubName || "");
    const roleRequested = String(after?.roleRequested || "player");

    if (!userId) {
      console.warn("onJoinRequestUpdated: userId manquant, requestId=", requestId);
      return null;
    }

    const userDoc = await db.collection("users").doc(userId).get();
    const token = userDoc.exists && userDoc.data()?.fcmToken;
    if (!token) {
      console.log(
        "onJoinRequestUpdated: pas de fcmToken pour userId=",
        userId,
      );
      return null;
    }

    const isAccepted = newStatus === "accepted";
    const notifTitle = isAccepted
      ? "Demande d'adhésion acceptée"
      : "Demande d'adhésion refusée";
    const notifBody = clubName
      ? `${clubName} : votre demande a été ${isAccepted ? "acceptée" : "refusée"}.`
      : `Votre demande a été ${isAccepted ? "acceptée" : "refusée"}.`;

    const payload = {
      notification: { title: notifTitle, body: notifBody },
      data: {
        type: "join_request_response",
        requestId: String(requestId),
        clubId,
        clubName,
        status: newStatus,
        roleRequested,
      },
      android: { priority: "high" },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    };

    const messaging = admin.messaging();
    try {
      const result = await messaging.sendEachForMulticast({
        tokens: [token],
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onJoinRequestUpdated: notif envoyée à userId=",
        userId,
        "status=",
        newStatus,
      );
      return result;
    } catch (err) {
      console.error("onJoinRequestUpdated: erreur FCM", err);
      throw err;
    }
  });

/**
 * Envoie une notification FCM au joueur lorsqu'une demande de prêt
 * est acceptée ou refusée (mise à jour du champ status).
 */
exports.onLoanRequestUpdated = functions.firestore
  .document("clubs/{clubId}/equipment_loan_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const { clubId, requestId } = context.params;
    const after = change.after.data();

    const newStatus = String(after?.status || "");
    if (newStatus !== "accepted" && newStatus !== "refused") {
      return null;
    }

    const before = change.before.data();
    const oldStatus = String(before?.status || "");
    if (oldStatus === "accepted" || oldStatus === "refused") {
      return null;
    }

    const playerId = String(after?.playerId || "");
    const equipmentName = String(after?.equipmentName || "").trim();
    const adminResponse = String(after?.adminResponse || "").trim();

    if (!playerId) {
      console.warn(
        "onLoanRequestUpdated: playerId manquant, requestId=",
        requestId,
      );
      return null;
    }

    const clubDoc = await db.collection("clubs").doc(clubId).get();
    const clubName = clubDoc.exists
      ? String(clubDoc.data()?.name || "")
      : "";

    const userDoc = await db.collection("users").doc(playerId).get();
    const token = userDoc.exists && userDoc.data()?.fcmToken;
    if (!token) {
      console.log(
        "onLoanRequestUpdated: pas de fcmToken pour playerId=",
        playerId,
      );
      return null;
    }

    const isAccepted = newStatus === "accepted";
    const notifTitle = isAccepted
      ? "Demande de prêt acceptée"
      : "Demande de prêt refusée";
    const notifBody = clubName
      ? `${clubName} : ${equipmentName ? equipmentName + " - " : ""}demande ${isAccepted ? "acceptée" : "refusée"}.`
      : `Demande ${isAccepted ? "acceptée" : "refusée"}.`;

    const payload = {
      notification: { title: notifTitle, body: notifBody },
      data: {
        type: "loan_request_response",
        requestId: String(requestId),
        clubId: String(clubId),
        clubName,
        status: newStatus,
        equipmentName,
        adminResponse: adminResponse || "",
      },
      android: { priority: "high" },
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    };

    const messaging = admin.messaging();
    try {
      const result = await messaging.sendEachForMulticast({
        tokens: [token],
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onLoanRequestUpdated: notif envoyée à playerId=",
        playerId,
        "status=",
        newStatus,
      );
      return result;
    } catch (err) {
      console.error("onLoanRequestUpdated: erreur FCM", err);
      throw err;
    }
  });
