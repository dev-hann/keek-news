import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/thumbnail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('Thumbnail', () {
    testWidgets('should show placeholder when imageUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(shadHarness(const Thumbnail(imageUrl: null)));

      expect(find.byIcon(LucideIcons.image), findsOneWidget);
    });

    testWidgets('should show placeholder when imageUrl is empty', (
      tester,
    ) async {
      await tester.pumpWidget(shadHarness(const Thumbnail(imageUrl: '')));

      expect(find.byIcon(LucideIcons.image), findsOneWidget);
    });

    testWidgets('should show image when imageUrl is provided', (tester) async {
      await tester.pumpWidget(
        shadHarness(const Thumbnail(imageUrl: 'https://example.com/test.jpg')),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('should use small size by default', (tester) async {
      await tester.pumpWidget(shadHarness(const Thumbnail(imageUrl: null)));

      final container = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(container.width, 48);
    });

    testWidgets('should use medium size when specified', (tester) async {
      await tester.pumpWidget(
        shadHarness(
          const Thumbnail(imageUrl: null, size: ThumbnailSize.medium),
        ),
      );

      final container = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(container.width, 72);
    });

    testWidgets('should use large size when specified', (tester) async {
      await tester.pumpWidget(
        shadHarness(const Thumbnail(imageUrl: null, size: ThumbnailSize.large)),
      );

      final container = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(container.width, 120);
    });
  });
}
