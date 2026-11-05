import 'package:cleartok_reborn/ui/screens/tiktok_navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the documented TikTok origin is internal', () {
    expect(
      classifyTikTokNavigation(Uri.parse('https://www.tiktok.com/login')),
      TikTokNavigation.internal,
    );
    expect(
      classifyTikTokNavigation(Uri.parse('https://www.tiktok.com:443/login')),
      TikTokNavigation.internal,
    );
    expect(
      classifyTikTokNavigation(Uri.parse('https://www.tiktok.com.evil.test/')),
      TikTokNavigation.external,
    );
    for (final value in [
      'http://www.tiktok.com/',
      'https://www.tiktok.com:444/',
      'https://user@www.tiktok.com/',
      'javascript:alert(1)',
      'file:///tmp/a',
      'content://a',
    ]) {
      expect(
        classifyTikTokNavigation(Uri.parse(value)),
        TikTokNavigation.block,
        reason: value,
      );
    }
  });

  test('deep links resolve only to the trusted origin', () {
    expect(
      resolveTikTokDeepLink(
        Uri.parse('tiktok://open?url=https%3A%2F%2Fwww.tiktok.com%2Flogin'),
      )?.host,
      'www.tiktok.com',
    );
    expect(
      resolveTikTokDeepLink(
        Uri.parse('tiktok://open?url=https%3A%2F%2Fevil.test'),
      ),
      isNull,
    );
    expect(
      resolveTikTokDeepLink(
        Uri.parse('tiktok://open?url=http%3A%2F%2Fwww.tiktok.com'),
      ),
      isNull,
    );
  });
}
