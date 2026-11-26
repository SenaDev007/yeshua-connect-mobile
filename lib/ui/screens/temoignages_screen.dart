/// ⭐ V2.0 — TÉMOIGNAGES (miroir des pages /temoignages + /vie-transformee).
/// ⭐ V2.3 — Articles professionnels : gras/italique rendus, titres
///          hiérarchisés, versets en blocs citation, listes dorées.
/// ⭐ V4.47 — SCISSION EN DEUX ESPACES DISTINCTS (retour pasteur) :
///    avant, l'écran ne montrait que les récits des serviteurs pendant
///    que l'accueil y renvoyait ses aperçus « Vies transformées » — les
///    deux mondes semblaient mélangés. Désormais DEUX onglets, comme sur
///    le site web (/temoignages vs /vie-transformee) :
///      ① « Témoignages » — récits des serviteurs (Afrika, Pasteur Kongo),
///         filtres par thème et par serviteur ;
///      ② « Vie transformée » — témoignages des CROYANTS publiés, avec
///         lecture complète ; c'est ICI (et seulement ici) que se trouve
///         le bouton « Partager votre témoignage ».
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
import 'partage_temoignage_screen.dart';

// ⭐ V4.47 — libellés des catégories « Vie transformée » (miroir web
// /vie-transformee — LABEL_CATEGORIE).
const Map<String, String> _libellesCategorie = {
  'vie_transformee': 'Vie transformée',
  'guerison': 'Guérison',
  'delivrance': 'Délivrance',
  'restauration': 'Foyer restauré',
  'providence': 'Providence',
  'appel': 'Appel & consécration',
  'action_graces': 'Action de grâces',
};

String _libelleCategorie(String code) =>
    _libellesCategorie[code] ?? (code.isEmpty ? 'Vie transformée' : code);

