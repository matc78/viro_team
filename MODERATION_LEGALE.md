# Modération des contenus et conformité légale – ViroTeam

**Dernière mise à jour :** Février 2026

Ce document décrit la politique de modération des contenus utilisateur (notamment les photos de profil), la procédure de signalement et les références légales applicables.

---

## 1. Politique de modération des avatars

ViroTeam modère les **photos de profil (avatars)** afin de garantir un environnement conforme à la loi et aux règles de la communauté.

### 1.1 Contenus concernés

- **Nudité et contenu à caractère sexuel** : les images détectées comme « adulte » ou « suggestives » (racy) au-delà d’un seuil défini sont rejetées.
- **Violence** : les images contenant des contenus violents au-delà du seuil défini sont rejetées.
- **Contenu illégal** : tout contenu illégal (notamment à caractère pédopornographique ou relevant d’autres infractions) doit être signalé et ne doit pas être diffusé. La modération technique (détection automatique) complète mais ne remplace pas les obligations légales de signalement.

### 1.2 Moyens techniques

- **Modération automatique** : chaque avatar uploadé est analysé par l’API Google Cloud Vision (Safe Search). Si les scores « adulte », « racy » ou « violence » atteignent le seuil **LIKELY** ou **VERIFIED**, l’image est supprimée du stockage et l’avatar de l’utilisateur est réinitialisé. L’utilisateur est informé dans l’application.
- Cette modération technique **ne couvre pas à elle seule** les obligations légales (signalement aux autorités, conservation dans certains cas, etc.). Elle vise à limiter la diffusion de contenus inappropriés.

### 1.3 Traçabilité des rejets

- Chaque rejet d’avatar fait l’objet de **logs structurés** (identifiant utilisateur, chemin du fichier, date, scores de modération).
- Une collection Firestore **avatar_moderation_logs** peut être utilisée pour enregistrer les rejets (à des fins d’audit ou de réponse aux autorités). L’accès à cette collection est restreint (rôles admin / support).
- **Durée de conservation des logs** : 1 an à compter de la date du rejet, sauf obligation légale ou demande des autorités exigeant une conservation différente.

---

## 2. Procédure de signalement pour les utilisateurs

Tout utilisateur ou tiers peut signaler un contenu qu’il estime illégal ou contraire aux règles.

### 2.1 Comment signaler

- **Par email** : matia.cilly@gmail.com (objet : « Signalement contenu – ViroTeam »).
- Indiquez si possible : type de contenu (avatar, message, etc.), identifiant ou pseudo de l’utilisateur concerné, description du contenu, date et contexte.

### 2.2 Engagement du responsable du traitement

- Les signalements sont **traités dans les meilleurs délais**.
- Les contenus manifestement illégaux seront **retirés** et, le cas échéant, **signalés aux autorités compétentes** (voir section 3).
- Nous nous engageons à **coopérer avec les autorités** en cas de demande légale (conservation de données, communication d’informations dans le cadre légal).

### 2.3 Lien depuis l’application

Il est recommandé d’ajouter dans l’application un lien vers cette procédure (par exemple dans les paramètres, la politique de confidentialité ou les CGU) : **« Signaler un contenu »** pointant vers ce document ou une page dédiée.

---

## 3. Références légales et autorités compétentes

### 3.1 Droit applicable

- **France / Union européenne** : LCEN (Loi pour la confiance dans l’économie numérique), RGPD, droit pénal (notamment infractions à caractère sexuel, exploitation des mineurs, apologie du terrorisme, etc.).
- En tant qu’hébergeur de contenus utilisateur, le responsable du traitement peut être soumis aux obligations de retrait de contenus illégaux et, selon les cas, de signalement.

### 3.2 Signalement aux autorités

- **France** : plateforme **PHAROS** (Plateforme d’Harmonisation, d’Analyse, de Recoupement et d’Orientation des Signalements) – [internet-signalement.gouv.fr](https://www.internet-signalement.gouv.fr/).
- **Contenu pédopornographique** : signalement à PHAROS et, le cas échéant, aux dispositifs prévus par la loi (ex. dispositifs avec NCMEC à l’international, selon les cas).
- Toute décision de signalement ou de conservation de données au-delà des durées habituelles sera prise en conformité avec le droit applicable et, si besoin, avec l’avis d’un conseil juridique.

### 3.3 Contenu illégal

La modération technique (Safe Search) aide à détecter des contenus « adulte » ou « violents » mais **ne dispense pas** de :
- mettre en place une **procédure de signalement** (présente dans ce document) ;
- **retirer** les contenus illégaux dès qu’ils sont portés à notre connaissance ;
- **signaler** aux autorités compétentes lorsque la loi l’exige ou le recommande.

---

## 4. Contact

Pour toute question relative à la modération ou à ce document :

**Matia Cilly**  
Avenue du Général Leclerc, 78220 Viroflay, France  
Email : matia.cilly@gmail.com  
Téléphone : 06 65 78 87 93
