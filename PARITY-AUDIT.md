# 🔍 Audit de parité totale — Web (Mouvement Christ Libéré) ↔ Mobile (Yeshua Connect)

> Édition V1.7 — 2026-09-06. Méthode : lecture croisée des routes API du
> backend partagé (28 routes `yeshua-connect` + routes live/bible/calendrier)
> contre l'implémentation Flutter (`lib/`). Backend partagé = 100 % (aucune
> donnée dupliquée, même PostgreSQL, mêmes tokens serveur).
>
> ⭐⭐ **V1.7 (2026-09-06) — RETOURS TERRAIN DU PASTEUR : 9 CAUSES RACINES
> CORRIGÉES** (test réel sur téléphone après l'audit V1.6) :
> ① **Icône de l'app** : Android affichait l'icône Flutter générique →
> icônes launcher REGENERATED depuis le logo officiel Christ Libéré
> (legacy 48→192 px + adaptative avec zone de sécurité et halo doré,
> fond nuit #1E0F2B) ;
> ② **Splash screen** : croix Material générique → CLONAGE FIDÈLE de
> l'intro web `landing-intro.tsx` (logo officiel pulsant + double halo,
> « Christ Libère », « Le shofar retentit… », « Ouverture de la
> visitation », barre 5 s en pourcentage, bouton « Passer ») + SON DU
> SHOFAR (même fichier, 30 s, qui poursuit après l'ouverture comme le
> web) ;
> ③ **Login** : icône générique → logo officiel avec halo doré ;
> ④ **PHOTOS DE PROFIL** (cause racine majeure) : les avatars du web sont
> des data-URLs base64 en base — `CachedNetworkImage` ne sait PAS les
> rendre → nouvel `AvatarWidget` universel (data-URL → `Image.memory`,
> http → `CachedNetworkImage`) → photos des MEMBRES, de l'UTILISATEUR
> CONNECTÉ (profil désormais lu via `/api/user/profile`, photo toujours
> fraîche), des bulles, des appels et des tuiles s'affichent ;
> ⑤ **STRUCTURE DES DISCUSSIONS** : liste plate tout mélangé (« tout est
> mélangé », « ça a multiplié certaines conversations ») → 4 SECTIONS
> DÉPLIABLES/REPLIABLES exactement comme la sidebar web : **Canaux** /
> **Groupes** (incl. PASTORS) / **Direct** / **Canaux vocaux** — mêmes
> titres, mêmes icônes, même filtrage, + dédoublonnage par id et tri par
> activité ; le titre/avatar d'un privé utilise L'AUTRE membre (plus
> jamais son propre nom) ;
> ⑥ **FICHIERS JOINTS** (« image indisponible partout ») : les images en
> data-URL s'affichent désormais (ImageUniverselle), les fichiers/vidéos
> sont TAPABLES (ouverture via navigateur/visionneuse ; data-URL →
> fichier temporaire), les notes vocales data-URL se lisent (temp +
> DeviceFileSource) ;
> ⑦ **APPELS SORTANTS** : « ça ne sonne pas comme sur la version web » →
> ringback.wav (même fichier) en BOUCLE à volume 0,5 pendant toute la
> phase sonnerie, coupé dès le décroché/la fin — comportement web exact ;
> ⑧ **BIBLE** : « chapitre indisponible sur cette version » → BUG DE
> PREMIER LANCEMENT corrigé (le contrôleur ne chargeait JAMAIS le
> chapitre par défaut au premier démarrage alors que l'API répond
> parfaitement) ; **+ 5 ONGLETS D'ÉTUDE AJOUTÉS** (parité
> BibleWorkspace web) : Lexique Strong, Texte hébraïque interlinéaire
> (tap mot → fiche Strong), Peshitta araméenne (66 livres, RTL),
> Concordance Strong, Comparatif (verset parallèle dans les 6 versions) ;
> ⑨ **CALENDRIER** : « ne s'affiche pas, ça met prochain événement » →
> VUE MENSUELLE biblique en GRILLE (comme vue-mensuelle web) : 7 colonnes
> J1→Shabbat, Shabbats dorés, fêtes colorées + pastille, jour courant
> encadré or, écho grégorien jour/mois, navigation ◀ ▶ 12 mois, fêtes du
> mois listées — en plus des vues Aujourd'hui et Années (existantes).
>
> ⭐ **V1.6 (2026-09-06) — 2 écarts réparés après re-audit face au web V3.43** :
> ① **J'aime du live** : le web V3.39 a un bouton cœur persistant
> (`GET/POST /api/live/[id]/like`, état mémorisé sur l'appareil) — l'app
> mobile ne l'avait pas → AJOUTÉ (cœur animé + compteur + persistance
> SharedPreferences, même route, même comportement) ;
> ② **Vote de sondage** : les options s'affichaient en texte INERTE et le
> repository envoyait `{ optionIds }` alors que l'API web attend
> `{ optionId }` (singulier) → double bug : vote impossible UI + erreur
> 400 serveur → CORRIGÉ (options tapables, coche/surlignage de MES votes,
> format d'appel conforme).

## ✅ PARITÉ TOTALE (forme et fond)

| Module | Web | Mobile | Détail |
|---|---|---|---|
| Authentification NextAuth (credentials) | ✅ | ✅ | Même flux CSRF → callback → session JWT (cookie persistant) |
| Conversations canaux/groupes/privés (V3.20) | ✅ | ✅ | Mêmes routes, filtrage serveur des privés, unreadCount, preview, tri |
| Chat : envoi/réception/pagination | ✅ | ✅ | Mêmes formats (TEXTE/VERSE/VOIX/IMAGE/FICHIER/SONDAGE) |
| Interactions messages : réponses, réactions, épinglage, modification, suppression, transfert | ✅ | ✅ | Mêmes routes PUT/DELETE/POST |
| Pièces jointes + notes vocales (multipart) | ✅ | ✅ | Enregistrement/lecture, chrono |
| Sondages : lecture + vote + **CRÉATION** | ✅ | ✅ | V1.5 : ➕ dans un canal — question/options/choix multiples (route `/polls`) ; ⭐ V1.6 : **votation réparée** (options tapables + `{ optionId }` conforme à l'API + coche de mes votes) |
| Annonces : lecture + **CRÉATION** (rôles annonceurs) | ✅ | ✅ | V1.5 : titre + corps + canal ANNOUNCEMENT (route `/announcements`) |
| Messages programmés : **création + suivi** | ✅ | ✅ | V1.5 : ➕ dans un canal, cron serveur `/api/cron/dispatch-scheduled` partagé |
| **Blocage/déblocage des membres (V3.5)** | ✅ | ✅ | V1.5 : fiche membre + Profil → Membres bloqués ; privés coupés, canaux ouverts |
| **🔴 Live public (viewer) — MODE YOUTUBE (V3.22)** | ✅ | ✅ | V1.5 : HLS `video_player` natif — **0 participant LiveKit côté viewer** ; replis WebRTC/Agora audience/Daily ; bascule ≤ 12 s ; pause persistée ; chat public + réactions ; compteur viewers réel (heartbeat 25 s) |
| Appels 1:1 audio/vidéo + Plan C P2P | ✅ | ✅ | SDK natifs, même signalisation |
| **Chaîne de repli multimédia LiveKit → Agora → Daily** | ✅ | ✅ | Appels + canaux vocaux + LIVES : même arbitrage serveur, bascule à chaud |
| Canaux vocaux persistants + mode vidéo admin | ✅ | ✅ | Rooms `yeshua-voice-<id>`, chaîne de repli, bascule auto |
| Bible (6 versions, recherche, marque-pages, partage de verset) | ✅ | ✅ | Marque-pages PARTAGÉS web ↔ mobile |
| Calendrier biblique + Shofar (fêtes, compte à rebours, annonce) | ✅ | ✅ | Même son, même texte d'annonce |
| Recherche globale (messages/canaux/utilisateurs) | ✅ | ✅ | Privés exclus côté serveur (V3.20) |
| Écran d'appel entrant (V1.1 : nom de l'APPELANT) | ✅ | ✅ | `initiatorName` + photo de l'appelant |
| **Notifications push (app fermée)** | ✅ (Web Push) | ✅ (FCM V1.4) | Appels privés + messages privés |
| Profil + annuaire membres | ✅ | ✅ | Photos, rôles, statut en ligne |

## ⚠️ PARTIEL (documenté — choix assumés)

| Écart | Impact | Explication |
|---|---|---|
| Daily (3ᵉ repli) = navigateur externe (appels, canaux vocaux, live) | Faible | SDK `daily_flutter` encore beta ; l'app ouvre la room Daily dans le navigateur (token serveur) — fonctionnel, sans crash. LiveKit + Agora = natifs. |
| Sonnerie shofar en arrière-plan | Faible | Le web ne sonne que l'onglet ouvert (ShofarNotifier) ; le mobile idem via l'écran calendrier. Une sonnerie OS en fond exigerait un service natif dédié. |
| Paramètres notifications + DND (dndEnabled, notif*) | Faible | Colonnes User prêtes ; l'UI web existe (profil). UI mobile non prioritaire (le push FCM V1.4 fonctionne sans). |
| Journal d'audit (admin, lecture seule) | Très faible | Route `/audit-log` prête ; écran de lecture mobile non demandé — consultable via le web. |

## ❌ RESTANTS

**Aucun écart bloquant.** La parité « sur la forme et le fond » est atteinte
sur **tous les modules** : messagerie, interactions, sondages (création
incluse), annonces (création incluse), messages programmés, blocage,
appels, canaux vocaux, **live public viewer (mode YouTube — économie de
facturation LiveKit)**, Bible, calendrier/Shofar, recherche, notifications
push — avec le **même backend**, la **même chaîne de repli
LiveKit → Agora → Daily** et les **mêmes formats de données**.

## Conclusion

⭐ **V1.6 = parité web ↔ mobile TOTALE, re-vérifiée contre le web V3.43**
(2026-09-06). Le spectateur du live mobile se comporte EXACTEMENT comme
celui du site (HLS, non compté, non interactif — exigence « comme YouTube »
du pasteur respectée sur les trois réseaux : LiveKit/Agora/Daily) — et il
peut désormais **aimer le live** (cœur persistant, parité V3.39 web) comme
sur le site. Le **vote de sondage** fonctionne enfin (options tapables,
format d'API conforme). Les annonces automatiques de lives publiées par le
relais web V3.36-V3.40 (création/reprogrammation/annulation) apparaissent
naturellement dans le canal Annonces de l'app (bulles texte + miniature
IMAGE, aucun changement requis). Les seuls écarts restants sont des choix
documentés (Daily navigateur, DND UI) sans impact d'usage.

⚠️ **Prérequis d'exécution** : l'app consomme le backend de production
`mouvement-christ-libere.vercel.app` — si le site Vercel est indisponible
(restriction compte/domaine), l'app affiche une erreur réseau à la
connexion tant que le backend n'est pas remis en ligne.

---

# ⭐ V1.8 — MODE HORS-LIGNE + FIX COMPILATION (2026-09-06)

## ① Corrections de compilation (blocage build Android)

| Erreur du build | Cause racine | Correction |
|---|---|---|
| `Type 'Uint8List' not found` (avatar_widget.dart:19) | `dart:typed_data` non importé | Import ajouté |
| `Method not found: 'BibleRepository'` ×5 (bible_screen) | Classe créée en V1.7 mais import absent | Import `bible_repository.dart` ajouté |
| `Member not found: 'scroll_outlined'` ×2 | Icône absente du SDK Flutter | `Icons.article_outlined` |
| Record `dynamic verset` incompatible (ligne 1672) | Erreur EN CASCADE des 5 précédentes (`_repo` devenu `dynamic` sans la classe) | Résolue par l'import |

Les avertissements Gradle 8.11.1 / AGP 8.9.1 / Kotlin 2.1.20 sont des
**avertissements de fin de support** — non bloquants, à traiter plus tard.

## ② Mode hors-ligne (exigence pasteur : « entrer et voir les conversations,
la Bible, le calendrier SANS internet ; seuls envois/appels/vidéos exigent
la connexion »)

