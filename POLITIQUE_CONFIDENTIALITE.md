# Politique de confidentialité – ViroTeam

**Dernière mise à jour :** 05/02/2026

## 1. Responsable du traitement

Les données à caractère personnel collectées via l’application **ViroTeam** sont traitées par :

**Matia Cilly (Développeur indépendant)**  
**Avenue du Général Leclerc   78220 Viroflay, France**  
**Email : matia.cilly@gmail.com**  
**Téléphone : 06 65 78 87 93**

Pour toute question relative à vos données personnelles ou à cette politique, vous pouvez nous contacter à l’adresse ci-dessus.

---

## 2. Données collectées et finalités

L’application ViroTeam permet la gestion de clubs et d’équipes sportives (joueurs, coachs, administrateurs). Nous collectons et traitons les données suivantes :

| Données                                                                    | Finalité                                                          | Base légale                                                |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------- |
| **Email, mot de passe**                                                    | Création de compte et authentification                            | Exécution du contrat (utilisation du service)              |
| **Nom, prénom, téléphone**                                                 | Identification et contact dans le cadre du club/équipe            | Exécution du contrat                                       |
| **Photo de profil (avatar)**                                               | Affichage dans l’application (équipes, événements, annonces)      | Exécution du contrat / consentement                        |
| **Rôles et appartenance aux clubs/équipes** (licence, catégories, équipes) | Gestion des membres, planning, événements                         | Exécution du contrat                                       |
| **Token de notification push (FCM)**                                       | Envoi de notifications (événements, demandes, prêts d’équipement) | Consentement (refusable dans les paramètres de l’appareil) |
| **Données techniques et logs d’erreurs** (Crashlytics)                     | Amélioration de la stabilité et du support                        | Intérêt légitime                                           |

Les **mots de passe** ne sont pas stockés en clair : ils sont gérés de manière sécurisée par Firebase Authentication.

Les données sont conservées **tant que votre compte est actif**. Après suppression du compte, les données sont effacées ou anonymisées dans les délais techniques et légaux (voir section 5).

---

## 3. Destinataires et hébergement

Vos données sont traitées avec les services suivants :

- **Google Firebase** (authentification, base de données Firestore, stockage de fichiers, notifications push, rapports de plantages) : hébergement et traitement par Google, susceptible d’impliquer des **transferts de données hors de l’Espace économique européen** (notamment vers les États-Unis). Google applique des garanties appropriées (clauses contractuelles types, etc.) conformément au droit européen.

Les données ne sont **pas vendues** à des tiers. Elles ne sont communiquées qu’aux personnes habilitées (équipe du responsable du traitement, administrateurs de club dans le cadre strict de leur rôle) et aux sous-traitants ci-dessus.

---

## 4. Sécurité

Nous mettons en œuvre des mesures techniques et organisationnelles pour protéger vos données :

- Authentification sécurisée (Firebase Auth)
- Règles d’accès Firestore limitant la lecture/écriture selon les rôles (admin, coach, joueur)
- Stockage des avatars et données sensibles sur des services sécurisés (Firebase)
- Utilisation de Crashlytics pour corriger les dysfonctionnements sans accéder au contenu de votre profil

---

## 5. Durée de conservation

- **Compte actif** : les données du profil et celles liées aux clubs/équipes sont conservées tant que le compte existe et que vous participez aux clubs.
- **Après suppression du compte** : suppression ou anonymisation des données personnelles dans les délais techniques et légaux (par ex. 30 jours à 3 mois selon les services). Certaines données peuvent être conservées plus longtemps si la loi l’exige (comptabilité, litiges).
- **Notifications** : le token FCM est supprimé ou invalidé lorsque vous désactivez les notifications ou supprimez le compte.
- **Crashlytics** : les rapports d’erreurs sont conservés selon la politique de Google Firebase/Crashlytics.

---

## 6. Vos droits (RGPD)

Vous disposez des droits suivants sur vos données personnelles :

- **Droit d’accès** : obtenir une copie des données que nous détenons sur vous.
- **Droit de rectification** : faire corriger des données inexactes ou incomplètes (une partie peut être modifiable directement dans l’application).
- **Droit à l’effacement** : demander la suppression de vos données, sous réserve des obligations légales.
- **Droit à la portabilité** : recevoir vos données dans un format structuré et couramment utilisé.
- **Droit d’opposition** : vous opposer à un traitement fondé sur l’intérêt légitime (ex. Crashlytics) ; pour les notifications push, vous pouvez les désactiver dans les paramètres de l’appareil.
- **Droit à la limitation du traitement** : demander que le traitement soit limité dans certains cas.
- **Droit de retirer votre consentement** : lorsque le traitement repose sur le consentement (ex. notifications), le retrait n’affecte pas la licéité du traitement antérieur.

Pour exercer ces droits, adressez une demande à l’adresse de contact indiquée au § 1, en précisant votre identité et l’objet de votre demande. Nous répondrons dans le délai légal (en général sous 1 mois).

Vous avez également le **droit d’introduire une réclamation** auprès de la CNIL : [https://www.cnil.fr](https://www.cnil.fr).

---

## 7. Données stockées sur l’appareil

L’application peut enregistrer localement sur votre appareil (via des mécanismes de type « stockage local ») :

- Préférences d’affichage et paramètres de l’application
- Données nécessaires au bon fonctionnement (ex. scores, minuteur dans le cadre des fonctionnalités sportives)

Ces données restent sur votre appareil et ne sont pas utilisées à des fins de publicité ou de profilage sans votre accord.

---

## 8. Modifications

Toute modification substantielle de cette politique sera portée à votre connaissance (par exemple via l’application ou par email). La date de dernière mise à jour figurant en tête du document sera actualisée. Nous vous encourageons à consulter régulièrement cette politique.

---

## 9. Résumé (conformité RGPD)

- **Responsable** : Matia Cilly (Viroflay, France)
- **Finalités** : gestion de compte, clubs et équipes, notifications, amélioration technique
- **Bases légales** : exécution du contrat, consentement (notifications), intérêt légitime (Crashlytics)
- **Destinataires** : responsable du traitement, administrateurs de club dans le cadre de leur rôle, Google Firebase (sous-traitant)
- **Transferts hors UE** : oui (Firebase/Google), avec garanties appropriées
- **Conservation** : durée du compte + délai technique et légal après suppression
- **Droits** : accès, rectification, effacement, portabilité, opposition, limitation, réclamation CNIL
- **Sécurité** : mesures techniques et organisationnelles (auth, règles d’accès, hébergement sécurisé)
