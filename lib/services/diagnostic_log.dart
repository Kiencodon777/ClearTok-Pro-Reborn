import 'dart:convert';
import 'package:flutter/foundation.dart';

class DiagnosticLog extends ChangeNotifier {
  static final instance = DiagnosticLog();
  final List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> get entries => List.unmodifiable(_entries);
  static const allowed = {'http_status', 'redirected', 'content_type',
    'response_length', 'response_kind', 'csrf_present', 'elapsed_ms',
    'login_redirect', 'verification_hint', 'browser_mode', 'secsdk_retry_status', 'secsdk_retry_length',
    'readback_attempted', 'readback_confirmed', 'readback_liked',
    'readback_http_status', 'readback_response_length', 'readback_redirected',
    'readback_verification_hint', 'readback_hydration_present',
    'readback_viewer_present', 'readback_same_session', 'readback_video_present',
    'readback_video_matches', 'readback_liked_present', 'readback_exception',
    'scan_count', 'scan_has_more', 'scan_cursor_changed', 'scan_min_cursor_changed', 'scan_max_cursor_changed',
    'scan_has_maxCursor', 'scan_has_max_cursor', 'scan_has_minCursor',
    'scan_has_min_cursor', 'scan_has_nextCursor', 'scan_has_next_cursor', 'scan_has_cursor'};

  void record(String action, int code, {Map<String, dynamic> details = const {}}) {
    _entries.add({'time': DateTime.now().toUtc().toIso8601String(),
      'action': action, 'code': code,
      for (final key in allowed)
        if (details[key] is num || details[key] is bool ||
            (key == 'response_kind' && ['json', 'html', 'empty', 'text'].contains(details[key])) ||
            (key == 'browser_mode' && ['mobile', 'desktop'].contains(details[key]))) key: details[key]});
    if (_entries.length > 200) _entries.removeAt(0);
    notifyListeners();
  }

  String export() => const JsonEncoder.withIndent('  ').convert(_entries);
  void clear() { _entries.clear(); notifyListeners(); }
}
