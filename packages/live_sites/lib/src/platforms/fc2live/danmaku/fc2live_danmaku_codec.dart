import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_json.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One message of an FC2 Live control socket: its `name`, the `id` of an answer
/// and its `arguments` (empty when the frame carries none, or none it can use).
typedef Fc2LiveFrame = ({String name, Object? id, Map<String, Object?> arguments});

/// FC2 Live's comment protocol, without I/O.
///
/// Comments travel on a media-control socket of their own — the same protocol
/// that announces a channel's playlists, on a grant taken for the purpose: FC2
/// has no chat server apart from it. The server pushes JSON text frames named by
/// `name`; the room is joined at `connect_complete`; the client sends only the
/// page's heartbeat command, answered by a `_response_` of the same id.
///
/// What the frames carry is small: `comment` is a list of chat lines (the 30
/// most recent ones come again marked `history`, and are not chat), `user_count`
/// the figures that changed, `ng_comment` the page's own filters, and
/// `control_disconnection` / `move_server` the server's orders to take a new
/// socket. Tips, gifts and entries arrive as a `system_comment` *inside* a
/// comment row rather than as their own kind, and the page shows them as a
/// system line the viewer cannot reply to — they are not chat here either, since
/// nothing in the model says what they are. There is no message id anywhere:
/// the `hash` a row carries names its sender, not the row, and repeats.
abstract final class Fc2LiveDanmakuCodec {
  /// The page's heartbeat period (`setInterval(…, 3e4)` from the socket's open).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// How long an open socket may take to say `connect_complete`: the recording
  /// of 2026-09-27 had it 5 ms after the open.
  static const Duration joinTimeout = Duration(seconds: 8);

  /// How long a socket may go without any frame before it is replaced (the
  /// runtime's default: the page itself never times a chat socket out, but a
  /// silent one carries nothing).
  static const Duration inactivityTimeout = Duration(seconds: 90);

  /// How many times a socket may be replaced for the same reason — a server
  /// order, a join timeout, a failed handshake — before the connection gives up.
  /// A heartbeat that is answered restarts the count.
  static const int maxReconnects = 8;

  /// The step between those attempts.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// The name the site gives an anonymous comment, whatever name it carries (the
  /// page hides the one it sends).
  static const String anonymousName = '[anonymous]';

  /// The comment colours by name, as the page's chat list styles them. `black`
  /// is the site's own default and, with any unknown name, white: the text is
  /// shown on a dark background here.
  static const Map<String, LiveMessageColor> colors = {
    'red': LiveMessageColor(0xE6, 0x3D, 0x37),
    'pink': LiveMessageColor(0xE1, 0x33, 0x96),
    'orange': LiveMessageColor(0xDC, 0x76, 0x11),
    'yellow': LiveMessageColor(0xE1, 0xAC, 0x00),
    'green': LiveMessageColor(0x33, 0xBD, 0x4A),
    'cyan': LiveMessageColor(0x1B, 0x94, 0xC7),
    'blue': LiveMessageColor(0x44, 0x72, 0xF3),
    'purple': LiveMessageColor(0xB8, 0x4A, 0xC5),
  };

  static const int _maxEpochMilliseconds = 8640000000000000;
  static final RegExp _tag = RegExp('<[/!?a-zA-Z][^<>]*>');

  /// The page's heartbeat command with its [id].
  static String heartbeat(int id) => '{"name":"heartbeat","arguments":{},"id":$id}';

  /// One frame (text, or UTF-8 bytes — malformed ones as the replacement
  /// character, as the page's own client reads them), or null for a frame larger
  /// than a control accepts, that is not JSON, that is not an object, or that
  /// names nothing.
  static Fc2LiveFrame? decode(Object? data) {
    final String text;
    switch (data) {
      case final String value:
        text = value;
      case final List<int> bytes when bytes.length <= Fc2LiveEndpoints.messageLimit:
        text = utf8.decode(bytes, allowMalformed: true);
      default:
        return null;
    }
    if (text.length > Fc2LiveEndpoints.messageLimit) return null;
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (root is! Map) return null;
    final name = root['name'];
    if (name is! String) return null;
    final arguments = root['arguments'];
    return (name: name, id: root['id'], arguments: arguments is Map ? Map<String, Object?>.from(arguments) : const {});
  }

