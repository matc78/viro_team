# ViroTeam v2

Application Flutter refondue (invitation uniquement, multi-rôles).

## Lancer

```bash
cd v2
flutter pub get
flutter run
```

L’écran d’accueil actuel est un **aperçu du design system** (couleurs, typo, boutons, carte événement, badges rôles).

## Conventions

**Lire en priorité** : [`PROJECT_CONVENTIONS.md`](PROJECT_CONVENTIONS.md) (dont **§2 Thème & harmonisation** : `ViroScaffold`, fond dégradé, pas de bleu opaque).  
Constantes : `lib/config/project_config.dart`.

## Structure

```
lib/
  app/           # ViroApp (MaterialApp)
  config/        # Thème, motion, couleurs, project_config
  screens/       # Écrans (dev + features)
  widgets/
    common/      # ViroPressable, boutons flottants…
    lists/       # Tuiles ListView (obligatoire, pas d'inline)
  models/        # (à venir)
  services/      # (à venir)
  utils/         # firestore_instance → V2-dev
```

## Specs produit

Voir à la racine du monorepo :

- `viroheam_v2_design_system_final.md`
- `viroheam_v2_ux_journey_detailed.md`
- `viroheam_v2_invitation_only_model.md`
- `viroheam_v2_development_roadmap.md`

## Android (Gradle aligné sur v1)

La config Gradle de `v2/android/` reprend celle de la v1 :

- Plugins **Google Services** + **Firebase Crashlytics**
- AGP `8.9.1`, Kotlin `2.1.0`, Gradle `8.12`
- Signatures **release** (`key.properties`) et **debug** (`debug.keystore` / `debugViro`)

Fichiers à copier depuis la v1 (non versionnés) :

| Fichier v1 | Destination v2 |
|------------|----------------|
| `android/key.properties` | `v2/android/key.properties` |
| `android/app/debug.keystore` | `v2/android/app/debug.keystore` |
| `android/app/google-services.json` | `v2/android/app/google-services.json` |

Ou lancer `flutterfire configure` dans `v2/` pour régénérer `google-services.json`.

## Firestore v2

Créer la base **`V2-dev`** dans Firebase Console (projet `viroteam-75303`).  
L'app utilise `lib/utils/firestore_instance.dart` — jamais la base `default`.
