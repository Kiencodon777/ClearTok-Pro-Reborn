import '../api/tiktok_client.dart';
import '../database/local_database.dart';

class StudioScanner {
  Future<int> scan({
    required TikTokClient client,
    required LocalDatabase database,
    required TikTokUserProfile user,
    required String hub,
    required Set<String> existingIds,
    required int targetLimit,
    required bool Function() isActive,
    required void Function(List<dynamic>, int) onPage,
  }) async {
    int cursor = 0, previousCursor = -1, totalFound = 0;
    bool hasMore = true;
    final seenIds = {...existingIds};
    final seenCursors = <int>{0};
    if (hub == 'unfollow') {
      var followingCursor = '0';
      var followingMinCursor = '0';
      final followingCursors = <(String, String)>{('0', '0')};
      // Scan following users with multi-batch pagination
      while (isActive() &&
          hasMore &&
          (targetLimit <= 0 || totalFound < targetLimit)) {
        final res = await client.fetchFollowingUsersBatch(
          cursor: followingCursor,
          minCursor: followingMinCursor,
          secUid: user.secUid,
        );

        if (!isActive()) return totalFound;
        if (res.users.isEmpty) break;
        final items = res.users
            .where((u) => u.id.isNotEmpty && seenIds.add(u.id))
            .take(targetLimit > 0 ? targetLimit - totalFound : res.users.length)
            .toList();
        await database.saveFollowing(items);
        totalFound += items.length;

        if (!isActive()) return totalFound;
        onPage(items, totalFound);

        if (targetLimit > 0 && totalFound >= targetLimit) break;
        if (res.hasMore &&
            !followingCursors.add((res.nextCursor, res.nextMinCursor))) {
          throw Exception(
            'Đã lưu $totalFound tài khoản. TikTok chưa trả cursor mới; mở Log xem scan.following.',
          );
        }
        followingCursor = res.nextCursor;
        followingMinCursor = res.nextMinCursor;
        hasMore = res.hasMore;

        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } else {
      // Scan Reposts or Liked Videos with multi-batch pagination
      while (isActive() &&
          hasMore &&
          (targetLimit <= 0 || totalFound < targetLimit)) {
        final res = (hub == 'unlike')
            ? await client.fetchLikedVideosBatch(
                cursor: cursor,
                secUid: user.secUid,
              )
            : await client.fetchRepostBatch(
                cursor: cursor,
                secUid: user.secUid,
              );

        if (!isActive()) return totalFound;
        if (res.videos.isEmpty) break;
        final items = res.videos
            .where((v) => v.id.isNotEmpty && seenIds.add(v.id))
            .take(
              targetLimit > 0 ? targetLimit - totalFound : res.videos.length,
            )
            .toList();

        if (hub == 'unlike') {
          await database.saveLikedVideos(items);
        } else {
          await database.saveReposts(items);
        }

        totalFound += items.length;

        if (!isActive()) return totalFound;
        onPage(items, totalFound);

        if (targetLimit > 0 && totalFound >= targetLimit) break;
        if (res.hasMore && !seenCursors.add(res.nextCursor)) {
          throw Exception(
            'TikTok lặp cursor sau $totalFound mục; chưa quét hết.',
          );
        }
        if (res.nextCursor <= 0 ||
            res.nextCursor == cursor ||
            res.nextCursor == previousCursor) {
          break;
        }

        previousCursor = cursor;
        cursor = res.nextCursor;
        hasMore = res.hasMore;

        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    return totalFound;
  }
}
