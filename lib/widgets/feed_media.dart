import 'package:flutter/material.dart';

import 'package:keek_news/const/app_colors.dart';
import 'package:keek_news/const/app_radius.dart';
import 'package:keek_news/const/app_sizes.dart';
import 'package:keek_news/const/app_spacing.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';

class FeedMedia extends StatelessWidget {
  const FeedMedia({
    required this.imageUrl,
    super.key,
    this.onTap,
    this.additionalImageCount = 0,
    this.screenHeight,
  });
  final String imageUrl;
  final VoidCallback? onTap;
  final int additionalImageCount;
  final double? screenHeight;

  @override
  Widget build(BuildContext context) {
    final height = AppSizes.feedMediaHeight(
      screenHeight ?? MediaQuery.sizeOf(context).height,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: '미디어 — 탭하여 전체 화면으로 보기',
        button: true,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _content(context),
              if (additionalImageCount > 0) _multiBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (imageUrl.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.image_outlined,
          size: AppSizes.iconLarge * 2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return RetryableNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover);
  }

  Widget _multiBadge(BuildContext context) {
    return Positioned(
      top: AppSpacing.p8,
      right: AppSpacing.p8,
      child: Container(
        padding: AppSpacing.edgeH8V4,
        decoration: const BoxDecoration(
          color: AppColors.imageViewerOverlay,
          borderRadius: AppRadius.borderRadiusLg,
        ),
        child: Text(
          '+$additionalImageCount',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.imageViewerForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
