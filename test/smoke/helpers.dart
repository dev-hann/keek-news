import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Boots what a smoke test needs on the host.
///
/// flutter_test's binding is required for platform channels (PackageInfo,
/// charset_converter), but it also answers every `HttpClient` request with
/// 400. Smoke tests exist to hit live servers, so the real client is handed
/// back right after the binding starts. Call once at the top of `main()`,
/// before any test body creates a client.
void ensureLiveNetwork() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
}
