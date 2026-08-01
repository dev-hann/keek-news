import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/service/html_service.dart';
import 'package:keek_news/utils/media_classifier.dart';

class DioHtmlService extends HtmlService {
  DioHtmlService({required Dio dio, required String encoding})
    : _dio = dio,
      _encoding = encoding;

  final Dio _dio;
  final String _encoding;

  @override
  Future<String> get(String path) async {
    try {
      final response = await _dio.get<List<int>>(path);
      final bytes = response.data ?? <int>[];
      return CharsetConverter.decode(_encoding, Uint8List.fromList(bytes));
    } on DioException catch (e) {
      throw _toFailure(e);
    }
  }

  Failure _toFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(e.message ?? e.type.name);
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.unknown:
        return ServerFailure(e.message ?? e.type.name);
    }
  }

  @override
  int extractNumber(String? text) {
    if (text == null) return 0;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  @override
  String textOf(dom.Element? element) => element?.text.trim() ?? '';

  @override
  String? attrOf(dom.Element? element, String name) =>
      element?.attributes[name];

  @override
  int statOf(dom.Element? parent, String selector) {
    if (parent == null) return 0;
    return extractNumber(textOf(parent.querySelector(selector)));
  }

  @override
  ContentScanResult scanContent(dom.Element container) {
    final blocks = <ContentBlock>[];
    final seenKeys = <String>{};
    final imageUrls = <String>[];
    _walkNodes(container.nodes, blocks, seenKeys, imageUrls);
    return ContentScanResult(blocks: blocks, imageUrls: imageUrls);
  }

  @override
  ContentScanResult scanContentFull(dom.Document doc, dom.Element contentEl) {
    final blocks = <ContentBlock>[];
    final seenKeys = <String>{};
    final imageUrls = <String>[];

    _walkNodes(contentEl.nodes, blocks, seenKeys, imageUrls);

    final allDownloadLinks = doc.querySelectorAll(
      'a[href*="download.php?url="]',
    );
    for (final link in allDownloadLinks) {
      if (contentEl.contains(link)) continue;

      final href = link.attributes['href'] ?? '';
      final match = RegExp(
        r'download\.php\?url=(https?://[^&]+)',
      ).firstMatch(href);
      if (match == null) continue;

      final rawUrl = _normalizeUrl(match.group(1)!);
      if (!seenKeys.add(_dedupKey(rawUrl))) continue;

      final mediaType = MediaClassifier.classify(rawUrl);
      final thumbImg = link.querySelector('img');
      final thumbSrc = thumbImg?.attributes['src'] ?? '';
      final thumb = thumbSrc.isNotEmpty ? _normalizeUrl(thumbSrc) : null;

      switch (mediaType) {
        case MediaType.image:
          blocks.add(ImageBlock(url: rawUrl, thumbnailUrl: thumb));
          imageUrls.add(rawUrl);
        case MediaType.video:
          blocks.add(VideoBlock(url: rawUrl, thumbnailUrl: thumb));
        default:
          break;
      }
    }

    final mp4Divs = doc.querySelectorAll('[onclick*="comment_mp4_expand"]');
    for (final div in mp4Divs) {
      if (contentEl.contains(div)) continue;
      final onclick = div.attributes['onclick'] ?? '';
      final m = RegExp(
        r"comment_mp4_expand\('[^']*',\s*'([^']+)'",
      ).firstMatch(onclick);
      if (m != null) {
        final url = _normalizeUrl(m.group(1)!);
        if (seenKeys.add(_dedupKey(url))) {
          blocks.add(VideoBlock(url: url));
        }
      }
    }

    return ContentScanResult(blocks: blocks, imageUrls: imageUrls);
  }

  @override
  List<ContentBlock> scanContentCompact(dom.Element container) {
    final urls = <_UrlEntry>[];
    _collectUrlsRecursive(container, urls);

    final blocks = <ContentBlock>[];
    final seenKeys = <String>{};

    for (final entry in urls) {
      final rawUrl = _normalizeUrl(entry.url);
      if (!seenKeys.add(_dedupKey(rawUrl))) continue;

      final unwrapped = MediaClassifier.unwrapDownloadPhp(rawUrl) ?? rawUrl;
      final normalized = _normalizeUrl(unwrapped);
      final mediaType = MediaClassifier.classify(normalized);

      switch (mediaType) {
        case MediaType.image:
          blocks.add(
            ImageBlock(
              url: normalized,
              thumbnailUrl: entry.thumbUrl != null
                  ? _normalizeUrl(entry.thumbUrl!)
                  : null,
            ),
          );
        case MediaType.video:
          blocks.add(
            VideoBlock(
              url: normalized,
              thumbnailUrl: entry.thumbUrl != null
                  ? _normalizeUrl(entry.thumbUrl!)
                  : null,
            ),
          );
        case MediaType.youtube:
          final ytId = MediaClassifier.extractYoutubeId(normalized)!;
          blocks.add(
            VideoBlock(
              url: 'https://www.youtube.com/watch?v=$ytId',
              thumbnailUrl: 'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
            ),
          );
        default:
          break;
      }
    }

    return blocks;
  }

  static String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    var normalized = url.trim();
    if (normalized.startsWith('//')) {
      normalized = 'https:$normalized';
    }
    while (normalized.contains(':///')) {
      normalized = normalized.replaceFirst(':///', '://');
    }
    normalized = normalized.replaceAllMapped(RegExp('(?<!:)/{2,}'), (m) => '/');
    return normalized;
  }

  void _walkNodes(
    List<dom.Node> nodes,
    List<ContentBlock> blocks,
    Set<String> seenKeys,
    List<String> imageUrls,
  ) {
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          blocks.add(TextBlock(text));
        }
      } else if (node is dom.Element) {
        _scanElement(node, blocks, seenKeys, imageUrls);
      }
    }
  }

  void _scanElement(
    dom.Element el,
    List<ContentBlock> blocks,
    Set<String> seenKeys,
    List<String> imageUrls,
  ) {
    if (_isNoiseElement(el)) return;

    final extracted = _extractUrlsFromElement(el);
    if (extracted.isNotEmpty) {
      for (final entry in extracted) {
        final rawUrl = _normalizeUrl(entry.url);
        if (!seenKeys.add(_dedupKey(rawUrl))) continue;

        final unwrapped = MediaClassifier.unwrapDownloadPhp(rawUrl) ?? rawUrl;
        final normalized = _normalizeUrl(unwrapped);
        final mediaType = MediaClassifier.classify(normalized);
        final thumb = entry.thumbUrl != null
            ? _normalizeUrl(entry.thumbUrl!)
            : null;

        switch (mediaType) {
          case MediaType.image:
            blocks.add(ImageBlock(url: normalized, thumbnailUrl: thumb));
            imageUrls.add(normalized);
          case MediaType.video:
            blocks.add(VideoBlock(url: normalized, thumbnailUrl: thumb));
          case MediaType.audio:
            blocks.add(HtmlBlock('<a href="$normalized">$normalized</a>'));
          case MediaType.youtube:
            final ytId = MediaClassifier.extractYoutubeId(normalized)!;
            blocks.add(
              VideoBlock(
                url: 'https://www.youtube.com/watch?v=$ytId',
                thumbnailUrl: 'https://img.youtube.com/vi/$ytId/hqdefault.jpg',
              ),
            );
          case MediaType.link:
            final linkText = entry.text ?? normalized;
            blocks.add(
              HtmlBlock('<a href="$normalized" target="_blank">$linkText</a>'),
            );
          case MediaType.unknown:
            break;
        }
      }
      _walkNodes(el.nodes, blocks, seenKeys, imageUrls);
      return;
    }

    if (el.localName == 'video' || el.querySelector('video') != null) {
      final videoEl = el.localName == 'video' ? el : el.querySelector('video')!;
      final block = _parseVideoElement(videoEl);
      if (block != null) {
        final normalized = _normalizeUrl(block.url);
        if (seenKeys.add(_dedupKey(normalized))) {
          blocks.add(block);
        }
      }
      return;
    }

    if (el.nodes.isEmpty || _isSimpleTextElement(el)) {
      final text = el.text.trim();
      if (text.isNotEmpty) {
        blocks.add(TextBlock(text));
      }
      return;
    }

    if (_isRichMixedContent(el)) {
      final innerHtml = el.innerHtml.trim();
      if (innerHtml.isNotEmpty) {
        blocks.add(HtmlBlock(innerHtml));
      }
      return;
    }

    _walkNodes(el.nodes, blocks, seenKeys, imageUrls);
  }

  List<_UrlEntry> _extractUrlsFromElement(dom.Element el) {
    final entries = <_UrlEntry>[];

    if (el.localName == 'img') {
      final src = el.attributes['src'] ?? '';
      if (src.isNotEmpty && !src.contains('/images/')) {
        final url = el.attributes['img_file_url'] ?? src;
        if (url.isNotEmpty) {
          entries.add(_UrlEntry(url: url, thumbUrl: src != url ? src : null));
        }
      }
      return entries;
    }

    if (el.localName == 'a') {
      final href = el.attributes['href'] ?? '';
      if (href.contains('download.php?url=')) {
        final match = RegExp(
          r'download\.php\?url=(https?://[^&]+)',
        ).firstMatch(href);
        if (match != null) {
          final innerUrl = match.group(1)!;
          final thumbImg = el.querySelector('img');
          entries.add(
            _UrlEntry(url: innerUrl, thumbUrl: thumbImg?.attributes['src']),
          );
        }
        return entries;
      }
      if (href.startsWith('http')) {
        final text = el.text.trim();
        if (text.isNotEmpty && href != text) {
          entries.add(_UrlEntry(url: href, text: text));
        } else if (text.isEmpty) {
          entries.add(_UrlEntry(url: href));
        }
      }
      return entries;
    }

    final imgs = el.querySelectorAll('img');
    for (final img in imgs) {
      final src = img.attributes['src'] ?? '';
      if (src.isEmpty || src.contains('/images/')) continue;
      final url = img.attributes['img_file_url'] ?? src;
      if (url.isNotEmpty) {
        entries.add(_UrlEntry(url: url, thumbUrl: src != url ? src : null));
      }
    }

    final downloadLinks = el.querySelectorAll('a[href*="download.php?url="]');
    for (final link in downloadLinks) {
      final href = link.attributes['href'] ?? '';
      final match = RegExp(
        r'download\.php\?url=(https?://[^&]+)',
      ).firstMatch(href);
      if (match != null) {
        final innerUrl = match.group(1)!;
        final thumbImg = link.querySelector('img');
        entries.add(
          _UrlEntry(url: innerUrl, thumbUrl: thumbImg?.attributes['src']),
        );
      }
    }

    final onclick = el.attributes['onclick'] ?? el.attributes['OnClick'] ?? '';
    if (onclick.contains('comment_mp4_expand')) {
      final mp4Match = RegExp(
        r"comment_mp4_expand\('[^']*',\s*'([^']+)'",
      ).firstMatch(onclick);
      if (mp4Match != null) {
        entries.add(_UrlEntry(url: mp4Match.group(1)!));
      }
    }

    final anchors = el.querySelectorAll('a.autolink, span.autolink a');
    for (final anchor in anchors) {
      final href = anchor.attributes['href'] ?? '';
      if (href.startsWith('http')) {
        final text = anchor.text.trim();
        entries.add(_UrlEntry(url: href, text: text.isNotEmpty ? text : null));
      }
    }

    return entries;
  }

  void _collectUrlsRecursive(dom.Element el, List<_UrlEntry> urls) {
    final mp4Entry = _commentMp4Entry(el);
    if (mp4Entry != null) {
      urls.add(mp4Entry);
      return;
    }

    urls.addAll(_extractDirectUrls(el));

    for (final child in el.children) {
      _collectUrlsRecursive(child, urls);
    }
  }

  _UrlEntry? _commentMp4Entry(dom.Element el) {
    final onclick = el.attributes['onclick'] ?? el.attributes['OnClick'] ?? '';
    if (!onclick.contains('comment_mp4_expand')) return null;
    final m = RegExp(
      r"comment_mp4_expand\('[^']*',\s*'([^']+)'",
    ).firstMatch(onclick);
    if (m == null) return null;
    final url = m.group(1)!;

    String? thumb;
    final thumbImg = el.querySelector('img.comment_thumb_img');
    if (thumbImg != null) {
      thumb = thumbImg.attributes['src'];
    } else {
      for (final img in el.querySelectorAll('img')) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty && !src.contains('/images/')) {
          thumb = src;
          break;
        }
      }
    }
    if (thumb != null && thumb.contains('url_enc=')) {
      thumb = null;
    }
    return _UrlEntry(
      url: url,
      thumbUrl: (thumb != null && thumb.isNotEmpty) ? thumb : null,
    );
  }

  List<_UrlEntry> _extractDirectUrls(dom.Element el) {
    final entries = <_UrlEntry>[];

    if (el.localName == 'img') {
      final src = el.attributes['src'] ?? '';
      if (src.isNotEmpty && !src.contains('/images/')) {
        final url = el.attributes['img_file_url'] ?? src;
        if (url.isNotEmpty) {
          entries.add(_UrlEntry(url: url, thumbUrl: src != url ? src : null));
        }
      }
      return entries;
    }

    if (el.localName == 'a') {
      final href = el.attributes['href'] ?? '';
      if (href.contains('download.php?url=')) {
        final match = RegExp(
          r'download\.php\?url=(https?://[^&]+)',
        ).firstMatch(href);
        if (match != null) {
          final innerUrl = match.group(1)!;
          final thumbImg = el.querySelector('img');
          entries.add(
            _UrlEntry(url: innerUrl, thumbUrl: thumbImg?.attributes['src']),
          );
        }
        return entries;
      }
      if (href.startsWith('http')) {
        final text = el.text.trim();
        if (text.isNotEmpty && href != text) {
          entries.add(_UrlEntry(url: href, text: text));
        } else if (text.isEmpty) {
          entries.add(_UrlEntry(url: href));
        }
      }
      return entries;
    }

    return entries;
  }

  VideoBlock? _parseVideoElement(dom.Element video) {
    final source = video.querySelector('source');
    final src = source?.attributes['src'] ?? video.attributes['src'] ?? '';
    if (src.isEmpty || src.startsWith("'") || src.contains('"+')) return null;

    final poster = video.attributes['poster'] ?? '';
    final widthStr = video.attributes['width'];
    final heightStr = video.attributes['height'];

    return VideoBlock(
      url: _normalizeUrl(src),
      thumbnailUrl: poster.isNotEmpty ? _normalizeUrl(poster) : null,
      width: widthStr != null ? int.tryParse(widthStr) : null,
      height: heightStr != null ? int.tryParse(heightStr) : null,
    );
  }

  bool _isNoiseElement(dom.Element el) {
    return el.classes.contains('comment_thumb_notice') ||
        el.classes.contains('comment_crop_href') ||
        el.classes.contains('comment_crop_href_mp4') ||
        el.localName == 'iframe';
  }

  bool _isSimpleTextElement(dom.Element el) {
    final name = el.localName;
    return name == 'p' ||
        name == 'span' ||
        name == 'br' ||
        name == 'a' ||
        name == 'b' ||
        name == 'font' ||
        name == 'strong' ||
        name == 'em';
  }

  bool _isRichMixedContent(dom.Element el) {
    final hasFormatting =
        el.querySelector('b, font, strong, em, span[style], table') != null;
    final hasLinks = el.querySelector('a') != null;
    return hasFormatting && hasLinks;
  }

  String _dedupKey(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.replaceAll(RegExp('/+'), '/').toLowerCase();
    } catch (_) {
      return url.toLowerCase();
    }
  }
}

class _UrlEntry {
  const _UrlEntry({required this.url, this.thumbUrl, this.text});
  final String url;
  final String? thumbUrl;
  final String? text;
}
