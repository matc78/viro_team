const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { getDownloadURL } = require("firebase-admin/storage");
const { getFirestore } = require("firebase-admin/firestore");

admin.initializeApp();

const dbTest = getFirestore("test");
const dbProd = getFirestore("prod");

/** Seuils Safe Search : on rejette si VERY_LIKELY, LIKELY ou VERIFIED pour adult, racy, violence */
const REJECT_LIKELIHOODS = ["VERY_LIKELY", "LIKELY", "VERIFIED"];

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'une nouvelle
 * demande d'adhésion (join_requests) est créée.
 */
const makeOnJoinRequestCreated = (db) => async (snap, context) => {
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
  };
exports.onJoinRequestCreatedTest = functions.firestore
  .database("test")
  .document("join_requests/{requestId}")
  .onCreate(makeOnJoinRequestCreated(dbTest));
exports.onJoinRequestCreatedProd = functions.firestore
  .database("prod")
  .document("join_requests/{requestId}")
  .onCreate(makeOnJoinRequestCreated(dbProd));

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'une nouvelle
 * demande de prêt (equipment_loan_requests) est créée.
 */
const makeOnLoanRequestCreated = (db) => async (snap, context) => {
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
  };
exports.onLoanRequestCreatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/equipment_loan_requests/{requestId}")
  .onCreate(makeOnLoanRequestCreated(dbTest));
exports.onLoanRequestCreatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/equipment_loan_requests/{requestId}")
  .onCreate(makeOnLoanRequestCreated(dbProd));

/**
 * Envoie une notification FCM à l'utilisateur lorsqu'une demande d'adhésion
 * est acceptée ou refusée (mise à jour du champ status).
 */
const makeOnJoinRequestUpdated = (db) => async (change, context) => {
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
  };
exports.onJoinRequestUpdatedTest = functions.firestore
  .database("test")
  .document("join_requests/{requestId}")
  .onUpdate(makeOnJoinRequestUpdated(dbTest));
exports.onJoinRequestUpdatedProd = functions.firestore
  .database("prod")
  .document("join_requests/{requestId}")
  .onUpdate(makeOnJoinRequestUpdated(dbProd));

/**
 * Envoie une notification FCM au joueur lorsqu'une demande de prêt
 * est acceptée ou refusée (mise à jour du champ status).
 */
const makeOnLoanRequestUpdated = (db) => async (change, context) => {
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
  };
exports.onLoanRequestUpdatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/equipment_loan_requests/{requestId}")
  .onUpdate(makeOnLoanRequestUpdated(dbTest));
exports.onLoanRequestUpdatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/equipment_loan_requests/{requestId}")
  .onUpdate(makeOnLoanRequestUpdated(dbProd));

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'un membre,
 * coach ou admin quitte le club (création dans member_leaves).
 */
const makeOnMemberLeaveCreated = (db) => async (snap, context) => {
  const { clubId, leaveId } = context.params;
    const data = snap.data();

    console.log(
      "onMemberLeaveCreated: déclenché, clubId=",
      clubId,
      "leaveId=",
      leaveId,
    );

    const userId = String(data.userId || "");
    const firstName = String(data.firstName || "").trim();
    const lastName = String(data.lastName || "").trim();
    const role = String(data.role || "player");
    const leftAt = data.leftAt;

    const roleLabels = {
      player: "Membre",
      coach: "Coach",
      admin: "Admin",
    };
    const roleLabel = roleLabels[role] || role;
    const displayName =
      firstName || lastName ? `${firstName} ${lastName}`.trim() : "Un utilisateur";

    const clubDoc = await db.collection("clubs").doc(clubId).get();
    if (!clubDoc.exists) {
      console.warn("onMemberLeaveCreated: club introuvable, clubId=", clubId);
      return null;
    }

    const clubData = clubDoc.data();
    const admins = Array.isArray(clubData?.admins) ? clubData.admins : [];
    const coaches = Array.isArray(clubData?.coaches) ? clubData.coaches : [];
    const adminId = clubData?.adminId;
    const recipientIdsSet = new Set([...admins, ...coaches]);
    if (adminId) recipientIdsSet.add(adminId);
    // Exclure la personne qui part
    if (userId) recipientIdsSet.delete(userId);
    const recipientIds = [...recipientIdsSet];

    if (recipientIds.length === 0) {
      console.log(
        "onMemberLeaveCreated: aucun admin/coach à notifier pour clubId=",
        clubId,
      );
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
        "onMemberLeaveCreated: aucun token FCM. recipientIds=",
        recipientIds,
      );
      return null;
    }

    const notifTitle = "Départ du club";
    const notifBody = `${displayName} (${roleLabel}) a quitté le club.`;

    const payload = {
      notification: { title: notifTitle, body: notifBody },
      data: {
        type: "member_leave",
        clubId: String(clubId),
        leaveId: String(leaveId),
        userId,
        firstName,
        lastName,
        role,
        leftAt: leftAt ? String(leftAt.toMillis?.() ?? leftAt) : "",
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
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onMemberLeaveCreated: notif envoyée à",
        result.successCount,
        "/",
        tokens.length,
        "destinataire(s), leaveId=",
        leaveId,
      );
      return result;
    } catch (err) {
      console.error("onMemberLeaveCreated: erreur FCM", err);
      throw err;
    }
  };