**Architecture** (`lib/core/offline/`, aucune nouvelle dépendance) :

| Brique | Rôle |
|---|---|
| `CacheLocal` | Cache JSON local (documents app), écriture atomique `.tmp`→rename, plafond 12 Mo/entrée, empreinte anti-réécriture (le polling 10 s ne réécrit rien si contenu inchangé) |
| `Connectivite` | Enveloppe connectivity_plus v6 (`List<ConnectivityResult>`) : bandeau + pause des pollings |
| `ApiException.reseauKO` | Distingue échec RÉSEAU (hors ligne, timeout, 5xx, 404 déploiement absent) du refus applicatif (401/403) — déclenche le repli cache |
| `fetchSessionDetaillee()` | Session + diagnostic réseau : autorise l'entrée hors-ligne depuis la session en cache |

**Ce qui marche sans internet** (après une première consultation en ligne) :

| Fonction | Hors-ligne |
|---|---|
| ENTRER dans l'app (session restaurée) | ✅ |
| Liste des conversations (4 sections) | ✅ |
| Lecture des derniers messages (50/conversation) | ✅ |
| Bible — lecture, chapitre ◀▶ | ✅ |
| Bible — Strong, Hébreu, Peshitta, Concordance (déjà consultés) | ✅ |
| Calendrier biblique (grille mensuelle + années) | ✅ |
| Bandeau doré « Mode hors-ligne » | ✅ |
| Envois, réactions, votes, pièces jointes, appels, live | ❌ (connexion requise, message d'erreur FR) |

**Sécurités** : session purgée du cache au logout (pas de compte ressuscité) ;
401/403 ne servent jamais le cache (pas de données fantômes) ; recherche
biblique plein texte et pagination ancienne = en ligne (documenté).

---

## V1.9 — Calendrier complet + photo de profil + APK allégé (retours pasteur)

**Symptômes rapportés** : « Mois → "vue mensuelle indisponible sur ce backend" ;
Année → n'affiche rien ; Aujourd'hui → seulement "prochain événement" ; la photo
de profil ne s'affiche pas ; l'APK fait 326 Mo. »

| Cause racine | Correction V1.9 |
|---|---|
| Le téléphone a reçu la réponse LÉGère de `/evenements` (sans `annees`) — la vue Mois exigeait `annees[].jours`, la vue Années affichait `SizedBox.shrink()` quand `annees` était vide | `CalendarRepository` : si la réponse `?full=1` arrive sans `annees`, les 3 années sont récupérées via `GET /api/calendrier-biblique/{annee}` (route dédiée, même format), la réponse complète est ré-assemblée et **mise en cache** pour le hors-ligne. Message « indisponible » remplacé par un écran d'action avec bouton **Réessayer** |
| Vue Années vide aux bornes des 3 années | **Navigation continue** (parité web V3.10) : les chevrons ◀ ▶ chargent à la volée l'année manquante (1900-2100) via la même route, avec indicateur de chargement |
| Vue Aujourd'hui réduite au prochain événement | **Parité vue-aujourdhui.tsx** : carte « Jour biblique en cours » (22 Éloul · Jour N de l'année · équivalent grégorien · badge Shabbat · trimestre/saison), compte à rebours du **coucher de soleil** (18:00 UTC), carte **Prochaine fête** (fond couleur de la fête), puis le shofar/existant |
| `/api/user/profile` renvoie l'utilisateur À PLAT — le mobile cherchait `data['user']` (toujours faux) → photo jamais lue, repli sur le JWT figé au login | Lecture de la réponse à plat (`avatarUrl`, `bio`, `city`…) avec repli session |
| `MemberProfileModel` lisait `id`/`createdAt` alors que l'API membre envoie `userId`/`memberSince`/`isOnline` | Champs alignés (l'id vide rendait le bouton Bloquer inopérant) |
| APK debug **universel** = 4 architectures + symboles + JIT | `build.gradle` : `minifyEnabled` + `shrinkResources` + `resourceConfigurations 'fr'` + proguard-rules.pro (WebRTC/LiveKit/Agora/FCM conservés). **Compiler en release découpé** : `flutter build apk --release --split-per-abi` (arm64-v8a pour le TECNO KI5k) |

