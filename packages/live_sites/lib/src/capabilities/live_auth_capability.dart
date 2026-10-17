import 'package:live_sites/src/capabilities/live_site_capability.dart';

// The named poll-result constructors spell their class name by convention
// here; the `.new` shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How a QR login stands when [LiveAuthSession.poll] answers.
enum LiveAuthPollStatus {
  /// The QR is not confirmed yet: not scanned, or scanned and waiting for the
  /// confirmation on the device.
  pending,

  /// The user confirmed the login; the credential is ready for
  /// [LiveAuthCapability.exchange].
  success,

  /// The QR expired; the login has to start over.
  expired,
}

/// One answer of a QR-login poll.
final class LiveAuthPollResult {
  /// A poll that answered [status].
  const LiveAuthPollResult(this.status);

  /// The QR is not confirmed yet.
  const LiveAuthPollResult.pending() : status = LiveAuthPollStatus.pending;

  /// The user confirmed the login.
  const LiveAuthPollResult.success() : status = LiveAuthPollStatus.success;

  /// The QR expired.
  const LiveAuthPollResult.expired() : status = LiveAuthPollStatus.expired;

  /// How the login stands.
  final LiveAuthPollStatus status;

  @override
  String toString() => 'LiveAuthPollResult(${status.name})';
}

/// One started QR login: the QR content to render and the polling loop.
///
/// A platform whose QR content is issued by a request fills [qrContent] in
/// the background — [poll] waits for that issue, so the first [poll] answers
/// only once the QR exists (or throws what the issue failed with).
abstract interface class LiveAuthSession {
  /// The content to encode into the login QR image (an https URL for
  /// bilibili).
  ///
  /// Reading it before the issuing request answered throws a `StateError`;
  /// call [poll] first.
  String get qrContent;

  /// Asks the platform how the login stands. Safe to call on a timer until
  /// it answers success or expired; what a transport breakdown throws is the
  /// platform's failure type.
  Future<LiveAuthPollResult> poll();
}

/// A signed-in platform account as the site adapters consume it.
///
/// The application owns persistence (its secret store): `live_sites` only
/// carries the values between [LiveAuthCapability.exchange] and
/// [LiveAuthCapability.applyCredential].
final class LiveCredential {
  /// A credential for [siteId] whose requests carry [cookies] (name and
  /// value, without attributes).
  const LiveCredential({
    required this.siteId,
    required this.cookies,
    this.userId,
    this.nickname,
    this.avatar,
    this.expiry,
  });

  /// The platform the credential signs in (`bilibili`), as in the site
  /// manifest.
  final String siteId;

  /// The cookie name-value pairs the site's requests carry.
  final Map<String, String> cookies;

  /// The account's id on the platform, when the login names one.
  final String? userId;

  /// The account's display name, when the login names one.
  final String? nickname;

  /// The account's picture address, when the login names one.
  final String? avatar;

  /// When the login stops being valid, when the platform says so.
  final DateTime? expiry;

  @override
  String toString() => 'LiveCredential($siteId, ${cookies.length} cookie(s)'
      '${userId == null ? '' : ', user $userId'})';
}

/// Signing a site in and attaching the credential to its requests
/// (ARCHITECTURE.md §4.1: an optional capability, null from
/// `LiveSite.capability<T>()` when the site does not support it).
///
/// The failure of every method is thrown — a login flow has no useful
/// "result so far" to return alongside an error.
abstract interface class LiveAuthCapability implements LiveSiteCapability {
  /// Starts a QR login and returns the session to render and poll. The QR
  /// content may still be in flight; see [LiveAuthSession].
  LiveAuthSession startQrLogin();

  /// Exchanges a confirmed [session] for the credential: polls once more
  /// when no poll answered success yet, so a session whose last poll said
  /// pending or expired fails here.
  Future<LiveCredential> exchange(LiveAuthSession session);

  /// Makes this site's requests carry [credential]'s cookies from now on.
  ///
  /// In-memory only: persistence is the application's business. Throws for a
  /// credential of another site or without cookies.
  Future<void> applyCredential(LiveCredential credential);

  /// Detaches the applied credential; the site's requests go out as before
  /// (a guest, or whatever the application feeds the site directly).
  Future<void> clearCredential();
}
