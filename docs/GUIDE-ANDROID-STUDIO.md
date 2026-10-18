# 🛠️ GUIDE COMPLET — Générer l'application « Christ Libère » avec Android Studio

> Ce guide accompagne le dépôt **yeshua-connect-mobile** (V2.0). Il explique
> pas à pas comment installer l'environnement, ouvrir le projet, tester sur
> un téléphone, puis **générer l'APK** (installation directe) et l'**AAB**
> (Google Play Store) — sur **Windows**, **macOS** ou **Linux**.
>
> ⏱ Durée totale : environ 1 à 2 heures la première fois (téléchargements
> inclus), puis 5 à 10 minutes par génération.

---

## ① Installer les outils (une seule fois)

### 1. Android Studio (tout-en-un)

1. Ouvrez **https://developer.android.com/studio**
2. Cliquez sur **Download Android Studio** (bouton vert).
3. Lancez l'installeur et laissez toutes les options par défaut :
   - Windows : `Next → Next → Next → Install` (cochez tout) ;
   - macOS : glissez « Android Studio.app » dans Applications, ouvrez-le ;
   - Linux : décompressez le `.tar.gz`, lancez `studio.sh`.
4. Au **premier démarrage**, un assistant « Setup Wizard » s'ouvre :
   choisissez **Standard** → `Next` jusqu'au bout.
   > Android Studio télécharge alors le SDK Android, les outils de build
   > et un émulateur. Laissez tout faire — c'est le plus sûr.

### 2. Git (pour récupérer le code)

1. Ouvrez **https://git-scm.com/downloads** et installez Git (options par défaut).
2. Vérifiez dans un terminal : `git --version`

> 💡 **Alternative sans Git** : sur la page GitHub du projet, bouton vert
> **`<> Code` → `Download ZIP`**, puis décompressez. Vous perdrez juste la
> possibilité de récupérer les mises à jour en une commande.

### 3. Récupérer le code du projet

Ouvrez un terminal (ou Git Bash sur Windows) :

```bash
# Placez-vous où vous voulez ranger le projet (ex. : Documents)
cd Documents

# Cloner le dépôt privé (remplacez VOTRE_TOKEN par votre jeton GitHub)
git clone https://VOTRE_TOKEN@github.com/SenaDev007/yeshua-connect-mobile.git christ-libere-app

cd christ-libere-app
```

> 🔑 Le dépôt est privé : il faut un **jeton d'accès personnel** GitHub
> (github.com → Settings → Developer settings → Personal access tokens →
> Generate new token, droits `repo`). Le même que celui que vous m'avez
> déjà transmis fonctionne.

---

## ② Ouvrir le projet dans Android Studio

1. Lancez **Android Studio**.
2. **File → Open** (ou « Open » sur l'écran d'accueil).
3. Sélectionnez le dossier du projet **christ-libere-app** (celui qui
   contient `pubspec.yaml` et le sous-dossier `android/`) → **OK**.
