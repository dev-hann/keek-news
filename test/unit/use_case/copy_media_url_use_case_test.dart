import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/media_target.dart';
import 'package:keek_news/use_case/copy_media_url_use_case.dart';

void main() {
  group('CopyMediaUrlUseCase', () {
    testWidgets('writes the target url to the clipboard', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.startsWith('Clipboard.')) calls.add(call);
          return null;
        },
      );

      const useCase = CopyMediaUrlUseCase();
      await useCase(MediaTarget.image('https://x/a.jpg'));

      expect(calls, hasLength(1));
      expect(calls.single.method, 'Clipboard.setData');
      expect(
        (calls.single.arguments as Map<dynamic, dynamic>)['text'],
        'https://x/a.jpg',
      );
    });
  });
}
