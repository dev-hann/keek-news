import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/avatar.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../helpers/shad_harness.dart';

void main() {
  group('Avatar', () {
    testWidgets('should show person icon when imageUrl is null', (
      tester,
    ) async {
      await tester.pumpWidget(shadHarness(const Avatar()));

      expect(find.byIcon(LucideIcons.user), findsOneWidget);
    });

    testWidgets('should render ShadAvatar', (tester) async {
      await tester.pumpWidget(shadHarness(const Avatar()));

      expect(find.byType(ShadAvatar), findsOneWidget);
    });
  });
}
