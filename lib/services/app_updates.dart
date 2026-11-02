import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../database/local_database.dart';
import '../ui/widgets/liquid_glass.dart';

class AppRelease {
  final String version;
  final String notes;
  final Uri url;
  AppRelease(this.version, this.notes, this.url);
  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString() ?? '';
    final url = Uri.tryParse(json['url']?.toString() ?? '');
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.startsWith('/Kiencodon777/ClearTok-Pro-Reborn/releases/')) {
      throw const FormatException('Feed cập nhật không hợp lệ.');
    }
    final notes = json['notes']?.toString() ?? '';
    return AppRelease(
      version,
      notes.substring(0, notes.length > 6000 ? 6000 : notes.length),
      url,
    );
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
  static const currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '2.3.33',
  );
  static const feedUrl = String.fromEnvironment('UPDATE_FEED_URL');
  static bool _checking = false;
  static final releasesUrl = Uri.parse(
    'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases',
  );

  /// Detailed built-in release notes displayed in the mobile Update Modal
  static const List<(IconData, String, String)> builtInReleaseHighlights = [
    (
      Icons.water_drop_rounded,
      'Hiệu ứng Giọt Nước Trong Suốt & Nảy Thanh Dock (GBox)',
      'Viên thuốc trượt phóng đại lớn hơn chiều cao thanh Dock, hoàn toàn trong suốt như nước pha lê kèm hiệu ứng thanh Dock lắc nảy đàn hồi theo chiều kéo.',
    ),
    (
      Icons.history_edu_rounded,
      'Tab Mới "Đã Xử Lý" & Tách Riêng Bộ Đếm 3 Mục',
      'Bổ sung tab thứ 4 dưới thanh Dock lưu trữ riêng biệt các video đã hủy Repost, đã Bỏ Thích và các kênh đã Hủy Follow để bạn dễ dàng xem và mở lại bất cứ lúc nào.',
    ),
    (
      Icons.touch_app_rounded,
      'Nhấn Giữ Video/Kênh Để Mở Ngược Lại Trên TikTok',
      'Giữ lâu vào bất kỳ video Repost, video Thích hoặc tài khoản Following nào để mở menu xem lại trực tiếp trên TikTok Web hoặc ứng dụng TikTok.',
    ),
    (
      Icons.verified_user_rounded,
      'Sửa Triệt Để Lỗi Quét Repost & Bỏ Thích (SecSDK CSRF)',
      'Tự động đồng bộ phiên Desktop WebApp và làm mới token bảo mật giúp quét hàng loạt và bỏ thích mượt mà trên mọi thiết bị.',
    ),
  ];

  static Future<void> check(
    BuildContext context,
    LocalDatabase database, {
    bool manual = false,
  }) async {
    if (_checking ||
        (!manual &&
            (feedUrl.isEmpty ||
                database.updateSnoozedUntil >
                    DateTime.now().millisecondsSinceEpoch))) {
      return;
    }
    _checking = true;
    try {
      AppRelease? release;
      String? notice;
      if (feedUrl.isEmpty) {
        notice =
            'Phiên bản hiện tại: v$currentVersion. Bạn có thể mở GitHub Releases để kiểm tra và tải bản cài đặt mới nhất.';
      } else {
        final uri = Uri.parse(feedUrl);
        if (uri.scheme != 'https') {
          throw const FormatException('Feed cần HTTPS.');
        }
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200 || response.bodyBytes.length > 65536) {
          throw const FormatException('Không đọc được feed cập nhật.');
        }
        final candidate = AppRelease.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        if (candidate.newerThan(currentVersion)) {
          release = candidate;
        } else if (manual) {
          notice = 'Bạn đang dùng phiên bản mới nhất (v$currentVersion).';
        } else {
          return;
        }
      }
      if (!context.mounted) return;
      final available = release;
      final hasCustomRemoteNotes =
          available != null &&
          available.notes.trim().isNotEmpty &&
          !available.notes.contains(
            'Bản cập nhật LapinTokk. Xem ghi chú trên GitHub Releases.',
          );

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ClearTokColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ClearTokColors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: ClearTokColors.cyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  available != null
                      ? 'Cập nhật v${available.version}'
                      : 'Thông tin phiên bản',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ClearTokColors.pink.withValues(alpha: 0.28),
                        ClearTokColors.cyan.withValues(alpha: 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 36,
                        color: ClearTokColors.cyan,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        available != null
                            ? 'LapinTokk Studio v${available.version} đã sẵn sàng!'
                            : 'LapinTokk Studio v$currentVersion',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available != null
                            ? 'Phiên bản đang cài: v$currentVersion → Bản mới: v${available.version}'
                            : notice!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ClearTokColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '✨ Có gì mới trong bản cập nhật:',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                if (hasCustomRemoteNotes) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      available.notes,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: ClearTokColors.text,
                      ),
                    ),
                  ),
                ],
                ...builtInReleaseHighlights.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ClearTokColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.$1,
                            size: 16,
                            color: ClearTokColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.$3,
                                style: const TextStyle(
                                  color: ClearTokColors.secondary,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '💡 iOS: Tải file .ipa mới về và ký/cài đè bằng GBox, ESign hoặc chứng chỉ của bạn để giữ nguyên dữ liệu.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ClearTokColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                database.snoozeUpdates();
                Navigator.pop(ctx);
              },
              child: const Text('Nhắc tôi sau'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ClearTokColors.pink,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              onPressed: () async {
                try {
                  final opened = await launchUrl(
                    available?.url ?? releasesUrl,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened) throw StateError('Không mở được GitHub.');
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không mở được liên kết cập nhật.'),
                      ),
                    );
                  }
                }
              },
              label: Text(
                available == null ? 'Mở GitHub Releases' : 'Tải bản mới ngay',
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa kiểm tra được cập nhật. Thử lại sau.'),
          ),
        );
      }
    } finally {
      _checking = false;
    }
  }
}
