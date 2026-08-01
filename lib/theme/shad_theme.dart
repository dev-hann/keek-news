import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// App theme built on shadcn_ui.
///
/// Dark-only, orange primary. Replaces former flex_color_scheme setup.
/// ShadThemeData is converted to Material ThemeData by ShadApp.materialTheme,
/// so `Theme.of(context)` keeps working for url_launcher/webview/Material widgets.
abstract final class AppShadTheme {
  static ShadThemeData dark() => ShadThemeData(
    colorScheme: const ShadOrangeColorScheme.dark(),
    brightness: Brightness.dark,
  );
}