  /// The chat of a `comment` message: its rows in order, without the ones [ng]
  /// hides.
  static List<LiveMessage> comments(Map<String, Object?> arguments, {Fc2LiveNgList? ng}) => [
    for (final row in Fc2LiveJson.list(arguments['comments']))
      if (row is Map && !(ng?.hides(row) ?? false)) ?comment(Map<Object?, Object?>.from(row)),
  ];

  /// One comment row as chat, or null: a row replayed on joining, a system row
  /// (a tip, a gift, an entry), text that is not text or is blank after the
  /// page's own cleaning.
  ///
  /// The name is `user_name` as the page shows it, [anonymousName] when the row
  /// is marked anonymous or the name is blank; the sender id is the page's own
  /// key of `encrypted_user_id` ([userId]); the time is `timestamp` in
  /// milliseconds, left out when it is not positive or out of range; the colour
  /// is `color` by name ([colors]).
  static LiveMessage? comment(Object? item) {
    if (item is! Map) return null;
    if (isSet(item['history']) || item['system_comment'] != null) return null;
    final raw = item['comment'];
    if (raw is! String) return null;
    final text = plainText(raw);
    if (text.isEmpty) return null;
    final name = item['user_name'];
    final userName = name is String ? plainText(name) : '';
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: userId(item['encrypted_user_id']),
        userName: isSet(item['anonymous']) || userName.isEmpty ? anonymousName : userName,
      ),
      text: text,
      color: color(item['color']),
      sentAt: time(item['timestamp']),
    );
  }

  /// JavaScript's `1 == value`, which is how the page tests `history`,
  /// `anonymous` and `owner`: the number 1, the string `'1'` and `true` are set;
  /// `0`, `'0'`, `''` and null are not.
  static bool isSet(Object? value) => value == 1 || value == true || value == '1';

  /// A comment's time in milliseconds, or null outside what a clock can hold.
  static DateTime? time(Object? value) {
    final milliseconds = Fc2LiveJson.jsonInt(value);
    if (milliseconds == null || milliseconds <= 0 || milliseconds > _maxEpochMilliseconds) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// Text the site sends as HTML, shown as the page shows it: its tags removed,
  /// character references decoded, trimmed.
  static String plainText(String html) => Fc2LiveJson.htmlEntities(html.replaceAll(_tag, '')).trim();

  /// Text the site sends as HTML as the page compares it with its filters: the
  /// text of [html] with `&` and `<` escaped again and nothing trimmed — the
  /// page matches its stored keywords against exactly this.
  static String escapedText(String html) =>
      Fc2LiveJson.htmlEntities(html.replaceAll(_tag, '')).replaceAll('&', '&amp;').replaceAll('<', '&lt;');

  /// The page's own key of an `encrypted_user_id` (`decryptUserId`).
  ///
  /// A value of 2 to 12 characters that starts with `a` and has a digit next is
  /// an FC2 user id written with that digit as an offset — a different offset on
  /// every comment, which is why decoding it is what makes a sender stable. Any
  /// other value is a visitor's own key, written as `id_<value>`; nothing at all
  /// is no sender.
  static String userId(Object? encrypted) {
    if (encrypted is! String || encrypted.isEmpty) return '';
    if (encrypted.length >= 2 && encrypted.length <= 12 && encrypted.startsWith('a')) {
      final offset = encrypted.codeUnitAt(1) - 0x30;
      if (offset >= 0 && offset <= 9) {
        final parts = [for (var i = 2; i < encrypted.length; i++) '-${encrypted.codeUnitAt(i) - offset + 3 * i}'];
        return 'id${parts.join()}';
      }
    }
    return 'id_$encrypted';
  }

  /// A comment's colour by name ([colors]); white for a name the site does not
  /// style and for none at all.
  static LiveMessageColor color(Object? name) =>
      (name is String ? colors[name.trim().toLowerCase()] : null) ?? LiveMessageColor.white;

  /// The address a comment connection is nominally given: the grant request of
  /// [channelId]. Every handshake turns it into a fresh grant's socket.
  static Uri endpoint(String channelId) => Fc2LiveEndpoints.grantAddress(channelId);

  /// The channel of an [endpoint], or null for any other address.
  static String? channelOf(Uri address) => Fc2LiveEndpoints.channelOfGrant(address);

  /// [text] without the values of a grant's secrets: a failed handshake names
  /// the whole socket URL, its token included, and a connection that reports
  /// that failure must not repeat it.
  static String redact(String text) => text.replaceAllMapped(_secrets, (match) => '${match[1]}=…');

  static final RegExp _secrets = RegExp(r'''((?<=[?&])control_token|l_ortkn)=[^&#;\s'"]*''');
}

