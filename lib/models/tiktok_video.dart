class TikTokVideo {
  final String id;
  final String secUid;
  final String authorUsername;
  final String authorNickname;
  final String authorAvatar;
  final String coverUrl;
  final String description;
  final int playCount;
  final int diggCount;
  final int repostTimestamp;
  final bool isPinned;

  TikTokVideo({
    required this.id,
    required this.secUid,
    required this.authorUsername,
    required this.authorNickname,
    required this.authorAvatar,
    required this.coverUrl,
    required this.description,
    required this.playCount,
    required this.diggCount,
    required this.repostTimestamp,
    this.isPinned = false,
  });

  factory TikTokVideo.fromJson(Map<String, dynamic> json, {String secUid = ''}) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    final video = json['video'] as Map<String, dynamic>? ?? {};
    final stats = json['stats'] as Map<String, dynamic>? ?? {};

    return TikTokVideo(
      id: json['id']?.toString() ?? '',
      secUid: secUid,
      authorUsername: author['uniqueId']?.toString() ?? 'anonymous',
      authorNickname: author['nickname']?.toString() ?? '',
      authorAvatar: author['avatarThumb']?.toString() ?? '',
      coverUrl: video['cover']?.toString() ?? '',
      description: json['desc']?.toString() ?? '',
      playCount: int.tryParse(stats['playCount']?.toString() ?? '0') ?? 0,
      diggCount: int.tryParse(stats['diggCount']?.toString() ?? '0') ?? 0,
      repostTimestamp: int.tryParse(json['createTime']?.toString() ?? '0') ?? 0,
      isPinned: json['isPinned'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'secUid': secUid,
      'authorUsername': authorUsername,
      'authorNickname': authorNickname,
      'authorAvatar': authorAvatar,
      'coverUrl': coverUrl,
      'description': description,
      'playCount': playCount,
      'diggCount': diggCount,
      'repostTimestamp': repostTimestamp,
      'isPinned': isPinned,
    };
  }

  factory TikTokVideo.fromMap(Map<dynamic, dynamic> map) {
    return TikTokVideo(
      id: map['id']?.toString() ?? '',
      secUid: map['secUid']?.toString() ?? '',
      authorUsername: map['authorUsername']?.toString() ?? '',
      authorNickname: map['authorNickname']?.toString() ?? '',
      authorAvatar: map['authorAvatar']?.toString() ?? '',
      coverUrl: map['coverUrl']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      playCount: map['playCount'] as int? ?? 0,
      diggCount: map['diggCount'] as int? ?? 0,
      repostTimestamp: map['repostTimestamp'] as int? ?? 0,
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }
}
