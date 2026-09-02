/// ═══════════════════════════════════════════════════════════════════
/// ⭐⭐⭐ V1.1 — CORRECTIF « NOM DE L'APPELANT » ⭐⭐⭐
///
/// BUG V1.0 : cet écran titrait `convName` (le nom du CANAL). Or sur un
/// privé, le nom du canal est celui du DESTINATAIRE choisi par le
/// créateur → quand Pam appelait Ora, l'écran de Ora affichait…
/// « Ora » (son propre nom).
///
/// CORRECTIF V1.1 (s'appuie sur la V3.20 serveur, qui renvoie
/// `isDirect` + `initiatorName`/`initiatorAvatarUrl`) :
///
///   • Privé (`isDirect == true`)  → GRAND TITRE = **L'APPELANT**
///     (`initiatorName`) avec SA photo prioritaire — « Pam vous appelle ».
///   • Canal / groupe              → nom du CANAL en grand, appelant en
///     sous-ligne (« Appel de Pam »), photo du canal.
///
/// Tout passe par `IncomingCallModel.displayTitle` / `displayAvatar` /
/// `displaySubtitle` — une seule source de vérité, testable.
/// ═══════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/call_model.dart';
import '../../state/call_controller.dart';
import '../../state/incoming_call_controller.dart';
import '../widgets/avatar_widget.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _expiration;

  @override
  void initState() {
    super.initState();
    // Pulsation de la photo (comme la sonnerie WhatsApp).
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.96,
      upperBound: 1.04,
    )..repeat(reverse: true);

    // Filet de sécurité : le serveur balaye « manqué » à 45 s — on ferme
    // l'écran local après 50 s si l'utilisateur n'a rien touché.
    _expiration = Timer(const Duration(seconds: 50), () {
      if (mounted) _terminerSansReponse();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _expiration?.cancel();
    super.dispose();
  }

  void _terminerSansReponse() {
    final appel = ref.read(incomingCallProvider).actuel;
    if (appel != null) {
      // Refus implicite → le signal serveur devient « missed/declined »
      // au prochain balayage ; on marque localement traité.
      ref.read(incomingCallProvider.notifier).terminer();
    }
    if (mounted) context.go('/app');
  }

  Future<void> _refuser(IncomingCallModel appel) async {
    ref.read(incomingCallProvider.notifier).terminer();
    try {
      // Refus explicite → côté serveur, termine l'appel sur un DIRECT.
      await ref.read(incomingCallProvider.notifier).refuser(appel.callId);
    } catch (_) {/* le balayage serveur tranche de toute façon */}
    if (mounted) context.go('/app');
  }

  Future<void> _accepter(IncomingCallModel appel) async {
    ref.read(incomingCallProvider.notifier).terminer();
    try {
      // ⭐ V1.1 — le contrôleur conserve l'info de L'APPELANT
      // (displayTitle/displayAvatar titrent l'appelant sur un privé)
      // pour TOUTE la durée de l'appel — jamais le nom du destinataire.
      await ref.read(activeCallProvider.notifier).repondre(appel);
      if (mounted) context.go('/app/appel');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de décrocher : $e')),
        );
        context.go('/app');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appel = ref.watch(incomingCallProvider).actuel;

    // Aucun appel (expiré/refusé ailleurs) → retour silencieux.
    if (appel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/app');
      });
      return const Scaffold(backgroundColor: AppColors.nuit);
    }

    // ⭐⭐ V1.1 — LE CORRECTIF, concentré ici ⭐⭐
    // displayTitle = initiatorName si privé, convName sinon.
    final titre = appel.displayTitle;
    final photo = appel.displayAvatar;
    final sousLigne = appel.displaySubtitle; // null sur un privé
    final estVideo = appel.isVideo;

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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // ── Étiquette type d'appel ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.or.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.or.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        estVideo ? Icons.videocam : Icons.call,
                        size: 15,
                        color: AppColors.or,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        estVideo ? 'APPEL VIDÉO ENTRANT' : 'APPEL AUDIO ENTRANT',
                        style: const TextStyle(
                          color: AppColors.or,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // ── Photo de L'APPELANT (pulsée) ──
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.or, width: 2.5),
                    ),
                    child: AvatarWidget(
                      photoUrl: photo,
                      name: titre,
                      size: 128,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                // ⭐⭐ LE TITRE CORRIGÉ : l'APPELANT en grand sur un privé ⭐⭐
                Text(
                  '$titre vous appelle',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (sousLigne != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    sousLigne,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: AppColors.or),
                      SizedBox(width: 5),
                      Text(
                        'Conversation privée',
                        style: TextStyle(color: AppColors.or, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const Spacer(flex: 3),
                // ── Boutons Décrocher / Refuser ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _boutonAction(
                      libelle: 'Refuser',
                      icone: Icons.call_end,
                      couleur: AppColors.danger,
                      onTap: () => _refuser(appel),
                    ),
                    _boutonAction(
                      libelle: 'Décrocher',
                      icone: estVideo ? Icons.videocam : Icons.call,
                      couleur: AppColors.succes,
                      onTap: () => _accepter(appel),
                      gros: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _boutonAction({
    required String libelle,
    required IconData icone,
    required Color couleur,
    required VoidCallback onTap,
    bool gros = false,
  }) {
    final taille = gros ? 74.0 : 64.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: taille,
                height: taille,
                child: Icon(icone, color: Colors.white, size: gros ? 34 : 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          libelle,
          style: const TextStyle(
            color: AppColors.texteSecondaire,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
