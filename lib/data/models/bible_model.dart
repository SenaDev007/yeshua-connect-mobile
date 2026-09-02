/// ⭐ Bible — miroir exact du workspace web (BibleWorkspace.tsx) :
/// 6 versions, 66 livres (id/nom/catégorie/nombre de chapitres),
/// chapitres versets numérotés, recherche plein texte, marque-pages
/// (persistés côté serveur via /api/bible/bookmarks — SAME backend).
library;

/// Version biblique disponible (6 — identiques au web).
class BibleVersionModel {
  final String code;
  final String langue;
  final String nom;

  const BibleVersionModel({required this.code, required this.langue, required this.nom});

  factory BibleVersionModel.fromJson(Map<String, dynamic> json) => BibleVersionModel(
        code: json['code'] as String? ?? '',
        langue: json['langue'] as String? ?? '',
        nom: json['nom'] as String? ?? '',
      );

  /// Libellé court — « FR · ÉPÉE » (même forme que le web).
  String get libelleCourt {
    final langueMaj = langue.toUpperCase();
    final sigle = switch (code) {
      'fr-apee' => 'ÉPÉE',
      'en-kjv' => 'KJV',
      'en-bbe' => 'BBE',
      'es-rvr' => 'RVR',
      'pt-acf' => 'ACF',
      'ar-svd' => 'SVD',
      _ => code.toUpperCase(),
    };
    return '$langueMaj · $sigle';
  }
}

/// Un livre de la Bible (66 — table IDENTIQUE au web pour des
/// identifiants cohérents dans les marque-pages et les partages).
class LivreBibleModel {
  final String id;
  final String nom;
  final String categorie; // AT | NT
  final int chapitres;

  const LivreBibleModel({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.chapitres,
  });

  bool get estAncienTestament => categorie == 'AT';
}

