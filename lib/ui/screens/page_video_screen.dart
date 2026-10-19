/// ⭐ V2.9 — PAGE VIDÉO UNIFIÉE (miroir fidèle de VideoPlayerView du web).
///
/// Demande du pasteur : « sur mobile, le schéma doit être le même, la
/// structure doit être la même comme pour le web : lorsque la vidéo est
/// en train de jouer, on voit à côté les vidéos similaires et il y a la
/// possibilité de mettre un like et de partager. »
///
/// Structure (identique à /videos côté web) :
///   · LECTEUR en haut —
///       – YouTube : WebView INTÉGRÉE sur youtube.com/embed (LE pattern
///         exact du site web — cf. _LecteurYouTube ci-dessous) ;
///       – copie R2 / MP4 hébergé (TikTok sauvegardé, rendus, replays) :
///         lecteur natif video_player ;
///       – TikTok sans copie : iframe officielle tiktok.com/embed/v2 ;
///   · TITRE + serviteur + VUES + LIKES (compteurs réels synchronisés
///     depuis YouTube/TikTok par la V4.17 web) ;
///   · ACTIONS : J'aime (POST /api/videos/<id>/like — même route que le
///     web), Partager (feuille native), Ouvrir (YouTube/TikTok, dernier
///     recours) ;
///   · DESCRIPTION dépliable ;
///   · VIDÉOS SIMILAIRES : même catégorie d'abord, puis même serviteur —
///     un tap remplace la vidéo en cours (comme le web).
///
/// ⭐ V2.9 — LECTURE YOUTUBE = PATTERN EXACT DU WEB : la V2.7 (paquet
/// youtube_player_iframe forké) n'a pas suffi — certaines vidéos
/// refusaient encore la lecture intégrée alors qu'elles jouent sur le
/// site. Le site incorpore une iframe `youtube.com/embed/<id>` servie
/// depuis le navigateur. L'app fait désormais EXACTEMENT pareil : une
/// WebView charge directement l'URL embed de youtube.com avec un
/// User-Agent Chrome mobile (le contexte « navigateur » que YouTube
/// attend — l'UA générique de WebView déclenche ses écrans d'erreur) ;
/// l'état d'erreur du lecteur YouTube (écran « ID de lecture ») est
/// détecté par sonde JS sur la page elle-même (même origine) et un
/// repli propre « Réessayer / Ouvrir sur YouTube » est proposé.
///
/// Hors-ligne : les métadonnées viennent de SQLite, mais la lecture exige
/// Internet (choix assumé du pasteur).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/config/app_config.dart';
import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api/api_client.dart';
import '../../data/models/contenu_models.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/contenu_widgets.dart' show resoudreUrl;

class PageVideoScreen extends StatefulWidget {
  final VideoModele video;

  /// Toutes les vidéos du contexte courant (grille filtrée ou page
  /// Adoration) — sert à composer la liste « Vidéos similaires », comme
  /// le web qui transmet allVideos à VideoPlayerView.
  final List<VideoModele> toutes;

  const PageVideoScreen({
    super.key,
    required this.video,
    required this.toutes,
  });

  @override
  State<PageVideoScreen> createState() => _PageVideoScreenState();
}

class _PageVideoScreenState extends State<PageVideoScreen> {
  late VideoModele _video;
  final _defilement = ScrollController();

  // ── Like (même mécanique que le web : localStorage ↔ SharedPreferences) ──
  static const _cleAimees = 'mcl_videos_aimees';
  bool _aime = false;
  int _compteurLikes = 0;
  bool _likeEnCours = false;

  // Description dépliée.
  bool _descriptionOuverte = false;

