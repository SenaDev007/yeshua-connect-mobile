/// ⭐ V2.16 — ENCAPSULATION DES ESPACES PRIVÉS (WebView plein écran).
///
/// Demande du pasteur : ouvrir le back-office, le secrétariat et la
/// trésorerie DANS l'application mobile, sans réécrire leur interface —
/// la version web officielle est donc encapsulée ici.
///
/// Fonctionnement :
///   · charge l'URL du sous-domaine (le proxy web redirige « / » vers le
///     tableau de bord de l'espace, ou sa page de connexion) ;
///   · la page de connexion officielle s'affiche → l'identifiant/mot de
///     passe se saisit ici même ; le cookie de session `admin_session`
///     (propre à CHAQUE hôte) est conservé par le WebView — au prochain
///     appel, l'espace s'ouvre DIRECTEMENT sans ressaisie ;
///   · navigation INTERNE conservée dans la WebView (le mini-menu
///     hamburger du back-office, les pages, les formulaires fonctionnent) ;
///   · tout lien sortant de l'espace (site public « Voir le site »…) est
///     ouvert dans le navigateur externe — l'app ne capture jamais un
///     contenu étranger à l'espace ;
///   · sélecteur de fichiers Android branché sur file_picker → les
///     uploads (photos des héros, documents) fonctionnent depuis l'app ;
///   · barre de progression, état hors ligne, état d'erreur + réessayer,
///     et « Ouvrir dans le navigateur » en dernier recours.
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';

/// Paramètres transportés par go_router (extra) vers EspaceWebScreen.
class EspaceWebParams {
  final String titre;
  final String url;

  /// Hôte qui reste DANS la WebView (ex. admin.mouvementchristlibere.com).
  final String hote;

  const EspaceWebParams({
    required this.titre,
    required this.url,
    required this.hote,
  });
}

class EspaceWebScreen extends StatefulWidget {
  final EspaceWebParams params;

  const EspaceWebScreen({super.key, required this.params});

  @override
  State<EspaceWebScreen> createState() => _EspaceWebScreenState();
}

class _EspaceWebScreenState extends State<EspaceWebScreen> {
  WebViewController? _controleur;
  bool _erreur = false;
  bool _chargement = true;
  int _progression = 0;
  bool _peutRevenirWeb = false;
  String? _dernierChargement;

  @override
  void initState() {
    super.initState();
    if (!Connectivite.instance.enLigne) {
      _erreur = true;
      _chargement = false;
      return;
    }
    _controleur = _creerControleur();
  }

