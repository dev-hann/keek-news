import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/link_text.dart';

import '../../helpers/shad_harness.dart';

/// Text.rich merges the default style as an extra root span, so link spans
/// sit at arbitrary depth — collect them recursively.
Iterable<TextSpan> _allSpans(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* _allSpans(child);
  }
}

TextSpan _rootSpanOf(RichText rich) => rich.text as TextSpan;

void main() {
  group('parseLinkSegments', () {
    test('plain text without URLs yields a single text segment', () {
      final segments = parseLinkSegments('그냥 본문 텍스트입니다.');
      expect(segments, hasLength(1));
      expect(segments.single.text, '그냥 본문 텍스트입니다.');
      expect(segments.single.isLink, isFalse);
    });

    test('http and https URLs become link segments', () {
      final segments = parseLinkSegments('보세요 https://example.com/a?x=1 감사');
      expect(segments, hasLength(3));
      expect(segments[0].text, '보세요 ');
      expect(segments[1].isLink, isTrue);
      expect(segments[1].text, 'https://example.com/a?x=1');
      expect(segments[1].url, 'https://example.com/a?x=1');
      expect(segments[2].text, ' 감사');
    });

    test('www. URLs get an https scheme in url but keep display text', () {
      final segments = parseLinkSegments('www.example.com/page');
      expect(segments.single.isLink, isTrue);
      expect(segments.single.text, 'www.example.com/page');
      expect(segments.single.url, 'https://www.example.com/page');
    });

    test('trailing punctuation stays out of the link', () {
      final segments = parseLinkSegments('링크 https://example.com/a.).');
      final link = segments.where((s) => s.isLink).single;
      expect(link.text, 'https://example.com/a');
      expect(segments.last.text, '.).');
    });

    test('multiple URLs split into separate segments', () {
      final segments = parseLinkSegments('https://a.com/1 그리고 www.b.com/2');
      final links = segments.where((s) => s.isLink).toList();
      expect(links, hasLength(2));
      expect(links[0].url, 'https://a.com/1');
      expect(links[1].url, 'https://www.b.com/2');
    });

    test('empty string yields no segments', () {
      expect(parseLinkSegments(''), isEmpty);
    });
  });

  group('LinkText widget', () {
    testWidgets('renders url text content', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const SingleChildScrollView(
            child: LinkText('여기 https://example.com/go 확인'),
          ),
        ),
      );

      expect(find.byType(RichText), findsOneWidget);
      final rich = tester.widget<RichText>(find.byType(RichText));
      final span = rich.text as TextSpan;
      expect(span.toPlainText(), '여기 https://example.com/go 확인');
    });

    testWidgets('tapping a url launches the in-app browser', (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      String? launchedUrl;
      String? launchedMethod;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        launchedMethod = call.method;
        final args = call.arguments;
        if (args is Map) launchedUrl = args['url'] as String?;
        return true;
      });

      await tester.pumpWidget(
        shadHarness(
          const SingleChildScrollView(
            child: LinkText('보기 www.example.com/x 열기'),
          ),
        ),
      );

      final rich = tester.widget<RichText>(find.byType(RichText));
      final spans = _allSpans(_rootSpanOf(rich)).toList();
      final linkSpan = spans.firstWhere((s) => s.recognizer != null);
      expect(linkSpan.text, 'www.example.com/x');

      final recognizer = linkSpan.recognizer! as TapGestureRecognizer;
      recognizer.onTap!();
      await tester.pump();
      await tester.pump();

      expect(launchedMethod, anyOf('launchUrl', 'launch'));
      expect(launchedUrl, 'https://www.example.com/x');
    });

    testWidgets('text change rebuilds recognizers without leaking', (
      tester,
    ) async {
      await tester.pumpWidget(
        shadHarness(
          const SingleChildScrollView(child: LinkText('a https://a.com/1')),
        ),
      );
      await tester.pumpWidget(
        shadHarness(
          const SingleChildScrollView(child: LinkText('b www.b.com/2')),
        ),
      );

      final rich = tester.widget<RichText>(find.byType(RichText));
      expect(rich.text.toPlainText(), 'b www.b.com/2');
      expect(tester.takeException(), isNull);
    });
  });
}
