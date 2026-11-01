import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/api/following_pagination.dart';

void main() {
  test('keeps opaque Following cursor and skips stale/zero aliases', () {
    expect(followingNextCursor({'maxCursor': 0, 'minCursor': 'page-token'}, '0'), 'page-token');
    expect(followingNextCursor({'maxCursor': 'old', 'minCursor': 'new'}, 'old'), 'new');
    expect(followingNextCursor({'nextCursor': '9223372036854775808'}, '0'), '9223372036854775808');
    expect(followingNextCursor({'maxCursor': 123.0}, '0'), '123');
  });
  test('no invented cursor or timestamp when server omits continuation', () {
    expect(followingNextCursor({'hasMore': true, 'maxCursor': 0}, '0'), '0');
    expect(followingHasMore({'hasMore': true}, 30, false), true);
    expect(followingHasMore({'hasMore': false}, 30, true), false);
  });
  test('walks Following pages beyond thirty using returned tokens', () {
    var cursor = '0';
    var total = 0;
    for (final next in ['page-a', 'page-b', 'page-c']) {
      final data = {'maxCursor': 0, 'minCursor': next, 'hasMore': true};
      final result = followingNextCursor(data, cursor);
      expect(result, isNot(cursor));
      expect(followingHasMore(data, 30, result != cursor), true);
      total += 30;
      cursor = result;
    }
    expect(total, 90);
  });
}
