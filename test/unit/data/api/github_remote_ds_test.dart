import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/datasources/github_remote_ds_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late GitHubRemoteDsImpl remoteDs;

  setUp(() {
    mockDio = MockDio();
    remoteDs = GitHubRemoteDsImpl(dio: mockDio);
  });

  const validJson = '''
  {
    "tag_name": "v1.2.0",
    "html_url": "https://github.com/dev-hann/humoruniv/releases/tag/v1.2.0",
    "body": "Release notes",
    "assets": [
      {
        "name": "app-release.apk",
        "browser_download_url": "https://github.com/dev-hann/humoruniv/releases/download/v1.2.0/app-release.apk"
      }
    ]
  }
  ''';

  group('GitHubRemoteDsImpl', () {
    test(
      'should return JSON string when fetchLatestRelease succeeds',
      () async {
        when(
          () => mockDio.get<String>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response<String>(
            data: validJson,
            statusCode: 200,
            requestOptions: RequestOptions(),
          ),
        );

        final result = await remoteDs.fetchLatestRelease();

        expect(result, isNotNull);
        expect(result, contains('v1.2.0'));
      },
    );

    test('should call GitHub API with correct URL', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<String>(
          data: validJson,
          statusCode: 200,
          requestOptions: RequestOptions(),
        ),
      );

      await remoteDs.fetchLatestRelease();

      verify(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).called(1);
    });

    test('should throw Exception when Dio throws DioException', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(() => remoteDs.fetchLatestRelease(), throwsA(isA<Exception>()));
    });

    test('should throw Exception when response data is null', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async =>
            Response<String>(statusCode: 200, requestOptions: RequestOptions()),
      );

      expect(() => remoteDs.fetchLatestRelease(), throwsA(isA<Exception>()));
    });

    test('should throw Exception on 404 response', () async {
      when(
        () => mockDio.get<String>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          response: Response(statusCode: 404, requestOptions: RequestOptions()),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(() => remoteDs.fetchLatestRelease(), throwsA(isA<Exception>()));
    });
  });
}
