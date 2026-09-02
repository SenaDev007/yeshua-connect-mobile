/// ⭐⭐ CANAUX VOCAUX PERSISTANTS (mobile) — miroir du web ⭐⭐
/// ============================================================================
/// Même mécanique que MessagingView.joinVoiceChannel (V2.7/V2.9/V3.21) :
///
///   1. GET  voice-mode → mode du canal (AUDIO ou VIDÉO — décision ADMIN,
///      « mode WhatsApp » : quand l'admin bascule, tout le monde suit).
///   2. POST /calls/media { action: "join-voice", conversationId } → le
///      SERVEUR arbitre le fournisseur (LiveKit → Agora → Daily) et renvoie
///      le bundle — tous les participants rejoignent le MÊME réseau.
///   3. Connexion native LiveKit (participants, orateurs, métadonnées du
///      canal → bascule du mode À CHAUD) ou Agora ; Daily = navigateur.
///   4. Déconnexion en cours de canal → failover-voice automatique : le
///      serveur avance au fournisseur suivant et on rejoint SANS action
///      de l'utilisateur.
///
/// La room `yeshua-voice-<convId>` est PERSISTANTE : partir/revenir ne
/// la détruit pas (les autres restent connectés — comme Telegram).
/// ============================================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repositories/calls_repository.dart';
import 'call_media_controller.dart'
    show MediaApiException, MediaParticipant, MediaProviderNom;

/// État d'un canal vocal.
class VoiceChannelState {
  final String? conversationId;
  final String? nomCanal;

  /// Connecté au canal (room rejointe).
  final bool connecte;

  /// Fournisseur actif de la chaîne (badge « Réseau : … »).
  final MediaProviderNom fournisseur;

  /// Bascule automatique en cours (bandeau doré).
  final bool basculeEnCours;

  /// Mode du canal décidé par l'ADMIN (audio pur ou audio + vidéo).
  final bool videoMode;

  /// Participants distants normalisés.
  final List<MediaParticipant> participants;

  final bool microCoupe;
  final bool cameraActive;

  final bool chargement;
  final String? erreur;

  const VoiceChannelState({
    this.conversationId,
    this.nomCanal,
    this.connecte = false,
    this.fournisseur = MediaProviderNom.aucun,
    this.basculeEnCours = false,
    this.videoMode = false,
    this.participants = const [],
    this.microCoupe = false,
    this.cameraActive = false,
    this.chargement = false,
    this.erreur,
  });

  VoiceChannelState copyWith({
    String? conversationId,
    String? nomCanal,
    bool? connecte,
    MediaProviderNom? fournisseur,
    bool? basculeEnCours,
    bool? videoMode,
    List<MediaParticipant>? participants,
    bool? microCoupe,
    bool? cameraActive,
    bool? chargement,
    bool clearErreur = false,
    String? erreur,
  }) =>
      VoiceChannelState(
        conversationId: conversationId ?? this.conversationId,
        nomCanal: nomCanal ?? this.nomCanal,
        connecte: connecte ?? this.connecte,
        fournisseur: fournisseur ?? this.fournisseur,
        basculeEnCours: basculeEnCours ?? this.basculeEnCours,
        videoMode: videoMode ?? this.videoMode,
        participants: participants ?? this.participants,
        microCoupe: microCoupe ?? this.microCoupe,
        cameraActive: cameraActive ?? this.cameraActive,
        chargement: chargement ?? this.chargement,
        erreur: clearErreur ? null : (erreur ?? this.erreur),
      );
}

class VoiceChannelController extends Notifier<VoiceChannelState> {
  final CallsRepository _repo = CallsRepository();

  Room? _room;
  RtcEngine? _agora;
  bool _detruit = false;
  bool _basculeEnVol = false;
  Timer? _gardeFou;
  final Set<String> _parleurs = {};
  final Set<int> _idsAgora = {};

