import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/themes/app_spacing.dart';

class TextPostCard extends StatelessWidget {
  const TextPostCard({
    required this.title,
    super.key,
    this.secondary,
    this.onTap,
    this.screenHeight,
  });

  final String title;
  final String? secondary;
  final VoidCallback? onTap;
  final double? screenHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final height = AppSizes.feedMediaHeight(
      screenHeight ?? MediaQuery.sizeOf(context).height,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: '게시글 — 탭하여 전체 화면으로 보기',
        button: true,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: ColoredBox(
            color: colorScheme.primary,
            child: Padding(
              padding: AppSpacing.edgeAll16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondary != null) ...[
                    AppSpacing.sbH8,
                    Text(
                      secondary!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.92),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