exports.onMemberLeaveCreatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/member_leaves/{leaveId}")
  .onCreate(makeOnMemberLeaveCreated(dbTest));
exports.onMemberLeaveCreatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/member_leaves/{leaveId}")
  .onCreate(makeOnMemberLeaveCreated(dbProd));

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'un prêt
 * est marqué comme retourné (equipment_loans status -> returned).
 */
const makeOnEquipmentLoanUpdated = (db) => async (change, context) => {
  const { clubId, loanId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    const newStatus = String(after?.status || "");
    if (newStatus !== "returned") {
      return null;
    }
    const oldStatus = String(before?.status || "");
    if (oldStatus === "returned") {
      return null;
    }

    const borrowerName = String(after?.borrowerName || "").trim();
    const equipmentName = String(after?.equipmentName || "").trim();
    const returnedAt = after?.returnedAt;
    const returnedAtStr = returnedAt
      ? String(returnedAt.toMillis ? returnedAt.toMillis() : returnedAt)
      : "";

    const clubDoc = await db.collection("clubs").doc(clubId).get();
    if (!clubDoc.exists) {
      console.warn("onEquipmentLoanUpdated: club introuvable, clubId=", clubId);
      return null;
    }

    const clubData = clubDoc.data();
    const admins = Array.isArray(clubData?.admins) ? clubData.admins : [];
    const coaches = Array.isArray(clubData?.coaches) ? clubData.coaches : [];
    const adminId = clubData?.adminId;
    const recipientIdsSet = new Set([...admins, ...coaches]);
    if (adminId) recipientIdsSet.add(adminId);
    const recipientIds = [...recipientIdsSet];

    if (recipientIds.length === 0) {
      console.warn(
        "onEquipmentLoanUpdated: aucun admin/coach pour clubId=",
        clubId,
      );
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
        "onEquipmentLoanUpdated: aucun token FCM. recipientIds=",
        recipientIds,
      );
      return null;
    }

    const notifTitle = "Retour de matériel";
    const notifBody =
      (borrowerName ? borrowerName + " - " : "") +
      (equipmentName || "Prêt") +
      " a été retourné.";

    const payload = {
      notification: { title: notifTitle, body: notifBody },
      data: {
        type: "loan_return",
        clubId: String(clubId),
        loanId: String(loanId),
        borrowerName: borrowerName || "",
        equipmentName: equipmentName || "",
        returnedAt: returnedAtStr,
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
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onEquipmentLoanUpdated: notif envoyée à",
        result.successCount,
        "/",
        tokens.length,
        "destinataire(s), loanId=",
        loanId,
      );
      return result;
    } catch (err) {
      console.error("onEquipmentLoanUpdated: erreur FCM", err);
      throw err;
    }
  };
exports.onEquipmentLoanUpdatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/equipment_loans/{loanId}")
  .onUpdate(makeOnEquipmentLoanUpdated(dbTest));
exports.onEquipmentLoanUpdatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/equipment_loans/{loanId}")
  .onUpdate(makeOnEquipmentLoanUpdated(dbProd));

/**
 * Résout les userId destinataires d'une annonce selon targetType et targetIds.
 * Retourne un tableau d'uid (sans doublons).
 */
