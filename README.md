# Yeshua Connect — Application Mobile (V1.4)

Application mobile **Flutter** officielle du **Mouvement Christ Libère**, connectée à la plateforme web
`mouvement-christ-libere.vercel.app`.

📦 **Code source** : https://github.com/SenaDev007/yeshua-connect-mobile

## 🔗 Backend PARTAGÉ avec le projet mère

> ⭐ Le dépôt GitHub est **séparé** (`yeshua-connect-mobile`) mais l'application
> consomme **EXCLUSIVEMENT le backend du projet web**
> (`Mouvement-Christ-Libere` — même base de code, même base PostgreSQL/Prisma) :
> authentification NextAuth, conversations, appels, **arbitrage multimédia
> LiveKit → Agora → Daily**, Bible, calendrier biblique, marque-pages…
> **Rien n'est dupliqué ni stocké ailleurs** — les marque-pages Bible créés sur
> mobile se retrouvent sur le web (et inversement).

URL par défaut : `https://mouvement-christ-libere.vercel.app` — surchargeable
SANS toucher au code pour brancher un backend local :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
flutter build apk --release   # production (défaut) — aucun dart-define requis
```

## 🕊️ Fonctionnalités

- **Connexion membre** — pseudonyme ou email + mot de passe (comptes validés par un administrateur).
- **Conversations** — canaux, groupes et **messages privés confidentiels** (V3.20 : filtrage serveur strict,
  seuls les 2 membres d'un privé peuvent le voir — y compris les admins).
- **Chat en temps réel** — envoi/réception de messages, pagination « charger plus ancien »,
  compteur de non-lus, épinglage, réactions, journal des appels dans le fil.
- **Appels audio & vidéo** — sonnerie entrante plein écran, accepter/refuser/raccrocher,
  chrono de durée, état reflété à distance.
- **Membres** — liste des membres d'une conversation, présence en ligne, démarrer un privé.
- **Recherche globale** — messages, canaux et membres.

## ⭐ V1.1 — Correctif « nom de l'appelant »

**Bug V1.0** : sur un appel entrant **privé**, l'écran affichait le nom du *canal* — or le nom d'un canal
privé est celui du **destinataire** vu par son créateur → Ora voyait son propre nom quand Pam l'appelait.

**Correctif V1.1** (s'appuie sur la V3.20 du web qui renvoie `isDirect` + `initiatorName` via
`GET /api/yeshua-connect/calls/signal?incoming=1`) :

- Sur un appel entrant **privé** (`isDirect: true`) → l'écran titre **l'appelant**
  (`initiatorName`), avec sa photo (`initiatorAvatarUrl`) prioritaire — « Pam vous appelle ».
- Sur un appel de **canal/groupe** → le nom du canal reste affiché, avec l'appelant en sous-ligne.
- Pendant TOUTE la durée de l'appel, l'info affichée est celle de **l'appelant**.

## 🛠️ Stack technique

| Élément | Version |
|---|---|
| Flutter / Dart | ≥ 3.24 / ≥ 3.5.0 |
| flutter_riverpod | 2.5.1 |
| go_router | 14.2.0 |
| dio (+ cookie_jar) | 5.4.3+1 |
| AGP / Kotlin | 8.9.1 / 2.1.20 |
| compileSdk / minSdk / targetSdk | 36 / 24 / 36 |
| Gradle | 8.11.1 |

Identité visuelle identique au web : **nuit** `#1E0F2B` · **pourpre** `#2A0E3D` · **or** `#C9A227`.

## 🔐 Authentification

L'app utilise le flux **NextAuth v5 (credentials)** du web :

1. `GET /api/auth/csrf` → jeton CSRF ;
2. `POST /api/auth/callback/credentials` (form-encoded : `csrfToken`, `pseudonyme`, `password`) ;
3. le cookie de session JWT est conservé dans un `CookieJar` persistant (8 h côté web / 30 j JWT) ;
4. toutes les requêtes API partent avec ce cookie — `userId` et rôle TOUJOURS décidés par le serveur.

## 📁 Architecture

