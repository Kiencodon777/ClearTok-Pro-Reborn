import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/tiktok_client.dart';
import '../../database/local_database.dart';
import '../../models/tiktok_follow_user.dart';
import '../../models/tiktok_video.dart';
import '../../services/export_analytics_service.dart';
import '../../services/tiktok_deletion_engine.dart';
import '../../services/app_updates.dart';
import '../widgets/liquid_glass.dart';

class RepostStudioScreen extends StatefulWidget {
  final LocalDatabase database;
  final TikTokClient? client;
  final TikTokUserProfile? currentUser;
  final VoidCallback onSwitchToBrowser;

  const RepostStudioScreen({
    super.key,
    required this.database,
    required this.client,
    required this.currentUser,
    required this.onSwitchToBrowser,
  });

  @override
  State<RepostStudioScreen> createState() => _RepostStudioScreenState();
}

class _RepostStudioScreenState extends State<RepostStudioScreen> {
  List<TikTokVideo> _videos = [];
  List<TikTokFollowUser> _followingUsers = [];
  final Set<String> _selectedIds = {};
  bool _isScanning = false;
  bool _toolsExpanded = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String? _filterAuthor;
  String? _filterYear;
  String _currentHub = 'repost'; // 'repost', 'unlike', 'unfollow'
  int _scanBatchLimit = 100;
  int _currentScannedCount = 0;

  TikTokDeletionEngine? _engine;

