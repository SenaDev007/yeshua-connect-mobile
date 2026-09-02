/// Écran d'appel : sonnerie sortante (« Appel… ») → en cours (chrono) →
/// issue (refusé / manqué / annulé / terminé + durée).
///
/// ⭐ V1.1 — l'état `ActiveCallState` porte le nom + la photo de
/// L'APPELANT (sur un privé) pour TOUTE la durée de l'appel : l'écran du
/// destinataire n'affiche JAMAIS son propre nom (correctif web V3.20
/// `acceptIncomingCall`, appliqué côté mobile).
///
/// ⭐⭐ V3.21 — LE MÉDIA EST RÉEL : LiveKit (source de vérité) → Agora →
/// Daily, arbitré par le serveur (chaîne de repli du pasteur). L'écran
/// affiche les PARTICIPANTS connectés (bulles audio / indicateur parole),
/// le badge « Réseau : LiveKit/Agora/Daily », le bandeau « Bascule
/// automatique… » pendant un failover, et les VRAIS contrôles (micro,
/// caméra, haut-parleur, raccrocher) routés vers le fournisseur actif.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../state/call_controller.dart';
import '../../state/call_media_controller.dart';
import '../widgets/avatar_widget.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.97,
      upperBound: 1.03,
    );
    // Le chrono est rafraîchi par le contrôleur ; ce tick UI est un filet
    // de sécurité (latence réseau du polling).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appel = ref.watch(activeCallProvider);
    final media = ref.watch(callMediaProvider);

    // Plus d'appel (fermé) → retour aux discussions.
    if (appel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/app');
      });
      return const Scaffold(backgroundColor: AppColors.nuit);
    }

    final enSonnerie = appel.phase == CallPhase.sonnerie;
    if (enSonnerie) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) _pulse.stop();
    }

    final sousTitre = _sousTitre(appel);
    final enCommunication = appel.phase == CallPhase.enCours;

    return Scaffold(
      backgroundColor: AppColors.nuit,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.nuit, AppColors.pourpre],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // ── Type d'appel + badge réseau (⭐ V3.21) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      appel.isVideo ? Icons.videocam : Icons.call,
                      size: 16,
                      color: AppColors.or,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      appel.isVideo ? 'APPEL VIDÉO' : 'APPEL AUDIO',
                      style: const TextStyle(
                        color: AppColors.or,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _badgeReseau(media),
                  ],
                ),
                // ── Bandeau bascule automatique (⭐ V3.21) ──
                if (media.basculeEnCours) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.or.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.or.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.or,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Bascule automatique vers le réseau de secours…',
                          style: TextStyle(color: AppColors.or, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
                if (media.erreur != null && !media.basculeEnCours) ...[
                  const SizedBox(height: 10),
                  Text(
                    media.erreur!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(flex: 2),
                // ── Photo (pulsée pendant la sonnerie) ──
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: enSonnerie ? AppColors.or : AppColors.orFonce,
                        width: 2.5,
                      ),
                    ),
                    child: AvatarWidget(
                      photoUrl: appel.displayAvatar,
                      name: appel.displayName,
                      size: 112,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ⭐ V1.1 — nom de L'APPELANT (privé) / de la conversation
                Text(
                  appel.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sousTitre,
                  style: TextStyle(
                    color: enSonnerie ? AppColors.orPastel : AppColors.texteSecondaire,
                    fontSize: 14,
                  ),
                ),
                if (appel.phase == CallPhase.enCours) ...[
                  const SizedBox(height: 12),
                  Text(
                    Formatters.chrono(appel.dureeSecondes),
                    style: const TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
                // ── ⭐ V3.21 : participants réellement connectés ──
                if (enCommunication && media.participants.isNotEmpty) ...[
                  const Spacer(),
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: media.participants.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final p = media.participants[i];
                        return _tuileParticipant(p);
                      },
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                // ── Contrôles ──
                _controles(context, ref, appel, media),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Badge « Réseau : LiveKit / Agora (secours) / Daily (secours) ».
  Widget _badgeReseau(MediaChainState media) {
    if (media.fournisseur == MediaProviderNom.aucun) {
      return const SizedBox.shrink();
    }
    final secours = media.fournisseur != MediaProviderNom.livekit;
    final dailyNavigateur = media.fournisseur == MediaProviderNom.daily;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pourpreClair,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: secours ? AppColors.or.withValues(alpha: 0.6) : AppColors.orFonce,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            dailyNavigateur ? Icons.open_in_new : Icons.network_check,
            size: 11,
            color: secours ? AppColors.or : AppColors.texteSecondaire,
          ),
          const SizedBox(width: 5),
          Text(
            dailyNavigateur
                ? 'Réseau : Daily (navigateur)'
                : 'Réseau : ${media.fournisseur.libelle}${secours ? ' (secours)' : ''}',
            style: TextStyle(
              color: secours ? AppColors.or : AppColors.texteSecondaire,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile d'un participant distant (photo + nom + micro/parole).
  Widget _tuileParticipant(MediaParticipant p) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pourpreClair,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: p.parle ? AppColors.or : Colors.transparent,
          width: p.parle ? 1.6 : 0,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarWidget(
                photoUrl: null,
                name: p.name ?? p.identity,
                size: 46,
              ),
              if (!p.microActif)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off, size: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            p.name ?? 'Membre',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _sousTitre(ActiveCallState appel) {
    switch (appel.phase) {
      case CallPhase.sonnerie:
        return appel.jeSuisAppelant ? 'Appel en cours…' : 'Connexion…';
      case CallPhase.enCours:
        return appel.isDirect ? 'Appel privé en cours' : 'Appel de groupe en cours';
      case CallPhase.refusee:
      case CallPhase.manquee:
      case CallPhase.annulee:
      case CallPhase.terminee:
        return appel.resultText ?? 'Appel terminé';
    }
  }

  Widget _controles(
    BuildContext context,
    WidgetRef ref,
    ActiveCallState appel,
    MediaChainState media,
  ) {
    // ── Issue : écran récapitulatif simple + bouton fermer ──
    if (appel.phase != CallPhase.sonnerie && appel.phase != CallPhase.enCours) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              ref.read(activeCallProvider.notifier).reinitialiser();
              context.go('/app');
            },
            icon: const Icon(Icons.close),
            label: const Text('Fermer'),
          ),
        ],
      );
    }

    final mediaCtrl = ref.read(callMediaProvider.notifier);

    // ── En communication : VRAIS contrôles multimédias (⭐ V3.21) ──
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Micro — coupe/rallume sur le fournisseur ACTIF (LiveKit/Agora).
        _boutonRond(
          icone: media.microCoupe ? Icons.mic_off : Icons.mic,
          couleur: media.microCoupe ? AppColors.danger : AppColors.pourpreClair,
          onTap: () => mediaCtrl.basculerMicro(),
        ),
        // Raccrocher.
        _boutonRond(
          icone: Icons.call_end,
          couleur: AppColors.danger,
          gros: true,
          onTap: () => ref.read(activeCallProvider.notifier).raccrocher(),
        ),
        // Caméra (appel vidéo) — LiveKit/Agora.
        _boutonRond(
          icone: appel.isVideo
              ? (media.cameraActive ? Icons.videocam : Icons.videocam_off)
              : Icons.volume_up,
          couleur: (appel.isVideo && !media.cameraActive)
              ? AppColors.orFonce
              : AppColors.pourpreClair,
          onTap: appel.isVideo ? () => mediaCtrl.basculerCamera() : null,
        ),
      ],
    );
  }

  Widget _boutonRond({
    required IconData icone,
    required Color couleur,
    required VoidCallback? onTap,
    bool gros = false,
  }) {
    final taille = gros ? 72.0 : 58.0;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: taille,
            height: taille,
            child: Icon(icone, color: AppColors.texte, size: gros ? 32 : 24),
          ),
        ),
      ),
    );
  }
}
