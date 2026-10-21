import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/blocked_image.dart';
import 'package:keek_news/model/failures.dart';
import 'package:keek_news/repository/blocked_image/blocked_image_repo.dart';
import 'package:keek_news/service/image_hash_service.dart';
import 'package:keek_news/use_case/block_image_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockBlockedImageRepo extends Mock implements BlockedImageRepo {}

class FakeImageHashService implements ImageHashService {
  const FakeImageHashService(this.hash);

  final String? hash;

  @override
  Future<String?> hashFor(String url) async => hash;
}

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

  group('BlockImageUseCase fingerprints', () {
    test('add should capture the fingerprint when hashing succeeds', () async {
      when(() => repo.add(any())).thenAnswer((_) async {});
      final useCaseWithHash = BlockImageUseCase(
        repo,
        hashService: const FakeImageHashService('abcdef0123456789'),
      );

      await useCaseWithHash.add('https://x/a.jpg');

      final captured =
          verify(() => repo.add(captureAny())).captured.single as BlockedImage;
      expect(captured.hash, 'abcdef0123456789');
    });

    test('add should store a URL-only entry when hashing fails', () async {
      when(() => repo.add(any())).thenAnswer((_) async {});
      final useCaseNoHash = BlockImageUseCase(
        repo,
        hashService: const FakeImageHashService(null),
      );

      await useCaseNoHash.add('https://x/a.jpg');

      final captured =
          verify(() => repo.add(captureAny())).captured.single as BlockedImage;
      expect(captured.hash, isNull);
    });

    test('isHashBlocked should delegate to the repo', () async {
      when(() => repo.isHashBlocked(any())).thenReturn(true);

      expect(useCase.isHashBlocked('0123456789abcdef'), isTrue);
      verify(() => repo.isHashBlocked('0123456789abcdef')).called(1);
    });
  });
}
