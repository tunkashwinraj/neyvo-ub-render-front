/// Lightweight in-memory TTL cache for sidebar / SWR patterns.
/// Cleared on sign-out and when [NeyvoPulseApi.setDefaultAccountId] changes account.
class ApiResponseCache {
  ApiResponseCache._();

  static final Map<String, ({dynamic data, DateTime expiresAt})> _store = {};

  static dynamic get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.data;
  }

  static void set(
    String key,
    dynamic data, {
    Duration ttl = const Duration(seconds: 60),
  }) {
    _store[key] = (data: data, expiresAt: DateTime.now().add(ttl));
  }

  static void invalidate(String key) => _store.remove(key);

  static void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  static void clear() => _store.clear();
}
