import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cleartok_reborn/services/cleartok_account.dart';
import 'package:cleartok_reborn/services/cleartok_account_session.dart';
import 'account_fixture.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountFixture fixture;
  ClearTokAccountSession? session;
  setUp(() {
    fixture = AccountFixture();
  });
  tearDown(() async {
    session?.dispose();
    session = null;
    await fixture.dispose();
  });
  test('callback allowlist is exact and malformed parameters fail closed', () {
    for (final url in [
      'cleartok://auth-callback?code=fixture',
      'cleartok://auth-callback#access_token=fixture',
    ]) {
      expect(isClearTokAuthCallback(Uri.parse(url)), true);
    }
    for (final url in [
      'http://auth-callback?code=fixture',
      'cleartok://evil?code=fixture',
      'cleartok://auth-callback.evil?code=fixture',
      'cleartok://auth-callback:99?code=fixture',
      'cleartok://user@auth-callback?code=fixture',
      'cleartok://auth-callback/other?code=fixture',
      'cleartok://auth-callback',
      'cleartok://auth-callback#code=%FF',
    ]) {
      expect(isClearTokAuthCallback(Uri.parse(url)), false);
    }
  });
  test(
    'early callback holds restored access until the SDK delivers recovery',
    () async {
      await fixture.signedIn();
      session = ClearTokAccountSession(fixture.api);
      await session!.verify();
      session!.beginCallback();
      await session!.verify();
      expect(session!.phase, AccountPhase.checking);
      expect(session!.account, isNull);
      await fixture.recovery();
      await settle();
      expect(session!.phase, AccountPhase.recovery);
      final checks = fixture.checks;
      await session!.verify();
      expect(fixture.checks, checks);
    },
  );
  test('login and signedIn event share a single enrollment request', () async {
    session = ClearTokAccountSession(fixture.api);
    await session!.login('test@example.invalid', 'fixture');
    await settle();
    expect(session!.phase, AccountPhase.ready);
    expect(fixture.checks, 1);
  });
  test(
    'duplicate submit is ignored while login/enrollment is in flight',
    () async {
      fixture.hold = Completer<void>();
      session = ClearTokAccountSession(fixture.api);
      final first = session!.login('test@example.invalid', 'fixture');
      await settle();
      await session!.login('test@example.invalid', 'fixture');
      expect(fixture.logins, 1);
      fixture.hold!.complete();
      await first;
      expect(fixture.checks, 1);
    },
  );
  test('logout invalidates an in-flight initial check', () async {
    await fixture.signedIn();
    fixture.hold = Completer<void>();
    session = ClearTokAccountSession(fixture.api);
    final pending = session!.verify();
    await settle();
    await session!.logout();
    fixture.hold!.complete();
    await pending;
    expect(session!.phase, AccountPhase.signedOut);
    expect(session!.account, isNull);
  });
  test(
    'token refresh keeps approved content visible until verification finishes',
    () async {
      await fixture.signedIn();
      session = ClearTokAccountSession(fixture.api);
      await session!.verify();
      fixture.hold = Completer<void>();
      await fixture.api.auth.refreshSession();
      await settle();
      expect(session!.phase, AccountPhase.ready);
      fixture.hold!.complete();
      await session!.verify();
      expect(session!.phase, AccountPhase.ready);
    },
  );
  test(
    'recovery preempts Studio even after a successful older check',
    () async {
      await fixture.signedIn();
      fixture.hold = Completer<void>();
      session = ClearTokAccountSession(fixture.api);
      final pending = session!.verify();
      await settle();
      await fixture.recovery();
      await settle();
      fixture.hold!.complete();
      await pending;
      expect(session!.phase, AccountPhase.recovery);
      expect(session!.account, isNull);
      await session!.changePassword('new-fixture-password');
      expect(fixture.writes, 1);
      expect(session!.phase, AccountPhase.ready);
    },
  );
  test(
    '403 removes cached access and emits batch cancellation signal',
    () async {
      await fixture.signedIn();
      session = ClearTokAccountSession(fixture.api);
      await session!.verify();
      final before = ClearTokAccount.accessInvalidated.value;
      fixture.denied = true;
      await session!.verify();
      expect(session!.phase, AccountPhase.denied);
      expect(session!.account, isNull);
      expect(ClearTokAccount.accessInvalidated.value, greaterThan(before));
      expect(session!.message, isNot(contains('cookie')));
    },
  );
  test('own-device revocation revalidates access and denies Studio', () async {
    await fixture.signedIn();
    session = ClearTokAccountSession(fixture.api);
    await session!.verify();
    await session!.revoke('fixture-device-row');
    expect(fixture.revoked, 1);
    expect(session!.phase, AccountPhase.denied);
  });
  test(
    'registration waits for email and errors never expose server details',
    () async {
      session = ClearTokAccountSession(fixture.api);
      await session!.register('test@example.invalid', 'fixture');
      expect(session!.phase, AccountPhase.verifyEmail);
      expect(fixture.checks, 0);
      expect(
        accountErrorMessage(
          const AuthException('Cookie=secret', code: 'invalid_credentials'),
        ),
        'Email hoặc mật khẩu chưa đúng.',
      );
      expect(
        accountErrorMessage(
          const AuthException('token=secret', statusCode: '429'),
        ),
        contains('quá nhanh'),
      );
    },
  );
}
