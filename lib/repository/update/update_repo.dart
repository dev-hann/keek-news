import 'package:keek_news/model/app_release.dart';

abstract class UpdateRepo {
  Future<AppRelease> getLatestRelease();
}
