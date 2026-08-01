import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:keek_news/service/retry_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RetryableNetworkImage extends StatefulWidget {
  const RetryableNetworkImage({
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 500),
    this.errorIcon = LucideIcons.refreshCw,
    this.placeholderColor,
    this.foregroundColor,
    this.borderRadius,
    this.controller,
    super.key,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int maxAttempts;
  final Duration retryDelay;
  final IconData errorIcon;
  final Color? placeholderColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  final RetryController? controller;

  @override
  State<RetryableNetworkImage> createState() => _RetryableNetworkImageState();
}

class _RetryableNetworkImageState extends State<RetryableNetworkImage> {
  RetryController? _ownedController;
  RetryController? _controller;
  int _lastSeenAttempt = 0;

  RetryController get _effectiveController {
    if (widget.controller != null) return widget.controller!;
    _ownedController ??= RetryController(
      maxAttempts: widget.maxAttempts,
      retryDelay: widget.retryDelay,
    );
    return _ownedController!;
  }

  @override
  void initState() {
    super.initState();
    _controller = _effectiveController;
    _lastSeenAttempt = _controller!.attempt;
    _controller!.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant RetryableNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newController = _effectiveController;
    if (!identical(newController, _controller)) {
      _controller?.removeListener(_onControllerChanged);
      _controller = newController;
      _lastSeenAttempt = _controller!.attempt;
      _controller!.addListener(_onControllerChanged);
    }
    if (oldWidget.imageUrl != widget.imageUrl) {
      _controller!.resetForUrl(widget.imageUrl, currentUrl: oldWidget.imageUrl);
      _lastSeenAttempt = _controller!.attempt;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller!.attempt != _lastSeenAttempt ||
        _controller!.isExhausted ||
        !_controller!.hasError) {
      _lastSeenAttempt = _controller!.attempt;
      setState(() {});
    }
  }

  void _onFailureDetected() {
    if (!mounted) return;
    _controller!.recordFailure();
  }

  void _onManualRetry() {
    _controller!.manualRetry();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mTheme = Theme.of(context);
    final background =
        widget.placeholderColor ?? mTheme.colorScheme.surfaceContainerHighest;
    final foreground =
        widget.foregroundColor ?? theme.colorScheme.mutedForeground;

    final Widget content;
    if (_controller!.isExhausted) {
      content = _RetryErrorView(
        icon: widget.errorIcon,
        foreground: foreground,
        background: background,
        showHint: true,
        onTap: _onManualRetry,
      );
    } else {
      content = CachedNetworkImage(
        key: ValueKey('${widget.imageUrl}#${_controller!.attempt}'),
        imageUrl: widget.imageUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorWidget: (_, __, ___) => _FailureMarker(
          onFailure: _onFailureDetected,
          child: const SizedBox.shrink(),
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }
    return content;
  }
}

class _FailureMarker extends StatefulWidget {
  const _FailureMarker({required this.onFailure, required this.child});

  final VoidCallback onFailure;
  final Widget child;

  @override
  State<_FailureMarker> createState() => _FailureMarkerState();
}

class _FailureMarkerState extends State<_FailureMarker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFailure();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RetryErrorView extends StatelessWidget {
  const _RetryErrorView({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.showHint,
    required this.onTap,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final bool showHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Material(
      color: background,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              if (showHint) ...[
                const SizedBox(height: 4),
                Text(
                  '탭하여 재시도',
                  style: theme.textTheme.small.copyWith(color: foreground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