/// Formatte une date ISO en français (« 12 mai 2025 ») sans dépendance.
String _dateFr(String iso) {
  if (iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  const mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

class TemoignagesScreen extends ConsumerStatefulWidget {
  /// ⭐ V4.47 — ouvrir directement l'onglet « Vie transformée »
  /// (route ?onglet=vie — utilisé par l'accueil et le menu tiroir).
  final bool ongletVie;

  const TemoignagesScreen({super.key, this.ongletVie = false});

  @override
  ConsumerState<TemoignagesScreen> createState() => _TemoignagesScreenState();
}

class _TemoignagesScreenState extends ConsumerState<TemoignagesScreen> {
  // ⭐ V4.47 — onglet actif : false = Témoignages des serviteurs,
  // true = Vie transformée (témoignages des croyants).
  late bool _ongletVie = widget.ongletVie;

  String? _theme;
  String _serviteur = 'all';

  @override
  Widget build(BuildContext context) {
    final contenu = ref.watch(contenuProvider);

    if (contenu.jamaisSynchronise) {
      return const _PageTemoignages(
        ongletVie: false,
        enfant: EtatPremiereSync(),
      );
    }

    final themes = contenu.temoignages.expand((t) => t.themes).toSet().toList()
      ..sort();

    var temoignages = contenu.temoignages.where((t) {
      if (_serviteur != 'all' && t.serviteur != _serviteur) return false;
      if (_theme != null && !t.themes.contains(_theme)) return false;
      return true;
    }).toList();

    return _PageTemoignages(
      ongletVie: _ongletVie,
      enfant: Column(
        children: [
          HeroEnTete(hero: contenu.hero('temoignages'), hauteur: 150),

          // ── ⭐ V4.47 — Sélecteur des DEUX espaces (comme le web) ──
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.carte,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bordure),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _OngletEspace(
                    libelle: 'Témoignages',
                    sousTitre: 'Afrika & Pasteur Kongo',
                    icone: Icons.auto_awesome,
                    actif: !_ongletVie,
                    onTap: () => setState(() => _ongletVie = false),
                  ),
                ),
                Expanded(
                  child: _OngletEspace(
                    libelle: 'Vie transformée',
                    sousTitre: 'Témoignages des croyants',
                    icone: Icons.volunteer_activism,
                    actif: _ongletVie,
                    onTap: () => setState(() => _ongletVie = true),
                  ),
                ),
              ],
            ),
          ),

          // ── Contenu de l'onglet actif ──
          if (!_ongletVie) ...[
            // ── Filtres (serviteurs uniquement) ──
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: [
                  PuceFiltre(
                    libelle: 'Tous',
                    actif: _theme == null,
                    onTap: () => setState(() => _theme = null),
                  ),
                  const SizedBox(width: 7),
                  ...themes.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: PuceFiltre(
                        libelle: t,
                        actif: _theme == t,
                        onTap: () => setState(() => _theme = t),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                children: [
                  PuceFiltre(
                    libelle: 'Tous les serviteurs',
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
            // ── Liste des récits des serviteurs ──
            Expanded(
              child: temoignages.isEmpty
                  ? const EtatSectionVide(
                      message:
                          'Aucun témoignage ne correspond à ces filtres.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                      itemCount: temoignages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _CarteTemoignage(
                        temoignage: temoignages[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _LectureTemoignage(
                              temoignage: temoignages[i],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ] else
            // ── ⭐ V4.47 — Liste des témoignages des CROYANTS ──
            Expanded(
              child: contenu.viesTransformees.isEmpty
                  ? const EtatSectionVide(
                      message:
                          'Aucun témoignage de croyant publié pour le moment.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: contenu.viesTransformees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _CarteVieTransformee(
                        vie: contenu.viesTransformees[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _LectureVieTransformee(
                              vie: contenu.viesTransformees[i],
                            ),
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
//  ⭐ V4.47 — ONGLET D'ESPACE (sélecteur haut de page)
// ═══════════════════════════════════════════════════════════════════

class _OngletEspace extends StatelessWidget {
  final String libelle;
  final String sousTitre;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  const _OngletEspace({
    required this.libelle,
    required this.sousTitre,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Onglet actif = touch de VIOLET impérial (identité web), texte crème.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: actif ? AppColors.pourpre : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icone,
              size: 15,
              color: actif ? AppColors.or : AppColors.encreSecondaire,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: actif ? AppColors.carte : AppColors.encre,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    sousTitre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: actif
                          ? AppColors.orPastel
                          : AppColors.encreSecondaire,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CARTE D'UN TÉMOIGNAGE DE SERVITEUR
// ═══════════════════════════════════════════════════════════════════

class _CarteTemoignage extends StatelessWidget {
  final TemoignageModele temoignage;
  final VoidCallback onTap;

  const _CarteTemoignage({required this.temoignage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: AppColors.or),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  temoignage.titre,
                  style: const TextStyle(
                    color: AppColors.encre,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // ⭐ V2.3 — résumé SANS marqueurs markdown (plus d'astérisques)
          Text(
            nettoyerMarkdown(temoignage.resume),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.encreSecondaire,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...temoignage.themes.take(3).map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.pourpre.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                              color: AppColors.orFonce, fontSize: 10.5),
                        ),
                      ),
                    ),
                  ),
              const Spacer(),
              if (temoignage.tempsLecture.isNotEmpty)
                Text(
                  temoignage.tempsLecture,
                  style: const TextStyle(
                      color: AppColors.encreEteinte, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ⭐ V4.47 — CARTE D'UN TÉMOIGNAGE DE CROYANT (« Vie transformée »)
// ═══════════════════════════════════════════════════════════════════

class _CarteVieTransformee extends StatelessWidget {
  final VieTransformeeModele vie;
  final VoidCallback onTap;

  const _CarteVieTransformee({required this.vie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CarteContenu(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism,
                  size: 15, color: AppColors.or),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vie.titre,
                  style: const TextStyle(
                    color: AppColors.encre,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (vie.contenu.isNotEmpty)
            Text(
              nettoyerMarkdown(vie.contenu),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.encreSecondaire,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.or.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _libelleCategorie(vie.categorie),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.orFonce, fontSize: 10.5),
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  [
                    if (vie.nom.isNotEmpty) vie.nom,
                    if (vie.ville.isNotEmpty) vie.ville,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.encreEteinte, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FICHE DE LECTURE COMPLÈTE (SERVITEUR) — structure pro V2.3
// ═══════════════════════════════════════════════════════════════════

class _LectureTemoignage extends StatelessWidget {
  final TemoignageModele temoignage;

  const _LectureTemoignage({required this.temoignage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: Text(
          temoignage.nomServiteur,
          style: const TextStyle(color: AppColors.encre, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 44),
        children: [
          // ── Badges thèmes ──
          if (temoignage.themes.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in temoignage.themes.take(4))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pourpre.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                          color: AppColors.orFonce, fontSize: 12.5),
                    ),
                  ),
              ],
            ),

          // ── Titre ──
          const SizedBox(height: 12),
          Text(
            temoignage.titre,
            style: const TextStyle(
              color: AppColors.encre,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // ── Métadonnées ──
          Row(
            children: [
              if (temoignage.referenceLivre.isNotEmpty) ...[
                const Icon(Icons.menu_book_outlined,
                    size: 13, color: AppColors.or),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    temoignage.referenceLivre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.orFonce, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (temoignage.tempsLecture.isNotEmpty)
                Text(
                  '· ${temoignage.tempsLecture}',
                  style: const TextStyle(
                      color: AppColors.encreEteinte, fontSize: 12.5),
                ),
            ],
          ),

          // ── Filet doré de séparation ──
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            height: 1,
            color: AppColors.or.withValues(alpha: 0.3),
          ),

          // ── Citation d'ouverture (résumé — gras rendus) ──
          if (temoignage.resume.isNotEmpty) ...[
            Text.rich(
              TextSpan(
                children: spansMarkdown(
                  temoignage.resume,
                  style: const TextStyle(
                    color: AppColors.encreSecondaire,
                    fontSize: 14,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                  styleGras: const TextStyle(
                    color: AppColors.encre,
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

          // ── Corps du témoignage — rendu markdown professionnel ──
          TexteMarkdown(temoignage.contenu),

          // ── Référence biblique ──
          if (temoignage.referenceLivre.isNotEmpty) ...[
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
                  const Icon(Icons.menu_book_outlined,
                      size: 18, color: AppColors.or),
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
                          temoignage.referenceLivre,
                          style: const TextStyle(
                            color: AppColors.encre,
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
              const Expanded(
                child: Text(
                  'Récit rapporté par la rédaction de Christ Libère',
                  style: TextStyle(
                    color: AppColors.encreEteinte,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ⭐ V4.47 — FICHE DE LECTURE D'UN TÉMOIGNAGE DE CROYANT
//  (miroir de la carte article web /vie-transformee : catégorie, auteur
//   anonymisé — nom, pays, ville — corps markdown, date de publication)
// ═══════════════════════════════════════════════════════════════════

class _LectureVieTransformee extends StatelessWidget {
  final VieTransformeeModele vie;

  const _LectureVieTransformee({required this.vie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: Text(
          _libelleCategorie(vie.categorie),
          style: const TextStyle(color: AppColors.encre, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 44),
        children: [
          // ── Bandeau catégorie (touch violet) ──
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.pourpre,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _libelleCategorie(vie.categorie),
                  style: const TextStyle(
                      color: AppColors.orPastel, fontSize: 12.5),
                ),
              ),
            ],
          ),

          // ── Titre ──
          const SizedBox(height: 12),
          Text(
            vie.titre,
            style: const TextStyle(
              color: AppColors.encre,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // ── Auteur (anonymisé : nom + ville/pays, comme le web) ──
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: AppColors.or),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  [
                    if (vie.nom.isNotEmpty) vie.nom,
                    [
                      if (vie.ville.isNotEmpty) vie.ville,
                      if (vie.pays.isNotEmpty) vie.pays,
                    ].join(', '),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.encreSecondaire, fontSize: 12.5),
                ),
              ),
              if (vie.publieLe.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  '· ${_dateFr(vie.publieLe)}',
                  style: const TextStyle(
                      color: AppColors.encreEteinte, fontSize: 12.5),
                ),
              ],
            ],
          ),

          // ── Filet doré de séparation ──
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            height: 1,
            color: AppColors.or.withValues(alpha: 0.3),
          ),

          // ── Corps du témoignage — rendu markdown professionnel ──
          TexteMarkdown(vie.contenu),

          // ── Encart pastoral ──
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pourpre.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.pourpre.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 18, color: AppColors.or),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TÉMOIGNAGE VALIDÉ',
                        style: TextStyle(
                          color: AppColors.orFonce,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Chaque récit est relu puis validé par l\'équipe '
                        'pastorale avant publication. Les coordonnées '
                        'complètes de l\'auteur ne sont pas publiées.',
                        style: TextStyle(
                          color: AppColors.encreSecondaire,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Signature ──
          const SizedBox(height: 22),
          Row(
            children: [
              Container(width: 28, height: 1, color: AppColors.or),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Vie transformée — Mouvement Christ Libère',
                  style: TextStyle(
                    color: AppColors.encreEteinte,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scaffold commun — ⭐ V4.47 : le FAB « Partager votre témoignage » ne
/// vit PLUS que dans l'onglet « Vie transformée » (retour pasteur).
class _PageTemoignages extends StatelessWidget {
  final Widget enfant;
  final bool ongletVie;

  const _PageTemoignages({required this.enfant, required this.ongletVie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.or),
        title: Text(
          ongletVie ? 'Vie transformée' : 'Témoignages',
          style: const TextStyle(
              color: AppColors.encre,
              fontSize: 17,
              fontWeight: FontWeight.w800),
        ),
      ),
      // ⭐ V2.17/V4.47 — Parité web : le croyant SOUMET son témoignage
      // (2 étapes → relecture pastorale → publication dans « Vie
      // transformée »). Bouton présent UNIQUEMENT dans cet onglet.
      floatingActionButton: ongletVie
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PartageTemoignageScreen(),
                ),
              ),
              backgroundColor: AppColors.pourpre,
              foregroundColor: AppColors.orPastel,
              elevation: 3,
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Partager votre témoignage',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            )
          : null,
      body: enfant,
    );
  }
}
