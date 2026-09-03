import '../utils/formatters.dart';

/// Optional storage delegate for persisting token across app restarts.
abstract class TokenStorageAdapter {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
}

/// In-memory storage adapter default.
class MemoryTokenStorage implements TokenStorageAdapter {
  final Map<String, String> _data = {};

  @override
  Future<String?> getItem(String key) async => _data[key];

  @override
  Future<void> setItem(String key, String value) async {
    _data[key] = value;
  }
}

/// Manages anonymous persistent user token UUID.
class UserTokenStore {
  static const String storageKey = 'cupthread_user_token_v1';
  static UserTokenStore? _shared;

  final TokenStorageAdapter _storage;
  String? _cachedToken;

  UserTokenStore([TokenStorageAdapter? storage])
      : _storage = storage ?? MemoryTokenStorage();

  static UserTokenStore get shared => _shared ??= UserTokenStore();

  static void configure(TokenStorageAdapter storage) {
    _shared = UserTokenStore(storage);
  }

  void _initToken() {
    _cachedToken ??= generateUuid();
  }

  /// Synchronously returns currently held token.
  String get token {
    if (_cachedToken == null) _initToken();
    return _cachedToken!;
  }

  /// Asynchronously retrieves or restores token from storage.
  Future<String> getToken() async {
    if (_cachedToken != null) {
      return _cachedToken!;
    }
    try {
      final stored = await _storage.getItem(storageKey);
      if (stored != null && stored.trim().isNotEmpty) {
        _cachedToken = stored.trim();
        return _cachedToken!;
      }
    } catch (_) {
      // Fallback
    }

    final newToken = generateUuid();
    _cachedToken = newToken;
    try {
      await _storage.setItem(storageKey, newToken);
    } catch (_) {}
    return newToken;
  }

  /// Overrides or sets custom user token.
  Future<void> setToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.setItem(storageKey, token);
    } catch (_) {}
  }

  /// Resets token to a newly generated UUID.
  Future<String> resetToken() async {
    final newToken = generateUuid();
    _cachedToken = newToken;
    try {
      await _storage.setItem(storageKey, newToken);
    } catch (_) {}
    return newToken;
  }
}
