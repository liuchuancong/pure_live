import 'dart:convert';

import 'package:live_sites/src/common/normalization/site_text.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What an FC2 Live control socket needs: the channel and the fresh grant's
/// socket (its `wss://` endpoint with the `control_token`, and the handshake
/// headers carrying the `l_ortkn` cookie). A grant is good for one socket,
/// about a minute, so the session takes it at connect time through the site.
@immutable
final class Fc2LiveDanmakuArgs {
  /// A control socket target.
  const new({required this.channelId, required this.endpoint, required this.headers});

  /// The channel number.
  final String channelId;

  /// The control socket URL with its `control_token`.
  final Uri endpoint;

  /// The handshake headers (origin, UA and the `l_ortkn` session cookie).
  final Map<String, String> headers;

  @override
  String toString() => 'Fc2LiveDanmakuArgs($channelId, ${endpoint.host})';
}

/// One message of an FC2 control socket: its `name`, the `id` of an answer
/// (`_response_`) and its `arguments` (empty when missing).
typedef Fc2LiveControlMessage = ({String name, Object? id, Map<String, Object?> arguments});

/// FC2 Live's comments on a control socket (the archived spec §7), without
/// I/O.
///
/// - The server pushes JSON text frames `{"name", "arguments"}`; the room is
///   joined at `connect_complete`. The client sends only the page's heartbeat
///   command every 30 s, answered by `_response_` with the same id.
/// - `comment` carries a list of comments. The 30 most recent ones come again
///   on joining, marked `history: 1`; they are not chat.
/// - `user_count` carries only the fields that changed: viewers now are PC
///   plus mobile, this broadcast's viewers the same for the totals
///   ([Fc2LiveAudience]).
///
/// Archived from the reference and mapped onto this tree's models: a comment
/// colour is an int, the two audience figures collapse to the room's
/// concurrent ([LiveAudienceUpdate.onlineViewers]) and cumulative
/// ([LiveAudienceUpdate.watching]) counts, and the anonymous sender keeps the
/// platform's own `[anonymous]` name.
abstract final class Fc2LiveDanmakuProtocol {
  /// The page's heartbeat period (`setInterval(…, 3e4)` from the socket's
  /// open).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// How long an open socket may take to say `connect_complete` (the archived
  /// v4's join timeout).
  static const Duration joinTimeout = Duration(seconds: 8);

  /// The name the server gives anonymous comments; also the name of a comment
  /// marked `anonymous`, whatever name it carries (the page hides it).
  static const String anonymousName = '[anonymous]';

  /// The largest frame the control accepts (2 MiB).
  static const int messageLimit = 2 * 1024 * 1024;

  /// The comment colours by name; the page's chat list, `black` (its default)
  /// and unknown names falling back to white ([defaultColor]).
  static const Map<String, int> colors = {
    'red': 0xE63D37,
    'pink': 0xE13396,
    'orange': 0xDC7611,
    'yellow': 0xE1AC00,
    'green': 0x33BD4A,
    'cyan': 0x1B94C7,
    'blue': 0x4472F3,
    'purple': 0xB84AC5,
  };

  /// White, the danmaku default.
  static const int defaultColor = 0xFFFFFF;

  static const int _maxEpochMilliseconds = 8640000000000000;
  static final RegExp _tag = RegExp('<[/!?a-zA-Z][^<>]*>');

  /// The page's heartbeat command with [id].
  static String heartbeat(int id) => '{"name":"heartbeat","arguments":{},"id":$id}';

  /// One frame (text, or UTF-8 bytes) as a control message; null for a frame
  /// that is larger than the control accepts, not JSON, not an object or
  /// without a name.
  static Fc2LiveControlMessage? decode(Object? data) {
    final String text;
    switch (data) {
      case final String value:
        text = value;
      case final List<int> bytes when bytes.length <= messageLimit:
        text = utf8.decode(bytes, allowMalformed: true);
      default:
        return null;
    }
    if (text.length > messageLimit) return null;
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (root is! Map<String, Object?>) return null;
    final name = root['name'];
    if (name is! String) return null;
    final arguments = root['arguments'];
    return (name: name, id: root['id'], arguments: arguments is Map<String, Object?> ? arguments : const {});
  }

