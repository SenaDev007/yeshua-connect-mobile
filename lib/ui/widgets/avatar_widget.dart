/// Avatar avec initiales dorées sur fond pourpre — photo réseau si fournie.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallback(),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      );
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
