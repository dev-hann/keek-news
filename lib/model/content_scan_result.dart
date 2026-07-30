import 'package:equatable/equatable.dart';
import 'package:keek_news/model/content_block.dart';

class ContentScanResult extends Equatable {
  const ContentScanResult({required this.blocks, required this.imageUrls});

  final List<ContentBlock> blocks;
  final List<String> imageUrls;

  @override
  List<Object?> get props => [blocks, imageUrls];
}
