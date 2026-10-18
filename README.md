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

## ⭐ V2.4 — CORRECTIFS TERRAIN (2ᵉ vague de retours)

- **Chargement visible** : pendant le téléchargement du contenu (premier
  lancement comme mises à jour), l'écran affiche un **logo pulsant + barre
  dorée « Téléchargement du contenu… »** ; sur l'accueil déjà rempli, une
  **fine barre dorée** sous l'en-tête signale la mise à jour ; l'en-tête du
  menu affiche l'état en direct (téléchargement / à jour / hors ligne).
- **Menu : la page courante est sélectionnée** — « Accueil » est allumé sur
  l'accueil (plus l'accent permanent « Yeshua Connect » qui semblait être
  une sélection par défaut). Fond doré doux + liseré or + texte gras.
- **Hero anti-débordement** : correctif « bottom overflowed by 16 pixels »
  — le bloc texte des bannières (TOUTES les pages) vit dans une vue
  ancrée en bas : un texte plus haut (grandes polices système) défile
  au-dessus au lieu de lever une erreur.
- **Avatar du compte connecté** : sa **photo réelle** s'affiche dans la
  barre d'accueil, l'en-tête du menu et le bouton « Mon profil » (plus
  d'icône générique) ; la fiche profil relit `/api/user/profile`.
- **Navigation réparée (profil / retour)** :
  - un accès protégé depuis l'accueil mémorise sa destination
    (`/login?next=…`) : après connexion on y arrive **au-dessus de
    l'accueil** → retour arrière = accueil (plus jamais de piège dans la
    messagerie) ;
  - bouton retour depuis Yeshua Connect = **accueil du ministère**
    (jamais une sortie de l'application) ;
  - les 5 onglets de la communauté portent le **menu hamburger du
    ministère** (retour permanent vers tous les modules) ;
  - plus aucun doublon de pile (destination déjà atteinte = tiroir fermé).
- **Carte des dispersés V2 (parité web)** : **zoom à pincer ×1→×6** +
  panoramique + boutons +/−/recentrer, **courbes de Bézier dorées**
  reliant les dispersés (même formule que le site), **une épingle par
  membre à sa position exacte** (couleur du niveau spirituel) — toucher
  une épingle ouvre sa fiche (initiales, niveau, ville/pays, message).
  Données : `disperses.membres` de `/api/app/sync` **V4.14 web** (positions
  arrondies à 0.1°, serviteurs localisés inclus).
- **YouTube — erreur 153 corrigée** : l'embed WebView brut est remplacé
  par le **lecteur officiel `youtube_player_iframe`** (IFrame API dans
  une page HTML maîtrisée — la solution éprouvée de l'écosystème).
- **TikTok — « overload protect » atténué** : User-Agent Chrome mobile,
  garde de 20 s et **repli « Ouvrir dans TikTok » en dernier recours
  explicite** ; la copie R2 du ministère reste toujours essayée en
  premier (backfill back-office relancé en production).

## ⭐ V2.3 — ARTICLES PROFESSIONNELS (enseignements & témoignages)

- **Plus d'astérisques visibles** : les mots écrits entre `**deux
  astérisques**` ou `*un astérisque*` dans le back-office s'affichent
  désormais **en gras / en italique** — exactement comme sur le site
  (miroir du moteur web V4.13 : emphases mal espacées réparées,
  soulignés `__x__` convertis, `#Titre` sans espace corrigé).
- **Moteur markdown maison** (`lib/core/utils/markdown_texte.dart`,
  zéro dépendance) : titres hiérarchisés (`#` → `####`) avec filet or
  sous les sections, versets `>` en **blocs citation bordés d'or**,
  listes à puces et numérotées dorées, séparateurs `---`, gras doré
  pastel, Isolélé automatique (« Israël » → « **Isolélé** (Israël) »).
- **Fiches de lecture refondues** (enseignements + témoignages) :
  badges thème/livre, filet doré, citation d'ouverture en italique,
  corps structuré, carte « RÉFÉRENCE BIBLIQUE » et signature de la
  rédaction — la même carte article que le site.
- **Bonus cohérence** : biographies des serviteurs, jalons de la frise
  et annonces du ministère rendus au même format markdown ; extraits
  des cartes de liste nettoyés (plus de marqueurs résiduels).
- Validation : `flutter analyze` 0 erreur / 0 avertissement ; 19 tests
  (`test/markdown_texte_test.dart` — réparations, garde-fous listes et
  multiplications, Isolélé, rendu widget complet).

## ⭐ V2.2 — CORRECTIFS TERRAIN (retours pasteur)

- **Logo officiel** : l'app utilise désormais `logo-christ-libere-v3.png`
  (tête de lion à la crinière de feu + aigle + Afrique — le logo du site
  public) sur l'écran d'ouverture, la connexion, et **toutes les icônes
  Android** (carrée, ronde, adaptative).
- **Accueil** : les boutons du hero ne chevauchent **plus** le texte
  (marge réservée + dégradé porteur) ; le bouton « Découvrir le Pasteur
  Kongo » n'est plus transparent (fond nuit semi-opaque) ; les CTA
  naviguent vers les **vraies pages** (« Découvrir Afrika » → fiche
  d'Afrika, etc. — table de correspondance web → app).
- **Dispersés d'Isolélé** : orthographe officielle (`Isolélé (Israël)`,
  directive V3.45 du site) partout + **carte du monde en points**
  (dotted-map identique au site) avec épingles dorées pulsantes par pays.
- **Vidéos** : lecture **100 % INTÉGRÉE** — les MP4 hébergés (dont les
  copies R2 des TikTok, désormais vraiment utilisées) passent au lecteur
  natif, et YouTube/TikTok jouent dans un lecteur **web embarqué**
  (iframe officielle) : plus aucune sortie vers les apps externes.

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
