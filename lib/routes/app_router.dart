import 'package:go_router/go_router.dart';
import 'package:happy_news/presentation/screens/bookmarks_screen.dart';
import 'package:happy_news/presentation/screens/home_screen.dart';
import 'package:happy_news/presentation/screens/settings_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
