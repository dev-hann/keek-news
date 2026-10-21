import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/provider/blocked_images_provider.dart';
import 'package:keek_news/utils/image_aspect_resolver.dart';
import 'package:keek_news/utils/long_image.dart';
import 'package:keek_news/widgets/media_action_sheet.dart';
import 'package:keek_news/widgets/media_count_badge.dart';
import 'package:keek_news/widgets/retryable_network_image.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Full-screen image viewer.
///
/// Pages horizontally via [PageView] (swipe or tap left/right thirds). Long
/// images scroll vertically; normal images use [InteractiveViewer] for zoom.
///
/// Deliberately avoids `photo_view` and swipe-down-to-dismiss: a vertical drag
/// recognizer competed with horizontal paging on real touches. Dismiss via the
/// close button or system back gesture.
///
/// Blocked images are removed from the paged list; callers may pass an
/// already-filtered list (feed carousel) or a raw snapshot (comment sheet) —
/// either way the viewer re-filters against the live blocklist. When every
/// page ends up blocked the viewer pops itself.
class ImageViewerView extends ConsumerStatefulWidget {
  const ImageViewerView({
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
  ConsumerState<ImageViewerView> createState() => _ImageViewerViewState();
}

class _ImageViewerViewState extends ConsumerState<ImageViewerView> {
  final TransformationController _transformController =
      TransformationController();
  PageController? _pageController;

  int _currentIndex = 0;
  bool _isZoomed = false;
  final Map<String, double> _aspects = {};
  List<String> _urls = const [];

  @override
  void initState() {
    super.initState();
    _urls = _filterUrls(_blockedUrls(ref.read(blockedImagesProvider)));
    final initial = _urls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _urls.length - 1);
    _currentIndex = initial;
    _pageController = PageController(initialPage: initial);
    _transformController.addListener(_onTransformChanged);
    if (widget.knownAspects != null) {
      _aspects.addAll(widget.knownAspects!);
    }
    for (final url in _urls) {
      _resolveAspect(url);
    }
    if (_urls.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _popIfEmpty());
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  Set<String> _blockedUrls(List<BlockedImage> images) => {
    for (final image in images) image.url,
  };

  List<String> _filterUrls(Set<String> blocked) => blocked.isEmpty
      ? widget.imageUrls
      : widget.imageUrls.where((u) => !blocked.contains(u)).toList();

  void _onBlockedChanged(Set<String> blocked) {
    final urls = _filterUrls(blocked);
    if (urls.length == _urls.length) {
      // Length equality on the same source list implies the same survivors;
      // avoids controller churn on unrelated blocklist writes.
      return;
    }
    setState(() {
      _urls = urls;
      if (urls.isEmpty) {
        _currentIndex = 0;
      } else if (_currentIndex >= urls.length) {
        _currentIndex = urls.length - 1;
      }
    });
    if (urls.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _popIfEmpty());
    } else {
      final target = _currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = _pageController;
        if (!mounted || controller == null || !controller.hasClients) return;
        controller.jumpToPage(target);
      });
    }
  }

  void _popIfEmpty() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _onTransformChanged() {
    final zoomed = _transformController.value.getMaxScaleOnAxis() > 1.0;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _resolveAspect(String url) {
    if (_aspects.containsKey(url)) return;
    ImageAspectResolver.resolve(
      url,
      onResolved: (aspect) {
        if (!mounted) return;
        setState(() => _aspects[url] = aspect);
      },
    );
  }

  bool _isLongImage(int index) {
    if (index < 0 || index >= _urls.length) return false;
    final size = MediaQuery.sizeOf(context);
    final viewportAspect = size.width / size.height;
    final imageAspect = _aspects[_urls[index]];
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
    if (index < 0 || index >= _urls.length) return;
    _pageController!.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.decelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<BlockedImage>>(blockedImagesProvider, (previous, next) {
      if (previous != next) _onBlockedChanged(_blockedUrls(next));
    });
    final multiple = _urls.length > 1;

    final pageView = PageView.builder(
      controller: _pageController,
      itemCount: _urls.length,
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
      onLongPress: () => showMediaActionSheet(
        context,
        target: MediaTarget.image(_urls[_currentIndex]),
      ),
      behavior: HitTestBehavior.opaque,
      child: pageView,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          tooltip: '닫기',
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            body,
            if (multiple)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: MediaCountBadge(
                    text: '${_currentIndex + 1}/${_urls.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
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
    final url = _urls[index];
    if (_isLongImage(index)) {
      // Reserve space below the image equal to the floating page indicator's
      // footprint (offset + indicator height) so the user can scroll the
      // image's bottom edge above the overlay. SafeArea already consumes the
      // system bottom inset, so we only need the indicator's own footprint.
      const bottomReserve = 32 + 32;
      return SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _imageFor(url),
              SizedBox(height: bottomReserve.toDouble()),
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
          foregroundColor: Colors.white,
        );
  }
}
