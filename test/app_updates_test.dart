import 'package:flutter_test/flutter_test.dart';
import 'package:cleartok_reborn/services/app_updates.dart';

void main() {
  test('compares numeric version segments', () {
    final release = AppRelease.fromJson({
      'version': '2.3.10',
      'notes': 'Update',
      'url':
          'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/tag/v2.3.10',
    });
    expect(release.newerThan('2.3.9'), true);
    expect(release.newerThan('2.3.10'), false);
    expect(release.newerThan('2.4.0'), false);
  });
  test('rejects unsafe download URLs and malformed versions', () {
    for (final url in [
      'http://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/latest',
      'https://evil.example/install',
      'javascript:alert(1)',
    ]) {
      expect(
        () => AppRelease.fromJson({'version': '2.3.10', 'url': url}),
        throwsFormatException,
      );
    }
    expect(
      () => AppRelease.fromJson({
        'version': 'new',
        'url':
            'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/latest',
      }),
      throwsFormatException,
    );

    // M6: untrusted apkUrl/ipaUrl hosts are stripped to null
    final untrusted = AppRelease.fromJson({
      'version': '2.4.1',
      'url':
          'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/tag/v2.4.1',
      'apkUrl': 'https://evil.example/LapinTokk.apk',
      'ipaUrl': 'https://github.com/other/repo/releases/download/v1/app.ipa',
    });
    expect(untrusted.apkUrl, isNull);
    expect(untrusted.ipaUrl, isNull);

    final trusted = AppRelease.fromJson({
      'version': '2.4.1',
      'url':
          'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/tag/v2.4.1',
      'apkUrl':
          'https://github.com/Kiencodon777/ClearTok-Pro-Reborn/releases/download/v2.4.1/LapinTokk-v2.4.1.apk',
      'ipaUrl':
          'https://objects.githubusercontent.com/github-production/app.ipa',
    });
    expect(trusted.apkUrl, isNotNull);
    expect(trusted.ipaUrl, isNotNull);
  });
}
