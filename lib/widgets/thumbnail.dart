import 'package:flutter/material.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ThumbnailSize { small, medium, large }

class Thumbnail extends StatelessWidget {
  const Thumbnail({
    required this.imageUrl,
    super.key,
    this.size = ThumbnailSize.small,
  });
  final String? imageUrl;
  final ThumbnailSize size;

  static const _smallDim = 48.0;
  static const _mediumDim = 72.0;
  static const _largeDim = 120.0;
  static const _radius = BorderRadius.all(Radius.circular(4));

  double get _dimension => switch (size) {
    ThumbnailSize.small => _smallDim,
    ThumbnailSize.medium => _mediumDim,
    ThumbnailSize.large => _largeDim,
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
            borderRadius: _radius,
          ),
          child: Icon(
            LucideIcons.image,
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
      borderRadius: _radius,
    );
  }
}
