import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_colors.dart';
import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/core/widgets/atoms/retryable_network_image.dart';
import 'package:happy_news/core/widgets/molecules/inline_video_player.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/presentation/screens/image_viewer_screen.dart';

class ContentBlockView extends StatelessWidget {
  const ContentBlockView({
    required this.block,
    required this.allImageUrls,
    super.key,
    this.imageIndex = 0,
  });
  final ContentBlock block;
  final List<String> allImageUrls;
  final int imageIndex;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      TextBlock() => const SizedBox.shrink(),
      HtmlBlock() => const SizedBox.shrink(),
      ImageBlock() => Semantics(
        label: '이미지 ${imageIndex + 1} — 탭하여 전체 화면으로 보기',
        button: true,
        child: _CompactImageThumbnail(
          block: block as ImageBlock,
          allImageUrls: allImageUrls,
        ),
      ),
      VideoBlock() => Semantics(
        label: '동영상',
        button: true,
        child: _CompactVideoThumbnail(block: block as VideoBlock),
      ),
    };
  }
}

class _CompactImageThumbnail extends StatelessWidget {
  const _CompactImageThumbnail({
    required this.block,
    required this.allImageUrls,
  });
  final ImageBlock block;
  final List<String> allImageUrls;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.p8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final idx = allImageUrls.indexOf(block.url);
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ImageViewerScreen(
                imageUrls: allImageUrls,
                initialIndex: idx >= 0 ? idx : 0,
              ),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: AppSizes.imagePlaceholderHeight,
          ),
          child: RetryableNetworkImage(
            imageUrl: block.url,
            fit: BoxFit.cover,
            width: double.infinity,
            borderRadius: AppRadius.borderRadiusMd,
          ),
        ),
      ),
    );
  }
}

class _CompactVideoThumbnail extends StatelessWidget {
  const _CompactVideoThumbnail({required this.block});
  final VideoBlock block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.p8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                backgroundColor: AppColors.mediaSurface,
                appBar: AppBar(backgroundColor: AppColors.mediaSurface),
                body: Center(child: InlineVideoPlayer(block: block)),
              ),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: AppSizes.imagePlaceholderHeight,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (block.thumbnailUrl != null)
                RetryableNetworkImage(
                  imageUrl: block.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  borderRadius: AppRadius.borderRadiusMd,
                  placeholderColor: AppColors.imagePlaceholder,
                )
              else
                _buildPlaceholder(),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.imageViewerOverlay,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(AppSpacing.p8),
                child: const Icon(
                  Icons.play_arrow,
                  size: AppSizes.iconLarge,
                  color: AppColors.imageViewerForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 120,
      color: AppColors.imagePlaceholder,
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: AppColors.imageViewerForegroundMuted,
          size: AppSizes.iconLarge,
        ),
      ),
    );
  }
}
