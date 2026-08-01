import 'package:flutter/foundation.dart';
import 'package:keek_news/model/video_id.dart';

abstract class VideoPlaybackController {
  ValueListenable<VideoId?> get activeVideo;

  void setActive(VideoId id);
}

class ValueNotifierVideoPlaybackController implements VideoPlaybackController {
  ValueNotifierVideoPlaybackController(this._active, this._onSetActive);

  final ValueNotifier<VideoId?> _active;
  final void Function(VideoId) _onSetActive;

  @override
  ValueListenable<VideoId?> get activeVideo => _active;

  @override
  void setActive(VideoId id) {
    if (_active.value == id) return;
    _onSetActive(id);
    _active.value = id;
  }
}
