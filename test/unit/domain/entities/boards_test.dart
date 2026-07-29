import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/domain/entities/boards.dart';

void main() {
  group('boards', () {
    test('should contain pds board', () {
      expect(boards, isNotEmpty);
      expect(boards.any((b) => b.table == 'pds'), isTrue);
    });

    test('defaultBoard should be pds', () {
      expect(defaultBoard.table, 'pds');
      expect(defaultBoard.name, '웃긴자료');
    });

    test('findBoardByTable should return matching board', () {
      final board = findBoardByTable('pds');
      expect(board, isNotNull);
      expect(board!.table, 'pds');
      expect(board.name, '웃긴자료');
    });

    test('findBoardByTable should return null for unknown table', () {
      final board = findBoardByTable('unknown');
      expect(board, isNull);
    });
  });
}
