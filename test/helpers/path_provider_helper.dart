import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Routes `getApplicationDocumentsPath()` (used by service_locator for cookie
/// jars) to a fresh temp directory in tests. Register in `setUpAll` of any
/// test that boots `configureDependencies`.
class _MockPathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final dir = await Directory.systemTemp.createTemp('keek_test_docs_');
    return dir.path;
  }
}

void setupPathProviderMock() {
  PathProviderPlatform.instance = _MockPathProviderPlatform();
}
