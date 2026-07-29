import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

abstract final class AppSchemes {
  static const orange = FlexSchemeData(
    name: 'Orange',
    description: 'HappyNews default theme based on brand colors',
    light: FlexSchemeColor(
      primary: Color(0xFFFF6D00),
      primaryContainer: Color(0xFFFFDBC8),
      secondary: Color(0xFFFF9100),
      secondaryContainer: Color(0xFFFFDDB3),
    ),
    dark: FlexSchemeColor(
      primary: Color(0xFFFF9100),
      primaryContainer: Color(0xFF9A4200),
      secondary: Color(0xFFFFB74D),
      secondaryContainer: Color(0xFF6D3B00),
    ),
  );
}
