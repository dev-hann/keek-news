import 'package:keek_news/model/blocked_image.dart';

/// Local blocklist of images. [changes] fires after every persisted mutation
/// so Riverpod mirrors can reload without owning the writes.
abstract class BlockedImageRepo {
  Future<List<BlockedImage>> getAll();

  Future<void> add(BlockedImage image);

  Future<void> remove(String url);

  Stream<void> get changes;

  /// Whether [hash] fingerprint-matches any blocked image (small Hamming
  /// distance). Sync so render-time checks never await.
  bool isHashBlocked(String hash);
}
