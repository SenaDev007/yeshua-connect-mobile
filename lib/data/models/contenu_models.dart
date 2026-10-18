/// ⭐ V2.0 — MODÈLES DU CONTENU PUBLIC (miroir de `GET /api/app/sync`).
///
/// Chaque modèle est le reflet EXACT du JSON renvoyé par la route de
/// synchronisation unifiée du backend (web V4.12). Les instances vivent
/// principalement dans la base SQLite locale (`DbLocal`) : elles sont
/// parsées une fois à la synchronisation puis servies hors ligne.
///
/// Sources côté web :
///   · serviteurs  → table Servant + frises Biography + photos profil
///   · héros       → table HeroSection (back-office /admin/heroes)
///   · témoignages → Testimony (statut CONFIRMED)
///   · enseignements → Teaching
///   · vidéos      → Video (même format que /api/videos : likes, vues…)
///   · vies transformées → CroyantTestimony (statut « publie »)
///   · annonces    → MinistryAnnouncement (secrétariat, publiées)
///   · lives       → LiveStream (EN COURS + programmés)
library;

// ═══════════════════════════════════════════════════════════════════
//  SERVITEURS
// ═══════════════════════════════════════════════════════════════════

/// Jalon de la frise chronologique d'un serviteur (module Biographies).
class JalonBiographique {
  final String id;
  final String date;
  final String titre;
  final String description;
  final String versetRef;
  final String versetTexte;
  final String photoUrl;
  final int ordre;

  const JalonBiographique({
    required this.id,
    required this.date,
    required this.titre,
    required this.description,
    this.versetRef = '',
    this.versetTexte = '',
    this.photoUrl = '',
    this.ordre = 0,
  });

  factory JalonBiographique.fromJson(Map<String, dynamic> json) =>
      JalonBiographique(
        id: json['id'] as String? ?? '',
        date: json['date'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        versetRef: json['verseRef'] as String? ?? '',
        versetTexte: json['verseText'] as String? ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
        ordre: (json['order'] as num?)?.toInt() ?? 0,
      );
}

/// Serviteur de Dieu (Afrika / Pasteur Kongo).
class ServiteurModele {
  final String id;
  final String code; // "afrika" | "kongo"
  final String nomComplet;
  final String nomCourt;
  final String role;
  final String bio;
  final String portraitUrl;
  final String photo;
  final String pays;
  final String ville;
  final List<JalonBiographique> biographies;

  const ServiteurModele({
    required this.id,
    required this.code,
    required this.nomComplet,
    required this.nomCourt,
    required this.role,
    required this.bio,
    this.portraitUrl = '',
    this.photo = '',
    this.pays = '',
    this.ville = '',
    this.biographies = const [],
  });

  /// Photo effective : photo de profil du module /admin/servants en
  /// priorité, sinon le portrait historique (même règle que le web).
  String get photoEffective => photo.isNotEmpty ? photo : portraitUrl;