  /// The chat of a `comment` message's [arguments], in order ([comment]),
  /// without the comments [ng] hides.
  static List<LiveMessage> comments(Map<String, Object?> arguments, {Fc2LiveNgList? ng}) {
    final list = arguments['comments'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map && !(ng?.hides(item.cast<Object?, Object?>()) ?? false))
          if (comment(item) case final LiveMessage message) message,
    ];
  }

  /// One comment as chat, or null: a comment replayed on joining (`history`
  /// 1) is not chat, nor is a system comment; the text is `comment` as the
  /// page shows it ([plainText]), blank or not a string gives nothing; the
  /// name is `user_name`, [anonymousName] when the comment is `anonymous` or
  /// the name is blank; the user id is the page's key of
  /// `encrypted_user_id` ([userId]); the time is `timestamp` (ms); the colour
  /// is `color` by name ([colors]). There is no message id: `hash` names the
  /// sender, not the comment.
  static LiveMessage? comment(Object? item) {
    if (item is! Map || _isSet(item['history'])) return null;
    final raw = item['comment'];
    if (raw is! String) return null;
    final text = plainText(raw);
    if (text.isEmpty) return null;
    final name = item['user_name'];
    final userName = name is String ? plainText(name) : '';
    final time = item['timestamp'];
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _isSet(item['anonymous']) || userName.isEmpty ? anonymousName : userName,
      userId: userId(item['encrypted_user_id']),
      message: text,
      sentAt: time is int && time > 0 && time <= _maxEpochMilliseconds
          ? DateTime.fromMillisecondsSinceEpoch(time)
          : null,
      color: color(item['color']),
    );
  }

  /// JavaScript's `1 == value`, the page's test of `history`.
  static bool _isSet(Object? value) => value == 1 || value == true || value == '1';

  /// Text the server sends as HTML, as the page shows it: tags removed,
  /// character references decoded, trimmed.
  static String plainText(String html) => unescapeEntities(html.replaceAll(_tag, '')).trim();

  /// Text the server sends as HTML as the page compares it with its NG lists:
  /// the text of [html] with `&` and `<` escaped again, untrimmed.
  static String escapedText(String html) =>
      unescapeEntities(html.replaceAll(_tag, '')).replaceAll('&', '&amp;').replaceAll('<', '&lt;');

  /// The character references a comment escapes, decoded through the shared
  /// [SiteText] table (the page decodes the common named and numeric ones).
  static String unescapeEntities(String value) => SiteText.unescape(value);

  /// The page's user key of an `encrypted_user_id`: an id of at most 12
  /// characters that starts with `a` and a digit is an FC2 user id encoded
  /// with that digit as the offset, a different one on every comment, so it is
  /// decoded (`id-<n>-<n>…`); any other value is a viewer's stable id
  /// (`id_<value>`). Empty when there is none.
  static String userId(Object? encrypted) {
    if (encrypted is! String || encrypted.isEmpty) return '';
    if (encrypted.length >= 2 && encrypted.length <= 12 && encrypted.startsWith('a')) {
      final offset = encrypted.codeUnitAt(1) - 0x30;
      if (offset >= 0 && offset <= 9) {
        return 'id${[for (var i = 2; i < encrypted.length; i++) '-${encrypted.codeUnitAt(i) - offset + 3 * i}'].join()}';
      }
    }
    return 'id_$encrypted';
  }

  /// A comment colour by name ([colors]); white otherwise.
  static int color(Object? name) => (name is String ? colors[name.trim().toLowerCase()] : null) ?? defaultColor;
}