async function resolveAnnouncementRecipients(db, clubId, targetType, targetIds) {
  const recipientIdsSet = new Set();
  const clubRef = db.collection("clubs").doc(clubId);
  const clubDoc = await clubRef.get();
  if (!clubDoc.exists) {
    return [];
  }
  const clubData = clubDoc.data();
  const admins = Array.isArray(clubData?.admins) ? clubData.admins : [];
  const coaches = Array.isArray(clubData?.coaches) ? clubData.coaches : [];
  const adminId = clubData?.adminId;
  if (adminId) recipientIdsSet.add(adminId);
  admins.forEach((id) => recipientIdsSet.add(id));
  coaches.forEach((id) => recipientIdsSet.add(id));

  const teamsSnap = await clubRef.collection("teams").get();

  if (targetType === "Tous les membres") {
    teamsSnap.docs.forEach((doc) => {
      const d = doc.data();
      (d.playerIds || []).forEach((id) => recipientIdsSet.add(id));
      (d.coachIds || []).forEach((id) => recipientIdsSet.add(id));
    });
    return [...recipientIdsSet];
  }

  if (targetType === "Équipes") {
    const ids = Array.isArray(targetIds) ? targetIds : [];
    for (const teamId of ids) {
      const teamDoc = await clubRef.collection("teams").doc(teamId).get();
      if (!teamDoc.exists) continue;
      const d = teamDoc.data();
      (d.playerIds || []).forEach((id) => recipientIdsSet.add(id));
      (d.coachIds || []).forEach((id) => recipientIdsSet.add(id));
    }
    return [...recipientIdsSet];
  }

  if (targetType === "Catégories") {
    const categories = Array.isArray(targetIds) ? targetIds : [];
    teamsSnap.docs.forEach((doc) => {
      const d = doc.data();
      const cat = d.category;
      if (cat && categories.includes(cat)) {
        (d.playerIds || []).forEach((id) => recipientIdsSet.add(id));
        (d.coachIds || []).forEach((id) => recipientIdsSet.add(id));
      }
    });
    return [...recipientIdsSet];
  }

  if (targetType === "Joueurs") {
    const ids = Array.isArray(targetIds) ? targetIds : [];
    ids.forEach((id) => id && recipientIdsSet.add(id));
    return [...recipientIdsSet];
  }

  return [...recipientIdsSet];
}

/**
 * Envoie une notification FCM aux destinataires lorsqu'une nouvelle
 * annonce club est créée (clubs/{clubId}/announcements).
 */
const makeOnAnnouncementCreated = (db) => async (snap, context) => {
  const { clubId, announcementId } = context.params;
  const data = snap.data();

  const message = String(data.message || "").trim();
    const senderFirstName = String(data.senderFirstName || "").trim();
    const senderLastName = String(data.senderLastName || "").trim();
    const targetType = String(data.targetType || "Tous les membres").trim();
    const targetIds = Array.isArray(data.targetIds) ? data.targetIds : [];

    const recipientIds = await resolveAnnouncementRecipients(
      db,
      clubId,
      targetType,
      targetIds
    );
    if (recipientIds.length === 0) {
      console.log(
        "onAnnouncementCreated: aucun destinataire, clubId=",
        clubId,
        "targetType=",
        targetType,
      );
      return null;
    }

    const messagePreview =
      message.length > 100 ? message.substring(0, 97) + "..." : message;
    const senderName = [senderFirstName, senderLastName].filter(Boolean).join(" ");
    const notifTitle = "Nouvelle annonce";
    const notifBody = senderName
      ? senderName + " : " + messagePreview
      : messagePreview || "Nouvelle annonce du club.";

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
        "onAnnouncementCreated: aucun token FCM. recipientIds=",
        recipientIds.length,
      );
      return null;
    }

    const payload = {
      notification: { title: notifTitle, body: notifBody },
      data: {
        type: "announcement",
        clubId: String(clubId),
        announcementId: String(announcementId),
        senderFirstName: senderFirstName || "",
        senderLastName: senderLastName || "",
        message: messagePreview || "",
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
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onAnnouncementCreated: notif envoyée à",
        result.successCount,
        "/",
        tokens.length,
        "announcementId=",
        announcementId,
      );
      return result;
    } catch (err) {
      console.error("onAnnouncementCreated: erreur FCM", err);
      throw err;
    }
  };
exports.onAnnouncementCreatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/announcements/{announcementId}")
  .onCreate(makeOnAnnouncementCreated(dbTest));
exports.onAnnouncementCreatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/announcements/{announcementId}")
  .onCreate(makeOnAnnouncementCreated(dbProd));

/**
 * Envoie une notification FCM aux membres concernés (teamMemberIds)
 * lorsqu'un nouvel événement est créé.
 */
