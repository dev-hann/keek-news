import 'package:flutter/foundation.dart';

@immutable
class VideoId {
  const VideoId({required this.postId, required this.blockIndex});
  final int postId;
  final int blockIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoId &&
          postId == other.postId &&
          blockIndex == other.blockIndex;

  @override
  int get hashCode => Object.hash(postId, blockIndex);
}
