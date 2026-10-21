import 'package:flutter/material.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/utils/time_ago.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// One blocked-image row in the management list: thumbnail, blocked-at time,
/// and an unblock action.
class BlockedImageTile extends StatelessWidget {
  const BlockedImageTile({
    required this.image,
    required this.onUnblock,
    super.key,
  });

  final BlockedImage image;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: RetryableNetworkImage(
              imageUrl: image.url,
              fit: BoxFit.cover,
              width: 64,
              height: 64,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TimeAgo.format(image.blockedAt),
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  image.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: '차단 해제',
            child: IconButton(
              tooltip: '차단 해제',
              icon: const Icon(LucideIcons.rotateCcw),
              onPressed: onUnblock,
            ),
          ),
        ],
      ),
    );
  }
}
