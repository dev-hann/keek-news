import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humoruniv/core/network/html_client.dart';
import 'package:humoruniv/data/datasources/community_adapter.dart';
import 'package:humoruniv/data/datasources/dogdrip_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_adapter_impl.dart';
import 'package:humoruniv/data/datasources/humoruniv_remote_ds.dart';
import 'package:humoruniv/data/datasources/ppomppu_adapter_impl.dart';
import 'package:humoruniv/data/datasources/todayhumor_adapter_impl.dart';
import 'package:humoruniv/data/models/post_dto.dart';
import 'package:humoruniv/data/parsers/main_page_parser.dart';
import 'package:humoruniv/data/repositories/merged_feed_repository_impl.dart';
import 'package:humoruniv/domain/entities/community.dart';
import 'package:humoruniv/domain/entities/post_detail.dart';
import 'package:mocktail/mocktail.dart';

class _MockHumorunivRemoteDs extends Mock implements HumorunivRemoteDs {}

class FixtureHtmlClient implements HtmlClient {
  FixtureHtmlClient(this._fixtures);
  final Map<String, String> _fixtures;

  @override
  Future<String> get(String path) async {
    for (final entry in _fixtures.entries) {
      if (path.contains(entry.key)) return entry.value;
    }
    throw Exception('No fixture for: $path');
  }
}

String _readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();

void main() {
  late MergedFeedRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(PostDto(
      id: 0,
      title: '',
      recommendCount: 0,
      url: '',
    ));

    final humorunivHtml = _readFixture('main_page.html');
    final humorunivDs = _MockHumorunivRemoteDs();
    when(() => humorunivDs.fetchMainPage())
        .thenAnswer((_) async => MainPageParser.parseBestPosts(humorunivHtml));

    final adapters = <CommunityId, CommunityAdapter>{
      CommunityId.humoruniv:
          HumorunivAdapterImpl(remoteDs: humorunivDs),
      CommunityId.todayhumor: TodayhumorAdapterImpl(
        htmlClient: FixtureHtmlClient({
          'list.php?table=bestofbest':
              _readFixture('todayhumor/list_bestofbest_pc.html'),
          'view.php': _readFixture('todayhumor/detail_483503.html'),
        }),
      ),
      CommunityId.ppomppu: PpomppuAdapterImpl(
        htmlClient: FixtureHtmlClient({
          'zboard.php?id=humor': _readFixture('ppomppu/list_humor.html'),
          'view.php': _readFixture('ppomppu/detail_770409.html'),
        }),
      ),
      CommunityId.dogdrip: DogdripAdapterImpl(
        htmlClient: FixtureHtmlClient({
          'mid=dogdrip': _readFixture('dogdrip/list_dogdrip.html'),
        }),
      ),
    };

    repo = MergedFeedRepositoryImpl(
      adapters: adapters,
      cacheTtl: const Duration(milliseconds: 1),
    );
  });

  group('Merged feed integration (real adapters + fixture HTML)', () {
    test('should return items from multiple communities', () async {
      final result = await repo.fetchMerged(perSource: 20);

      expect(result.isRight(), isTrue);
      final page = result.getOrElse(() => throw StateError(''));
      expect(page.items, isNotEmpty);

      final communities = page.items.map((e) => e.community).toSet();
      expect(communities.length, greaterThan(1));
    });

    test('should sort by publishedAt descending', () async {
      final result = await repo.fetchMerged(perSource: 20);

      final page = result.getOrElse(() => throw StateError(''));
      final ts = page.items
          .where((e) => e.publishedAt != null)
          .map((e) => e.publishedAt!.millisecondsSinceEpoch)
          .toList();

      for (var i = 1; i < ts.length; i++) {
        expect(ts[i - 1], greaterThanOrEqualTo(ts[i]));
      }
    });

    test('should return items with titles and URLs', () async {
      final result = await repo.fetchMerged(perSource: 20);

      final page = result.getOrElse(() => throw StateError(''));
      for (final item in page.items) {
        expect(item.title, isNotEmpty);
        expect(item.url, isNotEmpty);
        expect(item.id, isNotEmpty);
      }
    });

    test('should have cursor for pagination', () async {
      final result = await repo.fetchMerged(perSource: 20);

      final page = result.getOrElse(() => throw StateError(''));
      if (page.items.isNotEmpty) {
        expect(page.next, isNotNull);
      }
    });

    test('should fetch detail from correct adapter', () async {
      final feedResult = await repo.fetchMerged(perSource: 20);
      final page = feedResult.getOrElse(() => throw StateError(''));

      final thItem = page.items
          .where((e) => e.community == CommunityId.todayhumor)
          .firstOrNull;
      if (thItem != null) {
        final detailResult = await repo.fetchDetail(
          community: CommunityId.todayhumor,
          id: thItem.id,
        );
        expect(detailResult.isRight(), isTrue);
        final detail =
            detailResult.getOrElse(() => throw StateError(''));
        expect(detail.title, isNotEmpty);
        expect(detail.community, CommunityId.todayhumor);
      }
    });

    test('should filter by enabled communities', () async {
      final result = await repo.fetchMerged(
        perSource: 20,
        enabled: {CommunityId.humoruniv},
      );

      final page = result.getOrElse(() => throw StateError(''));
      for (final item in page.items) {
        expect(item.community, CommunityId.humoruniv);
      }
    });

    test('should isolate adapter failures', () async {
      final failingDs = _MockHumorunivRemoteDs();
      when(() => failingDs.fetchMainPage())
          .thenThrow(Exception('network down'));

      final failRepo = MergedFeedRepositoryImpl(
        adapters: {
          CommunityId.humoruniv:
              HumorunivAdapterImpl(remoteDs: failingDs),
          CommunityId.todayhumor: TodayhumorAdapterImpl(
            htmlClient: FixtureHtmlClient({
              'list.php': _readFixture(
                'todayhumor/list_bestofbest_pc.html',
              ),
            }),
          ),
        },
        cacheTtl: const Duration(milliseconds: 1),
      );

      final result = await failRepo.fetchMerged(perSource: 20);
      expect(result.isRight(), isTrue);

      final page = result.getOrElse(() => throw StateError(''));
      expect(page.failedSources, contains(CommunityId.humoruniv));
      expect(
        page.items.every((e) => e.community != CommunityId.humoruniv),
        isTrue,
      );
    });
  });
}
