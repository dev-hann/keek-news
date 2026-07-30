import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/presentation/screens/image_viewer_screen.dart';

void main() {
  group('ImageViewerScreen', () {
    testWidgets('renders close button for a single image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(imageUrls: ['https://example.com/a.jpg']),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders page indicator for multiple images', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(
            imageUrls: [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('renders a PageView for paging between images', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(imageUrls: ['https://example.com/a.jpg']),
        ),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('renders InteractiveViewer for a normal image', (tester) async {
      // viewport default 800x600 → viewportAspect 1.33; aspect 2.0 (wide) is NOT long.
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(
            imageUrls: ['https://example.com/a.jpg'],
            knownAspects: {'https://example.com/a.jpg': 2.0},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets(
      'long image page reserves bottom scroll space so the indicator does '
      'not obscure the bottom of the image',
      (tester) async {
        // Default test viewport is 800x600; with extendBodyBehindAppBar the
        // body fills it, so viewport height = 600. A 2000-tall long image
        // without any bottom reserve would have maxScrollExtent = 1400.
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(
              imageUrls: const ['https://example.com/long.jpg'],
              knownAspects: const {'https://example.com/long.jpg': 0.5},
              imageBuilder: (_) => Container(height: 2000, color: Colors.red),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        );

        expect(
          scrollable.position.maxScrollExtent,
          greaterThan(1400),
          reason:
              'long image page must add bottom reserve so its bottom can be '
              'scrolled above the floating page indicator',
        );
      },
    );

    testWidgets('renders vertical SingleChildScrollView for a long image '
        'instead of InteractiveViewer', (tester) async {
      // aspect 0.5 (tall) < viewportAspect 1.33 → long image.
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(
            imageUrls: ['https://example.com/a.jpg'],
            knownAspects: {'https://example.com/a.jpg': 0.5},
          ),
        ),
      );
      await tester.pump();

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollView.scrollDirection,
        Axis.vertical,
        reason: 'long image must scroll vertically',
      );
      expect(
        find.byType(InteractiveViewer),
        findsNothing,
        reason: 'long image must not use InteractiveViewer',
      );
    });

    testWidgets('close button pops the screen', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('root')),
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerScreen(
            imageUrls: const ['https://example.com/a.jpg'],
            imageBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('swiping down no longer dismisses (dismiss gesture removed)', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('root')),
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerScreen(
            imageUrls: const ['https://example.com/a.jpg'],
            imageBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A downward drag must NOT pop anymore; the viewer stays.
      await tester.fling(find.byType(PageView), const Offset(0, 250), 1000);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('root'), findsNothing);
    });

    testWidgets('tapping the right third advances to the next page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageViewerScreen(
            imageUrls: const [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
            imageBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);

      await tester.tapAt(const Offset(700, 300));
      await tester.pumpAndSettle();

      expect(
        find.text('2/2'),
        findsOneWidget,
        reason: 'tap on the right third should advance',
      );
    });

    testWidgets('tapping the left third goes back to the previous page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageViewerScreen(
            imageUrls: const [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
            initialIndex: 1,
            imageBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2/2'), findsOneWidget);

      await tester.tapAt(const Offset(100, 300));
      await tester.pumpAndSettle();

      expect(
        find.text('1/2'),
        findsOneWidget,
        reason: 'tap on the left third should go back',
      );
    });

    testWidgets('tapping the center third does not change page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageViewerScreen(
            imageUrls: const [
              'https://example.com/a.jpg',
              'https://example.com/b.jpg',
            ],
            imageBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets(
      'horizontal swipe advances pages when starting on a long image',
      (tester) async {
        // Page 0 is long (aspect 0.5 < 1.33), page 1 is normal (aspect 2.0).
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(
              imageUrls: const [
                'https://example.com/long.jpg',
                'https://example.com/normal.jpg',
              ],
              knownAspects: const {
                'https://example.com/long.jpg': 0.5,
                'https://example.com/normal.jpg': 2.0,
              },
              imageBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('1/2'), findsOneWidget);

        // Swipe left (negative dx) to advance to the next page.
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 2000);
        await tester.pumpAndSettle();

        expect(
          find.text('2/2'),
          findsOneWidget,
          reason: 'paging from a long image page should reach the next page',
        );
      },
    );

    testWidgets(
      'horizontal swipe advances pages when the next page is a long image',
      (tester) async {
        // Page 0 is normal, page 1 is long.
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(
              imageUrls: const [
                'https://example.com/normal.jpg',
                'https://example.com/long.jpg',
              ],
              knownAspects: const {
                'https://example.com/normal.jpg': 2.0,
                'https://example.com/long.jpg': 0.5,
              },
              imageBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('1/2'), findsOneWidget);

        await tester.fling(find.byType(PageView), const Offset(-300, 0), 2000);
        await tester.pumpAndSettle();

        expect(
          find.text('2/2'),
          findsOneWidget,
          reason: 'paging onto a long image page should still advance',
        );
      },
    );

    testWidgets('REPRO: horizontal swipe on a genuinely tall long-image page '
        'advances to the next page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageViewerScreen(
            imageUrls: const [
              'https://example.com/long.jpg',
              'https://example.com/normal.jpg',
            ],
            knownAspects: const {
              'https://example.com/long.jpg': 0.5,
              'https://example.com/normal.jpg': 2.0,
            },
            // Inject genuinely tall content so the long-image page's
            // SingleChildScrollView is actually scrollable (matches a real
            // loaded long image).
            imageBuilder: (url) {
              if (url.contains('long')) {
                return Container(height: 2000, color: Colors.red);
              }
              return Container(height: 200, width: 400, color: Colors.blue);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(
        find.text('2/2'),
        findsOneWidget,
        reason: 'paging from a tall scrollable long-image page must work',
      );
    });

    // The real-world bug report: real finger swipes are rarely perfectly
    // horizontal. A swipe with a vertical component on a normal-image page
    // must still page, not get captured by the swipe-down-to-dismiss handler.
    testWidgets(
      'REPRO: slightly-diagonal swipe from a normal image still pages '
      '(dismiss must not steal it)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(
              imageUrls: const [
                'https://example.com/normal.jpg',
                'https://example.com/long.jpg',
              ],
              knownAspects: const {
                'https://example.com/normal.jpg': 2.0,
                'https://example.com/long.jpg': 0.5,
              },
              imageBuilder: (url) => url.contains('long')
                  ? Container(height: 2000, color: Colors.red)
                  : Container(height: 200, width: 400, color: Colors.blue),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('1/2'), findsOneWidget);

        // Mostly-horizontal swipe with a small vertical component, like a real
        // finger.
        await tester.fling(
          find.byType(PageView),
          const Offset(-400, -40),
          2000,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('2/2'),
          findsOneWidget,
          reason: 'a mostly-horizontal swipe must page, not dismiss',
        );
      },
    );

    testWidgets(
      'REPRO: slightly-diagonal swipe from a long image still pages back',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageViewerScreen(
              imageUrls: const [
                'https://example.com/normal.jpg',
                'https://example.com/long.jpg',
              ],
              initialIndex: 1,
              knownAspects: const {
                'https://example.com/normal.jpg': 2.0,
                'https://example.com/long.jpg': 0.5,
              },
              imageBuilder: (url) => url.contains('long')
                  ? Container(height: 2000, color: Colors.red)
                  : Container(height: 200, width: 400, color: Colors.blue),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('2/2'), findsOneWidget);

        // Swipe right (back to page 0) with a small vertical component.
        await tester.fling(find.byType(PageView), const Offset(400, -40), 2000);
        await tester.pumpAndSettle();

        expect(
          find.text('1/2'),
          findsOneWidget,
          reason: 'a mostly-horizontal swipe back must page from a long image',
        );
      },
    );
  });
}
