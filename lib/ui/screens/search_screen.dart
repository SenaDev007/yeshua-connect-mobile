/// Recherche globale : membres, canaux, messages (résultats triés par
/// pertinence : membres d'abord).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../state/search_controller.dart';
import '../widgets/avatar_widget.dart';
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        title: const Text('Recherche'),
      ),
      body: Column(
        children: [
          // ── Champ de recherche ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: TextField(
              controller: _ctrl,
              onChanged: (q) =>
                  ref.read(searchProvider.notifier).onQueryChanged(q),
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColors.orPastel),
                hintText: 'Membres, canaux, messages…',
                suffixIcon: etat.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.texteSecondaire),
                        onPressed: () {
                          _ctrl.clear();
                          ref.read(searchProvider.notifier).onQueryChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // ── Résultats ──
          Expanded(
            child: etat.enCours
                ? const Center(child: CircularProgressIndicator(color: AppColors.or))
                : etat.query.trim().length < 2
                    ? _aide()
                    : etat.resultats.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun résultat',
                              style: TextStyle(color: AppColors.texteSecondaire),
                            ),
                          )
                        : _resultats(etat),
          ),
        ],
      ),
    );
  }

  Widget _aide() => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.manage_search, size: 52, color: AppColors.texteEteint),
              SizedBox(height: 14),
              Text(
                'Tapez au moins 2 lettres',
                style: TextStyle(color: AppColors.texteSecondaire, fontSize: 14),
              ),
              SizedBox(height: 6),
              Text(
                'La recherche parcourt les membres, les canaux publics et vos '
                'conversations. Les messages privés n\'apparaissent jamais '
                '(confidentialité V3.20).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.texteEteint, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      );

  Widget _resultats(SearchState etat) {
    final r = etat.resultats;
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 20),
      children: [
        if (r.users.isNotEmpty) ..._section('Membres'),
        ...r.users.map((u) => ListTile(
              leading: AvatarWidget(photoUrl: u.avatarUrl, name: u.name, size: 42),
              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                Formatters.labelRole(u.role),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => context.push('/app/profil/${u.id}'),
            )),
        if (r.channels.isNotEmpty) ..._section('Canaux'),
        ...r.channels.map((c) => ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.pourpreClair,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_outlined, color: AppColors.or, size: 20),
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                Formatters.labelType(c.type),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => context.go('/app/chat/${c.id}'),
            )),
        if (r.messages.isNotEmpty) ..._section('Messages'),
        ...r.messages.map((m) => ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.pourpreClair,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, color: AppColors.orPastel, size: 19),
              ),
              title: Text(
                Formatters.apercu(m.content, max: 46),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${m.senderName} · ${m.channelName} · ${Formatters.tempsRelatif(m.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5),
              ),
              onTap: () => context.go('/app/chat/${m.channelId}'),
            )),
      ],
    );
  }

  List<Widget> _section(String titre) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Text(
            titre.toUpperCase(),
            style: const TextStyle(
              color: AppColors.or,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ];
}
