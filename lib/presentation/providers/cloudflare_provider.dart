import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humoruniv/data/datasources/cloudflare_cookie_store.dart';
import 'package:humoruniv/presentation/providers/shared_preferences_provider.dart';

final cloudflareCookieStoreProvider =
    Provider.family<CloudflareCookieStore, String>((ref, domain) {
  final prefs = ref.read(sharedPreferencesProvider);
  return CloudflareCookieStore(prefs, domain);
});

final cfCookieStatusProvider = StateProvider.family<bool, String>((ref, domain) {
  final store = ref.read(cloudflareCookieStoreProvider(domain));
  return store.hasValidCookies;
});
