// Following cursors are opaque server values, not video timestamps or offsets.
String followingNextCursor(Map<String, dynamic> data, String current) {
  for (final key in ['maxCursor', 'max_cursor', 'nextCursor', 'next_cursor', 'cursor']) {
    final value = _cursorValue(data[key]);
    if (value != null) return value;
  }
  return current;
}

String followingNextMinCursor(Map<String, dynamic> data, String current) =>
    _cursorValue(data['minCursor']) ?? _cursorValue(data['min_cursor']) ?? current;

String? _cursorValue(dynamic raw) {
  if (raw == null || raw is bool || raw is Map || raw is List) return null;
  final value = raw is double && raw.isFinite && raw == raw.roundToDouble()
      ? raw.toInt().toString() : raw.toString().trim();
  return value.isEmpty || value == '-1' ? null : value;
}

bool followingHasMore(Map<String, dynamic> data, int count, bool advanced) {
  final flag = data['hasMore'] ?? data['has_more'];
  if ([false, 0, '0', 'false'].contains(flag)) return false;
  return count > 0 && (advanced || [true, 1, '1', 'true'].contains(flag));
}
