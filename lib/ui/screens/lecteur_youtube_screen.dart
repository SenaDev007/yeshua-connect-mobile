/// ⭐ V2.4 — LECTEUR YOUTUBE OFFICIEL DANS L'APP.
///
/// Contexte (retour pasteur) : l'embed brut `youtube.com/embed/ID` chargé
/// directement dans un WebView affichait « Une erreur de configuration du
/// lecteur s'est produite (153) » sur TOUTES les vidéos YouTube. La
/// solution éprouvée de l'écosystème Flutter est le paquet officiel
/// `youtube_player_iframe` : il sert SA page HTML maîtresse (IFrame API
/// YouTube), gère les spécificités du WebView Android et expose les
/// contrôles natifs du lecteur YouTube — c'est lui qui est utilisé ici.
///
/// ⭐ V2.5 — CORRECTIF ERREUR 152-4 (« Cette vidéo n'est pas disponible ») :
/// le lecteur officiel jouait certaines (voire toutes) les vidéos avec
/// l'erreur YouTube 152-4, alors que le site public joue les MÊMES vidéos
/// sans problème.
///   · CAUSE (confirmée par la source du paquet v5.2.1 + la communauté) :
///     par défaut `youtube_player_iframe` fait tourner le lecteur avec
///     l'ORIGINE « https://www.youtube.com » (baseUrl du document, host
///     de l'iframe, et playerVars origin/widget_referrer). Or YouTube
///     REFUSE un lecteur intégré qui provient de son propre domaine —
///     personne n'embarque légitimement un lecteur YouTube sur
///     youtube.com. Le site public, lui, embarque depuis
///     « mouvementchristlibere.com » : d'où la différence de comportement.
///   · CORRECTIF (V2.5) : déclarer l'origine « youtube-nocookie.com » —
///     le correctif confirmé par la communauté pour l'erreur 152-4.
///   · ⭐ V2.7 — CORRECTIF SUITE : avec l'origine nocookie, l'erreur 152-4
///     a bien disparu, mais CERTAINES vidéos (les contenus les plus
///     protégés par YouTube) refusaient encore la lecture intégrée :
///     « Une erreur s'est produite. Veuillez réessayer ultérieurement.
///     ID de lecture » — alors que les MÊMES vidéos se jouent sur le site
///     public et sur YouTube. La différence : le site public incorpore
///     une iframe servie par youtube.com DEPUIS mouvementchristlibere.com.
///     · CAUSE : en 5.2.1, `origin` pilote à la fois le HOST de l'iframe,
///     le baseUrl et les playerVars — impossible de reproduire le contexte
///     du site sans patcher le paquet.
///     · CORRECTIF : fork local du paquet (5.2.1+cl.1,
///     packages/youtube_player_iframe) qui FIXE le host sur youtube.com,
///     + origin = « https://www.mouvementchristlibere.com » (baseUrl +
///     playerVars). Le lecteur intégré se présente désormais à YouTube
///     EXACTEMENT comme le site public — où toutes les vidéos du
///     ministère fonctionnent.
///   · EN PRIME : détection de l'état d'erreur du lecteur → écran propre
///     en français avec « Réessayer » (le lecteur est recréé à neuf) et
///     « Ouvrir sur YouTube » en DERNIER recours (même philosophie que
///     le lecteur TikTok) — la lecture intégrée reste la voie normale.
///
/// Lecture 100 % intégrée (exigence pasteur V2.2) — aucune sortie vers
/// l'application YouTube externe. Internet requis.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';

class LecteurYoutubeScreen extends StatefulWidget {
  /// Identifiant YouTube (11 caractères).
  final String videoId;
  final String titre;

  const LecteurYoutubeScreen({
    super.key,
    required this.videoId,
    required this.titre,
  });

  @override
  State<LecteurYoutubeScreen> createState() => _LecteurYoutubeScreenState();
}

class _LecteurYoutubeScreenState extends State<LecteurYoutubeScreen> {
  late YoutubePlayerController _controleur;
  StreamSubscription<YoutubePlayerValue>? _abonnement;
  bool _enErreur = false;

