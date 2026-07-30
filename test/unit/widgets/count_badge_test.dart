import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/count_badge.dart';

void main() {
  group('CountBadge', () {
    testWidgets('should display count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CountBadge(count: 42, icon: Icons.thumb_up)),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('should display icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CountBadge(count: 42, icon: Icons.thumb_up)),
        ),
      );

      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    });
  });

  group('RecommendBadge', () {
    testWidgets('should display recommend count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RecommendBadge(count: 100))),
      );

      expect(find.text('100'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    });
  });

  group('CommentBadge', () {
    testWidgets('should display comment count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommentBadge(count: 15))),
      );

      expect(find.text('15'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });
  });

  group('BestBadge', () {
    testWidgets('should display BEST text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BestBadge())),
      );

      expect(find.text('BEST'), findsOneWidget);
    });
  });
}
