import 'package:flutter/material.dart';
import '../../services/cleartok_account.dart';
import '../../services/cleartok_account_session.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/project_credits.dart';

class ClearTokAccountGate extends StatefulWidget {
  final Widget child;
  final ClearTokAccountSession? session;
  const ClearTokAccountGate({super.key, required this.child, this.session});
  static Future<void> openAccount(BuildContext context) async {
    final state = context.findAncestorStateOfType<_ClearTokAccountGateState>();
    final session = state?.session;
    if (session == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AccountPage(session: session, profile: true),
      ),
    );
  }

  @override
  State<ClearTokAccountGate> createState() => _ClearTokAccountGateState();
}

class _ClearTokAccountGateState extends State<ClearTokAccountGate> {
  ClearTokAccountSession? session;
  @override
  void initState() {
    super.initState();
    final api = ClearTokAccount.client;
    if (api != null) session = widget.session ?? ClearTokAccountSession(api);
  }

  @override
  void dispose() {
    session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = session;
    if (value == null) {
      return const _AccountLayout(
        title: 'Chưa thể kết nối',
        children: [
          Text('Cần cấu hình Supabase URL và publishable key cho ClearTok.'),
        ],
      );
    }
    return AnimatedBuilder(
      animation: value,
      builder: (_, _) {
        if (value.phase == AccountPhase.ready) return widget.child;
        return _AccountPage(session: value);
      },
    );
  }
}

enum _FormMode { login, register, forgot, password }

class _AccountPage extends StatefulWidget {
  final ClearTokAccountSession session;
  final bool profile;
  const _AccountPage({required this.session, this.profile = false});
  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  _FormMode mode = _FormMode.login;
  bool hidden = true;
  bool confirmationHidden = true;
  bool submitted = false;
  bool finished = false;
  ClearTokAccountSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    email.text = session.api.auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  void switchMode(_FormMode value) {
    form.currentState?.reset();
    password.clear();
    confirmation.clear();
    setState(() {
      mode = value;
      submitted = false;
      finished = false;
      hidden = true;
    });
  }