  /// Incrémenté à chaque « Réessayer » : force le REMONTAGE complet du
  /// widget joueur (nouvelle WebView, nouvelle page maîtresse) — le seul
  /// remède fiable quand le lecteur YouTube entre en état d'erreur.
  int _tentative = 0;

  @override
  void initState() {
    super.initState();
    _controleur = _creer();
    _ecouter();
  }

  YoutubePlayerController _creer() => YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          playsInline: true,
          enableCaption: false,
          strictRelatedVideos: true,
          interfaceLanguage: 'fr',
          // Le lecteur s'adapte au thème sombre du ministère.
          color: 'white',
          // ⭐ V2.7 — ORIGINE DU SITE PUBLIC. Le fork local du paquet fixe
          // le host de l'iframe sur youtube.com (comme le site) ; cette
          // origine sert au baseUrl du document et aux playerVars
          // origin/widget_referrer : le lecteur intégré se présente à
          // YouTube exactement comme une incorporation faite depuis le
          // site public, où toutes les vidéos du ministère se jouent.
          // (V2.5 utilisait youtube-nocookie.com — accepté par YouTube,
          // mais refusé par certains contenus protégés.)
          origin: 'https://www.mouvementchristlibere.com',
        ),
      );

  /// Surveille l'état du lecteur (flux de valeurs du paquet) : bascule
  /// sur l'écran d'erreur — et uniquement lui — dès que YouTube signale
  /// une erreur, y compris les codes non répertoriés comme le 152.
  void _ecouter() {
    _abonnement?.cancel();
    _abonnement = _controleur.stream.listen((valeur) {
      final erreur = valeur.hasError;
      if (erreur != _enErreur && mounted) {
        setState(() => _enErreur = erreur);
      }
    });
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    _controleur.close();
    super.dispose();
  }

  /// « Réessayer » : ferme l'ancien contrôleur et en recrée un neuf —
  /// le widget joueur est remonté de zéro via la clé `_tentative`.
  void _reessayer() {
    _abonnement?.cancel();
    _controleur.close();
    setState(() {
      _tentative++;
      _enErreur = false;
    });
    _controleur = _creer();
    _ecouter();
  }

  /// Dernier recours (après échec du lecteur intégré) : la vraie page
  /// YouTube — l'application YouTube si installée, sinon le navigateur.
  Future<void> _ouvrirSurYoutube() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune application trouvée pour ouvrir cette vidéo.',
            ),
            backgroundColor: AppColors.pourpreClair,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horsLigne = !Connectivite.instance.enLigne;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Barre supérieure (retour + titre) ──
            Padding(
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
                ],
              ),
            ),
            Expanded(
              child: horsLigne
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: 46,
                              color: AppColors.orPastel,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'La lecture des vidéos nécessite une connexion Internet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.texteSecondaire,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // ⭐ V2.5 — écran d'erreur propre (au lieu du message
                  // gris de YouTube, illisible dans la WebView).
                  : _enErreur
                      ? _EtatErreurLecteur(
                          onReessayer: _reessayer,
                          onOuvrirYoutube: _ouvrirSurYoutube,
                        )
                      : Center(
                          key: ValueKey('youtube-$_tentative'),
                          child: YoutubePlayer(
                            controller: _controleur,
                            aspectRatio: 16 / 9,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⭐ V2.5 — Écran d'erreur du lecteur YouTube (même philosophie que le
/// lecteur TikTok) : « Réessayer » en premier, « Ouvrir sur YouTube » en
/// dernier recours uniquement.
class _EtatErreurLecteur extends StatelessWidget {
  final VoidCallback onReessayer;
  final VoidCallback onOuvrirYoutube;

  const _EtatErreurLecteur({
    required this.onReessayer,
    required this.onOuvrirYoutube,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 46,
              color: AppColors.orPastel,
            ),
            const SizedBox(height: 14),
            const Text(
              'Cette vidéo n\'a pas pu être lancée par le lecteur intégré.\n'
              'Réessayez — si le problème persiste, ouvrez-la sur YouTube.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
              onPressed: onOuvrirYoutube,
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Ouvrir sur YouTube'),
            ),
          ],
        ),
      ),
    );
  }
}
