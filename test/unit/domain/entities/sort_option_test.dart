import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/sort_option.dart';

void main() {
  group('SortOption', () {
    test('all has correct label and value', () {
      expect(SortOption.all.label, '전체');
      expect(SortOption.all.value, '');
    });

    test('day has correct label and value', () {
      expect(SortOption.day.label, '일간');
      expect(SortOption.day.value, 'day');
    });

    test('week has correct label and value', () {
      expect(SortOption.week.label, '주간');
      expect(SortOption.week.value, 'week');
    });

    test('month has correct label and value', () {
      expect(SortOption.month.label, '월간');
      expect(SortOption.month.value, 'month');
    });

    test('year has correct label and value', () {
      expect(SortOption.year.label, '연간');
      expect(SortOption.year.value, 'year');
    });

    test('recommend500 has correct label and value', () {
      expect(SortOption.recommend500.label, '추천500');
      expect(SortOption.recommend500.value, 'better');
    });

    test('values has exactly 6 options', () {
      expect(SortOption.values.length, 6);
    });
  });
}