/// Table des 66 livres — copie EXACTE de LIVRES_OPTIONS (BibleWorkspace).
const List<LivreBibleModel> kLivresBible = [
  LivreBibleModel(id: 'gn', nom: 'Genèse', categorie: 'AT', chapitres: 50),
  LivreBibleModel(id: 'ex', nom: 'Exode', categorie: 'AT', chapitres: 40),
  LivreBibleModel(id: 'lv', nom: 'Lévitique', categorie: 'AT', chapitres: 27),
  LivreBibleModel(id: 'nb', nom: 'Nombres', categorie: 'AT', chapitres: 36),
  LivreBibleModel(id: 'dt', nom: 'Deutéronome', categorie: 'AT', chapitres: 34),
  LivreBibleModel(id: 'js', nom: 'Josué', categorie: 'AT', chapitres: 24),
  LivreBibleModel(id: 'jg', nom: 'Juges', categorie: 'AT', chapitres: 21),
  LivreBibleModel(id: 'rt', nom: 'Ruth', categorie: 'AT', chapitres: 4),
  LivreBibleModel(id: '1sm', nom: '1 Samuel', categorie: 'AT', chapitres: 31),
  LivreBibleModel(id: '2sm', nom: '2 Samuel', categorie: 'AT', chapitres: 24),
  LivreBibleModel(id: '1kg', nom: '1 Rois', categorie: 'AT', chapitres: 22),
  LivreBibleModel(id: '2kg', nom: '2 Rois', categorie: 'AT', chapitres: 25),
  LivreBibleModel(id: '1ch', nom: '1 Chroniques', categorie: 'AT', chapitres: 29),
  LivreBibleModel(id: '2ch', nom: '2 Chroniques', categorie: 'AT', chapitres: 36),
  LivreBibleModel(id: 'er', nom: 'Esdras', categorie: 'AT', chapitres: 10),
  LivreBibleModel(id: 'ne', nom: 'Néhémie', categorie: 'AT', chapitres: 13),
  LivreBibleModel(id: 'est', nom: 'Esther', categorie: 'AT', chapitres: 10),
  LivreBibleModel(id: 'jb', nom: 'Job', categorie: 'AT', chapitres: 42),
  LivreBibleModel(id: 'ps', nom: 'Psaumes', categorie: 'AT', chapitres: 150),
  LivreBibleModel(id: 'pv', nom: 'Proverbes', categorie: 'AT', chapitres: 31),
  LivreBibleModel(id: 'ec', nom: 'Ecclésiaste', categorie: 'AT', chapitres: 12),
  LivreBibleModel(id: 'ct', nom: 'Cantique', categorie: 'AT', chapitres: 8),
  LivreBibleModel(id: 'es', nom: 'Ésaïe', categorie: 'AT', chapitres: 66),
  LivreBibleModel(id: 'je', nom: 'Jérémie', categorie: 'AT', chapitres: 52),
  LivreBibleModel(id: 'lm', nom: 'Lamentations', categorie: 'AT', chapitres: 5),
  LivreBibleModel(id: 'ez', nom: 'Ézéchiel', categorie: 'AT', chapitres: 48),
  LivreBibleModel(id: 'dn', nom: 'Daniel', categorie: 'AT', chapitres: 12),
  LivreBibleModel(id: 'os', nom: 'Osée', categorie: 'AT', chapitres: 14),
  LivreBibleModel(id: 'jl', nom: 'Joël', categorie: 'AT', chapitres: 3),
  LivreBibleModel(id: 'am', nom: 'Amos', categorie: 'AT', chapitres: 9),
  LivreBibleModel(id: 'ob', nom: 'Abdias', categorie: 'AT', chapitres: 1),
  LivreBibleModel(id: 'jn', nom: 'Jonas', categorie: 'AT', chapitres: 4),
  LivreBibleModel(id: 'mi', nom: 'Michée', categorie: 'AT', chapitres: 7),
  LivreBibleModel(id: 'na', nom: 'Nahum', categorie: 'AT', chapitres: 3),
  LivreBibleModel(id: 'hb', nom: 'Habacuc', categorie: 'AT', chapitres: 3),
  LivreBibleModel(id: 'so', nom: 'Sophonie', categorie: 'AT', chapitres: 3),
  LivreBibleModel(id: 'ag', nom: 'Aggée', categorie: 'AT', chapitres: 2),
  LivreBibleModel(id: 'za', nom: 'Zacharie', categorie: 'AT', chapitres: 14),
  LivreBibleModel(id: 'ml', nom: 'Malachie', categorie: 'AT', chapitres: 4),
  LivreBibleModel(id: 'mt', nom: 'Matthieu', categorie: 'NT', chapitres: 28),
  LivreBibleModel(id: 'mc', nom: 'Marc', categorie: 'NT', chapitres: 16),
  LivreBibleModel(id: 'lc', nom: 'Luc', categorie: 'NT', chapitres: 24),
  LivreBibleModel(id: 'jo', nom: 'Jean', categorie: 'NT', chapitres: 21),
  LivreBibleModel(id: 'ac', nom: 'Actes', categorie: 'NT', chapitres: 28),
  LivreBibleModel(id: 'rm', nom: 'Romains', categorie: 'NT', chapitres: 16),
  LivreBibleModel(id: '1co', nom: '1 Corinthiens', categorie: 'NT', chapitres: 16),
  LivreBibleModel(id: '2co', nom: '2 Corinthiens', categorie: 'NT', chapitres: 13),
  LivreBibleModel(id: 'ga', nom: 'Galates', categorie: 'NT', chapitres: 6),
  LivreBibleModel(id: 'ep', nom: 'Éphésiens', categorie: 'NT', chapitres: 6),
  LivreBibleModel(id: 'ph', nom: 'Philippiens', categorie: 'NT', chapitres: 4),
  LivreBibleModel(id: 'cl', nom: 'Colossiens', categorie: 'NT', chapitres: 4),
  LivreBibleModel(id: '1th', nom: '1 Thessaloniciens', categorie: 'NT', chapitres: 5),
  LivreBibleModel(id: '2th', nom: '2 Thessaloniciens', categorie: 'NT', chapitres: 3),
  LivreBibleModel(id: '1tm', nom: '1 Timothée', categorie: 'NT', chapitres: 6),
  LivreBibleModel(id: '2tm', nom: '2 Timothée', categorie: 'NT', chapitres: 4),
  LivreBibleModel(id: 'tt', nom: 'Tite', categorie: 'NT', chapitres: 3),
  LivreBibleModel(id: 'pm', nom: 'Philémon', categorie: 'NT', chapitres: 1),
  LivreBibleModel(id: 'he', nom: 'Hébreux', categorie: 'NT', chapitres: 13),
  LivreBibleModel(id: 'jq', nom: 'Jacques', categorie: 'NT', chapitres: 5),
  LivreBibleModel(id: '1pe', nom: '1 Pierre', categorie: 'NT', chapitres: 5),
  LivreBibleModel(id: '2pe', nom: '2 Pierre', categorie: 'NT', chapitres: 3),
  LivreBibleModel(id: '1jo', nom: '1 Jean', categorie: 'NT', chapitres: 5),
  LivreBibleModel(id: '2jo', nom: '2 Jean', categorie: 'NT', chapitres: 1),
  LivreBibleModel(id: '3jo', nom: '3 Jean', categorie: 'NT', chapitres: 1),
  LivreBibleModel(id: 'jd', nom: 'Jude', categorie: 'NT', chapitres: 1),
  LivreBibleModel(id: 'ap', nom: 'Apocalypse', categorie: 'NT', chapitres: 22),
];

