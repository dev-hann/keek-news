import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Computes 64-bit dHash (difference hash) fingerprints for image URLs.
///
/// The fingerprint survives re-encoding, format conversion (jpg ↔ webp) and
/// rescaling, so the same picture reposted under a new URL still matches.
abstract class ImageHashService {
  /// Returns the 16-char hex fingerprint for [url], or null when the bytes
  /// cannot be fetched or decoded. Results are memoized per URL.
  Future<String?> hashFor(String url);
}

class FlutterImageHashService implements ImageHashService {
  const FlutterImageHashService();

  static const _maxMemoized = 1024;
  static final Map<String, String?> _memo = <String, String?>{};

  @override
  Future<String?> hashFor(String url) async {
    if (_memo.containsKey(url)) return _memo[url];
    final hash = await _hashForUrl(url);
    if (_memo.length >= _maxMemoized) _memo.clear();
    return _memo[url] = hash;
  }

  /// Hamming distance between two hex fingerprints; 64 when unparseable.
  static int distance(String a, String b) {
    final x = int.tryParse(a, radix: 16);
    final y = int.tryParse(b, radix: 16);
    if (x == null || y == null) return 64;
    var diff = x ^ y;
    var count = 0;
    while (diff != 0) {
      diff &= diff - 1;
      count++;
    }
    return count;
  }

  /// Decodes [bytes] to 9×8 grayscale and packs the horizontal gradient into
  /// a 64-bit dHash. Returns null for undecodable input.
  @visibleForTesting
  static Future<String?> dHashFromBytes(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 9,
        targetHeight: 8,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData();
      if (data == null) return null;
      var hash = 0;
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          if (_luma(data, x, y) > _luma(data, x + 1, y)) {
            hash |= 1 << (y * 8 + x);
          }
        }
      }
      return hash.toRadixString(16).padLeft(16, '0');
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static int _luma(ByteData data, int x, int y) {
    final i = (y * 9 + x) * 4;
    final r = data.getUint8(i);
    final g = data.getUint8(i + 1);
    final b = data.getUint8(i + 2);
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }
}

Future<String?> _hashForUrl(String url) async {
  try {
    final file = await DefaultCacheManager().getSingleFile(url);
    final bytes = await file.readAsBytes();
    return await FlutterImageHashService.dHashFromBytes(bytes);
  } catch (_) {
    return null;
  }
}
