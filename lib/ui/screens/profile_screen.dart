/// Fiche membre : bio, localisation, présence, canaux communs.
/// `userId == null` → affiche MON profil (session courante).
/// ⭐ V1.5 — blocage/déblocage depuis la fiche + gestion (bloqués,
/// annonces, messages programmés) depuis MON profil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_client.dart';
import '../../data/models/search_models.dart';
import '../../state/auth_controller.dart';
import '../../state/blocks_controller.dart';
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
    final blocage = ref.watch(blocksProvider);

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
        // ── ⭐ V1.5 : gestion (mon profil) ──
        if (estMoi) ...[
          const SizedBox(height: 20),
          const Text(
            'GESTION',
            style: TextStyle(
                color: AppColors.or,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          _tuileGestion(
            icone: Icons.block,
            titre: 'Membres bloqués',
            sousTitre: 'Messages et appels privés coupés',
            compteur: blocage.bloques.length,
            destination: '/app/profil/bloques',
          ),
          _tuileGestion(
            icone: Icons.campaign_outlined,
            titre: 'Annonces',
            sousTitre: 'Annonces de la communauté',
            destination: '/app/profil/annonces',
          ),
          _tuileGestion(
            icone: Icons.schedule_send_outlined,
            titre: 'Messages programmés',
            sousTitre: 'Envois automatiques en attente',
            destination: '/app/profil/programmes',
          ),
        ],
        // ── ⭐ V1.5 : blocage (fiche d'un autre membre) ──
        if (!estMoi) ...[
          const SizedBox(height: 20),
          _boutonBlocage(p.id, p.name),
        ],
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
          'Yeshua Connect V1.5 — Mouvement Christ Libère',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
        ),
      ],
    );
  }

  /// Tuile de gestion (mon profil) — navigue vers l'écran dédié.
  Widget _tuileGestion({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required String destination,
    int? compteur,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(icone, color: AppColors.or, size: 22),
        title: Text(
          titre,
          style: const TextStyle(
              color: AppColors.texte, fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          sousTitre,
          style: const TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compteur != null && compteur > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.or.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$compteur',
                  style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            const Icon(Icons.chevron_right, color: AppColors.texteSecondaire),
          ],
        ),
        onTap: () => context.go(destination),
      ),
    );
  }

  /// ⭐ V1.5 — Bouton Bloquer/Débloquer sur la fiche d'un autre membre
  /// (parité web V3.5 : coupe les privés dans les DEUX sens, les canaux
  /// communs restent ouverts).
  Widget _boutonBlocage(String userId, String nom) {
    final blocage = ref.watch(blocksProvider);
    final dejaBloque = blocage.estBloque(userId);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: dejaBloque ? AppColors.or : AppColors.danger,
        side: BorderSide(
            color: dejaBloque ? AppColors.orFonce : AppColors.danger),
      ),
      onPressed: () async {
        if (dejaBloque) {
          final ok = await showDialog<bool>(
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
          if (ok == true) {
            await ref.read(blocksProvider.notifier).debloquer(userId);
          }
        } else {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.pourpre,
              title: Text('Bloquer $nom ?'),
              content: const Text(
                'Vous ne pourrez plus vous écrire ni vous appeler en privé — '
                'dans les deux sens. Les canaux de la communauté restent '
                'ouverts (on bloque la personne, pas la communauté).',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Bloquer'),
                ),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(blocksProvider.notifier).bloquer(userId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$nom est bloqué.')),
              );
            }
          }
        }
      },
      icon: Icon(dejaBloque ? Icons.lock_open : Icons.block, size: 18),
      label: Text(dejaBloque ? 'Débloquer' : 'Bloquer ce membre'),
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
