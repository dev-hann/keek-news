import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/const/app_theme.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/pages/settings_view.dart';

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

class KeekNewsApp extends StatelessWidget {
  const KeekNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '킥뉴스',
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
