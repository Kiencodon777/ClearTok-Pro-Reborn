import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/tiktok_video.dart';

class AuthorStat {
  final String username;
  final int count;
  final int totalLikes;

  AuthorStat({required this.username, required this.count, required this.totalLikes});
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

      final year = dfYear.format(v.repostTimestamp);
      years[year] = (years[year] ?? 0) + 1;
    }

    final sortedAuthors = authorCounts.entries.map((e) {
      return AuthorStat(
        username: e.key,
        count: e.value,
        totalLikes: authorLikes[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

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
    buffer.writeln('Video ID,Author Username,Author Nickname,Likes,Repost Timestamp,Cover URL,Description');

    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final v in videos) {
      final safeDesc = '"${v.description.replaceAll('"', '""').replaceAll('\n', ' ')}"';
      final safeNick = '"${v.authorNickname.replaceAll('"', '""')}"';
      final timeStr = df.format(v.repostTimestamp);

      buffer.writeln('${v.id},${v.authorUsername},$safeNick,${v.diggCount},$timeStr,${v.coverUrl},$safeDesc');
    }

    return buffer.toString();
  }

  static String exportToJson(List<TikTokVideo> videos) {
    final list = videos.map((v) => {
      'id': v.id,
      'authorUsername': v.authorUsername,
      'authorNickname': v.authorNickname,
      'diggCount': v.diggCount,
      'repostTimestamp': v.repostTimestamp.toIso8601String(),
      'coverUrl': v.coverUrl,
      'description': v.description,
    }).toList();

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(list);
  }
}
