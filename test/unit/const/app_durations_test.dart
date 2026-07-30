import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_durations.dart';

void main() {
  group('AppDurations', () {
    test('fast should be 150ms', () {
      expect(AppDurations.fast, const Duration(milliseconds: 150));
    });

    test('medium should be 300ms', () {
      expect(AppDurations.medium, const Duration(milliseconds: 300));
    });

    test('slow should be 500ms', () {
      expect(AppDurations.slow, const Duration(milliseconds: 500));
    });

    test('durations should be ordered fast < medium < slow', () {
      expect(AppDurations.fast < AppDurations.medium, isTrue);
      expect(AppDurations.medium < AppDurations.slow, isTrue);
    });
  });

  group('AppCurves', () {
    test('standard should be easeInOut', () {
      expect(AppCurves.standard, Curves.easeInOut);
    });

    test('decelerate should be easeOut', () {
      expect(AppCurves.decelerate, Curves.easeOut);
    });

    test('accelerate should be easeIn', () {
      expect(AppCurves.accelerate, Curves.easeIn);
    });
  });
}
