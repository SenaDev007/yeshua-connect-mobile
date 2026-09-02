/// ⭐⭐ V1.5 — CONTRÔLEUR DU LIVE PUBLIC (VIEWER) ⭐⭐
/// ============================================================================
/// Écran viewer du live, MÊME orchestration que le site web V3.22 :
///
///   1. `GET /api/live/[id]/stream` (PUBLIC) toutes les 12 s → le SERVEUR
///      décide du mode : `hls` (YouTube : 0 participant facturé — le viewer
///      ne rejoint AUCUNE room) | `webrtc` (repli local) | `agora`
///      (AUDIENCE : reçoit, n'interagit jamais) | `daily` (room prebuilt).
///      Le studio fait avancer la chaîne LiveKit → Agora → Daily : les
///      viewers suivent automatiquement (bascule ≤ 12 s).
///   2. `GET /api/live/next` toutes les 3 s → pause persistée en base,
///      visible par TOUS les modes (comme les viewers YouTube du web).
///   3. `GET /api/live/[id]/chat` toutes les 4 s → chat public (visiteurs
///      anonymes autorisés — route sans auth, comme le web).
///   4. `POST /api/live/[id]/viewers` toutes les 25 s → heartbeat du
///      compteur RÉEL de viewers (fenêtre de fraîcheur 90 s).
///
/// ⭐ MODE YOUTUBE — exigence du pasteur : les viewers ne SONT PAS des
/// participants. Ils regardent, ne publient rien, n'ouvrent pas leur micro
/// ou caméra — aucune permission média n'est demandée dans les modes
/// hls/agora/daily ; en webrtc le token serveur interdit la publication
/// (canPublish: false) et l'app ne publie rien non plus.
/// ============================================================================
library;

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/models/live_model.dart';
import '../data/repositories/live_repository.dart';

/// Mode d'affichage courant du viewer.
enum LiveViewerMode { chargement, hls, webrtc, agora, daily, eteint, erreur }

extension LiveViewerModeX on LiveViewerMode {
  String get libelle {
    switch (this) {
      case LiveViewerMode.hls:
        return 'YouTube';
      case LiveViewerMode.webrtc:
        return 'WebRTC';
      case LiveViewerMode.agora:
        return 'Agora (audience)';
      case LiveViewerMode.daily:
        return 'Daily';
      case LiveViewerMode.eteint:
        return 'Hors direct';
      case LiveViewerMode.erreur:
        return 'Erreur';
      case LiveViewerMode.chargement:
        return '…';
    }
  }
}

/// État du viewer.
class LiveViewerState {
  final LiveStreamModel? live;
  final LiveStreamBundleModel? bundle;
  final LiveViewerMode mode;
  final String? raison;
  final List<LiveChatMessageModel> messages;
  final int nbViewers;
  final bool enPause;
  final bool envoiChatEnCours;
  final String? erreur;

  /// Lecteur HLS (mode YouTube) — géré par le contrôleur.
  final VideoPlayerController? controleurHls;

  /// Piste vidéo distante LiveKit (mode webrtc — repli local).
  final RemoteVideoTrack? pisteVideoLiveKit;

  /// uid distant Agora (mode audience).
  final int? uidAgora;

  const LiveViewerState({
    this.live,
    this.bundle,
    this.mode = LiveViewerMode.chargement,
    this.raison,
    this.messages = const [],
    this.nbViewers = 0,
    this.enPause = false,
    this.envoiChatEnCours = false,
    this.erreur,
    this.controleurHls,
    this.pisteVideoLiveKit,
    this.uidAgora,
  });

  LiveViewerState copyWith({
    LiveStreamModel? live,
    LiveStreamBundleModel? bundle,
    LiveViewerMode? mode,
    String? raison,
    bool clearRaison = false,
    List<LiveChatMessageModel>? messages,
    int? nbViewers,
    bool? enPause,
    bool? envoiChatEnCours,
    String? erreur,
    bool clearErreur = false,
    VideoPlayerController? controleurHls,
    bool clearControleurHls = false,
    RemoteVideoTrack? pisteVideoLiveKit,
    bool clearPisteVideo = false,
    int? uidAgora,
    bool clearUidAgora = false,
  }) =>
      LiveViewerState(
        live: live ?? this.live,
        bundle: bundle ?? this.bundle,
        mode: mode ?? this.mode,
        raison: clearRaison ? null : (raison ?? this.raison),
        messages: messages ?? this.messages,
        nbViewers: nbViewers ?? this.nbViewers,
        enPause: enPause ?? this.enPause,
        envoiChatEnCours: envoiChatEnCours ?? this.envoiChatEnCours,
        erreur: clearErreur ? null : (erreur ?? this.erreur),
        controleurHls:
            clearControleurHls ? null : (controleurHls ?? this.controleurHls),
        pisteVideoLiveKit: clearPisteVideo
            ? null
            : (pisteVideoLiveKit ?? this.pisteVideoLiveKit),
        uidAgora: clearUidAgora ? null : (uidAgora ?? this.uidAgora),
      );
}

