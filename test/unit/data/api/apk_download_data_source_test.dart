import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/data/datasources/apk_download_data_source_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late ApkDownloadDataSourceImpl dataSource;
  late String reportedPath;

  setUp(() {
    mockDio = MockDio();
    reportedPath = '/tmp/fake_app.apk';
    dataSource = ApkDownloadDataSourceImpl(
      dio: mockDio,
      resolveSavePath: () async => reportedPath,
    );
  });

  group('ApkDownloadDataSourceImpl', () {
    test(
      'should call dio.download with url, save path, progress and cancel token',
      () async {
        when(
          () => mockDio.download(
            any(),
            any(),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        );

        await dataSource.download('https://example.com/app.apk', (_, __) {});

        verify(
          () => mockDio.download(
            'https://example.com/app.apk',
            '/tmp/fake_app.apk',
            onReceiveProgress: any(named: 'onReceiveProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);
      },
    );

    test('should return the save path on success', () async {
      when(
        () => mockDio.download(
          any(),
          any(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await dataSource.download(
        'https://example.com/app.apk',
        (_, __) {},
      );

      expect(result, '/tmp/fake_app.apk');
    });

    test('should expose the saved path after download', () async {
      when(
        () => mockDio.download(
          any(),
          any(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await dataSource.download('https://example.com/app.apk', (_, __) {});

      expect(dataSource.savedPath, '/tmp/fake_app.apk');
    });

    test('should forward progress callback to caller', () async {
      void Function(int, int)? capturedProgress;
      when(
        () => mockDio.download(
          any(),
          any(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        capturedProgress =
            invocation.namedArguments[#onReceiveProgress]
                as void Function(int, int)?;
        capturedProgress?.call(50, 100);
        capturedProgress?.call(100, 100);
        return Response<dynamic>(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );
      });

      final progresses = <int>[];
      await dataSource.download(
        'https://example.com/app.apk',
        (received, total) => progresses.add(received),
      );

      expect(progresses, [50, 100]);
    });

    test('should propagate exception when dio.download fails', () async {
      when(
        () => mockDio.download(
          any(),
          any(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => dataSource.download('https://example.com/app.apk', (_, __) {}),
        throwsA(isA<Exception>()),
      );
    });

    test('should cancel the cancel token when cancel is called', () async {
      CancelToken? capturedToken;
      when(
        () => mockDio.download(
          any(),
          any(),
          onReceiveProgress: any(named: 'onReceiveProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        capturedToken = invocation.namedArguments[#cancelToken] as CancelToken?;
        return Response<dynamic>(
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );
      });

      await dataSource.download('https://example.com/app.apk', (_, __) {});

      expect(capturedToken, isNotNull);
      expect(capturedToken!.isCancelled, false);

      dataSource.cancel();

      expect(capturedToken!.isCancelled, true);
    });
  });
}
