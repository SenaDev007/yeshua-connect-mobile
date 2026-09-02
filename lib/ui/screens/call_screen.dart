/// Écran d'appel : sonnerie sortante (« Appel… ») → en cours (chrono) →
/// issue (refusé / manqué / annulé / terminé + durée).
///
/// ⭐ V1.1 — l'état `ActiveCallState` porte le nom + la photo de
/// L'APPELANT (sur un privé) pour TOUTE la durée de l'appel : l'écran du
/// destinataire n'affiche JAMAIS son propre nom (correctif web V3.20
/// `acceptIncomingCall`, appliqué côté mobile).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../state/call_controller.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // ── Type d'appel ──
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
                  ],
                ),
                const SizedBox(height: 24),
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
                      size: 118,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
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
                  const SizedBox(height: 14),
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
                const Spacer(flex: 3),
                // ── Contrôles ──
                _controles(context, ref, appel),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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

  Widget _controles(BuildContext context, WidgetRef ref, ActiveCallState appel) {
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

    // ── En communication : micro (décoratif d'état) + raccrocher ──
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Indicateur audio — l'activation réelle du micro suit le média
        // web (LiveKit/WebRTC) ; l'état local reflète l'appel.
        _boutonRond(
          icone: Icons.mic,
          couleur: AppColors.pourpreClair,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Le son de l\'appel transite par la plateforme web (LiveKit) — '
                  'rejoignez la salle depuis le bouton de conversation.',
                ),
              ),
            );
          },
        ),
        _boutonRond(
          icone: Icons.call_end,
          couleur: AppColors.danger,
          gros: true,
          onTap: () => ref.read(activeCallProvider.notifier).raccrocher(),
        ),
        _boutonRond(
          icone: appel.isVideo ? Icons.videocam : Icons.volume_up,
          couleur: AppColors.pourpreClair,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La vidéo de l\'appel transite par la plateforme web (LiveKit) — '
                  'rejoignez la salle depuis le bouton de conversation.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _boutonRond({
    required IconData icone,
    required Color couleur,
    required VoidCallback onTap,
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
