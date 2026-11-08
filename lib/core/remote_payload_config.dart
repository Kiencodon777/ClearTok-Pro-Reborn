class RemotePayloadConfig {
  const RemotePayloadConfig();
  static const fallbackScanEndpoint =
      'https://www.tiktok.com/api/repost/item_list/';
  static const fallbackDeleteEndpoint =
      'https://www.tiktok.com/tiktok/v1/upvote/delete';
  final String scanEndpoint = fallbackScanEndpoint;
  final String deleteEndpoint = fallbackDeleteEndpoint;
  final int aid = 1988;
  final int defaultDelayMs = 700;
  final bool allowFastMode = true;
}
