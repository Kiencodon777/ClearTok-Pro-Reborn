// Following cursors are opaque server values, not video timestamps or offsets.
String followingNextCursor(Map<String, dynamic> data, String current) {
  for (final key in ['maxCursor', 'max_cursor', 'minCursor', 'min_cursor', 'nextCursor', 'next_cursor', 'cursor']) {
    final raw = data[key];
    if (raw == null || raw is bool || raw is Map || raw is List) continue;
    final value = raw is num && raw.isFinite && raw == raw.roundToDouble()
        ? raw.toInt().toString() : raw.toString().trim();
    if (value.isNotEmpty && value != '0' && value != '-1' && value != current) return value;
  }
  return current;
}

bool followingHasMore(Map<String, dynamic> data, int count, bool advanced) {
  final flag = data['hasMore'] ?? data['has_more'];
  if ([false, 0, '0', 'false'].contains(flag)) return false;
  return count > 0 && (advanced || [true, 1, '1', 'true'].contains(flag));
}
