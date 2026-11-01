import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/tiktok_client.dart';
import '../../database/local_database.dart';
import '../../models/tiktok_video.dart';
import '../../services/export_analytics_service.dart';
import '../../services/tiktok_deletion_engine.dart';

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
  final Set<String> _selectedIds = {};
  bool _isScanning = false;
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
    _loadVideos();
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

  void _loadVideos() {
    setState(() {
      _videos = widget.database.getAllReposts();
      _selectedIds.clear();
      _selectedIds.addAll(_videos.map((v) => v.id));
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
    final int targetLimit = _scanBatchLimit; // 50, 100, 200, or 0 (unlimited)

    try {
      while (hasMore && (targetLimit <= 0 || totalFound < targetLimit)) {
        final res = await widget.client!.fetchRepostBatch(
          cursor: cursor,
          secUid: widget.currentUser!.secUid,
        );

        if (res.videos.isEmpty) break;
        await widget.database.saveReposts(res.videos);
        totalFound += res.videos.length;
        cursor = res.nextCursor;
        hasMore = res.hasMore;

        setState(() {
          _currentScannedCount = totalFound;
          _loadVideos();
        });

        // Batch limit reached: stop early as requested to prevent freezing
        if (targetLimit > 0 && totalFound >= targetLimit) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (totalFound > 0) {
        final limitDesc = targetLimit > 0 ? '$totalFound / $targetLimit bài' : '$totalFound bài';
        _showSnack('Quét hoàn tất đợt này: $limitDesc! Anh có thể hủy ngay hoặc quét tiếp.');
      } else {
        _showNoRepostDialog();
      }
    } catch (e) {
      _showSnack('Lỗi quét: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showNoRepostDialog() {
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
            const Text(
              'TikTok phản hồi không tìm thấy video Repost nào (0 video).',
              style: TextStyle(color: Colors.white, fontSize: 14),
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
                'Mẹo: Nếu tài khoản chắc chắn có video đã Repost, hãy bấm nút dưới đây để chuyển sang tab TikTok Web Desktop và bấm vào biểu tượng "Người" (Trang cá nhân) để TikTok tải dữ liệu Repost lên trước nhé!',
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
            child: const Text('Mở TikTok Web Desktop'),
          ),
        ],
      ),
    );
  }

  void _triggerBatchDelete() {
    if (widget.client == null) {
      _showSnack('Chưa kết nối WebView TikTok, vui lòng mở tab TikTok Web trước!', isError: true);
      return;
    }

    final targets = _videos.where((v) => _selectedIds.contains(v.id)).toList();

    if (targets.isEmpty) {
      _showSnack('Chưa chọn video nào để xóa cơ mà!', isError: true);
      return;
    }

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
            Text('Xác Nhận Hủy Repost', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anh có chắc chắn muốn hủy ${targets.length} repost này trên TikTok không?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                      const Icon(Icons.bolt, color: Color(0xFF25F4EE), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tốc độ: ${widget.database.customDelayMs}ms / video (Vô Hạn Quota ∞)',
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
                            'Anti-Ban: Nghỉ ${widget.database.deepRestDurationSec}s sau mỗi ${widget.database.deepRestBatchCount} video',
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
              _startLiveDeletionModal(targets);
            },
            child: const Text('Bắt Đầu Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startLiveDeletionModal(List<TikTokVideo> targets) {
    final engine = _freshEngine();

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
          total: targets.length,
          deleted: 0,
          failed: 0,
          status: DeletionStatus.running,
          message: 'Khởi động tiến trình hủy ${targets.length} repost...',
        ),
        builder: (ctx, snapshot) {
          final prog = snapshot.data;
          final isRunning = prog != null &&
              (prog.status == DeletionStatus.running ||
                  prog.status == DeletionStatus.paused ||
                  prog.status == DeletionStatus.deepResting);
          final isDeepResting = prog?.status == DeletionStatus.deepResting;
          final isDone = prog != null &&
              (prog.status == DeletionStatus.completed || prog.status == DeletionStatus.stopped);

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
                              isDeepResting ? Icons.spa_rounded : Icons.delete_sweep,
                              color: isDeepResting ? Colors.greenAccent : const Color(0xFFFE2C55),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDeepResting ? 'Anti-Ban: Đang Giải Nhiệt' : 'Đang Hủy Repost Hàng Loạt',
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
                            setState(() => _loadVideos());
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
                              setState(() => _loadVideos());
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

    Future.microtask(() => engine.executeBatch(targets));
  }

  // ─── MODAL 1: Smart Filter By Author ─────────────────────────────────────
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
                      subtitle: Text('${a.count} repost • ❤️ ${a.totalLikes}',
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

  // ─── MODAL 2: Analytics Dashboard ─────────────────────────────────────────
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
                    Text('Thống Kê Repost Studio',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatPill('Tổng Video', '${analytics.totalVideos}', const Color(0xFF8A2BE2)),
                const SizedBox(width: 8),
                _buildStatPill('Tổng Like ❤️', '${analytics.totalLikes}', const Color(0xFFFE2C55)),
                const SizedBox(width: 8),
                _buildStatPill('Like TB/Video', analytics.avgLikes.toStringAsFixed(1), const Color(0xFF00E5FF)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Top Tác Giả Bạn Repost Nhiều Nhất:',
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
                          Text('${a.count} video (${a.totalLikes} like)',
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

  // ─── MODAL 3: Export CSV & JSON ───────────────────────────────────────────
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
              'Lưu trữ danh sách video repost về máy trước khi hủy để không bị mất link hoặc tác giả yêu thích.',
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
                      _showSnack('Đã copy toàn bộ ${_videos.length} video dạng CSV vào bộ nhớ tạm!');
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
                      _showSnack('Đã copy toàn bộ ${_videos.length} video dạng JSON vào bộ nhớ tạm!');
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

  // ─── MODAL 4: Safety & Anti-Ban Presets ────────────────────────────────────
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
              // Presets selector
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
                  const Text('Thời gian nghỉ giữa mỗi video:', style: TextStyle(color: Colors.white70)),
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
                subtitle: const Text('Tự động dừng nghỉ ngơi theo chu kỳ để né tuyệt đối thuật toán quét của TikTok',
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
                Text('Cứ sau $deepBatch video sẽ nghỉ sâu $deepSec giây giải nhiệt.',
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

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Icons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  IconButton(
                    icon: const Icon(Icons.insights_rounded, color: Color(0xFF25F4EE)),
                    tooltip: 'Thống kê Analytics',
                    onPressed: _showAnalyticsModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white70),
                    tooltip: 'Xuất CSV/JSON',
                    onPressed: _showExportModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                    tooltip: 'Cài đặt Anti-Ban',
                    onPressed: _showSettingsModal,
                  ),
                ],
              ),
            ),

            // Studio Hub Switcher (Reposts / Un-Like / Un-Follow)
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
                    _buildHubTab('Reposts (${_videos.length})', 'repost', Icons.repeat_rounded),
                    _buildHubTab('Un-Like (Beta)', 'unlike', Icons.favorite_border_rounded),
                    _buildHubTab('Un-Follow (Beta)', 'unfollow', Icons.person_remove_rounded),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Hero Metric Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildMetricCard(
                    title: 'Đã Quét',
                    value: '${_videos.length}',
                    color: const Color(0xFF8A2BE2),
                    icon: Icons.video_library_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricCard(
                    title: 'Đã Xóa',
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

            const SizedBox(height: 8),

            // Scan Batch Limit Selector Bar (Theo yêu cầu: quét 100 bài mỗi đợt)
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

            // Quick Actions: Scan & Delete
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
                      label: Text(
                        _isScanning
                            ? (_scanBatchLimit > 0
                                ? '$_currentScannedCount/$_scanBatchLimit'
                                : 'Quét: $_currentScannedCount')
                            : (_scanBatchLimit > 0
                                ? 'Quét ($_scanBatchLimit bài)'
                                : 'Quét Tất Cả'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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
                      label: Text('Hủy Repost (${_selectedIds.length})'),
                      onPressed: _triggerBatchDelete,
                    ),
                  ),
                ],
              ),
            ),

            // Smart Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả (${_videos.length})', 'all'),
                  _buildFilterChip('Đã chọn (${_selectedIds.length})', 'selected'),
                  _buildFilterChip('Nhiều Like ❤️', 'most_liked'),
                  _buildFilterChip('Mới nhất 🔥', 'newest'),
                  _buildFilterChip('Cũ nhất 🕰', 'oldest'),
                  // Author filter chip
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
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedIds.length == _videos.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(_videos.map((v) => v.id));
                        }
                      });
                    },
                    icon: Icon(
                      _selectedIds.length == _videos.length ? Icons.deselect : Icons.select_all,
                      size: 16,
                      color: const Color(0xFF25F4EE),
                    ),
                    label: Text(
                      _selectedIds.length == _videos.length ? 'Bỏ chọn' : 'Chọn hết',
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
                  hintText: 'Tìm theo tên tác giả hoặc nội dung...',
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

            // Video Grid List
            Expanded(
              child: _filteredVideos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_collection_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Text(
                            _videos.isEmpty ? 'Chưa quét được repost nào cơ mà!' : 'Không có video nào khớp bộ lọc.',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
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
                    )
                  : GridView.builder(
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
                    ),
            ),
          ],
        ),
      ),
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
          setState(() => _currentHub = id);
          if (id != 'repost') {
            _showSnack('Tính năng $label đang mở rộng kết nối API TikTok!', isError: false);
          }
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
