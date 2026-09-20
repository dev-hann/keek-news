import 'package:flutter/material.dart';
import 'package:keek_news/theme/shad_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Wraps [home] in a [ShadApp] providing [AppShadTheme.dark()] for widget
/// tests that render shadcn_ui components or widgets transitively depending
/// on them.
///
/// [home] is used directly as the [ShadApp.home] (no Scaffold wrapper added).
Widget shadApp({Widget? home, GlobalKey<NavigatorState>? navigatorKey}) {
  return ShadApp(
    title: 'test',
    themeMode: ThemeMode.dark,
    darkTheme: AppShadTheme.dark(),
    navigatorKey: navigatorKey,
    home: home ?? const SizedBox.shrink(),
  );
}

/// Like [shadApp], but injects a [ScaffoldMessenger] above the navigator
/// (same wiring as KeekNewsApp's builder). Required when a test shows
/// snackbars from routes pushed on the navigator — e.g. modal bottom sheets
/// — because ScaffoldMessenger.of only looks up the tree.
Widget shadAppWithMessenger({Widget? home}) {
  return ShadApp(
    title: 'test',
    themeMode: ThemeMode.dark,
    darkTheme: AppShadTheme.dark(),
    builder: (context, child) =>
        ScaffoldMessenger(child: child ?? const SizedBox.shrink()),
    home: home ?? const Scaffold(),
  );
}

/// Wraps [body] in a [ShadApp] providing [AppShadTheme.dark()] and a
/// [Scaffold] for widget tests that just need a body.
Widget shadHarness(Widget body) {
  return ShadApp(
    title: 'test',
    themeMode: ThemeMode.dark,
    darkTheme: AppShadTheme.dark(),
    home: Scaffold(body: body),
  );
}

/// Wraps [body] in a [ShadApp] + [Scaffold] + [ScaffoldMessenger].
///
/// Required for widgets that call `ScaffoldMessenger.of(context)` (snackbars,
/// persistent bottom sheets, etc.). Production provides this via [MaterialApp]
/// implicitly, but [ShadApp] uses [WidgetsApp] so it must be added manually.
Widget shadHarnessWithMessenger(Widget body) {
  return ShadApp(
    title: 'test',
    themeMode: ThemeMode.dark,
    darkTheme: AppShadTheme.dark(),
    home: ScaffoldMessenger(child: Scaffold(body: body)),
  );
}
