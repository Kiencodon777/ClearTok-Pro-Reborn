import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../database/local_database.dart';
import '../ui/widgets/liquid_glass.dart';

class AppRelease {
  final String version;
  final String notes;
  final Uri url;
  final Uri? apkUrl;
  final Uri? ipaUrl;

  AppRelease(
    this.version,
    this.notes,
    this.url, {
    this.apkUrl,
    this.ipaUrl,
  });

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
    final apk = Uri.tryParse(json['apkUrl']?.toString() ?? '');
    final ipa = Uri.tryParse(json['ipaUrl']?.toString() ?? '');
    return AppRelease(
      version,
      notes.substring(0, notes.length > 6000 ? 6000 : notes.length),
      url,
      apkUrl: (apk != null && apk.scheme == 'https') ? apk : null,
      ipaUrl: (ipa != null && ipa.scheme == 'https') ? ipa : null,
    );
  }

  factory AppRelease.fromGitHubReleaseJson(Map<String, dynamic> gh) {
    final rawTag = (gh['tag_name']?.toString() ?? '').trim();
    final version = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
    final htmlUrl =
        Uri.tryParse(gh['html_url']?.toString() ?? '') ??
        Uri.parse(
          'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/tag/v$version',
        );
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Tag phiên bản GitHub không hợp lệ.');
    }
    Uri? apkUri;
    Uri? ipaUri;
    final assets = gh['assets'];
    if (assets is List) {
      for (final item in assets) {
        if (item is Map) {
          final name = (item['name']?.toString() ?? '').toLowerCase();
          final dl = Uri.tryParse(
            item['browser_download_url']?.toString() ?? '',
          );
          if (dl != null && dl.scheme == 'https') {
            if (name.endsWith('.apk')) apkUri = dl;
            if (name.endsWith('.ipa')) ipaUri = dl;
          }
        }
      }
    }
    apkUri ??= Uri.parse(
      'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/download/v$version/LapinTokk-v$version.apk',
    );
    ipaUri ??= Uri.parse(
      'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/download/v$version/LapinTokk-v$version.ipa',
    );
    final notes = gh['body']?.toString() ?? '';
    return AppRelease(
      version,
      notes.substring(0, notes.length > 6000 ? 6000 : notes.length),
      htmlUrl,
      apkUrl: apkUri,
      ipaUrl: ipaUri,
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
    defaultValue: '2.3.36',
  );
  static const feedUrl = String.fromEnvironment('UPDATE_FEED_URL');
  static bool _checking = false;
  static final releasesUrl = Uri.parse(
    'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases',
  );
  static final githubLatestApiUrl = Uri.parse(
    'https://api.github.com/repos/Kiencodon777/ClearTok-Pro-Reborn/releases/latest',
  );

  /// Detailed built-in release notes displayed in the mobile Update Modal
  static const List<(IconData, String, String)> builtInReleaseHighlights = [
    (
      Icons.water_drop_rounded,
      'Vật Lý Thạch Lò Xo 2D (Jelly Physics) & Âm Thanh Giọt Nước iOS',
      'Hiệu ứng đàn hồi bảo toàn thể tích 2 chiều như thạch thật khi chạm/kéo thanh Dock & nút bấm, kết hợp âm thanh click giọt nước êm ái chuẩn iOS.',
    ),
    (
      Icons.system_update_alt_rounded,
      'Tải Trực Tiếp Bản Cập Nhật Ngay Trong App (.IPA / .APK)',
      'Tự động dò bản mới từ máy chủ và cho phép bấm 1 chạm tải thẳng file .IPA / .APK hoặc mở cài qua GBox / ESign / SideStore mà không cần vào GitHub tìm file.',
    ),
    (
      Icons.filter_alt_rounded,
      'Bộ Lọc Thời Gian & Khôi Phục Hàng Loạt Ở Tab "Đã Xử Lý"',
      'Lọc nhanh lịch sử theo Hôm nay, 7 ngày qua, Tháng này, sắp xếp theo Lượt thích / Kênh và chọn nhiều mục để khôi phục hoặc sao lưu cùng lúc.',
    ),
    (
      Icons.backup_rounded,
      'Sao Lưu 1 Chạm Trước Khi Bỏ Thích / Xóa Repost Hàng Loạt',
      'Tích hợp nút sao lưu nhanh danh sách video kỷ niệm (JSON/CSV kèm link TikTok gốc) ngay trong hộp thoại xác nhận trước khi xử lý.',
    ),
  ];

  static Future<AppRelease?> _fetchLatestFromGitHub() async {
    final response = await http
        .get(
          githubLatestApiUrl,
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 || response.bodyBytes.length > 262144) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return AppRelease.fromGitHubReleaseJson(decoded);
    }
    return null;
  }

  static Future<void> check(
    BuildContext context,
    LocalDatabase database, {
    bool manual = false,
  }) async {
    final isWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
    if (_checking ||
        (!manual &&
            ((isWidgetTest && feedUrl.isEmpty) ||
                database.updateSnoozedUntil >
                    DateTime.now().millisecondsSinceEpoch))) {
      return;
    }
    _checking = true;
    try {
      AppRelease? release;
      String? notice;
      if (feedUrl.isNotEmpty) {
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
        }
      }

      if (release == null) {
        try {
          final ghCandidate = await _fetchLatestFromGitHub();
          if (ghCandidate != null && ghCandidate.newerThan(currentVersion)) {
            release = ghCandidate;
          }
        } catch (_) {}
      }

      if (release == null) {
        if (manual) {
          notice =
              'Bạn đang dùng phiên bản mới nhất (v$currentVersion). Bạn cũng có thể tải lại trực tiếp bộ cài .IPA / .APK bên dưới.';
        } else {
          return;
        }
      }

      if (!context.mounted) return;
      final available = release;
      final targetVer = available?.version ?? currentVersion;
      final directIpaUri =
          available?.ipaUrl ??
          Uri.parse(
            'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/download/v$targetVer/LapinTokk-v$targetVer.ipa',
          );
      final directApkUri =
          available?.apkUrl ??
          Uri.parse(
            'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/download/v$targetVer/LapinTokk-v$targetVer.apk',
          );
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final primaryDirectUri = isIOS ? directIpaUri : directApkUri;

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
                      ? 'Cập nhật Trực Tiếp v${available.version}'
                      : 'Cập nhật & Tải Trực Tiếp',
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
                            ? 'Đang cài: v$currentVersion → Bản mới: v${available.version}'
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
                const SizedBox(height: 14),
                // Direct 1-Tap In-App Action Buttons (No need to browse GitHub!)
                GlassActionButton(
                  primary: true,
                  icon: const Icon(Icons.bolt_rounded),
                  label: isIOS
                      ? 'Tải Trực Tiếp File .IPA (v$targetVer)'
                      : 'Tải Trực Tiếp File .APK (v$targetVer)',
                  onPressed: () async {
                    LiquidSoundHaptics.tapPop();
                    await launchUrl(
                      primaryDirectUri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: ClearTokColors.cyan,
                        ),
                        label: Text(
                          isIOS ? 'Copy link .IPA (GBox)' : 'Copy link .APK',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: primaryDirectUri.toString()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isIOS
                                    ? 'Đã copy link .IPA trực tiếp! Mở GBox/ESign dán vào để ký & cài ngay.'
                                    : 'Đã copy link tải .APK trực tiếp!',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: Icon(
                          isIOS
                              ? Icons.install_mobile_rounded
                              : Icons.phone_iphone_rounded,
                          size: 15,
                          color: ClearTokColors.pink,
                        ),
                        label: Text(
                          isIOS ? 'Cài qua SideStore' : 'Tải file .IPA (iOS)',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () async {
                          if (isIOS) {
                            final sideStoreUri = Uri.parse(
                              'sidestore://install?url=${Uri.encodeComponent(directIpaUri.toString())}',
                            );
                            final ok = await launchUrl(sideStoreUri);
                            if (!ok) {
                              await launchUrl(
                                directIpaUri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } else {
                            await launchUrl(
                              directIpaUri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    ),
                  ],
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
                  '💡 Trên Android: bấm nút tải trực tiếp .APK rồi chọn Cài đặt đè. Trên iOS: bấm Tải Trực Tiếp .IPA hoặc Copy link .IPA dán thẳng vào mục Tải URL của GBox / ESign mà không cần tìm trên GitHub.',
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
              child: const Text('Đóng / Nhắc sau'),
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
                    primaryDirectUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened) throw StateError('Không mở được liên kết.');
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
              label: Text(isIOS ? 'Tải Ngay .IPA' : 'Tải Ngay .APK'),
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
