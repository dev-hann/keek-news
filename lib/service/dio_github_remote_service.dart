import 'package:dio/dio.dart';
import 'package:keek_news/service/github_remote_service.dart';

class DioGitHubRemoteService implements GitHubRemoteService {
  DioGitHubRemoteService({Dio? dio})
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
      // Canonical repo name: GitHub's rename redirects (humoruniv,
      // happy-news) only last until those names are reused.
      '/repos/dev-hann/keek-news/releases/latest',
      options: Options(responseType: ResponseType.plain),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('GitHub API returned null data');
    }

    return data;
  }
}
