/// Écran Bibliothèque — espaces distincts par serviteur.
///
/// ⭐ V4.38 — Bibliothèque documentaire mobile.
/// Grille de couvertures avec filtres par catégorie, recherche,
/// et lecteur PDF intégré (webview).
///
/// ⭐ V4.42 — SCISSON STRICTE EN ESPACES : le sélecteur en tête d'écran
/// affiche UN espace à la fois — Pasteur Kongo / Afrika Pamela DALI, plus
/// « Collectif » pour les livres sans serviteur. Chaque espace a son accent
/// de couleur, sa bannière animée et ses compteurs. Le filtrage par espace
/// est fait côté serveur (?servantCode=) : rien n'est jamais mélangé.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/bibliotheque_repository.dart';

// ─── ⭐ V4.42 — Espaces de la bibliothèque ─────────────────────────────

/// Un livre appartient à UN seul espace (son servantCode côté API) :
/// kongo → espace du pasteur Kongo, afrika → espace d'Afrika Pamela DALI,
/// collectif → livres sans serviteur rattaché.
enum EspaceBibliotheque { kongo, afrika, collectif }

extension EspaceBibliothequeX on EspaceBibliotheque {
  /// Code servant attendu par l'API (?servantCode=) — vide pour « Collectif ».
  String get codeServant =>
      this == EspaceBibliotheque.kongo
          ? 'kongo'
          : this == EspaceBibliotheque.afrika
              ? 'afrika'
              : '';

  String get nomComplet => switch (this) {
        EspaceBibliotheque.kongo => 'Pasteur Kongo',
        EspaceBibliotheque.afrika => 'Afrika Pamela DALI',
        EspaceBibliotheque.collectif => 'Collectif',
      };

  String get sousTitre => switch (this) {
        EspaceBibliotheque.kongo => 'Époux, ministre pastoral',
        EspaceBibliotheque.afrika => 'Servante de l\'Éternel',
        EspaceBibliotheque.collectif => 'Ouvrages du ministère',
      };

  String get initiales => switch (this) {
        EspaceBibliotheque.kongo => 'PK',
        EspaceBibliotheque.afrika => 'AP',
        EspaceBibliotheque.collectif => 'MC',
      };

  /// Accent de couleur propre à l'espace (or pour Kongo, violet pour Afrika).
  Color get accent => switch (this) {
        EspaceBibliotheque.kongo => AppColors.or,
        EspaceBibliotheque.afrika => const Color(0xFFB87AEB),
        EspaceBibliotheque.collectif => const Color(0xFF8FA3C8),
      };

  /// Variante éclaircie pour les textes posés sur fond sombre.
  Color get accentClair => Color.lerp(accent, Colors.white, 0.35)!;
}

/// Convertit le paramètre de route ?espace=… en espace (null si inconnu).
EspaceBibliotheque? espaceDepuisTexte(String? texte) {
  switch ((texte ?? '').toLowerCase()) {
    case 'kongo':
      return EspaceBibliotheque.kongo;
    case 'afrika':
      return EspaceBibliotheque.afrika;
    case 'collectif':
      return EspaceBibliotheque.collectif;
    default:
      return null;
  }
}

// ─── Provider Riverpod pour la bibliothèque ───────────────────────────

final bibliothequeProvider = FutureProvider.family<List<BookModel>,
    ({EspaceBibliotheque espace, String? category, String? search})>(
  (ref, params) async {
    final repo = BibliothequeRepository();

    // ⭐ V4.42 — filtrage SERVEUR par espace : pour kongo/afrika l'API ne
    // renvoie que les livres de ce serviteur. « Collectif » = livres sans
    // serviteur : on récupère tout puis on garde ceux sans servantCode.
    var books = params.espace == EspaceBibliotheque.collectif
        ? await repo.tous()
        : await repo.tous(servantCode: params.espace.codeServant);
    if (params.espace == EspaceBibliotheque.collectif) {
      books = books.where((b) => (b.servantCode ?? '').isEmpty).toList();
    }

    // Filtre catégorie
    if (params.category != null) {
      books = books.where((b) => b.category == params.category).toList();
    }

    // Filtre recherche
    if (params.search != null && params.search!.isNotEmpty) {
      final q = params.search!.toLowerCase();
      books = books.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.description.toLowerCase().contains(q);
      }).toList();
    }

    return books;
  },
);

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
  /// ⭐ V4.42 — espace affiché à l'ouverture (paramètre de route ?espace=…).
  final EspaceBibliotheque? espaceInitiale;

  const BibliothequeScreen({super.key, this.espaceInitiale});

  @override
  ConsumerState<BibliothequeScreen> createState() => _BibliothequeScreenState();
}

