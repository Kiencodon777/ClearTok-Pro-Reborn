enum TikTokNavigation { internal, external, block }

TikTokNavigation classifyTikTokNavigation(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return TikTokNavigation.block;
  }
  return uri.host.toLowerCase() == 'www.tiktok.com'
      ? TikTokNavigation.internal
      : TikTokNavigation.external;
}

Uri? resolveTikTokDeepLink(Uri uri) {
  if (uri.scheme != 'tiktok' && !uri.scheme.startsWith('snssdk')) return null;
  final target = Uri.tryParse(uri.queryParameters['url'] ?? '');
  return classifyTikTokNavigation(target) == TikTokNavigation.internal
      ? target
      : null;
}
