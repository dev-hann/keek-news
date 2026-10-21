import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/comment.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/utils/blocked_image_filter.dart';

LoadedPostDetail _detail({
  List<ContentBlock> blocks = const [],
  List<String> imageUrls = const [],
  List<Comment> comments = const [],
}) {
  return LoadedPostDetail(
    id: 1,
    community: CommunityId.humoruniv,
    title: 'title',
    author: 'author',
    date: DateTime.fromMillisecondsSinceEpoch(0),
    contentBlocks: blocks,
    imageUrls: imageUrls,
    recommendCount: 0,
    notRecommendCount: 0,
    viewCount: 0,
    commentCount: comments.length,
    comments: comments,
  );
}

Comment _comment({
  int id = 1,
  List<ContentBlock> mediaBlocks = const [],
  List<Comment> replies = const [],
}) {
  return Comment(
    id: id,
    author: 'a',
    content: 'c',
    date: DateTime.fromMillisecondsSinceEpoch(0),
    recommendCount: 0,
    isBest: false,
    replies: replies,
    mediaBlocks: mediaBlocks,
  );
}

void main() {
  group('filterBlockedPostDetail', () {
    test('should return null detail untouched', () {
      expect(filterBlockedPostDetail(null, {'https://x/a.jpg'}), isNull);
    });

    test('should return error detail untouched', () {
      const detail = ErrorPostDetail(
        id: 1,
        community: CommunityId.humoruniv,
        failure: ServerFailure('x'),
      );

      expect(
        filterBlockedPostDetail(detail, {'https://x/a.jpg'}),
        same(detail),
      );
    });

    test('should return the same instance when blocklist empty', () {
      final detail = _detail(imageUrls: const ['https://x/a.jpg']);

      expect(filterBlockedPostDetail(detail, const {}), same(detail));
    });

    test('should drop blocked body image blocks and imageUrls', () {
      final detail = _detail(
        blocks: [
          const TextBlock('hello'),
          const ImageBlock(url: 'https://x/blocked.jpg'),
          const ImageBlock(url: 'https://x/keep.jpg'),
        ],
        imageUrls: const ['https://x/blocked.jpg', 'https://x/keep.jpg'],
      );

      final filtered =
          filterBlockedPostDetail(detail, const {'https://x/blocked.jpg'})!
              as LoadedPostDetail;

      expect(filtered.contentBlocks, const [
        TextBlock('hello'),
        ImageBlock(url: 'https://x/keep.jpg'),
      ]);
      expect(filtered.imageUrls, const ['https://x/keep.jpg']);
    });

    test('should keep video blocks untouched', () {
      const video = VideoBlock(url: 'https://x/v.mp4');
      final detail = _detail(blocks: const [video]);

      final filtered =
          filterBlockedPostDetail(detail, const {'https://x/v.mp4'})!
              as LoadedPostDetail;

      expect(filtered.contentBlocks, const [video]);
    });

    test('should drop blocked comment images recursively', () {
      final detail = _detail(
        comments: [
          _comment(
            mediaBlocks: const [
              ImageBlock(url: 'https://x/blocked.jpg'),
              ImageBlock(url: 'https://x/keep.jpg'),
            ],
            replies: [
              _comment(
                id: 2,
                mediaBlocks: const [ImageBlock(url: 'https://x/blocked.jpg')],
              ),
            ],
          ),
        ],
      );

      final filtered =
          filterBlockedPostDetail(detail, const {'https://x/blocked.jpg'})!
              as LoadedPostDetail;

      final comment = filtered.comments.single;
      expect(comment.imageUrls, const ['https://x/keep.jpg']);
      expect(comment.replies.single.imageUrls, isEmpty);
    });

    test('should keep non-media comment fields intact', () {
      final detail = _detail(
        comments: [
          _comment(
            id: 7,
            mediaBlocks: const [ImageBlock(url: 'https://x/blocked.jpg')],
          ),
        ],
      );

      final filtered =
          filterBlockedPostDetail(detail, const {'https://x/blocked.jpg'})!
              as LoadedPostDetail;

      final comment = filtered.comments.single;
      expect(comment.id, 7);
      expect(comment.content, 'c');
      expect(comment.recommendCount, 0);
    });
  });
}
