import 'package:equatable/equatable.dart';

/// An image the user blocked from the long-press media action sheet.
///
/// Identity is the canonical URL the parsers produce (post-rewrite) plus, when
/// available, a 64-bit dHash fingerprint that survives reposts under new URLs.
/// URL matching is exact; fingerprint matching allows a small Hamming
/// distance.
class BlockedImage extends Equatable {
  const BlockedImage({required this.url, required this.blockedAt, this.hash});

  factory BlockedImage.fromJson(Map<String, dynamic> json) => BlockedImage(
    url: json['url'] as String,
    hash: json['hash'] as String?,
    blockedAt: DateTime.fromMillisecondsSinceEpoch(
      json['blockedAtMillis'] as int,
    ),
  );

  final String url;
  final DateTime blockedAt;

  /// 16-char hex dHash, or null when the bytes were unavailable at block
  /// time (entry then matches by URL only).
  final String? hash;

  Map<String, dynamic> toJson() => {
    'url': url,
    'blockedAtMillis': blockedAt.millisecondsSinceEpoch,
    if (hash != null) 'hash': hash,
  };

  @override
  List<Object?> get props => [url, blockedAt, hash];
}
