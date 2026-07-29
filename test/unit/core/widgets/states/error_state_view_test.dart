import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/states/error_state_view.dart';

void main() {
  group('ErrorStateView', () {
    testWidgets('should display error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorStateView(message: '에러 발생')),
        ),
      );

      expect(find.text('에러 발생'), findsOneWidget);
    });

    testWidgets('should display error icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorStateView(message: '에러')),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should not show retry button when onRetry is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorStateView(message: '에러')),
        ),
      );

      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('should show retry button when onRetry is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(message: '에러', onRetry: () {}),
          ),
        ),
      );

      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('should call onRetry when retry button tapped', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(message: '에러', onRetry: () => retried = true),
          ),
        ),
      );

      await tester.tap(find.text('다시 시도'));
      expect(retried, isTrue);
    });
  });
}
