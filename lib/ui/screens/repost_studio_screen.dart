import 'package:flutter/material.dart';
import '../../api/tiktok_client.dart';
import '../../database/local_database.dart';
import '../../models/tiktok_video.dart';
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
  String _selectedFilter = 'all'; // all, selected, most_liked, newest, oldest

  TikTokDeletionEngine? _engine;
  BatchDeletionProgress? _deletionProgress;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void didUpdateWidget(covariant RepostStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != null && _engine == null) {
      _initEngine();
    }
  }

  void _loadVideos() {
    setState(() {
      _videos = widget.database.getAllReposts();
      _selectedIds.clear();
      _selectedIds.addAll(_videos.map((v) => v.id)); // Default select all
    });
  }

  void _initEngine() {
    if (widget.client == null) return;
    _engine = TikTokDeletionEngine(client: widget.client!, database: widget.database);
    _engine!.progressStream.listen((prog) {
      if (mounted) {
        setState(() {
          _deletionProgress = prog;
          if (prog.status == DeletionStatus.completed || prog.status == DeletionStatus.stopped) {
            _loadVideos();
          }
        });
      }
    });
  }

  List<TikTokVideo> get _filteredVideos {
    List<TikTokVideo> list = List.from(_videos);

    if (_searchQuery.isNotEmpty) {
      list = list.where((v) {
        return v.authorUsername.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            v.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
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
      _showSnack('Vui lòng qua tab "TikTok" đăng nhập trước nhé anh yêu!', isError: true);
      return;
    }

    setState(() => _isScanning = true);
    int cursor = 0;
    bool hasMore = true;
    int totalFound = 0;

    try {
      while (hasMore) {
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
          _loadVideos();
        });

        await Future.delayed(const Duration(milliseconds: 300));
      }

      _showSnack('Quét hoàn tất! Đã tìm thấy $totalFound repost mới.');
    } catch (e) {
      _showSnack('Lỗi quét: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _triggerBatchDelete() {
    if (_engine == null) _initEngine();
    final targets = _videos.where((v) => _selectedIds.contains(v.id)).toList();

    if (targets.isEmpty) {
      _showSnack('Chưa chọn video nào để xóa cưng ơi!', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
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
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF25F4EE), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tốc độ: ${widget.database.customDelayMs}ms / video (Bypass Quota: Vô Hạn)',
                      style: const TextStyle(color: Color(0xFF25F4EE), fontSize: 12),
                    ),
                  ),
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
              _engine?.executeBatch(targets);
            },
            child: const Text('Bắt Đầu Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSettingsModal() {
    int currentDelay = widget.database.customDelayMs;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cấu Hình Tốc Độ & Anti-Bot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thời gian nghỉ giữa mỗi lượt xóa:', style: TextStyle(color: Colors.white70)),
                  Text('${currentDelay}ms', style: const TextStyle(color: Color(0xFF25F4EE), fontWeight: FontWeight.bold)),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('⚡ Turbo (300ms)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('⚖️ Cân bằng (700ms)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('🛡️ Siêu An toàn (1500ms)', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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
    final isDeleting = _deletionProgress != null && _deletionProgress!.status == DeletionStatus.running;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Header Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          'ClearTok Studio',
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
                    icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                    tooltip: 'Cài đặt tốc độ',
                    onPressed: _showSettingsModal,
                  ),
                ],
              ),
            ),

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

            const SizedBox(height: 12),

            // Deletion Live Progress Banner (if active)
            if (isDeleting)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2C1320), Color(0xFF161926)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFE2C55).withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đang xóa: ${_deletionProgress!.deleted} / ${_deletionProgress!.total}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop_circle, color: Color(0xFFFE2C55)),
                          onPressed: () => _engine?.stop(),
                          tooltip: 'Dừng lại',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _deletionProgress!.total > 0
                            ? _deletionProgress!.deleted / _deletionProgress!.total
                            : 0,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFE2C55)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Actions: Scan & Delete
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.sync_rounded),
                      label: Text(_isScanning ? 'Đang Quét...' : 'Quét Repost'),
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
                      onPressed: isDeleting ? null : _triggerBatchDelete,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả (${_videos.length})', 'all'),
                  _buildFilterChip('Đã chọn (${_selectedIds.length})', 'selected'),
                  _buildFilterChip('Nhiều Like ❤️', 'most_liked'),
                  _buildFilterChip('Mới nhất 🕒', 'newest'),
                  _buildFilterChip('Cũ nhất ⏳', 'oldest'),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên @tác giả hoặc nội dung...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF161926),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                            _videos.isEmpty ? 'Chưa quét được repost nào cưng ơi!' : 'Không có video nào khớp bộ lọc.',
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
                                  // Gradient Vignette
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
                                  // Selection Checkbox Badge
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
                                  // Author & Stats info
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
