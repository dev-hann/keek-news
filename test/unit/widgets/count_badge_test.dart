import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/count_badge.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('CountBadge', () {
    testWidgets('should display count', (tester) async {
      await tester.pumpWidget(
        shadHarness(const CountBadge(count: 42, icon: LucideIcons.thumbsUp)),
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('should display icon', (tester) async {
      await tester.pumpWidget(
        shadHarness(const CountBadge(count: 42, icon: LucideIcons.thumbsUp)),
      );

      expect(find.byIcon(LucideIcons.thumbsUp), findsOneWidget);
    });
  });

  group('RecommendBadge', () {
    testWidgets('should display recommend count', (tester) async {
      await tester.pumpWidget(shadHarness(const RecommendBadge(count: 100)));

      expect(find.text('100'), findsOneWidget);
      expect(find.byIcon(LucideIcons.thumbsUp), findsOneWidget);
    });
  });

  group('CommentBadge', () {
    testWidgets('should display comment count', (tester) async {
      await tester.pumpWidget(shadHarness(const CommentBadge(count: 15)));

      expect(find.text('15'), findsOneWidget);
      expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);
    });
  });

  group('BestBadge', () {
    testWidgets('should display BEST text', (tester) async {
      await tester.pumpWidget(shadHarness(const BestBadge()));

      expect(find.text('BEST'), findsOneWidget);
    });
  });
}