/// ⭐ Contrôleur du viewer (un par live ouvert, family par liveId).
class LiveViewerController extends StateNotifier<LiveViewerState> {
  final String liveId;
  final LiveRepository _repo = LiveRepository();

  // Timers ( mêmes périodes que le viewer web V3.22 ).
  Timer? _timerFlux;     // 12 s — mode / bascule de chaîne
  Timer? _timerEtat;     // 3 s  — pause / statut du live
  Timer? _timerChat;     // 4 s  — chat public
  Timer? _timerPresence; // 25 s — heartbeat viewers

  // Sessions média.
  VideoPlayerController? _lecteurHls;
  Room? _roomLiveKit;
  RtcEngine? _agora;

  // Divers.
  String? _userId;       // memberId du heartbeat (le serveur résout user-<id>).
  String? _nomAffiche;   // pseudo du chat public.
  String? _dernierMessageIso;
  String? _modeApplique; // éviter les reconnexions inutiles.
  String? _urlHlsActive;
  bool _detruit = false;
  bool _applicationEnVol = false;

  LiveViewerController(this.liveId) : super(const LiveViewerState());

  /// Démarre le viewer : [userId] sert au compteur de présence, [nomAffiche]
  /// au chat public (les visiteurs du web peuvent être anonymes ; le mobile
  /// est connecté → nom de session, comme sur le site connecté).
  Future<void> demarrer({
    required String userId,
    required String nomAffiche,
    LiveStreamModel? liveConnu,
  }) async {
    _userId = userId;
    _nomAffiche = nomAffiche;
    state = state.copyWith(live: liveConnu);

    // Premier cycle immédiat, puis périodique.
    _pollEtat();
    _pollFlux();
    _pollChat();
    _pollPresence();

    _timerFlux = Timer.periodic(const Duration(seconds: 12), (_) => _pollFlux());
    _timerEtat = Timer.periodic(const Duration(seconds: 3), (_) => _pollEtat());
    _timerChat = Timer.periodic(const Duration(seconds: 4), (_) => _pollChat());
    _timerPresence =
        Timer.periodic(const Duration(seconds: 25), (_) => _pollPresence());
  }

