import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_colors.dart';

void main() {
  group('AppColors', () {
    test('imageViewerBackground should be black', () {
      expect(AppColors.imageViewerBackground, Colors.black);
    });

    test('imageViewerForeground should be white', () {
      expect(AppColors.imageViewerForeground, Colors.white);
    });

    test('imageViewerForegroundMuted should be white54', () {
      expect(AppColors.imageViewerForegroundMuted, Colors.white54);
    });

    test('imagePlaceholder should be non-null', () {
      expect(AppColors.imagePlaceholder, isNotNull);
    });
  });
}
