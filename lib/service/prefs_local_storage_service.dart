import 'package:keek_news/service/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsLocalStorageService implements LocalStorageService {
  PrefsLocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  bool containsKey(String key) => _prefs.containsKey(key);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
