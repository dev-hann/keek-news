import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/empty_state_view.dart';

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

  group('EmptyStateView title+subtitle', () {
    testWidgets('should render title and subtitle when both provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              title: '저장한 게시물이 없어요',
              subtitle: '좋아하는 글을 북마크해 보세요',
            ),
          ),
        ),
      );

      expect(find.text('저장한 게시물이 없어요'), findsOneWidget);
      expect(find.text('좋아하는 글을 북마크해 보세요'), findsOneWidget);
    });

    testWidgets('should style title larger than subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(title: '제목', subtitle: '부제목'),
          ),
        ),
      );

      final titleWidget = tester.widget<Text>(find.text('제목'));
      final subtitleWidget = tester.widget<Text>(find.text('부제목'));

      expect(
        (titleWidget.style?.fontSize ?? 0) >
            (subtitleWidget.style?.fontSize ?? 0),
        isTrue,
      );
    });

    testWidgets('should render title only when subtitle omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyStateView(title: '제목만 있음')),
        ),
      );

      expect(find.text('제목만 있음'), findsOneWidget);
    });

    testWidgets('should fall back to message when title omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyStateView(message: '레거시 메시지')),
        ),
      );

      expect(find.text('레거시 메시지'), findsOneWidget);
    });

    testWidgets('should use title weight bolder than subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(title: '제목', subtitle: '부제목'),
          ),
        ),
      );

      final titleWidget = tester.widget<Text>(find.text('제목'));
      final subtitleWidget = tester.widget<Text>(find.text('부제목'));

      final titleWeight = titleWidget.style?.fontWeight?.value ?? 400;
      final subtitleWeight = subtitleWidget.style?.fontWeight?.value ?? 400;
      expect(titleWeight >= subtitleWeight, isTrue);
    });
  });
}