```
lib/
├── main.dart                     Point d'entrée
├── app.dart                      MaterialApp + thème + router
├── core/
│   ├── config/app_config.dart    URL de l'API, constantes
│   ├── theme/                    couleurs & thème nuit/pourpre/or
│   ├── router/                   go_router (splash → login → app)
│   └── utils/formatters.dart     dates FR, durées d'appel
├── data/
│   ├── api/api_client.dart       dio + cookie jar + login NextAuth
│   ├── models/                   Conversation, Message, Call, User, Search
│   └── repositories/             auth, conversations, messages, calls, search
├── state/                        contrôleurs Riverpod (auth, chat, appels…)
└── ui/
    ├── screens/                  login, conversations, chat, appel entrant,
    │                             appel, membres, recherche, profil
    └── widgets/                  tuiles, bulles, avatars
```

## ▶️ Lancer le projet

```bash
flutter pub get
flutter run            # appareil connecté / émulateur
flutter build apk      # release Android
```

> L'URL de l'API se règle dans `lib/core/config/app_config.dart`
> (production : `https://mouvement-christ-libere.vercel.app`)
> ou via `--dart-define=API_BASE_URL=…`.

## ⭐ V1.2 — Parité web + chaîne de repli multimédia

**Chaîne d'appels (directive pasteur)** : LiveKit (source de vérité) → **Agora** (repli) → **Daily**
(dernier recours, room prebuilt dans le navigateur) — arbitrage 100 % serveur
(`/api/yeshua-connect/calls/media`, colonne `CallSignal.mediaProvider`) : l'appelant et le
destinataire rejoignent le MÊME réseau, bascule à chaud sans raccrocher (polling de statut),
badge « Réseau : LiveKit/Agora/Daily » + bandeau « Bascule automatique… ».

**Le média est désormais RÉEL sur mobile** : livekit_client 2.3.4 (Room native) et
agora_rtc_engine 6.5.0 — participants connectés, micro/caméra réellement pilotés,
indicateur de parole active.

**Interactions de parité web complètes** :
- Répondre à un message (bandeau de rappel)
- Réactions 🙏 ✋ ❤️ 📖 🔥 ⭐ (toggle, cliquables sous les bulles)
- Épingler / désépingler (persisté, panneau raccourci)
- Modifier son message (badge « modifié »)
- Supprimer (pour moi / pour tous — même dialogue que le web)
- Transférer vers une autre conversation
- Pièces jointes : images (lightbox zoom), vidéos, fichiers (FilePicker + multipart)
- Notes vocales : maintenir 🎤 pour enregistrer, lecture intégrée (audioplayers)
- Sondages affichés avec compteurs + vote

## ⭐ V1.3 — Bible · Calendrier & Shofar · Canaux vocaux (écrans dédiés)

### 📖 Bible (onglet dédié — parité web V2.6)
- **6 versions** : Bible de l'Épée, KJV, BBE, Reina Valera, ACF, Arabic Bible.
- **Navigation complète** : 66 livres AT/NT + chapitres, chapitre ◀ ▶, position
  de lecture mémorisée.
- **Recherche plein texte** de la version courante.
- **Partage de verset** dans une conversation — message `VERSE` au format web
  (`content` = référence, `verseRef`, `verseText`).
- **Marque-pages** persistés dans la base du projet mère (partagés web ↔ mobile).

### 📅 Calendrier biblique & Shofar (onglet dédié — parité web V3.6)
- **Prochain événement** avec compte à rebours en direct (Shabbat/solennité).
- **Prochains événements** : Shabbats + fêtes de l'Éternel, dates bibliques,
  entrée/sortie au coucher du soleil, jalons J-7 / J-3 / J-24 h.
- **Son du shofar** — même fichier audio que le web (`/sounds/shofar.mp3`).
- **Annonce** de la prochaine solennité dans un chat (texte IDENTIQUE au web).
- **Fêtes de l'Éternel** par année biblique (3 années, navigation ◀ ▶, J-restants).

### 🔊 Canaux vocaux persistants (écran dédié — parité web V2.7/V2.9/V3.21)
- **Room persistante** `yeshua-voice-<canal>` : on part, les autres restent.
- **Chaîne de repli identique au web** : LiveKit → Agora → Daily, arbitrage
  serveur (`join-voice` / `failover-voice`) — si LiveKit tombe en cours de
  canal, bascule AUTOMATIQUE vers Agora puis Daily, sans action utilisateur.
