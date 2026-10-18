# Mouvement Christ Libère — Application Mobile (V2.0)

Application mobile **Flutter** officielle du **Mouvement Christ Libère** :
l'application complète du ministère — accueil public, toutes les pages du
site, et la communauté **Yeshua Connect** — **utilisable hors ligne**.

📦 **Code source** : https://github.com/SenaDev007/yeshua-connect-mobile

## 🔗 Backend PARTAGÉ avec le projet mère

> ⭐ Le dépôt GitHub est **séparé** (`yeshua-connect-mobile`) mais l'application
> consomme **EXCLUSIVEMENT le backend du projet web**
> (`Mouvement-Christ-Libere` — même base de code, même base PostgreSQL/Prisma) :
> rien n'est dupliqué ni stocké ailleurs.

- URL par défaut : `https://mouvement-christ-libere.vercel.app`
- Surcharge sans toucher au code : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
- **V4.12 web** : `GET /api/app/sync` — route de synchronisation unifiée qui
  renvoie TOUT le contenu public (serviteurs, héros, témoignages,
  enseignements, vidéos, vies transformées, annonces, lives, dispersés) ;
  **V4.10 web** : `GET /api/app/content` — hash de changement (détection
  légère toutes les 60 s).

## ⭐ V2.0 — L'APPLICATION COMPLÈTE DU MINISTÈRE

### 🏠 Accueil public (comme le site)

- **Page d'accueil** type landing : grande bannère **pilotée par le
  back-office** (`/admin/heroes` → « landing »), bandeau **EN DIRECT** si un
  live est en cours, les **deux serviteurs**, grille des sections, aperçu
  « Vies transformées », encart **Rendez-vous**.
- **Menu hamburger** (tiroir latéral) : EXACTEMENT la structure du site —
  Serviteurs (Afrika, Pasteur Kongo) · Parole (Témoignages, Enseignements,
  Bible) · Média (Vidéos & Lives, Adoration & Louanges, Calendrier 364) ·
  Communauté (Yeshua Connect, Intercession, Dispersés, Annonces,
  Rendez-vous) · Contribuer — avec état de synchronisation et connexion.
- **Aucune connexion requise pour consulter** : tout le contenu est servi
  depuis la base SQLite locale (voir ci-dessous). Seule la LECTURE DES
  VIDÉOS exige Internet.

### 📖 Les 11 pages du ministère (miroir du site public)

| Page | Contenu |
|---|---|
| **Serviteurs ×2** | Photos (module `/admin/servants`), rôle, biographie, **frise chronologique** (module Biographies : jalons, versets, photos) |
| **Témoignages** | Témoignages CONFIRMÉS, filtres par thème et par serviteur, fiche de lecture complète |
| **Enseignements** | Recherche plein texte, filtres, niveau, fiche de lecture |
| **Vidéos & Lives** | Médiathèque complète : filtres catégorie + serviteur, recherche, miniatures, vues/likes ; lecture : MP4 **hébergés chez nous → lecteur intégré** (copie R2 TikTok, replays) ; YouTube/TikTok → app officielle |
| **Adoration & Louanges** | Page dédiée à Afrika, chantre de l'Éternel — scission Adoration / Louanges (V3.79 web) |
| **Intercession** | Formulaire complet (nom, pays, ville, téléphone, email, catégorie, urgence) + **NOTE VOCALE** (2 min) — multipart identique au web, arrivée directe back-office + canal « Sujets de prière » |
| **Dispersés d'Issos Lélé** | Compteur mondial, répartition par pays, mission de rassemblement |
| **Contribuer** | Dons **FedaPay** (Mobile Money MTN/Orange/Moov/Wave) ou **Paystack** (cartes internationales) — mêmes passerelles que le web, paiement sur la page sécurisée |
| **Annonces du ministère** | Voix officielle du secrétariat : urgence en tête, bascule automatique des annonces planifiées (V3.67 web) |
| **Rendez-vous** | Demande de rencontre (Afrika ou Pasteur Kongo) via le secrétariat + **code de suivi** (V3.66 web) |
| **Bible & Calendrier 364** | Publics, comme sur le site |

### 💾 Mode hors-ligne COMPLET (exigence pasteur)

> « Toutes les pages doivent marcher hors ligne avec une base de données
> locale intégrée ; seules les vidéos exigent la connexion ; les messages
> partent tout seuls au retour du réseau, comme WhatsApp. »

