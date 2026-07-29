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
    test('should return list of PostDto when fetchMainPage succeeds', () async {
      const testHtml = '''
      <html><body>
      <a href="/rd.html?path=/m/main/pds/1&url=/board/read.html&table=pds&number=100">
        <li id="pds_best_li_100">
          <span id="title_chk_pds-100">Test Post</span>
          <em>50</em>
        </li>
      </a>
      </body></html>
      ''';
      when(() => mockHtmlClient.get(any())).thenAnswer((_) async => testHtml);

      final result = await remoteDs.fetchMainPage();

      expect(result, isNotEmpty);
      expect(result.first.id, equals(100));
      expect(result.first.title, equals('Test Post'));
      expect(result.first.recommendCount, equals(50));
      verify(() => mockHtmlClient.get(any())).called(1);
    });

    test('should throw ServerFailure when fetchMainPage throws', () async {
      when(
        () => mockHtmlClient.get(any()),
      ).thenThrow(Exception('Network error'));

      expect(() => remoteDs.fetchMainPage(), throwsA(isA<ServerFailure>()));
    });

    test('should call get with correct main page url', () async {
      when(
        () => mockHtmlClient.get(any()),
      ).thenAnswer((_) async => '<html></html>');

      await remoteDs.fetchMainPage();

      verify(() => mockHtmlClient.get('/main.html')).called(1);
    });

    test('should return PostDetail when fetchPostDetail succeeds', () async {
      const testHtml = '''
      <html><head><title>테스트 글</title></head><body>
      <div id="read_profile_td">
        <span class="hu_nick_txt">작성자</span>
      </div>
      <div id="read_profile_desc">
        <span class="etc">작성 2026-05-15 11:00:00</span>
        <span class="ok"><span id="ok_div">100</span></span>
        <span class="notok"><span id="not_ok_span">5</span></span>
      </div>
      <div class="body_editor"><p>본문 내용</p></div>
      </body></html>
      ''';
      when(() => mockHtmlClient.get(any())).thenAnswer((_) async => testHtml);

      final result = await remoteDs.fetchPostDetail(
        '/board/read.html?table=pds&number=123',
      );

      expect(result.title, '테스트 글');
      expect(result.author, '작성자');
      verify(
        () => mockHtmlClient.get('/board/read.html?table=pds&number=123'),
      ).called(1);
    });

    test('should throw ServerFailure when fetchPostDetail fails', () async {
      when(() => mockHtmlClient.get(any())).thenThrow(Exception('fail'));

      expect(
        () => remoteDs.fetchPostDetail('/board/read.html?table=pds&number=123'),
        throwsA(isA<ServerFailure>()),
      );
    });

    test(
      'should return BoardListDsResult when fetchBoardList succeeds',
      () async {
        const testHtml = '''
      <html><body>
      <div class="post_item">
        <a class="post_link" href="/rd.html?url=/board/read.html&table=pds&number=100" data-number="100">
          <span class="link_hover">Board Test Post</span>
          <span class="hu_nick_txt">user1</span>
          <span class="blk">
            <span class="ok_num">50</span>
            <span class="not_ok_num">2</span>
            <span class="comment_num">10</span>
          </span>
        </a>
      </div>
      </body></html>
      ''';
        when(() => mockHtmlClient.get(any())).thenAnswer((_) async => testHtml);

        final result = await remoteDs.fetchBoardList('pds', 0, '');

        expect(result.posts, isNotEmpty);
        expect(result.posts.first.title, 'Board Test Post');
        verify(
          () => mockHtmlClient.get('/board/list.html?table=pds&pg=0'),
        ).called(1);
      },
    );

    test('should throw ServerFailure when fetchBoardList fails', () async {
      when(() => mockHtmlClient.get(any())).thenThrow(Exception('fail'));

      expect(
        () => remoteDs.fetchBoardList('pds', 0, ''),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('should include sort param in fetchBoardList URL', () async {
      when(
        () => mockHtmlClient.get(any()),
      ).thenAnswer((_) async => '<html></html>');

      await remoteDs.fetchBoardList('pds', 1, 'day');

      verify(
        () => mockHtmlClient.get('/board/list.html?table=pds&pg=1&sort=day'),
      ).called(1);
    });
  });
}
