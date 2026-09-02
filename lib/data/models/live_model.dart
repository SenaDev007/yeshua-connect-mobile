/// ⭐ V1.5 — Modèles du LIVE PUBLIC (parité web V3.22 — mode YouTube).
///
/// Le viewer mobile consomme EXACTEMENT les mêmes routes publiques que le
/// site : `/api/live/active`, `/api/live/next` (pause), `/api/live/[id]/stream`
/// (bundle de livraison), `/api/live/[id]/chat`, `/api/live/[id]/viewers`.
/// Aucune room LiveKit n'est rejointe en mode HLS : seul le diffuseur compte
/// comme participant — les viewers regardent, comme sur YouTube.
library;

/// Un live (réponses de `/api/live/active`, `/api/live/next`, `/upcoming`).
class LiveStreamModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? startedAt;
  final DateTime? scheduledAt;
  final String status; // LIVE | SCHEDULED | ENDED | …
  final String? servantName;
  final String? servantPortraitUrl;
  final String? youtubeUrl;
  final int viewerCount;
  final String? thumbnailUrl;

  /// ⭐ V3.22 web : pause PERSISTÉE en base (visible par TOUS les modes,
  /// y compris HLS/YouTube) — rafraîchie par le polling `/api/live/next`.
  final bool isPaused;
  final DateTime? pausedAt;

  const LiveStreamModel({
    required this.id,
    required this.title,
    this.description,
    this.startedAt,
    this.scheduledAt,
    required this.status,
    this.servantName,
    this.servantPortraitUrl,
    this.youtubeUrl,
    this.viewerCount = 0,
    this.thumbnailUrl,
    this.isPaused = false,
    this.pausedAt,
  });

  bool get estEnCours => status == 'LIVE';

  /// Durée affichée : figée sur (pausedAt - startedAt) pendant la pause,
  /// exactement comme le viewer web (sinon l'horloge continue).
  int get dureeSecondes {
    final debut = startedAt;
    if (debut == null) return 0;
    final fin = isPaused ? pausedAt : DateTime.now();
    if (fin == null) return 0;
    return fin.difference(debut).inSeconds.clamp(0, 1 << 40);
  }

  factory LiveStreamModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return LiveStreamModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'Direct',
      description: json['description'] as String?,
      startedAt: parse(json['startedAt']),
      scheduledAt: parse(json['scheduledAt']),
      status: (json['status'] as String?) ?? '',
      servantName: json['servantName'] as String?,
      servantPortraitUrl: json['servantPortraitUrl'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      isPaused: json['isPaused'] as bool? ?? false,
      pausedAt: parse(json['pausedAt']),
    );
  }
}

/// Message du chat public du live — visiteurs anonymes autorisés (comme le
/// web) : le nom affiché est libre, l'auth n'est PAS requise sur cette route.
class LiveChatMessageModel {
  final String id;
  final String userName;
  final String content;
  final String type; // "message" | "reaction"
  final String? emoji;
  final int likeCount;
  final DateTime createdAt;

  const LiveChatMessageModel({
    required this.id,
    required this.userName,
    required this.content,
    required this.type,
    this.emoji,
    this.likeCount = 0,
    required this.createdAt,
  });

  bool get estReaction => type == 'reaction';

  factory LiveChatMessageModel.fromJson(Map<String, dynamic> json) {
    return LiveChatMessageModel(
      id: json['id'] as String,
      userName: (json['userName'] as String?) ?? 'Visiteur',
      content: (json['content'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'message',
      emoji: json['emoji'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Bundle de livraison viewer — réponse de `GET /api/live/[id]/stream`
/// (V3.22 web). `mode` décide COMMENT le viewer regarde :
///   - `hls`    : mode YouTube — playlist(s) HLS, 0 participant facturé ;
///   - `webrtc` : spectateur LiveKit (repli si l'egress HLS échoue) ;
///   - `agora`  : rôle AUDIENCE (reçoit, n'interagit jamais) ;
///   - `daily`  : room prebuilt (dernier repli) ;
///   - `off`    : le live n'est pas en cours.
class LiveStreamBundleModel {
  final String mode;
  final String? provider;
  final String? reason;
  final List<String> hlsUrls;
  final String? livekitUrl;
  final String? livekitToken;
  final String? agoraAppId;
  final String? agoraChannel;
  final String? agoraToken;
  final int? agoraUid;
  final String? dailyUrl;
  final String? dailyToken;

  const LiveStreamBundleModel({
    required this.mode,
    this.provider,
    this.reason,
    this.hlsUrls = const [],
    this.livekitUrl,
    this.livekitToken,
    this.agoraAppId,
    this.agoraChannel,
    this.agoraToken,
    this.agoraUid,
    this.dailyUrl,
    this.dailyToken,
  });

  bool get estHls => mode == 'hls';
  bool get estWebrtc => mode == 'webrtc';
  bool get estAgora => mode == 'agora';
  bool get estDaily => mode == 'daily';
  bool get estEteint => mode == 'off';

  factory LiveStreamBundleModel.fromJson(Map<String, dynamic> json) {
    final hls = json['hls'];
    return LiveStreamBundleModel(
      mode: (json['mode'] as String?) ?? 'off',
      provider: json['provider'] as String?,
      reason: json['reason'] as String?,
      hlsUrls: hls is Map && hls['urls'] is List
          ? (hls['urls'] as List).map((u) => u.toString()).toList()
          : const [],
      livekitUrl: json['livekit'] is Map
          ? json['livekit']['url'] as String?
          : null,
      livekitToken: json['livekit'] is Map
          ? json['livekit']['token'] as String?
          : null,
      agoraAppId: json['agora'] is Map ? json['agora']['appId'] as String? : null,
      agoraChannel:
          json['agora'] is Map ? json['agora']['channel'] as String? : null,
      agoraToken: json['agora'] is Map ? json['agora']['token'] as String? : null,
      agoraUid: json['agora'] is Map
          ? (json['agora']['uid'] as num?)?.toInt()
          : null,
      dailyUrl: json['daily'] is Map ? json['daily']['url'] as String? : null,
      dailyToken:
          json['daily'] is Map ? json['daily']['token'] as String? : null,
    );
  }
}
