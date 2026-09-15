import 'package:codex_quota_monitor/core/bounded_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bounded cache evicts the least recently used entry', () {
    final cache = BoundedCache<String, List<int>>(maxEntries: 2);

    cache.put('old', [1]);
    cache.put('kept', [2]);
    expect(cache.get('old'), [1]);
    cache.put('new', [3]);

    expect(cache.length, 2);
    expect(cache.get('kept'), isNull);
    expect(cache.get('old'), [1]);
    expect(cache.get('new'), [3]);
  });

  test('replacing a cache entry does not grow the cache', () {
    final cache = BoundedCache<String, List<int>>(maxEntries: 2);

    for (var i = 0; i < 1000; i++) {
      cache.put('rolling-24h', [i]);
    }

    expect(cache.length, 1);
    expect(cache.get('rolling-24h'), [999]);
  });
}
