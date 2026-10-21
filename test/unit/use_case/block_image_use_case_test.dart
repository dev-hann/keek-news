import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockBlockedImageRepo extends Mock implements BlockedImageRepo {}

void main() {
  late MockBlockedImageRepo repo;
  late BlockImageUseCase useCase;

  setUpAll(() {
    registerFallbackValue(
      BlockedImage(url: '', blockedAt: DateTime.fromMillisecondsSinceEpoch(0)),
    );
  });

  setUp(() {
    repo = MockBlockedImageRepo();
    useCase = BlockImageUseCase(repo);
  });

  group('BlockImageUseCase', () {
    test('getAll should return right with images', () async {
      final images = [
        BlockedImage(
          url: 'https://x/a.jpg',
          blockedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ];
      when(() => repo.getAll()).thenAnswer((_) async => images);

      final result = await useCase.getAll();

      expect(result, Right<Failure, List<BlockedImage>>(images));
    });

    test('getAll should return left on repo failure', () async {
      when(repo.getAll).thenThrow(Exception('boom'));

      final result = await useCase.getAll();

      expect(result.isLeft(), isTrue);
    });

    test('add should persist a BlockedImage for the url', () async {
      when(() => repo.add(any())).thenAnswer((_) async {});

      final result = await useCase.add('https://x/a.jpg');

      expect(result, const Right<Failure, Unit>(unit));
      final captured =
          verify(() => repo.add(captureAny())).captured.single as BlockedImage;
      expect(captured.url, 'https://x/a.jpg');
    });

    test('remove should forward the url', () async {
      when(() => repo.remove(any())).thenAnswer((_) async {});

      final result = await useCase.remove('https://x/a.jpg');

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => repo.remove('https://x/a.jpg')).called(1);
    });

    test('changes should forward the repo stream', () async {
      final controller = StreamController<void>.broadcast();
      addTearDown(controller.close);
      when(() => repo.changes).thenAnswer((_) => controller.stream);

      var fired = 0;
      final subscription = useCase.changes.listen((_) => fired++);
      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(fired, 1);
      await subscription.cancel();
    });
  });
}
