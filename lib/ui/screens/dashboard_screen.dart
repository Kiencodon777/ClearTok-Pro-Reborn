import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../api/tiktok_client.dart';
import '../../core/remote_payload_config.dart';
import '../../database/local_database.dart';
import '../../models/tiktok_video.dart';
import '../../services/tiktok_deletion_engine.dart';

class DashboardScreen extends StatefulWidget {
  final LocalDatabase database;
  final RemotePayloadConfig remoteConfig;

  const DashboardScreen({
    super.key,
    required this.database,
    required this.remoteConfig,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  InAppWebViewController? _webViewController;
  TikTokClient? _client;
  TikTokDeletionEngine? _engine;

  bool _isLoggedIn = false;
  bool _isScanning = false;
  String _userSecUid = '';
  List<TikTokVideo> _cachedVideos = [];
  BatchDeletionProgress? _progress;

  @override
  void initState() {
    super.initState();
    _cachedVideos = widget.database.getAllReposts();
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _webViewController = controller;
    _client = TikTokClient(
      webViewController: controller,
      remoteConfig: widget.remoteConfig,
    );
    _engine = TikTokDeletionEngine(client: _client!, database: widget.database);

    _engine!.progressStream.listen((prog) {
      if (mounted) {
        setState(() {
          _progress = prog;
          if (prog.status == DeletionStatus.completed ||
              prog.status == DeletionStatus.stopped) {
            _cachedVideos = widget.database.getAllReposts();
          }
        });
      }
    });
  }

  Future<void> _checkLoginStatus() async {
    if (_client == null) return;
    final secUid =
        await _client!.getCookie('sec_user_id') ??
        await _client!.getCookie('secUid');
    if (secUid != null && secUid.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
        _userSecUid = secUid;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TikTok Account Connected!')),
      );
    }
  }

  Future<void> _startScanning() async {
    if (_client == null || _userSecUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to TikTok first!')),
      );
      return;
    }

    setState(() => _isScanning = true);
    int cursor = 0;
    bool hasMore = true;
    int totalFound = 0;

    try {
      while (hasMore) {
        final result = await _client!.fetchRepostBatch(
          cursor: cursor,
          secUid: _userSecUid,
        );
        if (result.videos.isEmpty) break;

        await widget.database.saveReposts(result.videos);
        cursor = result.nextCursor;
        hasMore = result.hasMore;
        totalFound += result.videos.length;

        setState(() {
          _cachedVideos = widget.database.getAllReposts();
        });

        await Future.delayed(const Duration(milliseconds: 300));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan complete! Found $totalFound new reposts.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan error: $e')));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _triggerBatchDelete() {
    if (_cachedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reposts in local cache to delete.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Mass Un-Repost'),
        content: Text(
          'Are you sure you want to delete all ${_cachedVideos.length} reposts from TikTok? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _engine?.executeBatch(_cachedVideos);
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LapinTokk — Unlimited'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkLoginStatus,
            tooltip: 'Check TikTok Session',
          ),
        ],
      ),
      body: Column(
        children: [
          // Headless WebView embedded in zero-height container
          SizedBox(
            height: _isLoggedIn ? 0 : 260,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://www.tiktok.com/login'),
              ),
              onWebViewCreated: _onWebViewCreated,
              onLoadStop: (controller, url) async {
                await _checkLoginStatus();
              },
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Status Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.deepPurple.shade900,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Cached Reposts',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_cachedVideos.length}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          color: Colors.teal.shade900,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Total Deleted',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${widget.database.totalDeletedCount}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Active Deletion Progress Monitor
                  if (_progress != null &&
                      _progress!.status == DeletionStatus.running)
                    Card(
                      color: Colors.black45,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: _progress!.total > 0
                                  ? _progress!.deleted / _progress!.total
                                  : 0,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deleting: ${_progress!.deleted} / ${_progress!.total} (${_progress!.failed} failed)',
                            ),
                            if (_progress!.currentTitle != null)
                              Text(
                                'Current: ${_progress!.currentTitle}',
                                style: const TextStyle(color: Colors.white60),
                              ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _engine?.stop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Stop Operation'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                            _isScanning ? 'Scanning...' : 'Scan Reposts',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isScanning ? null : _startScanning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Mass Un-Repost'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _triggerBatchDelete,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Video Grid
                  Expanded(
                    child: _cachedVideos.isEmpty
                        ? const Center(
                            child: Text(
                              'No reposts scanned yet. Tap "Scan Reposts" to begin.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _cachedVideos.length,
                            itemBuilder: (ctx, idx) {
                              final v = _cachedVideos[idx];
                              return ListTile(
                                leading: Image.network(
                                  v.coverUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.movie),
                                ),
                                title: Text(
                                  '@${v.authorUsername}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  v.description.isNotEmpty
                                      ? v.description
                                      : 'No description',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text('Likes: ${v.diggCount}'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
