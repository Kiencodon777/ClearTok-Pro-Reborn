import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cleartok_account.dart';

enum AccountPhase { signedOut, checking, ready, denied, verifyEmail, recovery }

// Shared by the gate and its profile route so opening an account never rebuilds WebView.
class ClearTokAccountSession extends ChangeNotifier {
  final SupabaseClient api;
  late final StreamSubscription<AuthState> _subscription;
  AccountPhase phase = AccountPhase.signedOut;
  Map<String, dynamic>? account;
  String message = '';
  bool working = false;
  bool _disposed = false;
  bool _loggingOut = false;
  bool _callbackPending = false;
  int _generation = 0;
  int _checkGeneration = -1;
  String? _user;
  Future<void>? _checking;
  bool get busy => working || _checking != null;

  ClearTokAccountSession(this.api) {
    _user = api.auth.currentUser?.id;
    _subscription = api.auth.onAuthStateChange.listen(
      _onAuth,
      onError: (Object error) {
        deny(accountErrorMessage(error));
      },
    );
    ClearTokAccount.accessInvalidated.addListener(_accessLost);
    if (api.auth.currentSession != null) unawaited(verify());
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _accessLost() =>
      deny('Tài khoản hoặc thiết bị không được phép truy cập.');

  void deny(String reason) {
    if (_disposed) return;
    _generation++;
    _callbackPending = false;
    _checking = null;
    account = null;
    phase = AccountPhase.denied;
    message = reason;
    _emit();
  }

  void beginCallback() {
    _generation++;
    _callbackPending = true;
    _checking = null;
    account = null;
    phase = AccountPhase.checking;
    _emit();
  }

  void _onAuth(AuthState state) {
    if (_disposed || _loggingOut) return;
    if (state.session != null &&
        state.session!.user.id != api.auth.currentUser?.id) {
      return;
    }
    final user = state.session?.user.id;
    if (user != _user || state.session == null) {
      _generation++;
      _user = user;
      account = null;
    }
    if (state.session == null) {
      if (_callbackPending && state.event == AuthChangeEvent.initialSession) {
        return;
      }
      phase = AccountPhase.signedOut;
      message = '';
      _emit();
      return;
    }
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _callbackPending = false;
      _checking = null;
      _generation++;
      account = null;
      phase = AccountPhase.recovery;
      message = '';
      _emit();
      return;
    }
    if (_callbackPending && state.event != AuthChangeEvent.signedIn) return;
    _callbackPending = false;
    if (phase != AccountPhase.recovery) unawaited(verify());
  }

  Future<void> verify() {
    if (_disposed ||
        _callbackPending ||
        phase == AccountPhase.recovery ||
        api.auth.currentSession == null) {
      return Future.value();
    }
    if (_checking != null && _checkGeneration == _generation) return _checking!;
    final generation = _generation;
    final user = api.auth.currentUser!.id;
    _checkGeneration = generation;
    if (account == null) phase = AccountPhase.checking;
    message = '';
    late final Future<void> task;
    task = () async {
      try {
        final result = await ClearTokAccount.check();
        if (_disposed ||
            generation != _generation ||
            api.auth.currentUser?.id != user) {
          return;
        }
        account = result;
        phase = AccountPhase.ready;
      } catch (error) {
        if (!_disposed && generation == _generation) {
          deny(accountErrorMessage(error));
          // A failed refresh also stops batches when the server cannot be reached.
          ClearTokAccount.accessInvalidated.value++;
          message = accountErrorMessage(error);
        }
      } finally {
        if (identical(_checking, task)) _checking = null;
        _emit();
      }
    }();
    _checking = task;
    _emit();
    return task;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    working = true;
    message = '';
    _emit();
    try {
      await action();
    } catch (error) {
      if (!_disposed) {
        if (error is FunctionException &&
            (error.status == 401 || error.status == 403)) {
          ClearTokAccount.accessInvalidated.value++;
        }
        message = accountErrorMessage(error);
        if (error is AuthException && error.code == 'email_not_confirmed') {
          phase = AccountPhase.verifyEmail;
        }
      }
    } finally {
      working = false;
      _emit();
    }
  }

  Future<void> login(String email, String password) => run(() async {
    await api.auth.signInWithPassword(email: email, password: password);
    if (_user != api.auth.currentUser?.id) {
      _generation++;
      _user = api.auth.currentUser?.id;
    }
    await verify();
  });
  Future<void> register(String email, String password) => run(() async {
    final result = await api.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'cleartok://auth-callback',
    );
    if (result.session == null) {
      phase = AccountPhase.verifyEmail;
      message = 'Kiểm tra email để xác minh tài khoản.';
    } else {
      await verify();
    }
  });
  Future<void> resend(String email) => run(() async {
    await api.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: 'cleartok://auth-callback',
    );
    message = 'Nếu có thể gửi, thư xác minh sẽ đến email của bạn.';
  });
  Future<void> forgot(String email) => run(() async {
    await api.auth.resetPasswordForEmail(
      email,
      redirectTo: 'cleartok://auth-callback',
    );
    message = 'Nếu email hợp lệ, bạn sẽ nhận được hướng dẫn khôi phục.';
  });
  Future<void> changePassword(String password) => run(() async {
    await api.auth.updateUser(UserAttributes(password: password));
    if (phase == AccountPhase.recovery) {
      phase = AccountPhase.checking;
      await verify();
    }
    if (phase == AccountPhase.ready) message = 'Đã đổi mật khẩu.';
  });
  Future<void> revoke(String id) => run(() async {
    await api.functions.invoke(
      'account',
      body: {
        'action': 'revoke_device',
        'payload': {'id': id},
      },
    );
    await verify();
  });
  Future<void> logout() async {
    if (working || _disposed) return;
    working = true;
    _loggingOut = true;
    _callbackPending = false;
    _generation++;
    account = null;
    phase = AccountPhase.signedOut;
    ClearTokAccount.accessInvalidated.value++;
    phase = AccountPhase.signedOut;
    _emit();
    try {
      await api.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      message = accountErrorMessage(error);
    } finally {
      _generation++;
      _user = null;
      _checking = null;
      account = null;
      phase = AccountPhase.signedOut;
      working = false;
      _loggingOut = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription.cancel();
    ClearTokAccount.accessInvalidated.removeListener(_accessLost);
    super.dispose();
  }
}

String accountErrorMessage(Object error) {
  if (error is AuthException) {
    if (error.statusCode == '429' ||
        error.code == 'over_email_send_rate_limit') {
      return 'Bạn đang gửi quá nhanh. Vui lòng thử lại sau.';
    }
    if (error.code == 'invalid_credentials') {
      return 'Email hoặc mật khẩu chưa đúng.';
    }
    if (error.code == 'email_not_confirmed') {
      return 'Vui lòng xác minh email trước khi đăng nhập.';
    }
    if (error.code == 'weak_password') {
      return 'Mật khẩu chưa đáp ứng chính sách bảo mật.';
    }
    if (error is AuthRetryableFetchException) {
      return 'Không thể kết nối. Kiểm tra mạng và thử lại.';
    }
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return 'Không thể kết nối. Kiểm tra mạng và thử lại.';
  }
  if (error is FunctionException &&
      (error.status == 401 || error.status == 403)) {
    return 'Tài khoản hoặc thiết bị không được phép truy cập.';
  }
  if (error is FunctionException && error.status == 429) {
    return 'Bạn đang gửi quá nhanh. Vui lòng thử lại sau.';
  }
  return 'Không thể hoàn tất. Vui lòng thử lại.';
}