  @override
  VoiceChannelState build() {
    ref.onDispose(_couperSync);
    return const VoiceChannelState();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  REJOINDRE / QUITTER
  // ═══════════════════════════════════════════════════════════════════

  /// Rejoint le canal vocal : mode (admin) → arbitrage serveur → connexion
  /// native → boucle de repli (failover-voice) en cas d'échec.
  Future<void> rejoindre({required String conversationId, required String nomCanal}) async {
    if (state.connecte && state.conversationId == conversationId) return;
    _detruit = false;
    state = state.copyWith(
      conversationId: conversationId,
      nomCanal: nomCanal,
      chargement: true,
      clearErreur: true,
    );
    await [Permission.microphone, Permission.camera].request();

    try {
      // 1. Mode du canal (décision ADMIN — la caméra ne s'allume QUE
      //    si l'admin a activé le mode vidéo).
      bool videoMode = false;
      try {
        videoMode = await _repo.modeCanalVocal(conversationId);
      } catch (_) {/* best effort — audio par défaut */}
      state = state.copyWith(videoMode: videoMode);

      // 2. Arbitrage serveur + boucle de repli.
      var bundle = await _repo.rejoindreMediaCanal(conversationId);
      if (bundle.exhausted || bundle.provider == null) {
        throw const MediaApiException(
            'Aucun réseau disponible (LiveKit → Agora → Daily).');
      }
      for (var essai = 0; essai < 3; essai++) {
        try {
          await _connecterFournisseur(conversationId, bundle);
          state = state.copyWith(chargement: false, connecte: true);
          return;
        } catch (e) {
          if (_detruit || state.conversationId != conversationId) return;
          final suivant = await _repo.signalerEchecMediaCanal(
            conversationId,
            bundle.provider!,
            'mobile: $e',
          );
          if (suivant.exhausted || suivant.provider == null) {
            state = state.copyWith(
              chargement: false,
              erreur: suivant.reason ?? 'Réseau indisponible — réessayez.',
            );
            throw const MediaApiException('Chaîne du canal vocal épuisée.');
          }
          bundle = suivant;
        }
      }
      state = state.copyWith(chargement: false, erreur: 'Réseau indisponible — réessayez.');
    } catch (e) {
      state = state.copyWith(
        chargement: false,
        connecte: false,
        erreur: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Quitte le canal (la room PERSISTE pour les autres participants).
  Future<void> quitter() async {
    final convId = state.conversationId;
    await _couperInterne();
    state = VoiceChannelState(conversationId: convId, nomCanal: state.nomCanal);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CONTRÔLES LOCAUX
  // ═══════════════════════════════════════════════════════════════════

  Future<void> basculerMicro() async {
    final prochainCoupe = !state.microCoupe;
    final room = _room;
    if (room != null) {
      await room.localParticipant?.setMicrophoneEnabled(!prochainCoupe);
    } else if (_agora != null) {
      await _agora!.muteLocalAudioStream(prochainCoupe);
    }
    state = state.copyWith(microCoupe: prochainCoupe);
  }

  /// Caméra — uniquement si l'ADMIN a activé le mode vidéo du canal.
  Future<void> basculerCamera() async {
    if (!state.videoMode) {
      state = state.copyWith(erreur: 'Mode vidéo désactivé par l\u2019administrateur du canal.');
      return;
    }
    final prochaineActive = !state.cameraActive;
    final room = _room;
    if (room != null) {
      await room.localParticipant?.setCameraEnabled(prochaineActive);
    } else if (_agora != null) {
      await _agora!.muteLocalVideoStream(!prochaineActive);
    }
    state = state.copyWith(cameraActive: prochaineActive, clearErreur: true);
  }

  /// ADMIN — bascule le mode du canal (audio ↔ vidéo) : persisté en base +
  /// propagé à chaud à tous les participants (métadonnées room LiveKit).
  /// Le serveur renvoie 403 aux non-admins (même règle que le web).
  Future<void> basculerModeCanal({required bool video}) async {
    final convId = state.conversationId;
    if (convId == null) return;
    try {
      await _repo.basculerModeCanalVocal(convId, video: video);
      state = state.copyWith(videoMode: video, cameraActive: video ? state.cameraActive : false, clearErreur: true);
      if (!video) {
        // Caméras coupées immédiatement côté local aussi.
        final room = _room;
        await room?.localParticipant?.setCameraEnabled(false);
        await _agora?.muteLocalVideoStream(true);
        state = state.copyWith(cameraActive: false);
      }
    } catch (e) {
      state = state.copyWith(erreur: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CONNEXION PAR FOURNISSEUR
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _connecterFournisseur(String conversationId, MediaBundleModel bundle) async {
    switch (bundle.provider) {
      case 'livekit':
        await _connecterLiveKit(conversationId, bundle);
      case 'agora':
        await _connecterAgora(conversationId, bundle);
      case 'daily':
        await _ouvrirDaily(bundle);
      default:
        throw MediaApiException('Fournisseur inconnu : ${bundle.provider}');
    }
    state = state.copyWith(
      fournisseur: _nomDepuis(bundle.provider),
      microCoupe: false,
      cameraActive: false,
      clearErreur: true,
    );
  }

  // ─── LiveKit (source de vérité) ─────────────────────────────────────

  Future<void> _connecterLiveKit(String conversationId, MediaBundleModel bundle) async {
    if (bundle.livekitUrl == null || bundle.livekitToken == null) {
      throw const MediaApiException('Identifiants LiveKit manquants.');
    }
    await _couperInterne();
    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;

    room.events
      ..on<ParticipantConnectedEvent>((_) => _emitParticipants())
      ..on<ParticipantDisconnectedEvent>((_) => _emitParticipants())
      ..on<TrackSubscribedEvent>((_) => _emitParticipants())
      ..on<TrackUnsubscribedEvent>((_) => _emitParticipants())
      ..on<TrackMutedEvent>((_) => _emitParticipants())
      ..on<TrackUnmutedEvent>((_) => _emitParticipants())
      ..on<ActiveSpeakersChangedEvent>((e) {
        _parleurs
          ..clear()
          ..addAll(e.speakers.map((s) => s.identity));
        _emitParticipants();
      })
      // ⭐ V2.7 — L'ADMIN a basculé le mode : TOUT LE MONDE suit à chaud
      // (métadonnées de room poussées par le serveur).
      ..on<RoomMetadataChangedEvent>((e) {
        _appliquerMetadata(e.metadata);
      })
      // ⭐ V3.21 — Déconnexion LiveKit en cours de canal → FAILOVER
      // AUTOMATIQUE (failover-voice) vers Agora puis Daily, sans action
      // de l'utilisateur — la room persiste, on revient.
      ..on<RoomDisconnectedEvent>((_) {
        if (_detruit || !state.connecte) return;
        _relancerApresDeconnexion();
      });

    _gardeFou?.cancel();
    _gardeFou = Timer(const Duration(seconds: 12), () {});
    try {
      await room.connect(bundle.livekitUrl!, bundle.livekitToken!);
      await room.localParticipant?.setMicrophoneEnabled(true);
      // Caméra UNIQUEMENT si l'admin a activé le mode vidéo du canal.
      await room.localParticipant?.setCameraEnabled(state.videoMode);
    } catch (e) {
      await _couperInterne();
      throw MediaApiException('LiveKit : $e');
    } finally {
      _gardeFou?.cancel();
      _gardeFou = null;
    }
    _appliquerMetadata(room.metadata);
    _emitParticipants();
    final local = room.localParticipant;
    state = state.copyWith(
      microCoupe: !(local?.isMicrophoneEnabled() ?? false),
      cameraActive: local?.isCameraEnabled() ?? false,
    );
  }

  /// Métadonnées de la room : { videoMode, updatedAt, updatedBy }.
  void _appliquerMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return;
    try {
      final map = jsonDecode(metadata);
      if (map is Map<String, dynamic> && map['videoMode'] is bool) {
        final video = map['videoMode'] as bool;
        if (video != state.videoMode) {
          state = state.copyWith(videoMode: video);
          if (!video) {
            _room?.localParticipant?.setCameraEnabled(false);
            state = state.copyWith(cameraActive: false);
          }
        }
      }
    } catch (_) {/* métadonnées non JSON — ignorées */}
  }

  /// Déconnexion en cours de canal → chaîne de repli serveur puis reconnexion.
  Future<void> _relancerApresDeconnexion() async {
    if (_basculeEnVol) return;
    final convId = state.conversationId;
    if (convId == null) return;
    _basculeEnVol = true;
    state = state.copyWith(basculeEnCours: true);
    try {
      await _couperInterne();
      final bundle = await _repo.signalerEchecMediaCanal(
        convId,
        'livekit',
        'déconnexion du canal',
      );
      if (!bundle.exhausted && bundle.provider != null) {
        await _connecterFournisseur(convId, bundle);
        state = state.copyWith(connecte: true, basculeEnCours: false);
      } else {
        state = state.copyWith(connecte: false, basculeEnCours: false);
      }
    } catch (_) {
      state = state.copyWith(connecte: false, basculeEnCours: false);
    } finally {
      _basculeEnVol = false;
      state = state.copyWith(basculeEnCours: false);
    }
  }

  void _emitParticipants() {
    final room = _room;
    if (room == null) return;
    final distants = room.remoteParticipants.values.map((p) {
      return MediaParticipant(
        identity: p.identity,
        name: p.name.isEmpty ? null : p.name,
        microActif: p.isMicrophoneEnabled(),
        cameraActive: p.isCameraEnabled(),
        parle: _parleurs.contains(p.identity),
      );
    }).toList();
    state = state.copyWith(participants: distants);
  }

  // ─── Agora (repli n°1) ───────────────────────────────────────────────

  Future<void> _connecterAgora(String conversationId, MediaBundleModel bundle) async {
    if (bundle.agoraAppId == null ||
        bundle.agoraChannel == null ||
        bundle.agoraToken == null ||
        bundle.agoraUid == null) {
      throw const MediaApiException('Identifiants Agora manquants.');
    }
    await _couperInterne();
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: bundle.agoraAppId!));
    _agora = engine;

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) => _emitAgoraParticipants(),
      onUserJoined: (connection, uid, elapsed) {
        _idsAgora.add(uid);
        _emitAgoraParticipants();
      },
      onUserOffline: (connection, uid, reason) {
        _idsAgora.remove(uid);
        _emitAgoraParticipants();
      },
      onUserMuteAudio: (connection, uid, muted) => _emitAgoraParticipants(),
      onUserMuteVideo: (connection, uid, muted) => _emitAgoraParticipants(),
    ));

    await engine.enableAudio();
    await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
    await engine.joinChannel(
      token: bundle.agoraToken!,
      channelId: bundle.agoraChannel!,
      uid: bundle.agoraUid!,
      options: const ChannelMediaOptions(
        publishCameraTrack: false,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
    _emitAgoraParticipants();
  }

  void _emitAgoraParticipants() {
    if (_agora == null) return;
    final distants = _idsAgora
        .map((uid) => MediaParticipant(
              identity: 'agora-$uid',
              name: null,
              microActif: true,
              cameraActive: false,
            ))
        .toList();
    state = state.copyWith(participants: distants);
  }

  // ─── Daily (repli n°2 — room prebuilt navigateur) ────────────────────

  Future<void> _ouvrirDaily(MediaBundleModel bundle) async {
    if (bundle.dailyUrl == null || bundle.dailyToken == null) {
      throw const MediaApiException('Identifiants Daily manquants.');
    }
    await _couperInterne();
    final uri = Uri.parse('${bundle.dailyUrl!}?t=${bundle.dailyToken!}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw const MediaApiException("Impossible d'ouvrir la room Daily.");
    }
    state = state.copyWith(participants: const []);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  NETTOYAGE
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _couperInterne() async {
    _gardeFou?.cancel();
    _gardeFou = null;
    final room = _room;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
      _room = null;
    }
    final agora = _agora;
    if (agora != null) {
      try {
        await agora.leaveChannel();
        await agora.release();
      } catch (_) {}
      _agora = null;
    }
    _parleurs.clear();
    _idsAgora.clear();
    state = state.copyWith(participants: const [], connecte: false, fournisseur: MediaProviderNom.aucun);
  }

  void _couperSync() {
    _detruit = true;
    try {
      _room?.disconnect();
      _agora?.leaveChannel();
      _agora?.release();
    } catch (_) {}
    _gardeFou?.cancel();
    _room = null;
    _agora = null;
  }

  MediaProviderNom _nomDepuis(String? nom) {
    switch (nom) {
      case 'livekit':
        return MediaProviderNom.livekit;
      case 'agora':
        return MediaProviderNom.agora;
      case 'daily':
        return MediaProviderNom.daily;
      default:
        return MediaProviderNom.aucun;
    }
  }
}

/// ⭐ Provider Riverpod du canal vocal (un seul canal rejoint à la fois).
final voiceChannelProvider =
    NotifierProvider<VoiceChannelController, VoiceChannelState>(
  VoiceChannelController.new,
);
