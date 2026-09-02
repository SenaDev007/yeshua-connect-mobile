/// Liste des conversations — le serveur n'envoie déjà plus les privés
/// des autres (V3.20) : tout ce qui apparaît ici est légitime.
///
/// ⭐ V1.5 — BANNIÈRE LIVE en tête : quand un direct est en cours, une
/// carte rouge « Rejoindre le direct » ouvre l'écran viewer (HLS mode
/// YouTube — le viewer n'est PAS un participant LiveKit).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../state/auth_controller.dart';
import '../../state/conversations_controller.dart';
import '../../state/live_viewer_controller.dart';
import '../widgets/conversation_tile.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  Timer? _ticLive;

  @override
  void initState() {
    super.initState();
    // Bannière LIVE rafraîchie toutes les 30 s (comme la landing web :
    // UpcomingLiveFloat 30 s — charge nulle sur le serverless).
    _ticLive = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(liveActifProvider);
    });
  }

  @override
  void dispose() {
    _ticLive?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(conversationsProvider);
    final meId = ref.watch(myIdProvider);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        title: const Text('Discussions'),
        actions: [
          // ⭐ V1.5 — Accès permanent au direct (même hors bannière).
          IconButton(
            tooltip: 'Direct en cours / à venir',
            icon: const Icon(Icons.sensors, color: AppColors.orPastel),
            onPressed: () => context.go('/app/live'),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh, color: AppColors.orPastel),
            onPressed: () {
              ref.read(conversationsProvider.notifier).rafraichir();
              ref.invalidate(liveActifProvider);
            },
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
                  ? Column(
                      children: [
                        _banniereLive(),
                        Expanded(child: _vueVide()),
                      ],
                    )
                  : Column(
                      children: [
                        _banniereLive(),
                        Expanded(
                          child: RefreshIndicator(
                            color: AppColors.or,
                            backgroundColor: AppColors.pourpre,
                            onRefresh: () => ref
                                .read(conversationsProvider.notifier)
                                .rafraichir(),
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
                                        .read(
                                            conversationsProvider.notifier)
                                        .marquerLu(conv.id);
                                    context.go('/app/chat/${conv.id}');
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  /// Carte « DIRECT EN COURS » — rouge, pulse, ouvre l'écran viewer.
  Widget _banniereLive() {
    final liveAsync = ref.watch(liveActifProvider);
    final live = liveAsync.asData?.value;
    if (live == null || !live.estEnCours) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/app/live/${live.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3D0E16), Color(0xFF2A0E3D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.danger, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DIRECT EN COURS',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        live.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.texte,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700),
                      ),
                      if ((live.servantName ?? '').isNotEmpty)
                        Text(
                          live.servantName!,
                          maxLines: 1,
                          style: const TextStyle(
                              color: AppColors.texteSecondaire,
                              fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Text(
                    'Rejoindre',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
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
              Icon(Icons.forum_outlined,
                  size: 56, color: AppColors.texteEteint),
              SizedBox(height: 16),
              Text(
                'Aucune discussion pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.texteSecondaire, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text(
                'Rejoignez les canaux de la communauté depuis la plateforme web '
                '— ils apparaîtront ici automatiquement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.texteEteint,
                    fontSize: 12.5,
                    height: 1.5),
              ),
            ],
          ),
        ),
      );

  Widget _vueErreur(BuildContext context, WidgetRef ref, String error) =>
      Center(
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
                style: const TextStyle(
                    color: AppColors.texteSecondaire, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(conversationsProvider.notifier).rafraichir(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}