/// The audience of one connection, read from its `user_count` messages.
///
/// Those carry only the fields that changed, so every field keeps its last
/// value and the two sums are reported when they change — exactly what the
/// page does. Viewers now are PC plus mobile; this broadcast's viewers the same
/// for the totals. A figure whose halves are both unknown is not reported (a
/// zero would be a lie), and a value that is not a whole number of zero or more
/// is ignored.
final class Fc2LiveAudience {
  final Map<String, int> _counts = {};

  static const List<String> _fields = ['pc_user_count', 'mobile_user_count', 'pc_total_count', 'mobile_total_count'];

  /// Viewers now: PC plus mobile, once either is known.
  int? get online => _sum('pc_user_count', 'mobile_user_count');

  /// This broadcast's viewers: PC plus mobile, once either half is known.
  int? get total => _sum('pc_total_count', 'mobile_total_count');

  int? _sum(String pc, String mobile) {
    final a = _counts[pc];
    final b = _counts[mobile];
    return a == null && b == null ? null : (a ?? 0) + (b ?? 0);
  }

  /// Applies a `user_count` message and gives the figures that changed: viewers
  /// now, then this broadcast's total.
  List<LiveMessage> update(Map<String, Object?> arguments) {
    final onlineBefore = online;
    final totalBefore = total;
    for (final field in _fields) {
      final value = arguments[field];
      if (value is int && value >= 0) _counts[field] = value;
    }
    return [
      if (online case final int value when value != onlineBefore) _figure(LiveAudienceSignalKind.onlineViewers, value),
      if (total case final int value when value != totalBefore) _figure(LiveAudienceSignalKind.totalViewers, value),
    ];
  }

  static LiveMessage _figure(LiveAudienceSignalKind kind, int value) => LiveMessage.normalized(
    type: LiveMessageType.audienceUpdate,
    payload: LiveAudienceUpdate.of(kind: kind, value: value),
  );
}

/// The filters the site applies to other viewers' comments, from the
/// `ng_comment` messages that name them (the streamer's and the platform's
/// lists, sent to a viewer who keeps none of their own).
///
/// An entry is a keyword (`keyword`, `channel_keyword`, `admin_keyword`) or a
/// sender (`user`, `channel_user`, `admin_user` and the three shared lists).
/// `admin_ng` turns the platform's lists on or off and `shared_ng_level` which
/// of the shared ones apply; the channel's lists and a viewer's own always
/// apply. A `mode` of `add` (or none) stores an entry under its id, any other
/// mode removes it.
///
/// A comment is hidden when its name (not for an anonymous one) or its text
/// holds a keyword — compared as the page escapes them, in lower case — or when
/// its sender is listed, by the decoded user id for an FC2 account and by the
/// session token for anyone else. The streamer's own comments are checked
/// against the plain `keyword` list only.
final class Fc2LiveNgList {
  static const Set<String> _keywordTypes = {'keyword', 'channel_keyword', 'admin_keyword'};
  static const Set<String> _userTypes = {
    'user',
    'channel_user',
    'admin_user',
    'share_low',
    'share_high',
    'share_hyper',
  };

  bool _admin = false;
  int _sharedLevel = 0;
  final Map<String, _NgEntry> _byId = {};
  final List<_NgEntry> _unnamed = [];

  /// How many entries are held.
  int get length => _byId.length + _unnamed.length;

