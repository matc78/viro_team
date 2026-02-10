/// Helper pour l'affichage des avatars après modération Vision (nudité/violence/racy).
///
/// Règle : n'afficher l'avatar que si l'URL est "OK" pour l'affichage.
/// - Backend efface [avatarUrl] au rejet (Option A) ; en succès il met [avatarModerationOk: true].
/// - Rétrocompatibilité : si [avatarModerationRejected] est true, ne pas afficher même si [avatarUrl] présent.
String? effectiveAvatarUrl(Map<String, dynamic>? userData) {
  if (userData == null) return null;
  if (userData['avatarModerationRejected'] == true) return null;
  final url = userData['avatarUrl'];
  if (url == null) return null;
  final s = url is String ? url.trim() : url.toString().trim();
  return s.isEmpty ? null : s;
}
