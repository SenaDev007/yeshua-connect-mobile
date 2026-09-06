/// Liste des conversations — le serveur n'envoie déjà plus les privés
/// des autres (V3.20) : tout ce qui apparaît ici est légitime.
///
/// ⭐ V1.5 — BANNIÈRE LIVE en tête : quand un direct est en cours, une
/// carte rouge « Rejoindre le direct » ouvre l'écran viewer (HLS mode
/// YouTube — le viewer n'est PAS un participant LiveKit).
///
/// ⭐⭐ V1.7 — STRUCTURE EXACTE DE LA SIDEBAR WEB (MessagingView) :
/// 4 sections séparées et DÉPLIABLES/REPLIABLES (le pasteur : « la
/// sidebar qu'on peut dérouler et qu'on peut plier et replier ») :
///
///   • Canaux         (type CHANNEL)              — icône mégaphone
///   • Groupes        (GROUP + PASTORS)           — icône groupe
///   • Direct         (DIRECT)                    — icône message
///   • Canaux vocaux  (VOICE)                     — icône volume
///
/// Mêmes titres, mêmes icônes, même filtrage que le web — plus rien de
/// mélangé dans une liste plate (les canaux vocaux homonymes des canaux
/// texte n'apparaissent plus « dupliqués » côte à côte).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/conversation_model.dart';
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

  // Sections dépliables — ouvertes par défaut (comme la sidebar web).
  final Map<String, bool> _ouvert = {
    'canaux': true,
    'groupes': true,
    'direct': true,
    'vocaux': true,
  };

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

    // ⭐ V1.7 — MÊME FILTRAGE QUE LE WEB (MessagingView) :
    final canaux =
        etat.conversations.where((c) => c.type == 'CHANNEL').toList();
    final groupes = etat.conversations
        .where((c) => c.type == 'GROUP' || c.type == 'PASTORS')
        .toList();
    final directs =
        etat.conversations.where((c) => c.type == 'DIRECT').toList();
    final vocaux =
        etat.conversations.where((c) => c.type == 'VOICE').toList();

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
              : RefreshIndicator(
                  color: AppColors.or,
                  backgroundColor: AppColors.pourpre,
                  onRefresh: () =>
                      ref.read(conversationsProvider.notifier).rafraichir(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      _banniereLive(),
                      if (etat.conversations.isEmpty) ...[
                        const SizedBox(height: 60),
                        _vueVide(),
                      ] else ...[
                        // ═══ STRUCTURE DE LA SIDEBAR WEB ═══
                        if (canaux.isNotEmpty)
                          _Section(
                            cle: 'canaux',
                            titre: 'Canaux',
                            icone: Icons.campaign_outlined,
                            ouvert: _ouvert['canaux'] ?? true,
                            nonLus: _totalNonLus(canaux),
                            onToggle: _basculer,
                          ),
                        if (_ouvert['canaux'] ?? true)
                          for (final conv in canaux)
                            _tuile(conv, meId ?? ''),
                        if (groupes.isNotEmpty)
                          _Section(
                            cle: 'groupes',
                            titre: 'Groupes',
                            icone: Icons.groups_2_outlined,
                            ouvert: _ouvert['groupes'] ?? true,
                            nonLus: _totalNonLus(groupes),
                            onToggle: _basculer,
                          ),
                        if (_ouvert['groupes'] ?? true)
                          for (final conv in groupes)
                            _tuile(conv, meId ?? ''),
                        if (directs.isNotEmpty)
                          _Section(
                            cle: 'direct',
                            titre: 'Direct',
                            icone: Icons.chat_bubble_outline,
                            ouvert: _ouvert['direct'] ?? true,
                            nonLus: _totalNonLus(directs),
                            onToggle: _basculer,
                          ),
                        if (_ouvert['direct'] ?? true)
                          for (final conv in directs)
                            _tuile(conv, meId ?? ''),
                        if (vocaux.isNotEmpty)
                          _Section(
                            cle: 'vocaux',
                            titre: 'Canaux vocaux',
                            icone: Icons.volume_up_outlined,
                            ouvert: _ouvert['vocaux'] ?? true,
                            nonLus: _totalNonLus(vocaux),
                            accent: const Color(0xFF5AC8FA),
                            onToggle: _basculer,
                          ),
                        if (_ouvert['vocaux'] ?? true)
                          for (final conv in vocaux)
                            _tuile(conv, meId ?? ''),
                      ],
                    ],
                  ),
                ),
    );
  }

  int _totalNonLus(List<ConversationModel> convs) =>
      convs.fold(0, (sum, c) => sum + c.unreadCount);

  void _basculer(String cle) =>
      setState(() => _ouvert[cle] = !(_ouvert[cle] ?? true));

  Widget _tuile(ConversationModel conv, String meId) => ConversationTile(
        conversation: conv,
        meId: meId,
        onTap: () {
          ref
              .read(conversationsProvider.notifier)
              .marquerLu(conv.id);
          context.go('/app/chat/${conv.id}');
        },
      );

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

/// En-tête de section — cliquable pour DÉPLIER/REPLIER (le pasteur :
/// « la sidebar qu'on peut dérouler et qu'on peut plier et replier »).
/// Mêmes intitulés que la sidebar web : Canaux / Groupes / Direct /
/// Canaux vocaux.
class _Section extends StatelessWidget {
  final String cle;
  final String titre;
  final IconData icone;
  final bool ouvert;
  final int nonLus;
  final Color? accent;
  final void Function(String cle) onToggle;

  const _Section({
    required this.cle,
    required this.titre,
    required this.icone,
    required this.ouvert,
    required this.nonLus,
    required this.onToggle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = accent ?? AppColors.orPastel;
    return InkWell(
      onTap: () => onToggle(cle),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 6),
        child: Row(
          children: [
            Icon(icone, size: 15, color: couleur),
            const SizedBox(width: 7),
            Text(
              titre.toUpperCase(),
              style: TextStyle(
                color: couleur,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            if (nonLus > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.or,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  nonLus > 99 ? '99+' : '$nonLus',
                  style: const TextStyle(
                      color: AppColors.nuit,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
            const Spacer(),
            Icon(
              ouvert ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.texteEteint,
            ),
          ],
        ),
      ),
    );
  }
}
