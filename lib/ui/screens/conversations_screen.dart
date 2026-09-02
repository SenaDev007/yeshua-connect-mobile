/// Liste des conversations — le serveur n'envoie déjà plus les privés
/// des autres (V3.20) : tout ce qui apparaît ici est légitime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/conversations_controller.dart';
import '../widgets/conversation_tile.dart';
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(conversationsProvider);
    final meId = ref.watch(myIdProvider);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        title: const Text('Discussions'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh, color: AppColors.orPastel),
            onPressed: () => ref.read(conversationsProvider.notifier).rafraichir(),
          ),
        ],
      ),
      body: etat.chargement && etat.conversations.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.or),
            )
          : etat.error != null && etat.conversations.isEmpty
              ? _vueErreur(context, ref, etat.error!)
              : etat.conversations.isEmpty
                  ? _vueVide()
                  : RefreshIndicator(
                      color: AppColors.or,
                      backgroundColor: AppColors.pourpre,
                      onRefresh: () =>
                          ref.read(conversationsProvider.notifier).rafraichir(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: etat.conversations.length,
                        separatorBuilder: (_, __) =>
                            const Divider(indent: 76, endIndent: 12),
                        itemBuilder: (context, i) {
                          final conv = etat.conversations[i];
                          return ConversationTile(
                            conversation: conv,
                            meId: meId ?? '',
                            onTap: () {
                              ref
                                  .read(conversationsProvider.notifier)
                                  .marquerLu(conv.id);
                              context.go('/app/chat/${conv.id}');
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _vueVide() => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 56, color: AppColors.texteEteint),
              SizedBox(height: 16),
              Text(
                'Aucune discussion pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.texteSecondaire, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text(
                'Rejoignez les canaux de la communauté depuis la plateforme web '
                '— ils apparaîtront ici automatiquement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.texteEteint, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      );

  Widget _vueErreur(BuildContext context, WidgetRef ref, String error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 52, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => ref.read(conversationsProvider.notifier).rafraichir(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}
