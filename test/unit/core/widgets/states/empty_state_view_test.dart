import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/states/empty_state_view.dart';

void main() {
  group('EmptyStateView', () {
    testWidgets('should display message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyStateView(message: '게시글이 없습니다')),
        ),
      );

      expect(find.text('게시글이 없습니다'), findsOneWidget);
    });

    testWidgets('should display default icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyStateView(message: '비어있음')),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('should display custom icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(message: '검색 결과 없음', icon: Icons.search_off),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });
  });
}
