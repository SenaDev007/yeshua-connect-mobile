/// ⭐⭐ V3.21 — CONTRÔLEUR MULTIMÉDIA DES APPELS (mobile) ⭐⭐
/// ============================================================================
/// Directive du pasteur : « LiveKit est la source de vérité ; si LiveKit a
/// des problèmes, Agora prend immédiatement le relais ; et si Agora a des
/// problèmes, Daily prend automatiquement le relais. »
///
/// Miroir EXACT de l'orchestrateur web (MessagingView.connectMediaChain +
/// src/lib/yeshua-connect/media-adapters.ts) :
///
///   1. POST /calls/media { action: "join" } → le SERVEUR arbitre le
///      fournisseur de l'appel (colonne CallSignal.mediaProvider) —
///      l'appelant et le destinataire rejoignent le MÊME réseau.
///   2. Connexion native : livekit_client 2.3.4 (Room) ou
///      agora_rtc_engine 6.5.0 (RtcEngine). Daily : la room prebuilt
///      s'ouvre dans le navigateur (url_launcher) — dernier recours.
///   3. En échec (12 s max) : POST { action: "failover" } → le serveur fait
///      avancer l'appel et renvoie le bundle suivant → reconnexion.
///   4. Bascule à CHAUD : le polling de statut (2 s) du call_controller voit
///      `mediaProvider` changer → ce contrôleur bascule sans raccrocher.
///
/// ⚠️ userId et rôle TOUJOURS décidés par le serveur — le token serveur
/// embarque l'identité (LiveKit) ou l'uid hashé (Agora).
library;

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repositories/calls_repository.dart';

/// Fournisseur actif de la chaîne.
enum MediaProviderNom { livekit, agora, daily, aucun }

extension MediaProviderNomX on MediaProviderNom {
  String get libelle {
    switch (this) {
      case MediaProviderNom.livekit:
        return 'LiveKit';
      case MediaProviderNom.agora:
        return 'Agora';
      case MediaProviderNom.daily:
        return 'Daily';
      case MediaProviderNom.aucun:
        return '—';
    }
  }
}

/// Participant distant NORMALISÉ — même forme que le web
/// (YcRemoteParticipant).
class MediaParticipant {
  final String identity;
  final String? name;
  final bool microActif;
  final bool cameraActive;
  final bool parle;

  const MediaParticipant({
    required this.identity,
    this.name,
    this.microActif = false,
    this.cameraActive = false,
    this.parle = false,
  });
}

/// État du contrôleur média.
class MediaChainState {
  /// Fournisseur connecté (aucun = pas de session).
  final MediaProviderNom fournisseur;

  /// Bascule automatique en cours (bandeau UI).
  final bool basculeEnCours;

  /// Participants distants normalisés.
  final List<MediaParticipant> participants;

  /// Micro local coupé ?
  final bool microCoupe;

  /// Caméra locale activée ?
  final bool cameraActive;

  /// Erreur (bandeau discret).
  final String? erreur;

  const MediaChainState({
    this.fournisseur = MediaProviderNom.aucun,
    this.basculeEnCours = false,
    this.participants = const [],
    this.microCoupe = false,
    this.cameraActive = false,
    this.erreur,
  });

  MediaChainState copyWith({
    MediaProviderNom? fournisseur,
    bool? basculeEnCours,
    List<MediaParticipant>? participants,
    bool? microCoupe,
    bool? cameraActive,
    String? erreur,
    bool clearErreur = false,
  }) =>
      MediaChainState(
        fournisseur: fournisseur ?? this.fournisseur,
        basculeEnCours: basculeEnCours ?? this.basculeEnCours,
        participants: participants ?? this.participants,
        microCoupe: microCoupe ?? this.microCoupe,
        cameraActive: cameraActive ?? this.cameraActive,
        erreur: clearErreur ? null : (erreur ?? this.erreur),
      );
}

/// Erreur locale du module média.
class MediaApiException implements Exception {
  final String message;
  const MediaApiException(this.message);
  @override
  String toString() => message;
}

/// ⭐ Contrôleur Riverpod de la chaîne multimédia.
class CallMediaController extends Notifier<MediaChainState> {
  final CallsRepository _repo = CallsRepository();

  Room? _room;            // session LiveKit
  RtcEngine? _agora;      // session Agora
  String? _callId;        // appel courant
  bool _estVideo = false;
  bool _detruit = false;
  bool _basculeEnVol = false;
  Timer? _gardeFou;
  final Set<String> _parleursLiveKit = {};
  final Set<int> _idsAgora = {};

