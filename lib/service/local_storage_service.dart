abstract class LocalStorageService {
  String? getString(String key);

  Future<void> setString(String key, String value);

  List<String>? getStringList(String key);

  Future<void> setStringList(String key, List<String> value);

  bool containsKey(String key);

  Future<void> remove(String key);
}
