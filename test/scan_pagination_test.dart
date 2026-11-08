import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/api/scan_pagination.dart';

void main() {
  test('zero cursor does not hide minCursor or camel-case maxCursor', () {
    expect(scanNextCursor({'cursor': 0, 'maxCursor': '123'}, 0), 123);
    expect(scanNextCursor({'maxCursor': 0, 'minCursor': '456'}, 0), 456);
    expect(scanNextCursor({'cursor': 123, 'min_cursor': 456}, 123), 456);
  });
  test('explicit end flag wins over full page', () {
    for (final flag in [false, 0, '0', 'false']) {
      expect(scanHasMore({'hasMore': flag}, 30, true), false);
    }
  });
  test('scan continues through multiple thirty-item pages', () {
    for (final limit in [50, 100, 200, 0]) {
      var found = 0;
      var cursor = 0;
      var pages = 0;
      while (limit == 0 || found < limit) {
        pages++;
        final data = {
          'cursor': 0,
          'minCursor': pages * 30,
          'hasMore': pages < 8,
        };
        final next = scanNextCursor(data, cursor);
        found += limit > 0 && limit - found < 30 ? limit - found : 30;
        if (!scanHasMore(data, 30, next != cursor)) break;
        cursor = next;
      }
      expect(found, limit == 0 ? 240 : limit);
      expect(pages, greaterThan(1));
    }
  });
  test('missing continuation is reported instead of claiming complete', () {
    expect(() => scanHasMore({'hasMore': true}, 30, false), throwsException);
  });
}
