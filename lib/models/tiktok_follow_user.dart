class TikTokFollowUser {
  final String id;
  final String uniqueId;
  final String nickname;
  final String avatarThumb;
  final int followerCount;
  final String bio;

  TikTokFollowUser({
    required this.id,
    required this.uniqueId,
    required this.nickname,
    required this.avatarThumb,
    required this.followerCount,
    this.bio = '',
  });

  factory TikTokFollowUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    final stats = json['stats'] as Map<String, dynamic>? ?? {};

    return TikTokFollowUser(
      id: user['id']?.toString() ?? user['uid']?.toString() ?? '',
      uniqueId: user['uniqueId']?.toString() ?? user['unique_id']?.toString() ?? 'anonymous',
      nickname: user['nickname']?.toString() ?? '',
      avatarThumb: user['avatarThumb']?.toString() ?? user['avatar_thumb']?.toString() ?? '',
      followerCount: int.tryParse(stats['followerCount']?.toString() ?? '0') ?? 0,
      bio: user['signature']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uniqueId': uniqueId,
      'nickname': nickname,
      'avatarThumb': avatarThumb,
      'followerCount': followerCount,
      'bio': bio,
    };
  }

  factory TikTokFollowUser.fromMap(Map<dynamic, dynamic> map) {
    return TikTokFollowUser(
      id: map['id']?.toString() ?? '',
      uniqueId: map['uniqueId']?.toString() ?? '',
      nickname: map['nickname']?.toString() ?? '',
      avatarThumb: map['avatarThumb']?.toString() ?? '',
      followerCount: map['followerCount'] as int? ?? 0,
      bio: map['bio']?.toString() ?? '',
    );
  }
}

class FollowingScanResult {
  final List<TikTokFollowUser> users;
  final int nextCursor;
  final bool hasMore;

  FollowingScanResult({required this.users, required this.nextCursor, required this.hasMore});
}