**Validation** (SDK réel Flutter 3.47.2) : `flutter analyze` → 0 erreur / 0
avertissement ; kernel compilé (76 Mo) ; API testée en direct : `?full=1` →
3 années × 364 jours, `/api/calendrier-biblique/2026` → format identique.

---

# ⭐ V2.0 — APPLICATION COMPLÈTE DU MINISTÈRE + HORS-LIGNE TOTAL (2026-10-18)

## ① Nouvelles surfaces publiques (miroir du site, SANS connexion)

| Page | Équivalent web | Détails |
|---|---|---|
| Accueil (landing) | `/` | Hero back-office (`/admin/heroes` → landing), bandeau DIRECT, 2 serviteurs, grille de sections, vies transformées, encart RDV |
| Menu hamburger | site-header | Groupes Serviteurs/Parole/Média/Communauté + Contribuer, état de synchro, connexion |
| Serviteurs ×2 | `/afrika`, `/pasteur-kongo` | Photos effectives (module servants), rôle, bio, frise chronologique (Biographies + versets + photos) |
| Témoignages | `/temoignages` | Filtres thème/serviteur + fiche de lecture complète |
| Enseignements | `/enseignements` | Recherche plein texte + filtres + fiche complète |
| Vidéos & Lives | `/videos` | Filtres catégorie/serviteur + recherche + miniatures + vues/likes ; lecture intégrée pour les MP4 hébergés (R2 TikTok/replays), app officielle pour YouTube/TikTok |
| Adoration & Louanges | `/adoration-louanges` | Scission Adoration/Louanges d'Afrika (V3.79 web) |
| Intercession | `/intercession` | Formulaire complet V3.32 (pays requis, contact) + note vocale V3.30 (2 min, multipart) |
| Dispersés | `/disperses` | Compteur mondial + répartition par pays + mission |
| Contribuer | `/contribuer` | FedaPay (Mobile Money) + Paystack via `/api/dons/initier` |
| Annonces | `/annonces` | Urgence en tête (tri web V3.67) |
| Rendez-vous | `/rendez-vous` | Formulaire V3.66 + code de suivi copiable |

