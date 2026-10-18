/// ⭐ V2.0 — ENSEIGNEMENTS (miroir de la page /enseignements du site).
/// ⭐ V2.3 — Articles professionnels : gras/italique rendus (fini les
///          astérisques visibles), titres hiérarchisés, versets en
///          blocs citation, listes dorées — miroir du design web.
///
/// Liste des enseignements bibliques des deux serviteurs avec recherche
/// plein texte (titre, thème, livre), filtres par serviteur et par
/// niveau, puis fiche de lecture complète.
///
/// HORS-LIGNE : tout vient de la base SQLite locale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/markdown_texte.dart';
import '../../data/models/contenu_models.dart';
import '../../state/contenu_controller.dart';
import '../widgets/contenu_widgets.dart';

class EnseignementsScreen extends ConsumerStatefulWidget {
  const EnseignementsScreen({super.key});

  @override
  ConsumerState<EnseignementsScreen> createState() => _EnseignementsScreenState();
}

class _EnseignementsScreenState extends ConsumerState<EnseignementsScreen> {
  final _recherche = TextEditingController();
  String _serviteur = 'all';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageEnseignements(enfant: EtatPremiereSync());
    }

    final q = _recherche.text.trim().toLowerCase();
    var enseignements = contenu.enseignements.where((e) {
      if (_serviteur != 'all' && e.serviteur != _serviteur) return false;
      if (q.isNotEmpty) {
        final haystack =
            '${e.titre} ${e.theme} ${e.livre} ${nettoyerMarkdown(e.extrait)}'
                .toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();

    return _PageEnseignements(
      enfant: Column(
        children: [
          HeroEnTete(hero: contenu.hero('enseignements'), hauteur: 150),
          // ── Barre de recherche ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: TextField(
              controller: _recherche,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.texte, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher un enseignement, un thème, un livre…',
                hintStyle: const TextStyle(color: AppColors.texteEteint, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.or, size: 20),
                filled: true,
                fillColor: AppColors.pourpre,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.pourpreClair),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.pourpreClair),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.or),
                ),
              ),
            ),
          ),
          // ── Filtres serviteur ──
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              children: [
                PuceFiltre(
                  libelle: 'Tous',
                  actif: _serviteur == 'all',
                  onTap: () => setState(() => _serviteur = 'all'),
                ),
                const SizedBox(width: 7),
                ...contenu.serviteurs.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: PuceFiltre(
                      libelle: s.nomCourt,
                      actif: _serviteur == s.code,
                      onTap: () => setState(() => _serviteur = s.code),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Liste ──
          Expanded(
            child: enseignements.isEmpty
                ? const EtatSectionVide(message: 'Aucun enseignement ne correspond.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                    itemCount: enseignements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _CarteEnseignement(
                      enseignement: enseignements[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              _LectureEnseignement(enseignement: enseignements[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE D'UN ENSEIGNEMENT
// ═══════════════════════════════════════════════════════════════════

class _CarteEnseignement extends StatelessWidget {
  final EnseignementModele enseignement;
  final VoidCallback onTap;

  const _CarteEnseignement({required this.enseignement, required this.onTap});

  static const _libellesNiveaux = {
    'decouverte': 'Découverte',
    'croissance': 'Croissance',
    'maturite': 'Maturité',
    'tous_niveaux': 'Tous niveaux',
  };

  @override
  Widget build(BuildContext context) {
    final niveau = _libellesNiveaux[enseignement.niveau] ?? enseignement.niveau;
    return CarteContenu(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.or.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  enseignement.theme,
                  style: const TextStyle(color: AppColors.orPastel, fontSize: 10.5),
                ),
              ),
              const Spacer(),
              Text(
                niveau,
                style: const TextStyle(color: AppColors.texteEteint, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            enseignement.titre,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          // ⭐ V2.3 — extrait SANS marqueurs markdown (plus d'astérisques)
          Text(
            nettoyerMarkdown(enseignement.extrait),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texteSecondaire,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 13, color: AppColors.or),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  enseignement.livre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 12),
                ),
              ),
              if (enseignement.tempsLecture.isNotEmpty)
                Text(
                  '· ${enseignement.tempsLecture}',
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 12),
                ),
              const SizedBox(width: 6),
              Text(
                enseignement.nomServiteur,
                style: const TextStyle(color: AppColors.orPastel, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FICHE DE LECTURE COMPLÈTE — structure professionnelle V2.3
//  (miroir de la carte article du site : badge, méta, citation
//   d'ouverture, corps markdown, référence biblique, signature)
// ═══════════════════════════════════════════════════════════════════

class _LectureEnseignement extends StatelessWidget {
  final EnseignementModele enseignement;

  const _LectureEnseignement({required this.enseignement});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: Text(
          enseignement.nomServiteur,
          style: const TextStyle(color: AppColors.texte, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 44),
        children: [
          // ── Badge thème · livre · niveau ──
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.or.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  enseignement.theme,
                  style: const TextStyle(color: AppColors.orPastel, fontSize: 12.5),
                ),
              ),
              if (enseignement.livre.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pourpre,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.pourpreClair),
                  ),
                  child: Text(
                    enseignement.livre,
                    style: const TextStyle(color: AppColors.texteSecondaire, fontSize: 12.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Titre ──
          Text(
            enseignement.titre,
            style: const TextStyle(
              color: AppColors.texte,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // ── Métadonnées ──
          Row(
            children: [
              Text(
                enseignement.nomServiteur,
                style: const TextStyle(color: AppColors.or, fontSize: 13),
              ),
              if (enseignement.tempsLecture.isNotEmpty)
                Text(
                  ' · ${enseignement.tempsLecture}',
                  style: const TextStyle(color: AppColors.texteEteint, fontSize: 12.5),
                ),
            ],
          ),

          // ── Filet doré de séparation ──
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            height: 1,
            color: AppColors.or.withValues(alpha: 0.3),
          ),

          // ── Citation d'ouverture (extrait — gras rendus) ──
          if (enseignement.extrait.isNotEmpty) ...[
            Text.rich(
              TextSpan(
                children: spansMarkdown(
                  enseignement.extrait,
                  style: const TextStyle(
                    color: AppColors.texteSecondaire,
                    fontSize: 14,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                  styleGras: const TextStyle(
                    color: AppColors.orPastel,
                    fontSize: 14,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ── Corps de l'article — rendu markdown professionnel ──
          TexteMarkdown(enseignement.contenu),

          // ── Référence biblique ──
          if (enseignement.livre.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.or.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.or.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 18, color: AppColors.or),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RÉFÉRENCE BIBLIQUE',
                          style: TextStyle(
                            color: AppColors.orFonce,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          enseignement.livre,
                          style: const TextStyle(
                            color: AppColors.texte,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Signature ──
          const SizedBox(height: 22),
          Row(
            children: [
              Container(width: 28, height: 1, color: AppColors.or),
              const SizedBox(width: 10),
              const Text(
                'Rédigé par la rédaction de Christ Libère',
                style: TextStyle(
                  color: AppColors.texteEteint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scaffold commun.
class _PageEnseignements extends StatelessWidget {
  final Widget enfant;

  const _PageEnseignements({required this.enfant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.nuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: const Text(
          'Enseignements',
          style: TextStyle(color: AppColors.texte, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: enfant,
    );
  }
}
