/// Écran Bibliothèque — une vraie bibliothèque, avec rayons par serviteur.
///
/// ⭐ V4.38 — Bibliothèque documentaire mobile.
/// Grille de couvertures avec filtres par catégorie, recherche,
/// et lecteur PDF intégré (webview).
///
/// ⭐ V4.42 — Scission stricte en espaces : filtrage par servantCode côté
/// serveur, accents de couleur par espace.
///
/// ⭐ V4.44 — VRAIE bibliothèque (retours pasteur, aligné sur le web) :
///   ① à l'ouverture, TOUTE la bibliothèque est affichée avec ses TOTAUX
///      (ouvrages, catégories, téléchargements) ;
///   ② toucher « Pasteur Kongo » ou « Afrika » ouvre SON espace : la grille
///      ne montre que ses ouvrages et les compteurs se mettent à jour ;
///   ③ re-toucher la puce active, ou la croix de la bannière, ramène à
///      toute la bibliothèque ;
///   ④ les puces et la bannière affichent les VRAIES photos de profil des
///      serviteurs lues depuis le contenu synchronisé de l'app (même source
///      que la page serviteur — module serviteur du back-office), plus
///      jamais d'initiales pour Kongo/Afrika ;
///   ⑤ plaques redessinées : médaillon photo à double anneau, rôle en
///      capitales espacées, bandeau de statistiques — fini le fond « dans
///      l'espace » qui se voyait.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/bibliotheque_repository.dart';
import '../../state/contenu_controller.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/contenu_widgets.dart';

// ─── ⭐ V4.42/V4.44 — Espaces de la bibliothèque ───────────────────────

/// Un livre appartient à UN seul espace (son servantCode côté API) :
/// kongo → espace du pasteur Kongo, afrika → espace d'Afrika Pamela DALI,
/// collectif → livres sans serviteur rattaché. « tous » est l'état PAR
/// DÉFAUT : toute la bibliothèque, tous les ouvrages confondus.
enum EspaceBibliotheque { tous, kongo, afrika, collectif }

extension EspaceBibliothequeX on EspaceBibliotheque {
  /// Code servant attendu par l'API (?servantCode=) — vide pour « tous »
  /// (bibliothèque entière) et « Collectif » (filtré côté app).
  String get codeServant =>
      this == EspaceBibliotheque.kongo
          ? 'kongo'
          : this == EspaceBibliotheque.afrika
              ? 'afrika'
              : '';

  String get nomComplet => switch (this) {
        EspaceBibliotheque.tous => 'Toute la bibliothèque',
        EspaceBibliotheque.kongo => 'Pasteur Kongo',
        EspaceBibliotheque.afrika => 'Afrika Pamela DALI',
        EspaceBibliotheque.collectif => 'Collectif',
      };

  String get sousTitre => switch (this) {
        EspaceBibliotheque.tous => 'Tous les ouvrages du ministère',
        EspaceBibliotheque.kongo => 'Époux, ministre pastoral',
        EspaceBibliotheque.afrika => 'Servante de l\'Éternel',
        EspaceBibliotheque.collectif => 'Ouvrages du ministère',
      };

  String get initiales => switch (this) {
        EspaceBibliotheque.tous => 'MC',
        EspaceBibliotheque.kongo => 'PK',
        EspaceBibliotheque.afrika => 'AP',
        EspaceBibliotheque.collectif => 'MC',
      };

  /// Accent de couleur propre à l'espace (or pour Kongo, violet pour Afrika).
  Color get accent => switch (this) {
        EspaceBibliotheque.tous => const Color(0xFFDDBE55),
        EspaceBibliotheque.kongo => AppColors.or,
        EspaceBibliotheque.afrika => const Color(0xFFB87AEB),
        EspaceBibliotheque.collectif => const Color(0xFF8FA3C8),
      };

  /// Variante éclaircie pour les textes posés sur fond sombre.
  Color get accentClair => Color.lerp(accent, Colors.white, 0.35)!;
}

