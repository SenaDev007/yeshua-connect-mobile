# ⭐ V1.9 — Règles R8 pour l'APK RELEASE allégé (minify + shrinkResources).
#
# Flutter conserve automatiquement le code du moteur et des plugins via
# sa configuration Gradle ; ces règles complètent pour les SDK NATIFS
# lourds embarqués (LiveKit/WebRTC, Agora) qui chargent leurs classes par
# réflexion/JNI et seraient sinon retirés par R8 → plantage à l'exécution.

# ── WebRTC (livekit_client) : classes JNI conservées telles quelles ──
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# ── LiveKit ──
-keep class io.livekit.** { *; }
-dontwarn io.livekit.**

# ── Agora RTC (viewer live + appels, provider alternatif) ──
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# ── Firebase Messaging (notifications push FCM) ──
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── OkHttp/Cronet (transport WebRTC, dio n'est pas concerné : Dart AOT) ──
-dontwarn okhttp3.**
-dontwarn org.conscrypt.**

# ── Symboles de débogage de l'application Dart (stack traces lisibles) ──
-keep class com.example.** { *; }
-keep class mouvement.christlibere.yeshuaconnect.** { *; }
