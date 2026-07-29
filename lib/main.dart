import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_news/core/themes/app_theme.dart';
import 'package:happy_news/di/injection.dart';
import 'package:happy_news/presentation/providers/shared_preferences_provider.dart';
import 'package:happy_news/presentation/providers/theme_provider.dart';
import 'package:happy_news/routes/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const HappyNewsApp(),
    ),
  );
}

class HappyNewsApp extends ConsumerWidget {
  const HappyNewsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: '해피뉴스',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