const makeOnEventCreated = (db) => async (snap, context) => {
  const { clubId, eventId } = context.params;
    const data = snap.data();

    const teamMemberIds = Array.isArray(data.teamMemberIds)
      ? data.teamMemberIds.filter((id) => id && String(id).trim())
      : [];
    if (teamMemberIds.length === 0) {
      console.log("onEventCreated: aucun teamMemberIds, eventId=", eventId);
      return null;
    }

    const title = String(data.title || "").trim() || null;
    const eventType = String(data.type || "Événement").trim();
    const teamName = String(data.teamName || "").trim();
    const dateId = String(data.dateId || "");
    const startTime = String(data.startTime || "");
    const location = String(data.location || "").trim();
    const clubName = String(data.clubName || "").trim();

    const displayTitle = title || eventType;
    const notifTitle = "Nouvel événement";
    const notifBody =
      (clubName ? clubName + " - " : "") +
      displayTitle +
      (teamName ? " (" + teamName + ")" : "") +
      (startTime ? " à " + startTime : "");

    const tokens = [];
    for (const uid of teamMemberIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      const token = userDoc.exists && userDoc.data()?.fcmToken;
      if (token) {
        tokens.push(token);
      }
    }

    if (tokens.length === 0) {
      console.warn(
        "onEventCreated: aucun token FCM. eventId=",
        eventId,
        "recipientIds=",
        teamMemberIds.length,
      );
      return null;
    }

    const payload = {
      notification: { title: notifTitle, body: notifBody },
      data: {
        type: "event",
        clubId: String(clubId),
        eventId: String(eventId),
        title: displayTitle || "",
        eventType,
        dateId,
        startTime,
        location,
        clubName,
        isReminder: "",
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
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      console.log(
        "onEventCreated: notif envoyée à",
        result.successCount,
        "/",
        tokens.length,
        "eventId=",
        eventId,
      );
      return result;
    } catch (err) {
      console.error("onEventCreated: erreur FCM", err);
      throw err;
    }
  };
exports.onEventCreatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/events/{eventId}")
  .onCreate(makeOnEventCreated(dbTest));
exports.onEventCreatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/events/{eventId}")
  .onCreate(makeOnEventCreated(dbProd));

/**
 * Format la date en français (ex: "lundi 9 mars")
 */
function formatEventDate(dateObj) {
  if (!dateObj) return "";
  const d = dateObj.toDate ? dateObj.toDate() : new Date(dateObj);
  return new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Europe/Paris",
    weekday: "long",
    day: "numeric",
    month: "long"
  }).format(d);
}

/**
 * Envoie une notification FCM aux membres concernés lorsqu'un événement
 * est modifié (date, heure, titre, lieu ou liste des participants).
 */
