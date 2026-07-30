import 'package:keek_news/model/failures.dart';
import 'package:keek_news/model/post_detail.dart';
import 'package:keek_news/service/html_client.dart';
import 'package:keek_news/service/humoruniv_remote_ds.dart';
import 'package:keek_news/service/parser/board_list_parser.dart';
import 'package:keek_news/service/parser/post_detail_parser.dart';

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
