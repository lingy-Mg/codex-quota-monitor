import 'dart:collection';

/// A small least-recently-used cache whose retained object graph is bounded.
class BoundedCache<K, V> {
  BoundedCache({required this.maxEntries}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  V? get(K key) {
    final value = _entries.remove(key);
    if (value != null) {
      _entries[key] = value;
    }
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  int get length => _entries.length;
}
