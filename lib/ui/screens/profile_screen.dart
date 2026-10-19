/// Fiche membre : bio, localisation, présence, canaux communs.
/// `userId == null` → affiche MON profil (session courante).
/// ⭐ V1.5 — blocage/déblocage depuis la fiche + gestion (bloqués,
/// annonces, messages programmés) depuis MON profil.
///
/// ⭐ V2.5 — ÉDITION DU PROFIL (retour pasteur : « il faut qu'on puisse
/// modifier la photo, le nom ainsi que la bio depuis l'application mobile
/// pour que ça se synchronise automatiquement avec le web ») : crayon en
/// AppBar → feuille d'édition (photo compressée JPEG comme le web, nom,
/// téléphone, pays, ville, bio) → PUT /api/user/profile — LA MÊME API que
/// le site → la synchronisation est AUTOMATIQUE (la base est unique,
/// l'app relit /api/user/profile à chaque affichage, le web rafraîchit
/// via l'événement « profile-updated »).
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import 'menu_tiroir.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/api_client.dart';
import '../../data/models/search_models.dart';
import '../../data/models/user_model.dart';
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
        final session = ref.read(authProvider).user;
        if (session == null) throw const ApiException('Non connecté');
        // ⭐ V1.9 — Profil via l'API (photo TOUJOURS à jour, comme le web
        // qui relit /api/user/profile) ; repli sur la session JWT.
        // ⚠ CORRECTION : l'API renvoie l'utilisateur À PLAT
        // ({ id, name, avatarUrl, role, bio… }) — PAS enveloppé dans
        // { user: … }. L'ancien test `data['user'] is Map` était TOUJOURS
        // faux → l'app ne lisait jamais la vraie photo et retombait sur
        // le JWT (photo figée au moment du login) → « la photo ne
        // s'affiche pas ».
        var profilSession = MemberProfileModel(
          id: session.id,
          name: session.name,
          avatarUrl: session.image,
          role: session.role,
        );
        try {
          final data = await ApiClient.instance.getJson('/api/user/profile');
          if (data is Map) {
            final u = Map<String, dynamic>.from(data);
            profilSession = MemberProfileModel(
              id: u['id'] as String? ?? session.id,
              name: u['name'] as String? ?? session.name,
              avatarUrl: (u['avatarUrl'] as String?) ?? session.image,
              role: u['role'] as String? ?? session.role,
              bio: u['bio'] as String?,
              country: u['country'] as String?,
              city: u['city'] as String?,
              phone: u['phone'] as String?,
            );
          }
        } catch (_) {/* repli session */}
        if (!mounted) return;
        setState(() {
          _profil = profilSession;
          _chargement = false;
        });
      } else {
        final data = await ApiClient.instance
            .getJson('/api/yeshua-connect/members/${widget.userId}/profile');
        if (!mounted) return;
        if (data is Map) {
          setState(() {
            _profil =
                MemberProfileModel.fromJson(Map<String, dynamic>.from(data));
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

  /// ⭐ V2.5 — Ouvre la feuille d'édition du profil (photo, nom, téléphone,
  /// pays, ville, bio). À la fermeture (enregistré ou annulé), la fiche
  /// est rechargée — la photo et le nom affichés sont toujours ceux de la
  /// base (donc ceux du web aussi).
  void _ouvrirEdition() {
    final p = _profil;
    if (p == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.pourpre,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => FeuilleEditionProfil(
        profil: p,
        onEnregistre: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profil mis à jour — visible aussi sur le site.'),
                backgroundColor: AppColors.pourpreClair,
              ),
            );
          }
        },
      ),
    ).whenComplete(() {
      if (mounted) _charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.nuit,
      // ⭐ V2.4 — tiroir du ministère (accès aux autres modules).
      drawer: const MenuTiroir(),
      appBar: AppBar(
        title: Text(_estMoi ? 'Mon profil' : 'Fiche membre'),
        // ⭐ V2.4 — hamburger sur l'ONGLET racine uniquement : la fiche
        // d'un autre membre est POUSSÉE (flèche retour automatique).
        leading: _estMoi
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.or),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        // ⭐ V2.5 — CRAYON D'ÉDITION sur MON profil : ouvre la feuille
        // (photo, nom, téléphone, pays, ville, bio).
        actions: _estMoi
            ? [
                IconButton(
                  tooltip: 'Modifier mon profil',
                  icon: const Icon(Icons.edit, color: AppColors.or),
                  onPressed: _profil == null ? null : _ouvrirEdition,
                ),
              ]
            : null,
      ),
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
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.or.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.or.withValues(alpha: 0.5)),
                ),
                child: Text(
                  Formatters.labelRole(p.role),
                  style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700),
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
                  style: const TextStyle(
                      color: AppColors.texteEteint, fontSize: 12.5),
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
            [p.city, p.country]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(', '),
          ),
        if (p.memberSince != null)
          _carte('Membre depuis',
              '${Formatters.jour(p.memberSince!)} — année ${p.memberSince!.year}'),
        if (estMoi && session?.email != null)
          _carte('Email', session.email as String),
        if (estMoi && session?.id != null)
          _carte('Identifiant', session.id as String),
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
            destination: '/app/connect/profil/bloques',
          ),
          _tuileGestion(
            icone: Icons.campaign_outlined,
            titre: 'Annonces',
            sousTitre: 'Annonces de la communauté',
            destination: '/app/connect/profil/annonces',
          ),
          _tuileGestion(
            icone: Icons.schedule_send_outlined,
            titre: 'Messages programmés',
            sousTitre: 'Envois automatiques en attente',
            destination: '/app/connect/profil/programmes',
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
          'Christ Libère V2.7 — Mouvement Christ Libère',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(icone, color: AppColors.or, size: 22),
        title: Text(
          titre,
          style: const TextStyle(
              color: AppColors.texte,
              fontSize: 14.5,
              fontWeight: FontWeight.w700),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.or.withValues(alpha: 0.16),
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
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.danger),
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
            style: const TextStyle(
                color: AppColors.texte, fontSize: 14.5, height: 1.4),
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

// ═══════════════════════════════════════════════════════════════════
//  ⭐ V2.5 — FEUILLE D'ÉDITION DU PROFIL
// ═══════════════════════════════════════════════════════════════════

/// Éditeur de « Mon profil » — mêmes champs et MÊME API que le web
/// (ProfileSettingsModal → PUT /api/user/profile) :
///   · PHOTO : choisie via le sélecteur système, compressée en JPEG
///     natif (~320 px, qualité 82 → data-URL bien sous la limite API de
///     100 Ko — le web fait pareil via canvas 256) ;
///   · NOM (60), TÉLÉPHONE (20), PAYS (60), VILLE (60), BIO (280).
///
/// La sauvegarde met à jour LA base du site → la synchronisation web/app
/// est automatique (base unique). La session locale (tiroir, accueil) est
/// rafraîchie immédiatement via `majUtilisateur` — le JWT NextAuth, lui,
/// garde l'ancien nom jusqu'à la prochaine connexion, l'affichage reste
/// donc piloté par la base.
class FeuilleEditionProfil extends ConsumerStatefulWidget {
  final MemberProfileModel profil;
  final VoidCallback onEnregistre;

  const FeuilleEditionProfil({
    super.key,
    required this.profil,
    required this.onEnregistre,
  });

  @override
  ConsumerState<FeuilleEditionProfil> createState() =>
      _FeuilleEditionProfilState();
}

class _FeuilleEditionProfilState extends ConsumerState<FeuilleEditionProfil> {
  late final TextEditingController _nom =
      TextEditingController(text: widget.profil.name);
  late final TextEditingController _tel =
      TextEditingController(text: widget.profil.phone ?? '');
  late final TextEditingController _pays =
      TextEditingController(text: widget.profil.country ?? '');
  late final TextEditingController _ville =
      TextEditingController(text: widget.profil.city ?? '');
  late final TextEditingController _bio =
      TextEditingController(text: widget.profil.bio ?? '');

  /// Data-URL de la NOUVELLE photo (null tant qu'on n'en a pas choisie).
  String? _nouvellePhoto;

  /// Vrai quand l'utilisateur a RETIRÉ sa photo (avatarUrl → null).
  bool _photoRetiree = false;

  bool _enregistrement = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _pays.dispose();
    _ville.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// Photo affichée dans la feuille : nouvelle photo > photo retirée >
  /// photo actuelle de la base.
  String? get _photoActuelle {
    if (_nouvellePhoto != null) return _nouvellePhoto;
    if (_photoRetiree) return null;
    return widget.profil.avatarUrl;
  }

  /// Choix + compression de la photo (JPEG natif, ~320 px, data-URL) —
  /// même mécanique que le web (canvas 256 JPEG ≤ 60 Ko).
  Future<void> _choisirPhoto() async {
    setState(() => _erreur = null);
    try {
      final choix = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final octets = choix?.files.single.bytes;
      if (octets == null) return; // sélecteur fermé sans choix
      final compres = await FlutterImageCompress.compressWithList(
        octets,
        minWidth: 320,
        minHeight: 320,
        quality: 82,
        format: CompressFormat.jpeg,
      );
      if (compres.isEmpty) throw const FormatException();
      setState(() {
        _nouvellePhoto = 'data:image/jpeg;base64,${base64Encode(compres)}';
        _photoRetiree = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _erreur = 'Photo illisible — essayez une image JPG ou PNG.');
    }
  }

  Future<void> _enregistrer() async {
    if (_enregistrement) return;
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreur = 'Le nom ne peut pas être vide.');
      return;
    }
    if (!Connectivite.instance.enLigne) {
      setState(() => _erreur =
          'La modification du profil nécessite une connexion Internet.');
      return;
    }
    setState(() {
      _enregistrement = true;
      _erreur = null;
    });
    try {
      // MÊME API que le web → la base (unique) est mise à jour des deux
      // côtés : la synchronisation est automatique.
      await ApiClient.instance.putJson('/api/user/profile', body: {
        'name': nom,
        'phone': _tel.text.trim().isEmpty ? null : _tel.text.trim(),
        'country': _pays.text.trim().isEmpty ? null : _pays.text.trim(),
        'city': _ville.text.trim().isEmpty ? null : _ville.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'avatarUrl': _photoActuelle,
      });

      // ⭐ V2.5 — session locale rafraîchie aussitôt (tiroir, accueil,
      // profil) : le JWT NextAuth garde l'ancien nom jusqu'à la prochaine
      // connexion, l'affichage, lui, suit la base.
      final session = ref.read(authProvider).user;
      if (session != null) {
        await ref.read(authProvider.notifier).majUtilisateur(SessionUser(
              id: session.id,
              name: nom,
              email: session.email,
              image: _photoActuelle,
              role: session.role,
            ));
      }
      widget.onEnregistre();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _enregistrement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Échec de la sauvegarde — réessayez.';
        _enregistrement = false;
      });
    }
  }

  InputDecoration _decoration(String libelle, {String? aide}) =>
      InputDecoration(
        labelText: libelle,
        labelStyle: const TextStyle(color: AppColors.texteSecondaire),
        helperText: aide,
        helperStyle:
            const TextStyle(color: AppColors.texteEteint, fontSize: 11),
        filled: true,
        fillColor: AppColors.nuit,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pourpreClair),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.or, width: 1.2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Le clavier ne recouvre jamais les champs.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Poignée + titre + fermer ──
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.or.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Modifier mon profil',
                    style: TextStyle(
                      color: AppColors.texte,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close,
                      color: AppColors.texteSecondaire, size: 21),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Photo ──
            Center(
              child: GestureDetector(
                onTap: _choisirPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarWidget(
                      photoUrl: _photoActuelle,
                      name: _nom.text.isEmpty ? '?' : _nom.text,
                      size: 104,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: AppColors.or,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.nuit, width: 2.5),
                          ),
                        ),
                        child: const Icon(Icons.photo_camera,
                            size: 17, color: AppColors.nuit),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Toucher la photo pour la changer',
                style: TextStyle(color: AppColors.texteEteint, fontSize: 11.5),
              ),
            ),
            if (_photoActuelle != null)
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _enregistrement
                      ? null
                      : () => setState(() {
                            _nouvellePhoto = null;
                            _photoRetiree = true;
                          }),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Retirer la photo'),
                ),
              ),
            const SizedBox(height: 10),

            // ── Champs ──
            TextField(
              controller: _nom,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.texte),
              decoration: _decoration('Nom affiché'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tel,
              maxLength: 20,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.texte),
              decoration: _decoration('Téléphone', aide: 'Ex. +229 …'),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ville,
                    maxLength: 60,
                    style: const TextStyle(color: AppColors.texte),
                    decoration: _decoration('Ville'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pays,
                    maxLength: 60,
                    style: const TextStyle(color: AppColors.texte),
                    decoration: _decoration('Pays'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _bio,
              maxLength: 280,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(color: AppColors.texte, height: 1.4),
              decoration: _decoration(
                'Bio',
                aide: 'Quelques mots sur vous, visibles par la communauté.',
              ),
            ),
            const SizedBox(height: 6),

            // ── Erreur ──
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  _erreur!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5),
                ),
              ),

            // ── Enregistrer ──
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.nuit,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _enregistrement ? 'Enregistrement…' : 'Enregistrer',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vos modifications sont enregistrées sur le site — elles '
              's\'appliquent automatiquement au web et à l\'application.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.texteEteint, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
