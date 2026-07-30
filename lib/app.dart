import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/const/app_theme.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/pages/settings_view.dart';
import 'package:keek_news/provider/theme_provider.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeView()),
    GoRoute(
      path: '/bookmarks',
      builder: (context, state) => const BookmarksView(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsView(),
    ),
  ],
);

class KeekNewsApp extends ConsumerWidget {
  const KeekNewsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: '킥뉴스',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
