/// ⭐ V1.5 — ÉCRAN VIEWER DU LIVE PUBLIC (parité web V3.22 — mode YouTube).
///
/// Le spectateur regarde le direct depuis l'app mobile EXACTEMENT comme
/// depuis le site : flux HLS prioritaire (le viewer ne rejoint AUCUNE room
/// — LiveKit ne compte et ne facture que le diffuseur), replis WebRTC /
/// Agora audience / Daily si le studio bascule la chaîne. Pause, chat
/// public, réactions et compteur de viewers identiques au web.
library;

import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/live_model.dart';
import '../../state/auth_controller.dart';
import '../../state/live_viewer_controller.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key, this.liveId});

  /// null → suit le live ACTIF automatiquement.
  final String? liveId;

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final TextEditingController _saisieChat = TextEditingController();
  final ScrollController _scrollChat = ScrollController();

  String? _liveIdResolu;
  bool _demarre = false;
  VideoPlayerController? _lecteurEcoute;
  Timer? _ticDuree;
  bool _sonCoupe = false;

  @override
  void initState() {
    super.initState();
    // L'horloge du direct tourne côté écran (figée pendant la pause).
    _ticDuree = Timer.periodic(const Duration(seconds: 1), (_) {
      final id = _liveIdResolu;
      if (id == null) return;
      if (mounted && !ref.read(liveViewerProvider(id)).enPause) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticDuree?.cancel();
    _lecteurEcoute?.removeListener(_surChangementLecteur);
    _saisieChat.dispose();
    _scrollChat.dispose();
    super.dispose();
  }

  void _surChangementLecteur() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // ── Résolution du live : paramètre > live actif ──
    final idParam = widget.liveId;
    if (idParam != null && idParam != _liveIdResolu) {
      _liveIdResolu = idParam;
    }
    if (idParam == null && _liveIdResolu == null) {
      final actif = ref.watch(liveActifProvider);
      final live = actif.asData?.value;
      if (live != null && live.estEnCours) {
        // après le build courant — setState pendant le build est interdit.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _liveIdResolu == null) {
            setState(() => _liveIdResolu = live.id);
          }
        });
      }
    }

    // ── Démarrage du viewer (une seule fois) ──
    final session = ref.watch(authProvider).user;
    final liveId = _liveIdResolu;
    if (liveId != null && session != null && !_demarre) {
      _demarre = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(liveViewerProvider(liveId).notifier)
            .demarrer(userId: session.id, nomAffiche: session.name);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(title: const Text('Direct — Mouvement Christ Libère')),
      body: liveId == null
          ? _vueSansDirect()
          : _corps(ref.watch(liveViewerProvider(liveId))),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  CORPS : vidéo + en-tête + réactions + chat
  // ═════════════════════════════════════════════════════════════════

  Widget _corps(LiveViewerState etat) {
    return Column(
      children: [
        _zoneVideo(etat),
        _enteteLive(etat),
        _rangeeReactions(),
        _zoneChat(etat),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  ZONE VIDÉO — mode décidé par l'arbitrage serveur V3.22
  // ═════════════════════════════════════════════════════════════════

  Widget _zoneVideo(LiveViewerState etat) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: Colors.black, child: _contenuVideo(etat)),
          ),
        ),
        // ── Badges (au-dessus de la vidéo) ──
        Positioned(top: 8, left: 8, child: _badgeDirect(etat)),
        Positioned(top: 8, right: 8, child: _badgeViewers(etat)),
        // ── Pause persistée : visible par TOUS les modes (comme YouTube) ──
        if (etat.enPause)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.66),
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle_outline,
                        size: 52, color: AppColors.or),
                    SizedBox(height: 8),
                    Text(
                      'Pause — le direct est momentanément interrompu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.texte,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _contenuVideo(LiveViewerState etat) {
    switch (etat.mode) {
      case LiveViewerMode.chargement:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.or),
        );
      case LiveViewerMode.hls:
        return _videoHls(etat);
      case LiveViewerMode.webrtc:
        return _videoWebRtc(etat);
      case LiveViewerMode.agora:
        return _videoAgora(etat);
      case LiveViewerMode.daily:
        return _vueDaily();
      case LiveViewerMode.eteint:
        return _vueEteinte(etat);
      case LiveViewerMode.erreur:
        return _vueErreur(etat);
    }
  }

  /// ⭐ MODE YOUTUBE — lecteur HLS natif (ExoPlayer / AVPlayer) : aucune
  /// room rejointe, 0 participant LiveKit côté viewer, audio inclus.
  Widget _videoHls(LiveViewerState etat) {
    final lecteur = etat.controleurHls;
    if (lecteur == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.or),
      );
    }
    if (_lecteurEcoute != lecteur) {
      _lecteurEcoute?.removeListener(_surChangementLecteur);
      _lecteurEcoute = lecteur;
      lecteur.addListener(_surChangementLecteur);
    }
    final ratio =
        lecteur.value.aspectRatio <= 0 ? 16 / 9 : lecteur.value.aspectRatio;
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: AspectRatio(aspectRatio: ratio, child: VideoPlayer(lecteur)),
        ),
        // Contrôles locaux minimaux (lecture/pause + son) — le direct
        // continue côté serveur, comme la pause locale de YouTube.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                lecteur.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                if (lecteur.value.isPlaying) {
                  lecteur.pause();
                } else {
                  lecteur.play();
                }
              },
            ),
            IconButton(
              icon: Icon(
                _sonCoupe ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              onPressed: () async {
                await lecteur.setVolume(_sonCoupe ? 1.0 : 0.0);
                setState(() => _sonCoupe = !_sonCoupe);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Repli WebRTC LiveKit (spectateur — token serveur sans publication).
  Widget _videoWebRtc(LiveViewerState etat) {
    final piste = etat.pisteVideoLiveKit;
    if (piste == null) {
      return const Center(
        child: Text(
          'Connexion au flux…',
          style: TextStyle(color: AppColors.texteSecondaire, fontSize: 13),
        ),
      );
    }
    return VideoTrackRenderer(piste);
  }

  /// Repli Agora — rôle AUDIENCE (reçoit, n'interagit jamais).
  Widget _videoAgora(LiveViewerState etat) {
    final uid = etat.uidAgora;
    final canal = etat.bundle?.agoraChannel;
    final engine =
        ref.read(liveViewerProvider(_liveIdResolu!).notifier).engineAgora;
    if (uid == null || engine == null || canal == null) {
      return const Center(
        child: Text(
          'Réception du flux Agora…',
          style: TextStyle(color: AppColors.texteSecondaire, fontSize: 13),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: canal),
      ),
    );
  }

  /// Dernier repli : room Daily prebuilt dans le navigateur.
  Widget _vueDaily() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 40, color: AppColors.or),
            const SizedBox(height: 10),
            const Text(
              'Retransmission via Daily (dernier secours)',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.texteSecondaire, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.or),
              onPressed: () => ref
                  .read(liveViewerProvider(_liveIdResolu!).notifier)
                  .ouvrirDaily(),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Ouvrir le direct'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueEteinte(LiveViewerState etat) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off,
                size: 44, color: AppColors.texteEteint),
            const SizedBox(height: 10),
            Text(
              etat.raison ?? 'Le direct est terminé ou pas encore commencé.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.texteSecondaire, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.or),
              onPressed: () {
                ref.invalidate(liveActifProvider);
                ref
                    .read(liveViewerProvider(_liveIdResolu!).notifier)
                    .reessayer();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur(LiveViewerState etat) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 42, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(
              etat.erreur ?? 'Flux indisponible.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.texteSecondaire, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.or),
              onPressed: () => ref
                  .read(liveViewerProvider(_liveIdResolu!).notifier)
                  .reessayer(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  EN-TÊTE : titre, serviteur, durée, badge mode
  // ═════════════════════════════════════════════════════════════════

  Widget _enteteLive(LiveViewerState etat) {
    final live = etat.live;
    final titre = live?.title ?? 'Direct';
    final serviteur =
        (live?.servantName ?? '').isNotEmpty ? live!.servantName : null;
    final duree = live?.dureeSecondes ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.texte,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _badgeMode(etat),
            ],
          ),
          if (serviteur != null) ...[
            const SizedBox(height: 3),
            Text(
              'Serviteur : $serviteur',
              style: const TextStyle(
                  color: AppColors.texteSecondaire, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            etat.enPause
                ? '⏸ ${Formatters.chrono(duree)} (en pause)'
                : '🔴 En direct depuis ${Formatters.chrono(duree)}',
            style: const TextStyle(
                color: AppColors.or,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _badgeDirect(LiveViewerState etat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: etat.enPause ? AppColors.or : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            etat.enPause ? 'PAUSE' : 'DIRECT',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _badgeViewers(LiveViewerState etat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '${etat.nbViewers}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Badge mode discret (YouTube / WebRTC / Agora / Daily) — comme le web.
  Widget _badgeMode(LiveViewerState etat) {
    if (etat.mode == LiveViewerMode.chargement) {
      return const SizedBox.shrink();
    }
    final secours = etat.mode != LiveViewerMode.hls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.pourpreClair,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: secours ? AppColors.or.withValues(alpha: 0.6) : AppColors.orFonce,
        ),
      ),
      child: Text(
        etat.mode.libelle,
        style: TextStyle(
          color: secours ? AppColors.or : AppColors.texteSecondaire,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  RÉACTIONS RAPIDES (chat public type reaction — comme le web)
  // ═════════════════════════════════════════════════════════════════

  Widget _rangeeReactions() {
    const emojis = ['❤️', '🙏', '✋', '🔥'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (final e in emojis)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => ref
                    .read(liveViewerProvider(_liveIdResolu!).notifier)
                    .reagir(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.pourpre,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  CHAT PUBLIC (visiteurs anonymes côté web — nom de session ici)
  // ═════════════════════════════════════════════════════════════════

  Widget _zoneChat(LiveViewerState etat) {
    final monNom = ref.watch(authProvider).user?.name;
    return Expanded(
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.pourpreClair),
          Expanded(
            child: etat.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Soyez le premier à écrire…',
                      style: TextStyle(
                          color: AppColors.texteEteint, fontSize: 12.5),
                    ),
                  )
                : _listeAutoScroll(etat, monNom),
          ),
          _barreChat(etat),
        ],
      ),
    );
  }

  /// Liste qui suit automatiquement le bas (comme le chat du live web).
  Widget _listeAutoScroll(LiveViewerState etat, String? monNom) {
    final nb = etat.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollChat.hasClients) {
        _scrollChat.jumpTo(_scrollChat.position.maxScrollExtent);
      }
    });
    return ListView.builder(
      controller: _scrollChat,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: nb,
      itemBuilder: (context, i) => _ligneChat(etat.messages[i], monNom),
    );
  }

  Widget _ligneChat(LiveChatMessageModel m, String? monNom) {
    // Les réactions : une ligne emoji compacte.
    if (m.estReaction) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${m.emoji} ${m.userName}',
            style: const TextStyle(
                color: AppColors.texteEteint, fontSize: 11.5),
          ),
        ),
      );
    }
    final aMoi = monNom != null && m.userName == monNom;
    return Align(
      alignment: aMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        constraints: const BoxConstraints(maxWidth: 290),
        decoration: BoxDecoration(
          color: aMoi ? AppColors.bulleMoi : AppColors.bulleAutre,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.userName,
              style: const TextStyle(
                  color: AppColors.orPastel,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              m.content,
              style: const TextStyle(
                  color: AppColors.texte, fontSize: 13.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barreChat(LiveViewerState etat) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _saisieChat,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _envoyerChat(etat),
                decoration:
                    const InputDecoration(hintText: 'Écrire un message…'),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color:
                    etat.envoiChatEnCours ? AppColors.texteEteint : AppColors.or,
              ),
              onPressed:
                  etat.envoiChatEnCours ? null : () => _envoyerChat(etat),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _envoyerChat(LiveViewerState etat) async {
    final texte = _saisieChat.text.trim();
    if (texte.isEmpty || _liveIdResolu == null) return;
    _saisieChat.clear();
    await ref
        .read(liveViewerProvider(_liveIdResolu!).notifier)
        .envoyerChat(texte);
  }

  // ═════════════════════════════════════════════════════════════════
  //  AUCUN DIRECT EN COURS
  // ═════════════════════════════════════════════════════════════════

  Widget _vueSansDirect() {
    final actif = ref.watch(liveActifProvider);
    final suivant = ref.watch(liveSuivantProvider);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Icon(Icons.videocam_off_outlined,
            size: 60, color: AppColors.texteEteint),
        const SizedBox(height: 14),
        const Text(
          'Aucun direct en cours',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.texte,
              fontSize: 17,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 26),
        _carteProchainDirect(suivant.asData?.value),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.or),
          onPressed: () {
            ref.invalidate(liveActifProvider);
            ref.invalidate(liveSuivantProvider);
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: actif.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.or),
                )
              : const Text('Actualiser'),
        ),
      ],
    );
  }

  Widget _carteProchainDirect(LiveStreamModel? live) {
    if (live == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.or.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROCHAIN DIRECT',
            style: TextStyle(
                color: AppColors.or,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            live.title,
            style: const TextStyle(
                color: AppColors.texte,
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          if (live.scheduledAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${Formatters.jour(live.scheduledAt!)} à ${Formatters.heure(live.scheduledAt!)}',
              style: const TextStyle(
                  color: AppColors.texteSecondaire, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
