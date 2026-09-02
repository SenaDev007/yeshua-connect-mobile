/// Tuile d'une conversation (liste) — avatar, titre, dernier message,
/// badge non-lus doré.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/conversation_model.dart';
import 'avatar_widget.dart';
class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String meId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.meId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final conv = conversation;
    final accent = AppColors.typeAccent(conv.type);
    final unread = conv.unreadCount;
    final preview = conv.lastMessagePreview ?? 'Aucun message';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // ── Avatar ──
            AvatarWithPresence(
              photoUrl: conv.isDirect ? conv.otherOf(meId)?.avatarUrl : conv.avatarUrl,
              name: conv.displayName,
              online: conv.isDirect && (conv.otherOf(meId)?.online ?? false),
              size: 50,
            ),
            const SizedBox(width: 12),
            // ── Titre + aperçu ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conv.isDirect)
                        Icon(Icons.lock_outline, size: 13, color: accent)
                      else
                        Icon(_icone(conv.type), size: 14, color: accent),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          conv.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.texte,
                            fontSize: 15.5,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.horodatage(conv.lastMessageAt ?? conv.updatedAt),
                        style: const TextStyle(
                          color: AppColors.texteEteint,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (conv.isLastFromMe(meId)) ...[
                        const Icon(Icons.done_all, size: 13, color: AppColors.or),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          Formatters.apercu(preview, max: 45),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0 ? AppColors.texte : AppColors.texteSecondaire,
                            fontSize: 13,
                            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.or,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: AppColors.nuit,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icone(String type) {
    switch (type) {
      case 'DIRECT':
        return Icons.lock_outline;
      case 'GROUP':
        return Icons.groups_outlined;
      case 'PASTORS':
        return Icons.church_outlined;
      case 'VOICE':
        return Icons.graphic_eq_outlined;
      case 'CHANNEL':
      default:
        return Icons.campaign_outlined;
    }
  }
}
