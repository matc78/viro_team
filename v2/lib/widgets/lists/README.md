# Tuiles de liste réutilisables

Chaque type de ligne affiché dans un `ListView` vit ici :

- `event_list_tile.dart`
- `roster_list_tile.dart`
- `invite_list_tile.dart`
- etc.

Les écrans dans `features/*/screens/` importent ces tuiles — pas de `itemBuilder` inline volumineux.