class _BibliothequeScreenState extends ConsumerState<BibliothequeScreen> {
  EspaceBibliotheque _espace = EspaceBibliotheque.kongo;
  String? _categorieSelectionnee;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _espace = widget.espaceInitiale ?? EspaceBibliotheque.kongo;
  }

  @override
  Widget build(BuildContext context) {
    final params = (
      espace: _espace,
      category: _categorieSelectionnee,
      search: _recherche.isEmpty ? null : _recherche,
    );
    final booksAsync = ref.watch(bibliothequeProvider(params));

    return Scaffold(
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.pourpre,
        title: const Text('Bibliothèque', style: TextStyle(color: AppColors.texte)),
        iconTheme: const IconThemeData(color: AppColors.or),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // ── ⭐ V4.42 Sélecteur d'espace : un seul espace visible à la fois ──
          // Chaque puce est Expanded : pas d'overflow même sur petit écran.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _PuceEspace(
                    espace: EspaceBibliotheque.kongo,
                    actif: _espace == EspaceBibliotheque.kongo,
                    onTap: () => _choisirEspace(EspaceBibliotheque.kongo),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PuceEspace(
                    espace: EspaceBibliotheque.afrika,
                    actif: _espace == EspaceBibliotheque.afrika,
                    onTap: () => _choisirEspace(EspaceBibliotheque.afrika),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PuceEspace(
                    espace: EspaceBibliotheque.collectif,
                    actif: _espace == EspaceBibliotheque.collectif,
                    onTap: () => _choisirEspace(EspaceBibliotheque.collectif),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Bannière de l'espace actif (animée au changement) ──
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
              child: _BanniereEspace(
                key: ValueKey(_espace),
                espace: _espace,
                nbOuvrages: booksAsync.value?.length,
              ),
            ),
          ),
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v),
              style: const TextStyle(color: AppColors.texte),
              decoration: InputDecoration(
                hintText: 'Rechercher un livre...',
                hintStyle: const TextStyle(color: AppColors.texteEteint),
                prefixIcon: Icon(Icons.search, color: _espace.accent),
                filled: true,
                fillColor: AppColors.pourpre,
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
                        color: selected ? AppColors.nuit : AppColors.texteSecondaire,
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
                            style: TextStyle(color: AppColors.texteSecondaire),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => ref.invalidate(bibliothequeProvider(params)),
                            child: const Text('Réessayer', style: TextStyle(color: AppColors.or)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (books) {
                    if (books.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book, size: 48, color: AppColors.texteEteint),
                              const SizedBox(height: 16),
                              Text(
                                _recherche.isNotEmpty
                                    ? 'Aucun livre ne correspond à votre recherche.'
                                    : 'Aucun livre dans l\'espace\n« ${_espace.nomComplet} » pour l\'instant.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.texteSecondaire),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Mémoriser les catégories disponibles pour les filtres
                    _updateCategories(books);

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: books.length,
                      itemBuilder: (ctx, i) => _CarteLivre(
                        book: books[i],
                        onTap: () => _ouvrirLivre(books[i]),
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

  void _choisirEspace(EspaceBibliotheque espace) {
    if (espace == _espace) return;
    setState(() {
      _espace = espace;
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

// ─── ⭐ V4.42 — Puce de sélection d'espace ─────────────────────────────

class _PuceEspace extends StatelessWidget {
  final EspaceBibliotheque espace;
  final bool actif;
  final VoidCallback onTap;

  const _PuceEspace({
    required this.espace,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = espace.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: actif ? accent : AppColors.pourpreClair,
            width: actif ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            // Point de couleur de l'espace
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: actif ? accent : AppColors.texteEteint,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                espace.nomComplet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: actif ? espace.accentClair : AppColors.texteSecondaire,
                  fontSize: 12.5,
                  fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ⭐ V4.42 — Bannière d'identité de l'espace actif ──────────────────

class _BanniereEspace extends StatelessWidget {
  final EspaceBibliotheque espace;
  final int? nbOuvrages;

  const _BanniereEspace({
    super.key,
    required this.espace,
    required this.nbOuvrages,
  });

  @override
  Widget build(BuildContext context) {
    final accent = espace.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            AppColors.pourpre,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Médaillon aux initiales de l'espace
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
            ),
            alignment: Alignment.center,
            child: Text(
              espace.initiales,
              style: TextStyle(
                color: espace.accentClair,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Espace ${espace.nomComplet}',
                  style: TextStyle(
                    color: espace.accentClair,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  espace.sousTitre,
                  style: const TextStyle(
                    color: AppColors.texteSecondaire,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  nbOuvrages == null
                      ? 'Chargement…'
                      : '${nbOuvrages ?? 0} ouvrage${(nbOuvrages ?? 0) > 1 ? 's' : ''} dans cet espace',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              color: AppColors.texte,
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
              color: AppColors.texteEteint,
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
      backgroundColor: AppColors.nuit,
      appBar: AppBar(
        backgroundColor: AppColors.pourpre,
        title: Text(
          book.title,
          style: const TextStyle(color: AppColors.texte, fontSize: 16),
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
                    const Icon(Icons.picture_as_pdf, size: 48, color: AppColors.texteEteint),
                    const SizedBox(height: 16),
                    Text(
                      book.description.isEmpty
                          ? 'Aucun fichier PDF disponible pour ce livre.'
                          : book.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.texteSecondaire),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _telecharger(BuildContext context) {
    // Pour l'instant, on ouvre l'URL dans le navigateur système.
    // TODO: implémenter le téléchargement local avec permission_handler + path_provider.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Téléchargement de « ${book.title} »...'),
        backgroundColor: AppColors.pourpreClair,
      ),
    );
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
                color: AppColors.texte,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Touchez le bouton ci-dessous pour ouvrir le PDF\ndans votre navigateur.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.texteSecondaire, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _ouvrirDansNavigateur(),
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

  Future<void> _ouvrirDansNavigateur() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
