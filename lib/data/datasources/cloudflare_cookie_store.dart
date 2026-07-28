import 'package:shared_preferences/shared_preferences.dart';

class CloudflareCookieStore {
  static const _cookieKey = 'cf_cookies_';
  static const _timestampKey = 'cf_cookies_ts_';

  final SharedPreferences _prefs;
  final String domain;

  CloudflareCookieStore(this._prefs, this.domain);

  Future<void> saveCookies(Map<String, String> cookies) async {
    final cookieString = cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');
    await _prefs.setString('$_cookieKey$domain', cookieString);
    await _prefs.setInt(
      '$_timestampKey$domain',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? getCookieHeader() {
    final ts = _prefs.getInt('$_timestampKey$domain');
    if (ts == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > const Duration(hours: 12).inMilliseconds) return null;

    return _prefs.getString('$_cookieKey$domain');
  }

  bool get hasValidCookies => getCookieHeader() != null;

  Future<void> clear() async {
    await _prefs.remove('$_cookieKey$domain');
    await _prefs.remove('$_timestampKey$domain');
  }
}
