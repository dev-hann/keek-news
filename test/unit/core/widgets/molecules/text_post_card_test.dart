import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/themes/app_sizes.dart';
import 'package:happy_news/core/widgets/molecules/text_post_card.dart';

void main() {
  group('TextPostCard', () {
    testWidgets('should display the title text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TextPostCard(title: '오늘의 이야기')),
        ),
      );

      expect(find.text('오늘의 이야기'), findsOneWidget);
    });

    testWidgets('should display the secondary text when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextPostCard(title: '제목', secondary: '부가 설명'),
          ),
        ),
      );

      expect(find.text('부가 설명'), findsOneWidget);
    });

    testWidgets('should not display secondary text when secondary is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TextPostCard(title: '제목')),
        ),
      );

      expect(find.text('secondary-here'), findsNothing);
    });

    testWidgets('should use feedMediaHeight for height on a 600-tall screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TextPostCard(title: '제목', screenHeight: 600)),
        ),
      );

      final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(box.height, AppSizes.feedMediaHeight(600));
    });

    testWidgets('should use onPrimary color for the title text', (
      tester,
    ) async {
      final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: TextPostCard(title: '제목')),
        ),
      );

      final expectedColor = theme.colorScheme.onPrimary;
      final text = tester.widget<Text>(find.text('제목'));
      expect(text.style?.color, expectedColor);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextPostCard(title: '제목', onTap: () => tapped = true),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextPostCard));
      expect(tapped, isTrue);
    });
  });
}