  @override
  void dispose() {
    _detruit = true;
    _timerFlux?.cancel();
    _timerEtat?.cancel();
    _timerChat?.cancel();
    _timerPresence?.cancel();
    _couperInterne();
    // Départ propre : le compteur de viewers baisse immédiatement.
    final uid = _userId;
    if (uid != null) {
      _repo.quitter(liveId, uid).catchError((_) {});
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  POLLINGS
  // ═══════════════════════════════════════════════════════════════════

  /// Mode de visionnage (12 s) — suit l'arbitrage serveur du studio.
  Future<void> _pollFlux() async {
    if (_detruit) return;
    try {
      final bundle = await _repo.flux(liveId);
      if (_detruit) return;
      state = state.copyWith(bundle: bundle, raison: bundle.reason, clearRaison: bundle.reason == null);
      await _appliquerBundle(bundle);
    } catch (_) {
      // Réseau : le prochain cycle retente (silence, comme le web).
    }
  }

  /// Pause + statut (3 s) — `/api/live/next`, source de vérité de la pause.
  Future<void> _pollEtat() async {
    if (_detruit) return;
    try {
      final live = await _repo.suivant();
      if (_detruit || live == null || live.id != liveId) return;
      final eteint = !live.estEnCours;
      state = state.copyWith(
        live: live,
        enPause: live.isPaused,
        mode: eteint && state.mode != LiveViewerMode.eteint
            ? LiveViewerMode.eteint
            : null,
      );
      if (eteint) await _couperSessions();
    } catch (_) {
      // Silencieux.
    }
  }

  /// Chat public (4 s) — incrémental via `since`.
  Future<void> _pollChat() async {
    if (_detruit) return;
    try {
      final frais = await _repo.chat(liveId, since: _dernierMessageIso);
      if (_detruit || frais.isEmpty) return;
      final fusionnes = [...state.messages, ...frais];
      // Garde-fou mémoire : les 300 derniers (le web charge 50).
      final tail = fusionnes.length > 300
          ? fusionnes.sublist(fusionnes.length - 300)
          : fusionnes;
      _dernierMessageIso = tail.last.createdAt.toIso8601String();
      state = state.copyWith(messages: tail);
    } catch (_) {
      // Silencieux.
    }
  }

  /// Présence (25 s) — heartbeat + compteur réel.
  Future<void> _pollPresence() async {
    if (_detruit || _userId == null) return;
    try {
      await _repo.heartbeat(liveId, _userId!);
    } catch (_) {}
    try {
      final n = await _repo.compterViewers(liveId);
      if (!_detruit) state = state.copyWith(nbViewers: n);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  //  APPLICATION DU MODE (bascule automatique quand le studio bascule)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _appliquerBundle(LiveStreamBundleModel bundle) async {
    if (_detruit || _applicationEnVol) return;

    // Mode « off » : le live n'est pas (ou plus) en cours.
    if (bundle.estEteint) {
      if (_modeApplique != 'off') {
        await _couperSessions();
        _modeApplique = 'off';
        state = state.copyWith(mode: LiveViewerMode.eteint);
      }
      return;
    }

    // Rien à faire si le mode ET l'URL HLS sont identiques (pas de thrash).
    if (bundle.mode == _modeApplique) {
      if (bundle.estHls &&
          bundle.hlsUrls.isNotEmpty &&
          bundle.hlsUrls.first == _urlHlsActive) {
        return;
      }
      if (!bundle.estHls) return;
    }

    _applicationEnVol = true;
    try {
      await _couperSessions();
      switch (bundle.mode) {
        case 'hls':
          await _demarrerHls(bundle);
        case 'webrtc':
          await _demarrerWebRtc(bundle);
        case 'agora':
          await _demarrerAgora(bundle);
        case 'daily':
          _modeApplique = 'daily';
          state = state.copyWith(mode: LiveViewerMode.daily);
        default:
          _modeApplique = 'off';
          state = state.copyWith(mode: LiveViewerMode.eteint);
      }
    } catch (e) {
      state = state.copyWith(
        mode: LiveViewerMode.erreur,
        erreur: 'Lecture impossible : $e',
      );
    } finally {
      _applicationEnVol = false;
    }
  }

  // ─── 1. HLS — MODE YOUTUBE (0 participant, aucune room rejointe) ────

  Future<void> _demarrerHls(LiveStreamBundleModel bundle) async {
    if (bundle.hlsUrls.isEmpty) {
      throw 'aucune playlist HLS disponible';
    }
    Object? derniereErreur;
    for (final url in bundle.hlsUrls) {
      final lecteur = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await lecteur.initialize();
        if (_detruit) {
          await lecteur.dispose();
          return;
        }
        await lecteur.play();
        await lecteur.setLooping(false);
        _lecteurHls = lecteur;
        _urlHlsActive = url;
        _modeApplique = 'hls';
        state = state.copyWith(
          mode: LiveViewerMode.hls,
          controleurHls: lecteur,
          clearErreur: true,
        );
        return;
      } catch (e) {
        derniereErreur = e;
        try {
          await lecteur.dispose();
        } catch (_) {}
      }
    }
    throw 'HLS indisponible ($derniereErreur)';
  }

  // ─── 2. WebRTC LiveKit (repli si l'egress HLS échoue — token viewer
  //        serveur : canPublish=false, on ne publie RIEN) ──────────────

  Future<void> _demarrerWebRtc(LiveStreamBundleModel bundle) async {
    if (bundle.livekitUrl == null || bundle.livekitToken == null) {
      throw 'identifiants LiveKit manquants';
    }
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _roomLiveKit = room;

    room.events
      ..on<TrackSubscribedEvent>((e) {
        final piste = e.track;
        if (piste is RemoteVideoTrack && !_detruit) {
          state = state.copyWith(pisteVideoLiveKit: piste, clearErreur: true);
        }
      })
      ..on<TrackUnsubscribedEvent>((e) {
        if (!_detruit && e.track is RemoteVideoTrack) {
          state = state.copyWith(clearPisteVideo: true);
        }
      });

    await room.connect(bundle.livekitUrl!, bundle.livekitToken!);
    if (_detruit) {
      await room.disconnect();
      return;
    }
    _modeApplique = 'webrtc';
    // ⭐ Aucune permission demandée : le viewer N'EST PAS un participant
    // actif — il ne publie jamais (exigence « comme YouTube »).
    state = state.copyWith(mode: LiveViewerMode.webrtc, clearErreur: true);

    // Piste déjà publiée pendant la connexion ?
    for (final p in room.remoteParticipants.values) {
      for (final t in p.trackPublications.values) {
        final piste = t.track;
        if (piste is RemoteVideoTrack && t.subscribed) {
          state = state.copyWith(pisteVideoLiveKit: piste);
          break;
        }
      }
    }
  }

  // ─── 3. Agora — rôle AUDIENCE (reçoit, n'interagit jamais) ──────────

  Future<void> _demarrerAgora(LiveStreamBundleModel bundle) async {
    if (bundle.agoraAppId == null ||
        bundle.agoraChannel == null ||
        bundle.agoraToken == null ||
        bundle.agoraUid == null) {
      throw 'identifiants Agora manquants';
    }
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: bundle.agoraAppId!));
    _agora = engine;

    engine.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (connection, uid, elapsed) {
        if (_detruit) return;
        // Premier diffuseur arrivé = flux affiché plein cadre.
        state = state.copyWith(uidAgora: uid, clearErreur: true);
      },
      onUserOffline: (connection, uid, reason) {
        if (_detruit) return;
        if (state.uidAgora == uid) {
          state = state.copyWith(clearUidAgora: true);
        }
      },
    ));

    // ⭐ Profil LIVE (broadcast) + rôle AUDIENCE : le viewer reçoit le flux,
    // il ne publierait de toute façon rien (token subscriber serveur).
    await engine.enableAudio();
    await engine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting);
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await engine.joinChannel(
      token: bundle.agoraToken!,
      channelId: bundle.agoraChannel!,
      uid: bundle.agoraUid!,
      options: const ChannelMediaOptions(
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
    if (_detruit) return;
    _modeApplique = 'agora';
    state = state.copyWith(mode: LiveViewerMode.agora);
  }

  // ─── 4. Daily — room prebuilt dans le navigateur (dernier repli) ────

  /// Ouvre la room Daily (avec son token serveur) — miroir du comportement
  /// des appels mobiles (SDK daily_flutter beta → navigateur assumé).
  Future<void> ouvrirDaily() async {
    final bundle = state.bundle;
    if (bundle?.dailyUrl == null || bundle?.dailyToken == null) {
      state = state.copyWith(erreur: 'Room Daily indisponible.');
      return;
    }
    final uri =
        Uri.parse('${bundle!.dailyUrl!}?t=${bundle.dailyToken!}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      state = state.copyWith(erreur: "Impossible d'ouvrir la room Daily.");
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CHAT PUBLIC + RÉACTIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Envoie un message du chat public (nom de session).
  Future<void> envoyerChat(String contenu) async {
    final texte = contenu.trim();
    if (texte.isEmpty || _nomAffiche == null) return;
    state = state.copyWith(envoiChatEnCours: true);
    try {
      await _repo.envoyerChat(liveId, _nomAffiche!, texte);
      await _pollChat();
    } finally {
      if (!_detruit) state = state.copyWith(envoiChatEnCours: false);
    }
  }

  /// Envoie une réaction rapide (❤️ 🙏 ✋ 🔥 — même route, type reaction).
  Future<void> reagir(String emoji) async {
    if (_nomAffiche == null) return;
    try {
      await _repo.reagir(liveId, _nomAffiche!, emoji);
    } catch (_) {}
  }

  /// Relayage manuel (bouton Réessayer après une erreur de lecture).
  Future<void> reessayer() async {
    final bundle = state.bundle;
    if (bundle == null) {
      await _pollFlux();
      return;
    }
    _modeApplique = null;
    state = state.copyWith(clearErreur: true);
    await _appliquerBundle(bundle);
  }

  /// Moteur Agora courant — l'écran en a besoin pour le rendu vidéo
  /// (AgoraVideoView + VideoViewController.remote).
  RtcEngine? get engineAgora => _agora;

  // ═══════════════════════════════════════════════════════════════════
  //  NETTOYAGE
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _couperSessions() async {
    final lecteur = _lecteurHls;
    _lecteurHls = null;
    if (lecteur != null) {
      try {
        await lecteur.dispose();
      } catch (_) {}
    }
    final room = _roomLiveKit;
    _roomLiveKit = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
    }
    final agora = _agora;
    _agora = null;
    if (agora != null) {
      try {
        await agora.leaveChannel();
        await agora.release();
      } catch (_) {}
    }
    if (!_detruit) {
      state = state.copyWith(
        clearControleurHls: true,
        clearPisteVideo: true,
        clearUidAgora: true,
      );
    }
  }

  Future<void> _couperInterne() async {
    _detruit = true;
    await _couperSessions();
  }
}

/// ⭐ Provider du viewer (family par liveId — un seul viewer à la fois).
final liveViewerProvider =
    StateNotifierProvider.family<LiveViewerController, LiveViewerState, String>(
  (ref, liveId) => LiveViewerController(liveId),
);

/// Provider simple du live ACTIF (bannière de la liste des discussions).
final liveActifProvider = FutureProvider.autoDispose<LiveStreamModel?>((ref) {
  return LiveRepository().actif();
});

/// Provider du prochain live programmé (carte discrète hors direct).
final liveSuivantProvider = FutureProvider.autoDispose<LiveStreamModel?>((ref) {
  return LiveRepository().suivant();
});
