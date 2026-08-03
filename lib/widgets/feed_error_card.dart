import 'package:flutter/material.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/feed_item.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Replaces a FeedCard when its detail failed to load. Stateless — the copy
/// and retry actions are wired by the host page via onCopyTap / onRetryTap
/// (keeps side effects out of the widget, per project convention).
class FeedErrorCard extends StatelessWidget {
  const FeedErrorCard({
    required this.post,
    required this.errorDetail,
    required this.onCopyTap,
    this.onRetryTap,
    super.key,
  });

  final FeedItem post;
  final ErrorPostDetail errorDetail;
  final VoidCallback onCopyTap;

  /// When null, the "다시 시도" button is hidden (e.g. list-level errors with
  /// no per-post retry path).
  final VoidCallback? onRetryTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    final colorScheme = mTheme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _communityLabel(),
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '불러오기 실패 — ${_reason()}',
                      style: mTheme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onRetryTap != null)
                      TextButton.icon(
                        onPressed: onRetryTap,
                        icon: const Icon(LucideIcons.refreshCw, size: 18),
                        label: const Text('다시 시도'),
                      ),
                    TextButton.icon(
                      onPressed: onCopyTap,
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: const Text('오류 정보 복사'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _communityLabel() {
    final c = Community.findById(post.community);
    return c?.displayName ?? post.community.name;
  }

  String _reason() {
    final f = errorDetail.failure;
    if (f is NetworkFailure) return '네트워크 오류';
    if (f is ServerFailure) return '서버 오류';
    if (f is ParseFailure) return '차단 또는 구조 변경 가능성';
    return f.message;
  }
}
