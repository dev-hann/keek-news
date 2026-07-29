import 'package:happy_news/domain/entities/board_post.dart';
import 'package:meta/meta.dart';

@immutable
class BoardListResult {
  const BoardListResult({
    required this.posts,
    required this.currentPage,
    required this.totalPage,
  });
  final List<BoardPost> posts;
  final int currentPage;
  final int totalPage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardListResult &&
          runtimeType == other.runtimeType &&
          currentPage == other.currentPage &&
          totalPage == other.totalPage &&
          _listEquals(posts, other.posts);

  static bool _listEquals(List<BoardPost> a, List<BoardPost> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(currentPage, totalPage);
}
