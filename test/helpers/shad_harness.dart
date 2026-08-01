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