  @override
  void initState() {
    super.initState();
    _scanBatchLimit = widget.database.scanBatchLimit;
    _toolsExpanded = widget.database.studioToolsExpanded;
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant RepostStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      _engine?.dispose();
      _engine = null;
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      _selectedIds.clear();
      if (_currentHub == 'repost') {
        _videos = widget.database.getAllReposts();
        _selectedIds.addAll(_videos.map((v) => v.id));
      } else if (_currentHub == 'unlike') {
        _videos = widget.database.getAllLikedVideos();
        _selectedIds.addAll(_videos.map((v) => v.id));
      } else if (_currentHub == 'unfollow') {
        _followingUsers = widget.database.getAllFollowing();
        _selectedIds.addAll(_followingUsers.map((u) => u.id));
      }
    });
  }

  TikTokDeletionEngine _freshEngine() {
    _engine?.dispose();
    _engine = TikTokDeletionEngine(
      client: widget.client!,
      database: widget.database,
    );
    return _engine!;
  }

  List<TikTokVideo> get _filteredVideos {
    List<TikTokVideo> list = List.from(_videos);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((v) {
        return v.authorUsername.toLowerCase().contains(q) ||
            v.authorNickname.toLowerCase().contains(q) ||
            v.description.toLowerCase().contains(q);
      }).toList();
    }

    if (_filterAuthor != null) {
      list = list.where((v) => v.authorUsername == _filterAuthor).toList();
    }

    if (_filterYear != null) {
      final dfYear = DateFormat('yyyy');
      list = list
          .where((v) => dfYear.format(v.repostDateTime) == _filterYear)
          .toList();
    }

    switch (_selectedFilter) {
      case 'selected':
        list = list.where((v) => _selectedIds.contains(v.id)).toList();
        break;
      case 'most_liked':
        list.sort((a, b) => b.diggCount.compareTo(a.diggCount));
        break;
      case 'newest':
        list.sort((a, b) => b.repostTimestamp.compareTo(a.repostTimestamp));
        break;
      case 'oldest':
        list.sort((a, b) => a.repostTimestamp.compareTo(b.repostTimestamp));
        break;
    }

    return list;
  }

  List<TikTokFollowUser> get _filteredFollowing {
    List<TikTokFollowUser> list = List.from(_followingUsers);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        return u.uniqueId.toLowerCase().contains(q) ||
            u.nickname.toLowerCase().contains(q) ||
            u.bio.toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedFilter == 'selected') {
      list = list.where((u) => _selectedIds.contains(u.id)).toList();
    }

    return list;
  }

  Future<void> _startScan() async {
    if (widget.client == null || widget.currentUser == null) {
      _showSnack(
        'Vui lòng qua tab "TikTok Web" đăng nhập trước nhé anh yêu!',
        isError: true,
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _currentScannedCount = 0;
    });

    int cursor = 0;
    bool hasMore = true;
    int totalFound = 0;
    int previousCursor = -1;
    final seenIds = <String>{};
    final seenCursors = <int>{0};
    final int targetLimit = _scanBatchLimit;

    try {
      if (_currentHub == 'unfollow') {
        var followingCursor = '0';
        var followingMinCursor = '0';
        final followingCursors = <(String, String)>{('0', '0')};
        // Scan following users with multi-batch pagination
        while (hasMore && (targetLimit <= 0 || totalFound < targetLimit)) {
          final res = await widget.client!.fetchFollowingUsersBatch(
            cursor: followingCursor,
            minCursor: followingMinCursor,
            secUid: widget.currentUser!.secUid,
          );

          if (res.users.isEmpty) break;
          final items = res.users
              .where((u) => u.id.isNotEmpty && seenIds.add(u.id))
              .take(
                targetLimit > 0 ? targetLimit - totalFound : res.users.length,
              )
              .toList();
          await widget.database.saveFollowing(items);
          totalFound += items.length;

          setState(() {
            _currentScannedCount = totalFound;
            _loadItems();
          });

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
        while (hasMore && (targetLimit <= 0 || totalFound < targetLimit)) {
          final res = (_currentHub == 'unlike')
              ? await widget.client!.fetchLikedVideosBatch(
                  cursor: cursor,
                  secUid: widget.currentUser!.secUid,
                )
              : await widget.client!.fetchRepostBatch(
                  cursor: cursor,
                  secUid: widget.currentUser!.secUid,
                );

          if (res.videos.isEmpty) break;
          final items = res.videos
              .where((v) => v.id.isNotEmpty && seenIds.add(v.id))
              .take(
                targetLimit > 0 ? targetLimit - totalFound : res.videos.length,
              )
              .toList();

          if (_currentHub == 'unlike') {
            await widget.database.saveLikedVideos(items);
          } else {
            await widget.database.saveReposts(items);
          }

          totalFound += items.length;

          setState(() {
            _currentScannedCount = totalFound;
            _loadItems();
          });

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

      if (totalFound > 0) {
        final modeLabel = _currentHub == 'unfollow'
            ? 'tài khoản đang follow'
            : (_currentHub == 'unlike' ? 'video đã thích' : 'video repost');
        final limitDesc = targetLimit > 0
            ? '$totalFound / $targetLimit'
            : '$totalFound';
        _showSnack(
          'Quét hoàn tất đợt này: $limitDesc $modeLabel! Anh có thể xử lý ngay.',
        );
      } else {
        _showNoItemsDialog();
      }
    } catch (e) {
      _showSnack('Lỗi quét: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showNoItemsDialog() {
    final title = _currentHub == 'unfollow'
        ? 'Không tìm thấy tài khoản follow nào'
        : (_currentHub == 'unlike'
              ? 'Không tìm thấy video đã thích'
              : 'Không tìm thấy video Repost');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClearTokColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        scrollable: true,
        icon: const Icon(Icons.info_outline, color: ClearTokColors.cyan),
        title: const Text('Kết Quả Quét', style: ClearTokTokens.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'Mẹo: Hãy đảm bảo tài khoản đã đăng nhập ở tab TikTok Web. Với video thích hoặc danh sách follow ở chế độ riêng tư, hãy mở hồ sơ cá nhân trên tab web một lần trước khi quét nhé!',
                style: TextStyle(color: ClearTokColors.secondary, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(color: ClearTokColors.secondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ClearTokColors.pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onSwitchToBrowser();
            },
            child: const Text('Mở TikTok Web'),
          ),
        ],
      ),
    );
  }

  void _triggerBatchAction() {
    if (widget.client == null) {
      _showSnack(
        'Chưa kết nối WebView TikTok, vui lòng mở tab TikTok Web trước!',
        isError: true,
      );
      return;
    }

    final int selectedCount = _selectedIds.length;
    if (selectedCount == 0) {
      _showSnack('Chưa chọn mục nào để xử lý cơ mà!', isError: true);
      return;
    }

    final actionLabel = _currentHub == 'unfollow'
        ? 'hủy theo dõi $selectedCount tài khoản'
        : (_currentHub == 'unlike'
              ? 'bỏ thích $selectedCount video'
              : 'hủy $selectedCount repost');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClearTokColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        scrollable: true,
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: ClearTokColors.pink,
        ),
        title: const Text('Xác Nhận Xử Lý', style: ClearTokTokens.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anh có chắc chắn muốn $actionLabel này không?',
              style: const TextStyle(
                color: ClearTokColors.secondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: ClearTokColors.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tốc độ: ${widget.database.customDelayMs}ms (Bypass Quota: Vô Hạn ∞)',
                          style: const TextStyle(
                            color: ClearTokColors.cyan,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.database.pulseJitterEnabled) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: ClearTokColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anti-Ban: Nghỉ ${widget.database.deepRestDurationSec}s sau mỗi ${widget.database.deepRestBatchCount} mục',
                            style: const TextStyle(
                              color: ClearTokColors.secondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy Bỏ',
              style: TextStyle(color: ClearTokColors.secondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ClearTokColors.pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startLiveModal();
            },
            child: const Text(
              'Bắt Đầu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _startLiveModal() {
    final engine = _freshEngine();
    final int total = _selectedIds.length;
    final hubMode = _currentHub;
    final pausedByUser = ValueNotifier(false);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GlassSheet(
        child: StreamBuilder<BatchDeletionProgress>(
          stream: engine.progressStream,
          initialData: BatchDeletionProgress(
            total: total,
            deleted: 0,
            failed: 0,
            status: DeletionStatus.running,
            message: 'Khởi động tiến trình xử lý $total mục...',
          ),
          builder: (ctx, snapshot) {
            final prog = snapshot.data;
            final isRunning =
                prog != null &&
                (prog.status == DeletionStatus.running ||
                    prog.status == DeletionStatus.paused ||
                    prog.status == DeletionStatus.deepResting);
            final isDeepResting = prog?.status == DeletionStatus.deepResting;
            final isDone =
                prog != null &&
                (prog.status == DeletionStatus.completed ||
                    prog.status == DeletionStatus.stopped ||
                    prog.status == DeletionStatus.error);

            final titleText = hubMode == 'unfollow'
                ? 'Hủy Follow Hàng Loạt'
                : (hubMode == 'unlike'
                      ? 'Bỏ Thích Hàng Loạt'
                      : 'Hủy Repost Hàng Loạt');

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDeepResting
                                      ? ClearTokColors.success.withValues(
                                          alpha: 0.2,
                                        )
                                      : ClearTokColors.pink.withValues(
                                          alpha: 0.2,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isDeepResting
                                      ? Icons.spa_rounded
                                      : (hubMode == 'unfollow'
                                            ? Icons.person_remove_rounded
                                            : Icons.delete_sweep),
                                  color: isDeepResting
                                      ? ClearTokColors.success
                                      : ClearTokColors.pink,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDeepResting
                                          ? 'Anti-Ban: Đang Giải Nhiệt'
                                          : titleText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      prog != null
                                          ? '${prog.deleted} / ${prog.total} (${prog.failed} lỗi)'
                                          : 'Khởi động...',
                                      style: TextStyle(
                                        color: isDeepResting
                                            ? ClearTokColors.success
                                            : ClearTokColors.cyan,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isDone)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _loadItems());
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (prog != null && prog.total > 0)
                            ? prog.deleted / prog.total
                            : null,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDeepResting
                              ? ClearTokColors.success
                              : ClearTokColors.pink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDeepResting
                            ? const Color(0xFF0F241E)
                            : Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDeepResting
                              ? ClearTokColors.success.withValues(alpha: 0.3)
                              : Colors.white10,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prog?.message ?? 'Đang kết nối tới TikTok...',
                            style: TextStyle(
                              color: isDeepResting
                                  ? ClearTokColors.success
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: isDeepResting
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (prog?.lastErrorDetail != null &&
                              prog!.lastErrorDetail!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Chi tiết: ${prog.lastErrorDetail}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (isRunning) ...[
                          Expanded(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: pausedByUser,
                              builder: (context, paused, _) => OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  if (paused) {
                                    engine.resume();
                                  } else {
                                    engine.pause();
                                  }
                                  pausedByUser.value = !paused;
                                },
                                child: Text(paused ? 'Tiếp Tục' : 'Tạm Dừng'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade900,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => engine.stop(),
                              child: const Text('Dừng Hẳn'),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ClearTokColors.pink,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _loadItems());
                              },
                              child: const Text('Đóng'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ).whenComplete(pausedByUser.dispose);

    // Launch appropriate batch runner
    Future.microtask(() {
      if (hubMode == 'unfollow') {
        final targetUsers = _followingUsers
            .where((u) => _selectedIds.contains(u.id))
            .toList();
        engine.executeUnfollowBatch(targetUsers);
      } else {
        final targetVideos = _videos
            .where((v) => _selectedIds.contains(v.id))
            .toList();
        engine.executeBatch(targetVideos, mode: hubMode);
      }
    });
  }

  void _showAuthorFilterModal() {
    final analytics = StudioAnalytics.fromVideos(_videos);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(
                ctx,
                'Lọc theo tác giả',
                Icons.person_search_rounded,
              ),
              const SizedBox(height: 12),
              if (analytics.topAuthors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Chưa có dữ liệu tác giả nào!',
                      style: TextStyle(color: ClearTokColors.muted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: analytics.topAuthors.length + 1,
                    itemBuilder: (ctx, idx) {
                      if (idx == 0) {
                        return ListTile(
                          leading: const Icon(
                            Icons.all_inclusive,
                            color: ClearTokColors.cyan,
                          ),
                          title: const Text(
                            'Tất cả tác giả',
                            style: TextStyle(color: Colors.white),
                          ),
                          trailing: _filterAuthor == null
                              ? const Icon(
                                  Icons.check,
                                  color: ClearTokColors.pink,
                                )
                              : null,
                          onTap: () {
                            setState(() => _filterAuthor = null);
                            Navigator.pop(ctx);
                          },
                        );
                      }
                      final a = analytics.topAuthors[idx - 1];
                      final isSelected = _filterAuthor == a.username;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ClearTokColors.raised,
                          child: Text(
                            a.username.isNotEmpty
                                ? a.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: ClearTokColors.pink),
                          ),
                        ),
                        title: Text(
                          '@${a.username}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${a.count} mục • ${a.totalLikes} lượt thích',
                          style: const TextStyle(
                            color: ClearTokColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check,
                                color: ClearTokColors.pink,
                              )
                            : null,
                        onTap: () {
                          setState(() => _filterAuthor = a.username);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalyticsModal() {
    final analytics = StudioAnalytics.fromVideos(_videos);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(ctx, 'Thống kê Studio', Icons.insights_rounded),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatPill(
                    'Tổng Đã Quét',
                    '${_videos.length}',
                    ClearTokColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  _buildStatPill(
                    'Tổng Like',
                    '${analytics.totalLikes}',
                    ClearTokColors.pink,
                  ),
                  const SizedBox(width: 8),
                  _buildStatPill(
                    'Like TB',
                    analytics.avgLikes.toStringAsFixed(1),
                    ClearTokColors.cyan,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Top Tác Giả Xuất Hiện Nhiều Nhất:',
                style: TextStyle(
                  color: ClearTokColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              if (analytics.topAuthors.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa có dữ liệu!',
                      style: TextStyle(color: ClearTokColors.muted),
                    ),
                  ),
                )
              else
                ...analytics.topAuthors
                    .take(5)
                    .map(
                      (a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '@${a.username}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${a.count} mục (${a.totalLikes} like)',
                              style: const TextStyle(
                                color: ClearTokColors.cyan,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String title, String val, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(ClearTokTokens.radius),
          border: Border.all(color: col.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: ClearTokColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                color: col,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(
                ctx,
                'Sao lưu & xuất dữ liệu',
                Icons.file_download_outlined,
              ),
              const SizedBox(height: 12),
              const Text(
                'Lưu trữ danh sách video về máy trước khi thao tác hàng loạt.',
                style: TextStyle(color: ClearTokColors.secondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClearTokColors.raised,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ClearTokTokens.radius,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.table_chart_rounded,
                        color: ClearTokColors.cyan,
                      ),
                      label: const Text('Copy CSV'),
                      onPressed: () {
                        final csv = ExportAnalyticsService.exportToCsv(_videos);
                        Clipboard.setData(ClipboardData(text: csv));
                        Navigator.pop(ctx);
                        _showSnack(
                          'Đã copy toàn bộ ${_videos.length} video dạng CSV!',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClearTokColors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ClearTokTokens.radius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.data_object_rounded),
                      label: const Text('Copy JSON'),
                      onPressed: () {
                        final jsonStr = ExportAnalyticsService.exportToJson(
                          _videos,
                        );
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        Navigator.pop(ctx);
                        _showSnack(
                          'Đã copy toàn bộ ${_videos.length} video dạng JSON!',
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsModal() {
    int currentDelay = widget.database.customDelayMs;
    bool pulseJitter = widget.database.pulseJitterEnabled;
    int deepBatch = widget.database.deepRestBatchCount;
    int deepSec = widget.database.deepRestDurationSec;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => GlassSheet(
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHeader(ctx, 'Nhịp xử lý', Icons.tune_rounded),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildPresetButton('Turbo', () {
                      setModalState(() {
                        currentDelay = 300;
                        pulseJitter = false;
                      });
                      widget.database.setCustomDelayMs(300);
                      widget.database.setPulseJitterEnabled(false);
                      setState(() {});
                    }),
                    const SizedBox(width: 8),
                    _buildPresetButton('Cân Bằng', () {
                      setModalState(() {
                        currentDelay = 700;
                        pulseJitter = true;
                        deepBatch = 20;
                        deepSec = 12;
                      });
                      widget.database.setCustomDelayMs(700);
                      widget.database.setPulseJitterEnabled(true);
                      widget.database.setDeepRestBatchCount(20);
                      widget.database.setDeepRestDurationSec(12);
                      setState(() {});
                    }),
                    const SizedBox(width: 8),
                    _buildPresetButton('Siêu An Toàn', () {
                      setModalState(() {
                        currentDelay = 1500;
                        pulseJitter = true;
                        deepBatch = 10;
                        deepSec = 20;
                      });
                      widget.database.setCustomDelayMs(1500);
                      widget.database.setPulseJitterEnabled(true);
                      widget.database.setDeepRestBatchCount(10);
                      widget.database.setDeepRestDurationSec(20);
                      setState(() {});
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Thời gian nghỉ giữa mỗi lượt:',
                        style: TextStyle(color: ClearTokColors.secondary),
                      ),
                    ),
                    Text(
                      '${currentDelay}ms',
                      style: const TextStyle(
                        color: ClearTokColors.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: currentDelay.toDouble(),
                  min: 200,
                  max: 2000,
                  divisions: 18,
                  activeColor: ClearTokColors.pink,
                  inactiveColor: Colors.white12,
                  label: '${currentDelay}ms',
                  onChanged: (val) {
                    setModalState(() => currentDelay = val.toInt());
                    setState(
                      () => widget.database.setCustomDelayMs(val.toInt()),
                    );
                  },
                ),
                const Divider(color: Colors.white10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: ClearTokColors.success,
                  title: const Text(
                    'Nhịp thở tự nhiên (Humanized Deep Rest)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Dừng nghỉ theo chu kỳ né bot TikTok',
                    style: TextStyle(color: ClearTokColors.muted, fontSize: 11),
                  ),
                  value: pulseJitter,
                  onChanged: (val) {
                    setModalState(() => pulseJitter = val);
                    widget.database.setPulseJitterEnabled(val);
                    setState(() {});
                  },
                ),
                if (pulseJitter) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cứ sau $deepBatch mục sẽ nghỉ sâu $deepSec giây giải nhiệt.',
                    style: const TextStyle(
                      color: ClearTokColors.cyan,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? ClearTokColors.pink : ClearTokColors.raised,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final int itemCount = (_currentHub == 'unfollow')
        ? _followingUsers.length
        : _videos.length;

    final String scanBtnText = _isScanning
        ? (_scanBatchLimit > 0
              ? '$_currentScannedCount/$_scanBatchLimit'
              : 'Quét: $_currentScannedCount')
        : (_currentHub == 'unfollow'
              ? 'Quét Follow (${_scanBatchLimit > 0 ? "$_scanBatchLimit" : "Hết"})'
              : (_currentHub == 'unlike'
                    ? 'Quét Thích (${_scanBatchLimit > 0 ? "$_scanBatchLimit" : "Hết"})'
                    : 'Quét Repost (${_scanBatchLimit > 0 ? "$_scanBatchLimit" : "Hết"})'));

    final String actionBtnText = _currentHub == 'unfollow'
        ? 'Hủy Follow (${_selectedIds.length})'
        : (_currentHub == 'unlike'
              ? 'Bỏ Thích (${_selectedIds.length})'
              : 'Hủy Repost (${_selectedIds.length})');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .58,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Top App Bar
                      LiquidGlassContainer(
                        margin: const EdgeInsets.symmetric(
                          horizontal: ClearTokTokens.inset,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/brand/app_icon.jpg',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                semanticLabel: 'ClearTok Pro',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ClearTok Studio Pro',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: user != null
                                              ? ClearTokColors.success
                                              : ClearTokColors.warning,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          user != null
                                              ? '@${user.uniqueId}'
                                              : 'Chưa kết nối tài khoản',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: user != null
                                                ? ClearTokColors.secondary
                                                : ClearTokColors.warning,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: _toolsExpanded
                                  ? 'Thu gọn công cụ'
                                  : 'Mở rộng công cụ',
                              icon: Icon(
                                _toolsExpanded ? Icons.expand_less : Icons.tune,
                                color: ClearTokColors.cyan,
                              ),
                              onPressed: () {
                                setState(
                                  () => _toolsExpanded = !_toolsExpanded,
                                );
                                widget.database.setStudioToolsExpanded(
                                  _toolsExpanded,
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Menu Studio',
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: ClearTokColors.cyan,
                              ),
                              color: ClearTokColors.surface.withValues(
                                alpha: .96,
                              ),
                              elevation: 2,
                              shadowColor: Colors.transparent,
                              surfaceTintColor: Colors.transparent,
                              position: PopupMenuPosition.under,
                              offset: const Offset(0, 8),
                              constraints: const BoxConstraints(
                                minWidth: 270,
                                maxWidth: 310,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                                side: const BorderSide(
                                  color: ClearTokColors.border,
                                ),
                              ),
                              onSelected: (value) {
                                if (value == 'analytics') {
                                  _showAnalyticsModal();
                                }
                                if (value == 'export') _showExportModal();
                                if (value == 'settings') {
                                  _showSettingsModal();
                                }
                                if (value == 'update') {
                                  AppUpdates.check(
                                    context,
                                    widget.database,
                                    manual: true,
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                _studioMenuItem(
                                  'analytics',
                                  Icons.insights_rounded,
                                  ClearTokColors.cyan,
                                  'Thống kê',
                                  'Tổng quan tương tác của bạn',
                                ),
                                _studioMenuItem(
                                  'export',
                                  Icons.file_download_outlined,
                                  ClearTokColors.cyan,
                                  'Xuất CSV/JSON',
                                  'Lưu báo cáo vào thiết bị',
                                ),
                                _studioMenuItem(
                                  'settings',
                                  Icons.tune_rounded,
                                  ClearTokColors.pink,
                                  'Cài đặt',
                                  'Tùy chỉnh nhịp xử lý',
                                ),
                                _studioMenuItem(
                                  'update',
                                  Icons.system_update_rounded,
                                  ClearTokColors.pink,
                                  'Kiểm tra cập nhật',
                                  'Khám phá phiên bản mới',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Studio Hub Switcher: Reposts | Mass Un-Like | Mass Un-Follow
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: glass.GlassSegmentedControl(
                          segments: const [
                            glass.GlassSegment(
                              label: 'Reposts',
                              icon: Icon(Icons.repeat_rounded),
                            ),
                            glass.GlassSegment(
                              label: 'Mass Un-Like',
                              icon: Icon(Icons.favorite_border_rounded),
                            ),
                            glass.GlassSegment(
                              label: 'Mass Un-Follow',
                              icon: Icon(Icons.person_remove_rounded),
                            ),
                          ],
                          selectedIndex: const [
                            'repost',
                            'unlike',
                            'unfollow',
                          ].indexOf(_currentHub),
                          onSegmentSelected: (index) {
                            setState(() {
                              _currentHub = const [
                                'repost',
                                'unlike',
                                'unfollow',
                              ][index];
                              _searchQuery = '';
                              _filterAuthor = null;
                              _filterYear = null;
                            });
                            _loadItems();
                          },
                          height: 56,
                          selectedTextStyle: Theme.of(context)
                              .textTheme
                              .labelMedium!
                              .copyWith(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                          unselectedTextStyle: Theme.of(context)
                              .textTheme
                              .labelMedium!
                              .copyWith(
                                color: ClearTokColors.secondary,
                                fontSize: 11,
                              ),
                          selectedIconColor: ClearTokColors.cyan,
                          unselectedIconColor: ClearTokColors.secondary,
                          backgroundColor: Colors.white.withValues(alpha: .06),
                          indicatorColor: ClearTokColors.pink.withValues(
                            alpha: .22,
                          ),
                          settings: glass.LiquidGlassSettings.ios27Dark,
                          quality: glass.GlassQuality.premium,
                          useOwnLayer: true,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (_toolsExpanded) ...[
                        // Hero Metric Cards
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildMetricCard(
                                title: 'Đã Quét',
                                value: '$itemCount',
                                color: ClearTokColors.cyan,
                                icon: Icons.video_library_rounded,
                              ),
                              const SizedBox(width: 10),
                              _buildMetricCard(
                                title: 'Đã Xử Lý',
                                value: '${widget.database.totalDeletedCount}',
                                color: ClearTokColors.cyan,
                                icon: Icons.delete_sweep_rounded,
                              ),
                              const SizedBox(width: 10),
                              _buildMetricCard(
                                title: 'Hạn Mức',
                                value: 'VÔ HẠN ∞',
                                color: ClearTokColors.pink,
                                icon: Icons.all_inclusive_rounded,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Scan Batch Limit Selector Bar (50 | 100⭐ | 200 | Tất cả)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 14,
                                color: ClearTokColors.cyan,
                              ),
                              const Text(
                                'Đợt quét:',
                                style: TextStyle(
                                  color: ClearTokColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                              _buildScanLimitPill('50', 50),
                              _buildScanLimitPill('100', 100),
                              _buildScanLimitPill('200', 200),
                              _buildScanLimitPill('Hết ∞', 0),
                            ],
                          ),
                        ),
                      ],

                      // Quick Actions: Scan & Action
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GlassActionButton(
                                icon: _isScanning
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                label: scanBtnText,
                                onPressed: _isScanning ? null : _startScan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassActionButton(
                                primary: true,
                                icon: const Icon(Icons.delete_forever_rounded),
                                label: actionBtnText,
                                onPressed: _triggerBatchAction,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_toolsExpanded) ...[
                        // Filter Chips Bar
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              _buildFilterChip('Tất cả ($itemCount)', 'all'),
                              _buildFilterChip(
                                'Đã chọn (${_selectedIds.length})',
                                'selected',
                              ),
                              if (_currentHub != 'unfollow') ...[
                                _buildFilterChip('Nhiều Like', 'most_liked'),
                                _buildFilterChip('Mới nhất', 'newest'),
                                _buildFilterChip('Cũ nhất', 'oldest'),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.person_search_rounded,
                                    size: 16,
                                    color: ClearTokColors.cyan,
                                  ),
                                  label: Text(
                                    _filterAuthor != null
                                        ? '@$_filterAuthor'
                                        : 'Theo Tác Giả',
                                    style: TextStyle(
                                      color: _filterAuthor != null
                                          ? Colors.white
                                          : ClearTokColors.secondary,
                                      fontSize: 12,
                                      fontWeight: _filterAuthor != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  backgroundColor: _filterAuthor != null
                                      ? ClearTokColors.pink
                                      : ClearTokColors.surface,
                                  onPressed: _showAuthorFilterModal,
                                ),
                              ],
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedIds.length == itemCount) {
                                      _selectedIds.clear();
                                    } else {
                                      _selectedIds.clear();
                                      if (_currentHub == 'unfollow') {
                                        _selectedIds.addAll(
                                          _followingUsers.map((u) => u.id),
                                        );
                                      } else {
                                        _selectedIds.addAll(
                                          _videos.map((v) => v.id),
                                        );
                                      }
                                    }
                                  });
                                },
                                icon: Icon(
                                  _selectedIds.length == itemCount
                                      ? Icons.deselect
                                      : Icons.select_all,
                                  size: 16,
                                  color: ClearTokColors.cyan,
                                ),
                                label: Text(
                                  _selectedIds.length == itemCount
                                      ? 'Bỏ chọn'
                                      : 'Chọn hết',
                                  style: const TextStyle(
                                    color: ClearTokColors.cyan,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: TextField(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: _currentHub == 'unfollow'
                                  ? 'Tìm kiếm theo tên kênh @username...'
                                  : 'Tìm theo tác giả hoặc nội dung...',
                              hintStyle: const TextStyle(
                                color: ClearTokColors.muted,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: ClearTokColors.muted,
                                size: 20,
                              ),
                              suffixIcon:
                                  (_searchQuery.isNotEmpty ||
                                      _filterAuthor != null)
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: ClearTokColors.muted,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() {
                                        _searchQuery = '';
                                        _filterAuthor = null;
                                      }),
                                    )
                                  : null,
                              filled: true,
                              fillColor: ClearTokColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ClearTokTokens.radius,
                                ),
                                borderSide: const BorderSide(
                                  color: ClearTokColors.border,
                                ),
                              ),
                            ),
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Main Content Area: Videos Grid or Following Users List
              Expanded(
                child: _currentHub == 'unfollow'
                    ? _buildFollowingList()
                    : _buildVideosGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _studioMenuItem(
    String value,
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 76,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ClearTokColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: ClearTokColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: ClearTokColors.cyan, size: 22),
        const SizedBox(width: ClearTokTokens.gap),
        Expanded(child: Text(title, style: ClearTokTokens.title)),
        IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildFollowingList() {
    if (_filteredFollowing.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_search_rounded,
              size: 64,
              color: ClearTokColors.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              _followingUsers.isEmpty
                  ? 'Chưa quét danh sách Following nào!'
                  : 'Không tìm thấy tài khoản nào khớp tìm kiếm.',
              style: const TextStyle(color: ClearTokColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_followingUsers.isEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClearTokColors.raised,
                ),
                icon: const Icon(Icons.sync),
                label: const Text('Bấm Quét Following'),
                onPressed: _startScan,
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        ClearTokTokens.dockClearance +
            MediaQuery.of(context).viewPadding.bottom,
      ),
      itemCount: _filteredFollowing.length,
      itemBuilder: (ctx, idx) {
        final u = _filteredFollowing[idx];
        final isSelected = _selectedIds.contains(u.id);

        return LiquidGlassContainer(
          key: ValueKey(u.id),
          blur: false,
          isSelected: isSelected,
          margin: const EdgeInsets.only(bottom: 10),
          borderRadius: 18,
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: u.avatarThumb.isNotEmpty
                  ? NetworkImage(u.avatarThumb)
                  : null,
              backgroundColor: ClearTokColors.raised,
              child: u.avatarThumb.isEmpty
                  ? Text(
                      u.uniqueId.isNotEmpty ? u.uniqueId[0].toUpperCase() : '?',
                      style: const TextStyle(color: ClearTokColors.cyan),
                    )
                  : null,
            ),
            title: Text(
              '@${u.uniqueId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              u.nickname.isNotEmpty
                  ? u.nickname
                  : (u.bio.isNotEmpty ? u.bio : 'TikTok Creator'),
              style: const TextStyle(
                color: ClearTokColors.secondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Checkbox(
              value: isSelected,
              activeColor: ClearTokColors.pink,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(u.id);
                  } else {
                    _selectedIds.remove(u.id);
                  }
                });
              },
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(u.id);
                } else {
                  _selectedIds.add(u.id);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildVideosGrid() {
    if (_filteredVideos.isEmpty) {
      final emptyText = _videos.isEmpty
          ? (_currentHub == 'unlike'
                ? 'Chưa quét được video đã thích nào!'
                : 'Chưa quét được repost nào!')
          : 'Không có video nào khớp bộ lọc.';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_collection_outlined,
              size: 64,
              color: ClearTokColors.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: const TextStyle(color: ClearTokColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_videos.isEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClearTokColors.raised,
                ),
                icon: const Icon(Icons.sync),
                label: const Text('Bấm Quét Ngay'),
                onPressed: _startScan,
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        ClearTokTokens.dockClearance +
            MediaQuery.of(context).viewPadding.bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _filteredVideos.length,
      itemBuilder: (ctx, idx) {
        final v = _filteredVideos[idx];
        final isSelected = _selectedIds.contains(v.id);

        return Semantics(
          key: ValueKey('video-${v.id}'),
          selected: isSelected,
          button: true,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ClearTokTokens.radius),
              border: Border.all(
                color: isSelected ? ClearTokColors.pink : Colors.white10,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ClearTokTokens.radius),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      v.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: ClearTokColors.surface,
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ClearTokColors.pink
                            : Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.circle_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${v.authorUsername}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: ClearTokColors.pink,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${v.diggCount}',
                              style: const TextStyle(
                                color: ClearTokColors.secondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          ClearTokTokens.radius,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(v.id);
                            } else {
                              _selectedIds.add(v.id);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanLimitPill(String label, int limit) {
    return ChoiceChip(
      label: Text(label),
      selected: _scanBatchLimit == limit,
      onSelected: (_) {
        setState(() => _scanBatchLimit = limit);
        widget.database.setScanBatchLimit(limit);
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: LiquidGlassContainer(
        blur: false,
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ClearTokColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String id) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          id == 'most_liked'
              ? Icons.favorite_border_rounded
              : id == 'newest'
              ? Icons.arrow_upward_rounded
              : id == 'oldest'
              ? Icons.arrow_downward_rounded
              : id == 'selected'
              ? Icons.check_circle_outline
              : Icons.filter_list_rounded,
          size: 16,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ClearTokColors.secondary,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: ClearTokColors.pink.withValues(alpha: .18),
        backgroundColor: ClearTokColors.surface,
        onSelected: (_) => setState(() => _selectedFilter = id),
      ),
    );
  }
}
