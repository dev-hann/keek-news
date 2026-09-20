import 'package:flutter/services.dart';
import 'package:keek_news/model/media_target.dart';

class CopyMediaUrlUseCase {
  const CopyMediaUrlUseCase();

  Future<void> call(MediaTarget target) async {
    await Clipboard.setData(ClipboardData(text: target.url));
  }
}