4. ⚠️ **IMPORTANT** : Android Studio propose d'ouvrir le dossier `android/`
   (sous-dossier avec l'icône Android). **Ne l'ouvrez PAS séparément** —
   ouvrez toujours la **racine du projet Flutter**.

Android Studio détecte le projet Flutter et, en bas à droite, affiche
**« Pub get »** puis **« Indexing »**. Attendez la fin (première fois :
5 à 15 minutes de téléchargement des paquets Flutter/Dart).

### Si Android Studio ne connaît pas le SDK Flutter

Si un bandeau rouge « Dart SDK is not configured » apparaît :

1. **File → Settings** (Windows/Linux) ou **Android Studio → Preferences** (macOS).
2. **Languages & Frameworks → Flutter**.
3. **Flutter SDK path** : indiquez le chemin du SDK Flutter.
   - Si vous ne l'avez pas : téléchargez-le sur https://docs.flutter.dev/get-started/install
     (décompressez par ex. dans `C:\flutter` ou `~/flutter`), puis sélectionnez ce dossier ici.

---

## ③ Tester l'application sur votre téléphone (recommandé avant de générer)

### Activer le mode développeur sur le téléphone Android

1. **Réglages → À propos du téléphone** (ou « À propos de l'appareil »).
2. Tapez **7 fois** sur « Numéro de version » (ou « Numéro de build »)
   → message « Vous êtes maintenant développeur ! ».
3. Retournez dans **Réglages → Système → Options pour développeurs**.
4. Activez **« Débogage USB »**.
5. Branchez le téléphone au PC avec un câble USB ; sur le téléphone,
   acceptez « Autoriser le débogage USB » (cochez « Toujours autoriser »).

### Lancer l'app

1. En haut d'Android Studio, le sélecteur d'appareil liste votre téléphone
   (ex. : « TECNO KI5k ») — sélectionnez-le.
2. Cliquez sur le bouton vert **▶ Run** (ou `Shift + F10`).
3. L'application **Christ Libère** s'installe et s'ouvre sur le téléphone. 🎉

> Vérifications rapides : l'accueil affiche la bannière du ministère ;
> le menu hamburger (☰) ouvre la navigation complète ; coupez le Wi-Fi et
> les données → tout reste consultable ; le bandeau doré « Mode hors-ligne »
> apparaît ; écrivez un message dans Yeshua Connect hors ligne → bulle avec
> horloge → il part tout seul au retour du réseau.

---

## ④ GÉNÉRER L'APK (installation directe sur les téléphones)

> L'APK est le fichier d'installation que l'on partage directement
> (WhatsApp, clé USB, portail de téléchargement). C'est le format à
> utiliser pour distribuer l'app à la communauté sans passer par Google.

### Méthode A — Android Studio (interface graphique)

1. Menu **Build → Generate Signed Bundle / APK…**
2. Boîte de dialogue : sélectionnez **APK** → **Next**.
3. **Keystore (clé de signature)** :
   - **Première fois** → cliquez **Create new…** :
     - **Path** : choisissez un emplacement SÛRE, par ex.
       `C:/cles/christ-libere.jks` (ou `~/cles/christ-libere.jks`) ;
     - **Password / Confirm** : un mot de passe FORT — **notez-le
       précieusement** (ex. dans un gestionnaire de mots de passe) ;
     - **Alias** : `christlibere` ;
     - **Key password** : le même mot de passe (ou un autre, notez-le) ;
     - **Validity** : 25 ans par défaut (laissez — largement suffisant) ;
     - **Certificate** : remplissez au minimum *Name* (Mouvement Christ
       Libère), *Organization* (Mouvement Christ Libère), *Country code*
       (`BJ` pour le Bénin, `CI`… selon le siège).
     - ⚠️ **LA CLÉ EST DÉFINITIVE** : perdue, impossible de publier une mise
       à jour de la même app sur Google Play. Faites une **copie de
       sauvegarde** du fichier `.jks` ET du mot de passe (clé USB + cloud).
   - **Fois suivantes** → **Choose existing…** et reprenez le même `.jks`.
4. **Next** :
   - **Signature versions** : cochez **V1 (Jar Signature)** ET **V2 (Full APK
     Signature)** pour une compatibilité maximale (Android 7 → 15).
5. Sélectionnez **release** → **Finish**.
6. La génération dure 3 à 10 minutes. Un bandeau apparaît en bas à
   droite : cliquez **locate** (ou ouvrez manuellement) :

```
christ-libere-app/build/app/outputs/flutter-apk/app-release.apk
```

### Méthode B — Terminal (plus rapide, la même clé)

```bash
cd christ-libere-app

# APK « universel » (un seul fichier, tous les téléphones)
flutter build apk --release

# ⭐ RECOMMANDÉ — APK découpé par architecture (3 fichiers 3× plus légers ;
#   le TECNO KI5k = arm64-v8a ; partagez arm64-v8a pour les téléphones modernes)
flutter build apk --release --split-per-abi
```

Résultat dans `build/app/outputs/flutter-apk/` :

| Fichier | Pour quels téléphones |
|---|---|
| `app-armeabi-v7a-release.apk` | anciens téléphones 32 bits |
| `app-arm64-v8a-release.apk` | **téléphones modernes 64 bits (TECNO, Samsung, Infinix…) — LE BON CHOIX** |
| `app-x86_64-release.apk` | émulateurs |

> 💡 Avec le terminal, la signature se règle une seule fois dans le
> fichier `android/key.properties` + `android/app/build.gradle` (voir
> annexe A). Sinon la méthode A (assistant Android Studio) demande la
> clé à chaque génération.

### Installer l'APK sur un téléphone

1. Copiez `app-arm64-v8a-release.apk` sur le téléphone (WhatsApp « Document »,
   clé USB, ou téléchargement direct).
2. Sur le téléphone, ouvrez le fichier → **Paramètres → Autoriser cette
   source** (une fois) → **Installer**.
3. L'icône **Christ Libère** (logo officiel) apparaît sur l'écran d'accueil.

> ⚠️ Les notifications push (FCM) exigent les `--dart-define` Firebase
> documentés dans le README § V1.4 — sans eux, l'app fonctionne
> intégralement mais sans push application fermée.

---

## ⑤ GÉNÉRER L'AAB (publication Google Play Store)

> Google Play **exige** le format AAB (.aab). Il est signé par Google et
> adapte automatiquement l'app à chaque téléphone.

1. Menu **Build → Generate Signed Bundle / APK…**
2. Sélectionnez **Android App Bundle** → **Next**.
3. Keystore : le MÊME que pour l'APK (`Create new…` la première fois,
   `Choose existing…` ensuite — cf. ④-A, étape 3).
4. **Next** → cochez **V2** → **release** → **Finish**.
5. Fichier produit :

```
christ-libere-app/build/app/outputs/bundle/release/app-release.aab
```

Ou en terminal :

```bash
flutter build appbundle --release
```

### Publier sur Google Play (résumé)

1. Créez un **compte développeur** : https://play.google.com/console
   (frais uniques de 25 USD — carte ou Mobile Money converti selon région).
2. **Créer une application** → nom : **Christ Libère**, langue : Français,
   catégorie : `Social` ou `Lifestyle` (application religieuse/communauté).
3. Onglet **Publication → Production** → **Créer une version** :
   - importez `app-release.aab` ;
   - notes de version en français (ex. « V2.0 — application complète du
     ministère : accueil, enseignements, témoignages, vidéos, Bible,
     messagerie hors ligne »).
4. Renseignez les **fiches du store** : description, captures d'écran
   (prenez-les depuis le téléphone avec l'app ouverte), icône (le logo
   officiel déjà intégré au projet `public/app-icons/` du site), classement
   du contenu : **Tous publics / 3+**.
5. **Envoyer pour examen** — Google valide en général en 1 à 7 jours pour
   un premier compte développeur.

> 💡 Si vous préférez tester en interne d'abord : onglet **Test fermé**
   (jusqu'à 100 testeurs par lien) — recommandé avant la production.

---

## ⑥ Mettre à jour l'application après une modification du code

```bash
cd christ-libere-app

# 1. Récupérer la dernière version du code
git pull

# 2. Régénérer l'APK léger (nouvelle clé non nécessaire : la même)
flutter build apk --release --split-per-abi
```

- **APK déjà installé** : installez simplement le nouveau fichier par-dessus
  (mêmes clé et id de package `mouvement.christlibere.yeshuaconnect` →
  données, sessions et base locale conservées).
- **Play Store** : générez l'AAB, créez une nouvelle version dans la
  console, importez, envoyez pour examen.
- ⭐ Pensez à incrémenter le numéro de version dans `pubspec.yaml`
  (ex. `version: 2.0.0+11` → `2.0.1+12`) avant chaque publication.

---

## ⑦ Problèmes fréquents (et solutions)

| Symptôme | Cause | Solution |
|---|---|---|
| `flutter: command not found` | SDK Flutter absent du PATH | Installez Flutter (②) ou rouvrez le terminal après l'installation |
| Gradle télécharge longtemps au premier build | Normal — outils du SDK Android | Laissez finir (10-20 min), une seule fois |
| `Keystore file not found` | Chemin de la clé erroné | Recréez le `.jks` ou corrigez le chemin dans l'assistant |
| L'app installée affiche « erreur réseau » | Pas de connexion OU URL du backend changée | Vérifiez internet ; le backend est `mouvement-christ-libere.vercel.app` (config `lib/core/config/app_config.dart`) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Une ancienne version signée avec une AUTRE clé existe | Désinstallez l'ancienne app, réinstallez |
| L'émulateur est lent | Virtualisation désactivée | Activez VT-x/AMD-V dans le BIOS, ou testez sur téléphone réel |
| Le téléphone n'apparaît pas dans la liste | Débogage USB non activé / pilote manquant (Windows) | Activez le débogage USB ; installez le pilote du fabricant |
| Le build échoue avec une erreur Gradle | Cache Gradle corrompu | Menu **File → Invalidate Caches / Restart** ; ou `cd android && ./gradlew clean` |

---

## Annexe A — Signature permanente (facultatif, pour les pros)

Pour ne plus saisir la clé à chaque build GUI et permettre
`flutter build apk --release` direct :

1. Créez le fichier `android/key.properties` :

```properties
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=christlibere
storeFile=C:/cles/christ-libere.jks
```

2. Dans `android/app/build.gradle`, après la ligne `apply from:` existante,
   ajoutez :

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

puis remplacez le bloc `buildTypes { release { ... } }` par :

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

3. Ajoutez `key.properties` au `.gitignore` (le mot de passe ne doit
   JAMAIS partir sur GitHub).

## Annexe B — Commandes de vérification avant génération

```bash
flutter doctor          # environnement complet (SDK, Android, outils)
flutter analyze         # 0 erreur / 0 avertissement attendu
flutter test            # compile-check de l'arbre Dart complet
```
