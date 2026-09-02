# Yeshua Connect — Application Mobile (V1.2)

Application mobile **Flutter** officielle du **Mouvement Christ Libère**, connectée à la plateforme web
`mouvement-christ-libere.vercel.app`.

📦 **Code source** : https://github.com/SenaDev007/yeshua-connect-mobile

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
> (production : `https://mouvement-christ-libere.vercel.app`).

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

## 📜 Historique

- **V1.0** — première version : auth, conversations, chat, appels, recherche, profil (52 fichiers).
- **V1.1** — correctif du nom de l'appelant sur l'écran d'appel entrant + garde `isDirect`.
- **V1.2** — parité web : chaîne LiveKit → Agora → Daily (arbitrage serveur), média réel,
  interactions messages complètes, pièces jointes, notes vocales, sondages.
