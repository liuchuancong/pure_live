// Module: lib/src/message_format.dart
// Purpose: The ICU subset these translations actually use - named arguments, plural and select branches,
// escaped braces - parsed to a checkable form instead of failing at display time.
// Author: liuchuancong
// Created: 2026-10-11
//
// Why not package:intl's MessageFormat: it throws when a pattern is malformed, so a typo in one locale's file
// surfaces as an exception on the first screen that happens to render that string. Parsing here produces a
// problem list, which lets a catalog refuse a bad entry at load time and report which key it was.

import 'locale.dart';
import 'plural_math.dart';
import 'plural_rules.dart';

/// A message pattern with its parse result.
final class LocalizedMessage {
  LocalizedMessage._(this.pattern, this._parts, this.problems);

  /// Parses [pattern]; unreadable pieces are reported and rendered as literal text.
  factory LocalizedMessage.parse(String pattern) {
    final parser = _Parser(pattern);
    final parts = parser.parseParts();
    return LocalizedMessage._(pattern, parts, parser.problems);
  }

  final String pattern;
  final List<_Part> _parts;

  /// What the parser could not read, empty for a well-formed message.
  final List<MessageProblem> problems;

  bool get isValid => problems.isEmpty;

  /// The argument names the message reads, which is how a catalog checks a translation uses the same
  /// arguments as the source string it replaced.
  Set<String> get argumentNames {
    final names = <String>{};
    for (final part in _parts) {
      names.addAll(part.uses);
    }
    return names;
  }

  /// Renders with [args].
  ///
  /// A missing argument renders as its own placeholder, because a silent empty slot is a bug the reader
  /// cannot report.
  String format(Map<String, Object?> args, {String language = 'en', NumberRender? number}) {
    final buffer = StringBuffer();
    for (final part in _parts) {
      buffer.write(part.render(args, language: language, number: number));
    }
    return buffer.toString();
  }

  @override
  String toString() => 'LocalizedMessage(${problems.isEmpty ? pattern : '$pattern: ${problems.first}'})';
}

/// Formats a number inside a message: the count in a plural branch, or a bare argument.
typedef NumberRender = String Function(num value, int visibleFractionDigits);

/// One defect found while parsing, with where it was found.
final class MessageProblem {
  const MessageProblem(this.message, this.offset);

  final String message;
  final int offset;

  @override
  String toString() => '$message (at $offset)';
}

abstract class _Part {
  const _Part();

  /// The argument names this part reads.
  Set<String> get uses;

  String render(Map<String, Object?> args, {required String language, NumberRender? number});
}

class _Literal extends _Part {
  const _Literal(this.text);

  final String text;

  @override
  Set<String> get uses => const <String>{};

  @override
  String render(Map<String, Object?> args, {required String language, NumberRender? number}) => text;
}

class _Argument extends _Part {
  const _Argument(this.name);

  final String name;

  @override
  Set<String> get uses => <String>{name};

  @override
  String render(Map<String, Object?> args, {required String language, NumberRender? number}) {
    if (!args.containsKey(name)) {
      return '{$name}';
    }
    final value = args[name];
    if (value is num && number != null) {
      return number(value, 0);
    }
    return '$value';
  }
}

class _Plural extends _Part {
  const _Plural(this.name, this.branches);

  final String name;
  final Map<String, List<_Part>> branches;

  @override
  Set<String> get uses => <String>{name};

  @override
  String render(Map<String, Object?> args, {required String language, NumberRender? number}) {
    final raw = args[name];
    final count = raw is num ? raw : num.tryParse('$raw');
    if (count == null) {
      // No usable number: the other form is still the best sentence to show, with `#` left visible so the
      // caller can see the argument did not arrive rather than reading a sentence about nothing.
      final fallback = branches['other'];
      if (fallback == null) {
        return '{$name}';
      }
      return _renderParts(fallback, args, language: language, number: number);
    }
    final operands = PluralOperands.of(count);
    // `=N` beats the grammatical category: it is how a translation writes "exactly one hour" differently from
    // the singular of an arbitrary count.
    final exact = branches['=${operands.i}'];
    final category = pluralCategoryOf(count, language: language);
    final branch = exact ?? branches[category.name] ?? branches[PluralCategory.other.name] ?? branches['other'];
    if (branch == null) {
      return number == null ? '$count' : number(count, operands.v);
    }
    return _join(branch, count, operands.v, number, args, language);
  }

  String _join(
    List<_Part> branch,
    num count,
    int fractionDigits,
    NumberRender? number,
    Map<String, Object?> args,
    String language,
  ) {
    // `#` is the count, substituted after rendering so a nested argument inside the branch is already in
    // place. Without a number renderer it is written plainly, which is what a debug build wants.
    final text = _renderParts(branch, args, language: language, number: number);
    return text.replaceAll('#', number == null ? '$count' : number(count, fractionDigits));
  }
}

