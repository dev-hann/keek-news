import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/stale_data_banner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('StaleDataBanner', () {
    testWidgets('should display message', (tester) async {
      await tester.pumpWidget(
        shadHarness(const StaleDataBanner(message: '마지막 업데이트: 5분 전')),
      );

      expect(find.text('마지막 업데이트: 5분 전'), findsOneWidget);
    });

    testWidgets('should display offline icon', (tester) async {
      await tester.pumpWidget(
        shadHarness(const StaleDataBanner(message: '오프라인')),
      );

      expect(find.byIcon(LucideIcons.cloudOff), findsOneWidget);
    });
  });
}
