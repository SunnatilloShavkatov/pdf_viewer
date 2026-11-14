/// Small least-recently-used map for rendered page images.
class LruCache<K, V> {
  new(this.capacity);

  final int capacity;
  final Map<K, V> _entries = <K, V>{};

  V? operator [](K key) {
    final V? value = _entries.remove(key);
    if (value != null) {
      _entries[key] = value;
    }
    return value;
  }

  void operator []=(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}
