# 🔍 Audit de parité totale — Web (Mouvement Christ Libère) ↔ Mobile (Yeshua Connect)

> Édition V1.6 — 2026-09-06. Méthode : lecture croisée des routes API du
> backend partagé (28 routes `yeshua-connect` + routes live/bible/calendrier)
> contre l'implémentation Flutter (`lib/`). Backend partagé = 100 % (aucune
> donnée dupliquée, même PostgreSQL, mêmes tokens serveur).
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
