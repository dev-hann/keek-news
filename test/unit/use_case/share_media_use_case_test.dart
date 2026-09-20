import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/content_block.dart';
import 'package:keek_news/model/media_save_failure.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/repository/media_save/media_save_repo.dart';
import 'package:keek_news/use_case/share_media_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockMediaSaveRepo extends Mock implements MediaSaveRepo {}

void main() {
  late _MockMediaSaveRepo repo;

  setUpAll(() {
    registerFallbackValue(const MediaTargetVideoFallback());
  });

  setUp(() {
    repo = _MockMediaSaveRepo();
  });

  group('ShareMediaUseCase', () {
    test('delegates to repo.share', () async {
      final target = MediaTarget.image('https://x/a.jpg');
      when(
        () => repo.share(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => const Right<MediaSaveFailure, Unit>(unit));

      final useCase = ShareMediaUseCase(repo);
      final result = await useCase(target);

      expect(result, const Right<MediaSaveFailure, Unit>(unit));
      verify(() => repo.share(target)).called(1);
    });

    test('cancel forwards to the repo', () {
      final target = MediaTarget.video(
        const VideoBlock(url: 'https://x/v.mp4'),
      );
      final useCase = ShareMediaUseCase(repo);
      useCase.cancel(target);

      verify(() => repo.cancel('https://x/v.mp4')).called(1);
    });
  });
}

class MediaTargetVideoFallback extends MediaTarget {
  const MediaTargetVideoFallback() : super(url: '', kind: MediaKind.video);
}
