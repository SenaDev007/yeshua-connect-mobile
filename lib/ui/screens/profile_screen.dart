/// Fiche membre : bio, localisation, présence, canaux communs.
/// `userId == null` → affiche MON profil (session courante).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_client.dart';
import '../../data/models/search_models.dart';
import '../../state/auth_controller.dart';
import '../widgets/avatar_widget.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  MemberProfileModel? _profil;
  bool _chargement = true;
  String? _error;

  bool get _estMoi => widget.userId == null;

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
      if (_estMoi) {
        // Profil = session courante (id, nom, rôle, email).
        final session = ref.read(authProvider).user;
        if (session == null) throw const ApiException('Non connecté');
        setState(() {
          _profil = MemberProfileModel(
            id: session.id,
            name: session.name,
            avatarUrl: session.image,
            role: session.role,
          );
          _chargement = false;
        });
      } else {
        final data = await ApiClient.instance
            .getJson('/api/yeshua-connect/members/${widget.userId}/profile');
        if (!mounted) return;
        if (data is Map) {
          setState(() {
            _profil = MemberProfileModel.fromJson(Map<String, dynamic>.from(data));
            _chargement = false;
          });
        } else {
          throw const ApiException('Membre introuvable');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deconnexion(BuildContext context) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      // Le routeur redirige automatiquement via l'état auth.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(title: Text(_estMoi ? 'Mon profil' : 'Fiche membre')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: AppColors.or))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _corps(session),
    );
  }

  Widget _corps(dynamic session) {
    final p = _profil!;
    final estMoi = _estMoi;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── En-tête ──
        Center(
          child: Column(
            children: [
              AvatarWithPresence(
                photoUrl: p.avatarUrl,
                name: p.name,
                online: p.isOnline,
                size: 110,
              ),
              const SizedBox(height: 16),
              Text(
                p.name,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.or.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.or.withOpacity(0.5)),
                ),
                child: Text(
                  Formatters.labelRole(p.role),
                  style: const TextStyle(color: AppColors.or, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (p.isOnline) ...[
                const SizedBox(height: 8),
                const Text(
                  '● en ligne',
                  style: TextStyle(color: AppColors.enLigne, fontSize: 12.5),
                ),
              ] else if (p.lastSeenAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'vu ${Formatters.tempsRelatif(p.lastSeenAt!)}',
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        // ── Détails ──
        if ((p.bio ?? '').isNotEmpty) _carte('Bio', p.bio!),
        if ((p.city ?? '').isNotEmpty || (p.country ?? '').isNotEmpty)
          _carte(
            'Localisation',
            [p.city, p.country].whereType<String>().where((s) => s.isNotEmpty).join(', '),
          ),
        if (p.memberSince != null)
          _carte('Membre depuis', '${Formatters.jour(p.memberSince!)} — année ${p.memberSince!.year}'),
        if (estMoi && session?.email != null) _carte('Email', session.email as String),
        if (estMoi && session?.id != null) _carte('Identifiant', session.id as String),
        const SizedBox(height: 20),
        // ── Actions ──
        if (estMoi)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () => _confirmerDeconnexion(context),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        const SizedBox(height: 30),
        const Text(
          'Yeshua Connect V1.1 — Mouvement Christ Libère',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _carte(String titre, String valeur) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre.toUpperCase(),
            style: const TextStyle(
              color: AppColors.or,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            valeur,
            style: const TextStyle(color: AppColors.texte, fontSize: 14.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.pourpre,
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez ressaisir votre pseudonyme et mot de passe pour revenir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deconnexion(context);
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