/// Convertit le paramètre de route ?espace=… en espace (null → « tous »).
EspaceBibliotheque? espaceDepuisTexte(String? texte) {
  switch ((texte ?? '').toLowerCase()) {
    case 'kongo':
      return EspaceBibliotheque.kongo;
    case 'afrika':
      return EspaceBibliotheque.afrika;
    case 'collectif':
      return EspaceBibliotheque.collectif;
    default:
      return EspaceBibliotheque.tous;
  }
}

// ─── ⭐ V4.44 — Provider : ouvrages BRUTS de l'espace (sans filtres) ────
//
// Le provider renvoie TOUS les livres de l'espace (filtrage serveur par
// servantCode) : la grille applique ensuite recherche/catégorie LOCALEMENT
// et les compteurs (ouvrages, catégories, téléchargements) portent sur
// l'espace entier — comme sur le web.

final bibliothequeProvider =
    FutureProvider.family<List<BookModel>, EspaceBibliotheque>((ref, espace) async {
  final repo = BibliothequeRepository();

  // kongo/afrika → filtrage SERVEUR ; tous/collectif → bibliothèque entière.
  final books =
      (espace == EspaceBibliotheque.kongo || espace == EspaceBibliotheque.afrika)
          ? await repo.tous(servantCode: espace.codeServant)
          : await repo.tous();

  // « Collectif » = livres sans serviteur rattaché.
  if (espace == EspaceBibliotheque.collectif) {
    return books.where((b) => (b.servantCode ?? '').isEmpty).toList();
  }
  return books;
});

// ─── Couleurs par catégorie (dégradés pour les couvertures sans image) ──

