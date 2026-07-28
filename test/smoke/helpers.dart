import 'dart:convert';
import 'dart:io';

const _mobileUA =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Mobile Safari/537.36';

const _desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

Future<String> fetchHtml(
  String pathOrUrl, {
  String baseUrl = 'https://m.humoruniv.com',
  String encoding = 'cp949',
  bool desktop = false,
}) async {
  final fullUrl = pathOrUrl.startsWith('http')
      ? pathOrUrl
      : '$baseUrl$pathOrUrl';
  final ua = desktop ? _desktopUA : _mobileUA;

  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(fullUrl));
    request.headers.set('User-Agent', ua);
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      [],
      (acc, chunk) => acc..addAll(chunk),
    );

    if (encoding == 'utf-8' || encoding == 'utf8') {
      return utf8.decode(bytes);
    }

    final tempFile = File(
      '${Directory.systemTemp.path}/smoke_${DateTime.now().millisecondsSinceEpoch}.html',
    );
    await tempFile.writeAsBytes(bytes);

    final result = await Process.run(
      'iconv',
      ['-f', encoding, '-t', 'utf-8', tempFile.path],
    );
    await tempFile.delete();

    if (result.exitCode != 0) {
      throw Exception('iconv failed: ${result.stderr}');
    }

    return result.stdout as String;
  } finally {
    client.close();
  }
}
