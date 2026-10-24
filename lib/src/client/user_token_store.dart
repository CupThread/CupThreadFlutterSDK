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
  String? _ephemeralToken;
  Future<String>? _pendingResolution;
  Future<void>? _pendingWrite;

  UserTokenStore([TokenStorageAdapter? storage])
      : _storage = storage ?? MemoryTokenStorage();

  static UserTokenStore get shared => _shared ??= UserTokenStore();

  static void configure(TokenStorageAdapter storage) {
    _shared = UserTokenStore(storage);
  }

  /// The storage adapter backing this store.
  ///
  /// Other durable SDK state (changelog seen versions) shares this adapter
  /// so hosts configure persistence in one place via [configure].
  TokenStorageAdapter get adapter => _storage;

  /// Resolves the durable identity from storage exactly once; concurrent
  /// callers share the same in-flight [Future].
  Future<String> _resolve() {
    final pending = _pendingResolution;
    if (pending != null) return pending;
    return _pendingResolution = _resolveDurableToken();
  }

  /// Persists [token] through a single serialized write queue so the
  /// identity installed last always wins in storage, even when a
  /// mint-and-persist from [_resolveDurableToken] is still in flight while
  /// [setToken]/[resetToken] install a newer identity. Write failures are
  /// swallowed, matching the previous behavior, without breaking the queue.
  Future<void> _persist(String token) {
    final previous = _pendingWrite ?? Future<void>.value();
    final guarded = previous
        .then((_) => _storage.setItem(storageKey, token))
        .catchError((Object _) {});
    _pendingWrite = guarded;
    return guarded;
  }

  Future<String> _resolveDurableToken() async {
    final cachedAtStart = _cachedToken;
    if (cachedAtStart != null) return cachedAtStart;

    String? stored;
    try {
      stored = await _storage.getItem(storageKey);
    } catch (_) {
      // Storage read failed; fall through to minting a fresh identity.
    }

    // setToken/resetToken may have run while the storage read was in
    // flight; an explicitly provided token always wins over storage.
    final raced = _cachedToken;
    if (raced != null) return raced;

    final existing = stored?.trim() ?? '';
    if (existing.isNotEmpty) {
      _cachedToken = existing;
      return existing;
    }

    final newToken = generateUuid();
    _cachedToken = newToken;
    await _persist(newToken);
    // setToken/resetToken may have installed a newer identity while the
    // persistence write was in flight; report the current one.
    return _cachedToken ?? newToken;
  }

  /// Synchronously returns the currently held identity token.
  ///
  /// Until the durable identity has been restored from storage (the very
  /// first access after process start), this returns a stable ephemeral
  /// token that is neither cached nor persisted, so it can never overwrite
  /// a token that exists in storage. Prefer [getToken] — or mount widgets
  /// through `CupThreadTheme`, which defers its child until resolution
  /// completes — whenever the durable identity matters.
  String get token {
    final cached = _cachedToken;
    if (cached != null) return cached;
    // Warm the durable cache in the background; the ephemeral token
    // deliberately stays out of [_cachedToken] until then.
    _resolve();
    return _ephemeralToken ??= generateUuid();
  }

  /// Asynchronously retrieves or restores token from storage, minting and
  /// persisting a fresh UUID when storage has none. Concurrent calls share
  /// a single storage read.
  Future<String> getToken() async {
    final cached = _cachedToken;
    if (cached != null) return cached;
    return _resolve();
  }

  /// Overrides or sets custom user token.
  Future<void> setToken(String token) async {
    _cachedToken = token;
    await _persist(token);
  }

  /// Resets token to a newly generated UUID.
  Future<String> resetToken() async {
    final newToken = generateUuid();
    _cachedToken = newToken;
    await _persist(newToken);
    return newToken;
  }
}
