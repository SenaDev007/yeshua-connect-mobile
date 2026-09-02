/// Appels audio/vidéo — signalisation REST `calls/signal` (V3.1/V3.20)
/// + ARBITRAGE MULTIMÉDIA `calls/media` (⭐ V3.21 : LiveKit → Agora → Daily).
library;

import '../api/api_client.dart';
import '../models/call_model.dart';

/// ⭐ V3.21 — Bundle d'un fournisseur multimédia renvoyé par /calls/media
/// (miroir de la réponse web). `exhausted` = chaîne épuisée.
class MediaBundleModel {
  final String? provider; // livekit | agora | daily | null
  final bool exhausted;
  final String? reason;

  final String? livekitUrl;
  final String? livekitToken;

  final String? agoraAppId;
  final String? agoraToken;
  final String? agoraChannel;
  final int? agoraUid;

  final String? dailyUrl;
  final String? dailyToken;

  const MediaBundleModel({
    this.provider,
    this.exhausted = false,
    this.reason,
    this.livekitUrl,
    this.livekitToken,
    this.agoraAppId,
    this.agoraToken,
    this.agoraChannel,
    this.agoraUid,
    this.dailyUrl,
    this.dailyToken,
  });

  factory MediaBundleModel.fromJson(Map<String, dynamic> json) {
    final lk = json['livekit'] as Map<String, dynamic>?;
    final ag = json['agora'] as Map<String, dynamic>?;
    final dl = json['daily'] as Map<String, dynamic>?;
    return MediaBundleModel(
      provider: json['provider'] as String?,
      exhausted: json['exhausted'] == true,
      reason: json['reason'] as String?,
      livekitUrl: lk?['url'] as String?,
      livekitToken: lk?['token'] as String?,
      agoraAppId: ag?['appId'] as String?,
      agoraToken: ag?['token'] as String?,
      agoraChannel: ag?['channel'] as String?,
      agoraUid: (ag?['uid'] as num?)?.toInt(),
      dailyUrl: dl?['url'] as String?,
      dailyToken: dl?['token'] as String?,
    );
  }
}

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

  // ═══════════════════════════════════════════════════════════════════
  // ⭐ V3.21 — ARBITRAGE MULTIMÉDIA (LiveKit → Agora → Daily)
  // ═══════════════════════════════════════════════════════════════════

  /// Bundle du fournisseur ARBITRÉ pour cet appel (l'appelant et le
  /// destinataire rejoignent le MÊME réseau, même après un failover).
  Future<MediaBundleModel> rejoindreMedia(String callId) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/calls/media',
      body: {'action': 'join', 'callId': callId},
    );
    if (data is Map) {
      return MediaBundleModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Arbitrage multimédia indisponible.');
  }

  /// Signale l'échec d'un fournisseur → le serveur fait AVANCER l'appel au
  /// suivant (Agora après LiveKit, Daily après Agora) et renvoie le bundle.
  Future<MediaBundleModel> signalerEchecMedia(
    String callId,
    String fromProvider,
    String raison,
  ) async {
    final data = await _api.postJson(
      '/api/yeshua-connect/calls/media',
      body: {'action': 'failover', 'callId': callId, 'from': fromProvider, 'reason': raison},
    );
    if (data is Map) {
      return MediaBundleModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('Failover multimédia indisponible.');
  }
}
