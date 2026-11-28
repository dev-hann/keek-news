import { type Bookmark } from '../model/bookmark';
import type { CommunityId } from '../model/community';
import { BookmarkImpl } from '../repository/bookmark/bookmark_impl';
import { BrowserLocalStorageService } from '../service/browser_local_storage_service';
import { BookmarkUseCase } from '../use_case/bookmark_use_case';
import { StateNotifier, useNotifierState } from './state_notifier';

/** The posts the user saved, most recently saved first. */
export class BookmarkNotifier extends StateNotifier<Bookmark[]> {
  private readonly useCase: BookmarkUseCase;

  constructor(useCase: BookmarkUseCase) {
    super([]);
    this.useCase = useCase;
    void this.load();
  }

  async load(): Promise<void> {
    const result = await this.useCase.getAll();
    if (result.ok) this.state = result.value;
  }

  isBookmarked(community: CommunityId, id: string): boolean {
    return this.state.some((b) => b.community === community && b.id === id);
  }

  /** Answers whether the post is saved afterwards. A failed write leaves the state as it was. */
  async toggle(bookmark: Bookmark): Promise<boolean> {
    const { community, id } = bookmark;
    if (this.isBookmarked(community, id)) {
      const result = await this.useCase.remove(community, id);
      if (!result.ok) return true;
      this.state = this.state.filter((b) => !(b.community === community && b.id === id));
      return false;
    }
    const result = await this.useCase.add(bookmark);
    if (!result.ok) return false;
    this.state = [bookmark, ...this.state];
    return true;
  }

  async remove(community: CommunityId, id: string): Promise<void> {
    const result = await this.useCase.remove(community, id);
    if (result.ok) {
      this.state = this.state.filter((b) => !(b.community === community && b.id === id));
    }
  }
}

let bookmarks: BookmarkNotifier | undefined;

/** The one bookmark notifier of the app, made the first time a screen asks for it. */
export function bookmarkNotifier(): BookmarkNotifier {
  bookmarks ??= new BookmarkNotifier(
    new BookmarkUseCase(new BookmarkImpl(new BrowserLocalStorageService()))
  );
  return bookmarks;
}

/** The posts the user saved, most recently saved first. */
export function useBookmarks(): Bookmark[] {
  return useNotifierState(bookmarkNotifier());
}
