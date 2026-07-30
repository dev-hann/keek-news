import 'package:happy_news/core/errors/failures.dart';
import 'package:happy_news/core/network/html_client.dart';
import 'package:happy_news/data/datasources/humoruniv_remote_ds.dart';
import 'package:happy_news/data/parsers/board_list_parser.dart';
import 'package:happy_news/data/parsers/post_detail_parser.dart';
import 'package:happy_news/domain/entities/post_detail.dart';

class HumorunivRemoteDsImpl implements HumorunivRemoteDs {
  const HumorunivRemoteDsImpl({required this.htmlClient});
  final HtmlClient htmlClient;

  @override
  Future<PostDetail> fetchPostDetail(String url) async {
    try {
      final html = await htmlClient.get(url);
      return PostDetailParser.parse(html);
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<BoardListDsResult> fetchBoardList(
    String table,
    int page,
    String sort,
  ) async {
    try {
      final sortParam = sort.isNotEmpty ? '&sort=$sort' : '';
      final path = '/board/list.html?table=$table&pg=$page$sortParam';
      final html = await htmlClient.get(path);
      final result = BoardListParser.parse(html);
      return BoardListDsResult(
        posts: result.posts,
        currentPage: result.currentPage,
        totalPage: result.totalPage,
      );
    } on ServerFailure {
      rethrow;
    } on NetworkFailure {
      rethrow;
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
