# Notifications « Demande d'adhésion » – Vérifications

Si l’admin ne reçoit pas la notification quand un joueur fait une demande d’adhésion, vérifier les points suivants.

## 1. Cloud Function déployée

La fonction doit être déployée sur Firebase :

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Vérifier dans **Firebase Console → Functions** que la fonction `onJoinRequestCreated` apparaît et qu’elle n’a pas d’erreur.

## 2. Token FCM enregistré pour l’admin

Le token FCM est enregistré dans Firestore **uniquement quand l’admin ouvre l’app en étant connecté**.

- L’admin doit **ouvrir l’app au moins une fois** (connecté en tant qu’admin/coach) après la mise à jour du code.
- Dans **Firestore → Collection `users` → Document de l’admin** (même uid que le compte admin), vérifier qu’il existe un champ **`fcmToken`** (chaîne longue).

Si `fcmToken` est absent :

- Ouvrir l’app sur le téléphone admin, se connecter, laisser l’app ouverte quelques secondes.
- Vérifier que les notifications sont autorisées (Paramètres du téléphone → Apps → ViroTeam → Notifications).
- Sur Android 13+, accepter la demande de permission « Notifications » si elle s’affiche.

## 3. Club : admins / coaches

Dans **Firestore → Collection `clubs` → Document du club** concerné par la demande :

- Vérifier qu’il existe soit un tableau **`admins`** contenant l’uid de l’admin, soit un champ **`adminId`** avec cet uid.
- Si le club a des coaches, le tableau **`coaches`** peut aussi contenir des uid qui recevront la notif.

La Cloud Function envoie la notif à tous les uid listés dans `admins` et `coaches`, plus `adminId` s’il est présent.

## 4. Logs de la Cloud Function

Après une **nouvelle** demande d’adhésion (création d’un document dans `join_requests`) :

1. Aller dans **Firebase Console → Functions → onJoinRequestCreated → Logs**.
2. Vérifier qu’une entrée apparaît au moment de la demande (ex. « onJoinRequestCreated: déclenché, requestId=… »).
3. Regarder les messages suivants :
   - « recipientIds= […] » → liste des uid qui doivent recevoir la notif.
   - « pas de fcmToken pour uid= … » → cet utilisateur n’a pas de token (voir §2).
   - « aucun token FCM » → aucun des admins/coachs n’a de token.
   - « envoyé à X / Y tokens » → la notif a bien été envoyée à X appareils.

Si la fonction ne se déclenche pas : vérifier que la demande crée bien un **nouveau** document (`.add()`), et non un simple `.set()` sur un document existant.

## 5. Téléphone « éteint » ou app fermée

- **Écran éteint, app en arrière-plan ou fermée** : FCM peut quand même envoyer la notif ; le système l’affiche dans la barre de notification.
- **Téléphone vraiment éteint** : aucune notif ne peut être reçue.
- **Mode économie d’énergie / restrictions d’arrière-plan** (certains constructeurs) : peuvent retarder ou bloquer les notifs. Désactiver les restrictions pour ViroTeam si besoin.

## Résumé rapide

1. Déployer la fonction : `firebase deploy --only functions`
2. Admin ouvre l’app une fois (connecté) → token enregistré dans `users/{uid}.fcmToken`
3. Vérifier Firestore : `users/{admin_uid}.fcmToken` présent, `clubs/{club_id}.admins` ou `adminId` contient l’admin
4. Consulter les logs de la fonction après une nouvelle demande pour confirmer l’envoi ou identifier l’erreur
