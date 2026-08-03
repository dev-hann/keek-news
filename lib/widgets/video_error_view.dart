import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Color _kVideoErrorBackground = Color(0xFF1a1a1a);
const Color _kVideoErrorForeground = Colors.white54;
const TextStyle _kVideoErrorMessageStyle = TextStyle(
  color: _kVideoErrorForeground,
  fontSize: 12,
);

/// Error state shown inside a video surface when the underlying controller
/// failed to initialize or recover.
///
/// When [onRetry] is non-null, the whole surface becomes tappable and a hint
/// is shown, mirroring the recovery idiom used by RetryableNetworkImage so
/// images and videos share one retry pattern.
class VideoErrorView extends StatelessWidget {
  const VideoErrorView({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          LucideIcons.alertCircle,
          color: _kVideoErrorForeground,
          size: 32,
        ),
        const SizedBox(height: 8),
        const Text('동영상을 불러올 수 없습니다', style: _kVideoErrorMessageStyle),
        if (onRetry != null) ...[
          const SizedBox(height: 4),
          const Text('탭하여 재시도', style: _kVideoErrorMessageStyle),
        ],
      ],
    );

    if (onRetry == null) {
      return ColoredBox(
        color: _kVideoErrorBackground,
        child: Center(child: body),
      );
    }
    return Material(
      color: _kVideoErrorBackground,
      child: InkWell(
        onTap: onRetry,
        child: Center(child: body),
      ),
    );
  }
}
