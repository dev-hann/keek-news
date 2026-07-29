import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/molecules/section_header.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('should display title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader(title: '댓글')),
        ),
      );

      expect(find.text('댓글'), findsOneWidget);
    });

    testWidgets('should display trailing widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: '댓글', trailing: Text('더보기')),
          ),
        ),
      );

      expect(find.text('더보기'), findsOneWidget);
    });
  });
}