  // Remontage complet des lecteurs au changement de vidéo.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _chargerEtatLike();
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _chargerEtatLike() async {
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cleAimees);
    final Map<String, dynamic> aimees =
        brut == null ? {} : (jsonDecode(brut) as Map<String, dynamic>);
    if (!mounted) return;
    setState(() {
      _compteurLikes = _video.likes;
      _aime = aimees[_video.id] == true;
    });
  }

  Future<void> _basculerLike() async {
    if (_likeEnCours) return;
    if (!Connectivite.instance.enLigne) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Une connexion Internet est requise pour aimer une vidéo.'),
        backgroundColor: AppColors.pourpreClair,
      ));
      return;
    }
    final nouveau = !_aime;
    setState(() {
      _likeEnCours = true;
      _aime = nouveau;
      _compteurLikes = nouveau
          ? _compteurLikes + 1
          : (_compteurLikes > 0 ? _compteurLikes - 1 : 0);
    });

    // Persistance locale (miroir du localStorage « likedVideos » du web).
    final prefs = await SharedPreferences.getInstance();
    final brut = prefs.getString(_cleAimees);
    final Map<String, dynamic> aimees =
        brut == null ? {} : (jsonDecode(brut) as Map<String, dynamic>);
    if (nouveau) {
      aimees[_video.id] = true;
    } else {
      aimees.remove(_video.id);
    }
    await prefs.setString(_cleAimees, jsonEncode(aimees));

    // Persistance serveur — POST /api/videos/<id>/like {action}.
    try {
      final reponse = await ApiClient.instance.postJson(
        '/api/videos/${_video.id}/like',
        body: {'action': nouveau ? 'like' : 'unlike'},
      );
      if (mounted && reponse is Map<String, dynamic>) {
        final likes = reponse['likes'];
        if (likes is num) {
          setState(() => _compteurLikes = likes.toInt());
        }
      }
    } catch (_) {
      // Optimiste : on garde l'état local — la prochaine visite du web
      // affichera le compteur serveur.
    } finally {
      if (mounted) setState(() => _likeEnCours = false);
    }
  }

  Future<void> _partager() async {
    final lien = '${AppConfig.apiBaseUrl}/videos?v=${_video.id}';
    try {
      await Share.share(
        '${_video.titre}\n\n$lien',
        subject: _video.titre,
      );
    } catch (_) {
      // Partage indisponible sur cet appareil.
    }
  }

  /// Ouvre la source sur sa plateforme (YouTube / TikTok) — même dernier
  /// recours que le web (« Voir sur YouTube » / « Ouvrir sur TikTok »).
  Future<void> _ouvrirSourceExterne() async {
    final Uri? uri = _lienExterne == null ? null : Uri.tryParse(_lienExterne!);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune application trouvée pour ouvrir cette vidéo.'),
          backgroundColor: AppColors.pourpreClair,
        ));
      }
    }
  }

  String? get _lienExterne {
    if (_video.youtubeId.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=${_video.youtubeId}';
    }
    if (_video.tiktokId.isNotEmpty) {
      return _video.videoUrl ??
          'https://www.tiktok.com/@mouvementchristlibere/video/${_video.tiktokId}';
    }
    return null;
  }

  /// Vidéos similaires : même catégorie d'abord, puis même serviteur —
  /// comme la sidebar « Vidéos recommandées » du web.
  List<VideoModele> get _similaires {
    final autres = widget.toutes.where((v) => v.id != _video.id).toList();
    final memes = autres.where((v) => v.categorie == _video.categorie).toList();
    final memesServiteur =
        autres.where((v) => v.serviteur == _video.serviteur).toList();
    final reste = autres
        .where((v) =>
            v.categorie != _video.categorie && v.serviteur != _video.serviteur)
        .toList();
    return [...memes, ...memesServiteur, ...reste].take(20).toList();
  }

  void _choisir(VideoModele video) {
    setState(() {
      _video = video;
      _generation++;
      _descriptionOuverte = false;
    });
    _chargerEtatLike();
    if (_defilement.hasClients) {
      _defilement.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

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
          _video.titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.texte,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Lecteur ──
          _Lecteur(video: _video, generation: _generation),
          // ── Métadonnées + actions + similaires (défilables) ──
          Expanded(
            child: ListView(
              controller: _defilement,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
              children: [
                if (_video.categorie.isNotEmpty)
                  Text(
                    _video.categorie.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.or,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _video.titre,
                  style: const TextStyle(
                    color: AppColors.texte,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                // Serviteur + vues + likes.
                Row(
                  children: [
                    AvatarWidget(
                      photoUrl: null,
                      name: _video.nomServiteur,
                      size: 34,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _video.nomServiteur,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.texte,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.visibility_outlined,
                                  size: 13, color: AppColors.texteEteint),
                              const SizedBox(width: 3),
                              Text(
                                _compteLisible(_video.vues),
                                style: const TextStyle(
                                    color: AppColors.texteEteint,
                                    fontSize: 11.5),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.favorite_outline,
                                  size: 13, color: AppColors.texteEteint),
                              const SizedBox(width: 3),
                              Text(
                                _compteLisible(_compteurLikes),
                                style: const TextStyle(
                                    color: AppColors.texteEteint,
                                    fontSize: 11.5),
                              ),
                              if (_video.duree.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _video.duree,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.texteEteint,
                                        fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Barre d'actions (comme le web) ──
                Row(
                  children: [
                    _BoutonAction(
                      icone: _aime ? Icons.favorite : Icons.favorite_outline,
                      libelle: _compteurLikes > 0
                          ? _compteLisible(_compteurLikes)
                          : "J'aime",
                      actif: _aime,
                      couleurActive: const Color(0xFFE5484D),
                      enCours: _likeEnCours,
                      onTap: _basculerLike,
                    ),
                    const SizedBox(width: 8),
                    _BoutonAction(
                      icone: Icons.share_outlined,
                      libelle: 'Partager',
                      actif: false,
                      onTap: _partager,
                    ),
                    if (_lienExterne != null) ...[
                      const SizedBox(width: 8),
                      _BoutonAction(
                        icone: Icons.open_in_new,
                        libelle:
                            _video.youtubeId.isNotEmpty ? 'YouTube' : 'TikTok',
                        actif: false,
                        onTap: _ouvrirSourceExterne,
                      ),
                    ],
                  ],
                ),
                // ── Description ──
                if (_video.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => setState(
                        () => _descriptionOuverte = !_descriptionOuverte),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pourpre.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.pourpreClair),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _video.description.trim(),
                            maxLines: _descriptionOuverte ? null : 3,
                            overflow: _descriptionOuverte
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.texteSecondaire,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _descriptionOuverte
                                ? 'Réduire'
                                : 'Lire la description',
                            style: const TextStyle(
                              color: AppColors.orPastel,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // ── Vidéos similaires ──
                if (_similaires.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'VIDÉOS SIMILAIRES',
                    style: TextStyle(
                      color: AppColors.texte,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._similaires.map(
                    (v) => _CarteSimilaire(
                      video: v,
                      onTap: () => _choisir(v),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _compteLisible(int n) {
    if (n >= 1000000) {
      final m = (n / 1000000).toStringAsFixed(1);
      return '$m M';
    }
    if (n >= 1000) {
      final k = (n / 1000).toStringAsFixed(1);
      return '$k k';
    }
    return '$n';
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LECTEUR — choisit la brique selon la source (comme le web)
// ═══════════════════════════════════════════════════════════════════

class _Lecteur extends StatelessWidget {
  final VideoModele video;
  final int generation;

  const _Lecteur({required this.video, required this.generation});

  @override
  Widget build(BuildContext context) {
    if (!Connectivite.instance.enLigne) {
      return const _HorsLigne();
    }

    final direct = video.urlLectureDirecte;

    // ① YouTube — WebView sur youtube.com/embed (pattern exact du web).
    if (video.youtubeId.isNotEmpty) {
      return _LecteurYouTube(
        key: ValueKey('yt-${video.youtubeId}-$generation'),
        videoId: video.youtubeId,
      );
    }

    // ② Copie R2 / MP4 hébergé — lecteur natif.
    if (direct != null) {
      return _LecteurNatif(
        key: ValueKey('natif-${video.id}-$generation'),
        url: resoudreUrl(direct),
      );
    }

    // ③ TikTok sans copie — iframe officielle (repli).
    if (video.tiktokId.isNotEmpty) {
      return _LecteurTikTok(
        key: ValueKey('tt-${video.tiktokId}-$generation'),
        tiktokId: video.tiktokId,
        lienTiktok: video.videoUrl,
      );
    }

    // Aucune source lisible.
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Source vidéo indisponible pour cette vidéo.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.texteSecondaire, fontSize: 13.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorsLigne extends StatelessWidget {
  const _HorsLigne();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 40, color: AppColors.orPastel),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'La lecture des vidéos nécessite une connexion Internet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.texteSecondaire,
                      fontSize: 13,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ⭐ V2.9 — LECTEUR YOUTUBE : PATTERN EXACT DU WEB
//
//  Le site public incorpore une iframe standard :
//    https://www.youtube.com/embed/<id>?autoplay=1&rel=0&modestbranding=1
//  servie dans un navigateur — et toutes les vidéos du ministère y
//  jouent. L'app charge LA MÊME URL dans une WebView avec un User-Agent
//  Chrome mobile (un vrai contexte de navigateur — l'UA générique des
//  WebViews déclenche les écrans d'erreur 152/153 de YouTube).
//
//  Détection d'erreur : l'écran d'erreur de YouTube (« Une erreur s'est
//  produite… ID de lecture ») vit DANS la page embed — une sonde JS
//  (même origine que la page) vérifie .ytp-error ; en cas d'échec on
//  propose « Réessayer » (rechargement avec cache-buster) puis « Ouvrir
//  sur YouTube » en dernier recours, comme les lecteurs TikTok V2.4.
// ═══════════════════════════════════════════════════════════════════

class _LecteurYouTube extends StatefulWidget {
  final String videoId;

  const _LecteurYouTube({super.key, required this.videoId});

  @override
  State<_LecteurYouTube> createState() => _LecteurYouTubeState();
}

class _LecteurYouTubeState extends State<_LecteurYouTube> {
  WebViewController? _controleur;
  bool _erreur = false;
  bool _chargement = true;
  Timer? _garde;
  Timer? _sonde;

  static const _uaChromeMobile =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  String get _url => 'https://www.youtube.com/embed/${widget.videoId}'
      '?autoplay=1&rel=0&modestbranding=1&playsinline=1&hl=fr';

  @override
  void initState() {
    super.initState();
    _controleur = _creer();
  }

  @override
  void dispose() {
    _garde?.cancel();
    _sonde?.cancel();
    super.dispose();
  }

  WebViewController _creer({String? cacheBuster}) {
    final controleur = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _garde?.cancel();
            if (mounted) setState(() => _chargement = false);
            _armerSonde();
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && mounted) {
              _marquerErreur();
            }
          },
        ),
      )
      // ⭐ V2.9 — User-Agent CHROME MOBILE : YouTube doit voir un vrai
      // navigateur (même contexte que le site web) — l'UA générique des
      // WebViews déclenche ses écrans d'erreur.
      ..setUserAgent(_uaChromeMobile);
    if (controleur.platform is AndroidWebViewController) {
      (controleur.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    controleur.loadRequest(Uri.parse(
      cacheBuster == null ? _url : '$_url&_r=$cacheBuster',
    ));
    _armerGarde();
    return controleur;
  }

  /// Garde 25 s : si la page embed ne charge pas du tout (réseau TikTok
  /// style), état d'erreur explicite.
  void _armerGarde() {
    _garde?.cancel();
    _garde = Timer(const Duration(seconds: 25), () {
      if (mounted && _chargement) _marquerErreur();
    });
  }

  /// Sonde JS : l'écran d'erreur de YouTube (`.ytp-error` — « Une erreur
  /// s'est produite… ID de lecture ») n'émet AUCUN signal WebView — on
  /// interroge la page elle-même (même origine), 3 s après la fin du
  /// chargement puis toutes les 2,5 s pendant ~75 s (certaines erreurs
  /// n'apparaissent qu'après la résolution publicitaire).
  void _armerSonde() {
    _sonde?.cancel();
    var essais = 0;
    _sonde = Timer.periodic(const Duration(milliseconds: 2500), (t) async {
      essais++;
      if (!mounted || essais > 30) {
        t.cancel();
        return;
      }
      // Premier tick (2,5 s) : laisser le lecteur s'initialiser.
      if (essais == 1) {
        return;
      }
      try {
        final c = _controleur;
        if (c == null) return;
        final brut = await c.runJavaScriptReturningResult(
          '(function(){return document.querySelector(".ytp-error") != null'
          ' ? "1" : "0";})()',
        );
        if (brut.toString().contains('1')) {
          t.cancel();
          _marquerErreur();
        }
      } catch (_) {
        // Page en transition — sonde suivante.
      }
    });
  }

  void _marquerErreur() {
    _garde?.cancel();
    _sonde?.cancel();
    if (mounted) {
      setState(() {
        _erreur = true;
        _chargement = false;
      });
    }
  }

  void _reessayer() {
    setState(() {
      _erreur = false;
      _chargement = true;
    });
    // Remontage complet de la WebView + cache-buster (_r) : nouvelle
    // requête au CDN YouTube, pas de cache navigateur.
    _garde?.cancel();
    _sonde?.cancel();
    _controleur = _creer(
      cacheBuster: '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    );
  }

  Future<void> _ouvrirSurYoutube() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune application trouvée pour ouvrir cette vidéo.'),
          backgroundColor: AppColors.pourpreClair,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: _erreur || c == null
            ? _EcranErreurLecteur(
                onReessayer: _reessayer,
                onOuvrirExterne: _ouvrirSurYoutube,
                libelleExterne: 'Ouvrir sur YouTube',
                message: 'Cette vidéo n\'a pas pu être lancée par le lecteur '
                    'intégré.\nRéessayez — si le problème persiste, ouvrez-la '
                    'sur YouTube.',
              )
            : Stack(
                children: [
                  WebViewWidget(controller: c),
                  if (_chargement)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.or),
                    ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LECTEUR NATIF (copie R2 / MP4 hébergé — TikTok sauvegardé, rendus)
// ═══════════════════════════════════════════════════════════════════

class _LecteurNatif extends StatefulWidget {
  final String url;

  const _LecteurNatif({super.key, required this.url});

  @override
  State<_LecteurNatif> createState() => _LecteurNatifState();
}

class _LecteurNatifState extends State<_LecteurNatif> {
  VideoPlayerController? _controleur;
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    _controleur = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controleur?.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _erreur = true);
      });
  }

  @override
  void dispose() {
    _controleur?.dispose();
    super.dispose();
  }

  void _reessayer() {
    _controleur?.dispose();
    setState(() => _erreur = false);
    _controleur = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controleur?.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _erreur = true);
      });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: _erreur
            ? _EcranErreurLecteur(
                onReessayer: _reessayer,
                message: 'Cette vidéo n\'a pas pu être chargée. Réessayez '
                    'avec une connexion stable.',
              )
            : c == null || !c.value.isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.or),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // La vraie image, à SA ratio (TikTok = portrait).
                      Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio == 0
                              ? 16 / 9
                              : c.value.aspectRatio,
                          child: GestureDetector(
                            onTap: () {
                              setState(() =>
                                  c.value.isPlaying ? c.pause() : c.play());
                            },
                            child: VideoPlayer(c),
                          ),
                        ),
                      ),
                      if (!c.value.isPlaying)
                        const Icon(Icons.play_arrow,
                            size: 58, color: AppColors.or),
                      // Barre de progression discrète.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _BarreProgression(controleur: c),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _BarreProgression extends StatelessWidget {
  final VideoPlayerController controleur;

  const _BarreProgression({required this.controleur});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controleur,
      builder: (context, valeur, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        color: Colors.black.withValues(alpha: 0.35),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                valeur.isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppColors.or,
                size: 22,
              ),
              onPressed: () =>
                  valeur.isPlaying ? controleur.pause() : controleur.play(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VideoProgressIndicator(
                controleur,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.or,
                  backgroundColor: Colors.white24,
                  bufferedColor: Colors.white38,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_duree(valeur.position)} / ${_duree(valeur.duration)}',
              style: const TextStyle(
                  color: AppColors.texteSecondaire, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _duree(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LECTEUR TIKTOK (repli — iframe officielle, pattern V2.4 éprouvé)
// ═══════════════════════════════════════════════════════════════════

class _LecteurTikTok extends StatefulWidget {
  final String tiktokId;
  final String? lienTiktok;

  const _LecteurTikTok({super.key, required this.tiktokId, this.lienTiktok});

  @override
  State<_LecteurTikTok> createState() => _LecteurTikTokState();
}

class _LecteurTikTokState extends State<_LecteurTikTok> {
  WebViewController? _controleur;
  bool _erreur = false;
  bool _chargement = true;
  Timer? _garde;

  static const _uaChromeMobile =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

  String get _url => 'https://www.tiktok.com/embed/v2/${widget.tiktokId}';

  @override
  void initState() {
    super.initState();
    _controleur = _creer();
  }

  @override
  void dispose() {
    _garde?.cancel();
    super.dispose();
  }

  WebViewController _creer() {
    final controleur = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _garde?.cancel();
            if (mounted) setState(() => _chargement = false);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && mounted) {
              _marquerErreur();
            }
          },
        ),
      )
      // UA Chrome mobile — le CDN TikTok bloque les WebViews génériques
      // (« overload protect triggered », constat V2.4).
      ..setUserAgent(_uaChromeMobile);
    if (controleur.platform is AndroidWebViewController) {
      (controleur.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    controleur.loadRequest(Uri.parse(_url));
    _armerGarde();
    return controleur;
  }

  void _armerGarde() {
    _garde?.cancel();
    _garde = Timer(const Duration(seconds: 20), () {
      if (mounted && _chargement) _marquerErreur();
    });
  }

  void _marquerErreur() {
    _garde?.cancel();
    if (mounted) {
      setState(() {
        _erreur = true;
        _chargement = false;
      });
    }
  }

  void _reessayer() {
    setState(() {
      _erreur = false;
      _chargement = true;
    });
    if (_controleur == null) {
      _controleur = _creer();
    } else {
      _armerGarde();
      _controleur!.reload();
    }
  }

  Future<void> _ouvrirTiktok() async {
    final lien = widget.lienTiktok ?? _url;
    final uri = Uri.tryParse(lien);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucune application trouvée pour ouvrir cette vidéo.'),
          backgroundColor: AppColors.pourpreClair,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    return LayoutBuilder(
      builder: (context, contraintes) {
        // Vidéo TikTok = portrait 9:16 — la plus grande possible dans la
        // largeur, bornée à 62 % de la hauteur de l'écran (la suite de la
        // page — like, partage, similaires — reste visible dessous).
        final hauteurMax = MediaQuery.of(context).size.height * 0.62;
        var hauteur = contraintes.maxWidth * 16 / 9;
        if (hauteur > hauteurMax) hauteur = hauteurMax;
        return SizedBox(
          height: hauteur,
          width: double.infinity,
          child: ColoredBox(
            color: Colors.black,
            child: _erreur || c == null
                ? _EcranErreurLecteur(
                    onReessayer: _reessayer,
                    onOuvrirExterne: _ouvrirTiktok,
                    libelleExterne: 'Ouvrir dans TikTok',
                    message: 'Cette vidéo n\'a pas pu être chargée (le '
                        'lecteur TikTok peut être momentanément saturé).',
                  )
                : Stack(
                    children: [
                      WebViewWidget(controller: c),
                      if (_chargement)
                        const Center(
                          child: CircularProgressIndicator(color: AppColors.or),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  UI partagée
// ═══════════════════════════════════════════════════════════════════

/// Écran d'erreur propre d'un lecteur (même philosophie que les
/// lecteurs V2.4/V2.5 : « Réessayer » d'abord, plateforme externe en
/// dernier recours).
class _EcranErreurLecteur extends StatelessWidget {
  final VoidCallback onReessayer;
  final VoidCallback? onOuvrirExterne;
  final String? libelleExterne;
  final String message;

  const _EcranErreurLecteur({
    required this.onReessayer,
    this.onOuvrirExterne,
    this.libelleExterne,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 42, color: AppColors.orPastel),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texteSecondaire,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
              ),
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
            if (onOuvrirExterne != null && libelleExterne != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orPastel,
                  side: BorderSide(color: AppColors.or.withValues(alpha: 0.4)),
                ),
                onPressed: onOuvrirExterne,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(libelleExterne!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton d'action arrondi (like / partager / ouvrir) — miroir des pills
/// du web.
class _BoutonAction extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final bool actif;
  final Color? couleurActive;
  final bool enCours;
  final VoidCallback onTap;

  const _BoutonAction({
    required this.icone,
    required this.libelle,
    required this.actif,
    this.couleurActive,
    this.enCours = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? (couleurActive ?? AppColors.or) : AppColors.or;
    return Expanded(
      child: Material(
        color: actif
            ? (couleurActive ?? AppColors.or).withValues(alpha: 0.15)
            : AppColors.pourpre.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: enCours ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (enCours)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.or),
                  )
                else
                  Icon(icone, size: 16.5, color: couleur),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: actif ? couleur : AppColors.texte,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vidéo similaire (miniature + titre + compteurs) — miroir de la
/// sidebar « Vidéos recommandées » du web.
class _CarteSimilaire extends StatelessWidget {
  final VideoModele video;
  final VoidCallback onTap;

  const _CarteSimilaire({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.pourpre.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 132,
                    height: 76,
                    child: ImageUniverselle(
                      url: resoudreUrl(video.miniatureUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.nomServiteur,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.texteEteint, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined,
                              size: 11, color: AppColors.texteEteint),
                          const SizedBox(width: 3),
                          Text(
                            _compte(video.vues),
                            style: const TextStyle(
                                color: AppColors.texteEteint, fontSize: 10.5),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.favorite_outline,
                              size: 11, color: AppColors.texteEteint),
                          const SizedBox(width: 3),
                          Text(
                            _compte(video.likes),
                            style: const TextStyle(
                                color: AppColors.texteEteint, fontSize: 10.5),
                          ),
                          if (video.categorie.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                video.categorie,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.orPastel, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _compte(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)} k';
    return '$n';
  }
}