const makeOnEventUpdated = (db) => async (change, context) => {
  const { clubId, eventId } = context.params;
  const before = change.before.data();
  const after = change.after.data();

  // 1. Détection de modification d'attendance
  const attendanceBefore = before.attendance || {};
  const attendanceAfter = after.attendance || {};
  const attendanceChanged = JSON.stringify(attendanceBefore) !== JSON.stringify(attendanceAfter);

  // 2. Détection de modification des autres champs (joueurs)
  const relevantFields = [
    "date",
    "startTime",
    "endTime",
    "title",
    "type",
    "location",
    "canceled",
  ];
  const eventDetailsChanged = relevantFields.some(
    (f) => JSON.stringify(after?.[f]) !== JSON.stringify(before?.[f])
  );

  if (!attendanceChanged && !eventDetailsChanged) {
    return null;
  }

  const teamMemberIds = Array.isArray(after.teamMemberIds)
    ? after.teamMemberIds.filter((id) => id && String(id).trim())
    : [];

  const title = String(after.title || "").trim() || null;
  const eventType = String(after.type || "Événement").trim();
  const displayTitle = title || eventType;
  const teamName = String(after.teamName || "").trim();
  const startTime = String(after.startTime || "");
  const clubName = String(after.clubName || "").trim();
  const dateStr = formatEventDate(after.date);

  const messaging = admin.messaging();

  // ----- NOTIFICATION COACH (Présences) -----
  if (attendanceChanged) {
    let coachIds = [];
    if (teamName && teamName !== "Tout le club" && teamName !== "Multi-équipes") {
      const teamsSnap = await db.collection("clubs").doc(clubId).collection("teams").where("name", "==", teamName).limit(1).get();
      if (!teamsSnap.empty) {
        coachIds = teamsSnap.docs[0].data().coachIds || [];
      }
    } else {
      const teamNames = Array.isArray(after.teamNames) ? after.teamNames : [];
      if (teamNames.length > 0) {
        // Firestore 'in' query supports up to 30 elements
        const chunks = [];
        for (let i = 0; i < teamNames.length; i += 30) {
          chunks.push(teamNames.slice(i, i + 30));
        }
        for (const chunk of chunks) {
          const tSnap = await db.collection("clubs").doc(clubId).collection("teams").where("name", "in", chunk).get();
          tSnap.forEach(doc => {
            const cIds = doc.data().coachIds || [];
            coachIds.push(...cIds);
          });
        }
      }
    }

    coachIds = [...new Set(coachIds)];

    if (coachIds.length > 0) {
      const attendanceValues = Object.values(attendanceAfter);
      const presentCount = attendanceValues.filter(v => v === "present").length;
      const absentCount = attendanceValues.filter(v => v === "absent").length;
      
      // Calculate total players logic. Pending is total invited minus responded.
      let totalConvoqued = teamMemberIds.length;
      if (teamName && teamName !== "Tout le club" && teamName !== "Multi-équipes") {
         const teamsSnap = await db.collection("clubs").doc(clubId).collection("teams").where("name", "==", teamName).limit(1).get();
         if (!teamsSnap.empty) {
            const pendingIds = teamsSnap.docs[0].data().pendingPlayerIds || [];
            totalConvoqued += pendingIds.length;
         }
      }
      
      const pendingCount = Math.max(0, totalConvoqued - presentCount - absentCount);

      const coachTokens = [];
      for (const uid of coachIds) {
        const userDoc = await db.collection("users").doc(uid).get();
        const token = userDoc.exists && userDoc.data()?.fcmToken;
        if (token) coachTokens.push(token);
      }

      if (coachTokens.length > 0) {
        const notifTitle = "Mise à jour des présences";
        const notifBody = `${displayTitle} du ${dateStr} : ${presentCount} Oui, ${absentCount} Non, ${pendingCount} En attente.`;

        const payload = {
          notification: { title: notifTitle, body: notifBody },
          data: {
            type: "event_presence",
            clubId: String(clubId),
            eventId: String(eventId),
            isReminder: "",
          },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
        };

        try {
          await messaging.sendEachForMulticast({ ...payload, tokens: coachTokens });
        } catch (err) {
          console.error("onEventUpdated: erreur FCM Coach", err);
        }
      }
    }
  }

  // ----- NOTIFICATION JOUEURS (Modif/Annulation) -----
  if (eventDetailsChanged && teamMemberIds.length > 0) {
    const isCanceled = after.canceled === true && before.canceled !== true;
    
    let notifTitle = "";
    let notifBody = "";

    if (isCanceled) {
      notifTitle = "Événement annulé";
      notifBody = `L'événement ${displayTitle} du ${dateStr} a été annulé.`;
    } else {
      notifTitle = "Événement modifié";
      notifBody = `Événement modifié : ${displayTitle} aura lieu le ${dateStr} à ${startTime}.`;
    }

    const playerTokens = [];
    for (const uid of teamMemberIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      const token = userDoc.exists && userDoc.data()?.fcmToken;
      if (token) playerTokens.push(token);
    }

    if (playerTokens.length > 0) {
      const payload = {
        notification: { title: notifTitle, body: notifBody },
        data: {
          type: "event_update",
          clubId: String(clubId),
          eventId: String(eventId),
          title: displayTitle || "",
          eventType,
          dateId: String(after.dateId || ""),
          startTime,
          location: String(after.location || "").trim(),
          clubName,
          isReminder: "",
        },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      };

      try {
        await messaging.sendEachForMulticast({ ...payload, tokens: playerTokens });
      } catch (err) {
        console.error("onEventUpdated: erreur FCM Joueurs", err);
      }
    }
  }

  return null;
};
exports.onEventUpdatedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/events/{eventId}")
  .onUpdate(makeOnEventUpdated(dbTest));
exports.onEventUpdatedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/events/{eventId}")
  .onUpdate(makeOnEventUpdated(dbProd));

/**
 * Envoie une notification lorsqu'un événement est supprimé.
 */
const makeOnEventDeleted = (db) => async (snap, context) => {
  const { clubId, eventId } = context.params;
  const data = snap.data();

  const teamMemberIds = Array.isArray(data.teamMemberIds)
    ? data.teamMemberIds.filter((id) => id && String(id).trim())
    : [];
  
  if (teamMemberIds.length === 0) return null;

  const title = String(data.title || "").trim() || null;
  const eventType = String(data.type || "Événement").trim();
  const displayTitle = title || eventType;
  const dateStr = formatEventDate(data.date);

  const notifTitle = "Événement supprimé";
  const notifBody = `L'événement ${displayTitle} du ${dateStr} a été supprimé.`;

  const tokens = [];
  for (const uid of teamMemberIds) {
    const userDoc = await db.collection("users").doc(uid).get();
    const token = userDoc.exists && userDoc.data()?.fcmToken;
    if (token) tokens.push(token);
  }

  if (tokens.length === 0) return null;

  const payload = {
    notification: { title: notifTitle, body: notifBody },
    data: {
      type: "event_deleted",
      clubId: String(clubId),
      eventId: String(eventId),
    },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
  };

  try {
    await admin.messaging().sendEachForMulticast({ ...payload, tokens });
  } catch (err) {
    console.error("onEventDeleted: erreur FCM", err);
  }
  return null;
};

