import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_radius.dart';

void main() {
  group('AppRadius', () {
    test('sm should be 4', () {
      expect(AppRadius.sm, 4);
    });

    test('md should be 8', () {
      expect(AppRadius.md, 8);
    });

    test('lg should be 12', () {
      expect(AppRadius.lg, 12);
    });

    test('xl should be 16', () {
      expect(AppRadius.xl, 16);
    });

    test('xxl should be 24', () {
      expect(AppRadius.xxl, 24);
    });

    test('full should be 9999', () {
      expect(AppRadius.full, 9999);
    });

    test('all values should be multiples of 4 or 4pt half-steps', () {
      const values = [
        AppRadius.sm,
        AppRadius.md,
        AppRadius.lg,
        AppRadius.xl,
        AppRadius.xxl,
      ];
      for (final v in values) {
        expect(v % 4, anyOf(0, 2), reason: '$v is not on the 4pt grid');
      }
    });

    group('BorderRadius presets', () {
      test('borderRadiusSm should use sm', () {
        expect(
          AppRadius.borderRadiusSm,
          const BorderRadius.all(Radius.circular(AppRadius.sm)),
        );
      });

      test('borderRadiusXl should use xl', () {
        expect(
          AppRadius.borderRadiusXl,
          const BorderRadius.all(Radius.circular(AppRadius.xl)),
        );
      });

      test('borderRadiusFull should use full', () {
        expect(
          AppRadius.borderRadiusFull,
          const BorderRadius.all(Radius.circular(AppRadius.full)),
        );
      });
    });
  });
}
