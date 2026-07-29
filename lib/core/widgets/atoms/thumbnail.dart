import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/widgets/atoms/retryable_network_image.dart';

enum ThumbnailSize { small, medium, large }

class Thumbnail extends StatelessWidget {
  const Thumbnail({
    required this.imageUrl,
    super.key,
    this.size = ThumbnailSize.small,
  });
  final String? imageUrl;
  final ThumbnailSize size;

  double get _dimension => switch (size) {
    ThumbnailSize.small => AppSizes.thumbnailSmall,
    ThumbnailSize.medium => AppSizes.thumbnailMedium,
    ThumbnailSize.large => AppSizes.thumbnailLarge,
  };

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return SizedBox(
        width: _dimension,
        height: _dimension,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.borderRadiusSm,
          ),
          child: Icon(
            Icons.image_outlined,
            size: _dimension * 0.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RetryableNetworkImage(
      imageUrl: imageUrl!,
      width: _dimension,
      height: _dimension,
      fit: BoxFit.cover,
      borderRadius: AppRadius.borderRadiusSm,
    );
  }
}
