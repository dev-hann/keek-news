import 'package:dio/dio.dart';
import 'package:keek_news/service/github_remote_ds.dart';

class GitHubRemoteDsImpl implements GitHubRemoteDs {
  GitHubRemoteDsImpl({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.github.com',
              headers: {'Accept': 'application/vnd.github+json'},
            ),
          );
  final Dio _dio;

  @override
  Future<String> fetchLatestRelease() async {
    final response = await _dio.get<String>(
      '/repos/dev-hann/humoruniv/releases/latest',
      options: Options(responseType: ResponseType.plain),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('GitHub API returned null data');
    }

    return data;
  }
}
