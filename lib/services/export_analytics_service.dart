import 'dart:convert';
import 'package:intl/intl.dart';
import '../database/local_database.dart';
import '../models/tiktok_follow_user.dart';
import '../models/tiktok_video.dart';

class AuthorStat {
  final String username;
  final int count;
  final int totalLikes;

  AuthorStat({
    required this.username,
    required this.count,
    required this.totalLikes,
  });
}

class StudioAnalytics {
  final int totalVideos;
  final int totalLikes;
  final double avgLikes;
  final List<AuthorStat> topAuthors;
  final Map<String, int> yearDistribution;

  StudioAnalytics({
    required this.totalVideos,
    required this.totalLikes,
    required this.avgLikes,
    required this.topAuthors,
    required this.yearDistribution,
  });

  factory StudioAnalytics.fromVideos(List<TikTokVideo> videos) {
    if (videos.isEmpty) {
      return StudioAnalytics(
        totalVideos: 0,
        totalLikes: 0,
        avgLikes: 0,
        topAuthors: [],
        yearDistribution: {},
      );
    }

    int likesSum = 0;
    final Map<String, int> authorCounts = {};
    final Map<String, int> authorLikes = {};
    final Map<String, int> years = {};

    final dfYear = DateFormat('yyyy');

    for (final v in videos) {
      likesSum += v.diggCount;

      final author = v.authorUsername.isNotEmpty ? v.authorUsername : 'unknown';
      authorCounts[author] = (authorCounts[author] ?? 0) + 1;
      authorLikes[author] = (authorLikes[author] ?? 0) + v.diggCount;

      final year = dfYear.format(v.repostDateTime);
      years[year] = (years[year] ?? 0) + 1;
    }

    final sortedAuthors = authorCounts.entries.map((e) {
      return AuthorStat(
        username: e.key,
        count: e.value,
        totalLikes: authorLikes[e.key] ?? 0,
      );
    }).toList()..sort((a, b) => b.count.compareTo(a.count));

    return StudioAnalytics(
      totalVideos: videos.length,
      totalLikes: likesSum,
      avgLikes: likesSum / videos.length,
      topAuthors: sortedAuthors.take(8).toList(),
      yearDistribution: years,
    );
  }
}

class ExportAnalyticsService {
  static String exportToCsv(List<TikTokVideo> videos) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Video ID,Author Username,Author Nickname,Likes,Repost Timestamp,TikTok URL,Cover URL,Description',
    );

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final v in videos) {
      final safeDesc =
          '"${v.description.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      final safeNick = '"${v.authorNickname.replaceAll('"', '""')}"';
      final timeStr = df.format(v.repostDateTime);
      final cleanAuthor = v.authorUsername.replaceFirst(RegExp(r'^@'), '');
      final tiktokUrl = cleanAuthor.isNotEmpty
          ? 'https://www.tiktok.com/@$cleanAuthor/video/${v.id}'
          : 'https://www.tiktok.com/video/${v.id}';

      buffer.writeln(
        '${v.id},${v.authorUsername},$safeNick,${v.diggCount},$timeStr,$tiktokUrl,${v.coverUrl},$safeDesc',
      );
    }

    return buffer.toString();
  }

  static String exportToJson(List<TikTokVideo> videos) {
    final list = videos.map((v) {
      final cleanAuthor = v.authorUsername.replaceFirst(RegExp(r'^@'), '');
      final tiktokUrl = cleanAuthor.isNotEmpty
          ? 'https://www.tiktok.com/@$cleanAuthor/video/${v.id}'
          : 'https://www.tiktok.com/video/${v.id}';
      return {
        'id': v.id,
        'authorUsername': v.authorUsername,
        'authorNickname': v.authorNickname,
        'diggCount': v.diggCount,
        'repostTimestamp': v.repostDateTime.toIso8601String(),
        'tiktokUrl': tiktokUrl,
        'coverUrl': v.coverUrl,
        'description': v.description,
      };
    }).toList();

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(list);
  }

  static String exportFollowingToCsv(List<TikTokFollowUser> users) {
    final buffer = StringBuffer();
    buffer.writeln(
      'User ID,Username,Nickname,Followers,SecUID,TikTok Profile URL,Bio',
    );
    for (final u in users) {
      final safeNick = '"${u.nickname.replaceAll('"', '""')}"';
      final safeBio = '"${u.bio.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      final profileUrl = 'https://www.tiktok.com/@${u.uniqueId}';
      buffer.writeln(
        '${u.id},${u.uniqueId},$safeNick,${u.followerCount},${u.secUid},$profileUrl,$safeBio',
      );
    }
    return buffer.toString();
  }

  static String exportFollowingToJson(List<TikTokFollowUser> users) {
    final list = users
        .map(
          (u) => {
            'id': u.id,
            'uniqueId': u.uniqueId,
            'nickname': u.nickname,
            'followerCount': u.followerCount,
            'secUid': u.secUid,
            'profileUrl': 'https://www.tiktok.com/@${u.uniqueId}',
            'bio': u.bio,
          },
        )
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  static String exportHistoryToCsv(List<ProcessedHistoryItem> items) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Type,ID,Author Username,Author Nickname,Likes/Followers,Processed Time,TikTok URL,Description',
    );
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final item in items) {
      final safeNick = '"${item.authorNickname.replaceAll('"', '""')}"';
      final safeDesc =
          '"${item.description.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      final timeStr = item.processedAt > 0
          ? df.format(DateTime.fromMillisecondsSinceEpoch(item.processedAt))
          : '';
      buffer.writeln(
        '${item.type},${item.id},${item.authorUsername},$safeNick,${item.diggCount},$timeStr,${item.tiktokUrl},$safeDesc',
      );
    }
    return buffer.toString();
  }

  static String exportHistoryToJson(List<ProcessedHistoryItem> items) {
    final list = items
        .map(
          (item) => {
            'type': item.type,
            'id': item.id,
            'authorUsername': item.authorUsername,
            'authorNickname': item.authorNickname,
            'diggCount': item.diggCount,
            'processedAt': item.processedAt > 0
                ? DateTime.fromMillisecondsSinceEpoch(
                    item.processedAt,
                  ).toIso8601String()
                : null,
            'tiktokUrl': item.tiktokUrl,
            'description': item.description,
          },
        )
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}