class _Select extends _Part {
  const _Select(this.name, this.branches);

  final String name;
  final Map<String, List<_Part>> branches;

  @override
  Set<String> get uses => <String>{name};

  @override
  String render(Map<String, Object?> args, {required String language, NumberRender? number}) {
    if (!args.containsKey(name)) {
      return '{$name}';
    }
    final key = '${args[name]}';
    final branch = branches[key] ?? branches['other'];
    if (branch == null) {
      return key;
    }
    return _renderParts(branch, args, language: language, number: number);
  }
}

/// Renders a parsed body, passing the caller's arguments all the way down.
String _renderParts(List<_Part> parts, Map<String, Object?> args, {required String language, NumberRender? number}) {
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write(part.render(args, language: language, number: number));
  }
  return buffer.toString();
}

class _Parser {
  _Parser(this.text);

  final String text;
  final List<MessageProblem> problems = <MessageProblem>[];

  int _at = 0;

  bool get _done => _at >= text.length;

  List<_Part> parseParts({bool insideBranch = false}) {
    final parts = <_Part>[];
    final literal = StringBuffer();

    String flush() {
      final text = literal.toString();
      literal.clear();
      return text;
    }

    while (!_done) {
      final char = text[_at];
      if (char == '}' && insideBranch) {
        return parts;
      }
      if (char == '{' && _peek(1) == '{') {
        literal.write('{');
        _at += 2;
        continue;
      }
      if (char == '}' && _peek(1) == '}') {
        literal.write('}');
        _at += 2;
        continue;
      }
      if (char == '{') {
        final head = flush();
        if (head.isNotEmpty) {
          parts.add(_Literal(head));
        }
        _at++;
        final placeholder = _parsePlaceholder();
        if (placeholder != null) {
          parts.add(placeholder);
        }
        continue;
      }
      literal.write(char);
      _at++;
    }
    final tail = flush();
    if (tail.isNotEmpty) {
      parts.add(_Literal(tail));
    }
    if (insideBranch) {
      problems.add(MessageProblem('branch is not closed', _at));
    }
    return parts;
  }

  String? _peek(int ahead) => _at + ahead < text.length ? text[_at + ahead] : null;

  _Part? _parsePlaceholder() {
    final start = _at;
    final name = _readUntil(separators).trim();
    if (_done) {
      problems.add(MessageProblem('unterminated placeholder', start));
      return name.isEmpty ? null : _Argument(name);
    }
    if (text[_at] == '}') {
      _at++;
      return _Argument(name);
    }
    // Here text[_at] is ',', so the placeholder carries a type.
    _at++;
    final kind = _readUntil(separators).trim().toLowerCase();
    if (_done || text[_at] != ',') {
      problems.add(MessageProblem('placeholder "$name" is missing its branches', start));
      _skipToClose();
      return _Argument(name);
    }
    _at++;
    if (kind == 'number' || kind == 'date' || kind == 'time' || kind == 'currency') {
      // The style is decided by the caller's renderer, so the option is skipped and the value passed through.
      _skipToClose();
      return _Argument(name);
    }
    if (kind != 'plural' && kind != 'selectordinal' && kind != 'select') {
      problems.add(MessageProblem('unknown placeholder type "$kind"', start));
      _skipToClose();
      return _Argument(name);
    }
    final branches = _readBranches();
    if (kind == 'select') {
      return _Select(name, branches);
    }
    return _Plural(name, branches);
  }

  Map<String, List<_Part>> _readBranches() {
    final branches = <String, List<_Part>>{};
    while (!_done) {
      while (!_done && (text[_at] == ' ' || text[_at] == '\t' || text[_at] == '\n' || text[_at] == '\r')) {
        _at++;
      }
      if (_done) {
        break;
      }
      if (text[_at] == '}') {
        _at++;
        return branches;
      }
      final key = _readUntil(<String>{'{', '}', ' '}).trim();
      if (_done || text[_at] != '{') {
        problems.add(MessageProblem('branch "${key.isEmpty ? '?' : key}" has no body', _at));
        return branches;
      }
      _at++;
      final body = parseParts(insideBranch: true);
      if (!_done && text[_at] == '}') {
        _at++;
      }
      if (key.isNotEmpty) {
        branches[key] = body;
      }
    }
    problems.add(MessageProblem('branch list is not closed', _at));
    return branches;
  }

  void _skipToClose() {
    var depth = 1;
    while (!_done && depth > 0) {
      final char = text[_at];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          _at++;
          return;
        }
      }
      _at++;
    }
  }

  static const Set<String> separators = <String>{',', '}', '{'};

  String _readUntil(Set<String> stops) {
    final buffer = StringBuffer();
    while (!_done && !stops.contains(text[_at])) {
      buffer.write(text[_at]);
      _at++;
    }
    return buffer.toString();
  }
}
