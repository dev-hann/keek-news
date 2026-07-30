import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/app_release.dart';
import 'package:keek_news/model/app_release_dto.dart';

void main() {
  group('AppReleaseDto', () {
    test('should convert to AppRelease entity with all fields', () {
      const dto = AppReleaseDto(
        version: '1.2.0',
        htmlUrl: 'https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0',
        downloadUrl:
            'https://github.com/dev-hann/humoruniv/releases/download/v1.2.0/app.apk',
        releaseNotes: '버그 수정',
      );

      final entity = dto.toEntity();

      expect(entity, isA<AppRelease>());
      expect(entity.version, '1.2.0');
      expect(entity.htmlUrl, contains('v1.2.0'));
      expect(entity.downloadUrl, contains('.apk'));
      expect(entity.releaseNotes, '버그 수정');
    });

    test('should convert to entity with nullable fields as null', () {
      const dto = AppReleaseDto(
        version: '1.0.0',
        htmlUrl: 'https://example.com',
      );

      final entity = dto.toEntity();

      expect(entity.version, '1.0.0');
      expect(entity.downloadUrl, isNull);
      expect(entity.releaseNotes, isNull);
    });

    test('should preserve all fields during conversion', () {
      const dto = AppReleaseDto(version: '', htmlUrl: '');

      final entity = dto.toEntity();

      expect(entity.version, isEmpty);
      expect(entity.htmlUrl, isEmpty);
    });
  });
}