const _categoryGradients = <String, List<Color>>{
  'Enseignements': [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
  'Prière & Intercession': [Color(0xFFD97706), Color(0xFF9A3412)],
  'Révélations': [Color(0xFF7C3AED), Color(0xFF5B21B6)],
  'Délivrance': [Color(0xFFDC2626), Color(0xFF991B1B)],
  'Vie Chrétienne': [Color(0xFF16A34A), Color(0xFF065F46)],
  'Prophéties': [Color(0xFF0891B2), Color(0xFF1E40AF)],
  'Jeunesse': [Color(0xFFDB2777), Color(0xFF831843)],
  'Santé & Guérison': [Color(0xFF059669), Color(0xFF064E3B)],
  'Famille & Couple': [Color(0xFFF59E0B), Color(0xFFB45309)],
  'Finances Royaume': [Color(0xFF84CC16), Color(0xFF365314)],
  'Adoration & Louanges': [Color(0xFFA855F7), Color(0xFF6B21A8)],
  'Autres': [Color(0xFF6B7280), Color(0xFF374151)],
};

List<Color> _gradientFor(String category) =>
    _categoryGradients[category] ?? _categoryGradients['Autres']!;

// ─── Écran principal ──────────────────────────────────────────────────

class BibliothequeScreen extends ConsumerStatefulWidget {
  /// Espace affiché à l'ouverture (paramètre de route ?espace=…).
  final EspaceBibliotheque? espaceInitiale;

  const BibliothequeScreen({super.key, this.espaceInitiale});

  @override
  ConsumerState<BibliothequeScreen> createState() => _BibliothequeScreenState();
}

class _BibliothequeScreenState extends ConsumerState<BibliothequeScreen> {
  // ⭐ V4.44 — PAR DÉFAUT : toute la bibliothèque (tous les ouvrages).
  EspaceBibliotheque _espace = EspaceBibliotheque.tous;
  String? _categorieSelectionnee;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _espace = widget.espaceInitiale ?? EspaceBibliotheque.tous;
  }

  /// Photo de profil EFFECTIVE du serviteur (contenu synchronisé de l'app :
  /// photo du module serviteur du back-office, comme la page serviteur).
  String? _photoServiteur(String code) {
    for (final s in ref.read(contenuProvider).serviteurs) {
      if (s.code == code) {
        final url = resoudreUrl(s.photoEffective);
        return url.isEmpty ? null : url;
      }
    }
    return null;
  }

  String? _photoEspace(EspaceBibliotheque espace) {
    switch (espace) {
      case EspaceBibliotheque.kongo:
        return _photoServiteur('kongo');
      case EspaceBibliotheque.afrika:
        return _photoServiteur('afrika');
      default:
        return null; // « tous » et « collectif » : médaillon emblème/initiales
    }
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bibliothequeProvider(_espace));
    final livresEspace = booksAsync.value ?? const <BookModel>[];

    // Grille : recherche + catégorie appliqués localement sur l'espace.
    final livresAffiches = livresEspace.where((b) {
      if (_categorieSelectionnee != null &&
          b.category != _categorieSelectionnee) {
        return false;
      }
      if (_recherche.isNotEmpty) {
        final q = _recherche.toLowerCase();
        return b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.description.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // ⭐ V4.44 — compteurs de l'espace ENTIER (pas des seuls résultats
    // filtrés) : ouvrages, catégories, téléchargements cumulés.
    final nbOuvrages = livresEspace.length;
    final nbCategories = livresEspace.map((b) => b.category).toSet().length;
    final nbTelechargements =
        livresEspace.fold<int>(0, (total, b) => total + b.downloadCount);

    // Catégories disponibles dans l'espace (pour les pastilles de filtre).
    if (booksAsync.value != null) _updateCategories(livresEspace);

    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.pourpre,
        title: const Text('Bibliothèque', style: TextStyle(color: AppColors.encre)),
        iconTheme: const IconThemeData(color: AppColors.or),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // ── ⭐ V4.44 Puces d'espace avec PHOTOS réelles (scrollables) ──
          // Re-toucherc la puce active ramène à « toute la bibliothèque ».
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final espace in EspaceBibliotheque.values) ...[
                  _PuceEspace(
                    espace: espace,
                    actif: _espace == espace,
                    photoUrl: _photoEspace(espace),
                    onTap: () => _choisirEspace(espace),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── ⭐ V4.44 Plaque de l'espace actif (photo + rôle + stats) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _PlaqueEspace(
                key: ValueKey(_espace),
                espace: _espace,
                photoUrl: _photoEspace(_espace),
                nbOuvrages: booksAsync.value == null ? null : nbOuvrages,
                nbCategories: booksAsync.value == null ? null : nbCategories,
                nbTelechargements:
                    booksAsync.value == null ? null : nbTelechargements,
                onRetourTout: _espace == EspaceBibliotheque.tous
                    ? null
                    : () => _choisirEspace(EspaceBibliotheque.tous),
              ),
            ),
          ),
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v),
              style: const TextStyle(color: AppColors.encre),
              decoration: InputDecoration(
                hintText: 'Rechercher un livre...',
                hintStyle: const TextStyle(color: AppColors.encreEteinte),
                prefixIcon: Icon(Icons.search, color: _espace.accent),
                filled: true,
                fillColor: AppColors.carte,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Filtres catégories (scroll horizontal) — teintés à l'accent de l'espace
          if (_categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final selected = _categorieSelectionnee == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _categorieSelectionnee = selected ? null : cat;
                        });
                      },
                      selectedColor: _espace.accent,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.nuit : AppColors.encreSecondaire,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: AppColors.pourpre,
                      side: BorderSide(
                        color: selected ? _espace.accent : AppColors.pourpreClair,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // Grille de livres (rejouée à chaque changement d'espace)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey(_espace),
                child: booksAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.or),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.library_books, size: 48, color: AppColors.or),
                          const SizedBox(height: 16),
                          const Text(
                            'Impossible de charger la bibliothèque.\nVérifiez votre connexion.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.encreSecondaire),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => ref.invalidate(bibliothequeProvider(_espace)),
                            child: const Text('Réessayer', style: TextStyle(color: AppColors.or)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (_) {
                    if (livresAffiches.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book, size: 48, color: AppColors.encreEteinte),
                              const SizedBox(height: 16),
                              Text(
                                _recherche.isNotEmpty || _categorieSelectionnee != null
                                    ? 'Aucun livre ne correspond à votre recherche.'
                                    : _espace == EspaceBibliotheque.tous
                                        ? 'Aucun livre publié dans la bibliothèque\npour l\'instant.'
                                        : 'Aucun livre dans l\'espace\n« ${_espace.nomComplet} » pour l\'instant.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.encreSecondaire),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: livresAffiches.length,
                      itemBuilder: (ctx, i) => _CarteLivre(
                        book: livresAffiches[i],
                        onTap: () => _ouvrirLivre(livresAffiches[i]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⭐ V4.44 — choisir un espace ; re-choisir l'espace ACTIF ramène à
  /// « toute la bibliothèque » (même logique que le web : clic dans le vide
  /// / re-clic de la carte).
  void _choisirEspace(EspaceBibliotheque espace) {
    setState(() {
      _espace = espace == _espace
          ? EspaceBibliotheque.tous
          : espace;
      // Les catégories d'un espace n'ont pas de sens dans l'autre
      _categorieSelectionnee = null;
    });
  }

  // Catégories dynamiques (remplies après le premier chargement)
  final List<String> _categories = [];

  void _updateCategories(List<BookModel> books) {
    final cats = books.map((b) => b.category).toSet().toList()..sort();
    if (_categories.length != cats.length || !_listEquals(_categories, cats)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _categories
          ..clear()
          ..addAll(cats));
      });
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _ouvrirLivre(BookModel book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LecteurLivreScreen(book: book),
      ),
    );
  }
}

// ─── ⭐ V4.44 — Puce d'espace : médaillon PHOTO + nom ───────────────────
//
// Kongo/Afrika : vraie photo de profil (contenu synchronisé) ; « tous » :
// emblème bibliothèque ; « collectif » : initiales. Au repos : bordure
// discrète sur fond transparent (plus de fond qui « se voit ») ; à l'état
// actif : accent plein + halo.

class _PuceEspace extends StatelessWidget {
  final EspaceBibliotheque espace;
  final bool actif;
  final String? photoUrl;
  final VoidCallback onTap;

  const _PuceEspace({
    required this.espace,
    required this.actif,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = espace.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        decoration: BoxDecoration(
          color: actif ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: actif ? accent.withValues(alpha: 0.8) : AppColors.pourpreClair,
            width: actif ? 1.4 : 1,
          ),
          boxShadow: actif
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Médaillon : photo réelle, emblème « tous », initiales « collectif »
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: actif
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.85),
                          accent.withValues(alpha: 0.25),
                        ],
                      )
                    : null,
                border: Border.all(
                  color: actif ? accent : AppColors.pourpreClair,
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl != null
                  ? ImageUniverselle(
                      url: photoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : _MedaillonDefaut(espace: espace),
            ),
            const SizedBox(width: 7),
            Text(
              espace.nomComplet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: actif ? espace.accentClair : AppColors.encreSecondaire,
                fontSize: 12.5,
                fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu par défaut du médaillon quand il n'y a pas de photo.
class _MedaillonDefaut extends StatelessWidget {
  final EspaceBibliotheque espace;

  const _MedaillonDefaut({required this.espace});

  @override
  Widget build(BuildContext context) {
    final accent = espace.accent;
    return Container(
      color: accent.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: espace == EspaceBibliotheque.tous
          ? Icon(Icons.local_library_outlined,
              color: accent, size: 16)
          : Text(
              espace.initiales,
              style: TextStyle(
                color: espace.accentClair,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
    );
  }
}

// ─── ⭐ V4.44 — Plaque d'identité de l'espace (photo + rôle + stats) ────

class _PlaqueEspace extends StatelessWidget {
  final EspaceBibliotheque espace;
  final String? photoUrl;
  final int? nbOuvrages;
  final int? nbCategories;
  final int? nbTelechargements;
  final VoidCallback? onRetourTout;

  const _PlaqueEspace({
    super.key,
    required this.espace,
    required this.photoUrl,
    required this.nbOuvrages,
    required this.nbCategories,
    required this.nbTelechargements,
    required this.onRetourTout,
  });

  @override
  Widget build(BuildContext context) {
    final accent = espace.accent;
    final enChargement = nbOuvrages == null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            AppColors.pourpre,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Médaillon à DOUBLE anneau : photo réelle (ou emblème/initiales)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.9),
                      accent.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.nuit,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl != null
                      ? ImageUniverselle(
                          url: photoUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : _MedaillonDefaut(espace: espace),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      espace.nomComplet,
                      style: TextStyle(
                        color: espace.accentClair,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      espace.sousTitre.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.encreSecondaire.withValues(alpha: 0.85),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Croix « retour à toute la bibliothèque »
              if (onRetourTout != null)
                IconButton(
                  onPressed: onRetourTout,
                  tooltip: 'Toute la bibliothèque',
                  icon: Icon(Icons.close,
                      size: 18, color: AppColors.encreSecondaire),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Bandeau de statistiques (ouvrages · catégories · téléchargements)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.nuit.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                _StatMini(
                  icone: Icons.auto_stories_outlined,
                  valeur: nbOuvrages,
                  label: 'ouvrages',
                  accent: accent,
                ),
                _SeparateurStat(accent: accent),
                _StatMini(
                  icone: Icons.category_outlined,
                  valeur: nbCategories,
                  label: 'catégories',
                  accent: accent,
                ),
                _SeparateurStat(accent: accent),
                _StatMini(
                  icone: Icons.download_outlined,
                  valeur: nbTelechargements,
                  label: 'téléchargements',
                  accent: accent,
                ),
              ],
            ),
          ),
          if (enChargement) ...[
            const SizedBox(height: 6),
            Text(
              'Chargement des compteurs…',
              style: TextStyle(
                color: accent.withValues(alpha: 0.8),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Statistique compacte de la plaque (valeur + libellé).
class _StatMini extends StatelessWidget {
  final IconData icone;
  final int? valeur;
  final String label;
  final Color accent;

  const _StatMini({
    required this.icone,
    required this.valeur,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: accent.withValues(alpha: 0.85), size: 15),
          const SizedBox(width: 5),
          Text(
            valeur == null ? '—' : '$valeur',
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.encreEteinte,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fine séparation verticale entre deux statistiques.
class _SeparateurStat extends StatelessWidget {
  final Color accent;

  const _SeparateurStat({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: accent.withValues(alpha: 0.25),
    );
  }
}

// ─── Carte livre (couverture + titre + auteur) ────────────────────────

class _CarteLivre extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const _CarteLivre({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientFor(book.category);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Couverture
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                        ? Image.network(
                            book.coverUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => _couvertureDefaut(gradient),
                          )
                        : _couvertureDefaut(gradient),
                  ),
                ),
                // Badge catégorie
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Titre
          Text(
            book.title,
            style: const TextStyle(
              color: AppColors.encre,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Auteur
          Text(
            book.author,
            style: const TextStyle(
              color: AppColors.encreEteinte,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _couvertureDefaut(List<Color> gradient) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, color: Colors.white70, size: 24),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              book.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lecteur de livre (modal avec PDF + téléchargement) ───────────────

class _LecteurLivreScreen extends StatelessWidget {
  final BookModel book;

  const _LecteurLivreScreen({required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.pourpre,
        title: Text(
          book.title,
          style: const TextStyle(color: AppColors.carte, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: AppColors.or),
        actions: [
          if (book.fileUrl != null)
            IconButton(
              icon: const Icon(Icons.download, color: AppColors.or),
              onPressed: () => _telecharger(context),
              tooltip: 'Télécharger',
            ),
        ],
      ),
      body: book.fileUrl != null
          ? _PdfViewer(url: book.fileUrl!, title: book.title)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 48, color: AppColors.encreEteinte),
                    const SizedBox(height: 16),
                    Text(
                      book.description.isEmpty
                          ? 'Aucun fichier PDF disponible pour ce livre.'
                          : book.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.encreSecondaire),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ⭐ V4.47 — VRAI téléchargement (avant : une simple SnackBar, le
  // fichier n'était JAMAIS récupéré — retour utilisateur). Le PDF est
  // téléchargé via Dio dans le stockage de l'app, puis le panneau de
  // partage système s'ouvre : l'utilisateur peut l'enregistrer où il
  // veut (Fichiers, Drive, WhatsApp…). Barre de progression pendant le
  // transfert.
  Future<void> _telecharger(BuildContext context) async {
    final url = book.fileUrl;
    if (url == null || url.isEmpty) return;

    // Repertoire local (documents de l'app — persistant, sans permission).
    final Directory dir = await getApplicationDocumentsDirectory();
    final nomPropre = book.title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final chemin = '${dir.path}/${nomPropre.isEmpty ? 'livre' : nomPropre}.pdf';

    // Bandeau de progression.
    final controleur = ScaffoldMessenger.of(context);
    OverlayEntry? progression;
    double avancement = 0;

    void rafraichir() {
      progression?.markNeedsBuild();
    }

    progression = OverlayEntry(
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.nuit.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.or.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf,
                  color: AppColors.or, size: 34),
              const SizedBox(height: 12),
              SizedBox(
                width: 190,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: avancement <= 0 ? null : avancement,
                    backgroundColor: AppColors.pourpreClair,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.or),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                avancement <= 0
                    ? 'Téléchargement de « ${book.title} »…'
                    : 'Téléchargement… ${(avancement * 100).toStringAsFixed(0)} %',
                style: const TextStyle(
                    color: AppColors.carte, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context).insert(progression);

    try {
      await Dio().download(
        url,
        chemin,
        onReceiveProgress: (recus, total) {
          if (total > 0) {
            avancement = recus / total;
            rafraichir();
          }
        },
      );

      progression.remove();
      progression = null;

      // ⭐ Ouverture du panneau de partage : « Enregistrer sur
      // l'appareil », Drive, WhatsApp… — le fichier EST téléchargé et
      // remis à l'utilisateur (au lieu d'un faux message).
      // API share_plus 10.x : Share.shareXFiles. L'API SharePlus.instance.share
      // n'existe qu'à partir de share_plus 11.0.0.
      final rendu = await Share.shareXFiles(
        [XFile(chemin, mimeType: 'application/pdf')],
        text: book.title,
      );
      if (!context.mounted) return;
      controleur.showSnackBar(
        SnackBar(
          content: Text(rendu.status == ShareResultStatus.success
              ? 'PDF téléchargé — « ${book.title} ».'
              : 'PDF téléchargé dans l\'application.'),
          backgroundColor: AppColors.pourpreClair,
        ),
      );
    } catch (_) {
      progression?.remove();
      progression = null;
      if (!context.mounted) return;
      controleur.showSnackBar(
        const SnackBar(
          content: Text(
              'Échec du téléchargement — vérifiez votre connexion puis réessayez.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// ─── Visionneuse PDF ──────────────────────────────────────────────────
// Pour l'instant, on ouvre le PDF dans le navigateur système (url_launcher).
// TODO: intégrer syncfusion_flutter_pdfviewer ou flutter_pdfview pour un
// lecteur natif avec effet de feuilletage.

class _PdfViewer extends StatelessWidget {
  final String url;
  final String title;

  const _PdfViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: AppColors.or),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.encre,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Touchez le bouton ci-dessous pour ouvrir le PDF\ndans votre navigateur.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.encreSecondaire, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _ouvrirDansNavigateur(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ouvrir le PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ V4.47 — CORRECTION « le PDF ne s'ouvre pas » : l'ancien code
  // interrogeait canLaunchUrl AVANT de lancer. Sur Android 11+, interroger
  // un navigateur exige une déclaration <queries> dans le manifeste — sans
  // elle, canLaunchUrl renvoie FALSE et l'ouverture échouait en silence.
  // Désormais : on lance DIRECTEMENT en application externe, avec repli
  // sur le navigateur intégré (Custom Tabs) puis message d'erreur explicite.
  Future<void> _ouvrirDansNavigateur(BuildContext context) async {
    final uri = Uri.parse(url);
    var ouvert = false;
    try {
      ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ouvert) {
        // Repli : navigateur intégré (Custom Tabs / vue in-app).
        ouvert = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {
      ouvert = false;
    }
    if (!ouvert && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Impossible d\'ouvrir le PDF — aucun navigateur disponible sur cet appareil.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
