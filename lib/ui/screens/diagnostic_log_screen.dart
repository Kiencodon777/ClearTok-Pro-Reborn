import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/diagnostic_log.dart';
import '../widgets/liquid_glass.dart';

class DiagnosticLogScreen extends StatelessWidget {
  const DiagnosticLogScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final log = DiagnosticLog.instance;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Log chẩn đoán'),
          flexibleSpace: const LiquidGlassContainer(
              borderRadius: 0, child: SizedBox.expand()),
          actions: [
            IconButton(
                tooltip: 'Sao chép log',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: log.export()));
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép log')));
                }),
            IconButton(
                tooltip: 'Xóa log',
                icon: const Icon(Icons.delete_outline),
                onPressed: log.clear),
          ]),
      body: ColoredBox(
          color: ClearTokColors.background,
          child: Column(children: [
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    '200 sự kiện gần nhất trong phiên mở app. Log không lưu cookie, token, ID tài khoản hoặc nội dung phản hồi.')),
            Expanded(
                child: AnimatedBuilder(
                    animation: log,
                    builder: (context, _) {
                      final entries = log.entries.reversed.toList();
                      if (entries.isEmpty)
                        return const Center(
                            child: Text(
                                'Chưa có log. Thực hiện thao tác trong Studio rồi quay lại đây.'));
                      return ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: SelectableText(
                                  '${entries[index]['http_status'] == 200 && entries[index]['response_kind'] == 'empty' ? 'PHÁT HIỆN: HTTP 200 rỗng — chưa xác nhận kết quả, không tự thử lại.\n' : ''}'
                                  '${entries[index].entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
                                  style: ClearTokTokens.body.copyWith(
                                      fontFamily: 'monospace', fontSize: 12))));
                    })),
          ])),
    );
  }
}
