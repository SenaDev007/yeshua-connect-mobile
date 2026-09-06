/// Avatar avec initiales dorées sur fond pourpre — photo réseau si fournie.
///
/// ⭐ V1.7 — SUPPORT DES DATA-URLS (cause racine « aucune photo de profil
/// ne s'affiche ») : le web stocke les avatars en base64 `data:image/…`
/// (≤ 100 Ko, V2.7) dans PostgreSQL — `CachedNetworkImage` ne sait PAS
/// rendre une data-URL → toutes les photos tombaient en initiales.
/// Désormais : data-URL → `Image.memory` (base64 décodé, mis en cache par
/// le cache d'images Flutter), http(s) → CachedNetworkImage, sinon initiales.
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Décode une data-URL en octets (null si malformée).
Uint8List? octetsDataUrl(String dataUrl) {
  final virgule = dataUrl.indexOf(',');
  if (virgule <= 4) return null;
  final meta = dataUrl.substring(0, virgule); // data:image/jpeg;base64
  if (!meta.startsWith('data:') || !meta.contains('base64')) return null;
  try {
    return base64Decode(dataUrl.substring(virgule + 1));
  } catch (_) {
    return null;
  }
}

/// Vrai si l'URL est une data-URL d'image rendable.
bool estDataUrlImage(String url) =>
    url.startsWith('data:image/') && octetsDataUrl(url) != null;

/// Image universelle : data-URL (base64) OU http(s) — même garde-fou
/// d'erreur (placeholder doré + icône) que CachedNetworkImage.
class ImageUniverselle extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ImageUniverselle({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    if (u.startsWith('data:')) {
      final octets = octetsDataUrl(u);
      if (octets != null) {
        return Image.memory(
          octets,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _erreur(),
        );
      }
      return _erreur();
    }
    return CachedNetworkImage(
      imageUrl: u,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => _erreur(),
      errorWidget: (_, __, ___) => _erreur(),
    );
  }

  Widget _erreur() => Container(
        width: width,
        height: height ?? 64,
        color: AppColors.pourpre,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined,
            color: AppColors.texteEteint, size: (width ?? 48) * 0.3),
      );
}

class AvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;

  const AvatarWidget({super.key, this.photoUrl, required this.name, this.size = 44});

  String get _initiales {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length > 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = (photoUrl ?? '').trim();
    if (photo.isNotEmpty) {
      // ⭐ V1.7 — data-URL (avatars base64 du web) OU http(s) : les deux
      // se rendent désormais (avant : data-URL → erreur → initiales).
      if (photo.startsWith('data:image/') || photo.startsWith('http')) {
        return ClipOval(
          child: ImageUniverselle(
            url: photo,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.pourpreClair,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _initiales,
          style: TextStyle(
            color: AppColors.or,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.34,
            letterSpacing: 0.5,
          ),
        ),
      );
}

/// Avatar + point de présence (vert < 90 s, même fenêtre que le serveur).
class AvatarWithPresence extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final bool online;
  final double size;

  const AvatarWithPresence({
    super.key,
    this.photoUrl,
    required this.name,
    required this.online,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarWidget(photoUrl: photoUrl, name: name, size: size),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: const BoxDecoration(
                color: AppColors.enLigne,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.nuit, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
