import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'package:keek_news/const/app_schemes.dart';
import 'package:keek_news/const/app_typography.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final base = FlexThemeData.dark(
      colors: AppSchemes.orange,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    );

    return _applyTypography(base);
  }

  static ThemeData _applyTypography(ThemeData base) {
    return base.copyWith(
      textTheme: AppTypography.build(
        onSurface: base.colorScheme.onSurface,
        onSurfaceVariant: base.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
