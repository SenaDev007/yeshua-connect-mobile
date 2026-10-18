/// ⭐ V2.2 — LECTEUR WEB EMBARQUÉ (YouTube / TikTok) DANS L'APP.
///
/// Exigence du pasteur : les vidéos jouent À L'INTÉRIEUR de
/// l'application — plus aucune sortie vers les apps YouTube/TikTok.
///   · MP4/HLS hébergés par le Mouvement → LecteurVideoScreen (natif) ;
///   · YouTube  → iframe officielle youtube.com/embed (comme le web) ;
///   · TikTok   → iframe officielle tiktok.com/embed/v2 (comme le web —
///     la copie R2 reste préférée, l'embed TikTok peut se saturer).
///
/// La lecture exige Internet (seule fonction du ministère dans ce cas).
library;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';

class LecteurWebScreen extends StatefulWidget {
  /// URL complète à charger (embed YouTube / TikTok).
  final String url;
  final String titre;

  const LecteurWebScreen({super.key, required this.url, required this.titre});

  @override
  State<LecteurWebScreen> createState() => _LecteurWebScreenState();
}

class _LecteurWebScreenState extends State<LecteurWebScreen> {
  WebViewController? _controleur;
  bool _erreur = false;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    if (!Connectivite.instance.enLigne) {
      _erreur = true;
      return;
    }
    _controleur = _creerControleur();
  }

  WebViewController _creerControleur() {
    final controleur = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _chargement = false);
          },
          onWebResourceError: (e) {
            // Erreur de sous-ressource (pub, pixel…) : ignorée — seules
            // les erreurs de page PRINCIPALE basculent en état d'erreur.
            if (e.isForMainFrame == true && mounted) {
              setState(() {
                _erreur = true;
                _chargement = false;
              });
            }
          },
        ),
      );
    // Android : lecture SANS geste utilisateur (autoplay de l'embed) —
    // API spécifique de webview_flutter_android.
    if (controleur.platform is AndroidWebViewController) {
      (controleur.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    controleur.loadRequest(Uri.parse(widget.url));
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
      _controleur!.reload();
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
                ? _EtatErreur(horsLigne: !Connectivite.instance.enLigne)
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

  const _EtatErreur({required this.horsLigne});

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
                      'peut être momentanément saturé). Réessayez.',
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
              onPressed: () => context
                  .findAncestorStateOfType<_LecteurWebScreenState>()
                  ?._reessayer(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
