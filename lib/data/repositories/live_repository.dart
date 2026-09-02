/// ⭐ V1.5 — LIVE PUBLIC : dépôt miroir des routes publiques du site
/// (`/api/live/*`, V3.22). Le viewer mobile suit le MÊME arbitrage serveur
/// que le web : le studio décide du fournisseur (LiveKit → Agora → Daily),
/// les viewers pollent `/api/live/[id]/stream` et suivent (≤ 12 s).
///
/// ⭐ MODE YOUTUBE : en mode HLS le viewer ne rejoint AUCUNE room —
/// 0 participant, 0 interaction, 0 facturation LiveKit côté viewers.
/// Seul le diffuseur (studio) compte comme participant.
library;

import '../api/api_client.dart';
import '../models/live_model.dart';

class LiveRepository {
  final ApiClient _api = ApiClient.instance;

  LiveRepository();

  /// Le live EN COURS (null si aucun) — `GET /api/live/active`.
  Future<LiveStreamModel?> actif() async {
    final data = await _api.getJson('/api/live/active');
    if (data is Map && data['live'] is Map) {
      return LiveStreamModel.fromJson(
        Map<String, dynamic>.from(data['live'] as Map),
      );
    }
    return null;
  }

  /// Prochain live programmé + état de pause rafraîchi — `GET /api/live/next`
  /// (source de vérité de la pause pour les viewers HLS/YouTube, polling 3 s).
  Future<LiveStreamModel?> suivant() async {
    final data = await _api.getJson('/api/live/next');
    if (data is Map && data['live'] is Map) {
      return LiveStreamModel.fromJson(
        Map<String, dynamic>.from(data['live'] as Map),
      );
    }
    return null;
  }

  /// Lives programmés + en cours (bannière d'accueil) — `GET /api/live/upcoming`.
  Future<List<LiveStreamModel>> prochains() async {
    final data = await _api.getJson('/api/live/upcoming');
    if (data is Map && data['lives'] is List) {
      return (data['lives'] as List)
          .whereType<Map>()
          .map((l) => LiveStreamModel.fromJson(Map<String, dynamic>.from(l)))
          .toList();
    }
    return const [];
  }

  /// Bundle de livraison viewer — `GET /api/live/[id]/stream` (PUBLIC).
  /// Décide du mode (hls | webrtc | agora | daily | off) selon l'arbitrage
  /// serveur V3.22 — polling 12 s, comme le viewer web.
  Future<LiveStreamBundleModel> flux(String liveId) async {
    final data = await _api.getJson('/api/live/$liveId/stream');
    if (data is Map) {
      return LiveStreamBundleModel.fromJson(Map<String, dynamic>.from(data));
    }
    return const LiveStreamBundleModel(mode: 'off', reason: 'Flux indisponible');
  }

  /// Messages du chat public — `GET /api/live/[id]/chat?since=<iso>`
  /// (les 50 derniers sans `since`, incrémental avec — polling 4 s).
  Future<List<LiveChatMessageModel>> chat(String liveId, {String? since}) async {
    final query = <String, dynamic>{if (since != null) 'since': since};
    final data =
        await _api.getJson('/api/live/$liveId/chat', queryParameters: query);
    if (data is Map && data['messages'] is List) {
      return (data['messages'] as List)
          .whereType<Map>()
          .map((m) => LiveChatMessageModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  /// Envoie un message du chat public — PAS d'auth requise (visiteurs
  /// anonymes, comme le web) ; [userName] = nom affiché.
  Future<void> envoyerChat(String liveId, String userName, String content) async {
    await _api.postJson(
      '/api/live/$liveId/chat',
      body: {'userName': userName, 'content': content},
    );
  }

  /// Envoie une RÉACTION (❤️ 🙏 ✋ 🔥) — même route, `type: "reaction"`.
  Future<void> reagir(String liveId, String userName, String emoji) async {
    await _api.postJson(
      '/api/live/$liveId/chat',
      body: {
        'userName': userName,
        'content': emoji,
        'type': 'reaction',
        'emoji': emoji,
      },
    );
  }

  /// Compteur de viewers RÉEL — `GET /api/live/[id]/viewers` ({count},
  /// fenêtre de fraîcheur 90 s, heartbeat 25 s).
  Future<int> compterViewers(String liveId) async {
    final data = await _api.getJson('/api/live/$liveId/viewers');
    if (data is Map && data['count'] is num) {
      return (data['count'] as num).toInt();
    }
    return 0;
  }

  /// Heartbeat de présence — `POST /api/live/[id]/viewers` {memberId}.
  /// [memberId] = id NextAuth : le serveur résout/crée le LiveMember
  /// correspondant (sessionId "user-<id>") — V2.9 web.
  Future<void> heartbeat(String liveId, String memberId) async {
    await _api.postJson(
      '/api/live/$liveId/viewers',
      body: {'memberId': memberId},
    );
  }

  /// Quitte le live (compteur immédiat) — `DELETE /api/live/[id]/viewers?memberId=`.
  Future<void> quitter(String liveId, String memberId) async {
    await _api.deleteJson(
      '/api/live/$liveId/viewers',
      queryParameters: {'memberId': memberId},
    );
  }
}
