# 🏐 ViroTeam - Application de Gestion d'Équipe Sportive

**ViroTeam** est une application mobile Flutter complète pour la gestion d'équipes sportives. Elle permet aux joueurs, entraîneurs et administrateurs de clubs de gérer leurs activités, calendriers, membres et communications de manière centralisée.

---

## 📋 Table des matières

- [Description](#-description)
- [Fonctionnalités](#-fonctionnalités)
- [Technologies utilisées](#-technologies-utilisées)
- [Prérequis](#-prérequis)
- [Installation](#-installation)
- [Configuration Firebase](#-configuration-firebase)
- [Lancement avec l'émulateur Android](#-lancement-avec-lémulateur-android-studio)
- [Structure du projet](#-structure-du-projet)
- [Architecture](#-architecture)

---

## 🎯 Description

ViroTeam est une plateforme de gestion sportive qui offre :

- **Gestion multi-rôles** : Un utilisateur peut être joueur, entraîneur et/ou administrateur dans plusieurs clubs simultanément
- **Gestion de clubs** : Création et administration de clubs sportifs
- **Planning** : Calendrier d'événements (entraînements, matches, réunions)
- **Gestion des membres** : Inscription, approbation et suivi des licenciés
- **Équipes multiples** : Gestion de plusieurs équipes par club (U11, U15, Seniors, etc.)
- **Communication** : Messaging et annonces au niveau du club
- **Profils personnalisés** : Gestion de profil avec photos et informations

---

## ✨ Fonctionnalités

### Pour les Joueurs (Licenciés)

- ✅ **Accueil personnalisé** : Vue d'ensemble des événements à venir et informations importantes
- ✅ **Planning** : Consultation du calendrier des entraînements et matches avec possibilité de marquer sa présence
- ✅ **Détails d'événements** : Informations complètes sur chaque événement (heure, lieu, équipe)
- ✅ **Mes équipes** : Vue de toutes les équipes auxquelles le joueur appartient
- ✅ **Profil** : Gestion de son profil personnel (photo, nom, numéro de licence)
- ✅ **Demande d'adhésion** : Possibilité de rejoindre un club en faisant une demande (statut en attente)
- ✅ **Multi-clubs** : Possibilité d'appartenir à plusieurs clubs simultanément

### Pour les Entraîneurs / Administrateurs

- ✅ **Tableau de bord** : Vue d'ensemble des demandes en attente, prochains événements et statistiques
- ✅ **Gestion des demandes** : Approbation ou refus des demandes d'adhésion de nouveaux membres
- ✅ **Planning** : Création et gestion des événements (entraînements, matches, réunions)
- ✅ **Gestion des membres** : Liste complète des membres, modification des informations, affectation aux équipes
- ✅ **Gestion des équipes** : Création et organisation des équipes (U11, U15, Seniors, etc.)
- ✅ **Communication du club** : Envoi de messages et annonces à tous les membres
- ✅ **Détails d'événements** : Vue complète avec liste des présents/absents et gestion des présences
- ✅ **Création de club** : Fonction pour créer un nouveau club (rôle Admin Fondateur)

### Fonctionnalités transversales

- ✅ **Authentification** : Connexion/Inscription via Firebase Authentication
- ✅ **Changement de profil** : Possibilité de basculer entre différents profils (joueur, coach, admin)
- ✅ **Multi-profils** : Support des utilisateurs ayant plusieurs rôles dans plusieurs clubs
- ✅ **Thème personnalisé** : Interface utilisateur moderne avec thème bleu et blanc
- ✅ **Localisation** : Interface en français avec support du formatage des dates

---

## 🛠 Technologies utilisées

### Framework et Langage
- **Flutter** 3.9.2+
- **Dart** (SDK ^3.9.2)

### Backend et Services
- **Firebase Authentication** : Gestion des utilisateurs et authentification
- **Cloud Firestore** : Base de données NoSQL pour le stockage des données
- **Firebase Storage** : Stockage des images de profil et médias

### Packages principaux
- `firebase_auth: ^6.1.3` - Authentification
- `cloud_firestore: ^6.1.1` - Base de données
- `firebase_storage: ^13.0.5` - Stockage de fichiers
- `cached_network_image: ^3.4.1` - Cache d'images réseau
- `table_calendar: ^3.2.0` - Widget calendrier
- `image_picker: ^1.2.1` - Sélection d'images depuis l'appareil
- `go_router: ^17.0.1` - Navigation (si utilisé)
- `intl: ^0.20.2` - Internationalisation et formatage de dates
- `font_awesome_flutter: ^10.12.0` - Icônes supplémentaires

### Plateformes supportées
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

---

## 📦 Prérequis

Avant de commencer, assurez-vous d'avoir installé :

1. **Flutter SDK** (version 3.9.2 ou supérieure)
   - Téléchargement : [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
   - Vérifier l'installation : `flutter doctor`

2. **Android Studio**
   - Téléchargement : [https://developer.android.com/studio](https://developer.android.com/studio)
   - Inclut le SDK Android et les outils nécessaires

3. **Android SDK** (via Android Studio)
   - SDK Platform-Tools
   - SDK Build-Tools

4. **Un émulateur Android** ou un appareil physique connecté
   - Configuration via Android Studio > AVD Manager

5. **Git** (pour cloner le projet)

6. **Compte Firebase** avec un projet configuré
   - Console Firebase : [https://console.firebase.google.com](https://console.firebase.google.com)

---

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone <url-du-repo>
cd viro_team
```

### 2. Installer les dépendances Flutter

```bash
flutter pub get
```

Cette commande télécharge et installe tous les packages listés dans `pubspec.yaml`.

### 3. Vérifier la configuration Flutter

```bash
flutter doctor
```

Assurez-vous que tous les composants sont correctement installés (marqués par ✓).

---

## 🔥 Configuration Firebase

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com)
2. Cliquez sur **"Ajouter un projet"** (ou utilisez un projet existant)
3. Suivez les étapes de création du projet
4. Notez le **Project ID** (ex: `viroteam-75303`)

### 2. Activer les services Firebase

Dans votre projet Firebase, activez :

- ✅ **Authentication**
  - Aller dans **Authentication** > **Sign-in method**
  - Activer **Email/Password**

- ✅ **Cloud Firestore**
  - Aller dans **Firestore Database**
  - Cliquer sur **Créer une base de données**
  - Choisir le mode **Production** ou **Test** (pour le développement)
  - Sélectionner une région (ex: `europe-west`)

- ✅ **Storage**
  - Aller dans **Storage**
  - Cliquer sur **Commencer**
  - Utiliser les règles par défaut (vous pouvez les ajuster plus tard)

### 3. Configurer Android

1. Dans Firebase Console, allez dans **Project Settings** (⚙️)
2. Cliquez sur l'icône Android
3. Entrez le **Package name** : `com.viroteam.viro_team`
4. Téléchargez le fichier `google-services.json`
5. Placez-le dans `android/app/google-services.json`

⚠️ **Important** : Le fichier `google-services.json` doit déjà être présent dans le projet. Si vous utilisez un nouveau projet Firebase, remplacez-le.

### 4. Générer les options Firebase (si nécessaire)

Si le fichier `lib/firebase_options.dart` n'existe pas ou doit être régénéré :

```bash
flutter pub add firebase_core
flutterfire configure
```

Suivez les instructions pour sélectionner votre projet Firebase et les plateformes.

---

## 📱 Lancement avec l'émulateur Android Studio

### 1. Démarrer l'émulateur Android

#### Méthode 1 : Via Android Studio

1. Ouvrez **Android Studio**
2. Cliquez sur **AVD Manager** (Android Virtual Device Manager)
   - Icône 📱 dans la barre d'outils, ou
   - Menu : **Tools** > **Device Manager**
3. Si aucun émulateur n'existe :
   - Cliquez sur **"Create Device"**
   - Choisissez un appareil (ex: **Pixel 5**)
   - Choisissez une image système (ex: **Android 13.0 - API 33**)
   - Cliquez sur **Finish**
4. Cliquez sur ▶️ **Play** pour démarrer l'émulateur

#### Méthode 2 : Via ligne de commande

```bash
# Lister les émulateurs disponibles
flutter emulators

# Lancer un émulateur spécifique
flutter emulators --launch <emulator_id>

# Exemple
flutter emulators --launch Pixel_5_API_33
```

### 2. Vérifier que l'émulateur est détecté

```bash
flutter devices
```

Vous devriez voir votre émulateur listé :
```
android • emulator-5554 • android-x86 • Android 13 (API 33)
```

### 3. Lancer l'application

#### Méthode 1 : Via Flutter CLI

```bash
# Lancer en mode debug (avec hot reload)
flutter run

# Spécifier l'émulateur explicitement
flutter run -d emulator-5554

# Lancer en mode release (plus rapide, pas de hot reload)
flutter run --release
```

#### Méthode 2 : Via Android Studio

1. Ouvrez le projet dans Android Studio
2. Sélectionnez l'émulateur dans la barre d'outils
3. Cliquez sur ▶️ **Run** (ou appuyez sur `Shift + F10`)

### 4. Hot Reload pendant le développement

Une fois l'app lancée :

- Appuyez sur **`r`** dans le terminal pour **hot reload**
- Appuyez sur **`R`** pour **hot restart**
- Appuyez sur **`q`** pour quitter

### 5. Dépannage courant

#### Problème : "No devices found"
```bash
# Vérifier les appareils connectés
flutter devices

# Redémarrer l'émulateur
# Ou vérifier que les outils Android SDK sont bien installés
flutter doctor
```

#### Problème : "google-services.json not found"
- Vérifiez que le fichier existe dans `android/app/google-services.json`
- Si nécessaire, téléchargez-le depuis Firebase Console

#### Problème : Build gradle errors
```bash
# Nettoyer le projet
flutter clean
flutter pub get

# Reconstruire
flutter build apk --debug
```

#### Problème : L'émulateur est lent
- Allouez plus de RAM à l'émulateur dans AVD Manager
- Activez **Hardware acceleration** (HAXM sur Windows/Linux, Hypervisor sur Mac)
- Réduisez la résolution de l'émulateur

---

## 📁 Structure du projet

```
viro_team/
├── android/              # Configuration Android
│   └── app/
│       └── google-services.json
├── ios/                  # Configuration iOS
├── lib/
│   ├── main.dart         # Point d'entrée de l'application
│   ├── firebase_options.dart  # Configuration Firebase
│   ├── models/           # Modèles de données
│   │   └── user_model.dart
│   ├── pages/            # Écrans de l'application
│   │   ├── auth_page.dart
│   │   ├── role_selection_page.dart
│   │   ├── multirole_selection_page.dart
│   │   ├── player_pages/     # Pages pour les joueurs
│   │   │   ├── player_home_page.dart
│   │   │   ├── player_planning_page.dart
│   │   │   ├── player_profil_page.dart
│   │   │   └── ...
│   │   └── admin_coach_pages/  # Pages pour admins/coaches
│   │       ├── admin_home_page.dart
│   │       ├── admin_planning_page.dart
│   │       ├── admin_members_page.dart
│   │       └── ...
│   ├── services/         # Services métier
│   │   └── user_session.dart
│   ├── theme/            # Thème de l'application
│   │   └── viro_theme.dart
│   ├── utils/            # Utilitaires
│   │   ├── firebase_error_handler.dart
│   │   └── firebase_helpers.dart
│   └── widget/           # Widgets réutilisables
│       ├── viro_loader.dart
│       └── profile_switcher_dialog.dart
├── assets/               # Ressources (images, logos)
│   └── logo/
├── pubspec.yaml          # Dépendances et configuration
└── README.md            # Ce fichier
```

---

## 🏗 Architecture

### Modèle de données utilisateur

L'application utilise un système de **rôles multiples** permettant à un utilisateur d'avoir plusieurs profils :

```dart
{
  "uid": "user123",
  "email": "user@example.com",
  "activeContext": {
    "role": "player",      // 'player', 'coach', ou 'admin'
    "clubId": "club123"
  },
  "roles": {
    "player": {
      "clubs": [
        {
          "clubId": "club123",
          "teamIds": ["u15", "senior"],
          "license": "12345"
        }
      ]
    },
    "coach": [
      {
        "clubId": "club456",
        "teams": ["u11"]
      }
    ],
    "admin": ["club789"]
  }
}
```

### Flux d'authentification

1. **AuthPage** : Connexion/Inscription
2. **RoleSelectionPage** : Choix du rôle initial (créer club, rejoindre comme joueur/coach)
3. **MultiRoleSelectionPage** : Si plusieurs profils existent, sélection du profil actif
4. **PlayerHomePage** ou **AdminHomePage** : Page d'accueil selon le rôle

### Gestion des clubs

- Les clubs sont stockés dans la collection `clubs`
- Chaque club contient :
  - Informations générales (nom, logo, etc.)
  - Collections `teams` (équipes)
  - Collections `events` (événements)
  - Collections `members` (membres)

### Événements (Planning)

Les événements sont stockés dans `clubs/{clubId}/events` et contiennent :
- Type (entraînement, match, réunion)
- Date et heure
- Équipe concernée
- Lieu
- Liste des présences (`attendance`)

---

## 🎨 Interface utilisateur

L'application utilise un thème personnalisé **bleu et blanc** défini dans `lib/theme/viro_theme.dart`. Les couleurs principales sont :

- **Primary** : Bleu (`#1E88E5`)
- **Background** : Blanc/Gris clair (`#F8F9FA`)
- **Accent** : Variations de bleu

---

## 🔐 Sécurité et règles Firestore

⚠️ **Important** : Pour la production, configurez les règles de sécurité Firestore dans Firebase Console :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règles de base - À personnaliser selon vos besoins
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /clubs/{clubId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // À restreindre selon les rôles
    }
  }
}
```

---

## 📝 Notes de développement

- L'application utilise principalement **StreamBuilder** pour l'écoute en temps réel des données Firestore
- Les images de profil sont stockées dans Firebase Storage et mises en cache localement
- Le formatage des dates utilise la locale française (`fr_FR`)

---

## 🤝 Contribution

Ce projet est privé. Pour toute contribution, contactez l'équipe de développement.

---

## 📄 Licence

[Spécifier la licence si applicable]

---

## 📞 Support

Pour toute question ou problème :

1. Vérifiez les logs dans la console Flutter
2. Consultez la documentation Firebase
3. Vérifiez que tous les services Firebase sont activés
4. Contactez l'équipe de développement

---

**Dernière mise à jour** : 2024

**Version** : 1.0.0+1
