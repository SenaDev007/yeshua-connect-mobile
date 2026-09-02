/// Recherche globale : messages, canaux, membres.
library;

import '../api/api_client.dart';
import '../models/search_models.dart';
class SearchRepository {
  final ApiClient _api = ApiClient.instance;

  SearchRepository();

  Future<SearchResults> rechercher(String q) async {
    final data = await _api.getJson(
      '/api/yeshua-connect/search',
      queryParameters: {'q': q},
    );
    if (data is Map) {
      return SearchResults.fromJson(Map<String, dynamic>.from(data));
    }
    return const SearchResults();
  }
}
