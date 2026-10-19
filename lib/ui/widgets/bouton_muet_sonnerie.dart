/// ⭐ V2.8 — BOUTON MUET DES SONNERIES (widget partagé).
///
/// « Un bouton lié pour pouvoir mettre le son, la sonnerie en muet au
/// cas où ça dérangerait l'utilisateur. » Placé partout où la sonnerie
/// résonne : écran de lancement (shofar), écran d'appel (ringback),
/// menu tiroir (accès permanent).
///
/// La bascule persiste la préférence (mode muet global) :
///   • couper  → arrête immédiatement la sonnerie en cours (callback
///     [onCoupe], ex. stop du shofar ou du ringback) ;
///   • réactiver → relance la sonnerie si pertinent (callback
///     [onReactive]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/sons_controller.dart';

class BoutonMuetSonnerie extends ConsumerWidget {
  /// Appelé quand le son vient d'être coupé (stop immédiat de la sonnerie
  /// en cours). Optionnel.
  final VoidCallback? onCoupe;

  /// Appelé quand le son vient d'être réactivé (relance si pertinent).
  /// Optionnel.
  final VoidCallback? onReactive;

  /// Taille de l'icône.
  final double tailleIcone;

  const BoutonMuetSonnerie({
    super.key,
    this.onCoupe,
    this.onReactive,
    this.tailleIcone = 18,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muet = ref.watch(sonsMuetsProvider);

    // Libellé accessible complet du bouton.
    final libelle = muet
        ? 'Réactiver le son des sonneries (shofar, appel…)'
        : 'Couper le son des sonneries (shofar, appel…)';

    return Tooltip(
      message: libelle,
      child: TextButton(
        onPressed: () async {
          final controller = ref.read(sonsMuetsProvider.notifier);
          final etaitMuet = ref.read(sonsMuetsProvider);
          await controller.basculer();
          if (etaitMuet) {
            onReactive?.call();
          } else {
            onCoupe?.call();
          }
        },
        style: TextButton.styleFrom(
          foregroundColor:
              muet ? AppColors.texteSecondaire : AppColors.orPastel,
          side: BorderSide(
            color: (muet ? AppColors.texteEteint : AppColors.or)
                .withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(9),
          minimumSize: const Size(40, 40),
        ),
        child: Icon(
          muet ? Icons.volume_off : Icons.volume_up,
          size: tailleIcone,
        ),
      ),
    );
  }
}
