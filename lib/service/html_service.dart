import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/url_builder.dart';
import 'package:keek_news/service/media_classifier.dart';
import 'package:keek_news/service/media_dedup.dart';

abstract class HtmlService {
  Future<String> get(String path);

  int extractNumber(String? text);

  String textOf(Element? element);

  String? attrOf(Element? element, String name);

  int statOf(Element? parent, String selector);

  int extractBracketedInt(String? text) {
    if (text == null) return 0;
    final match = RegExp(r'\[(\d+)\]').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  String? extractQueryParam(String href, String key) {
    final match = RegExp('$key=([^&#]+)').firstMatch(href);
    return match?.group(1);
  }

  int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  ContentScanResult scanContent(Element container);

  ContentScanResult scanContentFull(Document doc, Element contentEl);

  List<ContentBlock> scanContentCompact(Element container);

  List<String> collectImageUrls(
    Element? content, {
    required CommunityId community,
    bool Function(String src)? includeFilter,
  }) {
    if (content == null) return const [];
    return content
        .querySelectorAll('img')
        .map((img) => img.attributes['src'] ?? '')
        .where((src) => src.isNotEmpty)
        .where(includeFilter ?? (_) => true)
        .map((src) => UrlBuilder.resolveAbsolute(community, src))
        .where(MediaClassifier.isLoadableImage)
        .toList();
  }

  List<ContentBlock> buildContentBlocks(
    Iterable<Element> blockEls,
    ContentBlockConfig config, {
    String? fallbackText,
  }) {
    final blocks = <ContentBlock>[];
    final seenVideoKeys = <String>{};

    for (final el in blockEls) {
      final videos = <Element>[
        if (el.localName == 'video') el,
        ...el.querySelectorAll('video'),
      ];
      if (videos.isNotEmpty) {
        for (final video in videos) {
          if (_addVideoBlock(blocks, video, seenVideoKeys, config)) break;
        }
        continue;
      }

      final imgs = <Element>[
        if (el.localName == 'img') el,
        ...el.querySelectorAll('img'),
      ];
      if (imgs.isNotEmpty) {
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          if (src.isEmpty) continue;
          if (config.isUiAsset != null && config.isUiAsset!(src)) continue;
          final url = config.resolveImageUrls
              ? UrlBuilder.resolveAbsolute(config.community, src)
              : src;
          blocks.add(ImageBlock(url: url));
        }
      } else {
        final text = el.text.trim();
        if (text.isNotEmpty && _isAcceptableText(text, config)) {
          blocks.add(TextBlock(text));
        }
      }
    }

    if (blocks.isEmpty &&
        fallbackText != null &&
        fallbackText.trim().isNotEmpty) {
      blocks.add(TextBlock(fallbackText.trim()));
    }
    return blocks;
  }

  bool _addVideoBlock(
    List<ContentBlock> blocks,
    Element video,
    Set<String> seenKeys,
    ContentBlockConfig config,
  ) {
    String? mp4Src;
    final directSrc = video.attributes['src'] ?? '';
    if (directSrc.isNotEmpty && directSrc.contains('.mp4')) {
      mp4Src = directSrc;
    } else {
      for (final source in video.querySelectorAll('source')) {
        final src = source.attributes['src'] ?? '';
        if (src.isNotEmpty && src.contains('.mp4')) {
          mp4Src = src;
          break;
        }
      }
    }
    if (mp4Src == null) return false;

    final full = UrlBuilder.resolveAbsolute(config.community, mp4Src);
    final key = config.dedupStrategy == DedupStrategy.filenameKey
        ? MediaDedup.filenameKey(full)
        : full;
    if (!seenKeys.add(key)) return false;

    final poster = video.attributes['poster'] ?? '';
    blocks.add(
      VideoBlock(
        url: full,
        thumbnailUrl: poster.isNotEmpty
            ? UrlBuilder.resolveAbsolute(config.community, poster)
            : null,
      ),
    );
    return true;
  }

  bool _isAcceptableText(String text, ContentBlockConfig config) {
    if (config.skipBrowserText) {
      if (text.contains('browser does not support')) return false;
      if (text.contains('브라우저')) return false;
    }
    if (config.skipNbsp && text == '\u00a0') return false;
    return true;
  }

  ({String text, List<ContentBlock> media}) parseFragmentMemo(
    String html, {
    required CommunityId community,
    bool preserveBreaks = false,
  }) {
    if (html.isEmpty) return (text: '', media: const []);
    final processed = preserveBreaks
        ? html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        : html;
    final frag = parseFragment(processed);
    final media = <ContentBlock>[];
    for (final img in frag.querySelectorAll('img')) {
      final src = img.attributes['src'] ?? '';
      if (src.isEmpty) continue;
      media.add(ImageBlock(url: UrlBuilder.resolveAbsolute(community, src)));
    }
    var text = (frag.text ?? '').replaceAll('\u00a0', ' ');
    if (preserveBreaks) {
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }
    return (text: text.trim(), media: media);
  }
}

enum DedupStrategy { filenameKey, exactUrl }

class ContentBlockConfig {
  const ContentBlockConfig({
    required this.community,
    this.isUiAsset,
    this.dedupStrategy = DedupStrategy.filenameKey,
    this.resolveImageUrls = true,
    this.skipBrowserText = true,
    this.skipNbsp = false,
  });
  final CommunityId community;
  final bool Function(String)? isUiAsset;
  final DedupStrategy dedupStrategy;
  final bool resolveImageUrls;
  final bool skipBrowserText;
  final bool skipNbsp;
}
