/// ⭐ V1.5 — Écran « Membres bloqués » (parité web V3.5).
///
/// Liste des membres bloqués avec déblocage direct. Le blocage coupe les
/// conversations privées et les appels privés — les canaux communs restent
/// ouverts (on bloque la personne, pas la communauté).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../state/blocks_controller.dart';
import '../widgets/avatar_widget.dart';

class BloquesScreen extends ConsumerWidget {
  const BloquesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(blocksProvider);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(title: const Text('Membres bloqués')),
      body: RefreshIndicator(
        color: AppColors.or,
        backgroundColor: AppColors.pourpre,
        onRefresh: () => ref.read(blocksProvider.notifier).charger(),
        child: etat.chargement && etat.bloques.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.or))
            : etat.bloques.isEmpty
                ? ListView(children: const <Widget>[
                    SizedBox(height: 120),
                    Icon(Icons.shield_outlined,
                        size: 56, color: AppColors.texteEteint),
                    SizedBox(height: 16),
                    Text(
                      'Aucun membre bloqué',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.texteSecondaire, fontSize: 15),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Depuis la fiche d'un membre, « Bloquer » coupe les "
                        'messages et appels privés dans les deux sens — les '
                        'canaux de la communauté restent ouverts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.texteEteint,
                            fontSize: 12.5,
                            height: 1.5),
                      ),
                    ),
                  ])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: etat.bloques.length,
                    separatorBuilder: (_, __) =>
                        const Divider(indent: 76, endIndent: 16),
                    itemBuilder: (context, i) =>
                        _ligne(context, ref, etat.bloques[i]),
                  ),
      ),
    );
  }

  Widget _ligne(BuildContext context, WidgetRef ref, m) {
    return ListTile(
      leading: AvatarWidget(photoUrl: m.avatarUrl, name: m.name, size: 46),
      title: Text(
        m.name,
        style: const TextStyle(
            color: AppColors.texte, fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'bloqué ${Formatters.tempsRelatif(m.blockedAt)}',
        style: const TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
      ),
      trailing: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.or,
          side: const BorderSide(color: AppColors.orFonce),
        ),
        onPressed: () async {
          final ok = await _confirmerDeblocage(context, m.name);
          if (ok == true) {
            await ref.read(blocksProvider.notifier).debloquer(m.userId);
          }
        },
        icon: const Icon(Icons.lock_open, size: 15),
        label: const Text('Débloquer', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<bool?> _confirmerDeblocage(BuildContext context, String nom) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.pourpre,
        title: Text('Débloquer $nom ?'),
        content: const Text(
          'Vous pourrez de nouveau vous écrire et vous appeler en privé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.or),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Débloquer'),
          ),
        ],
      ),
    );
  }
}
