import 'package:flutter/widgets.dart';

abstract final class ImageAspectResolver {
  static void resolve(
    String url, {
    required void Function(double aspect) onResolved,
    VoidCallback? onError,
  }) {
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (info, _) {
        if (listener == null) return;
        onResolved(info.image.width.toDouble() / info.image.height.toDouble());
        stream.removeListener(listener);
      },
      onError: (Object _, StackTrace? __) {
        if (listener != null) stream.removeListener(listener);
        onError?.call();
      },
    );
    stream.addListener(listener);
  }
}
