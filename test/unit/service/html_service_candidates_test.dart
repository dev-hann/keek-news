import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/content_scan_result.dart';
import 'package:keek_news/service/dio_html_service.dart';
import 'package:keek_news/service/html_service.dart';

/// Minimal HtmlService that exposes only the multi-candidate helpers so the
/// fallback chain can be exercised without dragging in networking or
/// fixtures. The bodies mirror [DioHtmlService] for these methods.
class _CandidateOnlyService extends HtmlService {
  @override
  Future<String> get(String path) async => '';

  @override
  int extractNumber(String? text) {
    if (text == null) return 0;
    final digits = text.replaceAll(RegExp('[^0-9]'), '');
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
  int statOfAny(dom.Element? parent, Iterable<String> selectors) {
    if (parent == null) return 0;
    for (final s in selectors) {
      final value = extractNumber(textOf(parent.querySelector(s)));
      if (value != 0) return value;
    }
    return 0;
  }

  @override
  dom.Element? queryFirst(dom.Element? root, Iterable<String> selectors) {
    if (root == null) return null;
    for (final s in selectors) {
      final hit = root.querySelector(s);
      if (hit != null) return hit;
    }
    return null;
  }

  @override
  String textOfAny(dom.Element? root, Iterable<String> selectors) =>
      textOf(queryFirst(root, selectors));

  @override
  String? attrOfAny(
    dom.Element? root,
    Iterable<({String selector, String attr})> pairs,
  ) {
    if (root == null) return null;
    for (final p in pairs) {
      for (final el in root.querySelectorAll(p.selector)) {
        final v = el.attributes[p.attr];
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  @override
  ContentScanResult scanContent(dom.Element container) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  ContentScanResult scanContentFull(dom.Document doc, dom.Element contentEl) =>
      const ContentScanResult(blocks: [], imageUrls: []);

  @override
  List<ContentBlock> scanContentCompact(dom.Element container) => const [];
}

dom.Element _root(String html) =>
    html_parser.parse(html).body ?? dom.Element.tag('body');

void main() {
  final service = _CandidateOnlyService();

  group('queryFirst — fallback chain', () {
    test('returns null when root is null', () {
      expect(service.queryFirst(null, const ['.x', '.y']), isNull);
    });

    test('returns null when every candidate misses', () {
      final root = _root('<div><p class="a">1</p></div>');
      expect(service.queryFirst(root, const ['.x', '.y', '.z']), isNull);
    });

    test('returns the first hit, skipping leading misses', () {
      final root = _root('<div><p class="a">1</p><p class="b">2</p></div>');
      final hit = service.queryFirst(root, const ['.miss', '.b', '.a']);
      expect(hit?.text, '2');
    });
  });

  group('textOfAny — first non-empty wins', () {
    test('empty when all selectors miss', () {
      expect(service.textOfAny(_root('<div></div>'), const ['.x', '.y']), '');
    });

    test('skips leading misses and trims the hit', () {
      final root = _root('<div><span>  hello  </span></div>');
      expect(service.textOfAny(root, const ['.miss', 'span', 'div']), 'hello');
    });
  });

  group('statOfAny — first non-zero wins', () {
    test('zero when parent is null', () {
      expect(service.statOfAny(null, const ['.x']), 0);
    });

    test('zero when every candidate resolves to 0', () {
      final root = _root('<div><p>0</p><p>0</p></div>');
      expect(service.statOfAny(root, const ['p', 'p']), 0);
    });

    test('skips leading zero candidates and returns the first non-zero', () {
      final root = _root(
        '<div><p class="zero">0</p><p class="hit">42</p><p class="later">1</p></div>',
      );
      expect(service.statOfAny(root, const ['.zero', '.hit', '.later']), 42);
    });

    test('extracts digits from noisy text', () {
      final root = _root('<div><span>추천 (1,234)</span></div>');
      expect(service.statOfAny(root, const ['span']), 1234);
    });
  });

  group('attrOfAny — first non-empty attribute wins', () {
    test('null when root is null', () {
      expect(
        service.attrOfAny(null, const [(selector: '.x', attr: 'href')]),
        isNull,
      );
    });

    test('null when every pair misses', () {
      final root = _root('<div><a></a></div>');
      expect(
        service.attrOfAny(root, const [
          (selector: 'a', attr: 'href'),
          (selector: '.x', attr: 'data-id'),
        ]),
        isNull,
      );
    });

    test('returns first non-empty attribute across pairs', () {
      final root = _root(
        '<div><a href="">empty</a><a href="/r/42">hit</a></div>',
      );
      expect(
        service.attrOfAny(root, const [
          (selector: '.miss', attr: 'href'),
          (selector: 'a', attr: 'href'),
        ]),
        '/r/42',
      );
    });
  });
}