exports.onEventDeletedTest = functions.firestore
  .database("test")
  .document("clubs/{clubId}/events/{eventId}")
  .onDelete(makeOnEventDeleted(dbTest));
exports.onEventDeletedProd = functions.firestore
  .database("prod")
  .document("clubs/{clubId}/events/{eventId}")
  .onDelete(makeOnEventDeleted(dbProd));

/**
 * Parse startTime string "HH:mm" or "H:mm" into { hours, minutes }.
 * Default 9:00 if empty or invalid.
 */
function parseStartTime(startTimeStr) {
  if (!startTimeStr || typeof startTimeStr !== "string") {
    return { hours: 9, minutes: 0 };
  }
  const match = startTimeStr.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!match) {
    return { hours: 9, minutes: 0 };
  }
  const hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);
  if (isNaN(hours) || isNaN(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return { hours: 9, minutes: 0 };
  }
  return { hours, minutes };
}

/**
 * Rappel événement : envoie une notification FCM aux participants
 * pour les événements configurés via reminderConfig.
 * Exécuté toutes les 15 minutes.
 */
async function runEventReminderForDb(db) {
  const now = new Date();

  const clubsSnap = await db.collection("clubs").get();
  const messaging = admin.messaging();
  let sent = 0;

  for (const clubDoc of clubsSnap.docs) {
    const clubId = clubDoc.id;
    const clubData = clubDoc.data();
    const clubName = String(clubData?.name || "").trim();

    // On cherche les événements futurs (date de l'événement > maintenant)
    // On prend une marge large (-1 jour) pour être sûr de rattraper des notifs.
    const searchStart = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const eventsSnap = await db
      .collection("clubs")
      .doc(clubId)
      .collection("events")
      .where("date", ">=", searchStart)
      .get();

    for (const eventDoc of eventsSnap.docs) {
      const eventId = eventDoc.id;
      const data = eventDoc.data();
      const date = data.date;
      if (!date || !date.toDate) continue;
      
      const eventDate = date.toDate();
      const reminderConfig = data.reminderConfig;
      if (!reminderConfig || !Array.isArray(reminderConfig.reminders)) continue;

      const remindersSent = data.remindersSent || [];
      const teamMemberIds = Array.isArray(data.teamMemberIds)
        ? data.teamMemberIds.filter((id) => id && String(id).trim())
        : [];
      if (teamMemberIds.length === 0) continue;

      let hasSentSomething = false;

      for (let i = 0; i < reminderConfig.reminders.length; i++) {
        const reminder = reminderConfig.reminders[i];
        const reminderId = `reminder_${i}`;

        if (remindersSent.includes(reminderId)) continue; // Déjà envoyé

        // Calcul de la date cible
        // Mettre à minuit en UTC pour le calcul
        const targetUtc = new Date(Date.UTC(eventDate.getUTCFullYear(), eventDate.getUTCMonth(), eventDate.getUTCDate()));

        if (reminder.weekday !== undefined) {
          let jsDay = targetUtc.getUTCDay();
          let isoDay = jsDay === 0 ? 7 : jsDay;
          let diff = isoDay - reminder.weekday;
          if (diff <= 0) diff += 7;
          targetUtc.setUTCDate(targetUtc.getUTCDate() - diff);
        } else if (reminder.daysBefore !== undefined) {
          targetUtc.setUTCDate(targetUtc.getUTCDate() - reminder.daysBefore);
        } else {
          continue;
        }

        const { hours, minutes } = parseStartTime(reminder.time || "12:00");
        targetUtc.setUTCHours(hours, minutes, 0, 0);
        
        // On estime que l'heure configurée est locale (Europe/Paris).
        // On doit donc soustraire l'offset de Paris pour avoir l'UTC réel de la cible.
        const isoStr = now.toLocaleString('en-US', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
        const parts = isoStr.match(/(\d+)\/(\d+)\/(\d+), (\d+):(\d+):(\d+)/);
        if (parts) {
            const parisDate = new Date(Date.UTC(parts[3], parts[1]-1, parts[2], parts[4], parts[5], parts[6]));
            const offsetHours = Math.round((parisDate.getTime() - now.getTime()) / (60 * 60 * 1000));
            targetUtc.setUTCHours(targetUtc.getUTCHours() - offsetHours);
        }

        const timeDiff = now.getTime() - targetUtc.getTime();
        
        // Fenêtre d'envoi : si l'heure actuelle a dépassé la cible (timeDiff >= 0)
        // et qu'on ne dépasse pas 12h (pour éviter l'envoi de très vieux rappels)
        if (timeDiff >= 0 && timeDiff <= 12 * 60 * 60 * 1000) {
          const title = String(data.title || "").trim() || null;
          const eventType = String(data.type || "Événement").trim();
          const displayTitle = title || eventType;
          const startTime = String(data.startTime || "");

          const notifTitle = "Rappel : " + displayTitle;
          let notifBody = reminder.message;
          
          if (!notifBody || notifBody.trim() === "") {
             const dateStr = formatEventDate(eventDate);
             notifBody = `Rappel : ${displayTitle} le ${dateStr} à ${startTime}.`;
          }

          const tokens = [];
          for (const uid of teamMemberIds) {
            const userDoc = await db.collection("users").doc(uid).get();
            const token = userDoc.exists && userDoc.data()?.fcmToken;
            if (token) tokens.push(token);
          }

          if (tokens.length > 0) {
            const payload = {
              notification: { title: notifTitle, body: notifBody },
              data: {
                type: "event",
                clubId: String(clubId),
                eventId: String(eventId),
                title: displayTitle || "",
                eventType,
                dateId: String(data.dateId || ""),
                startTime,
                location: String(data.location || "").trim(),
                clubName,
                isReminder: "true",
              },
              android: { priority: "high" },
              apns: { payload: { aps: { sound: "default", badge: 1 } } },
            };

            try {
              const result = await messaging.sendEachForMulticast({ ...payload, tokens });
              sent += result.successCount;
              console.log(`scheduledEventReminder: rappel envoyé eventId=${eventId} reminderId=${reminderId} à ${result.successCount} dest.`);
              
              remindersSent.push(reminderId);
              hasSentSomething = true;
            } catch (err) {
              console.error("scheduledEventReminder: erreur FCM eventId=", eventId, err);
            }
          } else {
             // Marquer comme envoyé même si aucun token pour ne pas réessayer sans fin
             remindersSent.push(reminderId);
             hasSentSomething = true;
          }
        }
      }

      if (hasSentSomething) {
        await eventDoc.ref.update({ remindersSent });
      }
    }
  }

  return sent;
}

exports.scheduledEventReminder = functions.pubsub
  .schedule("every 15 minutes")
  .timeZone("Europe/Paris")
  .onRun(async (context) => {
    const totalSent =
      (await runEventReminderForDb(dbTest)) + (await runEventReminderForDb(dbProd));
    console.log(
      "scheduledEventReminder: terminé, total notifs envoyées=",
      totalSent,
    );
    return null;
  });

/**
 * Modération des avatars : après chaque upload (chemins avatars/ ou users/.../avatar_...png),
 * appelle Vision API Safe Search. Si adult, racy ou violence est LIKELY ou VERIFIED,
 * supprime le fichier et met à jour Firestore (avatarUrl effacé, avatarModerationRejected).
 * Si OK : met avatarUrl, avatarModerationOk true, et efface les champs rejet.
 * Retourne { uid, database: 'test'|'prod' } selon le chemin (test = uniquement base test, prod = uniquement base prod).
 */
function parseAvatarUidFromPath(name) {
  if (!name || typeof name !== "string") return null;
  const avatarsTestMatch = name.match(/^avatars_test\/([^/]+)\.jpg$/i);
  if (avatarsTestMatch) return { uid: avatarsTestMatch[1], database: "test" };
  const avatarsMatch = name.match(/^avatars\/([^/]+)\.jpg$/i);
  if (avatarsMatch) return { uid: avatarsMatch[1], database: "prod" };
  const usersTestMatch = name.match(/^users_test\/([^/]+)\/avatar_.*\.png$/i);
  if (usersTestMatch) return { uid: usersTestMatch[1], database: "test" };
  const usersMatch = name.match(/^users\/([^/]+)\/avatar_.*\.png$/i);
  if (usersMatch) return { uid: usersMatch[1], database: "prod" };
  return null;
}

const STORAGE_BUCKET = "viroteam-75303.firebasestorage.app";

function logError(prefix, err) {
  const msg = err && err.message ? err.message : String(err);
  const code = err && err.code !== undefined ? err.code : "(no code)";
  const stack = err && err.stack ? err.stack : "";
  console.error(prefix, "message=", msg, "code=", code);
  if (stack) console.error(prefix, "stack=", stack);
}

exports.onAvatarUploadFinalized = functions.storage
  .bucket(STORAGE_BUCKET)
  .object()
  .onFinalize(async (object) => {
    const name = object.name;
    const bucket = object.bucket;
    console.log("onAvatarUploadFinalized: déclenché name=", name, "bucket=", bucket);

    const parsed = parseAvatarUidFromPath(name);
    if (!parsed) {
      console.log("onAvatarUploadFinalized: chemin non avatar, ignoré name=", name);
      return null;
    }
    const { uid, database } = parsed;
    const db = database === "test" ? dbTest : dbProd;
    console.log("onAvatarUploadFinalized: uid=", uid, "database=", database);

    try {
      const vision = require("@google-cloud/vision");
      const imageUri = `gs://${bucket}/${name}`;
      const visionClient = new vision.ImageAnnotatorClient();
      let safeSearch;
      try {
        const [result] = await visionClient.safeSearchDetection({
          image: { source: { imageUri } },
        });
        safeSearch = result.safeSearchAnnotation;
        if (!safeSearch) {
          console.warn("onAvatarUploadFinalized: pas de safeSearchAnnotation, name=", name);
          return null;
        }
        console.log("onAvatarUploadFinalized: Safe Search OK adult=", safeSearch.adult, "racy=", safeSearch.racy, "violence=", safeSearch.violence);
      } catch (err) {
        logError("onAvatarUploadFinalized: Vision API ERROR", err);
        return null;
      }

      const toReject =
        REJECT_LIKELIHOODS.includes(safeSearch.adult) ||
        REJECT_LIKELIHOODS.includes(safeSearch.racy) ||
        REJECT_LIKELIHOODS.includes(safeSearch.violence);

      if (!toReject) {
        console.log("onAvatarUploadFinalized: contenu OK, pas de rejet");
        let downloadUrl = null;
        const fileRef = admin.storage().bucket(bucket).file(name);
        try {
          downloadUrl = await getDownloadURL(fileRef);
        } catch (err) {
          logError("onAvatarUploadFinalized: getDownloadURL (OK) ERROR", err);
          try {
            const [url] = await fileRef.getSignedUrl({
              version: "v4",
              action: "read",
              expires: new Date(Date.now() + 10 * 365 * 24 * 60 * 60 * 1000),
            });
            downloadUrl = url;
          } catch (err2) {
            logError("onAvatarUploadFinalized: getSignedUrl (OK) fallback ERROR", err2);
          }
        }
        const update = {
          avatarModerationPending: admin.firestore.FieldValue.delete(),
          avatarModerationOk: true,
          avatarModerationRejected: admin.firestore.FieldValue.delete(),
          avatarModerationRejectedAt: admin.firestore.FieldValue.delete(),
          avatarModerationReason: admin.firestore.FieldValue.delete(),
        };
        if (downloadUrl) update.avatarUrl = downloadUrl;
        await db.collection("users").doc(uid).set(update, { merge: true });
        console.log(
          "onAvatarUploadFinalized: Firestore mis à jour (modération OK), avatarUrl=",
          !!downloadUrl,
        );
        return null;
      }

      const scores = {
        adult: safeSearch.adult,
        racy: safeSearch.racy,
        violence: safeSearch.violence,
      };
      console.log("onAvatarUploadFinalized: REJET uid=", uid, "name=", name, "scores=", scores);

      try {
        await admin.storage().bucket(bucket).file(name).delete();
        console.log("onAvatarUploadFinalized: fichier supprimé");
      } catch (err) {
        logError("onAvatarUploadFinalized: suppression fichier ERROR", err);
      }

      const rejectUpdate = {
        avatarUrl: admin.firestore.FieldValue.delete(),
        avatarModerationOk: false,
        avatarModerationRejected: true,
        avatarModerationRejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        avatarModerationReason: "Photo non conforme. Veuillez choisir une photo appropriée.",
        avatarModerationPending: admin.firestore.FieldValue.delete(),
      };
      await db.collection("users").doc(uid).set(rejectUpdate, { merge: true });
      console.log("onAvatarUploadFinalized: Firestore users mis à jour (rejet, avatarUrl effacé)");

      const logEntry = {
        uid,
        storagePath: name,
        bucket,
        scores,
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      try {
        await db.collection("avatar_moderation_logs").add(logEntry);
      } catch (e) {
        logError("onAvatarUploadFinalized: avatar_moderation_logs (optionnel) ERROR", e);
      }

      return null;
    } catch (err) {
      logError("onAvatarUploadFinalized: ERREUR INATTENDUE", err);
      throw err;
    }
  });
