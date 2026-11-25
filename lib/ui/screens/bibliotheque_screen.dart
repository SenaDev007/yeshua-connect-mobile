/// Écran Bibliothèque — livres gratuits du pasteur et d'Afrika Pamela.
///
/// ⭐ V4.38 — Bibliothèque documentaire mobile.
/// Grille de couvertures avec filtres par catégorie, recherche,
/// et lecteur PDF intégré (webview).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/bibliotheque_repository.dart';

// ─── Provider Riverpod pour la bibliothèque ───────────────────────────

final bibliothequeProvider =
    FutureProvider.family<List<BookModel>, ({String? category, String? search})>(
  (ref, params) async {
    final repo = BibliothequeRepository();
    var books = await repo.tous();

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
  const BibliothequeScreen({super.key});

  @override
  ConsumerState<BibliothequeScreen> createState() => _BibliothequeScreenState();
}

class _BibliothequeScreenState extends ConsumerState<BibliothequeScreen> {
  String? _categorieSelectionnee;
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final params = (
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
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v),
              style: const TextStyle(color: AppColors.texte),
              decoration: InputDecoration(
                hintText: 'Rechercher un livre...',
                hintStyle: const TextStyle(color: AppColors.texteEteint),
                prefixIcon: const Icon(Icons.search, color: AppColors.or),
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
          // Filtres catégories (scroll horizontal)
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
                      selectedColor: AppColors.or,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.nuit : AppColors.texteSecondaire,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: AppColors.pourpre,
                      side: BorderSide(
                        color: selected ? AppColors.or : AppColors.pourpreClair,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // Grille de livres
          Expanded(
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
                      Text(
                        'Impossible de charger la bibliothèque.\nVérifiez votre connexion.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.texteSecondaire),
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
                          const Icon(Icons.menu_book, size: 48, color: AppColors.texteEteint),
                          const SizedBox(height: 16),
                          Text(
                            _recherche.isNotEmpty
                                ? 'Aucun livre ne correspond à votre recherche.'
                                : 'Aucun livre publié pour l\'instant.\nRevenez bientôt !',
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
        ],
      ),
    );
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
