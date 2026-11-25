/// Repository Bibliothèque — récupère les livres depuis l'API publique.
///
/// ⭐ V4.38 — Bibliothèque documentaire mobile.
/// API : GET /api/books (publique, pas d'auth requise).
import '../api/api_client.dart';
import '../models/book_model.dart';

class BibliothequeRepository {
  final ApiClient _api = ApiClient.instance;

  /// Récupère tous les livres publiés.
  /// Filtre optionnel par catégorie ou serviteur.
  Future<List<BookModel>> tous({
    String? category,
    String? servantCode,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (servantCode != null) params['servantCode'] = servantCode;

    final query = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
        : '';

    try {
      final data = await _api.getJson('/api/books$query');
      if (data is Map && data['books'] is List) {
        return (data['books'] as List)
            .map((b) => BookModel.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList();
      }
    } catch (e) {
      // best-effort — retourne une liste vide en cas d'erreur réseau
    }
    return [];
  }
}
