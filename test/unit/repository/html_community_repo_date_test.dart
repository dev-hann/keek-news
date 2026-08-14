import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:keek_news/repository/community/humoruniv/humoruniv_impl.dart';
import 'package:keek_news/service/html_service.dart';

import '../../helpers/html_service_helpers.dart';

/// HumorunivImpl is only used as a concrete carrier of the shared
/// parseDatePattern helper; no fixture data is fetched.
class _ThrowingHtmlService extends HtmlService
    with HtmlServiceMultiCandidateMixin {
  @override
  Future<String> get(String path) async => throw UnsupportedError('no http');

  @override
  int extractNumber(String? text) => 0;

  @override
  String textOf(Element? element) => '';

  @override
  String? attrOf(Element? element, String name) => null;

  @override
  int statOf(Element? parent, String selector) => 0;
}

void main() {
  late final repo = HumorunivImpl(htmlClient: _ThrowingHtmlService());

  group('HtmlCommunityRepo.parseDatePattern', () {
    test('parses full date-time with 6 groups', () {
      final date = repo.parseDatePattern(
        '2026-08-14 09:30:15',
        RegExp(r'(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})'),
      );
      expect(date, DateTime(2026, 8, 14, 9, 30, 15));
    });

    test('resolves two-digit years against 2000 when year2 is set', () {
      final date = repo.parseDatePattern(
        '26/08/14 09:30',
        RegExp(r'(\d{2})/(\d{2})/(\d{2}) (\d{2}):(\d{2})'),
        year2: true,
      );
      expect(date, DateTime(2026, 8, 14, 9, 30));
    });

    test('date-only patterns zero the time components', () {
      final date = repo.parseDatePattern(
        '2026.08.14',
        RegExp(r'(\d{4})\.(\d{2})\.(\d{2})'),
      );
      expect(date, DateTime(2026, 8, 14));
    });

    test('null groups inside an optional time section become 0', () {
      final date = repo.parseDatePattern(
        '2026-08-14',
        RegExp(
          r'(\d{4})-(\d{1,2})-(\d{1,2})(?:[^\d]*?(\d{1,2}):(\d{2}):(\d{2}))?',
        ),
      );
      expect(date, DateTime(2026, 8, 14));
    });

    test('returns null when the pattern does not match', () {
      final date = repo.parseDatePattern(
        'no date here',
        RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
      );
      expect(date, isNull);
    });
  });
}