/// The NG lists the page applies to other viewers' comments, from `ng_comment`
/// messages (the streamer's and FC2's lists).
///
/// - A list entry has a `type`: keywords (`channel_keyword`, `admin_keyword`,
///   `keyword`) or senders (`channel_user`, `admin_user`, `share_low`,
///   `share_high`, `share_hyper`, `user`). `mode` `add` (or none) adds it under
///   its `ng_comment_id`, any other mode removes that id, or an equal entry
///   without one.
/// - `admin_ng` turns FC2's lists (`admin_*`) on or off; `shared_ng_level` 1
///   adds `share_low`, 2 also `share_high`; `share_hyper`, the channel's lists
///   and `keyword`/`user` always apply.
/// - A comment is hidden when its name (not for anonymous comments) or its
///   text contains a keyword, or its sender is listed: an FC2 user by the
///   decoded id, anyone else by `orz_token`. The streamer's own comments
///   (`owner` 1) are only checked against `keyword`.
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

  /// Entries held.
  int get length => _byId.length + _unnamed.length;

  /// Whether FC2's lists apply (`admin_ng`).
  bool get usesAdminLists => _admin;

  /// Which shared lists apply (`shared_ng_level`, 0 to 2).
  int get sharedLevel => _sharedLevel;

  /// Applies an `ng_comment` message's [arguments].
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
      entry = _NgEntry(type! as String, keyword: keyword is String ? keyword.toLowerCase() : '');
    } else if (_userTypes.contains(type)) {
      final orz = item['ng_orz_token'];
      entry = _NgEntry(
        type! as String,
        userId: Fc2LiveDanmakuProtocol.userId(item['ng_encrypted_user_id']),
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

  /// Whether the page would hide [comment].
  bool hides(Map<Object?, Object?> comment) {
    final owner = comment['owner'] == 1;
    final name = comment['user_name'];
    if (!_isSet(comment['anonymous']) && name is String) {
      if (_keyword(Fc2LiveDanmakuProtocol.escapedText(name), owner: owner)) return true;
    }
    if (!owner) {
      final orz = comment['orz_token'];
      if (_sender(Fc2LiveDanmakuProtocol.userId(comment['encrypted_user_id']), orz is String ? orz : null)) {
        return true;
      }
    }
    final text = comment['comment'];
    return text is String && _keyword(Fc2LiveDanmakuProtocol.escapedText(text), owner: owner);
  }

  static bool _isSet(Object? value) => value == 1 || value == true || value == '1';

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

/// One NG list entry: a keyword, or a sender's decoded id and `orz_token`.
@immutable
final class _NgEntry {
  const new(this.type, {this.keyword = '', this.userId = '', this.orz = ''});

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

/// The audience of one connection from its `user_count` messages, which carry
/// only the fields that changed: every field keeps its last value, and the
/// sums are reported when they change (the page's `setUserCount`).
///
/// Viewers now (PC plus mobile) become [LiveAudienceUpdate.onlineViewers];
/// this broadcast's viewers (the same for the totals) become
/// [LiveAudienceUpdate.watching], this tree's one cumulative-viewers field.
final class Fc2LiveAudience {
  final Map<String, int> _counts = {};

  static const List<String> _fields = ['pc_user_count', 'mobile_user_count', 'pc_total_count', 'mobile_total_count'];

  /// Viewers now: PC plus mobile, once either is known (a missing one counts
  /// 0); null before.
  int? get online => _sum('pc_user_count', 'mobile_user_count');

  /// This broadcast's viewers: PC plus mobile, as [online].
  int? get total => _sum('pc_total_count', 'mobile_total_count');

  int? _sum(String pc, String mobile) {
    final a = _counts[pc];
    final b = _counts[mobile];
    return a == null && b == null ? null : (a ?? 0) + (b ?? 0);
  }

  /// Applies a `user_count` message's [arguments] (counts that are not whole
  /// numbers of zero or more are ignored) and returns the figures that
  /// changed.
  List<LiveMessage> update(Map<String, Object?> arguments) {
    final onlineBefore = online;
    final totalBefore = total;
    for (final field in _fields) {
      final value = arguments[field];
      if (value is int && value >= 0) _counts[field] = value;
    }
    return [
      if (online case final int value when value != onlineBefore)
        LiveMessage(
          type: LiveMessageType.audienceUpdate,
          userName: '',
          message: '',
          data: LiveAudienceUpdate(onlineViewers: value),
        ),
      if (total case final int value when value != totalBefore)
        LiveMessage(
          type: LiveMessageType.audienceUpdate,
          userName: '',
          message: '',
          data: LiveAudienceUpdate(watching: value),
        ),
    ];
  }
}
