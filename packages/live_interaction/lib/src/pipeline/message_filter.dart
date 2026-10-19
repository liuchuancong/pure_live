import 'package:live_sites/live_sites.dart';

/// What kind of text a block rule matches.
enum BlockKind {
  /// Match the message text (or user name) against a keyword, with a
  /// surrounding `/…/` meaning a regular expression.
  keyword,

  /// Match the sender's user name exactly.
  user,
}

/// One block rule, as the storage layer holds it.
///
/// This mirrors the shape of the block lists the app persists; the
/// storage package owns loading and editing them, the filter owns
/// matching.
final class BlockRule {
  /// A rule blocking [pattern] by [kind].
  const new({required this.kind, required this.pattern});

  /// What the rule matches.
  final BlockKind kind;

  /// The keyword, `/regex/` or user name.
  final String pattern;
}

/// A predicate over messages; the session runs the chain in order and the
/// first rejection drops the message.
typedef MessagePredicate = bool Function(LiveMessage message);

/// The filter chain over the shared message models.
///
/// Built for the interaction spec's minimal set: block rules (keywords,
/// `/regex/` patterns and users) plus a text-shape gate against
/// pure-emoji spam. Regex patterns are validated once at construction —
/// an invalid pattern is ignored rather than throwing at match time.
final class MessageFilter {
  /// A filter over [rules]; [dropPureEmoji] removes messages that are
  /// nothing but emotes/whitespace, and [collapseRepeated] keeps only the
  /// first copy of a text seen again within [repeatedWindow].
  new({
    required List<BlockRule> rules,
    this.dropPureEmoji = true,
    this.collapseRepeated = false,
    this.repeatedWindow = const Duration(seconds: 10),
  }) {
    for (final rule in rules) {
      switch (rule.kind) {
        case BlockKind.user:
          _users.add(rule.pattern.toLowerCase());
        case BlockKind.keyword:
          final regex = _compile(rule.pattern);
          if (regex != null) {
            _keywords.add(regex);
          } else {
            _plain.add(rule.pattern.toLowerCase());
          }
      }
    }
  }

  /// Whether pure-emoji messages are dropped. Mutable: the room's danmaku
  /// settings apply live, and a re-created filter would drop the
  /// deduplication memory below.
  bool dropPureEmoji;

  /// Whether an identical text from a *different* sender inside the window
  /// is dropped (the reference's 合并短时间内的相同弹幕).
  bool collapseRepeated;

  /// How long a text stays remembered for [collapseRepeated].
  Duration repeatedWindow;

  /// user|text → when its first copy passed, for the collapse window.
  final Map<String, DateTime> _recent = {};

  final Set<String> _users = {};
  final List<RegExp> _keywords = [];
  final Set<String> _plain = {};

  /// What may be left of a pure-emote chat once its emote codes are
  /// removed: whitespace and punctuation, nothing you could read.
  static final RegExp _spacers = RegExp(r'^[\s\[\]()（）\-—_:：.,!?。，！？~～*]*$');

  /// Blocks [name] as a sender from now on (the room's long-press 屏蔽 writes
  /// here and into the stored list — the running session picks it up without
  /// a reconnect).
  void addUser(String name) {
    _users.add(name.toLowerCase());
  }

  /// Blocks [pattern] from now on: a `/regex/` spelling compiles, anything
  /// else matches plain text.
  void addKeyword(String pattern) {
    final regex = _compile(pattern);
    if (regex != null) {
      _keywords.add(regex);
    } else {
      _plain.add(pattern.toLowerCase());
    }
  }

  /// Whether [message] may be shown.
  bool allows(LiveMessage message) {
    final user = message.effectiveSender.userName.toLowerCase();
    if (_users.contains(user)) {
      return false;
    }
    final text = message.text;
    final lowered = text.toLowerCase();
    for (final plain in _plain) {
      if (lowered.contains(plain)) {
        return false;
      }
    }
    for (final regex in _keywords) {
      if (regex.hasMatch(text)) {
        return false;
      }
    }
    if (dropPureEmoji && _isPureEmoji(message)) {
      return false;
    }
    if (collapseRepeated && message.type == LiveMessageType.chat) {
      final now = DateTime.now();
      // Local and system messages keep their own copy (the reference's
      // note); among platform chats the same text collapses whoever sent it.
      final key = text.toLowerCase();
      final seen = _recent[key];
      if (seen != null && now.difference(seen) <= repeatedWindow) {
        return false;
      }
      _recent[key] = now;
      if (_recent.length > 500) {
        _recent.removeWhere((_, at) => now.difference(at) > repeatedWindow);
      }
    }
    return true;
  }

  bool _isPureEmoji(LiveMessage message) {
    if (message.type != LiveMessageType.chat || message.emotes.isEmpty) {
      return false;
    }
    // A chat message whose emote placeholders cover its whole text.
    var stripped = message.text;
    for (final emote in message.emotes) {
      stripped = stripped.replaceAll(emote.code, '');
    }
    return _spacers.hasMatch(stripped);
  }

  static RegExp? _compile(String pattern) {
    if (pattern.length < 3 || !pattern.startsWith('/') || !pattern.endsWith('/')) {
      return null;
    }
    final body = pattern.substring(1, pattern.length - 1);
    if (body.isEmpty) {
      return null;
    }
    try {
      return RegExp(body, caseSensitive: false);
    } on FormatException {
      return null;
    }
  }
}
