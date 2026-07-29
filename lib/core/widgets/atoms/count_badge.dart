import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_colors.dart';
import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/themes/app_spacing.dart';

class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.count,
    required this.icon,
    super.key,
    this.color,
    this.fontWeight,
  });
  final int count;
  final IconData icon;
  final Color? color;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconMedium, color: effectiveColor),
        AppSpacing.sbW4,
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: effectiveColor,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}

class RecommendBadge extends StatelessWidget {
  const RecommendBadge({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CountBadge(
      count: count,
      icon: Icons.thumb_up,
      color: AppColors.recommendColor(count, colorScheme),
      fontWeight: AppColors.recommendWeight(count),
    );
  }
}

class CommentBadge extends StatelessWidget {
  const CommentBadge({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return CountBadge(
      count: count,
      icon: Icons.chat_bubble_outline,
      color: Theme.of(context).colorScheme.tertiary,
    );
  }
}

class ViewBadge extends StatelessWidget {
  const ViewBadge({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return CountBadge(
      count: count,
      icon: Icons.remove_red_eye,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class BestBadge extends StatelessWidget {
  const BestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.edgeH8V4,
      decoration: BoxDecoration(
        color: AppColors.recommendColor(100, Theme.of(context).colorScheme),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        'BEST',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
