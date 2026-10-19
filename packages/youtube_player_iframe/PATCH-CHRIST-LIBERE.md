# Fork Christ Libère — youtube_player_iframe 5.2.1+cl.1

Copie locale du paquet [`youtube_player_iframe` 5.2.1](https://pub.dev/packages/youtube_player_iframe)
(sarbagyastha, licence BSD), intégrée au dépôt de l'app pour **un seul correctif**.

## Pourquoi ce fork ?

Dans la 5.2.1 vanilla, le paramètre `YoutubePlayerParams.origin` pilote à lui
seul **trois choses à la fois** :

1. le **host de l'iframe** de lecture (`YT.Player({ host: … })`) ;
2. le **baseUrl** du document HTML chargé dans la WebView (`loadHtmlString`) ;
3. les **playerVars** `origin` + `widget_referrer`.

Il est donc impossible d'obtenir le contexte d'incorporation du site public —
une iframe servie par **youtube.com**, incorporée depuis
**mouvementchristlibere.com** — alors que c'est exactement ce contexte que
YouTube accepte pour toutes les vidéos du ministère.

- V2.4 (origine par défaut `www.youtube.com`) : erreur **152-4** sur toutes
  les vidéos — YouTube refuse un lecteur qui prétend tourner depuis
  youtube.com lui-même.
- V2.5 (origine `youtube-nocookie.com`) : l'erreur 152-4 a disparu, mais
  **certaines vidéos** (contenus les plus protégés) refusent l'embed
  « youtube-nocookie.com » (« *Une erreur s'est produite. Veuillez réessayer
  ultérieurement. ID de lecture* ») alors qu'elles se jouent parfaitement
  sur le site public — qui, lui, incorpore depuis **youtube.com**.

## Le correctif (V2.7)

`lib/src/controller/youtube_player_controller.dart`, méthode `load()` :

```dart
// vanilla 5.2.1 :
'host': params.origin ?? 'https://www.youtube.com',
// fork :
'host': 'https://www.youtube.com',
```

Le host de l'iframe est **fixé à youtube.com** (le domaine standard
d'incorporation — même choix que la v6 amont avec
`privacyEnhancedMode: false`), tandis que `origin` continue de piloter le
baseUrl et les playerVars. L'app passe alors
`origin: 'https://www.mouvementchristlibere.com'` (voir
`lib/ui/screens/lecteur_youtube_screen.dart`) : le lecteur intégré se
présente à YouTube **exactement comme le site public**, où toutes les
vidéos du ministère fonctionnent.

## Suivi amont

- La v6 du paquet sépare `privacyEnhancedMode` (host) et `origin` — elle
  rend ce fork inutile, mais exige Flutter ≥ 3.38 (contrainte plus stricte
  que l'environnement de build actuel du ministère).
- Si le paquet est un jour mis à jour vers la v6, supprimer ce dossier et
  reprendre le paquet hébergé.
