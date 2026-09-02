/// Appels audio/vidéo — signalisation REST `calls/signal` (V3.1/V3.20).
///
/// Le média transite par le web (LiveKit / WebRTC P2P) ; le mobile gère
/// la SONNERIE, l'acceptation, le refus, le raccroché et le statut
/// distant — exactement la même machine à états que le web.
library;

import '../api/api_client.dart';
import '../models/call_model.dart';
class CallsRepository {
  final ApiClient _api = ApiClient.instance;

  CallsRepository();

  /// Lance un appel (bouton 📞/🎥 d'une conversation).
  Future<StartedCallModel> demarrer(String conversationId, {bool video = false}) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/calls/signal',
      body: {
        'action': 'start',
        'conversationId': conversationId,
        'type': video ? 'video' : 'audio',
      },
    );
    if (data is Map) {
      return StartedCallModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Impossible de lancer l\'appel.');
  }

  /// Appels qui SONNENT pour moi (polling 3 s) — ⭐ V3.20 : chaque entrée
  /// porte `isDirect` + `initiatorName`/`initiatorAvatarUrl`, la base du
  /// correctif V1.1 (titre = l'APPELANT sur un privé).
  Future<List<IncomingCallModel>> entrants() async {
    final data = await _api.getJson(
      '/api/yeshua-connect/calls/signal',
      queryParameters: {'incoming': '1'},
    );
    if (data is Map && data['incoming'] is List) {
      return (data['incoming'] as List)
          .map((c) => IncomingCallModel.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
    }
    return const [];
  }

  /// Statut distant d'un appel (polling 2 s pendant l'appel).
  Future<CallStatusModel> statut(String callId) async {
    final data = await _api.getJson(
      '/api/yeshua-connect/calls/signal',
      queryParameters: {'callId': callId},
    );
    if (data is Map) {
      return CallStatusModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Appel introuvable.');
  }

  /// Décroche.
  Future<void> accepter(String callId) async {
    await _api.postJson('/api/yeshua-connect/calls/signal', body: {
      'action': 'accept',
      'callId': callId,
    });
  }

  /// Refuse (termine l'appel sur un DIRECT — signalisation serveur).
  Future<void> refuser(String callId) async {
    await _api.postJson('/api/yeshua-connect/calls/signal', body: {
      'action': 'decline',
      'callId': callId,
    });
  }

  /// Raccroche / annule.
  Future<void> raccrocher(String callId) async {
    await _api.postJson('/api/yeshua-connect/calls/signal', body: {
      'action': 'end',
      'callId': callId,
    });
  }
}
