// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/common/danmaku/filters/block_pattern.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';

/// The user's blocked viewers and words (3.x `DanmakuController._isBlocked`
/// with the lists of `_refreshFilters`).
///
/// - Both lists are trimmed and lower-cased once; empty entries are dropped.
/// - A masked name (a guest's view
///   of a Bilibili viewer such as `观***`) blocks nobody: it stands for
///   every viewer whose name starts the same way (audit B-1).
/// - A message is blocked when its trimmed, lower-cased sender name is a
///   blocked name, or when its lower-cased text contains a blocked word.
/// - A word written `/…/` is a pattern instead ([DanmakuBlockPattern],
///   D02.2): compiled once here, without regard to case, and matched with
///   the first [DanmakuBlockPattern.matchedLength] characters of the text;
///   a pattern that does not compile or is refused blocks nothing.
final class DanmakuBlockList {
  /// Creates the list from the stored names ([users]) and words
  /// ([keywords]), as the user typed them.
  factory DanmakuBlockList.of({Iterable<String> users = const [], Iterable<String> keywords = const []}) {
    final words = <String>[];
    final patterns = <RegExp>[];
    for (final keyword in keywords) {
      final word = keyword.trim();
      if (word.isEmpty) continue;
      if (DanmakuBlockPattern.isPattern(word)) {
        if (DanmakuBlockPattern.compile(word) case final pattern?) patterns.add(pattern);
      } else {
        words.add(word.toLowerCase());
      }
    }
    return DanmakuBlockList._(
      {
        for (final user in users)
          if (user.trim().toLowerCase() case final name when name.isNotEmpty && !_isMaskedName(name)) name,
      },
      List.unmodifiable(words),
      List.unmodifiable(patterns),
    );
  }

  const DanmakuBlockList._(this._users, this._keywords, this._patterns);

  /// A platform-masked viewer name (`观***`): it stands for every viewer
  /// whose name starts the same way, so it blocks nobody.
  static bool _isMaskedName(String name) => name.contains('*');

  final Set<String> _users;
  final List<String> _keywords;
  final List<RegExp> _patterns;

  /// Whether nothing is blocked.
  bool get isEmpty => _users.isEmpty && _keywords.isEmpty && _patterns.isEmpty;

  /// Whether [message] is from a blocked viewer or contains a blocked word.
  bool blocks(LiveMessage message) {
    final user = (message.sender?.userName ?? '').trim().toLowerCase();
    if (user.isNotEmpty && _users.contains(user)) return true;
    return matchesText(message.text);
  }

  /// Whether [text] contains a blocked word or matches a blocked pattern.
  bool matchesText(String text) {
    if (_keywords.isNotEmpty) {
      final lower = text.toLowerCase();
      if (_keywords.any(lower.contains)) return true;
    }
    if (_patterns.isEmpty) return false;
    final part = DanmakuBlockPattern.matchedPart(text);
    return _patterns.any((pattern) => pattern.hasMatch(part));
  }
}
