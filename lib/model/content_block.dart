import 'package:equatable/equatable.dart';

sealed class ContentBlock extends Equatable {
  const ContentBlock();
}

class TextBlock extends ContentBlock {
  const TextBlock(this.text);
  final String text;

  @override
  List<Object?> get props => [text];
}

class ImageBlock extends ContentBlock {
  const ImageBlock({required this.url, this.thumbnailUrl});
  final String url;
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [url, thumbnailUrl];
}

class VideoBlock extends ContentBlock {
  const VideoBlock({
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.isGifConversion = false,
  });
  final String url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final bool isGifConversion;

  @override
  List<Object?> get props => [
    url,
    thumbnailUrl,
    width,
    height,
    isGifConversion,
  ];
}

class HtmlBlock extends ContentBlock {
  const HtmlBlock(this.html);
  final String html;

  @override
  List<Object?> get props => [html];
}
