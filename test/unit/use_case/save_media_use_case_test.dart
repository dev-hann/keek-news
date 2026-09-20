import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/download_progress.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/media_save/media_save_repo.dart';
import 'package:keek_news/use_case/save_media_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockMediaSaveRepo extends Mock implements MediaSaveRepo {}

void main() {
  late _MockMediaSaveRepo repo;

  setUpAll(() {
    registerFallbackValue(
      const DownloadProgress(receivedBytes: 0, totalBytes: 0),
    );
  });

  setUp(() {
    repo = _MockMediaSaveRepo();
  });

  group('SaveMediaUseCase', () {
    test('delegates image targets to saveImage', () async {
      when(
        () => repo.saveImage(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => const Right<MediaSaveFailure, Unit>(unit));

      final useCase = SaveMediaUseCase(repo);
      final result = await useCase(MediaTarget.image('https://x/a.jpg'));

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      verify(() => repo.saveImage('https://x/a.jpg')).called(1);
      verifyNever(() => repo.saveVideo(any()));
    });

    test('delegates video targets to saveVideo', () async {
      when(
        () => repo.saveVideo(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => const Right<MediaSaveFailure, Unit>(unit));

      final useCase = SaveMediaUseCase(repo);
      final result = await useCase(
        MediaTarget.video(const VideoBlock(url: 'https://x/v.mp4')),
      );

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      verify(() => repo.saveVideo('https://x/v.mp4')).called(1);
    });

    test(
      'external embeds return Left(unexpected) without touching the repo',
      () async {
        final useCase = SaveMediaUseCase(repo);
        final result = await useCase(
          MediaTarget.video(const VideoBlock(url: 'https://youtu.be/x')),
        );

        expect(
          result.fold((f) => f.type, (_) => null),
          MediaSaveFailureType.unexpected,
        );
        verifyNever(() => repo.saveImage(any()));
        verifyNever(() => repo.saveVideo(any()));
      },
    );

    test('forwards progress callback', () async {
      final seen = <DownloadProgress>[];
      when(
        () => repo.saveImage(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((inv) async {
        (inv.namedArguments[#onProgress] as void Function(DownloadProgress))(
          const DownloadProgress(receivedBytes: 1, totalBytes: 2),
        );
        return const Right<MediaSaveFailure, Unit>(unit);
      });

      final useCase = SaveMediaUseCase(repo);
      await useCase(MediaTarget.image('https://x/a.jpg'), onProgress: seen.add);

      expect(seen.single.percent, 50);
    });

    test('cancel forwards to the repo', () {
      final useCase = SaveMediaUseCase(repo);
      useCase.cancel(MediaTarget.image('https://x/a.jpg'));

      verify(() => repo.cancel('https://x/a.jpg')).called(1);
    });
  });
}
