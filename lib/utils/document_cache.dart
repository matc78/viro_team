import 'package:cloud_firestore/cloud_firestore.dart';

/// Cache simple pour les documents Firestore au niveau de l'application
/// Évite les requêtes redondantes pour le même document dans la même session
class DocumentCache {
  DocumentCache._(); // Constructeur privé pour empêcher l'instanciation

  static final Map<String, _CachedDocument> _cache = {};
  static const Duration defaultCacheDuration = Duration(minutes: 5);

  /// Récupère un document depuis le cache ou Firestore
  /// 
  /// [path] : Chemin du document (ex: "users/user123" ou "clubs/club456")
  /// [cacheDuration] : Durée de validité du cache (par défaut 5 minutes)
  /// [forceRefresh] : Force le rafraîchissement même si le document est en cache
  static Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String path, {
    Duration cacheDuration = defaultCacheDuration,
    bool forceRefresh = false,
  }) async {
    // Vérifier le cache si pas de force refresh
    if (!forceRefresh && _isCached(path, cacheDuration)) {
      return _cache[path]!.document;
    }

    // Récupérer depuis Firestore
    final docRef = FirebaseFirestore.instance.doc(path);
    final doc = await docRef.get();

    // Mettre en cache
    _cacheDocument(path, doc, cacheDuration);

    return doc;
  }

  /// Récupère plusieurs documents en batch depuis le cache ou Firestore
  /// 
  /// [paths] : Liste des chemins des documents
  /// [cacheDuration] : Durée de validité du cache
  /// [forceRefresh] : Force le rafraîchissement
  static Future<List<DocumentSnapshot<Map<String, dynamic>>>> getDocuments(
    List<String> paths, {
    Duration cacheDuration = defaultCacheDuration,
    bool forceRefresh = false,
  }) async {
    final results = <DocumentSnapshot<Map<String, dynamic>>>[];
    final pathsToFetch = <String>[];

    // Vérifier le cache pour chaque document
    for (final path in paths) {
      if (!forceRefresh && _isCached(path, cacheDuration)) {
        results.add(_cache[path]!.document);
      } else {
        pathsToFetch.add(path);
      }
    }

    // Récupérer les documents manquants depuis Firestore
    if (pathsToFetch.isNotEmpty) {
      final futures = pathsToFetch.map((path) => 
        FirebaseFirestore.instance.doc(path).get()
      );
      final fetchedDocs = await Future.wait(futures);

      // Mettre en cache et ajouter aux résultats
      for (int i = 0; i < pathsToFetch.length; i++) {
        final path = pathsToFetch[i];
        final doc = fetchedDocs[i];
        _cacheDocument(path, doc, cacheDuration);
        results.add(doc);
      }
    }

    // Retourner dans l'ordre original
    final resultMap = {
      for (var doc in results) _getPathFromDoc(doc): doc,
    };
    return paths.map((path) => resultMap[path]!).toList();
  }

  /// Invalide le cache pour un document spécifique
  static void invalidate(String path) {
    _cache.remove(path);
  }

  /// Invalide tout le cache
  static void clear() {
    _cache.clear();
  }

  /// Vérifie si un document est en cache et valide
  static bool _isCached(String path, Duration cacheDuration) {
    if (!_cache.containsKey(path)) {
      return false;
    }

    final cached = _cache[path]!;
    final now = DateTime.now();
    return now.difference(cached.cachedAt) < cacheDuration;
  }

  /// Met un document en cache
  static void _cacheDocument(
    String path,
    DocumentSnapshot<Map<String, dynamic>> document,
    Duration cacheDuration,
  ) {
    _cache[path] = _CachedDocument(
      document: document,
      cachedAt: DateTime.now(),
    );
  }

  /// Extrait le chemin d'un document
  static String _getPathFromDoc(DocumentSnapshot doc) {
    return doc.reference.path;
  }
}

/// Document mis en cache avec sa date de cache
class _CachedDocument {
  final DocumentSnapshot<Map<String, dynamic>> document;
  final DateTime cachedAt;

  _CachedDocument({
    required this.document,
    required this.cachedAt,
  });
}