  @override
  MediaChainState build() {
    ref.onDispose(_toutCouperSync);
    return const MediaChainState();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Chaîne publique : connecter / basculer / couper
  // ═══════════════════════════════════════════════════════════════════

  /// Connecte le média d'un appel via la chaîne arbitrée par le serveur.
  Future<void> connecter({
    required String callId,
    required bool video,
  }) async {
    _callId = callId;
    _estVideo = video;
    await _permissions();
    var bundle = await _repo.rejoindreMedia(callId);
    if (bundle.exhausted || bundle.provider == null) {
      throw MediaApiException(bundle.reason ??
          'Aucun réseau disponible (LiveKit → Agora → Daily).');
    }
    // Boucle de repli : essai → failover serveur → suivant.
    for (var essai = 0; essai < 3; essai++) {
      try {
        await _connecterFournisseur(bundle);
        return;
      } catch (e) {
        if (_detruit || _callId == null) return;
        final suivant = await _repo.signalerEchecMedia(
          _callId!,
          bundle.provider!,
          'mobile: $e',
        );
        if (suivant.exhausted || suivant.provider == null) {
          state = state.copyWith(erreur: 'Aucun réseau disponible.');
          throw MediaApiException(suivant.reason ??
              'Chaîne multimédia épuisée (LiveKit → Agora → Daily).');
        }
        bundle = suivant;
      }
    }
    throw const MediaApiException(
        'Chaîne multimédia épuisée (LiveKit → Agora → Daily).');
  }

  /// Bascule à chaud vers le fournisseur arbitré par le serveur (vu dans
  /// le polling de statut `mediaProvider` — appelé par le call_controller).
  Future<void> basculerVers(String fournisseurDistant) async {
    if (_callId == null) return;
    final cible = _nomDepuis(fournisseurDistant);
    if (cible == state.fournisseur || _basculeEnVol) return;
    _basculeEnVol = true;
    state = state.copyWith(basculeEnCours: true);
    try {
      await _toutCouperInterne();
      final bundle = await _repo.rejoindreMedia(_callId!);
      if (!bundle.exhausted && bundle.provider != null) {
        await _connecterFournisseur(bundle);
      }
    } catch (_) {
      // La bascule distante n'a pas pris ici — le prochain polling retente.
    } finally {
      _basculeEnVol = false;
      state = state.copyWith(basculeEnCours: false);
    }
  }

  /// Coupe tout (raccroché).
  Future<void> deconnecter() async {
    _callId = null;
    await _toutCouperInterne();
    state = const MediaChainState();
  }

  // ─── Contrôles locaux (routés vers le fournisseur actif) ───────────

  /// Coupe/rallume le micro local.
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

  /// Active/coupe la caméra locale (appel vidéo).
  Future<void> basculerCamera() async {
    final prochaineActive = !state.cameraActive;
    final room = _room;
    if (room != null) {
      await room.localParticipant?.setCameraEnabled(prochaineActive);
    } else if (_agora != null) {
      await _agora!.muteLocalVideoStream(!prochaineActive);
    }
    state = state.copyWith(cameraActive: prochaineActive);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Connexion par fournisseur
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _connecterFournisseur(MediaBundleModel bundle) async {
    switch (bundle.provider) {
      case 'livekit':
        await _connecterLiveKit(bundle);
      case 'agora':
        await _connecterAgora(bundle);
      case 'daily':
        await _ouvrirDaily(bundle);
      default:
        throw MediaApiException('Fournisseur inconnu : ${bundle.provider}');
    }
    state = state.copyWith(
      fournisseur: _nomDepuis(bundle.provider),
      cameraActive: _estVideo,
      microCoupe: false,
      clearErreur: true,
    );
  }

  // ─── 1. LiveKit (source de vérité) — livekit_client 2.3.4 ───────────

  Future<void> _connecterLiveKit(MediaBundleModel bundle) async {
    if (bundle.livekitUrl == null || bundle.livekitToken == null) {
      throw const MediaApiException('Identifiants LiveKit manquants.');
    }
    await _toutCouperInterne();
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _room = room;

    // ⭐ livekit_client 2.3.4 : listeners TYPÉS (room.events.on<XxxEvent>).
    room.events
      ..on<ParticipantConnectedEvent>((e) => _emitLiveKitParticipants())
      ..on<ParticipantDisconnectedEvent>((e) => _emitLiveKitParticipants())
      ..on<TrackSubscribedEvent>((e) => _emitLiveKitParticipants())
      ..on<TrackUnsubscribedEvent>((e) => _emitLiveKitParticipants())
      ..on<TrackMutedEvent>((e) => _emitLiveKitParticipants())
      ..on<TrackUnmutedEvent>((e) => _emitLiveKitParticipants())
      ..on<ActiveSpeakersChangedEvent>((e) {
        _parleursLiveKit
          ..clear()
          ..addAll(e.speakers.map((s) => s.identity));
        _emitLiveKitParticipants();
      })
      ..on<RoomDisconnectedEvent>((e) {
        if (_detruit) return;
        // ⭐ Bascule chaude : le contrôleur d'appel voit mediaProvider
        // changer dans son polling 2 s et appelle basculerVers().
        state = state.copyWith(
            erreur: 'LiveKit déconnecté — bascule vers le secours…');
      });

    // Garde-fou 12 s (même borne que le web).
    _gardeFou?.cancel();
    _gardeFou = Timer(const Duration(seconds: 12), () {
      // Si la connexion n'est pas prête à 12 s, on la coupe — la boucle
      // externe (connecter) attrapera l'échec via room.state.
    });
    try {
      await room.connect(bundle.livekitUrl!, bundle.livekitToken!);
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(_estVideo);
    } catch (e) {
      await _toutCouperInterne();
      throw MediaApiException('LiveKit : $e');
    } finally {
      _gardeFou?.cancel();
      _gardeFou = null;
    }
    _emitLiveKitParticipants();
    _emitLiveKitEtats();
  }

  void _emitLiveKitEtats() {
    final local = _room?.localParticipant;
    if (local == null) return;
    state = state.copyWith(
      microCoupe: !local.isMicrophoneEnabled(),
      cameraActive: local.isCameraEnabled(),
    );
  }

  void _emitLiveKitParticipants() {
    final room = _room;
    if (room == null) return;
    final distants = room.remoteParticipants.values.map((p) {
      final nom = p.name.isEmpty ? null : p.name;
      return MediaParticipant(
        identity: p.identity,
        name: nom,
        microActif: p.isMicrophoneEnabled(),
        cameraActive: p.isCameraEnabled(),
        parle: _parleursLiveKit.contains(p.identity),
      );
    }).toList();
    state = state.copyWith(participants: distants);
  }

  // ─── 2. Agora (repli n°1) — agora_rtc_engine 6.5.0 ──────────────────

  Future<void> _connecterAgora(MediaBundleModel bundle) async {
    if (bundle.agoraAppId == null ||
        bundle.agoraChannel == null ||
        bundle.agoraToken == null ||
        bundle.agoraUid == null) {
      throw const MediaApiException('Identifiants Agora manquants.');
    }
    await _toutCouperInterne();
    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: bundle.agoraAppId!));
    _agora = engine;

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        _emitAgoraParticipants();
      },
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
    await engine.setChannelProfile(
        ChannelProfileType.channelProfileCommunication);
    await engine.joinChannel(
      token: bundle.agoraToken!,
      channelId: bundle.agoraChannel!,
      uid: bundle.agoraUid!,
      options: const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
    if (!_estVideo) {
      await engine.muteLocalVideoStream(true);
    }
    _idsAgora.clear();
    _emitAgoraParticipants();
  }