  WebViewController _creerControleur() {
    final controleur = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFAF6EF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progression = p);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _chargement = false;
                _progression = 100;
              });
            }
            _majFlecheWeb();
          },
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            final hote = uri?.host.toLowerCase() ?? '';
            final interne = hote == widget.params.hote || hote.isEmpty;
            if (interne) return NavigationDecision.navigate;

            // Lien sortant de l'espace (site public « Voir le site », don,
            // lien TikTok…) : il s'ouvre dans le NAVIGATEUR — jamais dans
            // la WebView de l'espace (l'utilisateur voit exactement où il
            // va, et l'espace ne capture pas un contenu étranger).
            unawaited(_ouvrirExterne(req.url));
            return NavigationDecision.prevent;
          },
          onWebResourceError: (e) {
            // Erreur de sous-ressource (piste, pixel…) : ignorée — seules
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

    // UA de navigateur Chrome MOBILE : certains pare-feu / CDN ferment la
    // porte aux UA génériques de WebView, et l'app Next.js sert alors sa
    // variante mobile — exactement ce qu'on veut ici.
    // ⚠️ AVANT loadRequest : le premier chargement doit déjà l'utiliser.
    controleur.setUserAgent(
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
    );

    if (controleur.platform is AndroidWebViewController) {
      final android = controleur.platform as AndroidWebViewController;
      // ⭐ Uploads DEPUIS l'espace encapsulé (photos, documents) :
      // branchement du sélecteur de fichiers natif sur file_picker.
      android.setOnShowFileSelector((params) async {
        try {
          final resultat = await FilePicker.platform.pickFiles(
            type: FileType.any,
            // webview_flutter_android ≥ 4.14 : la sélection multiple se lit
            // dans `mode` (FileSelectorMode.openMultiple) — le getter
            // `allowMultipleSelection` n'existe plus.
            allowMultiple: params.mode == FileSelectorMode.openMultiple,
          );
          return resultat?.paths.whereType<String>().toList() ?? <String>[];
        } catch (_) {
          return <String>[];
        }
      });
      // Autoplay des médias (lecteurs intégrés des espaces).
      android.setMediaPlaybackRequiresUserGesture(false);
    }

    // Lancement du chargement APRÈS configuration complète.
    controleur.loadRequest(Uri.parse(widget.params.url));
    return controleur;
  }

  /// La flèche « web » s'allume seulement s'il y a une page précédente
  /// DANS l'espace (historique du WebView).
  Future<void> _majFlecheWeb() async {
    final c = _controleur;
    if (c == null) return;
    final possible = await c.canGoBack();
    if (mounted && possible != _peutRevenirWeb) {
      setState(() => _peutRevenirWeb = possible);
    }
  }

  Future<void> _ouvrirExterne(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir ce lien sur cet appareil.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _reessayer() {
    setState(() {
      _erreur = false;
      _chargement = true;
      _progression = 0;
    });
    final c = _controleur;
    if (c == null) {
      _controleur = _creerControleur();
      if (mounted) setState(() {});
    } else {
      c.reload();
    }
  }

  /// Retour : d'abord l'historique de la page (dans l'espace), sinon on
  /// quitte l'écran.
  Future<void> _retour() async {
    final c = _controleur;
    if (c != null && await c.canGoBack()) {
      await c.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controleur;
    final horsLigne = !Connectivite.instance.enLigne;
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barre de l'espace (retour, titre + hôte, actions) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.or),
                    onPressed: _retour,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.params.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.encre,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.params.hote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.orFonce.withValues(alpha: 0.8),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Page précédente',
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: 17,
                      color: _peutRevenirWeb
                          ? AppColors.or
                          : AppColors.encreEteinte,
                    ),
                    onPressed:
                        _peutRevenirWeb ? () => _controleur?.goBack() : null,
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh, color: AppColors.or),
                    onPressed: _reessayer,
                  ),
                  IconButton(
                    tooltip: 'Ouvrir dans le navigateur',
                    icon: const Icon(Icons.open_in_new,
                        color: AppColors.or),
                    onPressed: () =>
                        unawaited(_ouvrirExterne(widget.params.url)),
                  ),
                ],
              ),
            ),
            // ── Progression du chargement ──
            SizedBox(
              height: 2.5,
              child: _chargement && _progression < 100
                  ? LinearProgressIndicator(
                      value: _progression > 0 ? _progression / 100 : null,
                      backgroundColor:
                          AppColors.or.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.or),
                    )
                  : const SizedBox.shrink(),
            ),
            // ── Contenu ──
            Expanded(
              child: (_erreur || c == null || horsLigne)
                  ? _EtatErreur(
                      horsLigne: horsLigne,
                      onReessayer: _reessayer,
                      onOuvrirNavigateur: () => unawaited(
                          _ouvrirExterne(widget.params.url)),
                    )
                  : Stack(
                      children: [
                        WebViewWidget(controller: c),
                        if (_chargement)
                          const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.or),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtatErreur extends StatelessWidget {
  final bool horsLigne;
  final VoidCallback onReessayer;
  final VoidCallback onOuvrirNavigateur;

  const _EtatErreur({
    required this.horsLigne,
    required this.onReessayer,
    required this.onOuvrirNavigateur,
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
                  ? 'L\'espace privé nécessite une connexion Internet — '
                      'reconnectez-vous puis réessayez.'
                  : 'Cet espace n\'a pas pu être chargé. Vérifiez votre '
                      'connexion puis réessayez.',
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
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orPastel,
                side: BorderSide(color: AppColors.or.withValues(alpha: 0.4)),
              ),
              onPressed: onOuvrirNavigateur,
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Ouvrir dans le navigateur'),
            ),
          ],
        ),
      ),
    );
  }
}
