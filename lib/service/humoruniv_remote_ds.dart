import 'package:keek_news/model/board_post_dto.dart';
import 'package:keek_news/model/post_detail.dart';

class BoardListDsResult {
  const BoardListDsResult({
    required this.posts,
    required this.currentPage,
    required this.totalPage,
  });
  final List<BoardPostDto> posts;
  final int currentPage;
  final int totalPage;
}

abstract class HumorunivRemoteDs {
  Future<PostDetail> fetchPostDetail(String url);
  Future<BoardListDsResult> fetchBoardList(String table, int page, String sort);
}
