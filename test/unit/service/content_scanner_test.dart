import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/service/content_scanner.dart';

ContentBlock? _firstImage(Iterable<ContentBlock> blocks) {
  for (final b in blocks) {
    if (b is ImageBlock) return b;
  }
  return null;
}

void main() {
  group('ContentScanner noise filtering', () {
    test('skips 1px spacer images regardless of source path', () {
      final doc = html_parser.parse(
        '<div><img src="https://cdn.example.com/skin/t.gif" width="8" '
        'height="1px"><img src="https://cdn.example.com/real.jpg"></div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final images = result.blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, contains('real.jpg'));
    });

    test('skips spacer-named images without dimensions', () {
      final doc = html_parser.parse(
        '<div><img src="https://cdn.example.com/spacer.gif">'
        '<img src="https://cdn.example.com/photo.webp"></div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final images = result.blocks.whereType<ImageBlock>().toList();
      expect(images, hasLength(1));
      expect(images.first.url, contains('photo.webp'));
    });

    test('prefers data-src over placeholder src for lazy images', () {
      final doc = html_parser.parse(
        '<div><img src="blank.gif" data-src="https://cdn.example.com/a.jpg">'
        '</div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final image = _firstImage(result.blocks);
      expect(image, isNotNull);
      expect(image!.url, 'https://cdn.example.com/a.jpg');
    });

    test('keeps plain src when no lazy attributes exist', () {
      final doc = html_parser.parse(
        '<div><img src="https://cdn.example.com/b.png"></div>',
      );
      final result = ContentScanner.scanContent(doc.body!);

      final image = _firstImage(result.blocks);
      expect(image, isNotNull);
      expect(image!.url, 'https://cdn.example.com/b.png');
    });

    test('link-dense chrome is not emitted as HtmlBlock', () {
      final html = '''
        <div><b><a href="/1">메뉴1</a> <a href="/2">메뉴2</a> '
        <a href="/3">메뉴3</a> <a href="/4">메뉴4</a></b></div>
      ''';
      final doc = html_parser.parse(html);
      final result = ContentScanner.scanContent(doc.body!);

      expect(result.blocks.whereType<HtmlBlock>(), isEmpty);
    });

    test('genuine rich mixed content still becomes HtmlBlock', () {
      final html = '''
        <div><b>본문 강조 텍스트가 충분히 길게 있는 문장입니다. '
        <a href="https://x.com">참고 링크</a> 그리고 마무리 문장.</b></div>
      ''';
      final doc = html_parser.parse(html);
      final result = ContentScanner.scanContent(doc.body!);

      expect(result.blocks.whereType<HtmlBlock>(), isNotEmpty);
    });
  });
}
