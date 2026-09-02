/// ⭐ V1.5 — Écran « Annonces » (parité web).
///
/// Lecture pour tous les membres ; CRÉATION pour les rôles annonceurs
/// (SUPER_ADMIN / ADMIN / MODERATOR / ANIMATOR — mêmes rôles que le web) :
/// titre + corps + canal ANNOUNCEMENT → POST /announcements, le message
/// apparaît aussitôt dans le canal choisi (chat + ici).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/announcement_model.dart';
import '../../data/repositories/announcements_repository.dart';
import '../../state/auth_controller.dart';

/// Rôles autorisés à publier des annonces (miroir exact du web).
const _rolesAnnonceurs = {
  'SUPER_ADMIN',
  'ADMIN',
  'MODERATOR',
  'ANIMATOR',
};

class AnnoncesScreen extends ConsumerStatefulWidget {
  const AnnoncesScreen({super.key});

  @override
  ConsumerState<AnnoncesScreen> createState() => _AnnoncesScreenState();
}

class _AnnoncesScreenState extends ConsumerState<AnnoncesScreen> {
  final AnnouncementsRepository _repo = AnnouncementsRepository();

  List<AnnonceModel> _annonces = [];
  List<CanalModel> _canauxAnnonces = [];
  bool _chargement = true;
  String? _erreur;

  bool get _peutPublier =>
      _rolesAnnonceurs.contains(ref.read(authProvider).user?.role);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final annonces = await _repo.lister();
      if (!mounted) return;
      setState(() {
        _annonces = annonces;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString();
      });
    }
  }

  /// Canaux ANNOUNCEMENT (chargés à la demande, pour la création).
  Future<void> _chargerCanaux() async {
    if (_canauxAnnonces.isNotEmpty) return;
    try {
      final canaux = await _repo.canaux();
      if (mounted) {
        setState(() =>
            _canauxAnnonces = canaux.where((c) => c.estAnnonce).toList());
      }
    } catch (_) {
      // Le dialogue affichera l'erreur au moment de la publication.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(title: const Text('Annonces de la communauté')),
      floatingActionButton: _peutPublier
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.or,
              foregroundColor: AppColors.nuit,
              onPressed: () async {
                await _chargerCanaux();
                if (!mounted) return;
                _dialogueCreation();
              },
              icon: const Icon(Icons.campaign),
              label: const Text('Publier'),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.or,
        backgroundColor: AppColors.pourpre,
        onRefresh: _charger,
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: AppColors.or))
            : _erreur != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.cloud_off,
                        size: 52, color: AppColors.danger),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _erreur!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.texteSecondaire, fontSize: 13.5),
                      ),
                    ),
                  ])
                : _annonces.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 110),
                        Icon(Icons.campaign_outlined,
                            size: 56, color: AppColors.texteEteint),
                        SizedBox(height: 14),
                        Text(
                          'Aucune annonce pour le moment',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.texteSecondaire,
                              fontSize: 15),
                        ),
                      ])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(14),
                        itemCount: _annonces.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _carte(_annonces[i]),
                      ),
      ),
    );
  }

  Widget _carte(AnnonceModel a) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pourpre,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: a.priority == 'HIGH'
                ? AppColors.danger.withValues(alpha: 0.55)
                : AppColors.or.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, size: 15, color: AppColors.or),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  a.title,
                  style: const TextStyle(
                      color: AppColors.texte,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (a.body.length > a.title.length) ...[
            const SizedBox(height: 6),
            Text(
              // Le corps serveur = « titre\n\ncorps » — on retire l'en-tête.
              a.body.startsWith('${a.title}\n\n')
                  ? a.body.substring('${a.title}\n\n'.length)
                  : a.body,
              style: const TextStyle(
                  color: AppColors.texteSecondaire,
                  fontSize: 13,
                  height: 1.45),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                a.priority == 'HIGH'
                    ? Icons.priority_high
                    : Icons.schedule,
                size: 12,
                color: a.priority == 'HIGH'
                    ? AppColors.danger
                    : AppColors.texteEteint,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${a.authorName} · ${a.channelName} · ${Formatters.tempsRelatif(a.publishedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.texteEteint, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  //  DIALOGUE DE CRÉATION (roles annonceurs)
  // ═════════════════════════════════════════════════════════════════

  void _dialogueCreation() {
    final titreCtrl = TextEditingController();
    final corpsCtrl = TextEditingController();
    String? canalChoisi;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogue) => AlertDialog(
          backgroundColor: AppColors.pourpre,
          title: const Text('Publier une annonce'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titreCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: corpsCtrl,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Corps de l\'annonce'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'CANAL D\'ANNONCES',
                  style: TextStyle(
                      color: AppColors.or,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1),
                ),
                const SizedBox(height: 6),
                if (_canauxAnnonces.isEmpty)
                  const Text(
                    'Aucun canal d\'annonces visible — créez-le depuis la '
                    'plateforme web.',
                    style: TextStyle(
                        color: AppColors.texteEteint, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _canauxAnnonces)
                        ChoiceChip(
                          label: Text(c.name,
                              style: const TextStyle(fontSize: 12)),
                          selected: canalChoisi == c.id,
                          selectedColor: AppColors.or,
                          labelStyle: TextStyle(
                              color: canalChoisi == c.id
                                  ? AppColors.nuit
                                  : AppColors.texteSecondaire),
                          onSelected: (_) =>
                              setDialogue(() => canalChoisi = c.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.or,
                  foregroundColor: AppColors.nuit),
              onPressed: () async {
                final titre = titreCtrl.text.trim();
                final corps = corpsCtrl.text.trim();
                if (titre.isEmpty || corps.isEmpty || canalChoisi == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Titre, corps et canal sont requis.')),
                  );
                  return;
                }
                try {
                  await _repo.publier(titre, corps, canalChoisi!);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _charger();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
  }
}
