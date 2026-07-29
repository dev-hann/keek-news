import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/molecules/stale_data_banner.dart';

void main() {
  group('StaleDataBanner', () {
    testWidgets('should display message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StaleDataBanner(message: '마지막 업데이트: 5분 전')),
        ),
      );

      expect(find.text('마지막 업데이트: 5분 전'), findsOneWidget);
    });

    testWidgets('should display offline icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StaleDataBanner(message: '오프라인')),
        ),
      );

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });
}
