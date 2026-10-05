import 'package:shared_preferences/shared_preferences.dart';

/// Tiny key/value store for per-user UI preferences (e.g. rows per page).
/// Screens depend on this interface, not on a plugin, so tests use memory.
abstract interface class KeyValueStore {
  int? getInt(String key);
  Future<void> setInt(String key, int value);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, int> _data = {};

  @override
  int? getInt(String key) => _data[key];

  @override
  Future<void> setInt(String key, int value) async => _data[key] = value;
}

class SharedPrefsKeyValueStore implements KeyValueStore {
  const SharedPrefsKeyValueStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }
}

/// App-wide preference store. `main` swaps in the persistent one.
abstract final class AppPrefs {
  static KeyValueStore store = MemoryKeyValueStore();

  static Future<void> initPersistent() async {
    store = SharedPrefsKeyValueStore(await SharedPreferences.getInstance());
  }
}
