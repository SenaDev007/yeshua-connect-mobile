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
/// Lecture 100 % intégrée (exigence pasteur V2.2) — aucune sortie vers
/// l'application YouTube externe. Internet requis.
library;

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/offline/connectivite.dart';
import '../../core/theme/app_colors.dart';

class LecteurYoutubeScreen extends StatefulWidget {
  /// Identifiant YouTube (11 caractères).
  final String videoId;
  final String titre;

  const LecteurYoutubeScreen({super.key, required this.videoId, required this.titre});

  @override
  State<LecteurYoutubeScreen> createState() => _LecteurYoutubeScreenState();
}

class _LecteurYoutubeScreenState extends State<LecteurYoutubeScreen> {
  late final YoutubePlayerController _controleur =
      YoutubePlayerController.fromVideoId(
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
    ),
  );

  @override
  void dispose() {
    _controleur.close();
    super.dispose();
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
                            Icon(Icons.wifi_off, size: 46, color: AppColors.orPastel),
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
                  : Center(
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