  Future<void> submit(_FormMode effective) async {
    setState(() => submitted = true);
    if (!form.currentState!.validate() || session.busy) return;
    FocusScope.of(context).unfocus();
    try {
      switch (effective) {
        case _FormMode.login:
          await session.login(email.text.trim(), password.text);
        case _FormMode.register:
          await session.register(email.text.trim(), password.text);
        case _FormMode.forgot:
          await session.forgot(email.text.trim());
        case _FormMode.password:
          await session.changePassword(password.text);
      }
      if (mounted && effective == _FormMode.forgot) {
        setState(() => finished = session.message.startsWith('Nếu email'));
      }
      if (mounted &&
          effective == _FormMode.password &&
          session.phase == AccountPhase.ready) {
        switchMode(_FormMode.login);
      }
    } finally {
      if (mounted) {
        password.clear();
        confirmation.clear();
      }
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    bool confirm = false,
  }) {
    final obscure = confirm ? confirmationHidden : hidden;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !session.busy,
        obscureText: secret && obscure,
        enableSuggestions: !secret,
        autocorrect: false,
        keyboardType: secret
            ? TextInputType.visiblePassword
            : TextInputType.emailAddress,
        textInputAction: secret ? TextInputAction.done : TextInputAction.next,
        autofillHints: [
          secret
              ? (mode == _FormMode.login &&
                        session.phase != AccountPhase.recovery
                    ? AutofillHints.password
                    : AutofillHints.newPassword)
              : AutofillHints.email,
        ],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            secret ? Icons.lock_outline_rounded : Icons.mail_outline_rounded,
          ),
          suffixIcon: secret
              ? IconButton(
                  tooltip: obscure ? 'Hiện $label' : 'Ẩn $label',
                  onPressed: () => setState(() {
                    if (confirm) {
                      confirmationHidden = !confirmationHidden;
                    } else {
                      hidden = !hidden;
                    }
                  }),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
              : null,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Vui lòng nhập $label.';
          if (!secret &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
            return 'Địa chỉ email chưa hợp lệ.';
          }
          if (confirm && value != password.text) {
            return 'Mật khẩu xác nhận chưa khớp.';
          }
          return null;
        },
      ),
    );
  }

  Widget action(
    String label,
    IconData icon,
    VoidCallback? onPressed, {
    bool primary = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassActionButton(
      label: label,
      icon: Icon(icon),
      primary: primary,
      onPressed: session.busy ? null : onPressed,
    ),
  );

  Widget notice() => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        session.message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: ClearTokColors.secondary),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (_, _) {
      final phase = session.phase;
      final recovery = phase == AccountPhase.recovery;
      if (phase == AccountPhase.ready &&
          widget.profile &&
          mode != _FormMode.password) {
        return profile();
      }
      if (phase == AccountPhase.checking) {
        return _AccountLayout(
          title: 'Đang kiểm tra tài khoản',
          back: widget.profile,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Đang xác nhận quyền truy cập và thiết bị…',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: session.working ? null : session.logout,
              child: const Text('Đăng xuất ClearTok'),
            ),
          ],
        );
      }
      if (phase == AccountPhase.denied) {
        return _AccountLayout(
          title: 'Chưa thể vào Studio',
          back: widget.profile,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 40,
              color: ClearTokColors.cyan,
            ),
            const SizedBox(height: 16),
            notice(),
            action(
              'Kiểm tra lại quyền',
              Icons.refresh_rounded,
              session.verify,
              primary: true,
            ),
            action('Đăng xuất ClearTok', Icons.logout_rounded, session.logout),
          ],
        );
      }
      if (phase == AccountPhase.verifyEmail) {
        return _AccountLayout(
          title: 'Xác minh email',
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 44,
              color: ClearTokColors.cyan,
            ),
            const SizedBox(height: 16),
            Text(
              'Mở thư xác minh gửi đến ${email.text}. Sau khi xác minh, quay lại đăng nhập.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Mẹo: Kiểm tra thêm mục Thư rác (Spam) hoặc Quảng cáo nếu chưa thấy email.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ClearTokColors.secondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (session.message.isNotEmpty) notice(),
            action(
              'Gửi lại thư xác minh',
              Icons.send_outlined,
              () => session.resend(email.text.trim()),
              primary: true,
            ),
            TextButton(
              onPressed: session.busy
                  ? null
                  : () {
                      session.phase = AccountPhase.signedOut;
                      switchMode(_FormMode.login);
                    },
              child: const Text('Quay lại đăng nhập'),
            ),
          ],
        );
      }
      final effective = recovery ? _FormMode.password : mode;
      final title = switch (effective) {
        _FormMode.login => 'Chào mừng trở lại',
        _FormMode.register => 'Tạo tài khoản ClearTok',
        _FormMode.forgot => 'Khôi phục mật khẩu',
        _FormMode.password => recovery ? 'Đặt mật khẩu mới' : 'Đổi mật khẩu',
      };
      final label = switch (effective) {
        _FormMode.login => 'Đăng nhập',
        _FormMode.register => 'Đăng ký',
        _FormMode.forgot => 'Gửi hướng dẫn khôi phục',
        _FormMode.password => 'Lưu mật khẩu mới',
      };
      return _AccountLayout(
        title: title,
        back: widget.profile && !recovery,
        children: [
          const Text(
            'Tài khoản ClearTok dành cho ứng dụng.\nĐăng nhập TikTok riêng trong TikTok Web.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ClearTokColors.secondary),
          ),
          const SizedBox(height: 24),
          if (session.busy) const LinearProgressIndicator(),
          if (session.message.isNotEmpty) notice(),
          if (!finished)
            AutofillGroup(
              child: Form(
                key: form,
                autovalidateMode: submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  children: [
                    if (effective != _FormMode.password)
                      field(email, 'Email ClearTok'),
                    if (effective != _FormMode.forgot)
                      field(
                        password,
                        effective == _FormMode.password
                            ? 'Mật khẩu mới'
                            : 'Mật khẩu ClearTok',
                        secret: true,
                      ),
                    if (effective == _FormMode.register ||
                        effective == _FormMode.password)
                      field(
                        confirmation,
                        'Xác nhận mật khẩu',
                        secret: true,
                        confirm: true,
                      ),
                    action(
                      label,
                      effective == _FormMode.forgot
                          ? Icons.mail_outline_rounded
                          : Icons.arrow_forward_rounded,
                      () => submit(effective),
                      primary: true,
                    ),
                  ],
                ),
              ),
            ),
          if (effective == _FormMode.login) ...[
            TextButton(
              onPressed: session.busy
                  ? null
                  : () => switchMode(_FormMode.forgot),
              child: const Text('Quên mật khẩu?'),
            ),
            TextButton(
              onPressed: session.busy
                  ? null
                  : () => switchMode(_FormMode.register),
              child: const Text('Chưa có tài khoản? Đăng ký'),
            ),
          ] else if (!recovery)
            TextButton(
              onPressed: session.busy
                  ? null
                  : () => switchMode(_FormMode.login),
              child: Text(
                widget.profile && phase == AccountPhase.ready
                    ? 'Quay lại tài khoản'
                    : 'Quay lại đăng nhập',
              ),
            ),
          if (recovery)
            TextButton(
              onPressed: session.working ? null : session.logout,
              child: const Text('Đăng xuất ClearTok'),
            ),
        ],
      );
    },
  );

  Widget profile() {
    final data = session.account!;
    final isPremium = data['effective_plan'] == 'premium';
    final entitlement = data['entitlement'] as Map?;
    final expiry = DateTime.tryParse(
      '${entitlement?['expires_at']}',
    )?.toLocal();
    return _AccountLayout(
      title: 'Tài khoản ClearTok',
      back: true,
      children: [
        Icon(
          isPremium ? Icons.workspace_premium_rounded : Icons.account_circle_outlined,
          size: 44,
          color: isPremium ? ClearTokColors.pink : ClearTokColors.cyan,
        ),
        const SizedBox(height: 12),
        Text(
          session.api.auth.currentUser?.email ?? '',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Gói: ${isPremium ? 'Premium' : 'Free'}',
          textAlign: TextAlign.center,
          style: ClearTokTokens.title,
        ),
        const SizedBox(height: 4),
        Text(
          isPremium
              ? 'Hạn mức: Tối đa 5 thiết bị hoạt động'
              : 'Hạn mức: Tối đa 1 thiết bị hoạt động',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ClearTokColors.secondary, fontSize: 12),
        ),
        if (expiry != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Thời hạn: ${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}',
              textAlign: TextAlign.center,
            ),
          ),
        if (session.busy) const LinearProgressIndicator(),
        if (session.message.isNotEmpty) notice(),
        const SizedBox(height: 24),
        const Text('Thiết bị của bạn', style: ClearTokTokens.title),
        for (final device in (data['devices'] as List? ?? []))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LiquidGlassContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        device['platform'] == 'ios'
                            ? Icons.phone_iphone
                            : Icons.devices,
                        color: ClearTokColors.cyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${device['device_name'] ?? device['platform']}',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    device['is_active'] == true
                        ? 'Đang hoạt động'
                        : 'Đã thu hồi',
                    style: const TextStyle(color: ClearTokColors.secondary),
                  ),
                  TextButton(
                    onPressed: session.busy || device['is_active'] != true
                        ? null
                        : () async {
                            final agreed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Thu hồi thiết bị?'),
                                content: const Text(
                                  'Nếu đây là thiết bị hiện tại, quyền vào Studio sẽ bị dừng. Dữ liệu TikTok vẫn được giữ nguyên.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Thu hồi'),
                                  ),
                                ],
                              ),
                            );
                            if (agreed == true) {
                              await session.revoke('${device['id']}');
                            }
                          },
                    child: const Text('Thu hồi'),
                  ),
                ],
              ),
            ),
          ),
        if ((data['devices'] as List? ?? []).isEmpty)
          const Text('Chưa có thiết bị.'),
        const SizedBox(height: 16),
        action('Kiểm tra lại quyền', Icons.refresh_rounded, session.verify),
        action(
          'Đổi mật khẩu',
          Icons.lock_reset_rounded,
          () => switchMode(_FormMode.password),
        ),
        action('Đăng xuất ClearTok', Icons.logout_rounded, () async {
          await session.logout();
          if (mounted && session.phase == AccountPhase.signedOut) {
            Navigator.of(context).pop();
          }
        }),
      ],
    );
  }
}

class _AccountLayout extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool back;
  const _AccountLayout({
    required this.title,
    required this.children,
    this.back = false,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClearTokColors.background,
    appBar: back ? AppBar(title: const Text('Tài khoản ClearTok')) : null,
    body: AmbientBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/brand/app_icon.jpg',
                        width: 72,
                        height: 72,
                      ),
                    ),
                    const SizedBox(height: 24),
                    LiquidGlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: ClearTokTokens.title.copyWith(fontSize: 25),
                          ),
                          const SizedBox(height: 24),
                          ...children,
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const ProjectCreditFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
