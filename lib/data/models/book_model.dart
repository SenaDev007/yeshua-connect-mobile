/// Modèle Book — livre de la bibliothèque documentaire.
///
/// ⭐ V4.38 — Bibliothèque : livres gratuits publiés par le pasteur et
/// Afrika Pamela. Récupérés via GET /api/books (API publique du site web).
class BookModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String category;
  final String? coverUrl;
  final String? fileUrl;
  final int? pageCount;
  final String language;
  final int? publishedYear;
  final int downloadCount;
  final String? servantCode;
  final String? servantShortName;

  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    this.description = '',
    this.category = 'Autres',
    this.coverUrl,
    this.fileUrl,
    this.pageCount,
    this.language = 'Français',
    this.publishedYear,
    this.downloadCount = 0,
    this.servantCode,
    this.servantShortName,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Autres',
        coverUrl: json['coverUrl'] as String?,
        fileUrl: json['fileUrl'] as String?,
        pageCount: (json['pageCount'] as num?)?.toInt(),
        language: json['language'] as String? ?? 'Français',
        publishedYear: (json['publishedYear'] as num?)?.toInt(),
        downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
        servantCode: json['servantCode'] as String?,
        servantShortName: json['servantShortName'] as String?,
      );

  @override
  String toString() => 'BookModel($title par $author)';
}
