import 'package:live_sites/src/capabilities/live_auth_capability.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_auth_provider.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One bilibili QR login: `passport.bilibili.com` issues the code (on the
/// first poll — the capability's `startQrLogin` is synchronous) and judges it
/// on every later one. The confirmed cookies stay in the session for
/// `exchange`.
final class BilibiliQrLoginSession implements LiveAuthSession {
  /// Starts the login; the code is issued in the background.
  BilibiliQrLoginSession({required this.provider});

  /// The capability this session logs in through.
  final BilibiliAuthProvider provider;

  Future<({String key, String url})>? _issue;
  ({String key, String url})? _code;
  ({Map<String, String> cookies, DateTime? expiry})? _granted;

  @override
  String get qrContent {
    final code = _code;
    if (code == null) {
      throw StateError('bilibili QR login: the code is not issued yet — poll() first');
    }
    return code.url;
  }

  @override
  Future<LiveAuthPollResult> poll() async {
    if (_granted != null) return const LiveAuthPollResult.success();
    final code = await _issueCode();
    final answer = await provider.pollQrCode(code.key);
    switch (answer.code) {
      case 0:
        if (answer.cookies.isEmpty) {
          throw const BilibiliFailure(BilibiliFailureKind.apiChanged, 'qrcode/poll: confirmed without cookies');
        }
        _granted = (cookies: answer.cookies, expiry: answer.expiry);
        return const LiveAuthPollResult.success();
      case 86038:
        return const LiveAuthPollResult.expired();
      case 86101: // Not scanned yet.
      case 86090: // Scanned, waiting for the confirmation: still pending.
        return const LiveAuthPollResult.pending();
      default:
        throw BilibiliFailure(BilibiliFailureKind.apiChanged, 'qrcode/poll: unexpected state ${answer.code}');
    }
  }

  /// The granted cookies, polling once more when no poll answered success
  /// yet; a pending or expired QR (or a failed issue) is a needs-login
  /// failure.
  Future<({Map<String, String> cookies, DateTime? expiry})> granted() async {
    final granted = _granted;
    if (granted != null) return granted;
    final result = await poll();
    if (result.status == LiveAuthPollStatus.success) return _granted!;
    throw BilibiliFailure(
      BilibiliFailureKind.needsLogin,
      result.status == LiveAuthPollStatus.expired ? 'qrcode/poll: the code expired' : 'qrcode/poll: not confirmed yet',
    );
  }

  Future<({String key, String url})> _issueCode() async {
    final code = _code;
    if (code != null) return code;
    try {
      return _code = await (_issue ??= provider.issueQrCode());
    } on Object {
      _issue = null; // The next poll issues a fresh code.
      rethrow;
    }
  }
}
