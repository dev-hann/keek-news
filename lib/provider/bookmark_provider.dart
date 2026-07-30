import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/repository/bookmark/bookmark_repo.dart';
import 'package:keek_news/service/service_locator.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepo>((ref) {
  return sl<BookmarkRepo>();
});

final bookmarkProvider =
    StateNotifierProvider<BookmarkNotifier, List<Bookmark>>(
      (ref) => BookmarkNotifier(ref.read(bookmarkRepositoryProvider)),
    );

class BookmarkNotifier extends StateNotifier<List<Bookmark>> {
  BookmarkNotifier(this._repository) : super(const []) {
    load();
  }

  final BookmarkRepo _repository;

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
