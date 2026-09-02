/// ⭐ V1.5 — Annonces communautaires — miroir des routes web
/// `/api/yeshua-connect/announcements` :
///   GET  (auth)          → 20 dernières annonces des canaux ANNOUNCEMENT ;
///   POST (roles annonceurs) { title, body, channelId } → publication.
/// Rôles annonceurs (web) : SUPER_ADMIN / ADMIN / MODERATOR / ANIMATOR.
library;

import '../api/api_client.dart';
import '../models/announcement_model.dart';

class AnnouncementsRepository {
  final ApiClient _api = ApiClient.instance;

  AnnouncementsRepository();

  /// Les 20 dernières annonces (toutes pour tout membre authentifié).
  Future<List<AnnonceModel>> lister() async {
    final data = await _api.getJson('/api/yeshua-connect/announcements');
    if (data is List) {
      return data
          .whereType<Map>()
          .map((a) => AnnonceModel.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    }
    return const [];
  }

  /// Publie une annonce — `content` format web : « titre\n\ncorps ».
  Future<void> publier(String titre, String corps, String channelId) async {
    await _api.postJson(
      '/api/yeshua-connect/announcements',
      body: {'title': titre, 'body': corps, 'channelId': channelId},
    );
  }

  /// Tous les canaux visibles (le sélecteur filtra les ANNOUNCEMENT).
  Future<List<CanalModel>> canaux() async {
    final data = await _api.getJson('/api/yeshua-connect/channels');
    if (data is List) {
      return data
          .whereType<Map>()
          .map((c) => CanalModel.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }
    return const [];
  }
}
