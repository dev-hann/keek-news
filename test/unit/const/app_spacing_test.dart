import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/const/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('p2 should be 2', () {
      expect(AppSpacing.p2, 2);
    });

    test('p4 should be 4', () {
      expect(AppSpacing.p4, 4);
    });

    test('p6 should be 6', () {
      expect(AppSpacing.p6, 6);
    });

    test('p8 should be 8', () {
      expect(AppSpacing.p8, 8);
    });

    test('p12 should be 12', () {
      expect(AppSpacing.p12, 12);
    });

    test('p16 should be 16', () {
      expect(AppSpacing.p16, 16);
    });

    test('p24 should be 24', () {
      expect(AppSpacing.p24, 24);
    });

    test('p32 should be 32', () {
      expect(AppSpacing.p32, 32);
    });

    test('all values should be multiples of 4 or 4pt half-steps', () {
      const values = [
        AppSpacing.p2,
        AppSpacing.p4,
        AppSpacing.p6,
        AppSpacing.p8,
        AppSpacing.p12,
        AppSpacing.p16,
        AppSpacing.p20,
        AppSpacing.p24,
        AppSpacing.p32,
        AppSpacing.p40,
        AppSpacing.p48,
        AppSpacing.p56,
        AppSpacing.p64,
      ];
      for (final v in values) {
        expect(v % 4, anyOf(0, 2), reason: '$v is not on the 4pt grid');
      }
    });

    group('EdgeInsets presets', () {
      test('edgeAll16 should have all sides 16', () {
        expect(AppSpacing.edgeAll16, const EdgeInsets.all(16));
      });

      test('edgeH16 should have horizontal 16', () {
        expect(AppSpacing.edgeH16, const EdgeInsets.symmetric(horizontal: 16));
      });

      test('edgeOnlyBottom12 should have bottom 12', () {
        expect(AppSpacing.edgeOnlyBottom12, const EdgeInsets.only(bottom: 12));
      });
    });

    group('SizedBox presets', () {
      test('sbH8 should have height 8', () {
        expect(AppSpacing.sbH8.height, 8);
      });

      test('sbW8 should have width 8', () {
        expect(AppSpacing.sbW8.width, 8);
      });
    });
  });
}
