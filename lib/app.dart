import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keek_news/pages/bookmarks_view.dart';
import 'package:keek_news/pages/home_view.dart';
import 'package:keek_news/pages/settings_view.dart';
import 'package:keek_news/theme/shad_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    return ShadApp.router(
      title: '킥뉴스',
      themeMode: ThemeMode.dark,
      darkTheme: AppShadTheme.dark(),
      routerConfig: appRouter,
      builder: (context, child) =>
          ScaffoldMessenger(child: child ?? const SizedBox.shrink()),
    );
  }
}
