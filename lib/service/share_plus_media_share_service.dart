import 'package:keek_news/service/media_share_service.dart';
import 'package:share_plus/share_plus.dart';

class SharePlusMediaShareService implements MediaShareService {
  const SharePlusMediaShareService();

  @override
  Future<void> shareFile(String path) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
