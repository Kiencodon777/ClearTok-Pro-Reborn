import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../database/local_database.dart';

class AppRelease {
  final String version;
  final String notes;
  final Uri url;
  AppRelease(this.version, this.notes, this.url);
  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString() ?? '';
    final url = Uri.tryParse(json['url']?.toString() ?? '');
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) || url == null ||
        url.scheme != 'https' || url.host != 'github.com' ||
        !url.path.startsWith('/Kiencodon777/ClearTok-Pro-Reborn/releases/')) {
      throw const FormatException('Feed cập nhật không hợp lệ.');
    }
    final notes = json['notes']?.toString() ?? '';
    return AppRelease(version, notes.substring(0, notes.length > 6000 ? 6000 : notes.length), url);
  }
  bool newerThan(String current) {
    final a = version.split('.').map(int.parse).toList();
    final b = current.split('.').map(int.tryParse).toList();
    if (b.length != 3 || b.contains(null)) return false;
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i]!;
    }
    return false;
  }
}

class AppUpdates {
  static const currentVersion = String.fromEnvironment('APP_VERSION', defaultValue: '2.2.2');
  static const feedUrl = String.fromEnvironment('UPDATE_FEED_URL');
  static bool _checking = false;
  static final releasesUrl = Uri.parse('https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases');

  static Future<void> check(BuildContext context, LocalDatabase database, {bool manual = false}) async {
    if (_checking || (!manual && (feedUrl.isEmpty || database.updateSnoozedUntil > DateTime.now().millisecondsSinceEpoch))) return;
    _checking = true;
    try {
      AppRelease? release;
      String? notice;
      if (feedUrl.isEmpty) {
        notice = 'Repo đang riêng tư. Mở GitHub Releases và đăng nhập để xem bản mới. Phiên bản hiện tại: $currentVersion.';
      } else {
        final uri = Uri.parse(feedUrl);
        if (uri.scheme != 'https') throw const FormatException('Feed cần HTTPS.');
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200 || response.bodyBytes.length > 65536) throw const FormatException('Không đọc được feed cập nhật.');
        final candidate = AppRelease.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        if (candidate.newerThan(currentVersion)) {
          release = candidate;
        } else if (manual) {
          notice = 'Bạn đang dùng phiên bản mới nhất ($currentVersion).';
        } else { return; }
      }
      if (!context.mounted) return;
      final available = release;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161926),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cập nhật phần mềm'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7F1738), Color(0xFF114A4E)]), borderRadius: BorderRadius.circular(14)),
            child: const Column(children: [Icon(Icons.system_update, size: 44, color: Color(0xFF25F4EE)), SizedBox(height: 10), Text('ClearTok Pro Reborn', style: TextStyle(fontWeight: FontWeight.bold))])),
          const SizedBox(height: 16),
          Text(available == null ? notice! : 'ClearTok ${available.version} đã sẵn sàng.'),
          if (available != null) ...[const SizedBox(height: 16), const Text('Có gì mới', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(available.notes)],
          const SizedBox(height: 12),
          const Text('iOS: tải IPA rồi ký/cài lại bằng công cụ của bạn. App không tự cài bản cập nhật.', style: TextStyle(fontSize: 12, color: Color(0xFFBDC7D5))),
        ])),
        actions: [
          TextButton(onPressed: () { database.snoozeUpdates(); Navigator.pop(ctx); }, child: const Text('Nhắc tôi sau')),
          FilledButton(onPressed: () async {
            try {
              final opened = await launchUrl(available?.url ?? releasesUrl, mode: LaunchMode.externalApplication);
              if (!opened) throw StateError('Không mở được GitHub.');
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (_) {
              if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được liên kết cập nhật.')));
            }
          }, child: Text(available == null ? 'Mở GitHub Releases' : 'Tải ngay')),
        ],
      ));
    } catch (_) {
      if (manual && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa kiểm tra được cập nhật. Thử lại sau.')));
    } finally { _checking = false; }
  }
}
