import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/bookmark.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/bookmark_use_case.dart';

final bookmarkProvider =
    StateNotifierProvider<BookmarkNotifier, List<Bookmark>>(
      (ref) => BookmarkNotifier(sl<BookmarkUseCase>()),
    );

class BookmarkNotifier extends StateNotifier<List<Bookmark>> {
  BookmarkNotifier(this._useCase) : super(const []) {
    load();
  }

  final BookmarkUseCase _useCase;

  Future<void> load() async {
    final result = await _useCase.getAll();
    result.fold((_) {}, (bookmarks) => state = bookmarks);
  }

  bool isBookmarked(CommunityId community, String id) {
    return state.any((b) => b.community == community && b.id == id);
  }

  Future<bool> toggle(Bookmark bookmark) async {
    final already = isBookmarked(bookmark.community, bookmark.id);
    if (already) {
      final result = await _useCase.remove(bookmark.community, bookmark.id);
      return result.fold((_) => true, (_) {
        state = state
            .where(
              (b) =>
                  !(b.community == bookmark.community && b.id == bookmark.id),
            )
            .toList();
        return false;
      });
    } else {
      final result = await _useCase.add(bookmark);
      return result.fold((_) => false, (_) {
        state = [bookmark, ...state];
        return true;
      });
    }
  }

  Future<void> remove(CommunityId community, String id) async {
    final result = await _useCase.remove(community, id);
    result.fold((_) {}, (_) {
      state = state
          .where((b) => !(b.community == community && b.id == id))
          .toList();
    });
  }
}