| Brique | Rôle |
|---|---|
| **SQLite locale** (`sqflite`, `lib/core/offline/db_local.dart`) | Miroir de TOUT le contenu public (une ligne par section) + table `outbox` (file d'envoi des messages) + `meta` (hash de synchro) |
| **Moteur de synchro** (`lib/state/contenu_controller.dart`) | Au démarrage : lecture SQLite (app utilisable immédiatement) → si en ligne : `GET /api/app/sync` → écriture SQLite → tous les écrans se rafraîchissent ; **surveillance légère 60 s** (hash `/api/app/app/content` — hash changé = back-office a publié → resynchronisation) |
| **OUTBOX « façon WhatsApp »** | Message rédigé hors ligne → mis en file SQLite + **bulle « en attente » (horloge)** → **envoi AUTOMATIQUE au retour du réseau** (ordre FIFO, y compris les réponses) ; les bulles envoyées sont remplacées par les vraies du serveur |
| **Images** | Mêmes visuels que le site (miniatures YouTube, photos R2, data-URLs base64) ; remplacement back-office → resynchronisation → app à jour |

Ce qui marche **sans internet** (après le premier passage en ligne) :
accueil, serviteurs, témoignages, enseignements, catalogue vidéos +
miniatures, adoration, annonces, dispersés, Bible, calendrier,
conversations et historique Yeshua Connect, rédaction de messages (file
d'envoi). Ce qui exige internet : lecture des vidéos, envoi des
formulaires (intercession, rendez-vous, dons), appels, lives.

### 🕊️ Yeshua Connect (communauté — connexion requise)

Tout l'existant V1.9 est préservé : conversations (canaux, groupes, privés
confidentiels), chat temps réel, interactions complètes (réponses,
réactions, épinglage, modification, suppression, transfert), pièces
jointes et notes vocales, sondages, appels audio/vidéo (chaîne LiveKit →
Agora → Daily), canaux vocaux persistants, Bible (6 versions + Strong +
hébreu + Peshitta + concordance), calendrier biblique + shofar, recherche,
profils, blocage, notifications push FCM.

## 🛠️ Stack technique

| Élément | Version |
|---|---|
| Flutter / Dart | ≥ 3.24 / ≥ 3.5.0 |
| flutter_riverpod | 2.5.1 |
| go_router | 14.2.0 |
| dio (+ cookie_jar) | 5.4.3+1 |
| **sqflite (base locale)** | 2.3.3+1 |
| video_player (lecteur intégré) | 2.9.1 |
| AGP / Kotlin | 8.9.1 / 2.1.20 |
| compileSdk / minSdk / targetSdk | 36 / 24 / 36 |
| Gradle | 8.11.1 |

Identité visuelle identique au web : **nuit** `#1E0F2B` · **pourpre** `#2A0E3D` · **or** `#C9A227`.
Icône de l'app : **logo officiel Christ Libère** (V1.7 — launcher legacy +
adaptative, halo doré, fond nuit).

## 🔐 Authentification (Yeshua Connect uniquement)

Le contenu du ministère est **public** (comme le site). La communauté
Yeshua Connect exige la connexion (NextAuth v5 credentials — même flux que
le web : CSRF → callback → cookie JWT persistant). Se connecter depuis le
tiroir ou l'icône en haut à droite de l'accueil.

## ▶️ Lancer le projet

```bash
flutter pub get
flutter run            # appareil connecté / émulateur
flutter test           # compile-check de l'arbre complet
flutter build apk --release --split-per-abi   # APK allégé par architecture
flutter build appbundle --release             # AAB (Play Store)
```

> Guide complet de génération (Android Studio, APK/AAB, signature) :
> **`docs/GUIDE-ANDROID-STUDIO.md`**.

## 📁 Architecture

```
lib/
├── main.dart                     Point d'entrée
├── core/
│   ├── config/app_config.dart    URL de l'API, pollings
│   ├── offline/
│   │   ├── db_local.dart         ⭐ V2.0 SQLite : contenu + outbox + meta
│   │   ├── cache_local.dart      cache JSON (conversations, Bible…)
│   │   └── connectivite.dart     suivi réseau (bandeau, pauses)
│   ├── router/                   go_router (splash → accueil public → …)
│   └── theme/                    couleurs & thème nuit/pourpre/or
├── data/
│   ├── api/api_client.dart       dio + cookie jar + login NextAuth
│   ├── models/                   ⭐ contenu_models.dart (serviteurs,
│   │                             témoignages, enseignements, vidéos…)
│   └── repositories/
├── state/
│   ├── contenu_controller.dart  ⭐ moteur de synchronisation + outbox
│   ├── chat_controller.dart     chat + file d'envoi différée
│   └── …                        auth, conversations, appels…
└── ui/
    ├── screens/
    │   ├── accueil_screen.dart  ⭐ landing publique
    │   ├── menu_tiroir.dart     ⭐ menu hamburger (structure du site)
    │   ├── serviteur_screen.dart ⭐ temoignages, enseignements, videos,
    │   ├── …                    adoration, intercession, disperses,
    │   │                        contribuer, annonces, rendez-vous,
    │   │                        lecteur_video
    │   └── …                    connect/ (chat, appels, bible…)
    └── widgets/
```

## 📜 Historique

- **V1.0–V1.9** — Yeshua Connect : messagerie complète, appels, Bible,
  calendrier, live viewer, push FCM, cache hors-ligne lecture (cf.
  PARITY-AUDIT.md).
- **V2.0** — **APPLICATION COMPLÈTE DU MINISTÈRE** : accueil public type
  landing + menu hamburger, 11 pages miroir du site, **base SQLite locale**
  (tout consultable hors ligne, seules les vidéos exigent Internet),
  **synchro automatique** (hash 60 s — le back-office publie, l'app se met
  à jour), **outbox « façon WhatsApp »** (envoi différé + bulle horloge +
  envoi automatique au retour du réseau), app renommée **Christ Libère**,
  contenu public sans connexion.
