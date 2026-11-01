import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/tiktok_client.dart';
import '../../database/local_database.dart';
import '../../models/tiktok_follow_user.dart';
import '../../models/tiktok_video.dart';
import '../../services/export_analytics_service.dart';
import '../../services/tiktok_deletion_engine.dart';
import '../widgets/project_credits.dart';
import '../../services/app_updates.dart';

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
      list = list.where((v) => dfYear.format(v.repostDateTime) == _filterYear).toList();
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
      _showSnack('Vui lòng qua tab "TikTok Web" đăng nhập trước nhé anh yêu!', isError: true);
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
          final items = res.users.where((u) => u.id.isNotEmpty && seenIds.add(u.id))
              .take(targetLimit > 0 ? targetLimit - totalFound : res.users.length).toList();
          await widget.database.saveFollowing(items);
          totalFound += items.length;

          setState(() {
            _currentScannedCount = totalFound;
            _loadItems();
          });

          if (targetLimit > 0 && totalFound >= targetLimit) break;
          if (res.hasMore && !followingCursors.add((res.nextCursor, res.nextMinCursor))) {
            throw Exception('Đã lưu $totalFound tài khoản. TikTok chưa trả cursor mới; mở Log xem scan.following.');
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
          final items = res.videos.where((v) => v.id.isNotEmpty && seenIds.add(v.id))
              .take(targetLimit > 0 ? targetLimit - totalFound : res.videos.length).toList();

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
            throw Exception('TikTok lặp cursor sau $totalFound mục; chưa quét hết.');
          }
          if (res.nextCursor <= 0 || res.nextCursor == cursor || res.nextCursor == previousCursor) {
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
        final limitDesc = targetLimit > 0 ? '$totalFound / $targetLimit' : '$totalFound';
        _showSnack('Quét hoàn tất đợt này: $limitDesc $modeLabel! Anh có thể xử lý ngay.');
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
        : (_currentHub == 'unlike' ? 'Không tìm thấy video đã thích' : 'Không tìm thấy video Repost');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF25F4EE), size: 28),
            SizedBox(width: 10),
            Text('Kết Quả Quét', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
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
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE2C55),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      _showSnack('Chưa kết nối WebView TikTok, vui lòng mở tab TikTok Web trước!', isError: true);
      return;
    }

    final int selectedCount = _selectedIds.length;
    if (selectedCount == 0) {
      _showSnack('Chưa chọn mục nào để xử lý cơ mà!', isError: true);
      return;
    }

    final actionLabel = _currentHub == 'unfollow'
        ? 'hủy theo dõi $selectedCount tài khoản'
        : (_currentHub == 'unlike' ? 'bỏ thích $selectedCount video' : 'hủy $selectedCount repost');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFE2C55), size: 28),
            SizedBox(width: 10),
            Text('Xác Nhận Xử Lý', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anh có chắc chắn muốn $actionLabel này không?',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                      const Icon(Icons.bolt, color: Color(0xFF25F4EE), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tốc độ: ${widget.database.customDelayMs}ms (Bypass Quota: Vô Hạn ∞)',
                          style: const TextStyle(color: Color(0xFF25F4EE), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (widget.database.pulseJitterEnabled) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anti-Ban: Nghỉ ${widget.database.deepRestDurationSec}s sau mỗi ${widget.database.deepRestBatchCount} mục',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
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
            child: const Text('Hủy Bỏ', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE2C55),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startLiveModal();
            },
            child: const Text('Bắt Đầu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startLiveModal() {
    final engine = _freshEngine();
    final int total = _selectedIds.length;
    final hubMode = _currentHub;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StreamBuilder<BatchDeletionProgress>(
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
          final isRunning = prog != null &&
              (prog.status == DeletionStatus.running ||
                  prog.status == DeletionStatus.paused ||
                  prog.status == DeletionStatus.deepResting);
          final isDeepResting = prog?.status == DeletionStatus.deepResting;
          final isDone = prog != null &&
              (prog.status == DeletionStatus.completed || prog.status == DeletionStatus.stopped || prog.status == DeletionStatus.error);

          final titleText = hubMode == 'unfollow'
              ? 'Hủy Follow Hàng Loạt'
              : (hubMode == 'unlike' ? 'Bỏ Thích Hàng Loạt' : 'Hủy Repost Hàng Loạt');

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDeepResting
                                  ? Colors.greenAccent.withOpacity(0.2)
                                  : const Color(0xFFFE2C55).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDeepResting
                                  ? Icons.spa_rounded
                                  : (hubMode == 'unfollow' ? Icons.person_remove_rounded : Icons.delete_sweep),
                              color: isDeepResting ? Colors.greenAccent : const Color(0xFFFE2C55),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDeepResting ? 'Anti-Ban: Đang Giải Nhiệt' : titleText,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                prog != null
                                    ? '${prog.deleted} / ${prog.total} (${prog.failed} lỗi)'
                                    : 'Khởi động...',
                                style: TextStyle(
                                  color: isDeepResting ? Colors.greenAccent : const Color(0xFF25F4EE),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                      value: (prog != null && prog.total > 0) ? prog.deleted / prog.total : null,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDeepResting ? Colors.greenAccent : const Color(0xFFFE2C55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDeepResting ? const Color(0xFF0F241E) : Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDeepResting ? Colors.greenAccent.withOpacity(0.3) : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prog?.message ?? 'Đang kết nối tới TikTok...',
                          style: TextStyle(
                            color: isDeepResting ? Colors.greenAccent : Colors.white,
                            fontSize: 13,
                            fontWeight: isDeepResting ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (prog?.lastErrorDetail != null && prog!.lastErrorDetail!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Chi tiết: ${prog.lastErrorDetail}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
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
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              if (prog?.status == DeletionStatus.paused) {
                                engine.resume();
                              } else {
                                engine.pause();
                              }
                            },
                            child: Text(prog?.status == DeletionStatus.paused ? 'Tiếp Tục' : 'Tạm Dừng'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => engine.stop(),
                            child: const Text('Dừng Hẳn'),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFE2C55),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );

    // Launch appropriate batch runner
    Future.microtask(() {
      if (hubMode == 'unfollow') {
        final targetUsers = _followingUsers.where((u) => _selectedIds.contains(u.id)).toList();
        engine.executeUnfollowBatch(targetUsers);
      } else {
        final targetVideos = _videos.where((v) => _selectedIds.contains(v.id)).toList();
        engine.executeBatch(targetVideos, mode: hubMode);
      }
    });
  }

  void _showAuthorFilterModal() {
    final analytics = StudioAnalytics.fromVideos(_videos);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lọc Theo Tác Giả (@Creator)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            if (analytics.topAuthors.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child: Text('Chưa có dữ liệu tác giả nào!', style: TextStyle(color: Colors.white54))),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: analytics.topAuthors.length + 1,
                  itemBuilder: (ctx, idx) {
                    if (idx == 0) {
                      return ListTile(
                        leading: const Icon(Icons.all_inclusive, color: Color(0xFF25F4EE)),
                        title: const Text('Tất cả tác giả', style: TextStyle(color: Colors.white)),
                        trailing: _filterAuthor == null
                            ? const Icon(Icons.check, color: Color(0xFFFE2C55))
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
                        backgroundColor: const Color(0xFF1E2235),
                        child: Text(a.username.isNotEmpty ? a.username[0].toUpperCase() : '?',
                            style: const TextStyle(color: Color(0xFFFE2C55))),
                      ),
                      title: Text('@${a.username}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text('${a.count} mục • ❤️ ${a.totalLikes}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFFE2C55)) : null,
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
    );
  }

  void _showAnalyticsModal() {
    final analytics = StudioAnalytics.fromVideos(_videos);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.insights_rounded, color: Color(0xFF25F4EE), size: 24),
                    SizedBox(width: 10),
                    Text('Thống Kê Studio',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatPill('Tổng Đã Quét', '${_videos.length}', const Color(0xFF8A2BE2)),
                const SizedBox(width: 8),
                _buildStatPill('Tổng Like ❤️', '${analytics.totalLikes}', const Color(0xFFFE2C55)),
                const SizedBox(width: 8),
                _buildStatPill('Like TB', analytics.avgLikes.toStringAsFixed(1), const Color(0xFF00E5FF)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Top Tác Giả Xuất Hiện Nhiều Nhất:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (analytics.topAuthors.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có dữ liệu!', style: TextStyle(color: Colors.white38))))
            else
              ...analytics.topAuthors.take(5).map(
                    (a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('@${a.username}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          Text('${a.count} mục (${a.totalLikes} like)',
                              style: const TextStyle(color: Color(0xFF25F4EE), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String title, String val, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: col.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: col.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  void _showExportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sao Lưu & Xuất Dữ Liệu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Lưu trữ danh sách video về máy trước khi thao tác hàng loạt.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2235),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF25F4EE)),
                    label: const Text('Copy CSV'),
                    onPressed: () {
                      final csv = ExportAnalyticsService.exportToCsv(_videos);
                      Clipboard.setData(ClipboardData(text: csv));
                      Navigator.pop(ctx);
                      _showSnack('Đã copy toàn bộ ${_videos.length} video dạng CSV!');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFE2C55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.data_object_rounded),
                    label: const Text('Copy JSON'),
                    onPressed: () {
                      final jsonStr = ExportAnalyticsService.exportToJson(_videos);
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      Navigator.pop(ctx);
                      _showSnack('Đã copy toàn bộ ${_videos.length} video dạng JSON!');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
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
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Smart Anti-Ban & Tốc Độ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildPresetButton('🚀 Turbo', () {
                    setModalState(() {
                      currentDelay = 300;
                      pulseJitter = false;
                    });
                    widget.database.setCustomDelayMs(300);
                    widget.database.setPulseJitterEnabled(false);
                    setState(() {});
                  }),
                  const SizedBox(width: 8),
                  _buildPresetButton('⚖️ Cân Bằng', () {
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
                  _buildPresetButton('🛡️ Siêu An Toàn', () {
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
                  const Text('Thời gian nghỉ giữa mỗi lượt:', style: TextStyle(color: Colors.white70)),
                  Text('${currentDelay}ms',
                      style: const TextStyle(color: Color(0xFF25F4EE), fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: currentDelay.toDouble(),
                min: 200,
                max: 2000,
                divisions: 18,
                activeColor: const Color(0xFFFE2C55),
                inactiveColor: Colors.white12,
                label: '${currentDelay}ms',
                onChanged: (val) {
                  setModalState(() => currentDelay = val.toInt());
                  setState(() => widget.database.setCustomDelayMs(val.toInt()));
                },
              ),
              const Divider(color: Colors.white10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.greenAccent,
                title: const Text('Nhịp thở tự nhiên (Humanized Deep Rest)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Dừng nghỉ theo chu kỳ né bot TikTok',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                value: pulseJitter,
                onChanged: (val) {
                  setModalState(() => pulseJitter = val);
                  widget.database.setPulseJitterEnabled(val);
                  setState(() {});
                },
              ),
              if (pulseJitter) ...[
                const SizedBox(height: 8),
                Text('Cứ sau $deepBatch mục sẽ nghỉ sâu $deepSec giây giải nhiệt.',
                    style: const TextStyle(color: Color(0xFF25F4EE), fontSize: 12)),
              ],
              const SizedBox(height: 16),
            ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFFE2C55) : const Color(0xFF1E2235),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final int itemCount = (_currentHub == 'unfollow') ? _followingUsers.length : _videos.length;

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
        : (_currentHub == 'unlike' ? 'Bỏ Thích (${_selectedIds.length})' : 'Hủy Repost (${_selectedIds.length})');

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFE2C55), Color(0xFF25F4EE)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ClearTok Studio Pro',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: user != null ? Colors.greenAccent : Colors.amberAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user != null ? '@${user.uniqueId}' : 'Chưa kết nối tài khoản',
                              style: TextStyle(
                                fontSize: 12,
                                color: user != null ? Colors.white70 : Colors.amberAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context, isScrollControlled: true,
                      builder: (ctx) => SafeArea(child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Align(alignment: Alignment.topRight, child: IconButton(
                            tooltip: 'Đóng credit', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))),
                          const ProjectCredits(expanded: true),
                        ])))),
                    child: const Text('D&K', style: TextStyle(color: Color(0xFF25F4EE), fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    tooltip: _toolsExpanded ? 'Thu gọn công cụ' : 'Mở rộng công cụ',
                    icon: Icon(_toolsExpanded ? Icons.expand_less : Icons.tune, color: const Color(0xFF25F4EE)),
                    onPressed: () {
                      setState(() => _toolsExpanded = !_toolsExpanded);
                      widget.database.setStudioToolsExpanded(_toolsExpanded);
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Menu Studio',
                    onSelected: (value) {
                      if (value == 'analytics') _showAnalyticsModal();
                      if (value == 'export') _showExportModal();
                      if (value == 'settings') _showSettingsModal();
                      if (value == 'update') AppUpdates.check(context, widget.database, manual: true);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'analytics', child: Text('Thống kê')),
                      PopupMenuItem(value: 'export', child: Text('Xuất CSV/JSON')),
                      PopupMenuItem(value: 'settings', child: Text('Cài đặt')),
                      PopupMenuItem(value: 'update', child: Text('Kiểm tra cập nhật')),
                    ],
                  ),
                ],
              ),
            ),

            // Studio Hub Switcher: Reposts | Mass Un-Like | Mass Un-Follow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161926),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    _buildHubTab('Reposts', 'repost', Icons.repeat_rounded),
                    _buildHubTab('Mass Un-Like', 'unlike', Icons.favorite_border_rounded),
                    _buildHubTab('Mass Un-Follow', 'unfollow', Icons.person_remove_rounded),
                  ],
                ),
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
                    color: const Color(0xFF8A2BE2),
                    icon: Icons.video_library_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricCard(
                    title: 'Đã Xử Lý',
                    value: '${widget.database.totalDeletedCount}',
                    color: const Color(0xFF00E5FF),
                    icon: Icons.delete_sweep_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricCard(
                    title: 'Hạn Mức',
                    value: 'VÔ HẠN ∞',
                    color: const Color(0xFFFE2C55),
                    icon: Icons.all_inclusive_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Scan Batch Limit Selector Bar (50 | 100⭐ | 200 | Tất cả)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF25F4EE)),
                  const SizedBox(width: 6),
                  const Text('Đợt quét:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const Spacer(),
                  _buildScanLimitPill('50', 50),
                  const SizedBox(width: 6),
                  _buildScanLimitPill('100 ⭐', 100),
                  const SizedBox(width: 6),
                  _buildScanLimitPill('200', 200),
                  const SizedBox(width: 6),
                  _buildScanLimitPill('Hết ∞', 0),
                ],
              ),
            ),

            ],

            // Quick Actions: Scan & Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2235),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync_rounded),
                      label: Text(scanBtnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _isScanning ? null : _startScan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFE2C55),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: Text(actionBtnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả ($itemCount)', 'all'),
                  _buildFilterChip('Đã chọn (${_selectedIds.length})', 'selected'),
                  if (_currentHub != 'unfollow') ...[
                    _buildFilterChip('Nhiều Like ❤️', 'most_liked'),
                    _buildFilterChip('Mới nhất 🔥', 'newest'),
                    _buildFilterChip('Cũ nhất 🕰', 'oldest'),
                    ActionChip(
                      avatar: const Icon(Icons.person_search_rounded, size: 16, color: Color(0xFF25F4EE)),
                      label: Text(
                        _filterAuthor != null ? '@$_filterAuthor' : 'Theo Tác Giả',
                        style: TextStyle(
                          color: _filterAuthor != null ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: _filterAuthor != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      backgroundColor: _filterAuthor != null ? const Color(0xFFFE2C55) : const Color(0xFF161926),
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
                            _selectedIds.addAll(_followingUsers.map((u) => u.id));
                          } else {
                            _selectedIds.addAll(_videos.map((v) => v.id));
                          }
                        }
                      });
                    },
                    icon: Icon(
                      _selectedIds.length == itemCount ? Icons.deselect : Icons.select_all,
                      size: 16,
                      color: const Color(0xFF25F4EE),
                    ),
                    label: Text(
                      _selectedIds.length == itemCount ? 'Bỏ chọn' : 'Chọn hết',
                      style: const TextStyle(color: Color(0xFF25F4EE), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _currentHub == 'unfollow'
                      ? 'Tìm kiếm theo tên kênh @username...'
                      : 'Tìm theo tác giả hoặc nội dung...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: (_searchQuery.isNotEmpty || _filterAuthor != null)
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _filterAuthor = null;
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF161926),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            ],

            // Main Content Area: Videos Grid or Following Users List
            Expanded(
              child: _currentHub == 'unfollow'
                  ? _buildFollowingList()
                  : _buildVideosGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_filteredFollowing.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            Text(
              _followingUsers.isEmpty
                  ? 'Chưa quét danh sách Following nào!'
                  : 'Không tìm thấy tài khoản nào khớp tìm kiếm.',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (_followingUsers.isEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2235)),
                icon: const Icon(Icons.sync),
                label: const Text('Bấm Quét Following'),
                onPressed: _startScan,
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFollowing.length,
      itemBuilder: (ctx, idx) {
        final u = _filteredFollowing[idx];
        final isSelected = _selectedIds.contains(u.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161926),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? const Color(0xFFFE2C55) : Colors.white10),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: u.avatarThumb.isNotEmpty ? NetworkImage(u.avatarThumb) : null,
              backgroundColor: const Color(0xFF1E2235),
              child: u.avatarThumb.isEmpty
                  ? Text(u.uniqueId.isNotEmpty ? u.uniqueId[0].toUpperCase() : '?',
                      style: const TextStyle(color: Color(0xFF25F4EE)))
                  : null,
            ),
            title: Text('@${u.uniqueId}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              u.nickname.isNotEmpty ? u.nickname : (u.bio.isNotEmpty ? u.bio : 'TikTok Creator'),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Checkbox(
              value: isSelected,
              activeColor: const Color(0xFFFE2C55),
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
          ? (_currentHub == 'unlike' ? 'Chưa quét được video đã thích nào!' : 'Chưa quét được repost nào!')
          : 'Không có video nào khớp bộ lọc.';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_collection_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            Text(emptyText, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 12),
            if (_videos.isEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E2235)),
                icon: const Icon(Icons.sync),
                label: const Text('Bấm Quét Ngay'),
                onPressed: _startScan,
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
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

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(v.id);
              } else {
                _selectedIds.add(v.id);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFFE2C55) : Colors.white10,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFE2C55).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      v.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF161926),
                        child: const Icon(Icons.movie, color: Colors.white24, size: 40),
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
                        color: isSelected ? const Color(0xFFFE2C55) : Colors.black54,
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
                            const Icon(Icons.favorite, color: Color(0xFFFE2C55), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${v.diggCount}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
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
    final isSelected = _scanBatchLimit == limit;
    return GestureDetector(
      onTap: () {
        setState(() => _scanBatchLimit = limit);
        widget.database.setScanBatchLimit(limit);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFE2C55) : const Color(0xFF161926),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFE2C55) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHubTab(String label, String id, IconData icon) {
    final isSelected = _currentHub == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentHub = id;
            _searchQuery = '';
            _filterAuthor = null;
            _filterYear = null;
          });
          _loadItems();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFE2C55) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white60),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161926),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
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
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12)),
        selected: isSelected,
        selectedColor: const Color(0xFFFE2C55),
        backgroundColor: const Color(0xFF161926),
        onSelected: (_) => setState(() => _selectedFilter = id),
      ),
    );
  }
}
