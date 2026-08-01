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
    state = await _useCase.getAll();
  }

  bool isBookmarked(CommunityId community, String id) {
    return state.any((b) => b.community == community && b.id == id);
  }

  Future<bool> toggle(Bookmark bookmark) async {
    final already = isBookmarked(bookmark.community, bookmark.id);
    if (already) {
      await _useCase.remove(bookmark.community, bookmark.id);
      state = state
          .where(
            (b) => !(b.community == bookmark.community && b.id == bookmark.id),
          )
          .toList();
      return false;
    } else {
      await _useCase.add(bookmark);
      state = [bookmark, ...state];
      return true;
    }
  }

  Future<void> remove(CommunityId community, String id) async {
    await _useCase.remove(community, id);
    state = state
        .where((b) => !(b.community == community && b.id == id))
        .toList();
  }
}
