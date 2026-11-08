import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/services/diagnostic_log.dart';

void main() {
  test('logs only approved diagnostic values, never credentials or bodies', () {
    final log = DiagnosticLog();
    log.record(
      'unlike',
      -2,
      details: {
        'cookie': 'secret',
        'csrfToken': 'secret',
        'raw': 'secret',
        'path': '/@private-user',
        'response_kind': 'html',
        'http_status': 200,
        'content_type': 'secret',
        'elapsed_ms': 'secret',
      },
    );
    expect(log.export(), isNot(contains('secret')));
    expect(log.export(), isNot(contains('private-user')));
    expect(log.entries.single['response_kind'], 'html');
    for (var i = 0; i < 220; i++) {
      log.record('unlike', i);
    }
    expect(log.entries.length, 200);
    log.clear();
    expect(log.entries, isEmpty);
  });
}
