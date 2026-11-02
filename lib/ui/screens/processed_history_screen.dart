import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../database/local_database.dart';
import '../widgets/liquid_glass.dart';

class ProcessedHistoryScreen extends StatefulWidget {
  final LocalDatabase database;
  final ValueChanged<String> onOpenInTikTokWeb;

  const ProcessedHistoryScreen({
    super.key,
    required this.database,
    required this.onOpenInTikTokWeb,
  });

  @override
  State<ProcessedHistoryScreen> createState() => _ProcessedHistoryScreenState();
}

class _ProcessedHistoryScreenState extends State<ProcessedHistoryScreen> {
  String _selectedType = 'repost'; // 'repost', 'unlike', 'unfollow'
  String _searchQuery = '';

  List<ProcessedHistoryItem> get _items {
    final all = widget.database.getProcessedHistory(type: _selectedType);
    if (_searchQuery.trim().isEmpty) return all;
    final q = _searchQuery.trim().toLowerCase();
    return all.where((item) {
      return item.authorUsername.toLowerCase().contains(q) ||
          item.authorNickname.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.id.toLowerCase().contains(q);
    }).toList();
  }

  String _formatTime(int millis) {
    if (millis <= 0) return 'Đã xử lý';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat('HH:mm · dd/MM/yyyy').format(dt);
  }

