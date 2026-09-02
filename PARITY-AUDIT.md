# 🔍 Audit de parité totale — Web (Mouvement Christ Libère) ↔ Mobile (Yeshua Connect)

> Édition V1.4 — 2026-09-02. Méthode : lecture croisée des routes API du
> backend partagé (28 routes `yeshua-connect` + routes live/bible/calendrier)
> contre l'implémentation Flutter (`lib/`). Backend partagé = 100 % (aucune
> donnée dupliquée, même PostgreSQL, mêmes tokens serveur).

## ✅ PARITÉ TOTALE (forme et fond)

| Module | Web | Mobile | Détail |
|---|---|---|---|
| Authentification NextAuth (credentials) | ✅ | ✅ | Même flux CSRF → callback → session JWT (cookie persistant) |
| Conversations canaux/groupes/privés (V3.20) | ✅ | ✅ | Mêmes routes, filtrage serveur des privés, unreadCount, preview, tri |
| Chat : envoi/réception/pagination | ✅ | ✅ | Mêmes formats (TEXTE/VERSE/VOIX/IMAGE/FICHIER/SONDAGE) |
| Interactions messages : réponses, réactions, épinglage, modification, suppression, transfert | ✅ | ✅ | Mêmes routes PUT/DELETE/POST |
| Pièces jointes + notes vocales (multipart) | ✅ | ✅ | Enregistrement/lecture, chrono |
| Sondages : lecture + vote | ✅ | ✅ | Compteurs en direct |
| Appels 1:1 audio/vidéo + Plan C P2P | ✅ | ✅ | SDK natifs, même signalisation |
| **Chaîne de repli multimédia LiveKit → Agora → Daily** | ✅ | ✅ | Même arbitrage serveur `/calls/media`, bascule à chaud 2 s |
| Canaux vocaux persistants + mode vidéo admin | ✅ | ✅ | Rooms `yeshua-voice-<id>`, chaîne de repli, bascule auto |
| Bible (6 versions, recherche, marque-pages, partage de verset) | ✅ | ✅ | Marque-pages PARTAGÉS web ↔ mobile |
| Calendrier biblique + Shofar (fêtes, compte à rebours, annonce) | ✅ | ✅ | Même son, même texte d'annonce |
| Recherche globale (messages/canaux/utilisateurs) | ✅ | ✅ | Privés exclus côté serveur (V3.20) |
| Écran d'appel entrant (V1.1 : nom de l'APPELANT) | ✅ | ✅ | `initiatorName` + photo de l'appelant |
| **Notifications push (app fermée)** | ✅ (Web Push) | ✅ (FCM V1.4) | Appels privés + messages privés |
| Profil + annuaire membres | ✅ | ✅ | Photos, rôles, statut en ligne |

## ⚠️ PARTIEL (documenté)

| Écart | Impact | Explication |
|---|---|---|
| Daily (3ᵉ repli) mobile = navigateur externe | Faible | SDK `daily_flutter` encore beta ; l'app ouvre la room Daily dans le navigateur — fonctionnel, sans crash. LiveKit + Agora = natifs. |
| Sonnerie shofar en arrière-plan | Faible | Le web ne sonne que l'onglet ouvert (ShofarNotifier) ; le mobile idem via l'écran calendrier. Une sonnerie OS en fond exigerait un service natif dédié. |
| Sondages : vote ✅, création ❌ | Moyen | Routes `/polls` prêtes côté serveur ; il manque l'UI de création mobile (formulaire question/options). |
| Annonces : lecture dans le chat ✅, création ❌ | Moyen | Routes `/announcements` prêtes ; l'admin crée depuis le web. |
| Paramètres notifications + DND (dndEnabled, notif*) | Moyen | Colonnes User prêtes ; l'UI web existe (profil), pas encore l'UI mobile — pertinent maintenant que le push FCM est en place (V1.4). |

## ❌ RESTANTS (prochaine itération — routes serveur déjà prêtes)

| Fonction | Route web existante | Effort mobile estimé |
|---|---|---|
| **Écran live public (viewer)** ⭐ | `GET /api/live/[id]/stream` (V3.22 : HLS mode YouTube, 0 participant) + `/api/live/active`, `/chat`, `/viewers` | Faible — `video_player` lit le HLS NATIVEMENT : l'écran viewer mobile devient trivial et hérite du mode YouTube (économie de facturation LiveKit) |
| Blocage/déblocage d'un membre | `/api/yeshua-connect/blocks` (V3.5) | Faible — bouton profil + repository |
| Messages programmés (création/lecture) | `/api/yeshua-connect/scheduled-messages` | Moyen — écran + sélecteur date |
| Création de sondages | `/api/yeshua-connect/polls` | Faible |
| Création d'annonces (admin) | `/api/yeshua-connect/announcements` | Faible |
| Journal d'audit (admin) | `/api/yeshua-connect/audit-log` | Faible — écran lecture seule |

## Conclusion

La parité « sur la forme et le fond » est atteinte sur **tous les modules
utilisés quotidiennement** (messagerie, appels, canaux vocaux, Bible,
calendrier/Shofar, recherche, notifications push), avec la **même chaîne de
repli LiveKit → Agora → Daily** et le **même backend**. Les écarts restants
sont des **UI de création/back-office** (annonces, sondages, programmés,
audit, blocage) consommables par le web en attendant, plus l'**écran viewer
du live** — facilité par le flux HLS V3.22 — recommandé en tête de la
prochaine itération.