  factory ServiteurModele.fromJson(Map<String, dynamic> json) =>
      ServiteurModele(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        nomComplet: json['fullName'] as String? ?? '',
        nomCourt: json['shortName'] as String? ?? '',
        role: json['role'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        portraitUrl: json['portraitUrl'] as String? ?? '',
        photo: json['photo'] as String? ?? '',
        pays: json['pays'] as String? ?? '',
        ville: json['ville'] as String? ?? '',
        biographies: (json['biographies'] as List<dynamic>? ?? [])
            .map((j) => JalonBiographique.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  TÉMOIGNAGES & ENSEIGNEMENTS
// ═══════════════════════════════════════════════════════════════════

class TemoignageModele {
  final String id;
  final String titre;
  final String resume;
  final String contenu;
  final List<String> themes;
  final String referenceLivre;
  final String tempsLecture;
  final String publieLe;
  final String serviteur;
  final String nomServiteur;

  const TemoignageModele({
    required this.id,
    required this.titre,
    required this.resume,
    required this.contenu,
    this.themes = const [],
    this.referenceLivre = '',
    this.tempsLecture = '',
    this.publieLe = '',
    this.serviteur = '',
    this.nomServiteur = '',
  });

  factory TemoignageModele.fromJson(Map<String, dynamic> json) =>
      TemoignageModele(
        id: json['id'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        resume: json['short'] as String? ?? '',
        contenu: json['content'] as String? ?? '',
        themes: (json['themes'] as List<dynamic>? ?? [])
            .map((t) => t as String)
            .toList(),
        referenceLivre: json['bookRef'] as String? ?? '',
        tempsLecture: json['readingTime'] as String? ?? '',
        publieLe: json['publishedAt'] as String? ?? '',
        serviteur: json['servant'] as String? ?? '',
        nomServiteur: json['servantName'] as String? ?? '',
      );
}

class EnseignementModele {
  final String id;
  final String titre;
  final String extrait;
  final String contenu;
  final String theme;
  final String livre;
  final String niveau;
  final String tempsLecture;
  final String pdfUrl;
  final String publieLe;
  final String serviteur;
  final String nomServiteur;

  const EnseignementModele({
    required this.id,
    required this.titre,
    required this.extrait,
    required this.contenu,
    this.theme = '',
    this.livre = '',
    this.niveau = '',
    this.tempsLecture = '',
    this.pdfUrl = '',
    this.publieLe = '',
    this.serviteur = '',
    this.nomServiteur = '',
  });

  factory EnseignementModele.fromJson(Map<String, dynamic> json) =>
      EnseignementModele(
        id: json['id'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        extrait: json['excerpt'] as String? ?? '',
        contenu: json['content'] as String? ?? '',
        theme: json['theme'] as String? ?? '',
        livre: json['book'] as String? ?? '',
        niveau: (json['level'] as String? ?? '').toLowerCase(),
        tempsLecture: json['readingTime'] as String? ?? '',
        pdfUrl: json['pdfUrl'] as String? ?? '',
        publieLe: json['publishedAt'] as String? ?? '',
        serviteur: json['servant'] as String? ?? '',
        nomServiteur: json['servantName'] as String? ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════
//  VIDÉOS (même format que /api/videos)
// ═══════════════════════════════════════════════════════════════════

class VideoModele {
  final String id;
  final String youtubeId;
  final String tiktokId;
  final String? videoUrl;
  final String? tiktokMp4Url;
  final String? hlsUrl;
  final String titre;
  final String description;
  final String duree;
  final int vues;
  final int likes;
  final String publieLe;
  final String categorie;
  final bool estRubrique;
  final String serviteur;
  final String nomServiteur;
  final String miniatureUrl;
  final bool estLive;

  const VideoModele({
    required this.id,
    required this.titre,
    this.youtubeId = '',
    this.tiktokId = '',
    this.videoUrl,
    this.tiktokMp4Url,
    this.hlsUrl,
    this.description = '',
    this.duree = '',
    this.vues = 0,
    this.likes = 0,
    this.publieLe = '',
    this.categorie = '',
    this.estRubrique = false,
    this.serviteur = '',
    this.nomServiteur = '',
    this.miniatureUrl = '',
    this.estLive = false,
  });

  /// URL de lecture directe (copie R2 TikTok, MP4 hébergé, HLS) si
  /// disponible — sinon la vidéo s'ouvre via YouTube / TikTok.
  String? get urlLectureDirecte => tiktokMp4Url ?? videoUrl ?? hlsUrl;

  /// Vrai si lisible DANS l'app (lecteur natif) plutôt que via l'app
  /// YouTube / TikTok. La lecture exige Internet (choix assumé).
  bool get lisibleDansLapp {
    final u = urlLectureDirecte;
    return u != null && u.isNotEmpty && youtubeId.isEmpty && tiktokId.isEmpty;
  }

  factory VideoModele.fromJson(Map<String, dynamic> json) => VideoModele(
        id: json['id'] as String? ?? '',
        youtubeId: json['youtubeId'] as String? ?? '',
        tiktokId: json['tiktokId'] as String? ?? '',
        videoUrl: json['videoUrl'] as String?,
        tiktokMp4Url: json['tiktokMp4Url'] as String?,
        hlsUrl: json['hlsUrl'] as String?,
        titre: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        duree: json['duration'] as String? ?? '',
        vues: (json['views'] as num?)?.toInt() ?? 0,
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        publieLe: json['publishedAt'] as String? ?? '',
        categorie: json['category'] as String? ?? '',
        estRubrique: json['isRubric'] as bool? ?? false,
        serviteur: json['servant'] as String? ?? '',
        nomServiteur: json['servantName'] as String? ?? '',
        miniatureUrl: json['thumbnailUrl'] as String? ?? '',
        estLive: json['isLive'] as bool? ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════════
//  VIES TRANSFORMÉES · ANNONCES · LIVES
// ═══════════════════════════════════════════════════════════════════

/// Témoignage d'un croyant (« Vies transformées » — validé par un super
/// admin avant publication ; aucune donnée personnelle exposée).
class VieTransformeeModele {
  final String id;
  final String nom;
  final String pays;
  final String ville;
  final String profession;
  final String eglise;
  final String categorie;
  final String titre;
  final String contenu;
  final String publieLe;

  const VieTransformeeModele({
    required this.id,
    required this.nom,
    required this.titre,
    required this.contenu,
    this.pays = '',
    this.ville = '',
    this.profession = '',
    this.eglise = '',
    this.categorie = '',
    this.publieLe = '',
  });

  factory VieTransformeeModele.fromJson(Map<String, dynamic> json) =>
      VieTransformeeModele(
        id: json['id'] as String? ?? '',
        nom: json['nom'] as String? ?? '',
        pays: json['pays'] as String? ?? '',
        ville: json['ville'] as String? ?? '',
        profession: json['profession'] as String? ?? '',
        eglise: json['eglise'] as String? ?? '',
        categorie: json['categorie'] as String? ?? '',
        titre: json['titre'] as String? ?? '',
        contenu: json['contenu'] as String? ?? '',
        publieLe: json['publishedAt'] as String? ?? '',
      );
}

/// Annonce officielle du ministère (secrétariat).
class AnnonceMinistereModele {
  final String id;
  final String titre;
  final String contenu;
  final String categorie; // generale | live | evenement | urgence
  final String publieLe;

  const AnnonceMinistereModele({
    required this.id,
    required this.titre,
    required this.contenu,
    this.categorie = 'generale',
    this.publieLe = '',
  });

  factory AnnonceMinistereModele.fromJson(Map<String, dynamic> json) =>
      AnnonceMinistereModele(
        id: json['id'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        contenu: json['content'] as String? ?? '',
        categorie: json['category'] as String? ?? 'generale',
        publieLe: json['publishedAt'] as String? ?? '',
      );

  bool get estUrgente => categorie == 'urgence';
}

/// Live programmé à venir.
class LiveAVenirModele {
  final String id;
  final String titre;
  final String nomServiteur;
  final DateTime? programmeLe;
  final String miniatureUrl;

  const LiveAVenirModele({
    required this.id,
    required this.titre,
    this.nomServiteur = '',
    this.programmeLe,
    this.miniatureUrl = '',
  });

  factory LiveAVenirModele.fromJson(Map<String, dynamic> json) => LiveAVenirModele(
        id: json['id'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        nomServiteur: json['servantName'] as String? ?? '',
        programmeLe: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
        miniatureUrl: json['thumbnailUrl'] as String? ?? '',
      );
}

/// Live EN COURS (bandeau DIRECT de l'accueil).
class LiveEnCoursModele {
  final String id;
  final String titre;
  final String nomServiteur;
  final String youtubeUrl;
  final String hlsUrl;
  final DateTime? demarreLe;

  const LiveEnCoursModele({
    required this.id,
    required this.titre,
    this.nomServiteur = '',
    this.youtubeUrl = '',
    this.hlsUrl = '',
    this.demarreLe,
  });

  factory LiveEnCoursModele.fromJson(Map<String, dynamic> json) =>
      LiveEnCoursModele(
        id: json['id'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        nomServiteur: json['servantName'] as String? ?? '',
        youtubeUrl: json['youtubeUrl'] as String? ?? '',
        hlsUrl: json['hlsUrl'] as String? ?? '',
        demarreLe: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  SECTION HERO (bannières paramétrables du back-office)
// ═══════════════════════════════════════════════════════════════════

/// Configuration d'une bannière de page (table HeroSection, module
/// /admin/heroes du back-office — textes + image + boutons).
class HeroConfigModele {
  final String page;
  final String kicker;
  final String titre;
  final String accentTitre;
  final String suffixeTitre;
  final String sousTitre;
  final String imageDeFond;
  final String ctaLabel;
  final String ctaHref;
  final String cta2Label;
  final String cta2Href;
  final Map<String, dynamic> data;

  const HeroConfigModele({
    required this.page,
    this.kicker = '',
    this.titre = '',
    this.accentTitre = '',
    this.suffixeTitre = '',
    this.sousTitre = '',
    this.imageDeFond = '',
    this.ctaLabel = '',
    this.ctaHref = '',
    this.cta2Label = '',
    this.cta2Href = '',
    this.data = const {},
  });

  /// Titre complet (accent en or + suffixe) : « <titre> <accent> <suffixe> ».
  String get titreComplet {
    final parties = <String>[
      if (titre.isNotEmpty) titre,
      if (accentTitre.isNotEmpty) accentTitre,
      if (suffixeTitre.isNotEmpty) suffixeTitre,
    ];
    return parties.join(' ');
  }

  factory HeroConfigModele.fromJson(String page, Map<String, dynamic> json) =>
      HeroConfigModele(
        page: json['page'] as String? ?? page,
        kicker: json['kicker'] as String? ?? '',
        titre: json['title'] as String? ?? '',
        accentTitre: json['titleAccent'] as String? ?? '',
        suffixeTitre: json['titleSuffix'] as String? ?? '',
        sousTitre: json['subtitle'] as String? ?? '',
        imageDeFond: json['backgroundImage'] as String? ?? '',
        ctaLabel: json['ctaLabel'] as String? ?? '',
        ctaHref: json['ctaHref'] as String? ?? '',
        cta2Label: json['cta2Label'] as String? ?? '',
        cta2Href: json['cta2Href'] as String? ?? '',
        data: (json['data'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>(),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  ÉTAT DE SYNCHRONISATION (snapshot complet)
// ═══════════════════════════════════════════════════════════════════

/// Photo figée de TOUT le contenu local — ce que voient les écrans.
class ContenuState {
  final List<ServiteurModele> serviteurs;
  final Map<String, HeroConfigModele> heroes;
  final List<TemoignageModele> temoignages;
  final List<EnseignementModele> enseignements;
  final List<VideoModele> videos;
  final List<VieTransformeeModele> viesTransformees;
  final List<AnnonceMinistereModele> annonces;
  final LiveEnCoursModele? liveEnCours;
  final List<LiveAVenirModele> livesAVenir;
  final int dispersesTotal;
  final Map<String, int> dispersesParPays;

  /// Dernière synchronisation réussie (null = jamais synchronisé →
  /// l'app n'a encore AUCUN contenu local).
  final DateTime? synchroniseLe;

  const ContenuState({
    this.serviteurs = const [],
    this.heroes = const {},
    this.temoignages = const [],
    this.enseignements = const [],
    this.videos = const [],
    this.viesTransformees = const [],
    this.annonces = const [],
    this.liveEnCours,
    this.livesAVenir = const [],
    this.dispersesTotal = 0,
    this.dispersesParPays = const {},
    this.synchroniseLe,
  });

  bool get jamaisSynchronise => synchroniseLe == null;

  HeroConfigModele hero(String page) =>
      heroes[page] ?? HeroConfigModele(page: page);

  ContenuState copyWith({
    List<ServiteurModele>? serviteurs,
    Map<String, HeroConfigModele>? heroes,
    List<TemoignageModele>? temoignages,
    List<EnseignementModele>? enseignements,
    List<VideoModele>? videos,
    List<VieTransformeeModele>? viesTransformees,
    List<AnnonceMinistereModele>? annonces,
    LiveEnCoursModele? liveEnCours,
    bool effacerLiveEnCours = false,
    List<LiveAVenirModele>? livesAVenir,
    int? dispersesTotal,
    Map<String, int>? dispersesParPays,
    DateTime? synchroniseLe,
  }) =>
      ContenuState(
        serviteurs: serviteurs ?? this.serviteurs,
        heroes: heroes ?? this.heroes,
        temoignages: temoignages ?? this.temoignages,
        enseignements: enseignements ?? this.enseignements,
        videos: videos ?? this.videos,
        viesTransformees: viesTransformees ?? this.viesTransformees,
        annonces: annonces ?? this.annonces,
        liveEnCours: effacerLiveEnCours ? null : (liveEnCours ?? this.liveEnCours),
        livesAVenir: livesAVenir ?? this.livesAVenir,
        dispersesTotal: dispersesTotal ?? this.dispersesTotal,
        dispersesParPays: dispersesParPays ?? this.dispersesParPays,
        synchroniseLe: synchroniseLe ?? this.synchroniseLe,
      );
}