Bible et Calendrier 364 restent publics (routes `/app/bible`,
`/app/calendrier`) — comme sur le site.

## ② Hors-ligne complet (SQLite + outbox)

- **`db_local.dart`** : base SQLite (`sqflite`) — tables `contenu`
  (miroir par section de `/api/app/sync`), `outbox` (file FIFO des
  messages rédigés hors ligne), `meta` (hash de changement).
- **`contenu_controller.dart`** : démarrage → lecture SQLite (app
  immédiatement utilisable) ; en ligne → `GET /api/app/sync` (V4.12
  web, 2 Mo : serviteurs, héros, 57+ témoignages, 69+ enseignements,
  1463+ vidéos, annonces, lives, dispersés) → SQLite → écrans notifiés ;
  toutes les 60 s → `GET /api/app/content` (V4.10 web — hash FNV) :
  hash changé = publication back-office → resynchronisation complète ;
  retour du réseau → resynchronisation + purge outbox.
- **Outbox « façon WhatsApp »** : envoi impossible (hors ligne ou
  serveur injoignable) → message en file SQLite + bulle « en attente »
  (horloge dorée, MessageModel.enAttenteLocal) ; au retour du réseau →
  envoi FIFO automatique (réponses incluses), remplacement par les vraies
  bulles serveur ; échec réseau interrompt la purge (le reste attend),
  erreur applicative retire le message (jamais bloquant).
