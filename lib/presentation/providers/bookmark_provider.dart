import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_news/di/injection.dart';
import 'package:happy_news/domain/entities/bookmark.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/domain/repositories/bookmark_repository.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return sl<BookmarkRepository>();
});

final bookmarkProvider =
    StateNotifierProvider<BookmarkNotifier, List<Bookmark>>(
      (ref) => BookmarkNotifier(ref.read(bookmarkRepositoryProvider)),
    );

class BookmarkNotifier extends StateNotifier<List<Bookmark>> {
  BookmarkNotifier(this._repository) : super(const []) {
    load();
  }

  final BookmarkRepository _repository;

  Future<void> load() async {
    state = await _repository.getAll();
  }

  bool isBookmarked(CommunityId community, String id) {
    return state.any((b) => b.community == community && b.id == id);
  }

  Future<bool> toggle(Bookmark bookmark) async {
    final already = isBookmarked(bookmark.community, bookmark.id);
    if (already) {
      await _repository.remove(bookmark.community, bookmark.id);
      state = state
          .where(
            (b) => !(b.community == bookmark.community && b.id == bookmark.id),
          )
          .toList();
      return false;
    } else {
      await _repository.add(bookmark);
      state = [bookmark, ...state];
      return true;
    }
  }

  Future<void> remove(CommunityId community, String id) async {
    await _repository.remove(community, id);
    state = state
        .where((b) => !(b.community == community && b.id == id))
        .toList();
  }
}
