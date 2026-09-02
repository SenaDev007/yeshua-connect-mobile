/// Panneau des membres d'une conversation : présence, badges de rôle,
/// « Écrire en privé » (règle anti-spam serveur : canal commun requis).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/search_models.dart';
import '../../data/repositories/conversations_repository.dart';
import '../../state/conversations_controller.dart';
import '../widgets/avatar_widget.dart';
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final ConversationsRepository _repo = ConversationsRepository();
  List<MemberModel> _membres = [];
  bool _chargement = true;
  String? _error;
  bool _ouverturePrive = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _error = null;
    });
    try {
      final membres = await _repo.membres(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _membres = membres;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _ecrireEnPrive(MemberModel membre) async {
    if (_ouverturePrive) return;
    setState(() => _ouverturePrive = true);
    try {
      final convId =
          await ref.read(conversationsProvider.notifier).demarrerPrive(membre.userId);
      await ref.read(conversationsProvider.notifier).rafraichir(silencieux: true);
      if (mounted) {
        context.go('/app/chat/$convId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _ouverturePrive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(title: const Text('Membres')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: AppColors.or))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.or,
                  backgroundColor: AppColors.pourpre,
                  onRefresh: _charger,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _membres.length,
                    separatorBuilder: (_, __) => const Divider(indent: 76, endIndent: 12),
                    itemBuilder: (context, i) {
                      final m = _membres[i];
                      return _tuileMembre(m);
                    },
                  ),
                ),
    );
  }

  Widget _tuileMembre(MemberModel m) {
    final badge = Formatters.labelRole(m.userRole ?? m.role);
    final estAdmin = m.userRole == 'SUPER_ADMIN' || m.userRole == 'ADMIN';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AvatarWithPresence(
        photoUrl: m.avatarUrl,
        name: m.name,
        online: m.isOnline,
        size: 46,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              m.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          if (estAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.or.withOpacity(0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.or.withOpacity(0.55)),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(color: AppColors.or, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        m.isOnline ? 'en ligne · $badge' : badge,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Écrire en privé',
        icon: Icon(
          Icons.chat_bubble_outline,
          color: _ouverturePrive ? AppColors.texteEteint : AppColors.or,
          size: 21,
        ),
        onPressed: _ouverturePrive ? null : () => _ecrireEnPrive(m),
      ),
      onTap: () => context.push('/app/profil/${m.userId}'),
    );
  }
}