- **Vidéos** : seule fonction exigeant Internet (exigence explicite) —
  lecteur intégré `video_player` pour NOS fichiers (R2/HLS), app
  officielle pour YouTube/TikTok.

## ③ Navigation & identité

- Routeur : splash → **accueil public** ; Yeshua Connect déplacé sous
  `/app/connect/*` (connexion requise — seul périmètre protégé) ;
  redirections historiques corrigées (chat, profil, appels, live).
- Login → entrée directe dans la communauté ; tiroir → profil/connexion.
- `android:label` : **Christ Libère** (app renommée).
- Icône : logo officiel (inchangé depuis V1.7 — adaptative + halo).

## ④ Validation

`flutter analyze` (Flutter 3.47.7) : **0 erreur / 0 avertissement**
(10 infos préexistantes V1.9 — const/dépréciations non introduites en
V2.0, fichiers nouveaux propres). `flutter test
test/compile_check_test.dart` : **arbre Dart complet compile** (+1).

## ⑤ Backend (projet web, déployé)

- **V4.12** `GET /api/app/sync` — bundle de synchronisation unifié
  (contenu complet, garde-fous idempotents, aucune donnée privée) —
  testé en production : HTTP 200, 2 035 801 octets, 2 serviteurs,
  57 témoignages, 69 enseignements, 1463 vidéos, 0 vies transformées
  (aucune publiée), 0 annonces (aucune publiée), lives OK.