  Future<void> _openItemActionsSheet(ProcessedHistoryItem item) async {
    HapticFeedback.mediumImpact();
    final isUser = item.type == 'unfollow';
    final url = item.tiktokUrl;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: ClearTokColors.cyan.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ClearTokColors.cyan.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      isUser
                          ? Icons.person_outline_rounded
                          : Icons.ondemand_video_rounded,
                      color: ClearTokColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${item.authorUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(item.processedAt),
                          style: const TextStyle(
                            color: ClearTokColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ClearTokColors.secondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GlassActionButton(
                icon: const Icon(Icons.public_rounded),
                label: isUser
                    ? 'Mở kênh trên tab TikTok Web'
                    : 'Xem lại video trên tab TikTok Web',
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onOpenInTikTokWeb(url);
                },
              ),
              const SizedBox(height: 10),
              GlassActionButton(
                primary: true,
                icon: const Icon(Icons.open_in_new_rounded),
                label: isUser
                    ? 'Mở kênh bằng app TikTok ngoài'
                    : 'Mở video bằng app TikTok ngoài',
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: const Text('Sao chép link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép liên kết TikTok!'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: ClearTokColors.pink,
                      ),
                      label: const Text(
                        'Xóa khỏi lịch sử',
                        style: TextStyle(color: ClearTokColors.pink),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await widget.database.removeProcessedHistoryEntry(
                          item.key,
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearCurrentHistory() async {
    final typeLabel = _selectedType == 'repost'
        ? 'Repost đã hủy'
        : (_selectedType == 'unlike'
              ? 'Video đã bỏ thích'
              : 'Kênh đã hủy follow');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClearTokColors.raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Xóa lịch sử mục này?', style: ClearTokTokens.title),
        content: Text(
          'Bạn có muốn làm trống danh sách lịch sử "$typeLabel" trên thiết bị không?',
          style: const TextStyle(color: ClearTokColors.secondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ClearTokColors.pink,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.database.clearProcessedHistory(type: _selectedType);
              if (mounted) setState(() {});
            },
            child: const Text('Xóa lịch sử'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repostDone = widget.database.deletedRepostCount;
    final likeDone = widget.database.deletedLikeCount;
    final followDone = widget.database.deletedFollowCount;
    final list = _items;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: LiquidGlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ClearTokColors.cyan.withValues(alpha: 0.28),
                            ClearTokColors.pink.withValues(alpha: 0.22),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.history_edu_rounded,
                        color: ClearTokColors.cyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kho Đã Xử Lý',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Chạm hoặc giữ lâu để mở lại trên TikTok (${repostDone + likeDone + followDone} mục)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: ClearTokColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (list.isNotEmpty)
                      BouncyTapWrapper(
                        pressedScale: 0.88,
                        onTap: () {},
                        child: IconButton(
                          tooltip: 'Xóa lịch sử mục này',
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            color: ClearTokColors.pink,
                          ),
                          onPressed: _confirmClearCurrentHistory,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 3 Separated Counter Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildCounterBadge(
                    label: 'Repost Đã Hủy',
                    count: repostDone,
                    color: ClearTokColors.cyan,
                    active: _selectedType == 'repost',
                    onTap: () => setState(() => _selectedType = 'repost'),
                  ),
                  const SizedBox(width: 8),
                  _buildCounterBadge(
                    label: 'Đã Bỏ Thích',
                    count: likeDone,
                    color: ClearTokColors.pink,
                    active: _selectedType == 'unlike',
                    onTap: () => setState(() => _selectedType = 'unlike'),
                  ),
                  const SizedBox(width: 8),
                  _buildCounterBadge(
                    label: 'Đã Hủy Follow',
                    count: followDone,
                    color: ClearTokColors.success,
                    active: _selectedType == 'unfollow',
                    onTap: () => setState(() => _selectedType = 'unfollow'),
                  ),
                ],
              ),
            ),

            // 3-Way Liquid Glass Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GBoxSegmentedControl(
                segments: const [
                  GBoxSegment(label: 'Reposts', icon: Icons.repeat_rounded),
                  GBoxSegment(
                    label: 'Un-Liked',
                    icon: Icons.favorite_border_rounded,
                  ),
                  GBoxSegment(
                    label: 'Un-Followed',
                    icon: Icons.person_remove_rounded,
                  ),
                ],
                selectedIndex: const [
                  'repost',
                  'unlike',
                  'unfollow',
                ].indexOf(_selectedType),
                onSegmentSelected: (idx) {
                  setState(() {
                    _selectedType = const ['repost', 'unlike', 'unfollow'][idx];
                  });
                },
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Tìm lại theo @username hoặc nội dung...',
                  hintStyle: const TextStyle(
                    color: ClearTokColors.muted,
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: ClearTokColors.muted,
                    size: 19,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 17),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

            // Content Area
            Expanded(
              child: list.isEmpty
                  ? _buildEmptyState()
                  : (_selectedType == 'unfollow'
                        ? _buildUnfollowedList(list)
                        : _buildProcessedVideosGrid(list)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterBadge({
    required String label,
    required int count,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: BouncyTapWrapper(
        pressedScale: 0.92,
        onTap: onTap,
        child: LiquidGlassContainer(
          blur: false,
          isSelected: active,
          onTap: onTap,
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ClearTokColors.secondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final label = _selectedType == 'repost'
        ? 'Chưa có video Repost nào bị hủy.'
        : (_selectedType == 'unlike'
              ? 'Chưa có video nào bị bỏ thích.'
              : 'Chưa có tài khoản nào bị hủy follow.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 58,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ClearTokColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Khi bạn hủy Repost, bỏ thích hoặc hủy follow ở tab Studio, các mục đó sẽ tự động lưu vào đây để bạn có thể mở lại bất cứ lúc nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ClearTokColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnfollowedList(List<ProcessedHistoryItem> items) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        ClearTokTokens.dockClearance +
            MediaQuery.of(context).viewPadding.bottom,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        return LiquidGlassContainer(
          key: ValueKey(item.key),
          blur: false,
          margin: const EdgeInsets.only(bottom: 10),
          borderRadius: 18,
          child: ListTile(
            onTap: () => _openItemActionsSheet(item),
            onLongPress: () => _openItemActionsSheet(item),
            leading: CircleAvatar(
              backgroundImage: item.coverUrl.isNotEmpty
                  ? NetworkImage(item.coverUrl)
                  : null,
              backgroundColor: ClearTokColors.raised,
              child: item.coverUrl.isEmpty
                  ? Text(
                      item.authorUsername.isNotEmpty
                          ? item.authorUsername[0].toUpperCase()
                          : '@',
                      style: const TextStyle(color: ClearTokColors.cyan),
                    )
                  : null,
            ),
            title: Text(
              '@${item.authorUsername}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${item.authorNickname.isNotEmpty ? "${item.authorNickname} · " : ""}${_formatTime(item.processedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ClearTokColors.secondary,
                fontSize: 11.5,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Mở lại kênh trên TikTok',
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: ClearTokColors.cyan,
                size: 20,
              ),
              onPressed: () => _openItemActionsSheet(item),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcessedVideosGrid(List<ProcessedHistoryItem> items) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
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
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        return GestureDetector(
          key: ValueKey(item.key),
          onTap: () => _openItemActionsSheet(item),
          onLongPress: () => _openItemActionsSheet(item),
          child: Container(
            decoration: ShapeDecoration(
              shape: gboxSquircleShape(
                ClearTokTokens.radius,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: gboxSquircleShape(ClearTokTokens.radius),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.coverUrl.isNotEmpty
                        ? Image.network(
                            item.coverUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, __, ___) => Container(
                              color: ClearTokColors.surface,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: Colors.white24,
                                size: 38,
                              ),
                            ),
                          )
                        : Container(
                            color: ClearTokColors.surface,
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                              size: 38,
                            ),
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.86),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 0.7,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: ClearTokColors.cyan,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Mở lại',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          '@${item.authorUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(item.processedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ClearTokColors.secondary,
                            fontSize: 10.5,
                          ),
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
}
