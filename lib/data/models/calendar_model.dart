/// ⭐ Calendrier biblique + moteur Shofar — miroir du web :
/// GET /api/calendrier-biblique/evenements (léger) et ?full=1 (3 années
/// sérialisées). Mêmes structures qu'`evenements-shofar.ts`.
library;

/// Jalon de notification d'une solennité : J-7 / J-3 / J-24 h.
class JalonModel {
  final String cle; // j7 | j3 | j24h
  final DateTime date;
  final String label;

  const JalonModel({required this.cle, required this.date, required this.label});

  factory JalonModel.fromJson(Map<String, dynamic> json) => JalonModel(
        cle: json['cle'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        label: json['label'] as String? ?? '',
      );
}

/// Un événement « shofar » : Shabbat hebdomadaire ou solennité.
class EvenementShofarModel {
  final String id;
  final String type; // shabbat | fete
  final String titre;
  final String? titreHebreu;
  final String couleur; // hex
  final String? dateBiblique; // « 14 Aviv »
  final DateTime dateGregorienne;
  final DateTime entree; // coucher du soleil d'entrée
  final DateTime sortie;
  final int dureeJours;
  final String? description;
  final String? reference;
  final bool travailInterdit;
  final List<JalonModel> jalons;

  const EvenementShofarModel({
    required this.id,
    required this.type,
    required this.titre,
    this.titreHebreu,
    this.couleur = '#2A0E3D',
    required this.dateGregorienne,
    required this.entree,
    required this.sortie,
    this.dateBiblique,
    this.dureeJours = 1,
    this.description,
    this.reference,
    this.travailInterdit = false,
    this.jalons = const [],
  });

  factory EvenementShofarModel.fromJson(Map<String, dynamic> json) =>
      EvenementShofarModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'shabbat',
        titre: json['titre'] as String? ?? '',
        titreHebreu: json['titreHebreu'] as String?,
        couleur: json['couleur'] as String? ?? '#2A0E3D',
        dateBiblique: json['dateBiblique'] as String?,
        dateGregorienne:
            DateTime.tryParse(json['dateGregorienne'] as String? ?? '') ?? DateTime.now(),
        entree: DateTime.tryParse(json['entree'] as String? ?? '') ?? DateTime.now(),
        sortie: DateTime.tryParse(json['sortie'] as String? ?? '') ?? DateTime.now(),
        dureeJours: (json['dureeJours'] as num?)?.toInt() ?? 1,
        description: json['description'] as String?,
        reference: json['reference'] as String?,
        travailInterdit: json['travailInterdit'] as bool? ?? false,
        jalons: (json['jalons'] as List<dynamic>? ?? [])
            .map((j) => JalonModel.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList(),
      );

  bool get estFete => type == 'fete';
  bool get estPasse => sortie.isBefore(DateTime.now());
}

/// Une fête de l'Éternel (sérialisation d'une année biblique).
class FeteModel {
  final String id;
  final String nomFr;
  final String? nomHebrew;
  final String referenceEcritures;
  final String description;
  final String categorie;
  final String couleur;
  final bool travailInterdit;
  final int dureeJours;
  final String dateBiblique;
  final DateTime dateGregorienne;
  final int jourDeSemaine;
  final int joursRestants;

  const FeteModel({
    required this.id,
    required this.nomFr,
    this.nomHebrew,
    required this.referenceEcritures,
    required this.description,
    required this.categorie,
    this.couleur = '#C9A227',
    required this.dateGregorienne,
    this.travailInterdit = false,
    this.dureeJours = 1,
    this.dateBiblique = '',
    this.jourDeSemaine = 1,
    this.joursRestants = 0,
  });

  factory FeteModel.fromJson(Map<String, dynamic> json) => FeteModel(
        id: json['id'] as String? ?? '',
        nomFr: json['nomFr'] as String? ?? '',
        nomHebrew: json['nomHebrew'] as String?,
        referenceEcritures: json['referenceEcritures'] as String? ?? '',
        description: json['description'] as String? ?? '',
        categorie: json['categorie'] as String? ?? '',
        couleur: json['couleur'] as String? ?? '#C9A227',
        travailInterdit: json['travailInterdit'] as bool? ?? false,
        dureeJours: (json['dureeJours'] as num?)?.toInt() ?? 1,
        dateBiblique: json['dateBiblique'] as String? ?? '',
        dateGregorienne:
            DateTime.tryParse(json['dateGregorienne'] as String? ?? '') ?? DateTime.now(),
        jourDeSemaine: (json['jourDeSemaine'] as num?)?.toInt() ?? 1,
        joursRestants: (json['joursRestants'] as num?)?.toInt() ?? 0,
      );

  bool get estPassee => joursRestants < 0;
}

/// Une année biblique sérialisée (364 jours — page /calendrier-biblique).
class AnneeBibliqueModel {
  final int annee;
  final String libelle;
  final DateTime debut;
  final DateTime fin;
  final int nombreJours;
  final List<FeteModel> fetes;

  const AnneeBibliqueModel({
    required this.annee,
    required this.libelle,
    required this.debut,
    required this.fin,
    required this.nombreJours,
    required this.fetes,
  });

  factory AnneeBibliqueModel.fromJson(Map<String, dynamic> json) => AnneeBibliqueModel(
        annee: (json['annee'] as num?)?.toInt() ?? 0,
        libelle: json['libelle'] as String? ?? '',
        debut: DateTime.tryParse(json['debut'] as String? ?? '') ?? DateTime.now(),
        fin: DateTime.tryParse(json['fin'] as String? ?? '') ?? DateTime.now(),
        nombreJours: (json['nombreJours'] as num?)?.toInt() ?? 364,
        fetes: (json['fetes'] as List<dynamic>? ?? [])
            .map((f) => FeteModel.fromJson(Map<String, dynamic>.from(f as Map)))
            .toList(),
      );
}
