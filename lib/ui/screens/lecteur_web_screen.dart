/// ⭐ V2.2 — LECTEUR WEB EMBARQUÉ (TikTok) DANS L'APP.
///
/// Exigence du pasteur : les vidéos jouent À L'INTÉRIEUR de
/// l'application — plus aucune sortie vers les apps YouTube/TikTok.
///   · MP4/HLS hébergés par le Mouvement → LecteurVideoScreen (natif) ;
///   · YouTube → LecteurYoutubeScreen (⭐ V2.4 — lecteur officiel
///     youtube_player_iframe, l'embed WebView brut renvoyait l'erreur 153) ;
///   · TikTok  → iframe officielle tiktok.com/embed/v2 (comme le web —
///     la copie R2 reste préférée, l'embed TikTok peut se saturer).
///
/// ⭐ V2.4 — fiabilisation du repli TikTok :
///   · User-Agent de navigateur Chrome mobile (le CDN TikTok bloque les
///     WebViews au UA générique — écran « overload protect triggered ») ;
///   · garde au bout de 20 s : si l'embed ne charge pas, état d'erreur
///     explicite avec « Ouvrir dans TikTok » en DERNIER recours
///     (l'utilisateur décide — la lecture intégrée reste la voie par
///     défaut, et la copie R2 du ministère est toujours essayée avant).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';

class LecteurWebScreen extends StatefulWidget {
  /// URL complète à charger (embed TikTok).
  final String url;
  final String titre;

  /// Dernier recours (SEULEMENT si l'embed est bloqué) : page réelle de
  /// la vidéo TikTok à ouvrir dans l'app/navigateur externe.
  final String? lienTiktok;

  const LecteurWebScreen({
    super.key,
    required this.url,
    required this.titre,
    this.lienTiktok,
  });

  @override
  State<LecteurWebScreen> createState() => _LecteurWebScreenState();
}

class _LecteurWebScreenState extends State<LecteurWebScreen> {
  WebViewController? _controleur;
  bool _erreur = false;
  bool _chargement = true;
  Timer? _garde;

  @override
  void initState() {
    super.initState();
    if (!Connectivite.instance.enLigne) {
      _erreur = true;
      return;
    }
    _controleur = _creerControleur();
  }

  @override
  void dispose() {
    _garde?.cancel();
    super.dispose();
  }

  /// Garde de chargement : l'embed TikTok bloqué (« overload protect »)
  /// ne déclenche AUCUNE erreur HTTP — la page reste blanche/figée.
  /// Au bout de 20 s sans fin de chargement, on bascule sur l'état
  /// d'erreur explicite.
  void _armerGarde() {
    _garde?.cancel();
    _garde = Timer(const Duration(seconds: 20), () {
      if (mounted && _chargement) {
        setState(() {
          _erreur = true;
          _chargement = false;
        });
      }
    });
  }

  WebViewController _creerControleur() {
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
            // Erreur de sous-ressource (pub, pixel…) : ignorée — seules
            // les erreurs de page PRINCIPALE basculent en état d'erreur.
            if (e.isForMainFrame == true && mounted) {
              _garde?.cancel();
              setState(() {
                _erreur = true;
                _chargement = false;
              });
            }
          },
        ),
      );
    // ⭐ V2.4 — User-Agent CHROME MOBILE : le CDN TikTok bloque les
    // WebViews au UA générique (« overload protect triggered ») ; avec
    // un UA de navigateur réel l'embed charge beaucoup plus souvent.
    controleur.setUserAgent(
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
    );
    // Android : lecture SANS geste utilisateur (autoplay de l'embed) —
    // API spécifique de webview_flutter_android.
    if (controleur.platform is AndroidWebViewController) {
      (controleur.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    controleur.loadRequest(Uri.parse(widget.url));
    _armerGarde();
    return controleur;
  }

  void _reessayer() {
    setState(() {
      _erreur = false;
      _chargement = true;
    });
    if (_controleur == null) {
      _controleur = _creerControleur();
    } else {
      _armerGarde();
      _controleur!.reload();
    }
  }

  /// Dernier recours (après échec de l'embed) : la page TikTok réelle —
  /// l'application TikTok si installée, sinon le navigateur.
  Future<void> _ouvrirDansTiktok() async {
    final lien = widget.lienTiktok;
    if (lien == null || lien.isEmpty) return;
    final uri = Uri.tryParse(lien);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune application trouvée pour ouvrir cette vidéo.'),
            backgroundColor: AppColors.pourpreClair,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Barre supérieure (retour + titre) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.or),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.texte,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Réessayer',
                    icon: const Icon(Icons.refresh, color: AppColors.or),
                    onPressed: _reessayer,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _erreur || c == null
                ? _EtatErreur(
                    horsLigne: !Connectivite.instance.enLigne,
                    lienTiktok: widget.lienTiktok,
                    onReessayer: _reessayer,
                    onOuvrirTiktok: _ouvrirDansTiktok,
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
        ],
      ),
    );
  }
}

class _EtatErreur extends StatelessWidget {
  final bool horsLigne;
  final String? lienTiktok;
  final VoidCallback onReessayer;
  final VoidCallback onOuvrirTiktok;

  const _EtatErreur({
    required this.horsLigne,
    required this.onReessayer,
    required this.onOuvrirTiktok,
    this.lienTiktok,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              horsLigne ? Icons.wifi_off : Icons.error_outline,
              size: 46,
              color: AppColors.orPastel,
            ),
            const SizedBox(height: 14),
            Text(
              horsLigne
                  ? 'La lecture des vidéos nécessite une connexion Internet.'
                  : 'Cette vidéo n\'a pas pu être chargée (le lecteur TikTok '
                      'peut être momentanément saturé).',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texteSecondaire,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.or,
                foregroundColor: AppColors.nuit,
              ),
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
            if (!horsLigne && lienTiktok != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orPastel,
                  side: BorderSide(color: AppColors.or.withValues(alpha: 0.4)),
                ),
                onPressed: onOuvrirTiktok,
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('Ouvrir dans TikTok'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
