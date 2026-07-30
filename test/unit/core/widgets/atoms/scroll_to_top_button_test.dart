import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/atoms/scroll_to_top_button.dart';

void main() {
  Widget harness({required VoidCallback onTap, bool visible = true}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ScrollToTopButton(onTap: onTap, visible: visible),
        ),
      ),
    );
  }

  group('ScrollToTopButton', () {
    testWidgets('should display the up-arrow icon', (tester) async {
      await tester.pumpWidget(harness(onTap: () {}));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('should be fully opaque when visible', (tester) async {
      await tester.pumpWidget(harness(onTap: () {}));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );
    });

    testWidgets('should be transparent when not visible', (tester) async {
      await tester.pumpWidget(harness(onTap: () {}, visible: false));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );
    });

    testWidgets('should call onTap once when tapped and visible', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(harness(onTap: () => taps++));
      await tester.tap(find.byType(ScrollToTopButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('should NOT call onTap when not visible', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(onTap: () => taps++, visible: false));
      await tester.tap(find.byType(ScrollToTopButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('should expose 맨 위로 semantics label as a button', (
      tester,
    ) async {
      await tester.pumpWidget(harness(onTap: () {}));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '맨 위로' &&
              (w.properties.button ?? false),
        ),
        findsOneWidget,
      );
    });
  });
}
