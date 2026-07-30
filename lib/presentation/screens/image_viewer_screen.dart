import 'package:flutter/material.dart';

import 'package:happy_news/core/themes/app_colors.dart';
import 'package:happy_news/core/themes/app_durations.dart';
import 'package:happy_news/core/themes/app_radius.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/themes/app_spacing.dart';
import 'package:happy_news/core/utils/long_image.dart';
import 'package:happy_news/core/widgets/atoms/retryable_network_image.dart';

/// Full-screen image viewer.
///
/// Multiple images are paged horizontally with a [PageView]. Paging works two
/// ways, so it is always reachable regardless of device gesture nuance:
///   * **Swipe** left/right between images.
///   * **Tap** the left/right third of the screen to go to the previous/next
///     image (handy for reading long comics: scroll down, tap right to
///     advance).
///
/// Each page picks its interaction model from the image aspect ratio:
///   * **Long** (taller-than-viewport at fit-width) images render in a vertical
///     [SingleChildScrollView] so they can be read by scrolling down — native
///     momentum scrolling, no pinch-zoom.
///   * **Normal** images render in an [InteractiveViewer] for pinch-zoom/pan.
///
/// This deliberately avoids `photo_view` and avoids a swipe-down-to-dismiss
/// [GestureDetector]: a vertical drag recognizer there competed with the
/// [PageView]'s horizontal paging on real touches and made paging unreliable.
/// Dismiss is via the close button or the system back gesture instead.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.imageUrls,
    this.initialIndex = 0,
    this.knownAspects,
    this.imageBuilder,
    super.key,
  });

  /// Image URLs to display. A single item still works (no paging indicator).
  final List<String> imageUrls;

  /// Page shown first.
  final int initialIndex;

  /// Optionally pre-resolved width/height aspects keyed by URL. Callers that
  /// already know image dimensions (e.g. the feed carousel, which sizes by
  /// aspect) may pass them to skip re-resolving here. When absent for a URL,
  /// the viewer resolves it itself.
  final Map<String, double>? knownAspects;

  /// Optional override for the image widget shown for each URL. Defaults to
  /// [Image.network]. Useful for tests to inject deterministic content (e.g. a
  /// tall placeholder to exercise long-image scrolling).
  final Widget Function(String url)? imageBuilder;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late final TransformationController _transformController;

  int _currentIndex = 0;
  bool _isZoomed = false;
  final Map<String, double> _aspects = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformController = TransformationController()
      ..addListener(_onTransformChanged);
    if (widget.knownAspects != null) {
      _aspects.addAll(widget.knownAspects!);
    }
    for (final url in widget.imageUrls) {
      _resolveAspect(url);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final zoomed = _transformController.value.getMaxScaleOnAxis() > 1.0;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _resolveAspect(String url) {
    if (_aspects.containsKey(url)) return;
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!mounted || listener == null) return;
        final aspect =
            info.image.width.toDouble() / info.image.height.toDouble();
        setState(() => _aspects[url] = aspect);
        stream.removeListener(listener);
      },
      onError: (Object _, StackTrace? __) {
        if (listener != null) stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  bool _isLongImage(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return false;
    final size = MediaQuery.sizeOf(context);
    final viewportAspect = size.width / size.height;
    final imageAspect = _aspects[widget.imageUrls[index]];
    if (imageAspect == null) return false;
    return LongImage.fitWidthScale(
          imageAspect: imageAspect,
          viewportAspect: viewportAspect,
        ) !=
        null;
  }

  void _onTapUp(TapUpDetails details) {
    // While zoomed in, let the user interact with the zoomed view instead of
    // paging on tap.
    if (_isZoomed) return;
    final width = MediaQuery.sizeOf(context).width;
    final dx = details.localPosition.dx;
    if (dx < width / 3) {
      _goToPage(_currentIndex - 1);
    } else if (dx > width * 2 / 3) {
      _goToPage(_currentIndex + 1);
    }
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    _pageController.animateToPage(
      index,
      duration: AppDurations.medium,
      curve: AppCurves.decelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.imageUrls.length > 1;

    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: widget.imageUrls.length,
      onPageChanged: (index) => setState(() {
        _currentIndex = index;
        _transformController.value = Matrix4.identity();
      }),
      itemBuilder: (context, index) => _buildPage(index),
    );

    // Tap-to-page overlay. A TapGestureRecognizer loses to drag recognizers in
    // the gesture arena, so swipes (paging) and vertical scroll (long images)
    // still reach the PageView/ScrollView; only clean taps page.
    final body = GestureDetector(
      onTapUp: _onTapUp,
      behavior: HitTestBehavior.opaque,
      child: pageView,
    );

    return Scaffold(
      backgroundColor: AppColors.imageViewerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.imageViewerBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: '닫기',
          icon: const Icon(Icons.close, color: AppColors.imageViewerForeground),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            body,
            if (multiple)
              Positioned(
                bottom: AppSizes.imageViewerIndicatorBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: AppSpacing.edgeH12V6,
                    decoration: const BoxDecoration(
                      color: AppColors.imageViewerOverlay,
                      borderRadius: AppRadius.borderRadiusXl,
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.imageUrls.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.imageViewerForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final url = widget.imageUrls[index];
    if (_isLongImage(index)) {
      // Reserve space below the image equal to the floating page indicator's
      // footprint (offset + indicator height) so the user can scroll the
      // image's bottom edge above the overlay. SafeArea already consumes the
      // system bottom inset, so we only need the indicator's own footprint.
      const bottomReserve =
          AppSizes.imageViewerIndicatorBottom +
          AppSizes.imageViewerIndicatorHeight;
      return SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _imageFor(url),
              const SizedBox(height: bottomReserve),
            ],
          ),
        ),
      );
    }
    return InteractiveViewer(
      transformationController: _transformController,
      maxScale: 4,
      // Pan only once zoomed in; at 1x, single-finger drags fall through to
      // horizontal paging.
      panEnabled: _isZoomed,
      child: Center(child: _imageFor(url)),
    );
  }

  Widget _imageFor(String url) {
    return widget.imageBuilder?.call(url) ??
        RetryableNetworkImage(
          imageUrl: url,
          placeholderColor: Colors.black,
          foregroundColor: AppColors.imageViewerForeground,
        );
  }
}