- **Participants en direct** (micro, orateur mis en avant), micro local.
- **Mode vidéo du canal** : décidé par l'ADMIN (« mode WhatsApp ») — bascule
  propagée à chaud via les métadonnées de la room ; les membres voient la
  caméra s'allumer/s'éteindre automatiquement.
- Carte d'état en haut du chat d'un canal vocal + badge « Réseau : … ».

### 🔐 Variables d'environnement — RIEN à configurer côté mobile

Tous les identifiants multimédias (LiveKit/Agora/Daily) sont générés **côté
serveur** par le backend partagé et livrés via `/api/yeshua-connect/calls/media` :
**aucune clé n'est embarquée dans l'APK**. La configuration se fait UNIQUEMENT
sur Vercel (projet web) :

| Variable (Vercel) | Fournisseur | Où la trouver |
|---|---|---|
| `AGORA_APP_ID` (32 car.) | Agora (repli 1) | console.agora.io → projet |
| `AGORA_APP_CERTIFICATE` (32 car.) | Agora | console.agora.io → certificat primaire |
| `DAILY_API_KEY` | Daily (repli 2) | dashboard.daily.co → Developers → API keys |
| `LIVEKIT_URL` / `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` | LiveKit (source de vérité) | déjà configurées |

> Un fournisseur sans identifiants est simplement **sauté** — la chaîne se
> dégrade proprement (voir `deploy/call-failover-chain/README.md` du repo web).

## ⭐ V1.4 — Notifications push (FCM, même app fermée)

- **Appels privés entrants** : « X vous appelle (audio/vidéo) » — notification
  HAUTE priorité → sonne/l'affiche MÊME APPLICATION FERMÉE (bac système
  Android).
- **Messages privés reçus** : « X : <aperçu> » (texte, note vocale, verset,
  photo, fichier).
- App ouverte : rien ne change (le polling temps réel existant gère déjà).
- Canaux publics : volontairement PAS de push (50 membres ≠ 50 vibrations).
- **Zéro secret dans l'APK** : l'envoi est 100 % serveur (Vercel) ; le mobile
  ne fait qu'enregistrer son token FCM (`POST /api/yeshua-connect/devices`,
  auth session) ; désactivation propre à la déconnexion.

### Configuration du push (optionnelle, sur la machine du pasteur)

1. **Vercel (projet web)** : `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`,
   `FCM_PRIVATE_KEY` — guide complet :
   `deploy/push-notifications/README.md` du dépôt web.
2. **Build mobile** : identifiants Firebase PUBLICS via `--dart-define`
   (issus du `google-services.json` de la console Firebase) :

```sh
flutter build apk --release \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_APP_ID=1:123:android:abc \
  --dart-define=FIREBASE_SENDER_ID=123456789 \
  --dart-define=FIREBASE_PROJECT_ID=yeshua-connect
```

> Sans ces `--dart-define`, l'APK fonctionne à l'identique — simplement sans
> notifications push (dégradation propre). iOS exige en plus APNs
> (compte Apple Developer + certificat téléversé dans Firebase).

## 📜 Historique

- **V1.0** — première version : auth, conversations, chat, appels, recherche, profil (52 fichiers).
- **V1.1** — correctif du nom de l'appelant sur l'écran d'appel entrant + garde `isDirect`.
- **V1.2** — parité web : chaîne LiveKit → Agora → Daily (arbitrage serveur), média réel,
  interactions messages complètes, pièces jointes, notes vocales, sondages.
- **V1.3** — écrans dédiés : **Bible** (6 versions, recherche, marque-pages partagés, partage de
  verset), **Calendrier biblique + Shofar** (compte à rebours, fêtes, son, annonces), **canaux
  vocaux persistants** (room persistante, chaîne de repli, mode vidéo admin) ; backend partagé
  explicité (`--dart-define=API_BASE_URL`).
- **V1.4** — notifications push FCM (appels privés + messages privés, même app fermée) ;
  init 100 % runtime via `--dart-define`, zéro secret dans l'APK, dégradation propre.