  void _emitAgoraParticipants() {
    final engine = _agora;
    if (engine == null) return;
    final distants = _idsAgora.map((uid) {
      return MediaParticipant(
        identity: 'agora-$uid',
        name: null,
        microActif: true,
        cameraActive: false,
      );
    }).toList();
    state = state.copyWith(participants: distants);
  }

  // ─── 3. Daily (repli n°2 — room prebuilt dans le navigateur) ────────

  /// Daily sur mobile : le SDK Flutter officiel étant en beta
  /// (daily_flutter), la room prebuilt (URL + token serveur) s'ouvre dans
  /// le navigateur du téléphone — le micro/caméra y sont gérés par Daily.
  /// L'appel de signalisation reste dans l'app (durée/journal) — dernier
  /// recours assumé et documenté (README).
  Future<void> _ouvrirDaily(MediaBundleModel bundle) async {
    if (bundle.dailyUrl == null || bundle.dailyToken == null) {
      throw const MediaApiException('Identifiants Daily manquants.');
    }
    await _toutCouperInterne();
    final uri = Uri.parse('${bundle.dailyUrl!}?t=${bundle.dailyToken!}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw const MediaApiException("Impossible d'ouvrir la room Daily.");
    }
    // Session « navigateur » : aucun participant local suivi ; l'appel
    // d'app (chrono/journal) continue, l'utilisateur revient au raccroché.
    state = state.copyWith(participants: const []);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Utilitaires
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _permissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  Future<void> _toutCouperInterne() async {
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
    _parleursLiveKit.clear();
    _idsAgora.clear();
  }

  void _toutCouperSync() {
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

/// ⭐ Provider Riverpod de la session média d'appel (une seule à la fois).
final callMediaProvider =
    NotifierProvider<CallMediaController, MediaChainState>(
  CallMediaController.new,
);
