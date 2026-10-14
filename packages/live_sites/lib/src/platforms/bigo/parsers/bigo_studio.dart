import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Who may watch a studio anonymously.
enum BigoAccess {
  /// Anyone with the web token, as far as the answer says — a later use of a
  /// token does not say whether the room has a password, so only a
  /// [BigoStudio.complete] answer settles it.
  public,

  /// `needLogin`, checked before everything else, as the official player does.
  loginRequired,

  /// `passRoom` (a password) or `isPaidShow` `"1"` (a paid show).
  restricted,
}

/// One `getInternalStudioInfo` answer, as the adapter reads it.
///
/// A web token answers differently on its first use than later: only the first
/// use says whether the room has a password ([password]) and hands out the
/// playlist ([hls]); every later use leaves both out but still gives the state,
/// names and pictures ([BigoStudio.complete] false). The three reads the
/// capabilities make (an entry, a refresh, a play resolve) therefore differ in
/// what one answer can settle.
final class BigoStudio {
  /// Creates the answer.
  const BigoStudio({
    required this.requestedSiteId,
    required this.siteId,
    required this.ownerId,
    required this.access,
    required this.roomStatus,
    required this.roomType,
    this.alive,
    this.broadcastId,
    this.nickname = '',
    this.title = '',
    this.category = '',
    this.avatar = '',
    this.snapshot = '',
    this.hls,
    this.password,
    this.paid = false,
    this.complete = true,
  });

  /// The Bigo id the studio was asked for (a numeric id or the streamer's
  /// chosen one).
  final String requestedSiteId;

  /// `clientBigoId`: the id as the site writes it, the room's identity
  /// whatever it was asked for by.
  final String siteId;

  /// `uid`: the streamer's account.
  final int ownerId;

  /// Who may watch.
  final BigoAccess access;

  /// Whether the studio is live, or null when the answer hides it (a login gate
  /// zeroes the answer; a password or paid room that is not alive does not say
  /// it is offline).
  final bool? alive;

  /// `roomStatus`.
  final int roomStatus;

  /// `roomType`; `"1"` is the studio the page ends the live for, whose chat the
  /// website does not open.
  final String roomType;

  /// `roomId`: the streamer's int64 room id as written (the same for every
  /// broadcast of the account), or null (`"0"`, offline or gated). The chat
  /// socket enters this one.
  final String? broadcastId;

  /// `nick_name`; '' when the answer gives none (an offline studio names
  /// nobody).
  final String nickname;

  /// `roomTopic`; '' when there is none.
  final String title;

  /// `gameTitle`; '' when there is none.
  final String category;

  /// `avatar`; '' when there is none.
  final String avatar;

  /// `snapshot`: the broadcast's screenshot (the last one when offline); ''
  /// when there is none.
  final String snapshot;

  /// `hls_src`: the media playlist, given only for a public live studio and
  /// only on a token's first use.
  final Uri? hls;

  /// `passRoom`; null when the answer does not say (a token's later use).
  final bool? password;

  /// `isPaidShow` is `"1"`.
  final bool paid;

  /// Whether this is a token's first use (`passRoom` given): only such an
  /// answer says whether the room has a password and gives the playlist.
  final bool complete;

  /// The state: live when `alive` says so, whatever the access (a restricted
  /// live room is live); offline when a public studio says not alive; unknown
  /// when the answer hides it.
  LiveStatus get liveStatus => switch (alive) {
    true => LiveStatus.live,
    false => LiveStatus.offline,
    null => LiveStatus.unknown,
  };

  /// What keeps a viewer out: `needsLogin` behind the login gate, `password`
  /// or `paid` for a restricted room, `none` for a complete public live answer
  /// with a playlist and `unplayable` without one; null when the answer cannot
  /// tell (offline, or a token's later use that is neither gated nor paid).
  LiveRestriction? get restriction => switch (access) {
    BigoAccess.loginRequired => LiveRestriction.needsLogin,
    BigoAccess.restricted => (password ?? false) ? LiveRestriction.password : LiveRestriction.paid,
    BigoAccess.public when alive != true || !complete => null,
    BigoAccess.public => hls == null ? LiveRestriction.unplayable : LiveRestriction.none,
  };

  /// Whether this studio's chat the website would open: live, not gated, not a
  /// password room (its chat needs the password), not `roomType` `"1"`, and
  /// with a room id. A paid show's chat is opened, as the website does.
  bool get opensChat =>
      broadcastId != null &&
      alive == true &&
      access != BigoAccess.loginRequired &&
      !(password ?? false) &&
      roomType != '1';

  /// This answer (a token's later use) behind the login gate that a first use
  /// of the same token reported: the gate stays, the state is this answer's.
  BigoStudio gated() => BigoStudio(
    requestedSiteId: requestedSiteId,
    siteId: siteId,
    ownerId: ownerId,
    access: BigoAccess.loginRequired,
    roomStatus: roomStatus,
    roomType: roomType,
    alive: alive,
    broadcastId: broadcastId,
    nickname: nickname,
    title: title,
    category: category,
    avatar: avatar,
    snapshot: snapshot,
    password: password,
    paid: paid,
    complete: false,
  );

  /// Why this studio's stream cannot be watched here, or null when it can: a
  /// login gate is [BigoFailureKind.needsLogin]; a password or paid room, an
  /// offline one and a live one whose complete answer gave no playlist are
  /// [BigoFailureKind.streamUnavailable]. A live answer that says nothing about
  /// the lock (a refresh) is let through: the play resolve asks the studio
  /// again.
  BigoFailure? get streamError => switch (access) {
    BigoAccess.loginRequired => BigoFailure(BigoFailureKind.needsLogin, '$siteId: needLogin'),
    BigoAccess.restricted => BigoFailure(
      BigoFailureKind.streamUnavailable,
      '$siteId: ${paid ? 'paid show' : 'password room'}',
    ),
    BigoAccess.public when alive != true => BigoFailure(BigoFailureKind.streamUnavailable, '$siteId is offline'),
    BigoAccess.public when complete && hls == null => BigoFailure(
      BigoFailureKind.streamUnavailable,
      '$siteId: live without hls_src',
    ),
    BigoAccess.public => null,
  };

  @override
  String toString() => 'BigoStudio($siteId, ${access.name}, ${liveStatus.name})';
}
