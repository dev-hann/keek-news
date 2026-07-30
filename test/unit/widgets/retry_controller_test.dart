import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/widgets/retry_controller.dart';

void main() {
  group('RetryController', () {
    group('ChangeNotifier integration', () {
      test('is a Listenable (ChangeNotifier)', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c, isA<Listenable>());
        expect(c, isA<ChangeNotifier>());
      });

      test('notifies listeners when auto-retry timer fires', () {
        fakeAsync((async) {
          var notifications = 0;
          final c = RetryController(
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);
          c.addListener(() => notifications++);

          c.recordFailure();
          expect(notifications, 0, reason: 'no notification on schedule');

          async.elapse(const Duration(milliseconds: 100));

          expect(
            notifications,
            greaterThan(0),
            reason:
                'listeners must be notified when timer fires so '
                'widgets can rebuild',
          );
          expect(c.attempt, 1);
          expect(c.hasError, isFalse);
        });
      });

      test('notifies once on exhaustion (so widgets can show retry hint)', () {
        fakeAsync((async) {
          var notifications = 0;
          final c = RetryController(maxAttempts: 1);
          addTearDown(c.dispose);
          c.addListener(() => notifications++);

          c.recordFailure();
          expect(
            notifications,
            1,
            reason: 'notifies once on exhaustion so widgets can rebuild',
          );

          async.elapse(const Duration(seconds: 5));

          expect(notifications, 1, reason: 'no further retries scheduled');
          expect(c.isExhausted, isTrue);
        });
      });
    });

    group('initial state', () {
      test('maxAttempts defaults to 3', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c.maxAttempts, 3);
      });

      test('retryDelay defaults to 500ms', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c.retryDelay, const Duration(milliseconds: 500));
      });

      test('attempt starts at 0', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c.attempt, 0);
      });

      test('hasError is false on fresh controller', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c.hasError, isFalse);
      });

      test('canAutoRetry is false on fresh controller', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c.canAutoRetry, isFalse);
      });

      test('isExhausted is false on fresh controller', () {
        final c = RetryController();
        addTearDown(c.dispose);
        expect(c.isExhausted, isFalse);
      });
    });

    group('after recordFailure (before retry timer fires)', () {
      test('hasError becomes true', () {
        fakeAsync((async) {
          final c = RetryController();
          addTearDown(c.dispose);

          c.recordFailure();

          expect(c.hasError, isTrue);
        });
      });

      test('canAutoRetry true when attempts remain', () {
        fakeAsync((async) {
          final c = RetryController();
          addTearDown(c.dispose);

          c.recordFailure();

          expect(c.canAutoRetry, isTrue);
        });
      });

      test('isExhausted false when attempts remain', () {
        fakeAsync((async) {
          final c = RetryController();
          addTearDown(c.dispose);

          c.recordFailure();

          expect(c.isExhausted, isFalse);
        });
      });

      test('isExhausted true on first failure when maxAttempts == 1', () {
        fakeAsync((async) {
          final c = RetryController(maxAttempts: 1);
          addTearDown(c.dispose);

          c.recordFailure();

          expect(c.isExhausted, isTrue);
          expect(c.canAutoRetry, isFalse);
        });
      });
    });

    group('after retry timer fires', () {
      test('hasError becomes false (new attempt starts)', () {
        fakeAsync((async) {
          final c = RetryController(
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);

          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));

          expect(c.hasError, isFalse);
          expect(c.attempt, 1);
        });
      });

      test('ChangeNotifier notifies on retry with new attempt number', () {
        fakeAsync((async) {
          var notifications = 0;
          var lastSeenAttempt = 0;
          final c = RetryController(
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);
          c.addListener(() {
            notifications++;
            lastSeenAttempt = c.attempt;
          });

          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));

          expect(notifications, 1);
          expect(lastSeenAttempt, 1);
        });
      });

      test('each failure+retry advances attempt by 1', () {
        fakeAsync((async) {
          final c = RetryController(
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);

          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));
          expect(c.attempt, 1);
          expect(c.hasError, isFalse);

          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));
          expect(c.attempt, 2);
          expect(c.hasError, isFalse);

          c.recordFailure();
          expect(c.attempt, 2);
          expect(c.hasError, isTrue);
          expect(c.isExhausted, isTrue);
        });
      });

      test('exhausted controller notifies but does NOT retry further', () {
        fakeAsync((async) {
          var notifications = 0;
          final c = RetryController(
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);
          c.addListener(() => notifications++);

          // First two failures schedule retries that fire and advance attempt.
          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));
          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));
          // Now attempt == 2 (maxAttempts - 1). Further failures exhaust.
          final notificationsBeforeExhaustion = notifications;

          for (var i = 0; i < 3; i++) {
            c.recordFailure();
            async.elapse(const Duration(milliseconds: 100));
          }

          expect(
            notifications,
            notificationsBeforeExhaustion + 3,
            reason: 'each exhausted recordFailure notifies once',
          );
          expect(c.attempt, 2);
          expect(c.isExhausted, isTrue);
        });
      });
    });

    group('manualRetry', () {
      test('clears error state', () {
        fakeAsync((async) {
          final c = RetryController(
            maxAttempts: 1,
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);

          c.recordFailure();
          expect(c.isExhausted, isTrue);

          c.manualRetry();

          expect(c.hasError, isFalse);
          expect(c.attempt, 0);
          expect(c.isExhausted, isFalse);
        });
      });

      test('cancels pending auto-retry timer', () {
        fakeAsync((async) {
          var notifications = 0;
          final c = RetryController();
          addTearDown(c.dispose);
          c.addListener(() => notifications++);

          c.recordFailure();
          c.manualRetry();

          async.elapse(const Duration(seconds: 5));

          expect(
            notifications,
            lessThan(2),
            reason: 'timer cancelled; only manualRetry notification fires',
          );
          expect(c.attempt, 0);
          expect(c.hasError, isFalse);
        });
      });
    });

    group('resetForUrl', () {
      test('resets everything when URL changes', () {
        fakeAsync((async) {
          final c = RetryController(maxAttempts: 1);
          addTearDown(c.dispose);

          c.recordFailure();
          expect(c.isExhausted, isTrue);

          c.resetForUrl('new-url', currentUrl: 'old-url');

          expect(c.attempt, 0);
          expect(c.hasError, isFalse);
          expect(c.isExhausted, isFalse);
        });
      });

      test('no-op when URL is unchanged', () {
        fakeAsync((async) {
          final c = RetryController(
            retryDelay: const Duration(milliseconds: 100),
          );
          addTearDown(c.dispose);

          c.recordFailure();
          async.elapse(const Duration(milliseconds: 100));
          expect(c.attempt, 1);

          c.resetForUrl('same', currentUrl: 'same');

          expect(c.attempt, 1);
        });
      });
    });

    group('dispose', () {
      test('cancels pending timer', () {
        fakeAsync((async) {
          var notifications = 0;
          final c = RetryController();
          c.addListener(() => notifications++);

          c.recordFailure();
          c.dispose();

          async.elapse(const Duration(seconds: 5));

          expect(notifications, 0);
        });
      });
    });
  });
}
