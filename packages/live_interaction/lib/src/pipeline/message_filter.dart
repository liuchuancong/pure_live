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
  /// nothing but emotes/whitespace.
  new({required List<BlockRule> rules, this.dropPureEmoji = true}) {
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

  /// Whether pure-emoji messages are dropped.
  final bool dropPureEmoji;

  final Set<String> _users = {};
  final List<RegExp> _keywords = [];
  final Set<String> _plain = {};

  static final RegExp _emoji = RegExp(r'^[\s\[\w\-:：]{0,8}$');

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
    return _emoji.hasMatch(stripped);
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
