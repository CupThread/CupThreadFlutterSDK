import 'package:cupthread_feedback/cupthread_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the anonymous CupThread identity across app restarts.
///
/// The SDK itself ships no storage plugin (it is pure Dart), so wire any
/// key-value store you like via [UserTokenStore.configure] before mounting
/// `CupThreadTheme`. Without it the SDK falls back to in-memory storage and
/// mints a fresh anonymous identity on every launch.
class SharedPreferencesTokenStorage implements TokenStorageAdapter {
  SharedPreferencesTokenStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> getItem(String key) async => _prefs.getString(key);

  @override
  Future<void> setItem(String key, String value) async {
    await _prefs.setString(key, value);
  }
}
