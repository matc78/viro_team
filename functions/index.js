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

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'un membre,
 * coach ou admin quitte le club (création dans member_leaves).
 */
exports.onMemberLeaveCreated = functions.firestore
  .document("clubs/{clubId}/member_leaves/{leaveId}")
  .onCreate(async (snap, context) => {
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
  });

/**
 * Envoie une notification FCM aux admins/coachs du club lorsqu'un prêt
 * est marqué comme retourné (equipment_loans status -> returned).
 */
exports.onEquipmentLoanUpdated = functions.firestore
  .document("clubs/{clubId}/equipment_loans/{loanId}")
  .onUpdate(async (change, context) => {
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
  });

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
exports.onAnnouncementCreated = functions.firestore
  .document("clubs/{clubId}/announcements/{announcementId}")
  .onCreate(async (snap, context) => {
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
  });

/**
 * Envoie une notification FCM aux membres concernés (teamMemberIds)
 * lorsqu'un nouvel événement est créé.
 */
exports.onEventCreated = functions.firestore
  .document("clubs/{clubId}/events/{eventId}")
  .onCreate(async (snap, context) => {
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
  });

/**
 * Envoie une notification FCM aux membres concernés lorsqu'un événement
 * est modifié (date, heure, titre, lieu ou liste des participants).
 */
exports.onEventUpdated = functions.firestore
  .document("clubs/{clubId}/events/{eventId}")
  .onUpdate(async (change, context) => {
    const { clubId, eventId } = context.params;
    const before = change.before.data();
    const after = change.after.data();

    const relevantFields = [
      "date",
      "dateId",
      "startTime",
      "endTime",
      "title",
      "type",
      "location",
      "teamMemberIds",
    ];
    const changed = relevantFields.some(
      (f) => JSON.stringify(after?.[f]) !== JSON.stringify(before?.[f])
    );
    if (!changed) {
      return null;
    }

    const teamMemberIds = Array.isArray(after.teamMemberIds)
      ? after.teamMemberIds.filter((id) => id && String(id).trim())
      : [];
    if (teamMemberIds.length === 0) {
      return null;
    }

    const title = String(after.title || "").trim() || null;
    const eventType = String(after.type || "Événement").trim();
    const teamName = String(after.teamName || "").trim();
    const dateId = String(after.dateId || "");
    const startTime = String(after.startTime || "");
    const location = String(after.location || "").trim();
    const clubName = String(after.clubName || "").trim();
    const displayTitle = title || eventType;

    const notifTitle = "Événement modifié";
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
      await messaging.sendEachForMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      return null;
    } catch (err) {
      console.error("onEventUpdated: erreur FCM", err);
      throw err;
    }
  });

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
 * pour les événements qui commencent dans 1 à 2 heures (fenêtre 1h).
 * Exécuté toutes les heures.
 */
exports.scheduledEventReminder = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("Europe/Paris")
  .onRun(async (context) => {
    const now = new Date();
    const inOneHour = new Date(now.getTime() + 60 * 60 * 1000);
    const inTwoHours = new Date(now.getTime() + 2 * 60 * 60 * 1000);

    const year = now.getUTCFullYear();
    const month = now.getUTCMonth();
    const day = now.getUTCDate();
    const todayStart = new Date(Date.UTC(year, month, day, 0, 0, 0, 0));
    const tomorrowEnd = new Date(Date.UTC(year, month, day + 2, 0, 0, 0, 0));

    const clubsSnap = await db.collection("clubs").get();
    const messaging = admin.messaging();
    let totalSent = 0;

    for (const clubDoc of clubsSnap.docs) {
      const clubId = clubDoc.id;
      const clubData = clubDoc.data();
      const clubName = String(clubData?.name || "").trim();

      const eventsSnap = await db
        .collection("clubs")
        .doc(clubId)
        .collection("events")
        .where("date", ">=", todayStart)
        .where("date", "<=", tomorrowEnd)
        .get();

      for (const eventDoc of eventsSnap.docs) {
        const eventId = eventDoc.id;
        const data = eventDoc.data();
        const date = data.date;
        if (!date || !date.toDate) {
          continue;
        }
        const dayStart = date.toDate();
        const startTimeStr = String(data.startTime || "").trim();
        const { hours, minutes } = parseStartTime(startTimeStr);
        const eventStart = new Date(
          Date.UTC(
            dayStart.getUTCFullYear(),
            dayStart.getUTCMonth(),
            dayStart.getUTCDate(),
            hours,
            minutes,
            0,
            0
          )
        );

        if (eventStart <= inOneHour || eventStart > inTwoHours) {
          continue;
        }

        const teamMemberIds = Array.isArray(data.teamMemberIds)
          ? data.teamMemberIds.filter((id) => id && String(id).trim())
          : [];
        if (teamMemberIds.length === 0) {
          continue;
        }

        const title = String(data.title || "").trim() || null;
        const eventType = String(data.type || "Événement").trim();
        const teamName = String(data.teamName || "").trim();
        const dateId = String(data.dateId || "");
        const startTime = String(data.startTime || "");
        const location = String(data.location || "").trim();
        const displayTitle = title || eventType;

        const notifTitle = "Rappel : " + displayTitle;
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
          continue;
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
            isReminder: "true",
          },
          android: { priority: "high" },
          apns: {
            payload: {
              aps: { sound: "default", badge: 1 },
            },
          },
        };

        try {
          const result = await messaging.sendEachForMulticast({
            tokens,
            notification: payload.notification,
            data: payload.data,
            android: payload.android,
            apns: payload.apns,
          });
          totalSent += result.successCount;
          console.log(
            "scheduledEventReminder: rappel envoyé eventId=",
            eventId,
            "à",
            result.successCount,
            "destinataire(s)",
          );
        } catch (err) {
          console.error("scheduledEventReminder: erreur FCM eventId=", eventId, err);
        }
      }
    }

    console.log(
      "scheduledEventReminder: terminé, total notifs envoyées=",
      totalSent,
    );
    return null;
  });