  /// Whether the platform's own lists apply (`admin_ng`).
  bool get usesAdminLists => _admin;

  /// Which shared lists apply (`shared_ng_level`: 0 none, 1 the low one, 2 also
  /// the high).
  int get sharedLevel => _sharedLevel;

  /// Applies an `ng_comment` message.
  void apply(Map<String, Object?> arguments) {
    if (arguments.containsKey('admin_ng')) _admin = _truthy(arguments['admin_ng']);
    if (_level(arguments['shared_ng_level']) case final int level) _sharedLevel = level;
    final list = arguments['ng_comments'];
    if (list is List) list.forEach(_change);
  }

  static bool _truthy(Object? value) => value != null && value != false && value != 0 && value != '';

  static int? _level(Object? value) => switch (value) {
    final int level => level,
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  void _change(Object? item) {
    if (item is! Map) return;
    final type = item['type'];
    final _NgEntry entry;
    if (_keywordTypes.contains(type)) {
      final keyword = item['ng_keyword'];
      entry = _NgEntry('$type', keyword: keyword is String ? keyword.toLowerCase() : '');
    } else if (_userTypes.contains(type)) {
      final orz = item['ng_orz_token'];
      entry = _NgEntry(
        '$type',
        userId: Fc2LiveDanmakuCodec.userId(item['ng_encrypted_user_id']),
        orz: orz is String ? orz : '',
      );
    } else {
      return;
    }
    final id = item['ng_comment_id'];
    final key = (id is int && id != 0) || (id is String && id.isNotEmpty) ? '$id' : null;
    final mode = item['mode'];
    if (mode == null || mode == 'add') {
      if (key != null) {
        _byId[key] = entry;
      } else {
        _unnamed.add(entry);
      }
    } else if (key != null) {
      _byId.remove(key);
    } else {
      _unnamed.removeWhere((held) => held == entry);
    }
  }

  Iterable<_NgEntry> get _entries => _byId.values.followedBy(_unnamed);

  /// Whether the page would hide [row].
  bool hides(Map<Object?, Object?> row) {
    final owner = row['owner'] == 1;
    final name = row['user_name'];
    if (!Fc2LiveDanmakuCodec.isSet(row['anonymous']) && name is String) {
      if (_keyword(Fc2LiveDanmakuCodec.escapedText(name), owner: owner)) return true;
    }
    if (!owner) {
      final orz = row['orz_token'];
      final userId = Fc2LiveDanmakuCodec.userId(row['encrypted_user_id']);
      if (_sender(userId, orz is String ? orz : null)) return true;
    }
    final text = row['comment'];
    return text is String && _keyword(Fc2LiveDanmakuCodec.escapedText(text), owner: owner);
  }

  bool _applies(String type) => switch (type) {
    'admin_keyword' || 'admin_user' => _admin,
    'share_low' => _sharedLevel >= 1,
    'share_high' => _sharedLevel >= 2,
    _ => true,
  };

  bool _keyword(String text, {required bool owner}) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return _entries.any(
      (entry) =>
          entry.keyword.isNotEmpty &&
          (owner ? entry.type == 'keyword' : _applies(entry.type)) &&
          lower.contains(entry.keyword),
    );
  }

  bool _sender(String userId, String? orz) {
    final decoded = userId.startsWith('id-');
    return _entries.any(
      (entry) =>
          _userTypes.contains(entry.type) &&
          _applies(entry.type) &&
          (decoded ? entry.userId.isNotEmpty && entry.userId == userId : entry.orz.isNotEmpty && entry.orz == orz),
    );
  }
}

/// One filter entry: a keyword, or a sender's decoded id and session token.
@immutable
final class _NgEntry {
  const _NgEntry(this.type, {this.keyword = '', this.userId = '', this.orz = ''});

  final String type;
  final String keyword;
  final String userId;
  final String orz;

  @override
  bool operator ==(Object other) =>
      other is _NgEntry && other.type == type && other.keyword == keyword && other.userId == userId && other.orz == orz;

  @override
  int get hashCode => Object.hash(type, keyword, userId, orz);
}
