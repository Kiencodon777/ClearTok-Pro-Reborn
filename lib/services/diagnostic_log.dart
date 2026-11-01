import 'dart:convert';
import 'package:flutter/foundation.dart';

class DiagnosticLog extends ChangeNotifier {
  static final instance = DiagnosticLog();
  final List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> get entries => List.unmodifiable(_entries);
  static const allowed = {'http_status', 'redirected', 'content_type',
    'response_length', 'response_kind', 'csrf_present', 'elapsed_ms',
    'login_redirect', 'verification_hint', 'browser_mode'};

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
