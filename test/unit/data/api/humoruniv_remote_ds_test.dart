import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/core/network/html_client.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockHtmlClient extends Mock implements HtmlClient {}

void main() {
  late MockHtmlClient mockHtmlClient;
  late HumorunivRemoteDsImpl remoteDs;

  setUp(() {
    mockHtmlClient = MockHtmlClient();
    remoteDs = HumorunivRemoteDsImpl(htmlClient: mockHtmlClient);
  });

  group('HumorunivRemoteDsImpl', () {
    group('fetchBoardList', () {
      test('should return BoardListDsResult when html is valid', () async {
        when(
          () => mockHtmlClient.get(any()),
        ).thenAnswer((_) async => '<html><body></body></html>');

        final result = await remoteDs.fetchBoardList('pds', 1, '');

        expect(result.currentPage, isA<int>());
        expect(result.totalPage, isA<int>());
        expect(result.posts, isA<List>());
      });

      test('should throw ServerFailure when htmlClient throws', () async {
        when(
          () => mockHtmlClient.get(any()),
        ).thenThrow(Exception('network error'));

        expect(
          () => remoteDs.fetchBoardList('pds', 1, ''),
          throwsA(isA<ServerFailure>()),
        );
      });
    });

    group('fetchPostDetail', () {
      test('should call htmlClient.get with url', () async {
        const url = '/board/read.html?table=pds&number=123';
        when(
          () => mockHtmlClient.get(any()),
        ).thenAnswer((_) async => '<html><body></body></html>');

        await remoteDs.fetchPostDetail(url);

        verify(() => mockHtmlClient.get(url)).called(1);
      });

      test('should throw ServerFailure when htmlClient throws', () async {
        when(
          () => mockHtmlClient.get(any()),
        ).thenThrow(Exception('network error'));

        expect(
          () => remoteDs.fetchPostDetail('/some/path'),
          throwsA(isA<ServerFailure>()),
        );
      });
    });
  });
}
