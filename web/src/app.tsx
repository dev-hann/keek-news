import { useLayoutEffect } from 'react';
import { Toaster } from './components/ui/sonner';
import { TooltipProvider } from './components/ui/tooltip';
import { BlockedImagesView } from './pages/blocked_images_view';
import { BookmarksView } from './pages/bookmarks_view';
import { HomeView } from './pages/home_view';
import { RelayCheckView } from './pages/relay_check_view';
import { SettingsView } from './pages/settings_view';
import {
  blockedImagesPath,
  bookmarksPath,
  homePath,
  navigate,
  relayCheckPath,
  scrollPositionOf,
  settingsPath,
  usePathname,
} from './utils/router';

/** Back to the page before, or to the feed when the app was opened on this page. */
function goBack(): void {
  if (window.history.length > 1) window.history.back();
  else navigate(homePath);
}

/** The page at `pathname`. A path the app does not have shows the feed. */
function Page({ pathname }: { pathname: string }) {
  if (pathname === settingsPath)
    return (
      <SettingsView
        onBack={goBack}
        onOpenBookmarks={() => navigate(bookmarksPath)}
        onOpenBlockedImages={() => navigate(blockedImagesPath)}
      />
    );
  if (pathname === bookmarksPath) return <BookmarksView onBack={goBack} />;
  if (pathname === blockedImagesPath) return <BlockedImagesView onBack={goBack} />;
  if (pathname === relayCheckPath) return <RelayCheckView onBack={goBack} />;
  return <HomeView onOpenSettings={() => navigate(settingsPath)} />;
}

export function App() {
  const pathname = usePathname();

  useLayoutEffect(() => {
    // A page starts where it was left; one never left starts at its top.
    window.scrollTo(0, scrollPositionOf(pathname) ?? 0);
  }, [pathname]);

  return (
    <TooltipProvider>
      <Page key={pathname} pathname={pathname} />
      <Toaster position="top-center" duration={2500} />
    </TooltipProvider>
  );
}