/// Retrouve un livre par son identifiant.
LivreBibleModel? livreBibleParId(String id) {
  for (final l in kLivresBible) {
    if (l.id == id) return l;
  }
  return null;
}

/// Un verset numéroté.
class VersetBibleModel {
  final int numero;
  final String texte;

  const VersetBibleModel({required this.numero, required this.texte});

  factory VersetBibleModel.fromJson(Map<String, dynamic> json) => VersetBibleModel(
        numero: (json['numero'] as num?)?.toInt() ?? 0,
        texte: json['texte'] as String? ?? '',
      );
}

/// Chapitre complet — réponse de GET /api/bible-v2/{version}/{livre}/{chapitre}.
class ChapitreBibleModel {
  final String version;
  final String livre;
  final String livreId;
  final int chapitre;
  final int nombreVersets;
  final List<VersetBibleModel> versets;
  final bool fallback;

  const ChapitreBibleModel({
    required this.version,
    required this.livre,
    required this.livreId,
    required this.chapitre,
    required this.nombreVersets,
    required this.versets,
    this.fallback = false,
  });

  factory ChapitreBibleModel.fromJson(Map<String, dynamic> json) => ChapitreBibleModel(
        version: json['version'] as String? ?? '',
        livre: json['livre'] as String? ?? '',
        livreId: json['livreId'] as String? ?? '',
        chapitre: (json['chapitre'] as num?)?.toInt() ?? 1,
        nombreVersets: (json['nombreVersets'] as num?)?.toInt() ?? 0,
        versets: (json['versets'] as List<dynamic>? ?? [])
            .map((v) => VersetBibleModel.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        fallback: json['fallback'] == true,
      );

  /// Référence affichable — « Jean 3:16 ».
  String get reference => '$livre $chapitre';
}

/// Résultat de recherche plein texte (/api/bible-v2/search).
class ResultatRechercheBibleModel {
  final String livre;
  final String livreId;
  final int chapitre;
  final int verset;
  final String texte;

  const ResultatRechercheBibleModel({
    required this.livre,
    required this.livreId,
    required this.chapitre,
    required this.verset,
    required this.texte,
  });

  factory ResultatRechercheBibleModel.fromJson(Map<String, dynamic> json) =>
      ResultatRechercheBibleModel(
        livre: json['livre'] as String? ?? '',
        livreId: json['livreId'] as String? ?? '',
        chapitre: (json['chapitre'] as num?)?.toInt() ?? 1,
        verset: (json['verset'] as num?)?.toInt() ?? 1,
        texte: json['texte'] as String? ?? '',
      );

  String get reference => '$livre $chapitre:$verset';
}

/// Marque-page utilisateur — persisté côté SERVEUR (même base que le web :
/// un verset marqué sur mobile se retrouve sur le web, et inversement).
class MarquePageBibleModel {
  final String id;
  final String version;
  final String livreId;
  final String livreNom;
  final int chapitre;
  final int verset;
  final String texte;
  final String? note;
  final String? couleur;
  final DateTime? createdAt;

  const MarquePageBibleModel({
    required this.id,
    required this.version,
    required this.livreId,
    required this.livreNom,
    required this.chapitre,
    required this.verset,
    required this.texte,
    this.note,
    this.couleur,
    this.createdAt,
  });

  factory MarquePageBibleModel.fromJson(Map<String, dynamic> json) =>
      MarquePageBibleModel(
        id: json['id'] as String? ?? '',
        version: json['version'] as String? ?? '',
        livreId: json['livreId'] as String? ?? '',
        livreNom: json['livreNom'] as String? ?? '',
        chapitre: (json['chapitre'] as num?)?.toInt() ?? 1,
        verset: (json['verset'] as num?)?.toInt() ?? 1,
        texte: json['texte'] as String? ?? '',
        note: json['note'] as String?,
        couleur: json['couleur'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );

  String get reference => '$livreNom $chapitre:$verset';

  /// Le marque-page pointe-t-il sur le verset donné ?
  bool concerne(String livreId, int chapitre, int verset) =>
      this.livreId == livreId && this.chapitre == chapitre && this.verset == verset;
}

/// Verset prêt à PARTAGER dans une conversation (même format que le web :
/// message type VERSE — content = référence, verseRef, verseText).
class VersetPartage {
  final String reference;
  final String texte;

  const VersetPartage({required this.reference, required this.texte});
}
