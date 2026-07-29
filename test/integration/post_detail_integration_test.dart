import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/network/html_client.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds_impl.dart';
import 'package:happy_news/data/repositories/post_repository_impl.dart';
import 'package:happy_news/domain/entities/content_block.dart';
import 'package:happy_news/domain/repositories/post_repository.dart';

class FixtureHtmlClient implements HtmlClient {
  FixtureHtmlClient(this._fixtures);
  final Map<String, String> _fixtures;

  @override
  Future<String> get(String path) async {
    final fixture = _fixtures[path];
    if (fixture != null) {
      return File(fixture).readAsStringSync();
    }
    throw Exception('No fixture for path: $path');
  }
}

void main() {
  late PostRepository repository;

  late FixtureHtmlClient htmlClient;

  setUp(() {
    htmlClient = FixtureHtmlClient({
      '/board/read.html?table=pds&number=1410286':
          'test/fixtures/post_detail.html',
      '/board/read.html?table=pds&number=999999':
          'test/fixtures/post_detail_daum.html',
    });
    final remoteDs = HumorunivRemoteDsImpl(htmlClient: htmlClient);
    repository = PostRepositoryImpl(remoteDs: remoteDs);
  });

  group('Integration: post detail flow', () {
    test(
      'should parse real fixture HTML through full chain and return PostDetail',
      () async {
        final result = await repository.getPostDetail(
          '/board/read.html?table=pds&number=1410286',
        );

        final detail = result.fold((failure) => null, (detail) => detail);

        expect(detail, isNotNull);
        expect(detail!.title, isNotEmpty);
        expect(detail.title, contains('MBC PD'));
        expect(detail.author, equals('오유의감동브레이커'));
        expect(detail.recommendCount, greaterThan(0));
        expect(detail.viewCount, greaterThan(0));
        expect(detail.commentCount, greaterThan(0));
      },
    );

    test('should extract image URLs from real post detail', () async {
      final result = await repository.getPostDetail(
        '/board/read.html?table=pds&number=1410286',
      );

      final detail = result.fold((failure) => null, (detail) => detail);

      expect(detail, isNotNull);
      expect(detail!.imageUrls, isNotEmpty);
      for (final url in detail.imageUrls) {
        expect(url, contains('humoruniv.com'));
      }
    });

    test(
      'should extract comments with best and regular from real data',
      () async {
        final result = await repository.getPostDetail(
          '/board/read.html?table=pds&number=1410286',
        );

        final detail = result.fold((failure) => null, (detail) => detail);

        expect(detail, isNotNull);
        expect(detail!.comments, isNotEmpty);

        final bestComments = detail.comments.where((c) => c.isBest).toList();
        expect(bestComments, isNotEmpty);

        for (final comment in detail.comments) {
          expect(comment.author, isNotEmpty);
          expect(comment.content, isNotEmpty);
        }
      },
    );
  });

  group('Integration: daum-wm-content layout (no body_editor)', () {
    test(
      'should parse post with image and text from daum-wm-content',
      () async {
        final result = await repository.getPostDetail(
          '/board/read.html?table=pds&number=999999',
        );

        final detail = result.fold((failure) => null, (detail) => detail);

        expect(detail, isNotNull);
        expect(detail!.title, contains('daum-wm-content'));
        expect(detail.author, equals('testAuthor'));
        expect(detail.recommendCount, equals(83));
        expect(detail.viewCount, greaterThan(0));
        expect(detail.commentCount, equals(3));
      },
    );

    test(
      'should extract both image and text blocks from daum-wm-content',
      () async {
        final result = await repository.getPostDetail(
          '/board/read.html?table=pds&number=999999',
        );

        final detail = result.fold((failure) => null, (detail) => detail);

        expect(detail, isNotNull);

        final images = detail!.contentBlocks.whereType<ImageBlock>().toList();
        final texts = detail.contentBlocks.whereType<TextBlock>().toList();

        expect(images, isNotEmpty);
        expect(texts, isNotEmpty);
        expect(texts.any((t) => t.text.contains('딸이 초등학교')), isTrue);
      },
    );

    test('should extract image URL from daum-wm-content post', () async {
      final result = await repository.getPostDetail(
        '/board/read.html?table=pds&number=999999',
      );

      final detail = result.fold((failure) => null, (detail) => detail);

      expect(detail, isNotNull);
      expect(detail!.imageUrls, isNotEmpty);
      expect(detail.imageUrls.first, contains('a_w5bcc3d001_testimage.jpg'));
    });
  });
}
