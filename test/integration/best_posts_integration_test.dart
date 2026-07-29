import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/network/html_client.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds_impl.dart';
import 'package:happy_news/data/repositories/post_repository_impl.dart';
import 'package:happy_news/domain/entities/post.dart';
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

  setUp(() {
    final htmlClient = FixtureHtmlClient({
      '/main.html': 'test/fixtures/main_page.html',
    });
    final remoteDs = HumorunivRemoteDsImpl(htmlClient: htmlClient);
    repository = PostRepositoryImpl(remoteDs: remoteDs);
  });

  group('Integration: best posts flow', () {
    test(
      'should parse real fixture HTML through full chain and return posts',
      () async {
        final result = await repository.getBestPosts();

        final posts = result.fold((failure) => <Post>[], (posts) => posts);

        expect(posts, isNotEmpty);
        expect(posts.length, greaterThanOrEqualTo(10));

        final first = posts.first;
        expect(first.id, greaterThan(0));
        expect(first.title, isNotEmpty);
        expect(first.recommendCount, greaterThanOrEqualTo(0));
        expect(first.url, contains('table=pds'));
        expect(first.url, contains('number='));
      },
    );

    test('should produce valid Post entities from real data', () async {
      final result = await repository.getBestPosts();

      final posts = result.fold((failure) => <Post>[], (posts) => posts);

      for (final post in posts) {
        expect(post.id, greaterThan(0));
        expect(post.title, isNotEmpty);
        expect(post.url, isNotEmpty);
      }
    });

    test('should have posts ordered by recommend count (descending)', () async {
      final result = await repository.getBestPosts();

      final posts = result.fold((failure) => <Post>[], (posts) => posts);

      for (var i = 1; i < posts.length; i++) {
        expect(
          posts[i - 1].recommendCount,
          greaterThanOrEqualTo(posts[i].recommendCount),
        );
      }
    });
  });
}
