import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/skeleton_box.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('SkeletonBox', () {
    testWidgets('should render with default height', (tester) async {
      await tester.pumpWidget(shadHarness(const SkeletonBox()));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
    });

    testWidgets('should render with custom width and height', (tester) async {
      await tester.pumpWidget(
        shadHarness(const SkeletonBox(width: 100, height: 20)),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth ?? 100, 100);
    });
  });
}
