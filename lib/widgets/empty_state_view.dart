import 'package:flutter/material.dart';

import 'package:keek_news/const/app_spacing.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    this.message,
    this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String? message;
  final String? title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTitle = title ?? message ?? '';

    return Center(
      child: Padding(
        padding: AppSpacing.edgeAll24,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            AppSpacing.sbH16,
            Text(
              effectiveTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.sbH8,
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
