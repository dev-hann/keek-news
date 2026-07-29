import 'package:flutter/material.dart';
import 'package:happy_news/core/themes/app_elevation.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/core/widgets/atoms/skeleton_box.dart';

class SkeletonFeedCard extends StatelessWidget {
  const SkeletonFeedCard({super.key, this.screenHeight});
  final double? screenHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: isDark ? AppElevation.level0 : AppElevation.level1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          SkeletonBox(
            width: double.infinity,
            height: AppSizes.feedMediaHeight(
              screenHeight ?? MediaQuery.sizeOf(context).height,
            ),
            borderRadius: BorderRadius.zero,
          ),
          _actionRow(),
          _caption(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: AppSpacing.edgeAll12,
      child: Row(
        children: [
          SkeletonBox(
            width: AppSizes.avatarSmall,
            height: AppSizes.avatarSmall,
            borderRadius: BorderRadius.circular(AppSizes.avatarSmall / 2),
          ),
          AppSpacing.sbW12,
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180, height: 12),
                AppSpacing.sbH8,
                SkeletonBox(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow() {
    return const Padding(
      padding: AppSpacing.edgeAll12,
      child: Row(
        children: [
          SkeletonBox(width: AppSizes.iconLarge, height: AppSizes.iconLarge),
          AppSpacing.sbW8,
          SkeletonBox(width: 40, height: 12),
          AppSpacing.sbW16,
          SkeletonBox(width: AppSizes.iconLarge, height: AppSizes.iconLarge),
          Spacer(),
          SkeletonBox(width: 60, height: 12),
        ],
      ),
    );
  }

  Widget _caption() {
    return const Padding(
      padding: AppSpacing.edgeH16V8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: double.infinity, height: 14),
          AppSpacing.sbH8,
          SkeletonBox(width: 200, height: 12),
        ],
      ),
    );
  }
}
