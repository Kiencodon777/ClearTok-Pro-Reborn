// Cursor values are opaque: never derive them from item counts or creation times.
int scanNextCursor(Map<String, dynamic> data, int current) {
  for (final key in [
    'cursor',
    'maxCursor',
    'max_cursor',
    'minCursor',
    'min_cursor',
  ]) {
    final value = int.tryParse(data[key]?.toString() ?? '');
    if (value != null && value > 0 && value != current) return value;
  }
  return current;
}

bool scanHasMore(Map<String, dynamic> data, int count, bool cursorAdvanced) {
  final flag = data['hasMore'] ?? data['has_more'];
  if (flag == false || flag == 0 || flag == '0' || flag == 'false') {
    return false;
  }
  if (count > 0 &&
      !cursorAdvanced &&
      (flag == true || flag == 1 || flag == '1' || flag == 'true')) {
    throw Exception(
      'TikTok báo còn dữ liệu nhưng thiếu cursor tiếp theo; kết quả quét chưa đầy đủ.',
    );
  }
  return count > 0 && cursorAdvanced;
}
