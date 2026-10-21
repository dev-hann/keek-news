import 'package:equatable/equatable.dart';

/// An image the user blocked from the long-press media action sheet.
///
/// Identity is the canonical URL the parsers produce (post-rewrite); matching
/// elsewhere is exact-URL comparison.
class BlockedImage extends Equatable {
  const BlockedImage({required this.url, required this.blockedAt});

  factory BlockedImage.fromJson(Map<String, dynamic> json) => BlockedImage(
    url: json['url'] as String,
    blockedAt: DateTime.fromMillisecondsSinceEpoch(
      json['blockedAtMillis'] as int,
    ),
  );

  final String url;
  final DateTime blockedAt;

  Map<String, dynamic> toJson() => {
    'url': url,
    'blockedAtMillis': blockedAt.millisecondsSinceEpoch,
  };

  @override
  List<Object?> get props => [url, blockedAt];
}
